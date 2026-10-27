extends "res://tests/forest-shrine/goemon_extended_reach_test.gd"
## Exercise moving enlarged weapons, not just a stationary contact pose.
func sweep_cost(reach:float)->Dictionary:
	var p=game.player;var combat=p.original_pipe_combat
	configured_pose(1,0,reach);combat.begin()
	var changes=[0];var changed=func():changes[0]+=1
	combat.shape.changed.connect(changed)
	var started=Time.get_ticks_usec()
	for stage in [1,2,3]:
		p.combo=stage
		var duration=RecoveredGoemonCombatProfile.action_duration(0x67+stage)
		for frame_ in ceili(duration*60):
			combat.tick(frame_/60.0,minf((frame_+1)/60.0,duration))
	combat.shape.changed.disconnect(changed)
	return {"reach":reach,"hull_changes":changes[0],"ms":(Time.get_ticks_usec()-started)/1000.0}
func run():
	await setup_fixture()
	raw_motion=JSON.parse_string(FileAccess.get_file_as_string("res://assets/characters/recovered_goemon/motion.json"))
	var p=game.player;var dummy=game.training_dummy
	var collision:CollisionShape3D=dummy.get_children().filter(func(c):return c is CollisionShape3D)[0]
	collision.shape.radius=.03;collision.shape.height=.06;collision.position=Vector3.ZERO;dummy.contact_shape.center=Vector3.ZERO
	for reach in [1.0,3.0,10.0]:
		for stage in [1,2,3]:
			var frame_=4 if stage==1 else (5 if stage==2 else 7)
			for local in [Vector3(23,-3,78),Vector3(23,-3,50)]:
				configured_pose(stage,frame_-1,reach)
				await target_at(raw_pipe_point(stage,frame_,local))
				p.original_pipe_combat.begin()
				p.original_pipe_combat.tick((frame_-1)/18.0,(frame_+1)/18.0)
				check(contacts==[stage],"Moving stage %d pipe hits a tiny mesh target at %.0f× reach"%[stage,reach])
				p.original_pipe_combat.tick((frame_-1)/18.0,(frame_+1)/18.0)
				check(contacts==[stage],"Repeated sweep keeps one hit per target")
			configured_pose(stage,0,reach)
			await target_at(raw_pipe_point(stage,frame_,Vector3(23,-3,78)))
			p.original_pipe_combat.begin()
			p.original_pipe_combat.tick(0,(frame_+1)/18.0)
			check(contacts==[stage],"A long tick retains stage %d tip contact at %.0f× reach"%[stage,reach])
	configured_pose(1,3,10)
	var tip=raw_pipe_point(1,4,Vector3(23,-3,78));await target_at(tip)
	var wall=StaticBody3D.new();wall.collision_layer=1
	var blocker=CollisionShape3D.new();var box=BoxShape3D.new();box.size=Vector3(20,80,.18);blocker.shape=box;wall.add_child(blocker);game.add_child(wall)
	wall.position=(p.position+Vector3.UP*1.1).lerp(tip,.5);wall.look_at(tip)
	await physics_frame;await physics_frame
	p.original_pipe_combat.begin();p.original_pipe_combat.tick(3.0/18,5.0/18)
	check(contacts.is_empty(),"An enlarged moving pipe still cannot hit through a wall")
	wall.queue_free();await physics_frame
	await target_at(Vector3(500,20,500))
	var normal=sweep_cost(1);var large=sweep_cost(10)
	print("PIPE_LARGE_SWEEP_COST ",JSON.stringify([normal,large]))
	check(large.hull_changes<=normal.hull_changes*3,"Tenfold reach avoids rebuilding hulls for every short linear movement")
	game.queue_free();paused=false;await frames();await create_timer(.15).timeout
	if FileAccess.file_exists(cfg):DirAccess.remove_absolute(ProjectSettings.globalize_path(cfg))
	print("GOEMON_LARGE_SWEEP_RESULT checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)
