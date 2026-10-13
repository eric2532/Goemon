extends Control
## Select a playable Rogue fighter without replacing the castle's ally rosters.
const Roster=preload("res://scripts/rogue_roster.gd")
var game: Node
var title_text="R O G U E   S I E G E   /   C H O O S E   Y O U R   F I G H T E R"
var start_hint="Choose a fighter to begin. Pick an upgrade card before each wave."
var back_text="Q / Esc · Back to battle"

func label(words: String,point_size: int,tint: Color=Color("eaf1ed"))->Label:
	var node=Label.new();node.text=words
	node.add_theme_font_size_override("font_size",point_size)
	node.add_theme_color_override("font_color",tint)
	node.mouse_filter=Control.MOUSE_FILTER_IGNORE
	return node

func _ready():
	process_mode=Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shade=ColorRect.new();shade.color=Color(.015,.06,.10,.40)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);shade.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(shade)
	var center=CenterContainer.new();center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);add_child(center)
	var layout=VBoxContainer.new();layout.custom_minimum_size.x=1260;layout.add_theme_constant_override("separation",10);center.add_child(layout)
	layout.add_child(label(title_text,29,Color("f1d198")))
	layout.add_child(label("Goemon and all ten Rogue fighters. Original weapons, movement abilities, and signature skills.",18,Color("c0d4d5")))
	var goemon=goemon_card(layout)
	var grid=GridContainer.new();grid.columns=5;grid.add_theme_constant_override("h_separation",12);grid.add_theme_constant_override("v_separation",12);layout.add_child(grid)
	var selected: Button=goemon if game.selected_rogue_id==1 else null
	for id in Roster.ids():
		var data=Roster.data(id)
		var tint=Color(data.color)
		var button=Button.new();button.name="RogueFighter_"+data.id
		button.custom_minimum_size=Vector2(242,300);button.mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND
		var style=StyleBoxFlat.new();style.bg_color=Color("142c36");style.border_color=Color(tint,.5);style.set_border_width_all(1);style.set_corner_radius_all(10)
		if id==game.selected_rogue_id:style.border_color=tint;style.set_border_width_all(2)
		var hover=style.duplicate();hover.bg_color=Color("25434b");hover.border_color=tint;hover.set_border_width_all(2)
		button.add_theme_stylebox_override("normal",style)
		for state in ["hover","focus","pressed"]:button.add_theme_stylebox_override(state,hover)
		button.pressed.connect(game.choose_rogue_character.bind(id));grid.add_child(button)
		button.tooltip_text=data.description
		var contents=VBoxContainer.new();contents.mouse_filter=Control.MOUSE_FILTER_IGNORE
		contents.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);contents.offset_left=12;contents.offset_right=-12;contents.offset_top=10;contents.offset_bottom=-10;contents.add_theme_constant_override("separation",4);button.add_child(contents)
		var portrait=TextureRect.new();portrait.mouse_filter=Control.MOUSE_FILTER_IGNORE
		portrait.custom_minimum_size=Vector2(218,104);portrait.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;portrait.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;portrait.texture=Roster.portrait(id);contents.add_child(portrait)
		contents.add_child(label(data.name,22,tint))
		contents.add_child(label("%d HP   ·   %s" % [data.maxHealth,data.title],11,Color("c4d4d5")))
		for slot in ["cutlass","flintlock","roll","drink"]:
			var key={"cutlass":"LMB","flintlock":"RMB","roll":"C / E","drink":"R"}[slot]
			var line=label("%s   %s" % [key,data.abilities[slot].name],14,tint if slot=="drink" else Color("d4e1df"))
			contents.add_child(line)
			button.tooltip_text+="\n%s · %s" % [data.abilities[slot].name,data.abilities[slot].description.replace("Proposed skill: ","")]
		if id==game.selected_rogue_id:selected=button
	var footer=HBoxContainer.new();footer.add_theme_constant_override("separation",22);layout.add_child(footer)
	var back=Button.new();back.name="RogueRosterClose";back.text="Esc · Back" if game.rogue_pick_start else back_text;back.custom_minimum_size=Vector2(270,44);back.pressed.connect(game.close_rogue_roster);footer.add_child(back)
	footer.add_child(label("WASD move · Mouse aim · Space jump · Shift sprint\n"+(start_hint if game.rogue_pick_start else "Time is paused. Switching keeps your health percentage and ability cooldowns."),15,Color("a9c3c4")))
	if selected!=null:selected.grab_focus()

