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
		if "--capture" in OS.get_cmdline_user_args():
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://build/Other Files/Asset Toolkit/Wave Groups/growth-settings.png")
		check(node("Core_starting_gold")!=null and node("Core_tower_health")!=null,"Core editor has economy and tower controls")
		check(node("Core_spawn_group_start").value==10 and node("Core_spawn_group_growth").value==1,"Existing saves default to groups of ten growing by one")
		node("Core_spawn_group_start").value=7
		node("Core_spawn_group_growth").value=2
		node("Core_starting_gold").value=321
		node("Core_tower_health").value=800
		node("Core_tower_damage").value=42
		node("Core_tower_attack_speed").value=2
		node("Core_tower_workers").value=1
		check(node("Core_bosses_per_portal")==null,"Boss counts live in each wave instead of a shared toggle")
		check(node("CoreEnemyBalance")!=null and node("Core_boss_health")==null,"Individual boss settings are reached through Enemy Balance")
		game.update_core_balance("boss_health",12345)
		game.update_core_balance("boss_speed",.75)
		node("Core_wave_count").value=2;await settle()
		for variant in range(8):node("Wave_1_enemy_%d"%variant).value=[2,1,3,4,5,6,7,0,0,0][variant]
		for variant in range(8):node("Wave_2_enemy_%d"%variant).value=0
		var original=game.core_balance.duplicate(true)
		var invalid=preload("res://scripts/forest/core_balance.gd").sanitized({"starting_gold":NAN,"tower_workers":999,"tower_attack_speed":-5,"waves":[[0,-3,INF,7]]})
		check(invalid.starting_gold==1000000 and invalid.tower_workers==24 and invalid.tower_attack_speed==.05 and invalid.waves[0]==preload("res://scripts/forest/core_balance.gd").split_legacy_wave([0,0,0,7],1),"Invalid and out-of-range config values are sanitized")
		var groups=preload("res://scripts/forest/core_balance.gd").sanitized({"spawn_group_start":-5,"spawn_group_growth":INF})
		check(groups.spawn_group_start==1 and groups.spawn_group_growth==1,"Group settings clamp invalid values and reject infinity")
		groups=preload("res://scripts/forest/core_balance.gd").sanitized({"spawn_group_start":10001,"spawn_group_growth":-1})
		check(groups.spawn_group_start==10000 and groups.spawn_group_growth==0,"Group settings enforce upper limits and allow fixed groups")
		game.resize_core_waves(50)
		check(game.core_balance.waves.size()==50 and game.core_balance.waves[0]==[2,1,3,4,5,6,7,0,0,0],"Growing the wave count preserves edited waves")
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
		check(game.model.gold==321 and game.model.balance.waves==[[2,1,3,4,5,6,7,0,0,0],[0,0,0,0,0,0,0,0,0,0]],"Play from title immediately uses saved starting gold and waves")
		check(game.model.balance.boss_health==12345 and game.model.balance.boss_speed==.75,"New runs snapshot all three edited portal boss settings")
		check(game.model.balance.spawn_group_start==7 and game.model.balance.spawn_group_growth==2,"New runs snapshot custom group sizes")
		game.show_pause();game.show_settings(true);game.show_core_balance(true);await settle()
		var escape=InputEventKey.new();escape.physical_keycode=KEY_ESCAPE;escape.pressed=true;game._input(escape);await settle()
		check(node("CharacterBalanceButton")!=null and game.ordinary_pause,"Escape returns from Core Balance to paused Settings")
		game.show_core_balance(true);await settle()
		node("Core_spawn_group_start").value=8
		node("Core_spawn_group_growth").value=0
		check(game.model.balance.spawn_group_start==7 and game.model.balance.spawn_group_growth==2,"Paused group edits leave the active run unchanged")
		node("Core_spawn_group_start").value=7
		node("Core_spawn_group_growth").value=2
		game.update_core_wave(0,0,9)
		check(game.model.balance.waves[0][0]==2,"Paused wave edits do not mutate the active run snapshot")
		game.update_core_wave(0,0,2)
		game.load_settings()
		check(game.core_balance.starting_gold==321 and game.core_balance.waves==[[2,1,3,4,5,6,7,0,0,0],[0,0,0,0,0,0,0,0,0,0]],"Core settings round-trip through disk")
		check(game.core_balance.boss_health==12345 and game.core_balance.boss_speed==.75,"Boss enable, health and fractional speed persist through disk")
		check(game.core_balance.spawn_group_start==7 and game.core_balance.spawn_group_growth==2,"Group size and growth persist through disk")
		game.model.reset(42,game.core_balance)
		var m=game.model
		check(m.gold==321,"New run uses configured starting gold")
		for b in m.buildings.values():
			if b.kind=="tower":check(b.hp==800 and m.workforce.capacity(b)==1,"Starter towers use tuned health and worker cap")
		check(m.start_wave() and m.waves.pending==28,"Wave one schedules exactly the configured total")
		for i in range(100):m.waves.spawn_one()
		var counts=[0,0,0,0,0,0,0,0,0,0]
		for e in m.enemies.values():counts[preload("res://scripts/forest/core_balance.gd").TYPES.find(e.variant)]+=1
		check(counts==[2,1,3,4,5,6,7,0,0,0] and m.waves.pending==0,"Every enemy preserves its own edited wave count")
		m.enemies.clear();m.waves.tick(.01,m.hero_position)
		check(m.phase=="preparing","Configured non-final wave returns to preparation")
		m.start_wave()
		check(m.waves.pending==0 and not m.waves.giant_pending,"An empty edited wave schedules no enemies")
		check(not m.waves.spawn_one() and m.enemies.is_empty() and m.balance.waves[1]==[0,0,0,0,0,0,0,0,0,0],"Empty wave stays empty without fallback enemies")
		m.enemies.clear();m.waves.pending=0;m.waves.tick(.01,m.hero_position)
		check(m.phase=="victory" and not m.start_wave(),"Victory uses the configured wave count")
		m.reset(42,{"bosses_per_portal":0,"waves":[[0,0,0,0]]});m.start_wave();m.waves.tick(.01,m.hero_position)
		check(m.phase=="victory","A zero-enemy final wave completes without stalling")
		# A real fired arrow consumes tuned cadence and damage.
		m.reset(42,game.core_balance);m.start_wave();m.waves.spawn_clock=10000
		var guard=m.workers.values().filter(func(w):return w.state=="garrison")[0]
		var enemy=m.waves.spawn_enemy(0,guard.pos+Vector3(0,0,15));m.update_vision(guard.pos)
		game.army_runtime.reset_world();game.army_runtime.import_arrivals()
		m.workforce.tick(.01,m.hero_position)
		check(is_equal_approx(guard.timer,.5) and not m.workforce.arrows.is_empty(),"Configured attack speed controls a real tower shot")
		m.workforce.tick_arrows(.5)
		game.army_runtime.sync_compatibility()
		check(enemy.hp==enemy.max_hp-42,"A real tower arrow applies configured damage")
		game.reset_core_balance()
		check(game.core_balance.spawn_group_start==10 and game.core_balance.spawn_group_growth==1,"Reset restores ten enemies and growth of one")
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
