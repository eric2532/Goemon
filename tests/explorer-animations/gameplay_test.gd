extends "res://tests/forest-shrine/explorer_close_assist_test.gd"
func capture(label_: String):
	if DisplayServer.get_name()=="headless":return
	game.camera_rig.camera.global_position=game.player.global_position+Vector3(5,2.8,7)
	game.camera_rig.camera.look_at(game.player.global_position+Vector3(0,1.1,0))
	await process_frame;await process_frame;await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://tests/explorer-animations/"+label_+".png")
func run():
	if "--packaged" in OS.get_cmdline_user_args():
		check(not FileAccess.file_exists("res://tools/export_explorer_animations.py") and FileAccess.file_exists("res://assets/animations/explorer_approved.json"),"Real gameplay test uses packaged animation resources")
	game=load("res://scenes/forest_shrine.tscn").instantiate();game.settings_path="user://explorer-animation-%d.cfg"%OS.get_process_id()
	root.add_child(game);current_scene=game
	await frames(3);game.start_wave();game.model.waves.spawn_clock=10000;game.model.waves.pending=0
	game.set_physics_process(false);game.player.set_physics_process(false);game.camera_rig.set_process(false)
	game.tuning.invincible=true;game.tuning.critical_chance=0.0
	await fresh(11)
	var c=game.player.active_ability;var actor=c.visual_actor
	actor.reset_motion();c._animate(0,0)
	var motion=actor.cosplay_rig.get("explorer_motion")
	check(c.class_id=="explorer" and motion!=null,"Real Explorer kit has approved movement")
	if motion==null:quit(1);return
	check(motion.last_clip=="idle","Real stationary player plays the approved idle")
	await capture("game-idle")
	Input.action_press("move_forward")
	var start: Vector3=game.player.position
	for i in 45:c.physics_step(1.0/60)
	check(game.player.position.distance_to(start)>2 and motion.last_clip=="run","W moves the collision body with the arms-behind run")
	await capture("game-run")
	Input.action_release("move_forward")
	for i in 90:c.physics_step(1.0/60)
	check(motion.last_clip=="idle" and game.player.velocity.length()<.1,"Releasing movement settles to the authored idle")
	var ground_y: float=game.player.position.y
	game.player.jump_buffer=.15
	var apex=ground_y;var saw_air=false;var saw_landing=false
	for i in 150:
		c.physics_step(1.0/60);apex=maxf(apex,game.player.position.y)
		if motion.last_clip=="jump" and motion.last_frame>=22 and motion.last_frame<=60:saw_air=true
		if motion.last_clip=="jump" and motion.last_frame>=76:saw_landing=true
		if i==20:await capture("game-jump-air")
		if motion.last_clip=="jump" and motion.last_frame>=76 and motion.last_frame<81:await capture("game-jump-land")
	check(saw_air and saw_landing and apex>ground_y+1,"Real jump reaches approved airborne and landing poses")
	check(game.player.is_on_floor() and absf(game.player.position.y-ground_y)<.1 and motion.last_clip=="idle","Jump returns to the actual floor and approved idle")
	check(actor.model.position.length()<.001,"Blender poses do not add a second jump height")
	game.player.jump_buffer=.15
	for i in 12:c.physics_step(1.0/60)
	game.player.jump_buffer=.15;c.physics_step(1.0/60)
	check(game.player.jumps_used==2 and game.player.velocity.y>0,"Explorer retains his existing second-jump physics")
	check(motion.last_clip=="jump" and motion.last_frame<=7 and actor.model.quaternion.angle_to(Quaternion.IDENTITY)<.001,"Second jump reuses approved launch without the old visual flip")
	for i in 150:c.physics_step(1.0/60)
	game.player.jump_buffer=.15;c.physics_step(1.0/60)
	c.physics_step(1.0/60)
	game.player.jump_buffer=.15;c.physics_step(1.0/60)
	check(game.player.jumps_used==2 and motion.air_age==0 and motion.last_frame==1,"Immediate second jump restarts launch with its actual lower launch velocity")
	for i in 150:c.physics_step(1.0/60)
	await fresh(11);c=game.player.active_ability;actor=c.visual_actor;c._animate(0,0);motion=actor.cosplay_rig.explorer_motion
	var e=target(Vector3(0,0,-2));c.attack()
	var contact=float(c.player.attack.contact);var duration=float(c.player.attack.duration)
	check(is_equal_approx(contact,.055) and is_equal_approx(float(c.player.attack.damage),19),"Explorer's primary contact and damage are unchanged")
	c.tick(contact-.001,false);c._animate(contact-.001,0)
	check(is_equal_approx(e.hp,10000) and motion.last_clip=="","Approved movement releases to combat before contact")
	c.tick(.002,false);c._animate(.002,0)
	check(e.hp<10000 and motion.last_clip=="","Native attack still hits on its existing contact tick")
	await capture("game-attack")
	c.tick(duration+.01,false)
	c.player.roll=.2;c._animate(.01,0)
	check(motion.last_clip=="","Dodge releases the movement animation")
	c.player.roll=0;actor.reset_motion()
	check(motion.last_clip=="" and motion.landing_age>10,"Reset clears airborne and landing state")
	game.player.select_character(10)
	check(game.player.active_ability.visual_actor.cosplay_rig.get("explorer_motion")==null,"Switching to Ranger keeps Explorer's animation isolated")
	game.player.select_character(11);game.player.active_ability._animate(0,0)
	check(game.player.active_ability.visual_actor.cosplay_rig.explorer_motion.last_clip=="idle","Switching back creates a clean Explorer idle")
	Input.action_release("move_forward");game.queue_free();paused=false;await frames(3)
	print("EXPLORER_GAMEPLAY_RESULT checks=",checks," failures=",failures);quit(1 if failures else 0)
