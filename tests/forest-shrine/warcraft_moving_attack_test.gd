extends "res://tests/forest-shrine/warcraft_characters_test.gd"
const MOVE_OUT="res://build/Other Files/Asset Toolkit/Warcraft/Moving Attacks/"
var driver:Node

func advance(count:int,_delta:float=1.0/60):
	var rendered=DisplayServer.get_name()!="headless"
	await driver.advance(count if rendered else 1,func(dt):
		for i in (1 if rendered else count):
			var start=Time.get_ticks_usec()
			game.player._physics_process(dt)
			for shots in Pool.service(game).all.values():
				for shot in shots:
					if shot.pool_live and shot.get_script()==Shot:shot._physics_process(dt)
			times.append((Time.get_ticks_usec()-start)/1000.0))

func run():
	create_timer(120).timeout.connect(func():printerr("WARCRAFT_MOVING_ATTACK_TIMEOUT");quit(1))
	DirAccess.make_dir_recursive_absolute(MOVE_OUT)
	await setup_fixture();game.tuning.invincible=true
	driver=load("res://tests/forest-shrine/physics_step_driver.gd").new();root.add_child(driver)
	game.set_process_input(false);game.set_process_unhandled_input(false)
	game.camera_rig.set_process_input(false);game.camera_rig.set_process_unhandled_input(false)
	var p=game.player;p.set_process_input(false);p.set_process_unhandled_input(false)
	game.camera_rig.camera.position=ORIGIN+Vector3(24,20,36);game.camera_rig.camera.look_at(ORIGIN+Vector3(0,7,0))
	Pool.service(game).launched.connect(func(shot):
		if shot.get_script()==Shot:shot.set_physics_process(false))
	for id in [31,32]:
		p.select_character(id)
		var c=p.active_ability
		for stage in 3:
			for action in ["move_left","move_right","move_forward","move_back"]:
				c.cancel();fresh();await advance(12)
				check(p.is_on_floor(),"Movement fixture starts grounded %d"%id)
				c.demon=id==32 and stage==2
				if c.demon:aim_meta_at(game.training_dummy.position+Vector3.UP*1.5)
				c.combo=stage-1;c.combo_timer=.85
				p.smoke_mode=false;Input.action_press(action)
				var before=p.position
				c.start_attack()
				await advance(1)
				var aim=p.facing
				check(c.is_attacking() and contacts.is_empty() and p.position.distance_to(before)>.005,"Can move during attack windup %d/%d/%s"%[id,stage,action])
				var recovery_motion=false;var aim_preserved=true;var photographed=false;var steps=0
				while c.is_attacking() and steps<120:
					before=p.position;await advance(1);steps+=1
					if c.is_attacking() and c.released and p.position.distance_to(before)>.005:recovery_motion=true
					if c.is_attacking() and not p.facing.is_equal_approx(aim):aim_preserved=false
					if not photographed and c.blade_active() and action=="move_right" and stage==0 and DisplayServer.get_name()!="headless":
						game.forest_ui.sync();await RenderingServer.frame_post_draw
						root.get_texture().get_image().save_png(MOVE_OUT+"%d-moving-cut.png"%id)
						photographed=true
				Input.action_release(action)
				check(recovery_motion,"Movement continues through attack recovery %d/%d/%s"%[id,stage,action])
				check(not c.is_attacking() and steps<120,"Moving attack completes normally")
				check(contacts.size()==1,"Moving attack lands exactly once %d/%d/%s (%d)"%[id,stage,action,contacts.size()])
				check(aim_preserved,"Movement preserves committed attack aim")
				await advance(45)
		if id==32:
			c.cancel();fresh();await advance(12);p.smoke_move=Vector2.RIGHT
			var before=p.position;c.start_morph();await advance(6)
			check(c.mode=="morph" and Vector2(p.position.x-before.x,p.position.z-before.z).length()<.001,"Metamorphosis retains its planted transition")
			c.cancel()
	times.sort()
	var report={"checks":checks,"failures":failures,"step_p95_ms":times[int(times.size()*.95)],"pool_misses":Pool.service(game).misses}
	FileAccess.open(MOVE_OUT+DisplayServer.get_name()+".json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("WARCRAFT_MOVING_ATTACK_RESULT ",JSON.stringify(report))
	game.queue_free();await frames(3);DirAccess.remove_absolute(cfg);quit(1 if failures else 0)
