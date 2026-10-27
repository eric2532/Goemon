extends "res://tests/forest-shrine/warcraft_characters_test.gd"
const SPLASH_OUT="res://build/Other Files/Asset Toolkit/Illidan Splash/"
func photo(label_:String):
	if DisplayServer.get_name()=="headless":return
	game.forest_ui.sync();await frames(2);await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(SPLASH_OUT+label_+".png")==OK,"Rendered "+label_)
func volley(pool:Node,p:Hero):
	var shots=[]
	for i in 24:shots.append(pool.launch(p,Shot,"demon",{"position":ORIGIN+Vector3(12+(i%6)*2,6+(i/6)*2,8),"velocity":Vector3.UP*3}))
	await advance(30)
	for shot in shots:shot.explode(shot.position)
	await advance(45)
	check(shots.all(func(shot):return not shot.pool_live),"Simultaneous impact playback returns all 24 leases")
func run():
	create_timer(180).timeout.connect(func():printerr("WARCRAFT_SPLASH_TIMEOUT");quit(1))
	DirAccess.make_dir_recursive_absolute(SPLASH_OUT)
	await setup_fixture();game.tuning.invincible=true
	game.set_process_input(false);game.set_process_unhandled_input(false)
	game.camera_rig.set_process_input(false);game.camera_rig.set_process_unhandled_input(false)
	var p=game.player;p.select_character(32);fresh();p.active_ability.demon=true
	p.set_process_input(false);p.set_process_unhandled_input(false)
	var pool=Pool.service(game);pool.launched.connect(func(shot):
		if shot.get_script()==Shot:shot.set_physics_process(false))
	game.training_dummy.home=ORIGIN+Vector3(0,0,-100);game.training_dummy.position=game.training_dummy.home
	var owner=game.army_runtime;owner.set_navigation(9931,{"width":0});var actors=[]
	for x in [0,2,4.5,9]:
		var row=game.model.waves.spawn_enemy(0,ORIGIN+Vector3(x,0,-10));row.hp=1000;row.max_hp=1000
		owner.import_arrivals();actors.append(game.actors[row.id])
	owner.sync_targets()
	game.camera_rig.camera.position=ORIGIN+Vector3(20,10,-2);game.camera_rig.camera.look_at(ORIGIN+Vector3(2,2,-10))
	live=true
	var shot=pool.launch(p,Shot,"demon",{"position":ORIGIN+Vector3(0,1.4,-4),"velocity":Vector3.FORWARD*28})
	for i in 30:
		await advance(1)
		if shot.resolved:break
	check(shot.resolved,"A real native army target triggers the impact")
	check(actors[0].hp==936 and actors[1].hp<1000 and actors[2].hp<1000 and actors[3].hp==1000,"One bolt splashes nearby native enemies and excludes distant enemies")
	var health=actors.map(func(actor):return actor.hp)
	await advance(5);await photo("native-splash")
	await advance(50)
	check(health==actors.map(func(actor):return actor.hp),"Native splash damages once while the recovered impact effect plays")
	owner.clear();game.actors.clear();game.enemies.clear();game.model.enemies.clear()
	shot=pool.launch(p,Shot,"demon",{"position":ORIGIN+Vector3(12,8,8),"velocity":Vector3.RIGHT*12})
	game.camera_rig.camera.position=ORIGIN+Vector3(18,12,26);game.camera_rig.camera.look_at(ORIGIN+Vector3(18,8,8))
	await advance(30);await photo("native-trail");shot.explode(shot.position)
	await advance(5);await photo("native-impact");await advance(45)
	await volley(pool,p);await advance(60)
	var counts=[Performance.get_monitor(Performance.OBJECT_NODE_COUNT),Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)]
	var created=pool.created;var misses=pool.misses;var cached=Shot.Effects.energy_textures.size()
	times.clear();intervals.clear()
	for cycle in 5:await volley(pool,p)
	await advance(60)
	check(counts==[Performance.get_monitor(Performance.OBJECT_NODE_COUNT),Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)],"Repeated native particle volleys retain stable node/resource counts")
	check(created==pool.created and misses==pool.misses and cached==Shot.Effects.energy_textures.size(),"Longer flight and impacts reuse warmed leases and textures")
	times.sort();intervals.sort()
	var report={"checks":checks,"failures":failures,"pool_misses":pool.misses,"counts":counts,"step_p95_ms":times[int(times.size()*.95)]}
	if not intervals.is_empty():report.frame_p95_ms=intervals[int(intervals.size()*.95)];report.frame_max_ms=intervals[-1]
	FileAccess.open(SPLASH_OUT+"gameplay-"+DisplayServer.get_name()+".json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("WARCRAFT_SPLASH_GAMEPLAY_RESULT ",JSON.stringify(report))
	game.queue_free();await frames(3);DirAccess.remove_absolute(cfg);quit(1 if failures else 0)
