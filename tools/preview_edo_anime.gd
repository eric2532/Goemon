extends SceneTree

func _initialize():call_deferred("run")

func run():
	root.size=Vector2i(1440,1000)
	var scene=Node3D.new();root.add_child(scene)
	var world=WorldEnvironment.new();var env=Environment.new()
	env.background_mode=Environment.BG_COLOR;env.background_color=Color("233542")
	env.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.ambient_light_color=Color.WHITE;env.ambient_light_energy=.7
	world.environment=env;scene.add_child(world)
	var light=DirectionalLight3D.new();scene.add_child(light);light.rotation_degrees=Vector3(-30,-30,0);light.light_energy=1.25
	var fill=DirectionalLight3D.new();scene.add_child(fill);fill.rotation_degrees=Vector3(-20,155,0);fill.light_energy=.45
	var heroes=[]
	for i in range(2):
		var hero=MusashiModel.new();scene.add_child(hero)
		var old=hero.rig_visual
		var path="res://assets/characters/musashi/preview/edo_posture_shoulders_v05.glb" if i==0 else "res://assets/models/characters/edo_anime.glb"
		hero.rig_visual=load(path).instantiate();hero.body.add_child(hero.rig_visual);old.queue_free()
		if i==0:load("res://assets/characters/musashi/materials/palette_v05.gd").apply(hero.rig_visual)
		elif ResourceLoader.exists("res://assets/characters/musashi/materials/anime_palette.gd"):
			load("res://assets/characters/musashi/materials/anime_palette.gd").apply(hero.rig_visual)
		hero.skeleton=hero.rig_visual.find_child("Skeleton3D",true,false)
		hero.locomotion=load("res://assets/characters/musashi/animations/relaxed_idle_v05.gd").new(hero)
		hero.position.x=.77 if i==0 else -.77;hero.set_process(false)
		for frame in 45:hero.animate(.016,0,true,0,0,false,0,false)
		heroes.append(hero)
	var camera=Camera3D.new();scene.add_child(camera);camera.position=Vector3(0,1.30,-8)
	camera.look_at(Vector3(0,1.16,0));camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=2.65
	var ui=CanvasLayer.new();scene.add_child(ui)
	for i in range(2):
		var label=Label.new();label.text="EDO · BEFORE" if i==0 else "EDO · ANIME REVAMP"
		label.position=Vector2(285+i*710,852);label.add_theme_font_size_override("font_size",25);ui.add_child(label)
	for view in ["front","three-quarter","back"]:
		for hero in heroes:hero.rotation.y={"front":.0,"three-quarter":.58,"back":PI+.3}[view]
		for frame in range(8):await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://tests/edo-anime/"+view+".png")
	quit()
