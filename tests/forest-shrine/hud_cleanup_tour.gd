extends SceneTree
var game
var capture_dir="res://tests/forest-shrine/hud-cleanup"
func _initialize():run.call_deferred()
func run():
	if OS.has_environment("FOREST_HUD_CAPTURE_DIR"):capture_dir=OS.get_environment("FOREST_HUD_CAPTURE_DIR")
	DirAccess.make_dir_recursive_absolute(capture_dir)
	game=load("res://scenes/forest_shrine.tscn").instantiate();root.add_child(game);current_scene=game
	await process_frame;await process_frame;AudioServer.set_bus_mute(0,true)
	game.forest_ui.message_left=0;await capture("preparation")
	game.player.select_character(7);game.start_wave();game.model.waves.spawn_clock=100000
	game.set_physics_process(false);game.player.set_physics_process(false)
	game.player.position=Vector3(3,.15,54);game.player.hp=62
	game.camera_rig.yaw=PI;game.camera_rig.reset_follow();game.camera_rig._process(0)
	game.forest_ui.message_left=0;await capture("combat-knight")
	game.player.select_character(2);game.forest_ui.sync();await capture("combat-edo")
	game.player.select_character(10);game.forest_ui.sync();await capture("combat-ranger")
	print("FOREST_HUD_TOUR_RESULT captures=4")
	await game.quit_clean()
func capture(label: String):
	for i in range(20):await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(capture_dir+"/"+label+".png")
