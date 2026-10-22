extends SceneTree
const GuardFixture=preload("res://tests/forest-shrine/guard_combat_fixture.gd")
## A recoverable player death must not retire surviving allied fighters.
var game
var checks=0
var failures=0
var cfg="user://helper-respawn-%d.cfg"%OS.get_process_id()
func _initialize():
	create_timer(90).timeout.connect(func():printerr("FAIL: helper respawn timeout");quit(1))
	run.call_deferred()
func check(ok:bool,message:String):
	checks+=1
	if not ok:failures+=1;printerr("FAIL: "+message)
func frames(count:int=3):
	for i in count:await process_frame
func freeze():
	game.set_physics_process(false);game.player.set_physics_process(false);game.camera_rig.set_process(false)
	for unit in game.gate_defenders.units.values():unit.set_physics_process(false)
	for unit in game.explorer_helpers.pool:unit.set_physics_process(false)
	for enemy in game.actors.values():enemy.set_physics_process(false)
func step(count:int):
	for i in count:
		for unit in game.explorer_helpers.pool:
			if unit.state!="idle":
				unit._physics_process(1.0/60)
				unit.active_ability.fx.tick(1.0/60)
		game.explorer_helpers.sync_targets()
		game.explorer_helpers._process(1.0/60)
		if i%20==0:
			game.model.update_vision(game.player.position)
			await process_frame
			freeze()
func run():
	var document=load("res://scripts/forest/forest_map_document.gd").new()
	document.load_original();set_meta("forest_custom_layout",document.data)
	game=load("res://scenes/forest_shrine.tscn").instantiate();game.settings_path=cfg
	root.add_child(game);current_scene=game;await frames()
	var hero=game.player;var helpers=game.explorer_helpers
	hero.select_character(11);hero.position=Vector3(0,.15,60)
	game.start_wave();game.model.waves.pending=999;game.model.waves.spawn_clock=100000
	freeze();game.model.update_vision(hero.position)
	var target=game.model.waves.spawn_enemy(0,Vector3(0,0,52))
	target.hp=1000000000;target.max_hp=1000000000;target.stun=100
	game.sync_enemies();await frames();freeze()
	for enemy in game.actors.values():enemy._sync_fitted_pose()
	check(GuardFixture.deploy(helpers,1),"The live battle summons one Ranger helper")
	freeze()
	var survivors=helpers.active_units(1).duplicate()
	check(survivors.size()==1,"The fixture has one living ally")
	if survivors.size()!=1:await finish();return
	await step(100)
	check(target.hp<1000000000,"The live ally fixture deals native ranged damage before player death")
	var hp_before=target.hp
	hero.invuln=0;hero.hp=1;game.tuning.invincible=false
	hero.take_hit(100000,Vector3.RIGHT)
	check(hero.hp<=0 and game.respawn_left>0 and game.model.phase=="wave","Fatal damage starts a recoverable death during the running battle")
	helpers._process(1.0/60)
	check(helpers.active_units(1)==survivors,"Player death preserves the same surviving helper instances")
	check(not helpers.request(1),"The dead player cannot summon additional allies")
	await step(120)
	check(survivors.all(func(unit):return unit.state=="acting" and unit.visible and unit.hp>0),"Surviving allies remain active during the respawn countdown")
	check(target.hp<hp_before,"Allies keep dealing native combat damage while the player is dead")
	check(survivors.all(func(unit):return game.model.defenders.has(unit.gate_id)),"Surviving allies remain registered as enemy targets")
	game._tick_player_respawn(4)
	helpers._process(0)
	check(hero.hp==hero.max_hp and helpers.active_units(1)==survivors,"Respawn preserves the army without replacing its members")
	game.model.phase="defeat";game.set_phase_view();helpers._process(0)
	check(helpers.active_units().is_empty() and survivors.all(func(unit):return unit.state=="idle"),"Castle defeat still retires all helper fighters")
	game.model.phase="preparing";game.set_phase_view();hero.position=Vector3(0,.15,60)
	check(GuardFixture.deploy(helpers,1),"Preparation can create a fresh group after the terminal-state fixture")
	game.show_title();helpers._process(0)
	check(helpers.active_units().is_empty(),"Returning to the title still clears the helper army")
	await finish()
func finish():
	game.sound_library.cancel();game.music.stop()
	game.queue_free();paused=false;await frames()
	if FileAccess.file_exists(cfg):DirAccess.remove_absolute(ProjectSettings.globalize_path(cfg))
	print("HELPER_RESPAWN_RESULT checks=%d failures=%d"%[checks,failures])
	quit(1 if failures else 0)
