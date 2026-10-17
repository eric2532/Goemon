extends SceneTree
var game
var checks=0
var failures=0
var config_path="user://core-balance-test-%d.cfg"%OS.get_process_id()
func _initialize():run.call_deferred()
func check(ok: bool,message: String):
	checks+=1
	if not ok:failures+=1;printerr("FAIL: "+message)
func settle():
	for i in range(4):await process_frame
func node(name_: String):return game.menu.find_child(name_,true,false)
func run():
	game=load("res://scenes/forest_shrine.tscn").instantiate();game.settings_path=config_path;root.add_child(game);current_scene=game
	await settle()
	var map_balance=game.forest_ui.find_child("PreparationBalance",true,false)
	check(map_balance!=null,"Building map exposes Core Game Balance")
	if map_balance!=null:
		map_balance.pressed.emit();await settle()
		check(node("Core_starting_gold")!=null and node("Core_tower_health")!=null,"Core editor has economy and tower controls")
		node("Core_starting_gold").value=321
		node("Core_tower_health").value=800
		node("Core_tower_damage").value=42
		node("Core_tower_attack_speed").value=2
		node("Core_tower_workers").value=1
		node("Core_wave_count").value=2;await settle()
		for variant in range(4):node("Wave_1_enemy_%d"%variant).value=[2,1,0,3][variant]
		for variant in range(4):node("Wave_2_enemy_%d"%variant).value=[0,0,2,0][variant]
		var original=game.core_balance.duplicate(true)
		var invalid=preload("res://scripts/forest/core_balance.gd").sanitized({"starting_gold":NAN,"tower_workers":999,"tower_attack_speed":-5,"waves":[[0,-3,INF,7]]})
		check(invalid.starting_gold==1000000 and invalid.tower_workers==24 and invalid.tower_attack_speed==.05 and invalid.waves[0]==[0,0,0,7],"Invalid and out-of-range config values are sanitized")
		game.resize_core_waves(50)
		check(game.core_balance.waves.size()==50 and game.core_balance.waves[0]==[2,1,0,3],"Growing the wave count preserves edited waves")
		game.resize_core_waves(2)
		check(game.core_balance==original,"Shrinking waves preserves retained settings")
		var tower=game.model.buildings.values().filter(func(b):return b.kind=="tower")[0]
		game.update_core_balance("tower_workers",3)
		game.model.workforce.assign_workers(tower.id)
		check(game.model.workforce.count_job(tower.id)==3,"An increased worker cap permits a real tower crew")
		game.update_core_balance("tower_workers",1)
		check(game.model.workforce.count_job(tower.id)==1,"Reducing the live cap releases surplus workers")
		tower.hp=400
		node("Core_tower_health").value=1000
		check(tower.max_hp==1000 and tower.hp==500,"Live tower health tuning preserves damage percentage")
		node("Core_tower_health").value=800
		game.show_title();game.begin_forest();game.choose_rogue_character(1)
		check(game.model.gold==321 and game.model.balance.waves==[[2,1,0,3],[0,0,2,0]],"Play from title immediately uses saved starting gold and waves")
		game.show_pause();game.show_settings(true);game.show_core_balance(true);await settle()
		var escape=InputEventKey.new();escape.physical_keycode=KEY_ESCAPE;escape.pressed=true;game._input(escape);await settle()
		check(node("CharacterBalanceButton")!=null and game.ordinary_pause,"Escape returns from Core Balance to paused Settings")
		game.show_core_balance(true);await settle()
		game.update_core_wave(0,0,9)
		check(game.model.balance.waves[0][0]==2,"Paused wave edits do not mutate the active run snapshot")
		game.update_core_wave(0,0,2)
		game.load_settings()
		check(game.core_balance.starting_gold==321 and game.core_balance.waves==[[2,1,0,3],[0,0,2,0]],"Core settings round-trip through disk")
		game.model.reset(42,game.core_balance)
		var m=game.model
		check(m.gold==321,"New run uses configured starting gold")
		for b in m.buildings.values():
			if b.kind=="tower":check(b.hp==800 and m.workforce.capacity(b)==1,"Starter towers use tuned health and worker cap")
		check(m.start_wave() and m.waves.pending==6,"Wave one schedules exactly the configured total")
		for i in range(100):m.waves.spawn_one()
		var counts=[0,0,0,0]
		for e in m.enemies.values():counts[e.variant]+=1
		check(counts==[2,1,0,3] and m.waves.pending==0,"Spawned enemy types match the edited wave exactly")
		m.enemies.clear();m.waves.tick(.01,m.hero_position)
		check(m.phase=="preparing","Configured non-final wave returns to preparation")
		m.start_wave()
		check(m.waves.pending==2 and m.waves.giant_pending,"Multiple-giant wave is scheduled")
		m.waves.spawn_one();m.enemies.values()[0].pos=Vector3.ZERO;m.waves.spawn_one()
		check(m.enemies.size()==2 and m.enemies.values().all(func(e):return e.variant==2),"All configured Daruma spawn")
		m.enemies.clear();m.waves.pending=0;m.waves.tick(.01,m.hero_position)
		check(m.phase=="victory" and not m.start_wave(),"Victory uses the configured wave count")
		m.reset(42,{"waves":[[0,0,0,0]]});m.start_wave();m.waves.tick(.01,m.hero_position)
		check(m.phase=="victory","A zero-enemy final wave completes without stalling")
		# A real fired arrow consumes tuned cadence and damage.
		m.reset(42,game.core_balance);m.start_wave();m.waves.spawn_clock=10000
		var guard=m.workers.values().filter(func(w):return w.state=="garrison")[0]
		var enemy=m.waves.spawn_enemy(0,guard.pos+Vector3(0,0,15));m.update_vision(guard.pos)
		m.workforce.tick(.01,m.hero_position)
		check(is_equal_approx(guard.timer,.5) and not m.workforce.arrows.is_empty(),"Configured attack speed controls a real tower shot")
		m.workforce.tick_arrows(.5)
		check(enemy.hp==enemy.max_hp-42,"A real tower arrow applies configured damage")
	game.show_title();game.begin_forest();game.choose_rogue_character(1);game.start_wave();game.model.waves.spawn_clock=10000
	game.set_physics_process(false);game.player.smoke_mode=true;game.player.smoke_move=Vector2.ZERO
	for fighter in range(1,13):
		game.player.select_character(fighter)
		for point in [Vector3(175,.1,75),Vector3(-175,.1,75),Vector3(75,.1,175),Vector3(75,.1,-175)]:
			game.player.position=point;game.player.velocity=Vector3.ZERO;var hp=game.player.hp
			await physics_frame;await physics_frame
			check(game.player.position.distance_to(game.checkpoint)>50,"Crossing an edge does not teleport to base")
			check(game.world.playable_bounds.has_point(Vector2(game.player.position.x,game.player.position.z)),"Hero remains inside playable bounds")
			check(game.player.hp==hp,"Boundary does not apply sanctuary damage")
		game.player.position=Vector3(75,-8,75);game.player.velocity=Vector3.ZERO
		await physics_frame;await physics_frame
		check(Vector2(game.player.position.x,game.player.position.z).distance_to(Vector2(75,75))<1 and game.player.position.y>=0,"Falling recovers locally instead of returning to base")
	game.sound_library.cancel();game.music.stop();game.queue_free();paused=false;await settle()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(config_path))
	print("CORE_BALANCE_RESULT checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)
