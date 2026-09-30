extends SceneTree
func _initialize():call_deferred("run")
func run():
	root.size=Vector2i(1280,800)
	var variants=["timber_house","noren_shop","two_story_inn","corner_house","plaster_storehouse"]
	var viewports=[]
	var bg=ColorRect.new();bg.color=Color("202c39");bg.size=Vector2(1280,800);root.add_child(bg)
	for i in range(variants.size()):
		var container=SubViewportContainer.new();container.position=Vector2((i%3)*426,(i/3)*390);root.add_child(container)
		var viewport=SubViewport.new();viewport.size=Vector2i(420,350);viewport.own_world_3d=true;container.add_child(viewport);viewports.append(viewport)
		var world=Node3D.new();viewport.add_child(world)
		var env=WorldEnvironment.new();env.environment=Environment.new();env.environment.background_mode=Environment.BG_COLOR;env.environment.background_color=Color("bddee0");env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.environment.ambient_light_color=Color.WHITE;env.environment.ambient_light_energy=.65;world.add_child(env)
		var sun=DirectionalLight3D.new();sun.rotation_degrees=Vector3(-45,-25,0);sun.light_energy=1.1;world.add_child(sun)
		GameAssets.place(world,"town/"+variants[i],Vector3.ZERO)
		var camera=Camera3D.new();camera.position=Vector3(12,10,17);world.add_child(camera);camera.look_at(Vector3(0,3,0));camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=15;camera.current=true
		var label=Label.new();label.text="town/"+variants[i];label.position=container.position+Vector2(12,355);label.add_theme_font_size_override("font_size",20);root.add_child(label)
	for i in range(12):await process_frame
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://docs/tidefall-town")
	root.get_texture().get_image().save_png("res://docs/tidefall-town/kit-contact-sheet.png")
	for i in range(variants.size()):viewports[i].get_texture().get_image().save_png("res://docs/tidefall-town/"+variants[i]+".png")
	print("TOWN_KIT_CAPTURE_COMPLETE")
	quit()
