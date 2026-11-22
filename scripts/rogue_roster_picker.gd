extends Control
## One shared gallery for all playable fighters. Selection art never drives gameplay.
const Roster=preload("res://scripts/rogue_roster.gd")
const KazSkins=preload("res://scripts/kaz_skins.gd")
const Proportions=preload("res://scripts/character_proportions.gd")
const PreparationSkin=preload("res://scripts/forest/preparation_skin.gd")
const BLUE_INK=Color("193c59")
const PORTRAIT_ORIGINS={Roster.RUBY_ID:Vector2(-34,-82),Roster.MAZE_ID:Vector2(-21,-76)}
const SKIN_ROW_HEIGHT=58
var game: Node
var title_text="F I R E   S I E G E   /   C H O O S E   Y O U R   H E R O"
var start_hint=""
var back_text="Q / Esc · Back to battle"
var grid: GridContainer
var scroll: ScrollContainer
var cards: Array[Button]=[]
var forest_mode=false
var art:TextureRect
var blue_paper:ColorRect
var blue_heading:VBoxContainer
var toolbar:PanelContainer
var dark_toolbar:StyleBox

func style_roster_button(button:Button):
	PreparationSkin.apply_button(button)

func label(words: String,point_size: int,tint: Color=Color("eaf1ed"))->Label:
	var node=Label.new();node.text=words
	node.add_theme_font_size_override("font_size",point_size)
	node.add_theme_color_override("font_color",tint)
	node.set_meta("roster_point_size",point_size)
	node.mouse_filter=Control.MOUSE_FILTER_IGNORE
	return node

func _ready():
	forest_mode=game.has_method("begin_forest")
	theme=PreparationSkin.theme()
	process_mode=Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	blue_paper=ColorRect.new();blue_paper.color=Color("e2eef5")
	blue_paper.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);blue_paper.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(blue_paper)
	art=TextureRect.new();art.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;art.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_COVERED
	art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);art.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(art)
	var margin=MarginContainer.new();margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left","right"]:margin.add_theme_constant_override("margin_"+side,30)
	for side in ["top","bottom"]:margin.add_theme_constant_override("margin_"+side,22)
	add_child(margin)
	var layout=VBoxContainer.new();layout.add_theme_constant_override("separation",10);margin.add_child(layout)
	blue_heading=VBoxContainer.new();blue_heading.add_theme_constant_override("separation",2);layout.add_child(blue_heading)
	blue_heading.add_child(label("CHARACTER SELECT",34,BLUE_INK))
	blue_heading.add_child(label("Choose your fighter",18,BLUE_INK))
	scroll=ScrollContainer.new();scroll.name="RosterScroll";scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;scroll.follow_focus=true;layout.add_child(scroll)
	grid=GridContainer.new();grid.name="RosterGrid";grid.columns=4;grid.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation",10);grid.add_theme_constant_override("v_separation",10);scroll.add_child(grid)
	for id in Roster.selection_ids():
		cards.append(fighter_card(id))
	toolbar=PanelContainer.new();toolbar.name="RosterToolbar";layout.add_child(toolbar)
	dark_toolbar=preload("res://scripts/forest/forest_hud_skin.gd").new().lacquer()
	var footer=HBoxContainer.new();footer.add_theme_constant_override("separation",18);toolbar.add_child(footer)
	var back=Button.new();back.name="RogueRosterClose";back.text="Back";back.custom_minimum_size=Vector2(100,46);back.pressed.connect(game.close_rogue_roster);footer.add_child(back)
	style_roster_button(back)
	show_gallery()
	layout.move_child(toolbar,0)
	resized.connect(refresh_columns);get_viewport().size_changed.connect(refresh_columns)
	scroll.resized.connect(refresh_columns)

func select_kaz_skin(skin_id:int,portrait:TextureRect):
	game.select_kaz_skin(skin_id)
	var skin:Array=KazSkins.CATALOG[game.settings.kaz_skin]
	set_crossgate_portrait(portrait,skin[1],skin[2],Roster.KAZI_ID,game.settings.kaz_skin)

