extends SceneTree
# Run from the project root:
# godot --headless --path . --script tests/defense-tactics/compact-edge-recovery.gd --fixed-fps 60
# The director stays disabled during the physical escape reproduction; each
# assertion then invokes its real tick before checking recovery invariants.
var game
var failures=0
func _initialize():
	call_deferred("run")
func frames(count: int):
	for i in range(count):await physics_frame
func check(value: bool,label: String):
	print("PASS: " if value else "FAIL: ",label)
	if not value:failures+=1
func setup(beta: bool):
	game.defense_beta=beta;game.defense_tactics=beta
	game.start_mode("defense")
	var s=game.encounters;s.set_physics_process(false)
	if beta:s.choose_card("supply_cache")
	game.player.set_physics_process(false);game.player.position=Vector3(65,.15,80)
	game.tuning.freeze_ai=false;game.tuning.invincible=true
	s.retire_wave_effects()
	for tower in s.cannons:
		if is_instance_valid(tower):tower.queue_free()
	s.cannons.clear()
	if beta:s.wave=9;s.chosen_wave=10
	s.queue_wave()
	while s.total_spawned<(41 if beta else 3):s.spawn_pending()
	s.pending=0
	await frames(2)
	return s
func snapshot(s,actor)->Dictionary:
	return {"hp":actor.hp,"max_hp":actor.max_hp,"money":s.money,"base_hp":s.base_hp,"kills":s.run_kills,"breaches":s.run_breaches,"wave_kills":s.wave_kills,"wave_breaches":s.wave_breaches,"resolved":s.resolved.duplicate(),"pending":s.pending,"alive":s.alive_count,"spawned":s.total_spawned,"wave":s.wave}
func run():
	game=load("res://scenes/main.tscn").instantiate();game.descent_mode=false;game.smoke_test=true
	root.add_child(game);await process_frame
	var s=await setup(true)
	var actor=game.enemies[0]
	actor.position=Vector3(84,2,-85);actor.velocity=Vector3(10,0,0);actor.grounded_cached=false;actor.walk_clock=0;actor.stun=5
	var before=snapshot(s,actor)
	await frames(180)
	print("ESCAPE_FIXTURE ",JSON.stringify({"position":str(actor.position),"alive":not actor.dead,"owned":s.owns(actor),"resolved":s.resolved.has(actor.encounter_id)}))
	check(actor.position.y< -5 and not actor.dead and s.owns(actor) and not s.resolved.has(actor.encounter_id),"Real enemy physics reproduces an unresolved fall outside the compact field")
	await verify(s,actor,before)
	print("BOUNDS_CHECK failures=",failures)
	game.sound_library.cancel();game.music.stop()
	for voice in game.voices:voice.stop()
	await create_timer(.3).timeout
	quit(failures)
func verify(s,actor,before):
	s.tick(0)
	check(actor.position.is_equal_approx(Vector3(-4.4,.15,-85)),"Escaped regular actor returns to its route at current z")
	check(actor.velocity==Vector3.ZERO and actor.walk_clock==0 and not actor.grounded_cached and actor.state=="march","Recovery clears knockback and cached movement")
	check(snapshot(s,actor)==before,"Recovery preserves health, money, shrine and all roster counters")
	check(actor.defense_waypoint==2,"Recovered actor uses next downstream waypoint")
	var restored_z=actor.position.z
	await frames(90)
	check(actor.position.z>restored_z+2 and actor.position.y> -.5,"Recovered actor resumes real lane movement")
	actor.position=Vector3(0,8,-70);actor.velocity=Vector3(0,3,0);actor.walk_clock=0;actor.grounded_cached=false
	var airborne=actor.position;s.tick(0)
	check(actor.position==airborne and actor.velocity==Vector3(0,3,0),"Valid airborne combat inside the field is preserved")
	actor.position=Vector3(0,-9,-40);actor.velocity=Vector3(0,-40,0)
	before=snapshot(s,actor);s.tick(0)
	check(is_equal_approx(actor.position.y,.15) and actor.position.z== -40 and snapshot(s,actor)==before,"Fallen actor inside the field recovers without changing the roster")
	var boss
	for enemy in game.enemies:
		if is_instance_valid(enemy) and enemy.defense_boss_tier==2:boss=enemy;break
	check(boss!=null,"Final boss fixture comes from the real wave-10 roster")
	boss.position=Vector3(84,2,75);boss.velocity=Vector3(15,0,0);boss.grounded_cached=false;boss.walk_clock=1
	boss.defense_traits.begin_slam();before=snapshot(s,boss);s.tick(0)
	check(boss.position==Vector3(0,.15,75) and boss.defense_waypoint==3,"Escaped final boss returns to the central route")
	check(boss.defense_traits.phase=="march" and not boss.defense_traits.tell.visible,"Recovery cancels the boss attack and its stale danger marker")
	check(snapshot(s,boss)==before,"Final-boss recovery preserves all combat and economy counters")
	var boss_z=boss.position.z;await frames(90)
	check(boss.position.z>boss_z+2 and boss.position.y> -.5,"Recovered final boss resumes real movement")
	actor.position=Vector3(84,2,999)
	before=snapshot(s,actor);s.tick(0)
	check(actor.position.z<game.world.base_position.z-8 and not actor.dead and snapshot(s,actor)==before,"Beyond-shrine recovery clamps upstream without causing a breach")
	actor.position=Vector3(-84,2,-999);s.tick(0)
	check(actor.position.z>=game.world.playable_bounds.position.y+3 and actor.defense_waypoint==1,"Upstream recovery remains inside the field with a valid first waypoint")
	actor.position=Vector3(84,2,-50);game.paused=true;s.tick(0)
	check(actor.position.x==84,"Pause prevents recovery mutations")
	game.paused=false;s.tick(0)
	var owned_ref=s.wave_actors[actor.encounter_id]
	s.wave_actors.erase(actor.encounter_id)
	actor.position=Vector3(84,2,-50);before=snapshot(s,actor);s.tick(0)
	check(actor.position==Vector3(84,2,-50) and snapshot(s,actor)==before,"Recovery cannot claim or mutate an actor outside this roster")
	s.wave_actors[actor.encounter_id]=owned_ref;s.tick(0)
	var ordinary=await setup(false)
	var diagonal=game.enemies[2];diagonal.position=Vector3(324,2,230);diagonal.velocity=Vector3(20,0,0);diagonal.walk_clock=1;diagonal.grounded_cached=false
	var diag_before=snapshot(ordinary,diagonal);ordinary.tick(0)
	var expected_x=lerpf(160,75,(230.0-205.0)/(260.0-205.0))+diagonal.defense_offset.x
	check(absf(diagonal.position.x-expected_x)<.01 and diagonal.position.z==230 and diagonal.defense_waypoint==5,"Standard outer lane recovers onto its diagonal segment with the correct waypoint")
	check(snapshot(ordinary,diagonal)==diag_before,"Standard recovery preserves health, money and roster counters")
	var diag_z=diagonal.position.z;await frames(120)
	check(diagonal.position.z>diag_z+2 and diagonal.position.y> -.5,"Recovered standard actor follows the physical diagonal route")
