extends "res://scripts/power_combat_tests.gd"

func balls()->Array:return get_tree().get_nodes_in_group("edo_fireballs")
func capture(label: String):
	if not visual:return
	game.hud.banner_time=0;game.hud.toast_time=0;game.player.invuln=0
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://tests/edo-firecaster/"+label+".png")

func run():
	visual="--firecaster-visual" in OS.get_cmdline_user_args()
	Input.use_accumulated_input=false
	game.tuning=PrototypeTuning.DEFAULTS.duplicate();game.tuning.invincible=true;game.tuning.freeze_ai=true
	check(game.music.stream is AudioStreamMP3 and game.music.stream.loop and game.music.playing==game.settings.music_enabled and game.music.stream.get_length()>148,"Reminiscence MP3 retains its loop and follows the music preference")
	game.start_game();game.encounters.enabled=false;game.player.smoke_mode=true
	game.camera_rig.set_process_unhandled_input(false);get_window().set_flag(Window.FLAG_NO_FOCUS,true)
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	var p=game.player
	await prepare(2)
	await key(KEY_1);await key(KEY_2)
	check(p.musashi.ranged_mode and p.musashi.available(),"Edo starts as a firecaster; 1/2 do not change his moveset")
	await mouse(true);await mouse(false);await wait(.15)
	check(balls().size()==3,"One left click creates three simultaneous fireballs")
	if balls().size()==3:
		check(not balls()[0].heavy and balls()[0].damage==24 and is_equal_approx(balls()[0].velocity.length(),32),"Normal volley has base damage and speed")
		check(balls()[0].velocity.normalized().dot(balls()[2].velocity.normalized())<.99,"Triple fireballs spread across a fan")
	await capture("01-triple-fireballs")
	await wait(.7);check(p.musashi.available() and not p.musashi.primary_held,"Releasing left click finishes only the current volley")
	var volley_counts=[]
	for stacks in [0,2]:
		await prepare(2)
		for i in range(stacks):p.collect_powerup("attack_speed")
		await mouse(true)
		var ids={}
		for frame in range(60):
			await get_tree().physics_frame
			for ball in balls():ids[ball.get_instance_id()]=true
		volley_counts.append(ids.size());await mouse(false)
	check(volley_counts[0]>=6 and volley_counts[1]>volley_counts[0] and volley_counts[0]%3==0 and volley_counts[1]%3==0,"Held LMB repeats complete volleys faster with blue orbs: "+str(volley_counts))
	await prepare(2);await mouse(true,true);await wait(.22)
	check(not p.musashi.is_charging() and balls().size()==1 and balls()[0].heavy and balls()[0].damage==96 and is_equal_approx(balls()[0].hit_radius,.95),"RMB immediately casts one larger 96-damage fireball without charging")
	await capture("02-giant-fireball");await mouse(false,true)
	await prepare(2);p.collect_powerup("damage");p.collect_powerup("attack_speed")
	await mouse(true);await mouse(false);await wait(.09)
	check(balls().size()==3 and balls()[0].damage==36 and is_equal_approx(balls()[0].velocity.length(),48),"Damage and attack speed affect every ball in the volley")
	await prepare(2);var enemy=target(Vector3(0,0,-6));var adjacent=target(Vector3(1.5,0,-6));p.soft_target=true
	await mouse(true,true);await mouse(false,true);await wait(.75)
	check(enemy.hp==9904 and adjacent.hp==9904,"Giant fireball hits direct and nearby targets exactly once")
	await prepare(2);enemy=target(Vector3(0,0,-6));p.soft_target=true
	var wall=Geo.box(game,p.position+Vector3(0,1.5,-3),Vector3(6,4,.4),Geo.mat("888888"),true)
	await wait(.1);await mouse(true);await mouse(false);await wait(.65)
	check(enemy.hp==10000,"Ordinary fireballs still collide with solid walls")
	wall.queue_free()

	await prepare(2)
	for i in range(5):
		var orb=EnergyPickup.new();orb.game=game;orb.kind="attack_speed";orb.position=p.position;game.add_child(orb)
		await wait(.45)
		check(is_equal_approx(p.attack_speed_multiplier(),1+.5*mini(i+1,4)) and p.powerups.attack_speed>19,"Yellow floor orb stacks/refreshes speed, pickup "+str(i+1))
	check(p.attack_speed_stacks==4,"Attack speed caps at four stacks / 3x")
	game.show_pause();var timer=p.powerups.attack_speed;await wait(.2)
	check(p.powerups.attack_speed==timer,"Pause freezes yellow-orb stack duration")
	game.resume();p.powerups.attack_speed=.03;await wait(.1)
	check(p.attack_speed_stacks==0 and p.attack_speed_multiplier()==1,"Expired speed buff clears all stacks")
	p.collect_powerup("attack_speed");check(p.attack_speed_multiplier()==1.5,"First pickup after expiry restarts at 1.5x")

	await prepare(2);var front=target(Vector3(0,0,-10));var rear=target(Vector3(0,0,-18));var side=target(Vector3(-10,0,0))
	var distant=target(Vector3(0,0,-60));distant.set_physics_process(false)
	wall=Geo.box(game,p.position+Vector3(0,1.5,-5),Vector3(6,4,.4),Geo.mat("888888"),true)
	await wait(.1);await key(KEY_R);await mouse(true);await wait(.23)
	check(is_instance_valid(p.musashi.beam) and front.hp<10000 and rear.hp<10000 and side.hp==10000,"R + held LMB pierces a wall and multiple targets in its path")
	check(is_equal_approx(p.musashi.beam.length_now,38) and distant.hp==10000,"Unboosted beam reaches 38m and cannot hit a target 60m away")
	await key(KEY_1);await key(KEY_2)
	check(is_instance_valid(p.musashi.beam),"Weapon keys cannot interrupt Edo's beam")
	for i in range(4):
		p.collect_powerup("attack_speed");await wait(.04)
		check(is_equal_approx(p.musashi.beam.length_now,38*(1+.5*(i+1))),"Active beam length updates with blue stack "+str(i+1))
	check(distant.hp<10000,"Blue stacks extend the damage volume to targets beyond the base beam length")
	await capture("03-piercing-beam")
	var old_direction=p.musashi.beam.direction;var old_hp=front.hp
	game.camera_rig.yaw=PI/2;await wait(.25)
	check(side.hp<10000 and front.hp==old_hp and old_direction.dot(p.musashi.beam.direction)<.1,"Held beam tracks camera turning and changes its hit path")
	await mouse(false)
	check(p.musashi.beam==null and p.musashi.empowered(),"Releasing LMB stops beam but preserves R shield")
	wall.queue_free()
	await mouse(true);game.show_pause();var shield_time=p.musashi.shield_left;await wait(.2)
	check(p.musashi.beam==null and not p.musashi.primary_held and p.musashi.shield_left==shield_time,"Pause cancels held fire and beam; shield timer freezes")
	game.resume();await wait(.15);check(p.musashi.beam==null,"Resume requires a fresh press")
	await mouse(false);await mouse(true);p.musashi.shield_left=.02;await wait(.1)
	check(p.musashi.beam==null and balls().is_empty(),"R expiry stops the beam without a stray volley")
	await mouse(false)
	var beam_damage=[]
	for boosted in [false,true]:
		await prepare(2);enemy=target(Vector3(0,0,-10))
		if boosted:p.collect_powerup("attack_speed");p.collect_powerup("damage")
		await key(KEY_R);await mouse(true)
		var beam=p.musashi.beam;beam.set_physics_process(false);p.set_physics_process(false);beam.tick_left=.1
		var hp=enemy.hp
		for i in range(200):beam._physics_process(.01)
		beam_damage.append(hp-enemy.hp);p.set_physics_process(true);await mouse(false)
	check(is_equal_approx(beam_damage[0],180) and is_equal_approx(beam_damage[1],405),"Beam uses faster ticks and damage buff: "+str(beam_damage))

	await prepare(2);enemy=target(Vector3(0,0,-2));p.dodge_cooldown=0;p.invuln=0
	await key(KEY_E);await wait(.05)
	check(p.musashi.teleport.active and enemy.hp==9964,"Fire dodge starts with one 36-damage departure explosion")
	var destination=p.musashi.teleport.destination
	var landing=target(destination-p.position+Vector3(1,0,0))
	check(EdoFireExplosion.fire_meshes.size()==2 and not get_tree().get_nodes_in_group("edo_explosions").is_empty(),"Dodge uses imported Blender flame meshes with smoke")
	await capture("04-fire-dodge-departure")
	await wait(.19);await capture("05-fire-dodge-arrival")
	await wait(.4)
	check(p.position.distance_to(destination)<.2 and landing.hp==9964 and enemy.hp==9964 and p.model.visible and not p.musashi.teleport.active,"Fire dodge lands safely, damages each target once, and restores Edo: distance %.2f, HP %s/%s, active %s" % [p.position.distance_to(destination),landing.hp,enemy.hp,p.musashi.teleport.active])
	await capture("06-fire-dodge-smoke")
	var effects=get_tree().get_nodes_in_group("edo_explosions")
	await wait(.2)
	check(not effects.is_empty() and effects[-1].flames[0].scale.x<.02 and effects[-1].smoke[0].scale.x>.5,"Explosion's flash gives way to expanding smoke")
	game.show_pause();var ages=[]
	for effect in effects:ages.append(effect.age)
	await wait(.2)
	var frozen=true
	for i in range(effects.size()):frozen=frozen and effects[i].age==ages[i]
	check(frozen,"Explosion animation freezes while paused")
	game.resume();await wait(1.5)
	check(get_tree().get_nodes_in_group("edo_explosions").is_empty(),"Fire and smoke clean up after their lifetime")
	await prepare(2);await mouse(true);await wait(.2);p.musashi.release_primary();await wait(.4)
	check(not p.musashi.primary_held and p.musashi.available(),"Focus loss stops repeated fire")
	await mouse(false);await key(KEY_R);await mouse(true);await key(KEY_Q)
	check(p.character_id==1 and p.musashi.beam==null and not p.musashi.empowered(),"Character switching clears beam and shield")
	await mouse(false)

	# Preserve the previous Goemon changes while sharing the new stack multiplier.
	var combo_frames=[]
	for stacks in [0,4]:
		await prepare(1);enemy=target(Vector3(0,0,-2.4))
		for i in range(stacks):p.collect_powerup("attack_speed")
		await mouse(true);await mouse(false);combo_frames.append(await attack_frames())
		check(enemy.hp==9926,"Goemon's complete three-hit combo survives speed stacks="+str(stacks))
	check(combo_frames[1]<combo_frames[0]*.5,"Four blue orbs speed up all three combo stages")
	await prepare(1);front=target(Vector3(0,0,-3));rear=target(Vector3(0,0,3));await key(KEY_R);await mouse(true);await mouse(false);await attack_frames()
	check(front.hp==9930 and rear.hp==9930,"Goemon R spin still hits front and rear")
	await prepare(1);p.select_weapon(2);await key(KEY_R);await mouse(true);await mouse(false);await wait(.31)
	var coins=get_tree().get_nodes_in_group("projectiles")
	check(coins.size()==1 and coins[0].piercing and coins[0].damage==70,"Goemon's powered giant toss remains intact")
	await prepare(1);enemy=target(Vector3(0,0,-6));p.collect_powerup("attack_speed");var origin=p.position
	await key(KEY_T);await attack_frames()
	check(enemy.hp==9840 and p.position.distance_to(origin)<.15,"Boosted T leap still hits and returns")
	p.collect_powerup("attack_speed");game.restart_area()
	check(p.attack_speed_stacks==0 and p.powerups.attack_speed==0 and game.encounters.remaining()==600,"Restart resets stack state and the ten-minute survival run")
	game.show_main_menu();await wait(.1)
	print("FIRECASTER_RESULT failures=",failures)
	get_tree().quit(1 if failures else 0)
