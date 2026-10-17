extends SceneTree
var game
var giant: Dictionary
var wall: Dictionary
var failures=0
var output="res://docs/enemy-concepts/runtime-v01/"
func _initialize():call_deferred("run")
func check(ok: bool,words: String):
	if not ok:failures+=1;printerr("FAIL: "+words)
func run():
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--capture-dir="):output=argument.trim_prefix("--capture-dir=").trim_suffix("/")+"/"
	DirAccess.make_dir_recursive_absolute(output)
	game=load("res://scenes/forest_shrine.tscn").instantiate();root.add_child(game);current_scene=game
	await process_frame;await process_frame
	wall=game.model.build("wall",Vector2i(-3,5),0);game.world.sync(0)
	game.model.wave=2;game.start_wave();game.set_physics_process(false);game.model.waves.pending=0;game.model.waves.giant_pending=false
	AudioServer.set_bus_mute(0,true);game.forest_ui.message_left=0
	game.player.position=Vector3(-12,.15,40)
	giant=game.model.waves.spawn_enemy(2,Vector3(0,0,42));giant.facing=0.0
	game.sync_enemies();game.model.update_vision(game.player.position);game.world.update_fog()
	game.camera_rig.set_process(false);game.camera_rig.camera.position=Vector3(-15,14,12);game.camera_rig.camera.look_at(Vector3(0,9,42))
	step(.1)
	check(giant.action=="windup" and giant.target_id==wall.id,"Live giant starts windup against the selected wall")
	for i in range(9):step(.1);await process_frame
	check(wall.hp==300,"Live giant does not damage the wall before contact")
	await capture("actual-windup")
	while giant.action=="windup":step(.05);await process_frame
	check(wall.hp==180 and giant.action=="recover","Live giant applies one120HP wall hit at contact")
	await capture("actual-contact")
	var actor=game.actors[giant.id];actor.freeze_for(.75)
	var left: float=giant.action_left
	step(.3);await process_frame
	check(giant.action_left==left,"Live hero freeze preserves giant recovery")
	await capture("actual-frozen")
	# Actual Archer flight against a healthy worker; dispatch its real model events.
	var worker=game.model.workers.values()[0];worker.pos=Vector3(0,0,56);worker.state="idle";worker.job=-1
	var archer=game.model.waves.spawn_enemy(1,Vector3(-18,0,56));archer.facing=-PI*.5
	game.sync_enemies();game.model.update_vision(game.player.position)
	for i in range(19):step(.05);await process_frame
	check(not game.model.waves.projectiles.is_empty(),"Live Archer has a traveling projectile")
	game.camera_rig.camera.position=Vector3(-20,10,80);game.camera_rig.camera.look_at(Vector3(-9,2,56))
	await capture("actual-archer-flight")
	for i in range(16):step(.05);await process_frame
	check(worker.hp<worker.max_hp,"Live Archer projectile damages its worker target")
	game.queue_free();paused=false;await process_frame;await create_timer(.25).timeout
	print("FOREST_ENEMY_BEHAVIOR_RESULT failures=%d"%failures);quit(1 if failures else 0)
func step(delta: float):
	game.model.waves.tick(delta,game.player.position)
	for event in game.model.events:
		if event.kind=="enemy_arrow":game.enemy_arrows.launch(event)
		elif event.kind=="enemy_arrow_impact":game.enemy_arrows.impact(event)
	game.model.events.clear();game.sync_enemies();game.world.sync(0)
func capture(label: String):
	for i in range(3):await process_frame
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(output+label+".png")==OK,"Native gameplay screenshot saves successfully")
