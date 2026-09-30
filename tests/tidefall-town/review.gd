extends SceneTree
var game
var prefix=""
func _initialize():call_deferred("run")
func run():
	game=load("res://scenes/main.tscn").instantiate();root.add_child(game)
	await process_frame
	game.smoke_test=true;game.start_game();game.encounters.set_physics_process(false)
	game.player.smoke_mode=true;game.player.set_physics_process(false)
	game.camera_rig.set_process_unhandled_input(false);game.tuning.freeze_ai=true
	if "--before" in OS.get_cmdline_user_args():
		prefix="before-"
		game.world.free()
		game.world=load("res://tests/tidefall-town/baseline/world.gd").new()
		game.world.generation_seed=90824
		game.add_child(game.world)
		WorldExpansion.walls(game.world,Geo.mat("405d68"))
	game.world.set_process(false)
	var views=[["spawn",Vector3(0,0,41),0.0],["market",Vector3(-2,0,20),0.0],["square",Vector3(-2,0,1),0.0],["bridge",Vector3(13,0,-8),-PI/2],["waterfront",Vector3(47.5,0,33),0.0],["residences",Vector3(-52,0,34),PI/2],["temple",Vector3(-10,0,-18),0.0]]
	for v in views:
		game.player.position=v[1];game.player.position.y=game.world.height_at(v[1].x,v[1].z)+.2
		game.camera_rig.yaw=v[2];game.camera_rig.reset_follow();game.hud.banner_time=0
		for i in range(12):await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://tests/tidefall-town/"+prefix+v[0]+".png")
		print("TOWN_CAPTURE ",v[0]," camera_distance=",game.camera_rig.current_distance)
	print("TOWN_REVIEW_COMPLETE")
	game.quit_clean()