func refresh_skin_cards():
	if not is_inside_tree():return
	for card in cards:
		var id:int=card.get_meta("fighter_id")
		if Roster.skin_catalog(id).is_empty():continue
		var view:TextureRect=card.find_child("SelectionPortrait",true,false)
		var skin=Roster.selected_skin(id,game.settings)
		if id==Roster.KAZI_ID:set_crossgate_portrait(view,KazSkins.CATALOG[skin][1],KazSkins.CATALOG[skin][2],id,skin)
		elif Roster.is_shin(id):show_shin_portrait(view,skin,id==Roster.SHIN_SPECIAL_ID)
		else:show_variant_portrait(view,id)
		for control in card.find_children("*","Button",true,false):
			if control.get_script()==preload("res://scripts/character_skin_picker.gd"):control.selected_id=skin;control.refresh()

func select_shin_skin(skin_id:int,character:int,portrait:TextureRect):
	game.select_shin_skin(character,skin_id)
	show_shin_portrait(portrait,skin_id,character==Roster.SHIN_SPECIAL_ID)

func select_crossgate_skin(skin_id:int,character:int,portrait:TextureRect):
	game.select_crossgate_skin(character,skin_id)
	show_variant_portrait(portrait,character)

func show_variant_portrait(view:TextureRect,character:int):
	var profile=Roster.CROSSGATE[character]
	var skin:int=game.settings[profile.skin_setting]
	set_crossgate_portrait(view,Roster.skin_portrait(character,skin),Roster.skin_portrait_origin(character,skin),character,skin)

func show_shin_portrait(view:TextureRect,id:int,weapon:bool):
	var texture=Roster.ShinSkins.portrait(id)
	var origin:Vector2=Roster.ShinSkins.catalog(weapon)[id][1]
	set_crossgate_portrait(view,texture,origin,Roster.SHIN_SPECIAL_ID if weapon else Roster.SHIN_ID,id)

func add_skin_picker(row:VBoxContainer,node_name:String,catalog:Dictionary,selected_id:int,changed:Callable,character:int):
	var caption=label("Skin",13,PreparationSkin.PAPER)
	caption.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	row.add_child(caption)
	var picker=preload("res://scripts/character_skin_picker.gd").new()
	picker.name=node_name
	picker.custom_minimum_size.y=34
	picker.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
	picker.catalog=catalog;picker.selected_id=selected_id;picker.character=character
	picker.skin_selected.connect(changed)
	style_roster_button(picker)
	picker.add_theme_font_size_override("font_size",14)
	row.add_child(picker)

static func show_selection_portrait(view:TextureRect,character:int,settings:Dictionary):
	view.texture=selection_texture(character,settings)

static func selection_texture(character:int,settings:Dictionary)->Texture2D:
	var skin=Roster.selected_skin(character,settings)
	if character==Roster.KAZI_ID:
		var row:Array=KazSkins.CATALOG[skin]
		return crossgate_texture(row[1],row[2],character,skin)
	elif Roster.is_shin(character):
		return crossgate_texture(Roster.ShinSkins.portrait(skin),Roster.ShinSkins.catalog(character==Roster.SHIN_SPECIAL_ID)[skin][1],character,skin)
	elif Roster.has_variant_skins(character):
		return crossgate_texture(Roster.skin_portrait(character,skin),Roster.skin_portrait_origin(character,skin),character,skin)
	return crossgate_texture(Roster.selection_portrait(character),PORTRAIT_ORIGINS[character],character,skin)

static func set_crossgate_portrait(view:TextureRect,texture:Texture2D,origin:Vector2,character:int,skin:int=0):
	view.texture=crossgate_texture(texture,origin,character,skin)

