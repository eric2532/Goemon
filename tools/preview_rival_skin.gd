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
		var hero=HeroModel.new();hero.skin_id="original" if i==0 else "ren";scene.add_child(hero)
		hero.position.x=1.45 if i==0 else -1.45;hero.rotation.y=.08
		hero.equipped=false;hero.pipe.hide();hero.set_process(false)
		hero.animate(.016,0,true,0,0,false,0,false);hero.sync_skeleton();heroes.append(hero)
	var camera=Camera3D.new();scene.add_child(camera);camera.position=Vector3(0,1.9,-8)
	camera.look_at(Vector3(0,1.75,0));camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=4.1
	var ui=CanvasLayer.new();scene.add_child(ui)
	for i in range(2):
		var label=Label.new();label.text="GOEMON · ORIGINAL" if i==0 else "REN · STORM RIVAL"
		label.position=Vector2(240+i*720,852);label.add_theme_font_size_override("font_size",24);ui.add_child(label)
	for view in ["front","three-quarter","back","gold"]:
		for hero in heroes:
			hero.rotation.y={"front":.08,"three-quarter":.65,"back":PI+.4,"gold":.08}[view]
			hero.set_surge(view=="gold")
		for frame in range(8):await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://tests/goemon-skins/rival/"+view+".png")
	quit()
