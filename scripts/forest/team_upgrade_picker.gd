extends Control
const PreparationSkin=preload("res://scripts/forest/preparation_skin.gd")
const SHINE=preload("res://scripts/forest/team_card_shine.gdshader")
const Skills=preload("res://scripts/spells/skill_balance.gd")
const Pets=preload("res://scripts/forest/pet_catalog.gd")
const RARITY_COLORS=[Color("dce8fa"),Color("ffd875"),Color("91f1ff")]
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
	var shade=ColorRect.new();shade.color=Color(.035,.055,.065,.64);shade.mouse_filter=Control.MOUSE_FILTER_IGNORE
	add_child(shade);shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel=VBoxContainer.new();panel.add_theme_constant_override("separation",16);add_child(panel)
	heading=text_label(panel,"",32);subtitle=text_label(panel,"",17)
	var row=HBoxContainer.new();row.alignment=BoxContainer.ALIGNMENT_CENTER;row.add_theme_constant_override("separation",18);panel.add_child(row)
	for i in 3:
		var button=Button.new();button.name="TeamCard%d"%(i+1);button.custom_minimum_size=Vector2(284,440)
		button.mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND
		PreparationSkin.apply_button(button)
		for state in ["normal","hover","pressed","hover_pressed"]:
			var frame=PreparationSkin.panel()
			if state!="normal":frame.modulate_color=Color(1.15,1.2,1.2)
			button.add_theme_stylebox_override(state,frame)
		row.add_child(button);buttons.append(button);button.pressed.connect(select.bind(i))
		var shine=ColorRect.new();shine.name="Shine";shine.mouse_filter=Control.MOUSE_FILTER_IGNORE
		shine.material=ShaderMaterial.new();shine.material.shader=SHINE;shine.material.set_shader_parameter("phase",i*1.7)
		button.add_child(shine);shine.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		shine.offset_left=4;shine.offset_right=-4;shine.offset_top=4;shine.offset_bottom=-4
		var contents=VBoxContainer.new();contents.mouse_filter=Control.MOUSE_FILTER_IGNORE
		button.add_child(contents);contents.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		contents.offset_left=20;contents.offset_right=-38;contents.offset_top=34;contents.offset_bottom=-22
		contents.add_theme_constant_override("separation",10)
		var category=text_label(contents,"",16);category.name="Category"
		category.add_theme_stylebox_override("normal",PreparationSkin.button_style("normal"));category.add_theme_color_override("font_color",PreparationSkin.INK)
		var icon=TextureRect.new();icon.name="Icon";icon.mouse_filter=Control.MOUSE_FILTER_IGNORE
		icon.custom_minimum_size=Vector2(65,65);icon.size_flags_horizontal=Control.SIZE_SHRINK_CENTER
		icon.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;icon.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		contents.add_child(icon)
		text_label(contents,"",22).name="Title"
		text_label(contents,"",22).name="Level"
	text_label(panel,"Choose one · Skill levels last for this run",16)
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
	heading.text="LEVEL %d"%offered_level
	subtitle.text="Choose a skill to upgrade" if progression.pending()==1 else "%d upgrades waiting · Choose one at a time"%progression.pending()
	for i in buttons.size():
		var button=buttons[i]
		button.visible=i<progression.offer.size()
		if not button.visible:continue
		var target:String=progression.offer[i]
		var skill=target.get_slice("|",0)
		var pet_key:String=game.skill_card_pet(target)
		var spec:Dictionary=Skills.all()[skill]
		var wearer="" if pet_key.is_empty() else Pets.display_name(Pets.skin(pet_key),game.settings.forest_pet_names)
		var rarity:int=progression.offer_rarities[i]
		var before:int=game.skill_card_level(target)
		var after=mini(Skills.Levels.MAX_LEVEL,before+progression.CARD_LEVELS[rarity])
		var level_text="Lv %d → %d"%[before,after]
		button.find_child("Category",true,false).text=str(i+1) if wearer.is_empty() else "%d · %s"%[i+1,wearer]
		button.find_child("Title",true,false).text=spec.name
		button.find_child("Level",true,false).text=level_text
		button.accessibility_name="%s, %s"%[spec.name,level_text] if wearer.is_empty() else "%s, %s, %s"%[wearer,spec.name,level_text]
		var shine=button.get_node("Shine")
		shine.material.set_shader_parameter("rarity_color",RARITY_COLORS[rarity]);shine.material.set_shader_parameter("rarity",float(rarity+1))
		var icon=button.find_child("Icon",true,false)
		icon.texture=Skills.Catalog.KAZI_ICONS.get(skill)
		if skill==Skills.Catalog.KAGEROU:icon.texture=Skills.Catalog.KAGEROU_ICON
		elif icon.texture==null:icon.texture=Skills.Catalog.Roster.portrait(spec.source)
	buttons[0].grab_focus()

func select(index:int):
	var offer:Array[String]=game.model.team_progression.offer
	if Time.get_ticks_msec()>=ready_at and index>=0 and index<offer.size():game.choose_team_upgrade(offer[index],offered_level)
