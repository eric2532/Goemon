extends SceneTree
var game
var capture_dir="res://tests/forest-shrine/starter-fort"
func _initialize():run.call_deferred()
func run():
	if OS.has_environment("FOREST_FORT_CAPTURE_DIR"):capture_dir=OS.get_environment("FOREST_FORT_CAPTURE_DIR")
	DirAccess.make_dir_recursive_absolute(capture_dir)
	game=load("res://scenes/forest_shrine.tscn").instantiate();root.add_child(game);current_scene=game
	await process_frame;await process_frame;AudioServer.set_bus_mute(0,true)
	game.forest_ui.message_left=0
	for i in range(30):await process_frame
	await capture("preparation")
	await measure("preparation")
	game.start_wave();game.model.waves.spawn_clock=100000;game.set_physics_process(false);game.player.set_physics_process(false)
	game.player.position=Vector3(3,.15,54);game.model.hero_position=game.player.position
	game.camera_rig.yaw=0;game.camera_rig.reset_follow();game.camera_rig._process(0)
	await capture("outside-gate")
	await measure("battle")
	game.player.position=Vector3(3,.15,35);game.model.hero_position=game.player.position
	game.camera_rig.yaw=PI;game.camera_rig.reset_follow();game.camera_rig._process(0)
	await capture("inside-gate")
	await game.quit_clean();quit()
func capture(label: String):
	for i in range(20):await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(capture_dir+"/"+label+".png")
func measure(label: String):
	var times=[];var last=Time.get_ticks_usec()
	for i in range(120):
		await process_frame
		var now=Time.get_ticks_usec();times.append((now-last)/1000.0);last=now
	times.sort();print("STARTER_FORT_FRAME stage=",label," median_ms=",times[60]," p95_ms=",times[114]," max_ms=",times.back()," draws=",Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)," primitives=",Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
