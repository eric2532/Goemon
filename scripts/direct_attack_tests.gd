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
	await key(KEY_1);check(p.quick_attacks.active and p.attack_charged,"1 immediately starts the powered wind spin")
	await wait(.38);await capture_direct("01-wind-spin");await drain()
	check(left.hp==9930 and right.hp==9930 and rear.hp==9930,"Wind spin hits both sides and behind once for 70 damage")
	check(p.weapon_slot==1 and not p.quick_attacks.active,"Wind spin completes without changing the equipped weapon")
	for powered in [false,true]:
		await fresh_robe(false)
		if powered:await key(KEY_R)
		await key(KEY_2);await wait(.9);await key(KEY_2)
		var base_coins=launches.filter(func(c):return not c.energy)
		check(base_coins.size()==3 and p.quick_attacks.pending.is_empty(),"Toggle repeatedly casts three coins over .9 seconds without queueing (R=%s)" % powered)
		var correct=true
		for c in base_coins:correct=correct and c.piercing==powered
		check(correct and p.weapon_slot==1 and p.model.pipe.visible and not p.quick_attacks.coins_enabled,"Toggle keeps normal/giant coin behavior and restores manual control (R=%s)" % powered)
	await fresh_robe(false);await key(KEY_3)
	check(p.chain_pipe_combat.active and p.chain_pipe_combat.mode=="sweep" and is_equal_approx(p.chain_pipe_combat.reach,11),"3 immediately starts an 11-metre chain sweep")
	left=target(Vector3(-8,0,-4));right=target(Vector3(8,0,-4));rear=target(Vector3(0,0,5));var far=target(Vector3(13,0,-4))
	await wait(.38);await capture_direct("02-long-sweep");await drain()
	check(left.hp==9930 and right.hp==9930 and rear.hp==10000 and far.hp==10000,"Long sweep retains its fan and distance limits")
	check(p.weapon_slot==1 and p.model.pipe.visible and not p.model.chain_selected,"3 restores the original pipe")
	await fresh_robe(false);await key(KEY_R);await key(KEY_3)
	check(p.chain_pipe_combat.powered and is_equal_approx(p.chain_pipe_combat.reach,18.15),"R retains the long fire sweep")
	await drain()
	var counts=[]
	for boosted in [false,true]:
		await fresh_robe(false)
		if boosted:
			for i in range(4):p.collect_powerup("attack_speed")
		await key(KEY_2);await wait(.9);await key(KEY_2);counts.append(launches.size())
	check(counts[1]>counts[0]*2,"Attack-speed pickups accelerate the automatic coin cadence")
	await fresh_robe();await key(KEY_2);await key(KEY_2)
	check(launches.size()==2,"A toggled cast keeps the robe's bonus coin")
	await fresh_robe();await key(KEY_3);await drain()
	check(launches.size()==1,"Direct long sweep keeps the robe's bonus coin")
	await fresh_robe();await key(KEY_1);await drain()
	check(launches.size()==16,"Hotkey wind spin releases the robe's 16-coin ring")
	await fresh_robe(false);await key(KEY_2);await key(KEY_2);await wait(.3);launches.clear()
	var enemy=target(Vector3(0,0,-2.4));await mouse(true);await mouse(false);await drain()
	check(is_equal_approx(enemy.hp,9867.6) and launches.is_empty(),"Manual LMB retains its complete hit-confirmed triplet after toggling coins off")
	for interrupted in [KEY_E,KEY_C]:
		await fresh_robe(false);await key(KEY_2);await key(interrupted);await wait(1)
		check(p.quick_attacks.coins_enabled and p.quick_attacks.pending.is_empty() and p.weapon_slot==1,"%s preserves the toggle without queueing attacks" % OS.get_keycode_string(interrupted))
	await fresh_robe(false);await key(KEY_3);await key(KEY_2);game.show_pause();var before=launches.size();await wait(.2)
	check(launches.size()==before and p.quick_attacks.coins_enabled,"Pause freezes auto shots and preserves the toggle")
	game.resume();await fresh_robe(false);await key(KEY_2);await key(KEY_Q);await wait(.8)
	check(p.character_id==2 and not p.quick_attacks.coins_enabled,"Switching to Edo switches auto coins off")
	print("DIRECT_ATTACKS_RESULT failures=",failures)
	get_tree().quit(1 if failures else 0)
