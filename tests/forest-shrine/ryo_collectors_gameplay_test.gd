extends SceneTree
const GuardFixture=preload("res://tests/forest-shrine/guard_combat_fixture.gd")
## Real scene regressions for immediate ally, model and cleanup rewards.
var game
var m
var checks=0
var failures=0
var config_path="user://ryo-collectors-%d.cfg"%OS.get_process_id()
var helper
var guard
var worker:Dictionary
var visual=false
func _initialize():
	create_timer(150).timeout.connect(func():printerr("FAIL: ryo collectors timeout");quit(1))
	run.call_deferred()
func check(ok:bool,message:String):
	checks+=1
	if not ok:failures+=1;printerr("FAIL: "+message)
func frames(count:int=3):
	for i in range(count):await physics_frame
func sync_collectors():
	game.gate_defenders.sync_model()
	game.explorer_helpers.sync_targets()
func tick(seconds:float):
	sync_collectors();game._tick_ryo(seconds)
func collect():
	for i in range(30):tick(.05)
func spawn(point:Vector3,variant:int=0)->Dictionary:
	var enemy:Dictionary=m.waves.spawn_enemy(variant,point)
	game.sync_enemies()
	for actor in game.actors.values():
		if is_instance_valid(actor):actor.set_physics_process(false)
	return enemy
func model_kill(point:Vector3)->Dictionary:
	var enemy=spawn(point);m.damage_enemy(enemy.id,100000)
	return enemy
func park_workers():
	for w in m.workers.values():
		w.pos=Vector3(-100,0,0);w.hp=w.max_hp;w.state="idle";w.job=-1;w.follow=false;w.deck_height=0.0
func capture(name_:String,focus:Vector3,offset:Vector3=Vector3(7,6,13)):
	if not visual:return
	game.camera_rig.set_process(false);game.camera_rig.set_physics_process(false)
	game.camera_rig.camera.global_position=focus+offset
	game.camera_rig.camera.look_at(focus+Vector3.UP*1.5)
	sync_collectors();m.update_vision(game.player.global_position);game.world.sync(.08)
	game.forest_ui.sync()
	await frames(4);await RenderingServer.frame_post_draw
	var folder=OS.get_environment("FOREST_RYO_CAPTURE_DIR")
	if folder.is_empty():folder=ProjectSettings.globalize_path("res://build/Other Files/ryo-repairs")
	DirAccess.make_dir_recursive_absolute(folder)
	var path=folder.path_join(name_+".png");root.get_texture().get_image().save_png(path)
	print("RYO_COLLECTOR_CAPTURE "+path)
