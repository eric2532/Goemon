extends Control
## Select a playable Rogue fighter without replacing the castle's ally rosters.
const Roster=preload("res://scripts/rogue_roster.gd")
var game: Node

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
	layout.add_child(label("F I R E   S I E G E   /   C H O O S E   Y O U R   H E R O",29,Color("f1d198")))
	layout.add_child(label("Goemon, Edo and ten Rogue heroes. Shared controls, original combat skills.",18,Color("c0d4d5")))
	var originals=HBoxContainer.new();originals.add_theme_constant_override("separation",12);layout.add_child(originals)
	var goemon=original_card(originals,1)
	var edo=original_card(originals,2)
	var grid=GridContainer.new();grid.columns=5;grid.add_theme_constant_override("h_separation",12);grid.add_theme_constant_override("v_separation",12);layout.add_child(grid)
	var selected: Button=goemon if game.selected_rogue_id==1 else (edo if game.selected_rogue_id==2 else null)
	for id in Roster.ids():
		var data=Roster.data(id)
		var tint=Color(data.color)
		var button=Button.new();button.name="RogueFighter_"+data.id
		button.custom_minimum_size=Vector2(242,282);button.mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND
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
		portrait.custom_minimum_size=Vector2(218,90);portrait.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;portrait.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;portrait.texture=Roster.portrait(id);contents.add_child(portrait)
		contents.add_child(label(data.name,22,tint))
		contents.add_child(label("%d HP   ·   %s" % [data.maxHealth,data.title],11,Color("c4d4d5")))
		for slot in ["cutlass","flintlock","roll","drink"]:
			var key={"cutlass":"LMB","flintlock":"RMB / 3","roll":("E" if data.id in ["samurai","ninja","explorer","master-thief"] else "C"),"drink":"R"}[slot]
			var line=label("%s   %s" % [key,data.abilities[slot].name],14,tint if slot=="drink" else Color("d4e1df"))
			contents.add_child(line)
			button.tooltip_text+="\n%s · %s" % [data.abilities[slot].name,data.abilities[slot].description.replace("Proposed skill: ","").replace("at the cursor","forward").replace("toward the cursor","forward")]
		if data.id in ["explorer","master-thief"]:contents.add_child(label("C   Evade",14,Color("d4e1df")))
		if id==game.selected_rogue_id:selected=button
	var footer=HBoxContainer.new();footer.add_theme_constant_override("separation",22);layout.add_child(footer)
	var back=Button.new();back.name="RogueRosterClose";back.text="Esc · Back" if game.rogue_pick_start else "Q / Esc · Back to battle";back.custom_minimum_size=Vector2(270,44);back.pressed.connect(game.close_rogue_roster);footer.add_child(back)
	var start_hint="Choose a hero to begin. Stand nearby to build, then hold Y to launch a wave." if game.roster_start_mode=="defense" else "Choose a hero to begin, then pick your first upgrade card."
	footer.add_child(label("WASD move · Mouse camera · Space jump · Shift sprint\n"+(start_hint if game.rogue_pick_start else "Time is paused. Switching keeps your health percentage and ability cooldowns."),15,Color("a9c3c4")))
	if selected!=null:selected.grab_focus()

func original_card(parent: Control,id: int)->Button:
	var button=Button.new();button.name="RogueFighter_goemon" if id==1 else "RogueFighter_edo"
	button.custom_minimum_size=Vector2(624,104);button.mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND
	parent.add_child(button)
	var style=StyleBoxFlat.new();style.bg_color=Color("142c36");style.border_color=Color("bf9b50")
	style.set_border_width_all(2 if game.selected_rogue_id==id else 1);style.set_corner_radius_all(10)
	var hover=style.duplicate();hover.bg_color=Color("25434b");hover.border_color=Color("f1d198");hover.set_border_width_all(2)
	button.add_theme_stylebox_override("normal",style)
	for state in ["hover","focus","pressed"]:button.add_theme_stylebox_override(state,hover)
	button.pressed.connect(game.choose_rogue_character.bind(id))
	var title=label("GOEMON" if id==1 else "EDO · FIRECASTER",24,Color("f1d198"));title.position=Vector2(18,8);button.add_child(title)
	var attacks=label("LMB · Pipe combo   RMB · Heavy" if id==1 else "LMB · Fireballs   RMB · Giant fireball",16);attacks.position=Vector2(18,42);button.add_child(attacks)
	var abilities=label("C Evade · E Dash · R Surge · T Sky strike" if id==1 else "C Evade · E Fire dodge · R Blue surge · T Meteors",14,Color("d4e1df"));abilities.position=Vector2(18,72);button.add_child(abilities)
	button.tooltip_text="Camera-facing attacks. Original moveset and numbered abilities preserved."
	return button

func _input(event):
	if not is_visible_in_tree() or event.is_echo():return
	if event.is_action_pressed("pause") or event.is_action_pressed("character_toggle"):
		get_viewport().set_input_as_handled();game.close_rogue_roster()
