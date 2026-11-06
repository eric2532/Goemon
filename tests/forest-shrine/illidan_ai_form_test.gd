extends "res://tests/forest-shrine/warcraft_characters_test.gd"
const AI_OUT="res://build/Other Files/Asset Toolkit/Illidan AI/"
var home=Vector3(-60,.1,60)
var mirrors
var morphs={}
var bolts={}
var samples=[]

func advance(count:int,_delta:float=1.0/60):
	for i in count:
		var start=Time.get_ticks_usec()
		game.player._physics_process(1.0/60)
		game.army_runtime.step(1.0/60,{"targets":[]})
		game.army_runtime.sync_compatibility()
		for shots in Pool.service(game).all.values():
			for shot in shots:
				if shot.pool_live and shot.get_script()==Shot:shot._physics_process(1.0/60)
		if mirrors!=null:
			for body in mirrors.bodies:
				var c=body.active_ability
				if c.mode=="morph" and c.elapsed<=1.0/60+.0001:
					morphs[body.get_instance_id()]=morphs.get(body.get_instance_id(),0)+1
		times.append((Time.get_ticks_usec()-start)/1000.0)
		if DisplayServer.get_name()!="headless":
			await physics_frame
			samples.append((Time.get_ticks_usec()-start)/1000.0)
		elif i%30==0:await process_frame

func fresh(surge:bool=false):
	super.fresh(surge)
	game.player.position=home;game.player.velocity=Vector3.DOWN
	game.player.move_and_slide()
	game.model.update_vision(home)

func run():
	create_timer(180).timeout.connect(func():printerr("ILLIDAN_AI_TIMEOUT");quit(1))
	DirAccess.make_dir_recursive_absolute(AI_OUT)
	var doc=load("res://scripts/forest/forest_map_document.gd").new();doc.load_wind_meadow()
	await setup_fixture(doc.data);game.tuning.invincible=true
	home.y=game.model.surface_height(home.x,home.z)+.1
	game.set_process(false);game.crowd.set_process(false);game.explorer_helpers.set_process(false)
	game.set_process_input(false);game.set_process_unhandled_input(false)
	game.player.set_process_input(false);game.player.set_process_unhandled_input(false)
	game.camera_rig.set_process_input(false);game.camera_rig.set_process_unhandled_input(false)
	var p=game.player;var owner=game.army_runtime;var pool=Pool.service(game)
	pool.launched.connect(func(shot):
		if shot.get_script()==Shot:
			shot.set_physics_process(false)
			bolts[shot.hero.get_instance_id()]=bolts.get(shot.hero.get_instance_id(),0)+1)
	p.select_character(32);fresh();await advance(5)
	var c=p.active_ability
	for action in ["heavy_attack","equip"]:
		c.cancel();c.clear_cooldowns();tap(action);await advance(100)
		check(c.demon,"Player enters Meta with "+action)
		c.clear_cooldowns();tap(action);check(c.mode=="morph","Player still starts reverse morph with "+action)
		await advance(100);check(not c.demon,"Player still returns to normal with "+action)
	owner.set_navigation(9933,{"width":0});owner.record_events=true
	game.training_dummy.home=home+Vector3(0,0,-100);game.training_dummy.position=game.training_dummy.home
	var row=game.model.waves.spawn_enemy(0,home+Vector3(0,0,-4));row.hp=100000000;row.max_hp=row.hp
	owner.import_arrivals();owner.sync_targets();var enemy=game.actors[row.id]
	owner.apply_hit(enemy.handle,{"element":"ice","status_seconds":120.0})
	mirrors=preload("res://scripts/warcraft_mirrors.gd").new(p,0)
	for i in 5:check(mirrors.reinforce(32,home+Vector3((i-2)*3,0,5)),"Native Illidan recruit %d"%i)
	# Both AI inputs reach the same toggle; form cooldown must not suppress a bolt.
	for body in mirrors.bodies:
		var kit=body.active_ability
		body.ai_aim=enemy.position+Vector3.UP*1.3;kit.start_morph();kit.tick(kit.duration)
		check(kit.demon,"AI can enter Meta normally")
		for action in ["heavy_attack","equip"]:
			kit.cooldown=2;body.press(action);body.release()
			check(kit.demon and kit.mode=="attack" and kit.clip=="Attack Alternate","Transformed AI fires instead of reversing on "+action)
			kit.tick(kit.duration);kit.cancel(true)
		kit.clear_cooldowns()
		kit.cancel();owner.native.set_mirror_busy(body.native_handle,false)
	bolts.clear();morphs.clear();await advance(1200)
	for body in mirrors.bodies:
		print("ILLIDAN_AI_TRACE home=",home," state=",owner.unit_state(body.native_handle)," morphs=",morphs.get(body.get_instance_id(),0)," bolts=",bolts.get(body.get_instance_id(),0))
		check(body.active_ability.demon and morphs.get(body.get_instance_id(),0)==1,"AI transforms exactly once across repeated native choices")
		check(bolts.get(body.get_instance_id(),0)>1,"AI continues firing real pooled bolts")
	check(enemy.hp<row.max_hp,"Native target receives real bolt damage")
	game.camera_rig.camera.position=home+Vector3(28,25,38);game.camera_rig.camera.look_at(home+Vector3.UP*7)
	if DisplayServer.get_name()!="headless":
		owner.flush_presentation();await RenderingServer.frame_post_draw
		check(root.get_texture().get_image().save_png(AI_OUT+"five-meta-allies.png")==OK,"Rendered five committed Meta allies")
	var created=pool.created;var misses=pool.misses
	var nodes=Performance.get_monitor(Performance.OBJECT_NODE_COUNT);var resources=Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)
	await advance(600)
	check(pool.created==created and pool.misses==misses,"Repeated native decisions reuse prepared projectile pool")
	check(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)<=nodes and Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)<=resources,"Repeated native decisions retain no extra nodes or resources")
	for body in mirrors.bodies:check(morphs.get(body.get_instance_id(),0)==1,"AI stays in Meta across later choices")
	mirrors.clear();check(mirrors.bodies.all(func(body):return not body.active_ability.demon and not body.has_offensive_action()),"Retirement clears form and pending attacks")
	var reused=mirrors.bodies[0];check(mirrors.reinforce(32,home),"Retired native body can be reused")
	check(mirrors.bodies[0]==reused and not reused.active_ability.demon,"Reused ally starts in normal form")
	mirrors.dispose();mirrors=null;await advance(90)
	times.sort();samples.sort()
	var report={"checks":checks,"failures":failures,"step_p95_ms":times[int(times.size()*.95)],"step_max_ms":times[-1],"frame_p95_ms":samples[int(samples.size()*.95)] if not samples.is_empty() else null,"frame_max_ms":samples[-1] if not samples.is_empty() else null,"pool_misses":pool.misses}
	FileAccess.open(AI_OUT+DisplayServer.get_name()+".json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("ILLIDAN_AI_RESULT ",JSON.stringify(report))
	game.queue_free();await frames(3);DirAccess.remove_absolute(cfg);quit(1 if failures else 0)