static func crossgate_texture(texture:Texture2D,origin:Vector2,character:int,skin:int=0)->AtlasTexture:
	var preview=AtlasTexture.new()
	preview.atlas=texture
	var body_pixels=Proportions.crossgate_body_pixels(character,skin)
	var ratio=body_pixels/Proportions.KAZ_BODY_PIXELS
	var feet=Vector2(0,Proportions.CROSSGATE_FEET_PIXELS)
	var canvas=Rect2(feet+Vector2(-58,-95)*ratio,Vector2(124,128)*ratio)
	# Fit the standing body. Effects that extend past the portrait slot are clipped.
	var crop=Rect2(origin,texture.get_size()).intersection(canvas)
	preview.region=Rect2(crop.position-origin,crop.size)
	preview.margin=Rect2(crop.position-canvas.position,canvas.size-crop.size)
	return preview

func show_gallery():
	# BlueCG NewClient, joy:450 / serial 245040.
	var blue=forest_mode
	blue_paper.visible=blue;blue_heading.visible=blue
	toolbar.add_theme_stylebox_override("panel",dark_toolbar)
	art.stretch_mode=TextureRect.STRETCH_SCALE if blue else TextureRect.STRETCH_KEEP_ASPECT_COVERED
	if blue:
		art.texture=preload("res://assets/ui/maroon/crossgate_character_making.png")
	else:
		art.texture=preload("res://assets/ui/maroon/blue_cross_gate_select.png")
	scroll.scroll_vertical=0
	refresh_columns.call_deferred()
	focus_selected_card.call_deferred()

func focus_selected_card():
	# The later rows have no final position until the gallery containers sort.
	# Focusing during _ready leaves a selected fighter below the scroll window.
	await get_tree().process_frame
	if not is_inside_tree():return
	var selected:Button
	for card in cards:
		if not card.visible:continue
		if selected==null:selected=card
		if card.get_meta("fighter_id")==Roster.gallery_id(game.selected_rogue_id):selected=card;break
	if selected!=null:
		selected.grab_focus();scroll.ensure_control_visible(selected)

func refresh_columns():
	if not is_instance_valid(grid):return
	# Godot stretches the canvas from 1440px. Use physical window size as well,
	# so a 960px window keeps comfortable cards and scrolls through three rows.
	var available=minf(size.x,DisplayServer.window_get_size().x)
	var blue=blue_heading.visible
	grid.columns=4
	var readability=maxf(1.0,1280.0/maxf(640,available))
	refresh_type(self,readability)
	var width=maxf(170,(minf(scroll.size.x,size.x-60)-18-(grid.columns-1)*10)/grid.columns)
	var height=clampf((scroll.size.y-10)*.5,235,400) if blue else (312 if forest_mode else 318)*readability
	for card in cards:
		card.custom_minimum_size=Vector2(width,height if forest_mode else height+SKIN_ROW_HEIGHT)
		card.find_child("SelectionPortrait",true,false).custom_minimum_size.y=height*.62 if blue else (210 if forest_mode else 158)*readability

func refresh_type(node: Node,readability: float):
	if node is Label and node.has_meta("roster_point_size"):
		node.add_theme_font_size_override("font_size",roundi(float(node.get_meta("roster_point_size"))*readability))
	for child in node.get_children():refresh_type(child,readability)

