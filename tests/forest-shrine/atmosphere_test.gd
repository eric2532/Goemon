extends SceneTree
## Rendered regression: unknown woodland must draw, without granting enemy vision.
var game
var failures=0
var capture_dir="res://tests/forest-shrine"
func check(ok: bool,message: String):
	if not ok:failures+=1;printerr("FAIL: "+message)
func _initialize():call_deferred("run")
func frame_image()->Image:
	for i in range(4):await process_frame
	await RenderingServer.frame_post_draw
	return root.get_texture().get_image()
func capture(name_: String):
	var image=await frame_image()
	var prefix="before-" if "--before" in OS.get_cmdline_user_args() else ""
	check(image.save_png(capture_dir+"/atmosphere-"+prefix+name_+".png")==OK,"Rendered capture saves successfully: "+name_)
func run():
	if DisplayServer.get_name()=="headless":
		printerr("Atmosphere validation requires a rendered window");quit(1);return
	if OS.has_environment("FOREST_ATMOSPHERE_CAPTURE_DIR"):capture_dir=OS.get_environment("FOREST_ATMOSPHERE_CAPTURE_DIR")
	DirAccess.make_dir_recursive_absolute(capture_dir)
	game=load("res://scenes/forest_shrine.tscn").instantiate();root.add_child(game);current_scene=game
	await process_frame;await capture("preparation")
	game.preparation_size=240;game.update_preparation_camera();await capture("overview")
	game.start_wave();game.model.waves.spawn_clock=10000;game.tuning.invincible=true
	game.model.waves.spawn_one();var enemy=game.model.enemies.values().back()
	enemy.pos=Vector3(0,0,-108);enemy.stun=100;enemy.hp=10000;enemy.max_hp=10000
	game.model.update_vision(game.player.position);game.sync_enemies()
	# Freeze simulation and presentation input, keeping the real battle camera.
	paused=true;game.set_process(false);game.camera_rig.set_process(false);game.camera_rig.set_process_unhandled_input(false)
	game.crowd._process(0)
	game.forest_ui.message_left=0;game.forest_ui.sync()
	check(not game.model.explored_at(enemy.pos),"Forest raider starts on unexplored ground")
	check(not game.actors[enemy.id].visible,"Scenery beyond vision must not reveal a raider")
	check(game.crowd.batches.all(func(b):return b.multimesh.visible_instance_count==0),"Unseen raiders are absent from rendered crowd batches")
	var explored=game.model.explored.duplicate();var visible=game.model.visible_cells.duplicate()
	game.camera_rig.yaw=0;game.camera_rig.reset_follow();game.camera_rig._process(0)
	await capture("battle")
	var with_trees=await frame_image()
	var batches=game.world.find_children("*","MultiMeshInstance3D",false,false)
	for batch in batches:batch.hide()
	var without_trees=await frame_image()
	var changed=0
	# Exclude HUD borders; compare pixels with and without actual forest geometry.
	for y in range(with_trees.get_height()/5,with_trees.get_height()*4/5,2):
		for x in range(with_trees.get_width()/6,with_trees.get_width()*5/6,2):
			var a=with_trees.get_pixel(x,y);var b=without_trees.get_pixel(x,y)
			if absf(a.r-b.r)+absf(a.g-b.g)+absf(a.b-b.b)>.06:changed+=1
	check(changed>500,"Unexplored tree silhouettes are visible from the starting battle camera")
	print("FOREST_TREE_PIXELS ",changed)
	for batch in batches:batch.show()
	check(game.model.explored==explored and game.model.visible_cells==visible,"Showing woodland does not explore terrain or grant vision")
	for direction in range(1,4):
		game.camera_rig.yaw=direction*PI*.5;game.camera_rig.reset_follow();game.camera_rig._process(0)
		await capture("direction-%d"%direction)
	game.player.position=Vector3(0,.15,-84);game.model.update_vision(game.player.position);game.sync_enemies();game.world.sync(0);game.world.update_fog();game.crowd._process(0)
	check(game.actors[enemy.id].visible,"Raider becomes visible when the hero reaches its forest approach")
	check(game.crowd.batches.any(func(b):return b.multimesh.visible_instance_count>0),"Scouted raider appears in a rendered crowd batch")
	game.camera_rig.yaw=0;game.camera_rig.reset_follow();game.camera_rig._process(0);await capture("forest-edge")
	print("FOREST_ATMOSPHERE_RESULT failures=%d"%failures)
	await game.quit_clean()
	quit(1 if failures else 0)
