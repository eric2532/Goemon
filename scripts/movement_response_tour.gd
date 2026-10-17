extends "res://scripts/movement_response_tests.gd"
## Captures the actual player controller at 60 physics steps / 30 video frames.
func run():
	if DisplayServer.get_name()=="headless":quit(1);return
	await setup_game()
	root.size=Vector2i(1280,720);root.content_scale_size=root.size
	game.world.hide();game.ui.hide();game.player.select_character(1);reset_body()
	var plane=MeshInstance3D.new();plane.mesh=PlaneMesh.new();plane.mesh.size=Vector2(100,100)
	plane.position.y=100;root.add_child(plane)
	var mat=StandardMaterial3D.new();mat.albedo_color=Color("586b62");plane.material_override=mat
	for i in range(-15,16):
		Geo.box(floor_,Vector3(0,100.008,i*2),Vector3(70,.01,.045),Geo.mat("8caa9a"))
	var light=DirectionalLight3D.new();root.add_child(light);light.rotation_degrees=Vector3(-55,-35,0);light.light_energy=1.3;light.shadow_enabled=true
	var label_=Label.new();root.add_child(label_);label_.position=Vector2(32,28);label_.add_theme_font_size_override("font_size",24)
	var out="res://build/smooth-movement/frames"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out))
	for frame in range(120):
		var direction_=Vector2.ZERO
		var action_="IDLE"
		if frame>=15 and frame<45:direction_=Vector2(0,-1);action_="START / RUN"
		elif frame>=45 and frame<66:direction_=Vector2(1,0);action_="TURN RIGHT"
		elif frame>=66 and frame<86:direction_=Vector2(0,1);action_="REVERSE"
		elif frame>=86:action_="STOP / IDLE"
		for i in range(2):step(direction_);game.player.model.sync_skeleton()
		var camera=game.camera_rig.camera
		camera.global_position=game.player.position+Vector3(5,3.8,7)
		camera.look_at(game.player.position+Vector3.UP*1.6)
		label_.text="SMOOTHER MOVEMENT  ·  %s  ·  %.1f units/s"%[action_,speed().length()]
		await process_frame
		RenderingServer.force_draw(false)
		root.get_texture().get_image().save_png(out.path_join("%03d.png"%frame))
	game.queue_free();current_scene=null;paused=false
	await create_timer(.4).timeout
	print("MOVEMENT_RESPONSE_TOUR frames=120 simulation_fps=60 playback_fps=30")
	quit(0)
