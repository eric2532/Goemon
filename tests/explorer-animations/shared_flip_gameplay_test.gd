extends "res://tests/forest-shrine/explorer_close_assist_test.gd"
func run():
	if "--packaged" in OS.get_cmdline_user_args():check(not FileAccess.file_exists("res://tools/export_tucked_double_jump.py") and FileAccess.file_exists("res://assets/animations/tucked_double_jump.json"),"Real jumps use packaged flip data")
	game=load("res://scenes/forest_shrine.tscn").instantiate();game.settings_path="user://shared-flip-%d.cfg"%OS.get_process_id()
	root.add_child(game);current_scene=game
	await frames(3);game.start_wave();game.model.waves.spawn_clock=10000;game.model.waves.pending=0
	game.set_physics_process(false);game.player.set_physics_process(false);game.camera_rig.set_process(false)
	game.tuning.invincible=true;game.tuning.critical_chance=0.0
	for id in [5,10,11]:
		for delay in [2,12]:
			await fresh(id)
			var c=game.player.active_ability;var actor=c.visual_actor;actor.reset_motion();c._animate(0,0)
			var motion=actor.cosplay_rig.double_jump;var label_=c.class_id+" delay=%d"%delay
			var floor_y: float=game.player.position.y
			game.player.jump_buffer=.15
			for i in delay:c.physics_step(1.0/60)
			check(not motion.active,label_+" first jump retains its own animation")
			game.player.jump_buffer=.15;c.physics_step(1.0/60)
			check(game.player.jumps_used==2 and game.player.velocity.y>0 and motion.active,label_+" second jump starts the shared flip")
			var saw_inverted=false;var finished_air=false
			for i in 145:
				c.physics_step(1.0/60)
				var sk: Skeleton3D=actor.cosplay_rig.skeleton;var b=sk.find_bone("Root")
				var turn=sk.get_bone_global_pose(b).basis*sk.get_bone_global_rest(b).basis.inverse()
				if (turn*Vector3.UP).dot(Vector3.UP)<-.9:saw_inverted=true
				if not motion.active and not game.player.is_on_floor():finished_air=true
			check(saw_inverted and finished_air,label_+" completes its tuck/turn before landing")
			check(game.player.is_on_floor() and absf(game.player.position.y-floor_y)<.1 and not motion.active,label_+" returns to the collision floor")
		await fresh(id)
		var c=game.player.active_ability;var actor=c.visual_actor;actor.reset_motion();c._animate(0,0)
		game.player.jump_buffer=.15
		for i in 12:c.physics_step(1.0/60)
		game.player.jump_buffer=.15
		for i in 10:c.physics_step(1.0/60)
		check(actor.cosplay_rig.double_jump.active,c.class_id+" is flipping before an airborne attack")
		c.attack();c._animate(1.0/60,0)
		check(not actor.cosplay_rig.double_jump.active and c.player.attack!=null,c.class_id+" native airborne attack interrupts the flip")
		if c.class_id=="ranger":
			check(c.player.attack.style=="bow-fan" and c.player.attack.downward,"Ranger retains his downward second-jump fan")
		for i in 30:c.tick(1.0/60,false);c._animate(1.0/60,0)
		check(not actor.cosplay_rig.double_jump.active,c.class_id+" attack completion does not restart a stale flip")
	game.queue_free();paused=false;await frames(3)
	print("SHARED_FLIP_GAMEPLAY_RESULT checks=",checks," failures=",failures);quit(1 if failures else 0)
