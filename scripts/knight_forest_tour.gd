extends SceneTree
## Render the real Knight in the latest four-enemy Forest scene.
var game
var output="res://docs/knight-integration/"
func _initialize():call_deferred("run")
func capture(label_: String):
	for i in 4:await process_frame
	await RenderingServer.frame_post_draw
	var error=root.get_texture().get_image().save_png(output+label_+".png")
	if error!=OK:push_error("Could not save Knight Forest capture");quit(1)
func run():
	if DisplayServer.get_name()=="headless":quit(1);return
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):output=arg.trim_prefix("--out=").path_join("")
	DirAccess.make_dir_recursive_absolute(output)
	root.size=Vector2i(1440,900)
	set_meta("forest_fighter",7)
	game=load("res://scenes/forest_shrine.tscn").instantiate();root.add_child(game);current_scene=game
	for i in 3:await physics_frame
	game.start_wave();game.set_physics_process(false);game.player.set_physics_process(false)
	game.model.waves.spawn_clock=100000;game.model.waves.pending=0
	game.player.position=Vector3(0,.15,50);game.player.active_ability.player.pos=game.player.position
	game.forest_ui.message_left=0
	for variant in range(4):
		var pos=[Vector3(-5,0,36),Vector3(7,0,34),Vector3(22,0,15),Vector3(3,0,26)][variant]
		var e=game.model.waves.spawn_enemy(variant,pos);e.facing=PI;e.stun=100
	for x in range(-20,21):
		for y in range(-20,21):game.model.visible_cells[Vector2i(x,y)]=true;game.model.explored[Vector2i(x,y)]=true
	game.sync_enemies();game.world.update_fog();game.camera_rig.set_process(false)
	var camera=game.camera_rig.camera
	camera.position=game.player.position+Vector3(4,4,12);camera.look_at(Vector3(0,2,36))
	game.player.model.actor.animate_pose({"grounded":true},1.0/30,0,0)
	await capture("forest-knight-and-new-enemies")
	for frame in 60:game.player.model.actor.animate_pose({"grounded":true,"motionSpeed":10.2,"localMotion":Vector3.BACK*10.2},1.0/30,frame/30.0,1)
	await capture("forest-knight-running")
	game.queue_free();paused=false
	for i in 3:await process_frame
	print("KNIGHT_FOREST_TOUR_RESULT captures=2 failures=0");quit()