func fighter_card(id: int)->Button:
	var data=Roster.data(id) if id>=3 else {"id":"goemon" if id==1 else "edo","name":"Goemon" if id==1 else "Edo","color":"#edcf87" if id==1 else "#ff956f","description":"Pipe master. Sweeping combos, heavy strikes and sky attacks." if id==1 else "Firecaster. Fireballs, blue surge and a meteor barrage."}
	if id==Roster.SONIC_ID:data={"id":"sonic","name":"Sonic","color":"#559dff","description":"Space / LMB: jump; press again in the air for Homing Attack. Hold RMB / E and release for Spin Dash. R: aerial Homing Attack. C: uncurl. Q: fighters."}
	if id==Roster.MUSASHI_ID:data={"id":"musashi","name":"Musashi","color":"#bba4f2","description":"Fusion and Lumina with Crosswise Cut (X Slash), Tenderize and Desperado. Original enemy skills and R to guard."}
	if id==Roster.SASUKE_ID:data={"id":"sasuke","name":"Sasuke","color":"#d7d4ac","description":"Mechanical ninja. Gold kunai combo, firecracker bombs, freezing kunai and charged Hail Beam, hair attacks and Super Jump. All equipment unlocked."}
	if id==Roster.YAE_ID:data={"id":"yae","name":"Yae","color":"#b4e4c3","description":"Secret ninja agent. Tier 3 gold katana combo, Sword Shield and bazooka with a charged lock-on shot. All combat equipment unlocked."}
	if id==Roster.MASTER_CHIEF_ID:data={"id":"master-chief","name":"Master Chief","color":"#a6d9b4","description":"Spartan-117. First-person combat. 1: Rocket launcher, 2: Pistol, 3: Shotgun, 4: Assault rifle, 5: Energy sword. Pistol headshots kill in one hit; rifle headshots deal double damage. LMB fires guns or swings the sword. Infinite ammunition. Mouse to aim. Q returns to the fighter gallery."}
	if id in [Roster.ED_ID,Roster.BEN_ID]:data={"id":Roster.class_id(id),"name":Roster.name_for(id),"color":"#ec947a" if id==14 else "#bad17c","description":"Hold LMB for a powerful piercing beam. RMB throws bouncing fireballs. E unleashes smoke jumps, volleys and a huge blast." if id==14 else "LMB: slash; click again to lunge. Hold RMB: blue bomb barrage. E: three-shuriken fan. Hold Space: flight."}
	var tint=Color(data.color)
	var blue=forest_mode and Roster.is_crossgate_fighter(id)
	var button=Button.new();button.name="RogueFighter_"+data.id
	button.set_meta("fighter_id",id)
	button.custom_minimum_size=Vector2(200,318);button.mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND
	button.clip_contents=true;button.tooltip_text="" if forest_mode or Roster.is_crossgate_fighter(id) else data.description;button.pressed.connect(game.choose_rogue_character.bind(id));grid.add_child(button)
	var style=PreparationSkin.compact_panel()
	if id==Roster.gallery_id(game.selected_rogue_id):style.modulate_color=Color(1.12,1.18,1.2)
	var hover=style.duplicate();hover.modulate_color=Color(1.2,1.25,1.25)
	PreparationSkin.apply_button(button)
	button.add_theme_stylebox_override("normal",style)
	for state in ["hover","pressed","hover_pressed"]:button.add_theme_stylebox_override(state,hover)
	var contents=VBoxContainer.new();contents.mouse_filter=Control.MOUSE_FILTER_IGNORE
	contents.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);contents.offset_left=11;contents.offset_right=-11;contents.offset_top=7;contents.offset_bottom=-8;contents.add_theme_constant_override("separation",3);button.add_child(contents)
	if blue:contents.offset_top=18;contents.offset_bottom=-14
	var portrait=TextureRect.new();portrait.name="SelectionPortrait";portrait.mouse_filter=Control.MOUSE_FILTER_IGNORE
	portrait.custom_minimum_size.y=210 if forest_mode else 158;portrait.size_flags_vertical=Control.SIZE_EXPAND_FILL;portrait.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;portrait.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;portrait.texture=Roster.selection_portrait(id);contents.add_child(portrait)
	if Roster.is_crossgate_fighter(id):show_selection_portrait(portrait,id,game.settings)
	if blue:
		portrait.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
		portrait.size_flags_vertical=Control.SIZE_FILL
	var name_label=label(data.name.to_upper() if forest_mode else data.name,24 if blue else 18,PreparationSkin.PAPER if forest_mode else tint)
	name_label.name="FighterName";name_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;name_label.vertical_alignment=VERTICAL_ALIGNMENT_CENTER;name_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	contents.add_child(name_label)
	if forest_mode:
		if not blue:name_label.add_theme_stylebox_override("normal",theme.get_stylebox("normal","Button"))
		return button
	if Roster.is_enemy(id):
		for line in ["1–5  Wind · Water · Fire · Earth · Sky" if id==30 else "LMB  Tail sweep" if id==27 else "LMB  Original attack","LMB Three-cut combo · RMB Sword rush" if id==30 else "RMB  Jump stomp" if id==27 else "Recovered enemy fighter","1–5  Special skills · Q to equip","C  Evade · Space  Jump"]:contents.add_child(label(line,13))
	elif Roster.WARCRAFT.has(id):
		for line in (["LMB Sword combo · RMB Critical strike","1 Bladestorm · Q Shared skills","Space Jump · C Evade"] if id==31 else ["LMB Hammer and axe · Passive Bash","1 Storm Bolt · 2 Thunder Clap · 3 Avatar","Space Jump · C Evade · Q Shared skills"] if id==33 else ["LMB Glaives / Demon bolt","RMB / 1 Metamorphosis · Q Shared skills","Space Jump / Meta Fly · Shift Boost · C Evade"]):contents.add_child(label(line,14))
	elif id==Roster.RUBY_ID:
		for line in ["Blue Cross Gate #105716","LMB / RMB  Staff combo","1–5  Blue Cross Gate spells","Space Timed Dodge · Shift + Space Jump"]:contents.add_child(label(line,14))
	elif id==Roster.KAZI_ID:
		for line in ["Blue Cross Gate #102488","LMB / RMB  Sword attack","Space Timed Dodge · Shift + Space Jump","Q Shared skills"]:contents.add_child(label(line,14))
	elif Roster.has_crossgate_throws(id):
		for line in ["LMB / RMB · Katana or dagger throw","Space Timed Dodge · Shift + Space Jump"]:contents.add_child(label(line,14))
	elif id==Roster.BOG_ID:
		for line in ["LMB / RMB · Axe attack","1 乾坤 · 2 連擊 · 4 明鏡止水"]:contents.add_child(label(line,14))
	elif Roster.is_shin(id):
		contents.add_child(label("LMB / RMB · Basic strike",14))
	elif id==Roster.KOJIRO_ID:
		for line in ["LMB  Cut → Turn → Flip","1 Homing · 2 Wind","RMB / 3  Sword wave","C  Evade · Space  Jump"]:contents.add_child(label(line,14))
	elif id==Roster.SONIC_ID:
		contents.add_child(label("Sonic Adventure DX",13,Color("aac3b6")))
		for line in ["Space / LMB  Jump / Homing","Hold RMB / 1  Spin Dash","2  Aerial Homing Attack","C  Uncurl · Q  Fighters"]:contents.add_child(label(line,14))
	elif id==Roster.MASTER_CHIEF_ID:
		contents.add_child(label("Spartan-117 · First person",13,Color("aac3b6")))
		for line in ["1 Rockets · 2 Pistol","3 Shotgun · 4 Assault Rifle","5 Energy Sword · LMB Swing","Mouse Aim · Q Fighters"]:contents.add_child(label(line,14))
	elif id==Roster.YAE_ID:
		contents.add_child(label("Secret ninja agent · Tier 3",13,Color("aac3b6")))
		for line in ["LMB / Hold  Katana combo","RMB / Hold  Shot / Lock-on","Hold 1 Shield · 2 Bazooka · 3 Lock-on","C  Evade · Space  Jump"]:contents.add_child(label(line,14))
	elif id==Roster.SASUKE_ID:
		contents.add_child(label("Mechanical ninja · Tier 3",13,Color("aac3b6")))
		for line in ["LMB  Gold kunai · RMB  Bomb","1 / Hold  Ice kunai / Hail Beam","3 Up hair · 4 Forward hair · 5 Bomb","2  Super Jump · C  Evade"]:contents.add_child(label(line,14))
	elif id==Roster.MUSASHI_ID:
		contents.add_child(label("Sword fighter",13,Color("aac3b6")))
		for line in ["LMB Fusion · RMB Lumina","1 X Slash · 2 Tenderize · 3 Desperado","One press performs the full combo","4 Lumina Rotation · 5 Mighty Strike","More abilities in Loadout","R Guard · Space Double jump · Q Fighters"]:contents.add_child(label(line,14))
	elif id in [Roster.ED_ID,Roster.BEN_ID]:
		contents.add_child(label("Beam caster" if id==14 else "Flying polearm fighter",13,Color("aac3b6")))
		for line in (["LMB / Hold  Beam blast","RMB  Bouncing fireballs","1 Smoke · 2 Burst · 3 Fireballs · 4 Beam","C  Evade","Space  Jump","Shift  Sprint · Q  Fighters"] if id==14 else ["LMB / Hold  Guandao combo","1 Stars / Axes · 2 Bombs · 3 Axes","Hold Space  Fly · Release  Descend","C  Evade · Shift  Boost"]):contents.add_child(label(line,14))
	elif id<=2:
		contents.add_child(label("Pipe master" if id==1 else "Firecaster",13,Color("aac3b6")))
		for line in (["LMB  Pipe combo","RMB  Heavy strike","1 Dash · 2 Surge · 3 Sky strike","4 Coins · 5 Chain pipe · C Evade"] if id==1 else ["LMB  Fireballs","RMB  Giant fireball","1 Fire dodge · 2 Blue surge","3 Meteors · 4/5 Fireballs"]):contents.add_child(label(line,14))
	else:
		contents.add_child(label("%d HP · %s"%[data.maxHealth,data.weaponNames[0]],13,Color("aac3b6")))
		for slot in ["cutlass","flintlock","roll","drink"]:
			var key={"cutlass":"LMB","flintlock":"RMB / 4","roll":"1","drink":"2"}[slot]
			var ability_name=str(data.abilities[slot].name)
			if slot=="roll" and data.id in ["samurai","ninja","explorer","master-thief"]:ability_name+=" · C Evade"
			var line=label("%s  %s"%[key,ability_name],14,tint if slot=="drink" else Color("d4e1df"))
			line.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS;contents.add_child(line)
			button.tooltip_text+="\n%s · %s"%[data.abilities[slot].name,data.abilities[slot].description.replace("RMB / 3:","RMB:" if forest_mode else "RMB / 3:")]
	add_skin_row(contents,id,portrait)
	return button

