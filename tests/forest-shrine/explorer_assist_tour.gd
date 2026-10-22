extends "res://tests/forest-shrine/explorer_close_assist_test.gd"
## A rendered check of the actual Explorer stroke beside a close side target.
func run():
	game=load("res://scenes/forest_shrine.tscn").instantiate();game.settings_path="user://explorer-tour.cfg";root.add_child(game);current_scene=game
	await frames(3);game.start_wave();game.model.waves.spawn_clock=10000;game.model.waves.pending=0
	game.set_physics_process(false);game.player.set_physics_process(false);game.camera_rig.set_process(false)
	game.tuning.invincible=true;game.tuning.critical_chance=0.0
	await fresh();var data=target(Vector3(1.5,0,-.2));var combat=game.player.active_ability
	combat.aim=ORIGIN+Vector3.FORWARD*20;combat.attack()
	game.camera_rig.camera.global_position=ORIGIN+Vector3(-5,4,7)
	game.camera_rig.camera.look_at(ORIGIN+Vector3(.6,1,0))
	game.forest_ui.message_left=0
	DirAccess.make_dir_recursive_absolute("res://docs/dense-crowd/explorer")
	for step in range(7):
		combat.tick(.01,false);game.crowd._process(.01)
		await process_frame;await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://docs/dense-crowd/explorer/%02d.png"%step)
	check(data.hp<10000,"Rendered Explorer stroke reaches the close side target")
	print("EXPLORER_ASSIST_TOUR failures=%d"%failures)
	await game.quit_clean();quit(1 if failures else 0)