func run():
	visual="--visual" in OS.get_cmdline_user_args()
	var document=load("res://scripts/forest/forest_map_document.gd").new();document.load_original()
	set_meta("forest_army_backend","legacy");set_meta("forest_custom_layout",document.data);set_meta("forest_painterly_preview",true)
	game=load("res://scenes/forest_shrine.tscn").instantiate();game.settings_path=config_path
	root.add_child(game);current_scene=game;await frames()
	game.set_process(false);game.set_physics_process(false);game.player.set_physics_process(false)
	game.gate_defenders.settings_path=config_path+"-defenders"
	game.gate_defenders.assignments.clear();game.gate_defenders.reconcile(true)
	m=game.model;m.gold=1000
	check(m.buildings.values().all(func(b):return b.kind!="mine") and m.deposits.is_empty(),"The playable original map has no passive gold mines")
	check(not game.gate_defenders.units.is_empty(),"The fixture has a real gate defender")
	game.player.select_character(2)
	check(GuardFixture.deploy(game.explorer_helpers,4),"A real helper request creates living Explorer allies")
	var helpers:Array=game.explorer_helpers.active_units(4)
	if helpers.is_empty() or game.gate_defenders.units.is_empty():await finish();return
	helper=helpers[0]
	for unit in helpers:
		if unit!=helper:unit.park()
	game.start_wave();m.waves.spawn_clock=10000;m.waves.pending=1
	game.set_physics_process(false);game.player.set_physics_process(false)
	game.player.position=Vector3(0,.15,120);park_workers()
	for unit in game.gate_defenders.units.values():
		unit.set_physics_process(false);unit.position=Vector3(100,.15,0)
	guard=game.gate_defenders.units.values()[0]
	helper.global_position=Vector3(0,.12,70);helper.set_physics_process(false)
	sync_collectors()
	var victim=spawn(Vector3(8,0,70))
	var ticket:Dictionary=helper.attack_chain.begin("ryo_test")
	game.actors[victim.id].take_hit(float(victim.hp)+1,Vector3.RIGHT,false,ticket)
	check(game.actors[victim.id].dead and victim.hp<=0 and m.gold==1012 and m.ryo.drops.is_empty(),"An actual ally-attributed actor kill immediately credits twelve ryo")
	m.damage_enemy(victim.id,100000);tick(.2)
	check(m.gold==1012,"Model cleanup after an ally kill cannot duplicate its reward")
	helper.park();guard.position=Vector3(0,.15,70);sync_collectors()
	model_kill(Vector3(100,0,100))
	check(m.gold==1024,"Model and defense damage pays even far from all collectors")
	guard.invuln=0;guard.take_hit(100000,Vector3.RIGHT)
	model_kill(Vector3(0,0,78));collect()
	check(guard.hp<=0 and m.gold==1036,"An incapacitated defender cannot delay or lose a kill reward")
	worker=m.workers.values()[0];m.damage_worker(worker.id,10000)
	model_kill(Vector3(0,0,78))
	check(worker.state=="wounded" and m.gold==1048,"Wounded workers do not affect automatic rewards")
	m.workforce.recover();worker.state="garrison"
	model_kill(Vector3(0,0,70))
	check(m.gold==1060,"Elevated tower crew do not affect automatic rewards")
	var wall:Dictionary={}
	for b in m.buildings.values():
		if b.kind=="wall" and b.rotation==0 and b.cell==Vector2i(-7,7):wall=b;break
	check(not wall.is_empty(),"The original castle wall remains in the scene")
	if wall.is_empty():await finish();return
	var center:Vector3=m.center(wall)
	worker.pos=center+Vector3(0,0,-3.5)
	var blocked=spawn(center+Vector3(0,0,3.5));blocked.hp=0
	m.waves.tick(.02,game.player.position)
	check(not m.enemies.has(blocked.id) and m.gold==1072,"Wave cleanup catches an authoritative zero-HP death exactly once")
	collect();m.waves.tick(.02,game.player.position)
	check(m.gold==1072 and m.ryo.drops.is_empty(),"Repeated cleanup and a wall between units cannot duplicate or block money")
	model_kill(Vector3(0,0,76));game.show_pause();tick(3)
	check(m.gold==1084,"Pausing after a kill retains its immediate reward")
	game.resume();game.settings_open=true;tick(3);game.settings_open=false;collect()
	check(m.gold==1084 and m.ryo.pending_bounty_total==0,"Overlays retain money and feedback drains once after resuming")
	check(not is_instance_valid(game.ryo_visuals),"No physical coin renderer is allocated")
	if visual:
		worker.pos=m.point(wall.cell+Vector2i(2,-1));worker.state="idle";worker.job=-1
		for w in m.workers.values():w.follow=w.id!=worker.id
		m.damage_building(wall.id,400)
		var before=wall.hp;var gold_before=m.gold
		m.workforce.assignment_clock=0
		for i in range(20):m.workforce.tick(.05,game.player.position)
		check(wall.hp>before and m.gold<gold_before and is_equal_approx(wall.hp-before,(gold_before-m.gold)*10.0),"The captured worker repair visibly spends the earned shared ryo")
		await capture("worker-repair-earned-ryo",m.point(wall.cell+Vector2i(2,-1)),Vector3(7,6,-12))
	await finish()
func finish():
	print("RYO_COLLECTORS_GAMEPLAY_RESULT checks=%d failures=%d"%[checks,failures])
	if is_instance_valid(game):
		game.sound_library.cancel();game.music.stop()
		for voice in game.voices:voice.stop()
		game.queue_free()
	paused=false;await frames();await create_timer(.35).timeout
	for path in [config_path,config_path+"-defenders"]:
		if FileAccess.file_exists(path):DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	quit(1 if failures else 0)
