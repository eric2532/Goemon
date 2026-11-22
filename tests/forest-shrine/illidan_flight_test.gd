extends "res://tests/forest-shrine/warcraft_characters_test.gd"
const FLIGHT_OUT="res://build/Other Files/Asset Toolkit/Illidan Flight/"
var driver:Node
var flight_cpu=[]
var flight_intervals=[]

func press(action:String,down:bool=true):
	if down:Input.action_press(action)
	else:Input.action_release(action)
	var event=InputEventAction.new();event.action=action;event.pressed=down
	if down:game.player._unhandled_input(event)
	else:game.player._input(event)

func flight_steps(count:int,render:bool=false):
	var realtime=render and DisplayServer.get_name()!="headless"
	var last=[Time.get_ticks_usec()]
	await driver.advance(count if realtime else 1,func(dt):
		if realtime:
			flight_intervals.append((Time.get_ticks_usec()-last[0])/1000.0);last[0]=Time.get_ticks_usec()
		for i in (1 if realtime else count):
			var start=Time.get_ticks_usec();game.player._physics_process(dt)
			flight_cpu.append((Time.get_ticks_usec()-start)/1000.0))

func park(id:int):
	press("jump",false);press("sprint",false)
	var p=game.player;p.select_character(id);p.active_ability.cancel();fresh()
	p.set_scarf_equipped(false);p.jump_style.equip(id,"")
	await flight_steps(12)

func photo(label_:String):
	if DisplayServer.get_name()=="headless":return
	var p=game.player
	game.forest_ui.sync();game.camera_rig.camera.position=p.position+Vector3(24,19,-42)
	game.camera_rig.camera.look_at(p.position+Vector3(0,11,0));p.model.pose(p.model.clip,.2)
	await frames(2);await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(FLIGHT_OUT+label_+".png")==OK,"Rendered "+label_)

func run():
	create_timer(120).timeout.connect(func():printerr("ILLIDAN_FLIGHT_TIMEOUT");quit(1))
	DirAccess.make_dir_recursive_absolute(FLIGHT_OUT)
	await setup_fixture();game.tuning.invincible=true
	game.set_process_input(false);game.set_process_unhandled_input(false)
	game.camera_rig.set_process_input(false);game.camera_rig.set_process_unhandled_input(false)
	var p=game.player;p.set_process_input(false);p.set_process_unhandled_input(false)
	driver=load("res://tests/forest-shrine/physics_step_driver.gd").new();root.add_child(driver)
	game.settings.jump_styles={}
	await park(32)
	check(not p.can_fly(),"Normal Illidan retains his ordinary jump")
	press("jump");await flight_steps(10);press("jump",false);press("jump");await flight_steps(2)
	check(p.jumps_used==2 and not p.flying,"Normal form still has a real double jump")
	await park(32);tap("equip");await flight_steps(100)
	check(p.active_ability.demon and p.can_fly(),"Completing Metamorphosis enables shared flight")
	var donor=[]
	for id in [30,32]:
		await park(id)
		if id==32:p.active_ability.demon=true
		p.position=ORIGIN+Vector3.UP*40;p.velocity=Vector3.ZERO;p.smoke_move=Vector2.RIGHT
		press("jump");await flight_steps(45)
		var rise=p.velocity
		check(p.flying and is_equal_approx(rise.y,18) and is_equal_approx(Vector2(rise.x,rise.z).length(),36),"Shared rise and steering speed %d"%id)
		press("sprint");await flight_steps(45);var boost=p.velocity
		check(is_equal_approx(boost.y,32) and is_equal_approx(Vector2(boost.x,boost.z).length(),64),"Shared boosted rise and steering speed %d"%id)
		press("jump",false);press("sprint",false);p.smoke_move=Vector2.ZERO;await flight_steps(55)
		check(is_equal_approx(p.velocity.y,-10),"Release Space gives controlled descent %d"%id)
		if id==30:donor=[rise,boost,p.velocity.y]
		else:check(rise.is_equal_approx(donor[0]) and boost.is_equal_approx(donor[1]) and is_equal_approx(p.velocity.y,donor[2]),"Meta Illidan matches Dark Lumina 3 flight velocities")
	check(p.model.clip=="Stand Ready Alternate" and p.air_turn==0,"Floating reuses the upright alternate ready pose")
	await photo("meta-flight")
	var pool=Pool.service(game);var shots=[]
	pool.launched.connect(func(shot):
		if shot.get_script()==Shot:shots.append(shot);shot.set_physics_process(false))
	press("jump");tap("light_attack");await flight_steps(12)
	check(shots.size()==1 and p.flying and p.active_ability.demon,"Meta flight can fire the original pooled demon bolt")
	if not shots.is_empty():
		check(is_equal_approx(shots[0].visual.pixel_size,.36),"Flight preserves the enlarged bolt visual")
		shots[0].retire()
	await flight_steps(30);press("jump",false)
	p.active_ability.cooldown=0;tap("heavy_attack");await flight_steps(100)
	check(not p.active_ability.demon and not p.can_fly() and not p.flying,"Reversing Metamorphosis in midair restores normal falling")
	p.active_ability.demon=true;p.jump_style.equip(32,"double")
	check(not p.can_fly(),"An explicitly equipped jump still overrides innate meta flight")
	p.jump_style.equip(32,"");check(p.can_fly(),"Original restores form-dependent flight without a saved override")
	p.select_character(31);check(not p.can_fly(),"Changing fighter clears innate meta flight")
	p.select_character(32);check(not p.active_ability.demon and not p.can_fly(),"Reselecting Illidan starts in normal form")
	await park(32);p.active_ability.demon=true
	press("jump");await flight_steps(30,true);press("jump",false);await flight_steps(150,true)
	check(p.is_on_floor(),"Releasing flight lands on actual world collision")
	await flight_steps(90);await create_timer(1.0).timeout;await frames(2)
	var counts=[Performance.get_monitor(Performance.OBJECT_NODE_COUNT),Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)]
	var created=pool.created;var misses=pool.misses
	for cycle in 5:
		press("jump");await flight_steps(30,cycle==0);press("jump",false);await flight_steps(150,cycle==0)
		check(p.is_on_floor() and p.jump_buffer==0,"Repeated flight lands without a queued jump %d"%cycle)
	await flight_steps(90);await create_timer(1.0).timeout;await frames(2)
	var final_counts=[Performance.get_monitor(Performance.OBJECT_NODE_COUNT),Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)]
	check(counts==final_counts,"Repeated floating reuses nodes and resources: %s -> %s"%[counts,final_counts])
	check(pool.created==created and pool.misses==misses,"Flight leaves prepared projectile pool unchanged")
	flight_cpu.sort();flight_intervals.sort()
	var report={"checks":checks,"failures":failures,"step_p95_ms":flight_cpu[int(flight_cpu.size()*.95)],"pool_misses":pool.misses}
	if not flight_intervals.is_empty():report.frame_p95_ms=flight_intervals[int(flight_intervals.size()*.95)];report.frame_max_ms=flight_intervals[-1]
	FileAccess.open(FLIGHT_OUT+DisplayServer.get_name()+".json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("ILLIDAN_FLIGHT_RESULT ",JSON.stringify(report))
	press("jump",false);press("sprint",false);game.queue_free();await frames(3);DirAccess.remove_absolute(cfg);quit(1 if failures else 0)
