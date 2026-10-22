extends SceneTree
## Catches missing HP scaling, unscaled arrows, and edits leaking into active waves.
const Model=preload("res://scripts/forest/forest_model.gd")
var game
var checks=0
var failures=0
var cfg="user://enemy-strength-%d.cfg"%OS.get_process_id()
func _initialize():run.call_deferred()
func check(ok:bool,message:String):
	checks+=1
	if not ok:failures+=1;printerr("FAIL: "+message)
func fresh(config:Dictionary={}):
	var m=Model.new();m.reset(42,config);m.trees.clear();m.workers.clear()
	for building in m.buildings.values():
		if building.id!=1:m._remove_building(building.id)
	m.rebuild_navigation()
	m.start_wave();m.waves.spawn_clock=100000
	return m
func frames(n=3):
	for i in n:await process_frame
func run():
	var m=fresh()
	var walk_speeds=[7.2,6.0,.9,12.0,1.8]
	for role in 5:
		m=fresh()
		for z in range(10,27):
			for x in range(-3,4):m.roads[Vector2i(x,z)]=true
		var walker=m.waves.spawn_enemy(role,Vector3(0,0,150));walker.facing=0;walker.road_path=[]
		for z in range(24,9,-1):walker.road_path.append(Vector2i(0,z))
		var distance=0.0
		for frame in 60:
			var before:Vector3=walker.pos;m.waves.tick_enemy(walker,1.0/60,Vector3(0,0,80));distance+=before.distance_to(walker.pos)
		print("ENEMY_WALK_SPEED role=",role," metres_per_second=",distance)
		check(absf(distance-walk_speeds[role])<.01,"Role %d actually walks 20 percent faster, including both giant types"%role)
		if role==2:
			var before:Vector3=walker.pos;walker.turn_escape=[before+Vector3.BACK*6]
			m.waves.retreat_tick(walker,1.0)
			check(absf(walker.pos.distance_to(before)-.9)<.01,"Daruma obstruction retreat uses the same faster walk speed")
	m=fresh({"enemy_speed_mult":2.0,"boss_speed":1.25})
	check(m.waves.role_stats(0).speed==12 and m.waves.role_stats(4).speed==2.5,"Shared movement tuning also scales customized boss speeds")
	m=fresh()
	var health=[900,195,9000,165,72000]
	for role in 5:
		var enemy=m.waves.spawn_enemy(role,Vector3(60,0,60))
		check(enemy.hp==health[role] and enemy.max_hp==health[role],"Role %d spawns with tripled authoritative health"%role)
		m.damage_enemy(enemy.id,25)
		check(enemy.hp==health[role]-25,"Role %d keeps real damage on its scaled health pool"%role)
	m=fresh();var hero=Vector3(0,0,80)
	var raider=m.waves.spawn_enemy(0,Vector3(0,0,83))
	m.waves.start_attack(raider,"hero",0,hero);m.events.clear();m.waves.attack_tick(raider,.5,hero)
	check(not m.events.any(func(e):return e.kind=="hero_hit"),"Stronger melee keeps its readable windup")
	m.waves.attack_tick(raider,.1,hero)
	check(m.events.any(func(e):return e.kind=="hero_hit" and e.amount==36),"Raider contact delivers doubled damage")
	m.events.clear();m.defenders[101]={"id":101,"pos":hero,"hp":200,"targetable":true}
	m.waves.start_attack(raider,"defender",101,hero);m.waves.attack_tick(raider,.6,hero)
	check(m.events.any(func(e):return e.kind=="defender_hit" and e.id==101 and e.amount==36),"Summoned defenders receive the same stronger melee damage")
	m=fresh();var archer=m.waves.spawn_enemy(1,Vector3(0,0,90))
	m.waves.arrows.launch(m.waves.projectiles,archer,"hero",0,hero+Vector3.UP*1.3)
	check(m.events.all(func(e):return e.kind!="hero_hit"),"A stronger arrow still travels before impact")
	m.waves.arrows.tick(m.waves.projectiles,.5,hero)
	check(m.events.any(func(e):return e.kind=="hero_hit" and e.amount==40 and e.get("projectile",false)),"Traveling archer projectiles deliver doubled damage")
	m=fresh();var wall=m._make_building("wall",Vector2i(-3,5),0);m.rebuild_navigation()
	var wall_health:float=wall.hp
	var giant=m.waves.spawn_enemy(2,Vector3(0,0,42));giant.facing=0
	m.waves.start_attack(giant,"building",wall.id,hero);m.waves.attack_tick(giant,1.6,hero)
	check(wall.hp==wall_health-240,"A deliberate giant strike removes exactly 240 health from the current wall")
	m=fresh({"boss_health":30000,"waves":[[2,1,0,3]]})
	check(m.waves.spawn_enemy(4,Vector3.ZERO).hp==90000 and m.balance.waves==[[2,1,0,3]],"Older saved balances gain stronger enemies while preserving boss tuning and wave composition")
	m=fresh({"enemy_health_mult":.5,"enemy_damage_mult":1.5})
	check(m.waves.spawn_enemy(0,Vector3.ZERO).hp==150,"Fractional health tuning reaches actual spawned enemies")
	hero=Vector3(0,0,80);archer=m.waves.spawn_enemy(1,Vector3(0,0,90))
	m.waves.arrows.launch(m.waves.projectiles,archer,"hero",0,hero+Vector3.UP*1.3);m.waves.arrows.tick(m.waves.projectiles,.5,hero)
	check(m.events.any(func(e):return e.kind=="hero_hit" and e.amount==30),"Fractional damage tuning reaches actual traveling arrows")
	m=fresh({"enemy_health_mult":0,"enemy_damage_mult":INF})
	check(m.waves.spawn_enemy(0,Vector3.ZERO).hp==75,"Invalid health input cannot create zero-health enemies")
	var saved=ConfigFile.new();saved.set_value("core_balance","values",{"boss_health":30000,"waves":[[2,1,0,3],[2,1,0,3]]});saved.save(cfg)
	game=load("res://scenes/forest_shrine.tscn").instantiate();game.settings_path=cfg;root.add_child(game);current_scene=game;await frames()
	game.show_building_balance();await frames()
	var health_control=game.menu.find_child("Core_enemy_health_mult",true,false)
	var damage_control=game.menu.find_child("Core_enemy_damage_mult",true,false)
	var speed_control=game.menu.find_child("Core_enemy_speed_mult",true,false)
	check(health_control!=null and damage_control!=null,"Building Balance exposes enemy health and damage controls")
	check(speed_control!=null,"Building Balance exposes shared enemy movement tuning")
	if health_control!=null and damage_control!=null and speed_control!=null:
		health_control.value=4;damage_control.value=2.5;speed_control.value=1.4;game.load_settings()
		check(game.core_balance.enemy_health_mult==4 and game.core_balance.enemy_damage_mult==2.5 and game.core_balance.boss_health==30000,"Enemy tuning saves without discarding existing balance settings")
		check(is_equal_approx(game.core_balance.enemy_speed_mult,1.4),"Enemy movement tuning persists through disk")
		game.resume();game.start_wave();game.set_physics_process(false);game.player.set_physics_process(false);game.model.waves.spawn_clock=100000
		var e=game.model.waves.spawn_enemy(0,Vector3(0,0,80));game.sync_enemies()
		var actor=game.actors[e.id];actor.set_physics_process(false);actor._physics_process(0)
		check(actor.hp==1200 and actor.max_hp==1200,"Building-view health edits apply to the next wave's real combat actor")
		check(game.model.waves.role_stats(0).damage==45,"Building-view damage edits apply to the next wave")
		check(is_equal_approx(game.model.waves.role_stats(0).speed,8.4),"Building-view speed edits apply to the next wave")
		game.update_core_balance("enemy_health_mult",5);game.update_core_balance("enemy_damage_mult",3)
		game.update_core_balance("enemy_speed_mult",1.8)
		check(e.hp==1200 and game.model.waves.role_stats(0).damage==45,"Editing during a wave cannot heal enemies or silently change their damage")
		check(is_equal_approx(game.model.waves.role_stats(0).speed,8.4),"Editing speed during combat cannot change an active wave")
		game.model.enemies.clear();game.model.phase="preparing";game.set_phase_view();game.start_wave()
		check(game.model.waves.spawn_enemy(0,Vector3.ZERO).hp==1500 and game.model.waves.role_stats(0).damage==54,"The following wave adopts saved edits")
		check(is_equal_approx(game.model.waves.role_stats(0).speed,10.8),"The following wave adopts saved movement speed")
	game.sound_library.cancel();game.music.stop()
	for kind in ["AudioStreamPlayer","AudioStreamPlayer3D","AudioStreamPlayer2D"]:
		for voice in game.find_children("*",kind,true,false):voice.stop()
	OS.delay_msec(120);game.queue_free();paused=false;await frames()
	if FileAccess.file_exists(cfg):DirAccess.remove_absolute(ProjectSettings.globalize_path(cfg))
	print("ENEMY_STRENGTH_RESULT checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)
