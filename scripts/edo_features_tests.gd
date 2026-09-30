extends "res://scripts/musashi_tests.gd"
func setup_edo():
	game.encounters.enabled=false
	await fresh()
	game.player.soft_target=false;game.player.musashi.ranged_mode=true
func cast_beam():
	await mouse(true);await wait(1.15);await mouse(false);await wait(.18)
func turn_mouse(pixels: float):
	# Dispatch the real mouse-motion event path, isolated from physical mouse movement.
	Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
	game.camera_rig.set_process_unhandled_input(true)
	var motion=InputEventMouseMotion.new();motion.relative=Vector2(pixels,0)
	Input.parse_input_event(motion);Input.flush_buffered_events()
	await get_tree().physics_frame
	game.camera_rig.set_process_unhandled_input(false)
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	await wait(.12)
func capture(label: String):
	if not visual:return
	game.hud.banner_time=0;game.hud.toast_time=0
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://tests/edo-beam/"+label+".png")
func find_regular(id: String)->Ninja:
	for enemy in game.enemies:
		if is_instance_valid(enemy) and not enemy.dead and enemy.encounter_id==id:return enemy
	return null
func run():
	Input.use_accumulated_input=false
	original_tuning=game.tuning.duplicate();game.tuning=PrototypeTuning.DEFAULTS.duplicate()
	game.start_game();game.player.smoke_mode=true;game.tuning.freeze_ai=true
	game.camera_rig.set_process_unhandled_input(false);get_window().set_flag(Window.FLAG_NO_FOCUS,true);Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	visual="--edo-visual" in OS.get_cmdline_user_args()
	await wait(.4)
	check(Hero.ROSTER[1].name=="Goemon" and Hero.ROSTER[2].name=="Edo","Playable names are Goemon and Edo")
	await setup_edo();var p=game.player;var c=p.musashi
	var e=dummy(Vector3(0,0,-6));await click();await wait(.7)
	check(e.hp==976 and get_tree().get_nodes_in_group("edo_beams").is_empty(),"Quick fireball stays a normal 24-damage projectile")
	await setup_edo();e=dummy(Vector3(0,0,-7));var wide=dummy(Vector3(1.45,0,-9));var far=dummy(Vector3(0,0,-15));var outside=dummy(Vector3(3.5,0,-8))
	await cast_beam()
	check(c.state==MusashiCombat.State.BEAM and is_instance_valid(c.beam),"Full charge starts the dedicated beam channel")
	check(c.beam.balance.beam_radius>=1.4 and c.beam.length_now>16,"Beam has a thick 2.8m volume and long reach")
	check(get_tree().get_nodes_in_group("musashi_projectiles").size()==1,"Full charge creates only the beam, not a larger fireball")
	check(c.beam_guard and c.protects_player() and is_instance_valid(c.shield),"Beam automatically activates the visible protective blue sphere")
	var hp=p.hp;p.invuln=0;p.take_hit(30,Vector3.BACK)
	check(p.hp==hp and is_instance_valid(c.beam),"Shield blocks damage and interruption throughout the beam")
	if visual:
		game.camera_rig.set_process(false);get_window().size=Vector2i(1200,800)
		game.camera_rig.camera.global_position=p.position+Vector3(13,9,9)
		game.camera_rig.camera.look_at(p.position+Vector3(0,1.5,-10))
	await capture("01-sustained-fire-beam")
	await wait(.6)
	check(e.hp<964 and wide.hp<1000 and far.hp<1000 and outside.hp==1000,"Beam repeatedly burns nearby and distant targets inside its thick volume")
	var before=c.beam.global_position;p.position.x+=2;game.camera_rig.yaw=-.25;await wait(.08)
	check(c.beam.global_position.distance_to(before)>1 and c.beam.direction.dot(p.facing)>.99,"Beam stays in front of Edo and follows aim")
	await wait(3.75);check(is_instance_valid(c.beam),"Beam remains active late in its five-second duration")
	await wait(.7);check(not is_instance_valid(c.beam) and c.available(),"Beam expires after five seconds and releases the combat state")
	check(not c.beam_guard and not c.protects_player() and c.shield==null,"Beam-only shield ends with the beam")
	p.invuln=0;hp=p.hp;p.take_hit(1,Vector3.BACK)
	check(p.hp<hp,"Normal vulnerability resumes after the beam")
	await setup_edo();var right=dummy(Vector3(3.2,0,-7));var left=dummy(Vector3(-3.2,0,-7));var near=dummy(Vector3(1.6,0,1))
	await cast_beam();var initial_yaw=game.camera_rig.yaw
	if DisplayServer.get_name()=="headless":
		print("SKIP: OS mouse capture requires the rendered --edo-test / --edo-visual suite")
		await wait(.8)
	else:
		await turn_mouse(160);await wait(.25)
		check(game.camera_rig.yaw<initial_yaw and c.beam.direction.x>.2 and right.hp<1000 and left.hp==1000,"Mouse movement turns the active beam right and sweeps damage onto new targets")
		await turn_mouse(-320);await wait(.25)
		check(c.beam.direction.x<-.2 and left.hp<1000,"Reverse mouse movement turns the active beam left")
	check(near.hp<1000,"Automatic beam shield also burns nearby enemies")
	c.cancel()
	await setup_edo();c.shield_cooldown=0;await key(KEY_R);var manual_shield=c.shield;await cast_beam()
	check(c.shield==manual_shield,"Manual and beam shield share one visual effect")
	c.cancel_beam();await wait(.1)
	check(c.shield_left>0 and c.protects_player() and c.shield==manual_shield,"Ending the beam preserves an independently active R shield")
	await setup_edo();c.shield_cooldown=0;await key(KEY_R);await cast_beam();c.shield_left=.1;await wait(.25)
	check(c.shield_left==0 and c.protects_player() and is_instance_valid(c.shield),"Beam protection continues when the manual shield timer expires")
	c.cancel()
	await setup_edo();c.shield_cooldown=5;await cast_beam()
	check(c.beam_guard and c.shield_cooldown<5,"Beam shield works during R cooldown without resetting it")
	c.cancel()
	await setup_edo();e=dummy(Vector3(0,0,-11))
	var wall=Geo.box(game,p.position+Vector3(0,2,-5),Vector3(7,4,.5),Geo.mat("777777"),true)
	await wait(.1);await cast_beam();await wait(.5)
	check(c.beam.length_now<5 and e.hp==1000,"Solid walls truncate the thick beam and block damage behind them")
	c.cancel();wall.queue_free();await wait(.1)
	for reason in ["switch","weapon","evade"]:
		await setup_edo();await cast_beam()
		match reason:
			"switch":await key(KEY_Q)
			"weapon":await key(KEY_1)
			"evade":await key(KEY_C)
		await wait(.08)
		check(get_tree().get_nodes_in_group("edo_beams").is_empty(),"Beam cancels cleanly on "+reason)
		check(not c.beam_guard and not c.protects_player() and c.shield==null,"Beam shield cleans up on "+reason)
	for rate in [20,120]:
		await setup_edo();e=dummy(Vector3(0,0,-7));p.set_physics_process(false)
		c.power=1;c.launch();c.beam.set_physics_process(false)
		for i in range(int(rate*2.05)):c.beam._physics_process(1.0/rate)
		check(e.hp==802,"Beam tick damage is frame-rate independent at "+str(rate)+" updates/second")
		c.cancel();p.set_physics_process(true)
	await setup_edo();await cast_beam();var remaining=c.beam.remaining
	game.paused=true;await wait(.3)
	check(is_equal_approx(c.beam.remaining,remaining),"Pause freezes the beam timer and damage")
	game.paused=false;c.cancel()
	# Walk through forward and return doors before defeating any guardian.
	game.area_cleared.clear()
	for destination in [1,2,3,2,1,0]:
		var selected: AreaGate
		for gate in game.gates:
			if gate.destination==destination:selected=gate
		check(selected!=null and selected.unlocked and selected.rim.mesh.outer_radius>2.5,"Large door to area %d is open before boss defeat" % destination)
		p.position=selected.position+Vector3(0,.1,4.8);p.velocity=Vector3.ZERO
		if visual:
			game.camera_rig.camera.global_position=selected.position+Vector3(2,6,13 if selected.forward_gate else -13)
			game.camera_rig.camera.look_at(selected.position+Vector3.UP*3)
			await capture("02-door-area-"+str(game.area_index)+("-forward" if selected.forward_gate else "-return"))
		await key(KEY_F)
		for step in range(180):
			if not game.transitioning:break
			await get_tree().process_frame
		check(game.area_index==destination and not game.transitioning,"F travels freely to area "+str(destination))
	check(game.area_cleared.is_empty(),"Travel through all dungeons requires zero guardian kills")
	# Travel during a sustained cast must not leave an invisible damaging beam.
	await setup_edo();p.position=game.gates[0].position+Vector3(0,.1,4.5);await cast_beam();await key(KEY_F)
	for step in range(180):
		if not game.transitioning:break
		await get_tree().process_frame
	check(game.area_index==1 and not is_instance_valid(c.beam) and get_tree().get_nodes_in_group("edo_beams").is_empty(),"Door travel during combat cancels the beam immediately")
	# Recycle one regular encounter repeatedly; population and IDs stay bounded.
	game.encounters.enabled=true;game.tuning.respawn_delay=.3
	game.reset_player_at(game.world.spawn_point);await wait(.2)
	var original_count=game.encounters.slots.size();var id="0"
	for cycle in range(3):
		var victim=find_regular(id);var old_id=victim.get_instance_id()
		victim.take_hit(10000,Vector3.BACK,false);await wait(1.2)
		var replacement=find_regular(id)
		check(replacement!=null and replacement.get_instance_id()!=old_id and replacement.hp==replacement.max_hp,"Regular encounter respawns again, cycle "+str(cycle+1))
		check(game.enemies.size()<=original_count+1,"Infinite replacements keep a bounded enemy list")
		check(replacement.position.distance_to(p.position)>=game.tuning.respawn_safe_distance,"Respawn keeps safe distance from player")
	var victim=find_regular("1");victim.take_hit(10000,Vector3.BACK,false)
	game.paused=true;var count=game.encounters.respawn_count;await wait(.5)
	check(game.encounters.respawn_count==count,"Paused gameplay never spawns replacements")
	game.paused=false;await wait(.8)
	check(find_regular("1")!=null,"Respawn resumes after pause")
	game.tuning=original_tuning
	print("EDO_FEATURES_RESULT failures=",failures)
	get_tree().call_deferred("quit",1 if failures else 0)
