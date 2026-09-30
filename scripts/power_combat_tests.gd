extends "res://scripts/musashi_tests.gd"

func prepare(id: int=1):
	await mouse(false);await mouse(false,true)
	var release=InputEventKey.new();release.physical_keycode=KEY_T;release.pressed=false;Input.parse_input_event(release);Input.flush_buffered_events()
	if game.paused:game.resume()
	game.player.cancel_charge();game.player.end_surge();game.player.clear_powerups()
	for enemy in game.enemies:
		if is_instance_valid(enemy):enemy.queue_free()
	game.enemies.clear()
	for effect in get_tree().get_nodes_in_group("projectiles"):effect.queue_free()
	game.player.select_character(id)
	game.player.attack_left=0;game.player.attack_charged=false;game.player.impact_pause=0
	game.reset_player_at(Vector3(0,game.world.height_at(0,41)+.05,41))
	game.player.facing=Vector3.FORWARD;game.player.soft_target=false;game.camera_rig.yaw=0
	if id==1:game.player.select_weapon(1)
	else:game.player.musashi.shield_cooldown=0;game.player.musashi.select_weapon(false)
	await wait(.1)

func target(offset: Vector3)->Ninja:
	var enemy=dummy(offset);enemy.hp=10000;enemy.max_hp=10000;return enemy

func attack_frames()->int:
	var frames=0
	while (game.player.attack_left>0 or game.player.sky_strike.active) and frames<240:
		await get_tree().physics_frame;frames+=1
	return frames

func capture_power(label: String):
	if not visual:return
	game.hud.banner_time=0;game.hud.toast_time=0;game.player.invuln=0
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://tests/power-"+label+".png")

