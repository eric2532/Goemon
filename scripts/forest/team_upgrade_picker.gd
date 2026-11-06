extends Control
const PreparationSkin=preload("res://scripts/forest/preparation_skin.gd")
const SHINE=preload("res://scripts/forest/team_card_shine.gdshader")
const RARITY_COLORS=[PreparationSkin.PAPER,Color("dce8fa"),Color("ffd875"),Color("91f1ff"),Color("fff0ba")]
var game
var panel:VBoxContainer
var heading:Label
var subtitle:Label
var buttons:Array[Button]=[]
var offered_level=0
var ready_at=0

func text_label(parent:Node,text_:String,font_size:int)->Label:
	var label=Label.new();label.text=text_;label.mouse_filter=Control.MOUSE_FILTER_IGNORE
	label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size",font_size);parent.add_child(label);return label

func _ready():
	name="TeamUpgradePicker";process_mode=Node.PROCESS_MODE_ALWAYS;theme=PreparationSkin.theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shade=ColorRect.new();shade.color=Color(.035,.015,.03,.82);shade.mouse_filter=Control.MOUSE_FILTER_IGNORE
	add_child(shade);shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel=VBoxContainer.new();panel.add_theme_constant_override("separation",16);add_child(panel)
	heading=text_label(panel,"",32);subtitle=text_label(panel,"",17)
	var row=HBoxContainer.new();row.add_theme_constant_override("separation",18);panel.add_child(row)
	for i in 3:
		var button=Button.new();button.name="TeamCard%d"%(i+1);button.custom_minimum_size=Vector2(284,440)
		button.size_flags_horizontal=Control.SIZE_EXPAND_FILL;button.mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND
		PreparationSkin.apply_button(button)
		for state in ["normal","hover","pressed","hover_pressed"]:
			var frame=PreparationSkin.panel()
			if state!="normal":frame.modulate_color=Color(1.3,1.15,1.2)
			button.add_theme_stylebox_override(state,frame)
		row.add_child(button);buttons.append(button);button.pressed.connect(select.bind(i))
		var shine=ColorRect.new();shine.name="Shine";shine.mouse_filter=Control.MOUSE_FILTER_IGNORE
		shine.material=ShaderMaterial.new();shine.material.shader=SHINE;shine.material.set_shader_parameter("phase",i*1.7)
		button.add_child(shine);shine.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		shine.offset_left=4;shine.offset_right=-4;shine.offset_top=4;shine.offset_bottom=-4
		var contents=VBoxContainer.new();contents.mouse_filter=Control.MOUSE_FILTER_IGNORE
		button.add_child(contents);contents.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		contents.offset_left=20;contents.offset_right=-20;contents.offset_top=20;contents.offset_bottom=-20
		contents.add_theme_constant_override("separation",10)
		var category=text_label(contents,"",16);category.name="Category"
		category.add_theme_stylebox_override("normal",PreparationSkin.button_style("normal"));category.add_theme_color_override("font_color",PreparationSkin.INK)
		text_label(contents,"",19).name="Rarity"
		var icon=TextureRect.new();icon.name="Icon";icon.mouse_filter=Control.MOUSE_FILTER_IGNORE
		icon.custom_minimum_size=Vector2(65,65);icon.size_flags_horizontal=Control.SIZE_SHRINK_CENTER
		icon.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;icon.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		contents.add_child(icon)
		text_label(contents,"",22).name="Title"
		var description=text_label(contents,"",17);description.name="Description";description.size_flags_vertical=Control.SIZE_EXPAND_FILL
		text_label(contents,"",14).name="Rank"
	text_label(panel,"Choose one · This run only",16)
	resized.connect(layout);refresh();layout.call_deferred()
	panel.modulate.a=0
	create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS).tween_property(panel,"modulate:a",1.0,.18)

func layout():
	var panel_size=Vector2(900,580)
	var factor=minf(1.0,minf((size.x-40)/panel_size.x,(size.y-40)/panel_size.y))
	panel.size=panel_size;panel.scale=Vector2.ONE*factor;panel.position=(size-panel_size*factor)*.5

func refresh():
	ready_at=Time.get_ticks_msec()+250
	var progression=game.model.team_progression;offered_level=progression.choice_level()
	heading.text="TEAM LEVEL %d"%offered_level
	subtitle.text="Choose how your team grows" if progression.pending()==1 else "%d upgrades waiting · Choose one at a time"%progression.pending()
	for i in 3:
		var id=progression.offer[i];var card=progression.CARDS[id];var button=buttons[i]
		var rarity=progression.offer_rarities[i];var power=rarity+1;var color=RARITY_COLORS[rarity]
		button.find_child("Category",true,false).text="%d · %s"%[i+1,card.category.to_upper()]
		var badge=button.find_child("Rarity",true,false);badge.text="LEGENDARY" if rarity==4 else "%s · %d× BONUS"%[progression.RARITIES[rarity].to_upper(),power]
		badge.add_theme_color_override("font_color",color)
		button.find_child("Title",true,false).text=card.title
		button.find_child("Description",true,false).text=progression.description(id,rarity)
		button.find_child("Rank",true,false).text="UNLOCK FOR ALL WORKERS" if id=="worker_revive" else "RANK %d → %d"%[progression.ranks.get(id,0),progression.ranks.get(id,0)+power]
		if rarity<4 and id!="worker_revive":button.find_child("Rank",true,false).text+="\n%s TOTAL ×%.2f → ×%.2f"%["PLAYER" if id=="player_range" else "TEAM",progression.multiplier(id),progression.multiplier(id,power)]
		if rarity==4:button.find_child("Rank",true,false).text="5× TOWER DAMAGE · THIS RUN" if id=="legendary_tower" else "INSTANT REINFORCEMENTS"
		var shine=button.get_node("Shine");shine.visible=rarity>0
		var inset=-28 if rarity==4 else 4
		shine.offset_left=inset;shine.offset_right=-inset;shine.offset_top=inset;shine.offset_bottom=-inset
		shine.material.set_shader_parameter("rarity_color",color);shine.material.set_shader_parameter("rarity",float(rarity))
		var icon=button.find_child("Icon",true,false);icon.material=null;icon.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		if card.has("hero") or card.has("mercenary"):
			var character=int(card.hero) if card.has("hero") else game.explorer_helpers.KITS[card.mercenary]
			icon.texture=preload("res://scripts/rogue_roster.gd").selection_portrait(character)
		elif card.category=="Tower":icon.texture=game.forest_ui.build_buttons.tower.icon
		elif card.category=="Worker":icon.texture=game.forest_ui.hud_icons.get_icon("worker")
		else:
			icon.texture=game.forest_ui.hero_portrait.texture;icon.material=game.forest_ui.hero_portrait.material;icon.stretch_mode=TextureRect.STRETCH_SCALE
	buttons[0].grab_focus()

func select(index:int):
	if Time.get_ticks_msec()>=ready_at and index>=0 and index<buttons.size():game.choose_team_upgrade(game.model.team_progression.offer[index],offered_level)