func add_skin_row(contents:VBoxContainer,id:int,portrait:TextureRect):
	var row=VBoxContainer.new()
	row.mouse_filter=Control.MOUSE_FILTER_IGNORE
	row.custom_minimum_size.y=SKIN_ROW_HEIGHT
	row.add_theme_constant_override("separation",2)
	contents.add_child(row)
	if id==Roster.KAZI_ID:
		add_skin_picker(row,"KazSkin",KazSkins.CATALOG,game.settings.kaz_skin,select_kaz_skin.bind(portrait),id)
	elif Roster.has_variant_skins(id):
		var profile=Roster.CROSSGATE[id]
		add_skin_picker(row,profile.name+"Skin",Roster.skin_catalog(id),game.settings[profile.skin_setting],select_crossgate_skin.bind(id,portrait),id)
	elif Roster.is_shin(id):
		var weapon=id==Roster.SHIN_SPECIAL_ID
		var setting=Roster.ShinSkins.setting(weapon)
		add_skin_picker(row,"ShinSpecialSkin" if weapon else "ShinSkin",Roster.ShinSkins.gallery(weapon),game.settings[setting],select_shin_skin.bind(id,portrait),id)

func _input(event):
	if not is_visible_in_tree() or event.is_echo():return
	if event.is_action_pressed("pause") or event.is_action_pressed("character_toggle"):
		get_viewport().set_input_as_handled();game.close_rogue_roster()
