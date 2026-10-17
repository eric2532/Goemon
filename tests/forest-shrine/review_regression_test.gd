extends SceneTree
var failures=0
var checks=0
func check(ok: bool,message: String):
	checks+=1
	if not ok:failures+=1;printerr("FAIL: "+message)
func _initialize():
	create_timer(30).timeout.connect(func():printerr("FAIL: review regression timeout");quit(1))
	call_deferred("run")
func run():
	var m=load("res://scripts/forest/forest_model.gd").new();preload("res://tests/forest-shrine/empty_settlement.gd").reset(m);m.gold=10000;m.update_vision(m.point(Vector2i(6,4)))
	var wall=m.build("wall",Vector2i(4,5),0);wall.hp=100
	check(m.workforce.assign_idle(wall.id)==2,"Damaged wall reserves two repairers")
	var seal=m.build("wall",Vector2i(4,6),0)
	check(seal.is_empty(),"Construction cannot seal the entrance of an assigned repair job")
	m.start_wave();m.waves.spawn_clock=10000
	for i in range(100):m.tick(.1,m.hero_position)
	check(wall.hp>100,"Reserved repairers still reach and repair their wall")
	preload("res://tests/forest-shrine/empty_settlement.gd").reset(m);m.gold=10000;m.update_vision(m.point(Vector2i(6,4)))
	var tower=m.build("tower",Vector2i(4,5),0);m.workforce.assign_idle(tower.id);m.start_wave();m.waves.spawn_clock=10000
	for i in range(150):m.tick(.1,m.hero_position)
	var worker=m.workers.values()[0];var origin: Vector3=worker.pos;var entrance=m.point(m.entry(tower))
	check(worker.state=="garrison","Tower crew reaches the archer deck")
	m.waves.spawn_one();var target=m.enemies.values()[0];target.pos=origin+Vector3(0,0,20);target.stun=100
	var target_hp=target.hp;m.update_vision(m.hero_position);m.workforce.tick(.1,m.hero_position)
	for i in range(10):m.workforce.tick(.05,m.hero_position)
	check(target.hp<target_hp and m.events.any(func(e):return e.kind=="arrow"),"Staffed towers shoot arrows and damage a visible raider")
	m.enemies.clear()
	m.rally(true,origin);m.workforce.tick(.1,Vector3(0,0,30))
	var expected=(entrance-origin).normalized();var motion=(worker.pos-origin).normalized()
	check(motion.dot(expected)>.999 and worker.pos.distance_to(origin)<1.5,"Recalled crew first walks toward the designated entrance without teleporting")
	check(worker.get("deck_height",0)>0 and worker.get("deck_height",9)<8.8,"Tower recall descends gradually instead of dropping to ground")
	var visited=false
	for i in range(100):
		m.workforce.tick(.05,Vector3(0,0,30))
		if worker.pos.distance_to(entrance)<.5:visited=true
	check(visited,"Recalled crew passes through the tower entrance before following")
	var game=load("res://scenes/forest_shrine.tscn").instantiate();root.add_child(game);current_scene=game
	await process_frame;await process_frame
	game.start_wave()
	var key=InputEventKey.new();key.physical_keycode=KEY_V;key.pressed=true
	game._input(key);check(game.model.workforce.held,"Fresh V press starts a rally")
	game.show_pause();game.resume();key.echo=true;game._input(key)
	check(not game.model.workforce.held,"Key repeat cannot restart canceled rally after pause")
	key.pressed=false;key.echo=false;game._input(key);key.pressed=true;game._input(key)
	check(game.model.workforce.held,"A fresh press after release can rally again")
	game.model.workforce.cancel_rally()
	game.model.phase="preparing";game.set_phase_view()
	game.player.position=Vector3(114,.1,0);game.model.update_vision(game.player.position)
	var gate=game.model.build("gate",Vector2i(20,0),1);game.world.sync(0)
	check(not gate.is_empty(),"Fog regression fixture has a real gate")
	game.start_wave();game.model.waves.spawn_clock=10000;game.model.waves.spawn_one()
	var enemy=game.model.enemies.values()[0];enemy.pos=Vector3(132,0,0);enemy.stun=100;game.sync_enemies()
	await physics_frame;await physics_frame
	game.model.update_vision(game.player.position);game.rogue_feedback.clear()
	check(not game.model.visible_at(enemy.pos),"Closed gate hides the raider beyond it")
	var chain=game.player.chain_pipe_combat;chain.direction=Vector3.RIGHT;chain.damage=10
	var hp=enemy.hp;chain.hit_path(Vector3(114,1.2,0),Vector3(133,1.2,0))
	check(enemy.hp<hp,"The real chain can pass through the friendly gate")
	check(game.rogue_feedback.active_count==0,"Chain impacts do not reveal hidden enemies")
	game.queue_free();paused=false;await process_frame;await create_timer(.35).timeout
	print("FOREST_REVIEW_RESULT checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)
