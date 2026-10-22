extends SceneTree

func _initialize():
	call_deferred("run")

func run():
	root.size=Vector2i(1200,1000)
	var scene=Node3D.new();root.add_child(scene)
	var world=WorldEnvironment.new();var env=Environment.new()
	env.background_mode=Environment.BG_COLOR;env.background_color=Color("263745")
	env.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.ambient_light_color=Color.WHITE;env.ambient_light_energy=.85
	world.environment=env;scene.add_child(world)
	var light=DirectionalLight3D.new();scene.add_child(light);light.rotation_degrees=Vector3(-30,-30,0);light.light_energy=1.25
	var fill=DirectionalLight3D.new();scene.add_child(fill);fill.rotation_degrees=Vector3(-20,155,0);fill.light_energy=.45
	var hero=HeroModel.new();hero.skin_id="ren";scene.add_child(hero);hero.rotation.y=.18
	hero.equipped=false;hero.pipe.hide();hero.set_process(false)
	hero.animate(.016,0,true,0,0,false,0,false);hero.sync_skeleton()
	var camera=Camera3D.new();scene.add_child(camera);camera.position=Vector3(0,1.55,-7);camera.look_at(Vector3(0,1.55,0));camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=3.4
	for i in range(12):await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://tests/goemon-skins/anime/front.png")
	hero.rotation.y=.65
	for i in range(4):await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://tests/goemon-skins/anime/three-quarter.png")
	hero.rotation.y=PI+.6
	for i in range(4):await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://tests/goemon-skins/anime/back.png")
	quit()
