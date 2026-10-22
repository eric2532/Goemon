extends "res://scripts/musashi_tests.gd"
func capture_frame(label: String):
	if not visual:return
	game.hud.banner_time=0;game.hud.toast_time=0
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://tests/combat-expansion/"+label+".png")
func run():
	Input.use_accumulated_input=false
	game.tuning=PrototypeTuning.DEFAULTS.duplicate();game.start_game()
	game.encounters.enabled=false;game.tuning.freeze_ai=true;game.player.smoke_mode=true
	game.camera_rig.set_process_unhandled_input(false);get_window().set_flag(Window.FLAG_NO_FOCUS,true)
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	visual="--expansion-v2-visual" in OS.get_cmdline_user_args()
	await wait(.4)
	var p=game.player
	await fresh();var e=dummy(Vector3(0,0,-2))
	await click();await wait(1.5)
	check(e.hp==926 and p.musashi.available(),"One Edo click completes exactly three punches: 22 + 22 + 30")
	await fresh();e=dummy(Vector3(0,0,-2));await click();await key(KEY_C);await wait(1.3)
	check(e.hp==1000,"Evade interrupts all remaining punches")
	await fresh();p.musashi.shield_cooldown=0;await key(KEY_R)
	var hp=p.hp;p.invuln=0;p.take_hit(30,Vector3.BACK)
	check(p.hp==hp and p.musashi.protects_player(),"Blue sphere grants invulnerability")
	check(p.musashi.shield.find_children("*","MeshInstance3D",true,false).size()==3,"Shield uses a complete spherical shell and two orbit rings")
	if visual:
		game.camera_rig.set_process(false);get_window().size=Vector2i(1200,800)
		game.camera_rig.camera.global_position=p.position+Vector3(-4,2.8,-6)
		game.camera_rig.camera.look_at(p.position+Vector3.UP*1.2)
		await wait(.35);await capture_frame("01-blue-sphere")
	p.musashi.cancel();await wait(.3);await capture_frame("02-edo-refined")
	p.select_character(1);await wait(.2);await capture_frame("03-goemon-reference")
	await fresh();game.tuning.beam_duration=6;game.tuning.beam_width=4;game.tuning.beam_length=24
	p.musashi.ranged_mode=true;p.musashi.power=1;p.musashi.launch();await wait(.1)
	var beam=p.musashi.beam
	check(beam.remaining>5.5 and beam.balance.beam_radius==2 and beam.balance.beam_length==24,"Beam takes duration, physical width and length from Settings")
	game.paused=true;var remaining=beam.remaining;await wait(.2)
	check(beam.remaining==remaining,"Pausing freezes the sustained beam")
	game.paused=false;p.musashi.cancel()
	game.tuning=PrototypeTuning.DEFAULTS.duplicate();game.tuning.freeze_ai=true
	await reset();p.select_character(1);p.sky_strike.previous_target=0
	e=dummy(Vector3(0,0,-6));var farther=dummy(Vector3(4,0,-8))
	if visual:
		game.camera_rig.set_process(true);game.camera_rig.reset_follow()
		await wait(.3)
	var origin=p.position;await key(KEY_T);await wait(.12)
	check(p.sky_strike.active and p.position.y>origin.y+2,"T selects the closest target and leaps into the air")
	await capture_frame("04-sky-strike-leap")
	await key(KEY_T);await key(KEY_T);await wait(1.4)
	check(e.hp==520 and farther.hp==1000,"Rapid T presses queue three massive strikes and always choose the nearest living target")
	check(not p.sky_strike.active and p.position.distance_to(origin)<.12,"Every queued strike returns to its original position")
	await key(KEY_T);await wait(.08);var pos=p.position;game.paused=true;await wait(.2)
	check(p.position==pos,"Pause freezes the leap sequence")
	game.paused=false;p.select_character(2)
	check(not p.sky_strike.active and p.sky_strike.pending==0 and p.position.distance_to(origin)<.12,"Character switch cancels safely at the original position")
	await reset();p.select_character(1);e=dummy(Vector3(0,0,-8))
	for enemy in game.enemies:
		if is_instance_valid(enemy) and enemy!=e:enemy.dead=true
	var wall=Geo.box(game,p.position+Vector3(0,2,-4),Vector3(12,4,.6),Geo.mat("888888"),true)
	await wait(.1);await key(KEY_T)
	check(p.sky_strike.active and e.hp==1000,"T finds the nearest target and clears a low wall with its arc")
	p.sky_strike.cancel()
	wall.queue_free();await wait(.1)
	await key(KEY_T);await wait(.1);e.take_hit(10000,Vector3.BACK,false);await wait(.5)
	check(not p.sky_strike.active and p.position.distance_to(origin)<.12,"Target death mid-leap still returns safely")
	await reset();e=dummy(Vector3(0,0,-2));e.training_dummy=false;e.hp=1
	e.take_hit(10,Vector3.BACK,false);await wait(.05)
	var drops=get_tree().get_nodes_in_group("energy_pickups")
	check(drops.size()==1,"Enemy death drops one energy power-up")
	var drop=drops[0];var drop_kind=drop.kind;p.position=drop.position;await wait(.5)
	check(get_tree().get_nodes_in_group("energy_pickups").is_empty() and p.powerups[drop_kind]>19,"Energy pickup collects when approached")
	for kind in ["jump","range","speed"]:p.collect_powerup(kind)
	check(p.pickup_multiplier("jump")==1.3 and p.pickup_multiplier("speed")==1.4 and p.range_multiplier()==1.5,"Yellow increases jump, blue increases speed, red increases hit range")
	p.powerups.speed=2;p.collect_powerup("speed")
	check(p.powerups.speed==20 and p.pickup_multiplier("speed")==1.4,"Duplicate power-ups refresh duration without runaway stacking")
	game.paused=true;await wait(.2);check(p.powerups.speed==20,"Power-up timers freeze during pause");game.paused=false
	p.powerups.speed=.05;await wait(.1);check(p.pickup_multiplier("speed")==1,"Expired power-up restores normal speed")
	p.clear_powerups()
	for index in range(4):
		game.rebuild_area(index);game.reset_player_at(game.world.spawn_point);await wait(.2)
		check(game.world.playable_bounds.size.x>180,"Area %d has an expanded playable width" % index)
		var variants={}
		for enemy in game.enemies:
			if not enemy.boss:variants[enemy.variant]=true
		check(variants.size()==4,"Area %d contains four enemy archetypes" % index)
		var hit=game.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(game.world.playable_bounds.end.x-4,20,0),Vector3(game.world.playable_bounds.end.x+6,20,0),1))
		check(not hit.is_empty(),"Expanded area %d has a physical boundary wall" % index)
		for gate in game.gates:check(game.world.playable_bounds.has_point(Vector2(gate.position.x,gate.position.z)) and gate.unlocked,"Expanded area's doors remain accessible")
		if visual and index==1:
			game.camera_rig.camera.global_position=Vector3(80,90,95);game.camera_rig.camera.look_at(Vector3(0,0,-10));await capture_frame("05-expanded-map")
	game.rebuild_area(0);game.reset_player_at(game.world.spawn_point);await wait(.2)
	game.encounters.enabled=true;game.tuning.respawn_delay=.2
	var victim=game.enemies[2];var id=victim.encounter_id;var variant=victim.variant
	game.encounters.slots[id].remaining=.2
	victim.take_hit(10000,Vector3.BACK,false);await wait(1.2)
	var replacement=game.encounters.living(game.encounters.slots[id])
	check(replacement!=null and replacement.variant==variant,"Endless respawns retain the enemy archetype")
	game.encounters.enabled=false
	game.show_pause();game.show_settings(true);await wait(.1);await capture_frame("06-beam-settings")
	game.resume();p.clear_powerups()
	print("COMBAT_EXPANSION_RESULT failures=",failures)
	get_tree().quit(1 if failures else 0)
