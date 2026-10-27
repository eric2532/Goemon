extends "res://scripts/recovered_goemon_gameplay_tests.gd"
const Pool=preload("res://scripts/character_projectile_pool.gd")
const Shot=preload("res://scripts/kojiro_projectile.gd")
const OUT="res://build/Other Files/Asset Toolkit/Kojiro/Piercing/"
var origin=ORIGIN+Vector3.UP*30
var cpu=[]
var focused=0
var rendered=0

func run():
	create_timer(120).timeout.connect(func():printerr("KOJIRO_PIERCING_TIMEOUT");quit(1))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	if DisplayServer.get_name()!="headless":
		DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_ALWAYS_ON_TOP,true);DisplayServer.window_move_to_foreground()
	await setup_fixture()
	game.set_process(false);game.army_runtime.set_physics_process(false)
	var p=game.player;p.select_character(28);p.position=origin
	var owner=game.army_runtime
	owner.clear();game.actors.clear();game.enemies.clear();game.model.enemies.clear()
	owner.set_navigation(9431,{"width":0})
	game.training_dummy.position=Vector3(0,-100,0)
	game.model.update_vision(origin)
	var victims=[]
	for offset in [Vector3(0,0,-6),Vector3(0,0,-12),Vector3(0,0,-18),Vector3(8,0,-12),Vector3(0,0,8)]:
		var row=game.model.waves.spawn_enemy(0,origin+offset);row.hp=100000;row.max_hp=100000
		owner.import_arrivals();owner.sync_targets();victims.append(game.actors[row.id])
	var point=Vector3(origin.x,AttackChain.aim_point(victims[0],origin).y,origin.z)
	var pool=Pool.service(game)
	pool.launched.connect(func(shot):
		if shot.get_script()==Shot:shot.set_physics_process(false))
	game.camera_rig.camera.position=origin+Vector3(12,9,10)
	game.camera_rig.camera.look_at(origin+Vector3(0,1,-9))
	game.crowd.army.present(owner.render_snapshot(),owner.presentation_events)
	owner.presentation_events.clear()
	await frames(3)
	var created=pool.created;var misses=pool.misses
	var nodes=Performance.get_monitor(Performance.OBJECT_NODE_COUNT)
	var resources=Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)
	for delta in [1.0/20,1.0/30,1.0/60,.75]:
		var before=victims.map(func(victim):return victim.hp)
		var shots=[]
		for i in 3:shots.append(pool.launch(p,Shot,"homing",{"kind":"homing","position":point,"velocity":Vector3.FORWARD*28,"unit":p.model.source_unit(),"damage":96.0,"target":victims[0]}))
		for frame in int(ceil(1.0/delta)):
			var start=Time.get_ticks_usec()
			for shot in shots:
				if shot.pool_live:shot._physics_process(delta)
			cpu.append((Time.get_ticks_usec()-start)/1000.0)
			if DisplayServer.get_name()!="headless":
				await physics_frame;rendered+=1
				if root.has_focus():focused+=1
				if is_equal_approx(delta,1.0/20) and frame in [4,9,14]:
					await RenderingServer.frame_post_draw
					root.get_texture().get_image().save_png(OUT+"flight-%d.png"%frame)
		for i in 3:check(is_equal_approx(before[i]-victims[i].hp,288.0),"Each of three birds hits native enemy %d once at delta %.4f"%[i,delta])
		check(victims[3].hp==before[3] and victims[4].hp==before[4],"Piercing preserves exact lane contacts at delta %.4f"%delta)
		for shot in shots:
			check(shot.pool_live and shot.target==null,"Bird continues beyond its original homing target")
			if shot.pool_live:
				shot.position=point;shot._physics_process(.75)
		for i in 3:check(is_equal_approx(before[i]-victims[i].hp,288.0),"Re-entering an enemy cannot duplicate a bird's damage")
		for shot in shots:shot.retire()
		for entries in pool.all.values():
			for effect in entries:
				if effect.pool_live:effect.retire()
	check(pool.created==created and pool.misses==misses,"Overlapping piercing flights reuse prepared birds and impact sparks")
	print("KOJIRO_PIERCING_RESOURCES nodes=",nodes," -> ",Performance.get_monitor(Performance.OBJECT_NODE_COUNT)," resources=",resources," -> ",Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT))
	check(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)<=nodes and Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)<=resources,"Repeated piercing does not grow nodes or resources")
	var wall=StaticBody3D.new();wall.collision_layer=1
	var shape=CollisionShape3D.new();shape.shape=BoxShape3D.new();shape.shape.size=Vector3(12,8,.5)
	wall.add_child(shape);game.add_child(wall);wall.position=origin+Vector3(0,3,-9)
	await physics_frame;await physics_frame
	var hp=victims[1].hp
	var bird=pool.launch(p,Shot,"homing",{"kind":"homing","position":point,"velocity":Vector3.FORWARD*28,"unit":p.model.source_unit(),"target":victims[0]})
	bird._physics_process(.8)
	check(not bird.pool_live and victims[1].hp==hp,"Bird pierces enemies but stops at solid cover")
	wall.queue_free();await physics_frame
	bird=pool.launch(p,Shot,"homing",{"kind":"homing","position":point+Vector3.UP*100,"velocity":Vector3.FORWARD*28,"unit":p.model.source_unit()})
	check(bird.hit_targets.is_empty() and bird.target==null,"Reused bird starts with no previous victims or target")
	bird._physics_process(3.0)
	check(not bird.pool_live,"Piercing retains the three-second lifetime")
	cpu.sort()
	FileAccess.open(OUT+"checks.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"pool_created":pool.created,"pool_misses":pool.misses,"renderer":RenderingServer.get_video_adapter_name(),"rendered_frames":rendered,"focused_frames":focused,"three_bird_cpu_p95_ms":cpu[int(cpu.size()*.95)],"scope":"Isolated native targets and three overlapping birds; manual projectile CPU timing, not full-army frame time or a long-session soak."},"  "))
	game.queue_free();paused=false;await frames(3)
	if FileAccess.file_exists(cfg):DirAccess.remove_absolute(ProjectSettings.globalize_path(cfg))
	print("KOJIRO_PIERCING_RESULT checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)
