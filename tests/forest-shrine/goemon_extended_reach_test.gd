extends "res://scripts/recovered_goemon_pipe_hitbox_tests.gd"
## Settings must reach the real Hero pose update and native swept-pipe contacts.
func configured_pose(stage:int,frame_:int,multiplier:float):
	reset_strike(stage)
	game.update_character_tuning(1,"melee_reach",multiplier)
	pose_fixture(stage,frame_)
	game.player._physics_process(0)
	# At 10× the source downward swing can enter terrain or scenery. Keep this
	# isolated reach fixture airborne; the native hitbox suite covers obstruction.
	game.player.position=ORIGIN+Vector3.UP*40
func run():
	await setup_fixture()
	raw_motion=JSON.parse_string(FileAccess.get_file_as_string("res://assets/characters/recovered_goemon/motion.json"))
	var p=game.player;var dummy=game.training_dummy
	check(game.balance_value(1,"melee_reach")==1,"Goemon keeps original reach until the player edits it")
	var shape:CollisionShape3D=dummy.get_children().filter(func(c):return c is CollisionShape3D)[0]
	shape.shape.radius=.08;shape.shape.height=.16;shape.position=Vector3.ZERO;dummy.contact_shape.center=Vector3.ZERO
	for stage in [1,2,3]:
		var frame_=4 if stage==1 else (5 if stage==2 else 7)
		await target_at(Vector3(500,20,500))
		configured_pose(stage,frame_,3)
		var old_tip=raw_pipe_point(stage,frame_,Vector3(23,-3,78))
		var old_duration:float=p.attack_duration;var old_body:Vector3=p.scale
		configured_pose(stage,frame_,10)
		var tip=raw_pipe_point(stage,frame_,Vector3(23,-3,78))
		check(tip.distance_to(p.position)>old_tip.distance_to(p.position)*2,"Tenfold setting extends native Goemon pipe stage %d"%stage)
		check(p.attack_duration==old_duration and p.scale==old_body,"Extended pipe keeps native timing and body size for stage %d"%stage)
		await target_at(tip)
		configured_pose(stage,frame_,3);p.strike()
		check(contacts.is_empty(),"Threefold pipe misses the distant stage %d tip target"%stage)
		configured_pose(stage,frame_,10);p.struck_targets.clear();contacts.clear();p.strike()
		check(contacts==[stage],"Tenfold native pipe hits the same stage %d tip target"%stage)
	game.move_audio.stop()
	for voice in game.voices:voice.stop()
	game.queue_free();paused=false;await frames();await create_timer(.15).timeout
	if FileAccess.file_exists(cfg):DirAccess.remove_absolute(ProjectSettings.globalize_path(cfg))
	print("GOEMON_EXTENDED_REACH_RESULT checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)
