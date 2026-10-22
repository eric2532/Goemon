extends SceneTree

func _initialize():call_deferred("run")
func run():
	root.size=Vector2i(1440,900)
	var scene=Node3D.new();root.add_child(scene)
	var world=WorldEnvironment.new();var env=Environment.new()
	env.background_mode=Environment.BG_COLOR;env.background_color=Color("233542")
	env.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.ambient_light_color=Color.WHITE;env.ambient_light_energy=.7
	world.environment=env;scene.add_child(world)
	var light=DirectionalLight3D.new();scene.add_child(light);light.rotation_degrees=Vector3(-30,-30,0);light.light_energy=1.25
	var fill=DirectionalLight3D.new();scene.add_child(fill);fill.rotation_degrees=Vector3(-20,155,0);fill.light_energy=.45
	for i in 3:
		var hero=HeroModel.new() if i==0 else MusashiModel.new()
		scene.add_child(hero);hero.position.x=2.0-i*2.0;hero.set_process(false)
		if i==0:hero.equipped=false;hero.pipe.hide()
		if i==1:hero.rig_visual.scale=Vector3.ONE
		for frame in 45:hero.animate(.016,0,true,0,0,false,0,false)
	var camera=Camera3D.new();scene.add_child(camera);camera.position=Vector3(0,1.55,-10)
	camera.look_at(Vector3(0,1.55,0));camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=4.05
	var ui=CanvasLayer.new();scene.add_child(ui)
	for i in 3:
		var label=Label.new();label.text=["GOEMON","EDO · BEFORE","EDO · 20% BIGGER"][i]
		label.position=Vector2(170+i*455,822);label.add_theme_font_size_override("font_size",24);ui.add_child(label)
	for frame in 8:await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://tests/edo-anime/size-comparison.png")
	quit()