func goemon_card(parent: Control)->Button:
	var button=Button.new();button.name="RogueFighter_goemon"
	button.custom_minimum_size=Vector2(1260,80);button.mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND
	parent.add_child(button)
	var style=StyleBoxFlat.new();style.bg_color=Color("142c36");style.border_color=Color("bf9b50")
	style.set_border_width_all(2 if game.selected_rogue_id==1 else 1);style.set_corner_radius_all(10)
	var hover=style.duplicate();hover.bg_color=Color("25434b");hover.border_color=Color("f1d198");hover.set_border_width_all(2)
	button.add_theme_stylebox_override("normal",style)
	for state in ["hover","focus","pressed"]:button.add_theme_stylebox_override(state,hover)
	button.pressed.connect(game.choose_rogue_character.bind(1))
	button.tooltip_text="Goemon's full moveset, with Magic Swordsman's timing and impact feel on his three-hit pipe combo.\n1 Spin · 2 Coins · 3 Sweep · 4 Red cloak · 5 Gold cloak · T Sky strike"
	var title=label("GOEMON",24,Color("f1d198"));title.position=Vector2(128,8);button.add_child(title)
	var subtitle=label("Original adventurer · Full moveset",16);subtitle.position=Vector2(128,43);button.add_child(subtitle)
	var attacks=label("LMB · Three-hit pipe combo   /   RMB · Heavy swing",18);attacks.position=Vector2(655,10);button.add_child(attacks)
	var abilities=label("C · Evade   E · Dash   R · Golden surge   T · Sky strike",16,Color("f1d198"));abilities.position=Vector2(655,44);button.add_child(abilities)
	# Show the equipped Goemon skin using the existing game model.
	var container=SubViewportContainer.new();container.position=Vector2(12,4);container.size=Vector2(100,72)
	container.stretch=true;container.mouse_filter=Control.MOUSE_FILTER_IGNORE;button.add_child(container)
	var viewport=SubViewport.new();viewport.size=Vector2i(100,72);viewport.own_world_3d=true
	viewport.transparent_bg=true;viewport.render_target_update_mode=SubViewport.UPDATE_ONCE;container.add_child(viewport)
	var world_environment=WorldEnvironment.new();var environment=Environment.new()
	environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;environment.ambient_light_color=Color.WHITE;environment.ambient_light_energy=.8
	world_environment.environment=environment;viewport.add_child(world_environment)
	var light=DirectionalLight3D.new();light.rotation_degrees=Vector3(-35,-30,0);light.light_energy=1.4;viewport.add_child(light)
	var preview=HeroModel.new();preview.skin_id=game.settings.goemon_skin;viewport.add_child(preview)
	preview.rotation.y=-.12;preview.equipped=false;preview.pipe.hide();preview.set_process(false)
	preview.animate(.016,0,true,0,0,false,0,false);preview.sync_skeleton()
	var camera=Camera3D.new();viewport.add_child(camera);camera.position=Vector3(0,1.85,-8)
	camera.look_at(Vector3(0,1.75,0));camera.projection=Camera3D.PROJECTION_ORTHOGONAL
	camera.keep_aspect=Camera3D.KEEP_HEIGHT;camera.size=4.05;camera.current=true
	return button

func _input(event):
	if not is_visible_in_tree() or event.is_echo():return
	if event.is_action_pressed("pause") or event.is_action_pressed("character_toggle"):
		get_viewport().set_input_as_handled();game.close_rogue_roster()