func run():
	visual="--power-combat-visual" in OS.get_cmdline_user_args()
	Input.use_accumulated_input=false
	game.tuning=PrototypeTuning.DEFAULTS.duplicate();game.tuning.invincible=true;game.tuning.freeze_ai=true
	game.start_game();game.encounters.enabled=false;game.player.smoke_mode=true
	game.camera_rig.set_process_unhandled_input(false);get_window().set_flag(Window.FLAG_NO_FOCUS,true)
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	var p=game.player
	await prepare()
	check(EnergyPickup.COLORS.has("damage") and EnergyPickup.COLORS.has("attack_speed") and not EnergyPickup.COLORS.has("jump") and not EnergyPickup.COLORS.has("speed"),"Mobility drops are replaced by damage and attack-speed orbs")
	for kind in ["damage","attack_speed"]:
		var orb=EnergyPickup.new();orb.game=game;orb.kind=kind;orb.position=p.position;game.add_child(orb)
		await wait(.45)
		check(p.powerups[kind]>19 and p.pickup_multiplier(kind)==1.5,"Collecting the actual %s orb grants its 20-second, 1.5x buff" % kind)
	check(p.pickup_multiplier("jump")==1 and p.pickup_multiplier("speed")==1,"Combat orbs do not alter normal movement or jumping")
	p.collect_powerup("damage");check(p.powerups.damage==20,"Repeated damage orb refreshes instead of stacking")
	p.collect_powerup("range");check(p.powerups.range>0 and p.powerups.attack_speed>0 and p.powerups.damage>0,"Damage, attack speed and range coexist")
	game.show_pause();var remaining=p.powerups.duplicate();await wait(.3)
	check(p.powerups==remaining,"Pausing freezes all orb durations")
	game.resume();await wait(.2)
	check(p.powerups.damage<20 and p.powerups.damage>19.7,"Attack speed does not accelerate buff expiry")
	await capture_power("orb-buffs")

	await prepare();var enemy=target(Vector3(0,0,-2.4))
	await mouse(true);check(p.attack_left>0 and not p.primary_down,"Normal left click starts the combo on press without charging")
	await wait(1.5);var held_hp=enemy.hp;await mouse(false);await wait(.3)
	check(held_hp==9926 and enemy.hp==held_hp and not p.attack_charged,"Holding and releasing normal LMB completes one combo, never a charged spin")
	var combo_frames=[]
	for boosted in [false,true]:
		await prepare();enemy=target(Vector3(0,0,-2.4))
		if boosted:p.collect_powerup("attack_speed")
		await mouse(true);await mouse(false);combo_frames.append(await attack_frames())
		check(enemy.hp==9926,"All three combo hits land exactly once with speed buff=%s" % boosted)
	check(combo_frames[1]<combo_frames[0]*.76 and combo_frames[1]>combo_frames[0]*.55,"Attack speed accelerates the whole combo, including hit pauses (%s)" % str(combo_frames))
	await prepare();enemy=target(Vector3(0,0,-2.4));p.collect_powerup("damage")
	await mouse(true);await mouse(false);await attack_frames()
	check(enemy.hp==9889,"Damage orb increases all combo stages by 50 percent")

	var leap_frames=[]
	for boosted in [false,true]:
		await prepare();enemy=target(Vector3(0,0,-6));var origin=p.position
		if boosted:p.collect_powerup("attack_speed");p.collect_powerup("damage")
		await key(KEY_T);leap_frames.append(await attack_frames())
		check(enemy.hp==(9760 if boosted else 9840) and p.position.distance_to(origin)<.15,"T leap applies damage buff and returns to its origin (buff=%s)" % boosted)
	check(leap_frames[1]<leap_frames[0]*.78,"Attack-speed orb accelerates both T leap and return (%s)" % str(leap_frames))

	await prepare();var front=target(Vector3(0,0,-3));var back=target(Vector3(0,0,3))
	await key(KEY_R);await mouse(true)
	check(p.attack_charged and p.attack_heavy and get_tree().get_nodes_in_group("spin_wind").size()==1,"R replaces melee LMB with an immediate wind spin")
	await wait(.35);await capture_power("wind-spin");await mouse(false);await attack_frames()
	check(front.hp==9930 and back.hp==9930,"Powered spin hits front and rear once for full damage")
	await wait(.1);check(get_tree().get_nodes_in_group("spin_wind").is_empty(),"Wind trails clean up when the spin finishes")
	p.surge_left=.02;await wait(.05);await mouse(true)
	check(not p.attack_charged and not p.attack_heavy,"Goemon's base combo returns when R expires")

	for boosted in [false,true]:
		await prepare();p.select_weapon(2)
		if boosted:p.collect_powerup("damage");p.collect_powerup("attack_speed")
		await mouse(true);await mouse(false);await wait(.12 if not boosted else .07)
		var coins=get_tree().get_nodes_in_group("projectiles")
		check(coins.size()==1,"Ranged LMB launches one coin (buff=%s)" % boosted)
		if coins.size()==1:
			check(is_equal_approx(coins[0].damage,30 if boosted else 20) and is_equal_approx(coins[0].velocity.length(),48 if boosted else 32),"Damage and attack-speed orbs affect coin damage and flight")
	await prepare();p.select_weapon(2);await key(KEY_R);await mouse(true);await mouse(false);await wait(.31)
	var coins=get_tree().get_nodes_in_group("projectiles")
	check(coins.size()==1 and coins[0].piercing and coins[0].damage==70 and coins[0].hit_radius>3,"Golden ranged LMB immediately winds up a full-sized piercing giant toss")
	await capture_power("giant-toss")

	var edo_combo_frames=[]
	for boosted in [false,true]:
		await prepare(2);enemy=target(Vector3(0,0,-2.4))
		if boosted:p.collect_powerup("attack_speed");p.collect_powerup("damage")
		await mouse(true);await mouse(false);edo_combo_frames.append(await attack_frames())
		check(enemy.hp==(9889 if boosted else 9926),"Edo's three-punch combo preserves all hits with combat orbs=%s" % boosted)
	check(edo_combo_frames[1]<edo_combo_frames[0]*.76,"Attack speed accelerates Edo's full combo (%s)" % str(edo_combo_frames))
	await prepare(2);p.musashi.activate_shield();p.impact_pause=.5
	await wait(.3)
	check(p.musashi.shield_left<6.75,"Edo's R timer keeps normal time during melee hit pauses")
	await prepare(2);enemy=target(Vector3(0,0,-6));p.soft_target=true;p.musashi.select_weapon(true)
	await mouse(true);await wait(.9);await mouse(false)
	check(enemy.hp==9976 and p.musashi.beam==null,"Base Edo ranged LMB remains a single normal fireball")
	await prepare(2);enemy=target(Vector3(0,0,-3.8));await key(KEY_R);await mouse(true);await mouse(false);await wait(.65)
	check(enemy.hp==9928,"Edo R changes melee LMB into an uncharged full-power heavy hook")

	await prepare(2);front=target(Vector3(0,0,-10));var side=target(Vector3(-10,0,0))
	p.musashi.select_weapon(true);await key(KEY_R);await mouse(true);await wait(.25)
	check(is_instance_valid(p.musashi.beam) and p.musashi.beam_action=="light_attack" and front.hp<10000,"R ranged LMB starts and sustains the beam")
	var old_direction=p.musashi.beam.direction;var old_hp=front.hp
	game.camera_rig.yaw=PI/2;await wait(.3)
	check(side.hp<10000 and front.hp==old_hp and old_direction.dot(p.musashi.beam.direction)<.1,"Held LMB beam follows mouse/camera turning and hits the new direction")
	await capture_power("edo-steerable-beam")
	var release=InputEventKey.new();release.physical_keycode=KEY_T;release.pressed=false;Input.parse_input_event(release);Input.flush_buffered_events();await wait(.05)
	check(p.musashi.beam_held,"Releasing unrelated T cannot cancel a left-button beam")
	await mouse(false);check(p.musashi.beam==null and not p.musashi.beam_guard and p.musashi.empowered(),"Releasing LMB stops the beam while keeping R active")
	await mouse(true);game.show_pause();var shield_time=p.musashi.shield_left;await wait(.3)
	check(p.musashi.beam==null and p.musashi.shield_left==shield_time and shield_time>0,"Pause cancels the beam and preserves the paused R moveset")
	await mouse(false);game.resume();await mouse(true)
	p.musashi.shield_left=.02;await wait(.1)
	check(p.musashi.beam==null and not p.musashi.empowered(),"R expiry ends an active LMB beam without firing a stray fireball")
	await mouse(false)

	var beam_hits=[]
	for boosted in [false,true]:
		await prepare(2);enemy=target(Vector3(0,0,-10));p.musashi.select_weapon(true)
		if boosted:p.collect_powerup("attack_speed");p.collect_powerup("damage")
		await key(KEY_R);await mouse(true)
		var beam=p.musashi.beam;beam.set_physics_process(false);p.set_physics_process(false);beam.tick_left=.1
		var before=enemy.hp
		for i in range(200):beam._physics_process(.01)
		beam_hits.append(before-enemy.hp)
		p.set_physics_process(true);await mouse(false)
	check(is_equal_approx(beam_hits[0],180) and is_equal_approx(beam_hits[1],405),"Beam combines faster ticks with higher damage (%s)" % str(beam_hits))

	var shield_hits=[]
	for boosted in [false,true]:
		await prepare(2);enemy=target(Vector3(0,0,-1.8))
		if boosted:p.collect_powerup("attack_speed");p.collect_powerup("damage")
		p.set_physics_process(false);p.musashi.activate_shield();p.musashi.shield_tick_left=.3
		var before=enemy.hp
		for i in range(120):p.musashi.tick(.01)
		shield_hits.append(before-enemy.hp)
		check(is_equal_approx(p.musashi.shield_left,5.8),"R duration stays in gameplay seconds despite attack speed")
		p.set_physics_process(true)
	check(shield_hits[0]==20 and shield_hits[1]==45,"Shield pulses use damage and attack-speed buffs (%s)" % str(shield_hits))

	await prepare(2);p.collect_powerup("attack_speed");await mouse(true,true);await wait(.72)
	check(p.musashi.charge_ratio()==1,"Attack speed shortens Edo's full hook charge")
	await mouse(false,true);await wait(.5)
	await prepare(2);enemy=target(Vector3(0,0,-2));p.collect_powerup("damage")
	p.musashi.teleport.smoke_damage(p.position)
	check(enemy.hp==9982,"Smoke teleport damage also uses the damage orb")

	await prepare(2);p.musashi.select_weapon(true);await key(KEY_R);await mouse(true);p.musashi.select_weapon(false)
	check(p.musashi.beam==null and p.musashi.empowered(),"Weapon switching cancels the beam while retaining R")
	p.musashi.select_weapon(true);await mouse(false);await mouse(true);await key(KEY_Q)
	check(p.character_id==1 and p.musashi.beam==null and not p.musashi.empowered(),"Character switching clears the old empowered moveset and beam")
	await mouse(false);p.collect_powerup("attack_speed");p.activate_surge();game.restart_area()
	check(p.powerups.attack_speed==0 and p.surge_left==0 and game.encounters.remaining()==600,"Restart clears combat power-ups and retains survival rules")
	game.show_main_menu()
	await wait(.1)
	print("POWER_COMBAT_RESULT failures=",failures)
	get_tree().quit(1 if failures else 0)
