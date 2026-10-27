extends "res://tests/forest-shrine/illidan_flight_test.gd"
const FLIP_OUT="res://build/Other Files/Asset Toolkit/Illidan Flip/"

func photo(label_:String):
	if DisplayServer.get_name()=="headless":return
	var p=game.player
	game.forest_ui.sync();game.camera_rig.camera.position=p.position+Vector3(25,20,40)
	game.camera_rig.camera.look_at(p.position+Vector3(0,8,0))
	await frames(2);await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(FLIP_OUT+label_+".png")==OK,"Rendered "+label_)

func second_jump():
	press("jump");await flight_steps(10);press("jump",false)
	check(game.player.model.body.transform.is_equal_approx(Transform3D.IDENTITY),"First jump remains upright")
	press("jump");await flight_steps(1)

func run():
	create_timer(120).timeout.connect(func():printerr("ILLIDAN_FLIP_TIMEOUT");quit(1))
	DirAccess.make_dir_recursive_absolute(FLIP_OUT)
	await setup_fixture();game.tuning.invincible=true
	game.set_process_input(false);game.set_process_unhandled_input(false)
	game.camera_rig.set_process_input(false);game.camera_rig.set_process_unhandled_input(false)
	var p=game.player;p.set_process_input(false);p.set_process_unhandled_input(false)
	driver=load("res://tests/forest-shrine/physics_step_driver.gd").new();root.add_child(driver)
	game.settings.jump_styles={}
	await park(32);await second_jump()
	var model=p.model;var animation_player=model.animation_player
	check(p.jumps_used==2 and p.velocity.y>0 and model.body.basis.y.z<0,"Second jump starts a forward somersault")
	check(model.clip=="Stand Ready" and not p.active_ability.is_attacking() and contacts.is_empty(),"Flip reuses ready pose without an attack or damage")
	var pivot=Vector3(0,1.4,0)
	await flight_steps(3);await photo("quarter-turn")
	await flight_steps(4)
	check(model.body.basis.y.y<-.99,"Halfway through Musashi's eight-tick duration Illidan is upside down")
	check((model.body.transform*pivot).is_equal_approx(pivot),"Body rotates around its torso instead of orbiting its feet")
	check(p.basis.is_equal_approx(Basis.IDENTITY),"Visual flip leaves the collision body upright")
	await photo("half-turn");await flight_steps(4);await photo("three-quarter-turn")
	await flight_steps(4)
	check(model.body.transform.is_equal_approx(Transform3D.IDENTITY),"One complete forward turn finishes at Musashi's duration")
	await photo("flip-finished")
	press("jump",false);press("jump");await flight_steps(3);press("jump",false)
	check(p.jumps_used==2 and model.body.transform.is_equal_approx(Transform3D.IDENTITY),"Third press grants neither another jump nor another flip")
	await flight_steps(150)
	check(p.is_on_floor() and model.body.transform.is_equal_approx(Transform3D.IDENTITY),"Landing clears the visual turn")
	await second_jump();tap("light_attack");await flight_steps(1)
	check(model.clip=="Attack" and model.body.transform.is_equal_approx(Transform3D.IDENTITY),"Air attacks take priority and reset the flip transform")
	await flight_steps(30);check(model.body.transform.is_equal_approx(Transform3D.IDENTITY),"Attack recovery does not replay the jump flip")
	await park(32);await second_jump();tap("equip");await flight_steps(1)
	check(model.clip=="Morph" and model.body.transform.is_equal_approx(Transform3D.IDENTITY),"Transforming during a flip restores the morph pose")
	await flight_steps(100);press("jump");await flight_steps(30)
	check(p.flying and p.active_ability.demon and model.body.transform.is_equal_approx(Transform3D.IDENTITY),"Meta flight remains upright")
	await park(32);p.jump_style.equip(32,"single")
	press("jump");await flight_steps(10);press("jump",false);press("jump");await flight_steps(2)
	check(p.jumps_used==1 and model.body.transform.is_equal_approx(Transform3D.IDENTITY),"Equipped single jump cannot trigger the flip")
	await park(32);await second_jump();p.select_character(31);p.select_character(32);await flight_steps(1)
	check(p.model.body.transform.is_equal_approx(Transform3D.IDENTITY),"Reselecting Illidan cannot retain a partial flip")
	await park(32)
	var counts=[]
	for cycle in 8:
		await second_jump();await flight_steps(20,cycle==0);press("jump",false);await flight_steps(150,cycle==0)
		check(p.is_on_floor() and model.body.transform.is_equal_approx(Transform3D.IDENTITY),"Repeated flip finishes and lands %d"%cycle)
		if cycle in [2,7]:
			await create_timer(1).timeout;await frames(2)
			counts.append([Performance.get_monitor(Performance.OBJECT_NODE_COUNT),Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)])
	check(counts[0]==counts[1] and model.animation_player==animation_player,"Repeated flips reuse the rig, animation player, nodes and resources")
	flight_cpu.sort();flight_intervals.sort()
	var report={"checks":checks,"failures":failures,"step_p95_ms":flight_cpu[int(flight_cpu.size()*.95)],"reuse":counts}
	if not flight_intervals.is_empty():report.frame_p95_ms=flight_intervals[int(flight_intervals.size()*.95)];report.frame_max_ms=flight_intervals[-1]
	FileAccess.open(FLIP_OUT+DisplayServer.get_name()+".json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("ILLIDAN_FLIP_RESULT ",JSON.stringify(report))
	press("jump",false);press("sprint",false);game.queue_free();await frames(3);DirAccess.remove_absolute(cfg);quit(1 if failures else 0)
