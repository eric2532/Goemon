extends Control

var game: Node
var from_pause=false
var cards: Array[Dictionary]=[]
var status: Label

func _ready():
	process_mode=Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var backdrop=ColorRect.new();backdrop.color=Color(0.015,.045,.065,.94)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(backdrop)
	game.label_at(self,"PLAYABLE SKINS",Vector2(92,72),40)
	game.label_at(self,"GOEMON  /  CHOOSE YOUR LOOK",Vector2(96,129),18,Color("dfc384"))
	game.label_at(self,"Classic adventurer or storm rival. Your choice.",Vector2(96,163),19)
	for i in range(HeroSkins.CATALOG.size()):
		make_card(HeroSkins.CATALOG[i],Vector2(96+i*624,214))
	var surge=CheckButton.new()
	surge.name="SkinSurgePreview";surge.text="Preview Golden Surge"
	surge.position=Vector2(924,735);surge.add_theme_font_size_override("font_size",19)
	add_child(surge)
	surge.toggled.connect(func(enabled):
		for card in cards:card.preview.set_surge(enabled))
	status=game.label_at(self,"",Vector2(96,739),18,Color("dfc384"))
	game.label_at(self,"Cosmetic only · Weapons, abilities and cloak stay the same. Selection is saved.",Vector2(96,782),16)
	game.button_at(self,"Back to Settings",Vector2(96,823),func():game.show_settings(from_pause),300)
	refresh()
	for card in cards:
		if not card.button.disabled:card.button.grab_focus()

func make_card(entry: Dictionary,origin: Vector2):
	var panel=Panel.new();panel.position=origin;panel.size=Vector2(584,493)
	var style=StyleBoxFlat.new();style.bg_color=Color("102c39")
	style.border_color=Color("55666b");style.set_border_width_all(1);style.set_corner_radius_all(12)
	panel.add_theme_stylebox_override("panel",style);add_child(panel)
	var container=SubViewportContainer.new();container.position=Vector2(12,12);container.size=Vector2(560,302)
	container.stretch=true;container.mouse_filter=Control.MOUSE_FILTER_IGNORE;panel.add_child(container)
	var viewport=SubViewport.new();viewport.size=Vector2i(560,302)
	viewport.own_world_3d=true;viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	viewport.msaa_3d=Viewport.MSAA_2X;container.add_child(viewport)
	var environment=WorldEnvironment.new();var env=Environment.new()
	env.background_mode=Environment.BG_COLOR;env.background_color=Color("102c39")
	env.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.ambient_light_color=Color.WHITE;env.ambient_light_energy=.7
	env.tonemap_mode=Environment.TONE_MAPPER_LINEAR;environment.environment=env;viewport.add_child(environment)
	var light=DirectionalLight3D.new();light.rotation_degrees=Vector3(-35,-30,0);light.light_energy=1.4;viewport.add_child(light)
	var fill=DirectionalLight3D.new();fill.rotation_degrees=Vector3(-20,145,0);fill.light_energy=.6;viewport.add_child(fill)
	var preview=HeroModel.new();preview.skin_id=entry.id;viewport.add_child(preview)
	preview.rotation.y=-.12;preview.equipped=false;preview.pipe.hide();preview.set_process(false)
	preview.animate(.016,0,true,0,0,false,0,false);preview.sync_skeleton()
	var camera=Camera3D.new();viewport.add_child(camera);camera.position=Vector3(0,1.85,-8)
	camera.look_at(Vector3(0,1.75,0));camera.projection=Camera3D.PROJECTION_ORTHOGONAL
	camera.keep_aspect=Camera3D.KEEP_HEIGHT;camera.size=4.05;camera.current=true
	game.label_at(panel,entry.name,Vector2(24,324),25)
	game.label_at(panel,entry.subtitle,Vector2(24,359),17,Color("dfc384"))
	var description=game.label_at(panel,entry.description,Vector2(24,392),16)
	description.size=Vector2(530,40);description.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	var button=game.button_at(panel,"Use this skin",Vector2(24,438),func():select_skin(entry.id),536)
	button.add_theme_color_override("font_disabled_color",Color("f1c767"))
	var equipped_style=StyleBoxFlat.new();equipped_style.bg_color=Color("203e49")
	equipped_style.content_margin_left=20;button.add_theme_stylebox_override("disabled",equipped_style)
	button.name="SelectSkin_"+entry.id;button.size.y=43
	cards.append({"id":entry.id,"button":button,"style":style,"preview":preview})

func select_skin(id: String):
	game.select_goemon_skin(id)
	refresh()

func refresh():
	for card in cards:
		var selected=game.settings.goemon_skin==card.id
		card.button.text="✓  Equipped" if selected else "Use this skin"
		card.button.disabled=selected
		if selected:card.button.release_focus()
		card.style.border_color=Color("f1c767") if selected else Color("55666b")
		card.style.set_border_width_all(2 if selected else 1)
	status.text="Equipped: "+HeroSkins.CATALOG[1 if game.settings.goemon_skin=="ren" else 0].name
