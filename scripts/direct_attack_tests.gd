extends "res://scripts/robe_coin_tests.gd"

func drain()->int:
	var frames=0
	while (game.player.attack_left>0 or game.player.quick_attacks.active or not game.player.quick_attacks.pending.is_empty()) and frames<600:
		await get_tree().physics_frame;frames+=1
	return frames

func capture_direct(label: String):
	if not visual:return
	game.hud.banner_time=0;game.hud.toast_time=0
	game.camera_rig.set_process(false)
	game.camera_rig.camera.global_position=game.player.position+Vector3(9,9,14)
	game.camera_rig.camera.look_at(game.player.position+Vector3.UP)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://tests/direct-attacks/"+label+".png")

func run():
	visual="--direct-attacks-visual" in OS.get_cmdline_user_args()
	Input.use_accumulated_input=false
	game.tuning=PrototypeTuning.DEFAULTS.duplicate();game.tuning.invincible=true;game.tuning.freeze_ai=true
	game.start_game();game.encounters.enabled=false;game.player.smoke_mode=true
	game.camera_rig.set_process_unhandled_input(false);get_window().set_flag(Window.FLAG_NO_FOCUS,true);Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	game.child_entered_tree.connect(observe_projectile)
	var p=game.player
	await fresh_robe(false)
	var left=target(Vector3(-2.8,0,-1));var right=target(Vector3(2.8,0,-1));var rear=target(Vector3(0,0,4))
	await key(KEY_1);check(p.quick_attacks.active and p.wide_swing,"1 immediately starts a wide swing without a mouse click")
	await wait(.38);await capture_direct("01-wide-swing");await drain()
	check(left.hp==9952 and right.hp==9952 and rear.hp==10000,"Wide swing hits both forward sides once for 48 damage, excluding rear targets")
	check(p.weapon_slot==1 and not p.quick_attacks.active and not p.wide_swing,"Wide swing completes without changing the equipped weapon")
	for powered in [false,true]:
		await fresh_robe(false)
		var enemy=target(Vector3(0,0,-15));enemy.set_physics_process(false)
		if powered:await key(KEY_R)
		await key(KEY_2);await key(KEY_2);await key(KEY_2)
		check(p.quick_attacks.pending.size()==2,"Repeated 2 taps queue throws while the first animates (R=%s)" % powered)
		await drain();await wait(.6)
		check(launches.size()==3,"Three rapid 2 presses produce exactly three coin attacks (R=%s)" % powered)
		check(enemy.hp==(9790 if powered else 9940),"Direct coins apply the original normal/giant damage (R=%s, HP=%s)" % [powered,enemy.hp])
		var correct=true
		for c in launches:correct=correct and c.piercing==powered
		check(correct and p.weapon_slot==1 and p.model.pipe.visible and not p.model.coin.visible,"2 uses the correct projectile and returns to the pipe (R=%s)" % powered)
	await fresh_robe(false);await key(KEY_3)
	check(p.chain_pipe_combat.active and p.chain_pipe_combat.mode=="sweep" and is_equal_approx(p.chain_pipe_combat.reach,11),"3 immediately starts an 11-metre chain sweep instead of selecting a weapon")
	left=target(Vector3(-8,0,-4));right=target(Vector3(8,0,-4));rear=target(Vector3(0,0,5));var far=target(Vector3(13,0,-4))
	await wait(.38);await capture_direct("02-long-sweep");await drain()
	check(left.hp==9930 and right.hp==9930 and rear.hp==10000 and far.hp==10000,"Long sweep damages both sides beyond the old 6.5m reach and respects its fan and distance limits")
	check(p.weapon_slot==1 and p.model.pipe.visible and not p.model.chain_selected and not p.model.chain_pipe.visible,"3 restores the original pipe and removes the temporary chain pose")
	await fresh_robe(false);await key(KEY_R);await key(KEY_3)
	check(p.chain_pipe_combat.powered and is_equal_approx(p.chain_pipe_combat.reach,18.15),"R retains the fire sweep and scales the longer reach")
	await wait(.36);await capture_direct("03-powered-long-sweep");await drain()
	var durations=[]
	for boosted in [false,true]:
		await fresh_robe(false)
		if boosted:
			for i in range(4):p.collect_powerup("attack_speed")
		await key(KEY_R);await key(KEY_2);await key(KEY_2);durations.append(await drain())
	check(durations[1]<durations[0]*.4,"Attack-speed orbs accelerate repeated giant throws (%s frames)" % str(durations))
	await fresh_robe();await key(KEY_2);await drain()
	check(launches.size()==2,"Direct coin throw keeps the robe's bonus coin")
	await fresh_robe();await key(KEY_3);await drain()
	check(launches.size()==1,"Direct long sweep keeps the robe's bonus coin")
	await fresh_robe();await key(KEY_1);await drain()
	check(launches.size()==1,"Direct wide swing keeps the robe's bonus coin")
	await fresh_robe();await key(KEY_R);await key(KEY_2);await drain();launches.clear()
	await mouse(true);await mouse(false);await drain()
	check(launches.size()==16,"Mouse R spin still emits the robe's 16-coin ring after using key 2")
	await fresh_robe(false);await key(KEY_2);await drain();launches.clear()
	var enemy=target(Vector3(0,0,-2.4));await mouse(true);await mouse(false);await drain()
	check(enemy.hp==9926 and launches.is_empty(),"LMB remains the original three-hit melee combo after a number-key coin throw")
	for interrupted in [KEY_E,KEY_C,KEY_Q]:
		await fresh_robe(false);await key(KEY_2);await key(KEY_2);await key(interrupted);await wait(1)
		check(launches.is_empty() and not p.quick_attacks.active and p.quick_attacks.pending.is_empty() and p.weapon_slot==1,"%s cancels windup and queued throws and restores the original weapon" % OS.get_keycode_string(interrupted))
	await fresh_robe(false);await key(KEY_3);await key(KEY_2);game.show_pause();await wait(.2);game.resume();await wait(.4)
	check(launches.is_empty() and not p.quick_attacks.active and p.weapon_slot==1 and not p.model.chain_selected,"Pause cancels the temporary sweep and pending throws without leaving a weapon swap")
	await fresh_robe(false);await key(KEY_3);await key(KEY_2);enemy=target(Vector3(0,0,-6));await key(KEY_T);await attack_frames();await wait(.2)
	check(p.weapon_slot==1 and p.quick_attacks.pending.is_empty() and launches.is_empty() and enemy.hp==9840,"T interrupts temporary attacks and retains Sky Strike damage")
	await fresh_robe(false);await key(KEY_2)
	var repeated=InputEventKey.new();repeated.physical_keycode=KEY_2;repeated.pressed=true;repeated.echo=true
	Input.parse_input_event(repeated);Input.flush_buffered_events();await drain()
	check(launches.size()==1,"OS key-repeat cannot flood the attack queue")
	await fresh_robe(false);await key(KEY_Q);await key(KEY_1);await key(KEY_2);await key(KEY_3);await wait(.8)
	check(p.character_id==2 and not p.quick_attacks.active and launches.is_empty(),"Edo continues to ignore Goemon's number attacks")
	print("DIRECT_ATTACKS_RESULT failures=",failures)
	get_tree().quit(1 if failures else 0)
