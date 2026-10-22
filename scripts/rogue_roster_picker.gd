extends Control
## One shared gallery for all playable fighters. Selection art never drives gameplay.
const Roster=preload("res://scripts/rogue_roster.gd")
var game: Node
var title_text="F I R E   S I E G E   /   C H O O S E   Y O U R   H E R O"
var start_hint=""
var back_text="Q / Esc · Back to battle"
var grid: GridContainer
var scroll: ScrollContainer
var cards: Array[Button]=[]
var forest_mode=false

func label(words: String,point_size: int,tint: Color=Color("eaf1ed"))->Label:
	var node=Label.new();node.text=words
	node.add_theme_font_size_override("font_size",point_size)
	node.add_theme_color_override("font_color",tint)
	node.set_meta("roster_point_size",point_size)
	node.mouse_filter=Control.MOUSE_FILTER_IGNORE
	return node

func _ready():
	process_mode=Node.PROCESS_MODE_ALWAYS
	forest_mode=game.has_method("begin_forest")
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shade=ColorRect.new();shade.color=Color("10221f");shade.color.a=.97
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);shade.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(shade)
	var margin=MarginContainer.new();margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left","right"]:margin.add_theme_constant_override("margin_"+side,30)
	for side in ["top","bottom"]:margin.add_theme_constant_override("margin_"+side,22)
	add_child(margin)
	var layout=VBoxContainer.new();layout.add_theme_constant_override("separation",10);margin.add_child(layout)
	var heading=label(title_text.replace("   "," ").replace("F O R E S T","FOREST").replace("S H R I N E","SHRINE").replace("C H O O S E","CHOOSE").replace("Y O U R","YOUR").replace("F I G H T E R","FIGHTER").replace("F I R E","FIRE").replace("S I E G E","SIEGE").replace("H E R O","HERO"),26,Color("f1d198"))
	heading.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;layout.add_child(heading)
	layout.add_child(label("%d fighters · Choose your style"%Roster.selection_ids().size(),17,Color("b6cac1")))
	if forest_mode:
		var helpers=label("1–5  Assigned weapons · Hire guards during preparation · RMB  Secondary attack",17,Color("d5d7af"));helpers.name="RosterSharedHelpers";layout.add_child(helpers)
	scroll=ScrollContainer.new();scroll.name="RosterScroll";scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;scroll.follow_focus=true;layout.add_child(scroll)
	grid=GridContainer.new();grid.name="RosterGrid";grid.columns=6;grid.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation",10);grid.add_theme_constant_override("v_separation",10);scroll.add_child(grid)
	for id in Roster.selection_ids():cards.append(fighter_card(id))
	var footer=HBoxContainer.new();footer.add_theme_constant_override("separation",18);layout.add_child(footer)
	var back=Button.new();back.name="RogueRosterClose";back.text="Esc · Back" if game.rogue_pick_start else back_text;back.custom_minimum_size=Vector2(225,46);back.pressed.connect(game.close_rogue_roster);footer.add_child(back)
	var outfits=Button.new();outfits.name="MusashiOutfits";outfits.text="Musashi equipment";outfits.custom_minimum_size=Vector2(200,46);footer.add_child(outfits)
	outfits.pressed.connect(func():
		if is_instance_valid(find_child("MusashiEquipment",true,false)):return
		var picker=load("res://scripts/recovered_musashi_outfit_picker.gd").new();picker.game=game;add_child(picker))
	var hint=start_hint if not start_hint.is_empty() else ("Choose a hero to begin. Stand nearby to build, then hold Y to launch a wave." if game.roster_start_mode=="defense" else "Choose a hero to begin, then pick your first upgrade card.")
	var help=label("WASD move · Mouse camera · Space jump · Shift sprint\n"+(hint if game.rogue_pick_start else "Time is paused. Switching keeps health percentage and cooldowns."),16,Color("a9c3b7"))
	help.size_flags_horizontal=Control.SIZE_EXPAND_FILL;help.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;footer.add_child(help)
	resized.connect(refresh_columns);get_viewport().size_changed.connect(refresh_columns)
	refresh_columns.call_deferred()
	focus_selected_card.call_deferred()

