extends SceneTree
var checks=0
var failures=0
var game: Node
var run: Node
func _initialize():run_tests.call_deferred()
func check(ok: bool,label: String):
	checks+=1
	if not ok:failures+=1;push_error("FAIL: "+label)
func run_tests():
	game=load("res://scenes/main.tscn").instantiate();game.smoke_test=true;root.add_child(game)
	game.tuning.freeze_ai=true;game.tuning.invincible=true;game.start_mode("defense")
	game.player.set_physics_process(false);run=game.encounters;run.set_physics_process(false);await physics_frame
	var tower=run.site_states[4].cannon
	check(tower.has_method("upgrade_to_ice"),"Tower exposes a deliberate ice conversion")
	if not tower.has_method("upgrade_to_ice"):finish();return
	run.update_start_input(0,false);run.update_start_input(3,true);run.tick(.2)
	var enemy=game.enemies.filter(func(e):return is_instance_valid(e) and not e.dead)[0];enemy.set_physics_process(false)
	tower.complete_build();enemy.position=tower.position+Vector3(0,0,12);await physics_frame
	tower._fire_at(enemy);check(tower.shells.size()==1,"Level one fires an arrow")
	check(tower.upgrade_to_ice() and tower.level==2 and tower.attack_type()==&"ice","Level two is a slow-only ice tower")
	check(tower.shells.is_empty() and not tower.upgrade_to_ice(),"Conversion cancels old arrows and cannot repeat")
	var kills=game.kills;var xp=game.player.progression.total_kills
	tower._fire_at(enemy);tower._tick_arrows(.5)
	check(enemy.hp==100 and enemy.stun==0 and not enemy.dead and game.kills==kills and game.player.progression.total_kills==xp,"Ice causes no damage, stun, kill or hero credit")
	check(is_equal_approx(enemy.defense_slow_multiplier(),.6),"Ice slows movement forty percent")
	var slowed=travel(enemy)
	enemy.defense_traits.tick_status(2)
	check(is_equal_approx(enemy.defense_slow_multiplier(),1),"Slow expires after two seconds")
	var ordinary=travel(enemy)
	check(slowed>.1 and ordinary>slowed*1.4 and ordinary<slowed*1.9,"Real enemy walking distance is reduced by ice")
	enemy.apply_defense_slow(.6,2);enemy.defense_traits.tick_status(.5);enemy.apply_defense_slow(.6,2)
	check(is_equal_approx(enemy.defense_slow_multiplier(),.6) and is_equal_approx(enemy.defense_traits.slow_left,2),"Repeated ice refreshes without multiplying")
	enemy.defense_boss_tier=1;enemy.defense_traits.slow_left=0;enemy.apply_defense_slow(.6,2)
	check(enemy.defense_slow_multiplier()>=.75 and enemy.defense_traits.slow_left==1,"Boss retains existing slow resistance")
	enemy.defense_boss_tier=0;enemy.defense_traits.tick_status(2)
	enemy.position=tower.position+Vector3(0,0,12)
	var wall=StaticBody3D.new();var collider=CollisionShape3D.new();var shape=BoxShape3D.new();shape.size=Vector3(8,8,.5)
	collider.shape=shape;wall.add_child(collider);wall.position=tower.position+Vector3(0,3,6);game.add_child(wall);await physics_frame
	tower._fire_at(enemy);tower._tick_arrows(.5)
	check(enemy.defense_slow_multiplier()==1 and tower.shells.is_empty(),"Cover blocks ice impact")
	wall.free();await physics_frame
	tower._fire_at(enemy);tower.shells[0].age=3.1;tower._tick_arrows(.001)
	check(enemy.defense_slow_multiplier()==1 and tower.shells.is_empty(),"Expired shot applies no slow")
	tower._fire_at(enemy);run.runtime.generation+=1;tower._tick_arrows(.5);run.runtime.generation-=1
	check(enemy.defense_slow_multiplier()==1 and tower.shells.is_empty(),"Retired generation applies no slow")
	tower._fire_at(enemy);run.wave+=1;tower._tick_arrows(.5);run.wave-=1
	check(enemy.defense_slow_multiplier()==1 and tower.shells.is_empty(),"Retired wave applies no slow")
	tower._fire_at(enemy);enemy.dead=true;tower._tick_arrows(.5);enemy.dead=false
	check(enemy.defense_slow_multiplier()==1 and tower.shells.is_empty(),"Dead target receives no slow")
	for i in range(1000):tower._fire_at(enemy);tower._tick_arrows(.5);tower.ice_effects.tick(.5)
	check(tower.ice_effects.visuals.size()<=4 and tower.shells.is_empty(),"One thousand shots reuse at most four flight visuals")
	check(tower.ice_effects.root.find_children("*","Light3D",true,false).is_empty() and tower.ice_effects.root.find_children("*","GPUParticles3D",true,false).is_empty(),"Ice effect adds no lights or particle emitters")
	for i in range(10):tower._fire_at(enemy)
	check(tower.shells.size()<=4,"Pool exhaustion skips visuals without unbounded growth")
	tower.retire_wave_effects();check(tower.shells.is_empty(),"Lifecycle clears all ice flights")
	var arrow=run.site_states[5].cannon;arrow.complete_build();enemy.hp=100;enemy.position=arrow.position+Vector3(0,0,12)
	arrow._fire_at(enemy);arrow._tick_arrows(.5)
	check(enemy.hp==50,"Level one still deals fifty damage")
	finish()
func travel(enemy: Ninja)->float:
	enemy.position=Vector3(0,.15,115);enemy.defense_offset=Vector3.ZERO;enemy.defense_waypoint=1;enemy.route_clock=0
	enemy.walk_clock=0;enemy.walk_phase_pending=false;enemy.walk_age=1;enemy.velocity=Vector3.ZERO;enemy.grounded_cached=true;enemy.stun=0
	game.player.position=Vector3(90,.15,210);game.tuning.freeze_ai=false
	var start=enemy.position
	for i in range(12):enemy._physics_process(1.0/60)
	game.tuning.freeze_ai=true
	return Vector2(enemy.position.x-start.x,enemy.position.z-start.z).length()
func finish():
	print("ICE_TOWER_RESULT checks=",checks," failures=",failures)
	game.sound_library.cancel();game.music.stop();game.queue_free();quit(1 if failures else 0)
