extends "res://scripts/power_combat_tests.gd"

const Progression=preload("res://scripts/level_progression.gd")
var platform: Node3D
var origin=Vector3(0,80,41)

func frames(count: int):
	for i in range(count):await get_tree().physics_frame

func fresh(id: int=1,max_level: bool=false):
	await prepare(id)
	game.player.progression.reset()
	if max_level:game.player.progression.award_kills(1402)
	game.player.smoke_move=Vector2.ZERO
	game.reset_player_at(origin+Vector3.UP*.05)
	await frames(8)

func capture_level(label: String):
	if not visual:return
	game.hud.banner_time=0;game.hud.toast_time=0
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://tests/leveling/"+label+".png")

func run():
	var curve=Progression.new()
	check(curve.level==1 and curve.kills_required()==5 and curve.attack_multiplier()==1 and curve.movement_multiplier()==1 and curve.jump_velocity_multiplier()==1,"Level 1 preserves all base stats")
	curve.award_kills(4)
	check(curve.level==1 and curve.kills_into_level==4 and is_equal_approx(curve.progress(),.8),"Partial kill progress fills the level meter")
	check(curve.award_kills()==1 and curve.level==2 and curve.kills_into_level==0,"The fifth kill immediately reaches level 2")
	curve.award_kills(20)
	check(curve.level==6 and curve.kills_required()==6,"Requirements rise by one every five levels and batched kills carry over")
	curve.reset()
	var boundaries=true
	for level_number in range(1,99):
		boundaries=boundaries and curve.level==level_number
		var required=5+floori(float(level_number-1)/5)
		curve.award_kills(required-1)
		boundaries=boundaries and curve.level==level_number
		curve.award_kills()
		boundaries=boundaries and curve.level==level_number+1 and curve.kills_into_level==0
	check(boundaries and curve.total_kills==1402,"All 98 level boundaries are exact; level 99 takes 1,402 kills")
	check(is_equal_approx(curve.attack_multiplier(),1.75) and is_equal_approx(curve.movement_multiplier(),1.4) and is_equal_approx(pow(curve.jump_velocity_multiplier(),2),1.6),"Level 99 caps at +75% attacks, +40% movement and +60% jump height")
	curve.award_kills(100000);var earned=curve.total_kills;curve.award_kills(-2)
	check(curve.level==99 and curve.kills_into_level==0 and curve.progress()==1 and curve.kills_required()==0 and curve.total_kills==earned,"Max level cannot overflow and negative awards are ignored")

	visual="--leveling-visual" in OS.get_cmdline_user_args()
	Input.use_accumulated_input=false
	game.tuning=PrototypeTuning.DEFAULTS.duplicate();game.tuning.freeze_ai=true;game.tuning.invincible=true
	game.start_game();game.encounters.enabled=false;game.orb_system.active=false;game.player.smoke_mode=true
	game.camera_rig.set_process_unhandled_input(false);get_window().set_flag(Window.FLAG_NO_FOCUS,true);Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	if visual:DirAccess.make_dir_recursive_absolute("res://tests/leveling")
	platform=Node3D.new();game.add_child(platform)
	Geo.box(platform,origin-Vector3.UP*.5,Vector3(80,1,80),Geo.mat("888888"),true)
	var p=game.player
	await fresh()
	await capture_level("01-level-one")
	if visual:
		p.progression.award_kills(500)
		game.chain=12
		for i in range(4):p.collect_powerup("attack_speed")
		p.activate_surge()
		await capture_level("02-level-mid-buffs")
		p.progression.award_kills(1402)
		await capture_level("03-level-max")
		print("LEVELING_VISUAL complete")
		get_tree().quit();return
	var victim=target(Vector3(15,0,0));victim.training_dummy=false;victim.practice=false
	victim.take_hit(1,Vector3.RIGHT,false)
	check(p.progression.total_kills==0,"Damage without a kill awards no progress")
	victim.take_hit(10000,Vector3.RIGHT,false)
	check(p.progression.total_kills==1 and p.progression.kills_into_level==1 and victim.position.distance_to(p.position)>8,"A distant kill grants progress immediately without collecting drops")
	victim.take_hit(10000,Vector3.RIGHT,false)
	check(p.progression.total_kills==1,"Repeated damage to a dead enemy cannot award another kill")
	for i in range(4):
		victim=target(Vector3(15,0,0));victim.training_dummy=false;victim.practice=false;victim.take_hit(10000,Vector3.RIGHT,false)
	check(p.progression.level==2 and p.progression.total_kills==5 and game.hud.toast_text.begins_with("LEVEL 2"),"Five actual enemy deaths level up and show bonus feedback")
	victim=target(Vector3(15,0,0));victim.take_hit(10000,Vector3.RIGHT,false)
	victim=target(Vector3(15,0,0));victim.training_dummy=false;victim.take_hit(10000,Vector3.RIGHT,false)
	check(p.progression.total_kills==5,"Training dummies and practice enemies cannot farm levels")
	p.select_character(2);p.select_character(1);game.reset_player_at(origin)
	check(p.progression.level==2 and p.progression.total_kills==5,"Character switching and fall recovery preserve shared progress")
	game.show_pause();p.award_kill();await wait(.05)
	check(p.progression.total_kills==5,"Pause prevents level progression")
	game.resume()

	for action in ["run","sprint","walk_modifier"]:
		var speeds=[]
		for high in [false,true]:
			await fresh(1,high);p.smoke_move=Vector2.RIGHT
			if action!="run":Input.action_press(action)
			await frames(45);speeds.append(Vector2(p.velocity.x,p.velocity.z).length())
			if action!="run":Input.action_release(action)
		check(absf(speeds[1]/speeds[0]-1.4)<.01,"Actual %s movement gains 40%% at level 99" % action)

	var heights=[]
	for high in [false,true]:
		await fresh(1,high);var start=p.position.y;var peak=start
		await key(KEY_SPACE)
		for i in range(100):
			await frames(1);peak=maxf(peak,p.position.y)
			if p.velocity.y<0 and peak>start+.5:break
		heights.append(peak-start)
	check(absf(heights[1]/heights[0]-1.6)<.04,"Measured ground-jump height increases 60%%: %s" % str(heights))
	await key(KEY_SPACE);await frames(2)
	check(p.jumps_used==2 and p.velocity.y>16,"Air jump keeps two charges and gains launch speed (vy=%.2f)" % p.velocity.y)

	await fresh(1,true)
	var wall=Geo.box(platform,origin+Vector3(4,12,0),Vector3(.4,24,12),Geo.mat("888888"),true)
	await frames(2);await key(KEY_SPACE);await frames(4);p.smoke_move=Vector2.RIGHT
	for i in range(60):
		await frames(1)
		if p.wall_jump_grace>0:break
	p.jumps_used=2;await key(KEY_SPACE);await frames(2)
	check(p.wall_jump_recovery>0 and p.velocity.x< -7 and p.velocity.y>16,"Wall hops inherit jump height and retain push-off (velocity=%s)" % str(p.velocity))
	wall.queue_free()

	var combo_times=[]
	for mode in [0,1,2]:
		await fresh(1,mode>0)
		if mode==2:
			for i in range(4):p.collect_powerup("attack_speed")
		victim=target(Vector3(0,0,-2.4))
		await mouse(true);await mouse(false);combo_times.append(await attack_frames())
		check(victim.hp==9926,"Combo lands each hit once with unchanged damage at speed mode %d" % mode)
	check(combo_times[1]<combo_times[0]*.7 and combo_times[2]<combo_times[0]*.3,"Level speed and all four buff stacks accelerate real attacks: %s frames" % str(combo_times))
	check(is_equal_approx(p.attack_speed_multiplier(),5.25),"Level attack speed multiplies with temporary buffs")
	p.clear_powerups();check(is_equal_approx(p.attack_speed_multiplier(),1.75),"Clearing temporary buffs preserves earned attack speed")

	var edo_times=[]
	for high in [false,true]:
		await fresh(2,high);await mouse(true);await mouse(false);edo_times.append(await attack_frames())
	check(edo_times[1]<edo_times[0]*.7,"Edo's real fireball attack uses shared level speed: %s frames" % str(edo_times))
	await fresh(1,true);p.set_scarf_equipped(true)
	check(is_equal_approx(p.movement_multiplier(),4.2) and p.maximum_jumps()==4,"Cloak multiplies earned movement speed and retains quad jump")
	p.velocity.x=40;p.set_scarf_equipped(false)
	check(is_equal_approx(p.velocity.x,game.tuning.walk_speed*1.4),"Removing cloak preserves the earned movement bonus")
	await capture_level("02-level-max")
	game.restart_area();game.encounters.enabled=false
	check(p.progression.level==1 and p.progression.total_kills==0 and p.attack_speed_multiplier()==1 and p.movement_multiplier()==1,"Restart resets level, progress and bonuses to level 1")
	platform.queue_free()
	print("LEVELING_RESULT failures=",failures)
	get_tree().quit(1 if failures else 0)