func focus_selected_card():
	# The later rows have no final position until the gallery containers sort.
	# Focusing during _ready leaves a selected fighter below the scroll window.
	await get_tree().process_frame
	if not is_inside_tree() or cards.is_empty():return
	var selected=cards[0]
	for card in cards:
		if card.get_meta("fighter_id")==game.selected_rogue_id:selected=card;break
	selected.grab_focus();scroll.ensure_control_visible(selected)

func refresh_columns():
	if not is_instance_valid(grid):return
	# Godot stretches the canvas from 1440px. Use physical window size as well,
	# so a 960px window keeps comfortable cards and scrolls through three rows.
	var available=minf(size.x,DisplayServer.window_get_size().x)
	grid.columns=6 if available>=1180 else (4 if available>=880 else 3)
	var readability=maxf(1.0,1280.0/maxf(640,available))
	refresh_type(self,readability)
	var width=maxf(170,(scroll.size.x-18-(grid.columns-1)*10)/grid.columns)
	for card in cards:
		card.custom_minimum_size=Vector2(width,318*readability)
		card.find_child("SelectionPortrait",true,false).custom_minimum_size.y=158*readability

func refresh_type(node: Node,readability: float):
	if node is Label and node.has_meta("roster_point_size"):
		node.add_theme_font_size_override("font_size",roundi(float(node.get_meta("roster_point_size"))*readability))
	for child in node.get_children():refresh_type(child,readability)

func fighter_card(id: int)->Button:
	var data=Roster.data(id) if id>=3 else {"id":"goemon" if id==1 else "edo","name":"Goemon" if id==1 else "Edo","color":"#edcf87" if id==1 else "#ff956f","description":"Pipe master. Sweeping combos, heavy strikes and sky attacks." if id==1 else "Firecaster. Fireballs, blue surge and a meteor barrage."}
	if id==Roster.MUSASHI_ID:data={"id":"musashi","name":"Musashi","color":"#bba4f2","description":"Fusion and Lumina sword attacks. Press 1 for Lumina Rotation or 2 for Mighty Strike. Hold R to guard."}
	if id==Roster.SASUKE_ID:data={"id":"sasuke","name":"Sasuke","color":"#d7d4ac","description":"Mechanical ninja. Gold kunai combo, firecracker bombs, freezing kunai and charged Hail Beam, hair attacks and Super Jump. All equipment unlocked."}
	if id==Roster.YAE_ID:data={"id":"yae","name":"Yae","color":"#b4e4c3","description":"Secret ninja agent. Tier 3 gold katana combo, Sword Shield and bazooka with a charged lock-on shot. All combat equipment unlocked."}
	if id==Roster.MASTER_CHIEF_ID:data={"id":"master-chief","name":"Master Chief","color":"#a6d9b4","description":"Spartan-117. First-person combat. 1: Rocket launcher, 2: Pistol, 3: Shotgun, 4: Assault rifle, 5: Energy sword. Pistol headshots kill in one hit; rifle headshots deal double damage. LMB fires guns or swings the sword. Infinite ammunition. Mouse to aim. Q returns to the fighter gallery."}
	if id in [Roster.ED_ID,Roster.BEN_ID]:data={"id":Roster.class_id(id),"name":Roster.name_for(id),"color":"#ec947a" if id==14 else "#bad17c","description":"Hold LMB for a powerful piercing beam. RMB throws bouncing fireballs. E unleashes smoke jumps, volleys and a huge blast." if id==14 else "LMB: polearm. Hold RMB: blue bomb barrage. E: three-shuriken fan. Hold Space: flight."}
	var tint=Color(data.color)
	var button=Button.new();button.name="RogueFighter_"+data.id
	button.set_meta("fighter_id",id)
	button.custom_minimum_size=Vector2(200,318);button.mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND
	button.clip_contents=true;button.tooltip_text=data.description;button.pressed.connect(game.choose_rogue_character.bind(id));grid.add_child(button)
	var style=StyleBoxFlat.new();style.bg_color=Color("1c3430");style.border_color=Color(tint,.55);style.set_border_width_all(1);style.set_corner_radius_all(10)
	if id==game.selected_rogue_id:style.border_color=tint;style.set_border_width_all(3)
	var hover=style.duplicate();hover.bg_color=Color("2a4840");hover.border_color=tint;hover.set_border_width_all(3)
	button.add_theme_stylebox_override("normal",style)
	for state in ["hover","focus","pressed"]:button.add_theme_stylebox_override(state,hover)
	var contents=VBoxContainer.new();contents.mouse_filter=Control.MOUSE_FILTER_IGNORE
	contents.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);contents.offset_left=11;contents.offset_right=-11;contents.offset_top=7;contents.offset_bottom=-8;contents.add_theme_constant_override("separation",3);button.add_child(contents)
	var portrait=TextureRect.new();portrait.name="SelectionPortrait";portrait.mouse_filter=Control.MOUSE_FILTER_IGNORE
	portrait.custom_minimum_size.y=158;portrait.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;portrait.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;portrait.texture=Roster.selection_portrait(id);contents.add_child(portrait)
	contents.add_child(label(data.name,21,tint))
	if id==Roster.MASTER_CHIEF_ID:
		contents.add_child(label("Spartan-117 · First person",13,Color("aac3b6")))
		for line in ["1 Rockets · 2 Pistol","3 Shotgun · 4 Assault Rifle","5 Energy Sword · LMB Swing","Mouse Aim · Q Fighters"]:contents.add_child(label(line,14))
	elif id==Roster.YAE_ID:
		contents.add_child(label("Secret ninja agent · Tier 3",13,Color("aac3b6")))
		for line in ["LMB / Hold  Katana combo","RMB / Hold  Shot / Lock-on","Hold E  Sword Shield","C  Evade · Space  Jump"]:contents.add_child(label(line,14))
	elif id==Roster.SASUKE_ID:
		contents.add_child(label("Mechanical ninja · Tier 3",13,Color("aac3b6")))
		for line in ["LMB  Gold kunai · RMB  Bomb","E / Hold  Ice kunai / Hail Beam","T / Shift+T  Up / Forward hair","R  Super Jump · C  Evade"]:contents.add_child(label(line,14))
	elif id==Roster.MUSASHI_ID:
		contents.add_child(label("Sword fighter",13,Color("aac3b6")))
		for line in ["LMB  4-hit Fusion · RMB  Lumina","1  Lumina Spin · 2  Mighty Strike","R  Guard · Space  Double jump","WASD  Move · Q  Fighters"]:contents.add_child(label(line,14))
	elif id in [Roster.ED_ID,Roster.BEN_ID]:
		contents.add_child(label("Beam caster" if id==14 else "Flying polearm fighter",13,Color("aac3b6")))
		for line in (["LMB / Hold  Beam blast","RMB  Bouncing fireballs","E  Smoke Assault · C  Evade","Space  Jump","Shift  Sprint · Q  Fighters"] if id==14 else ["LMB / Hold  Guandao combo","RMB  Propeller bomb","Hold Space  Fly · Release  Descend","C  Evade · Shift  Boost"]):contents.add_child(label(line,14))
	elif id<=2:
		contents.add_child(label("Pipe master" if id==1 else "Firecaster",13,Color("aac3b6")))
		for line in (["LMB  Pipe combo","RMB  Heavy strike","C  Evade · E  Dash","R  Surge · T  Sky strike"] if id==1 else ["LMB  Fireballs","RMB  Giant fireball","C  Evade · E  Fire dodge","R  Blue surge · T  Meteors"]):contents.add_child(label(line,14))
	else:
		contents.add_child(label("%d HP · %s"%[data.maxHealth,data.weaponNames[0]],13,Color("aac3b6")))
		for slot in ["cutlass","flintlock","roll","drink"]:
			var key={"cutlass":"LMB","flintlock":"RMB" if forest_mode else "RMB / 3","roll":("E" if data.id in ["samurai","ninja","explorer","master-thief"] else "C"),"drink":"R"}[slot]
			var ability_name=str(data.abilities[slot].name)
			if slot=="roll" and data.id in ["samurai","ninja","explorer","master-thief"]:ability_name+=" · C Evade"
			var line=label("%s  %s"%[key,ability_name],14,tint if slot=="drink" else Color("d4e1df"))
			line.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS;contents.add_child(line)
			button.tooltip_text+="\n%s · %s"%[data.abilities[slot].name,data.abilities[slot].description.replace("RMB / 3:","RMB:" if forest_mode else "RMB / 3:")]
	return button

func _input(event):
	if not is_visible_in_tree() or event.is_echo():return
	if event.is_action_pressed("pause") or event.is_action_pressed("character_toggle"):
		get_viewport().set_input_as_handled();game.close_rogue_roster()
