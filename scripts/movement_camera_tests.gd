extends "res://scripts/fire_siege_controls_tests.gd"
## Runtime checks of the actual controller, rendered body heading and camera.

func movement_rules():
	var p=game.player
	for character in range(1,13):
		if character>=3:await fresh_class(character-3)
		else:
			await fresh_goemon()
			p.select_character(character)
		for input in [Vector2.DOWN,Vector2.LEFT,Vector2.RIGHT,Vector2(-1,1).normalized(),Vector2(1,-1).normalized()]:
			game.reset_player_at(TEST_ORIGIN)
			aim_world(p.position+Vector3(8,0,0))
			p.smoke_move=input
			await frames(40)
			var expected=Vector3(input.x,0,input.y).rotated(Vector3.UP,game.camera_rig.yaw)
			check(p.facing.dot(expected)>.97 and (-p.model.global_basis.z).normalized().dot(expected)>.97,"Character %d faces travel for input %s" % [character,input])
			if character==1:
				check(p.model.locomotion.move_blend.y<-.1 and absf(p.model.locomotion.move_blend.x)<.08,"Character %d uses forward locomotion after turning" % character)
			if visual and character in [1,3]:await capture("%02d-direction-%d" % [character,roundi(rad_to_deg(input.angle()))])
		p.smoke_move=Vector2.ZERO
		await frames(20)
		# Attack aim must still be independent after travelling away from the cursor.
		aim_world(p.position+Vector3(8,0,0));tap("light_attack")
		await frames(2)
		check(p.facing.dot(Vector3.RIGHT)>.97,"Character %d still aims attacks toward the camera heading" % character)

func camera_step(offset: Vector3,input: Vector2,delta: float=1.0/60.0):
	game.player.position+=offset
	game.player.velocity=offset/delta
	game.player.smoke_move=input
	game.camera_rig._process(delta)

func camera_rules(label: String):
	var p=game.player;var rig=game.camera_rig
	p.smoke_move=Vector2.ZERO
	p.set_physics_process(false);rig.set_process(false)
	# Clear terrain and cover so this measures follow rather than collision zoom.
	game.reset_player_at(Vector3(0,300,100))
	rig.impulse=0;rig.kick_strength=0
	for i in range(120):camera_step(Vector3.ZERO,Vector2.ZERO)
	var forward=Vector3.FORWARD.rotated(Vector3.UP,rig.yaw)
	var right=Vector3.RIGHT.rotated(Vector3.UP,rig.yaw)
	var initial=rig.camera.global_position
	for i in range(6):camera_step(forward*.1,Vector2.UP)
	check(absf((rig.camera.global_position-initial).dot(forward))<.02,label+": first 60 cm forward leaves the camera in place")
	for i in range(24):camera_step(forward*.1,Vector2.UP)
	check((rig.camera.global_position-initial).dot(forward)>1.5,label+": camera follows after the forward buffer")
	var before=rig.camera.global_position
	camera_step(-forward*.15,Vector2.DOWN)
	check((rig.camera.global_position-before).dot(forward)<-.08,label+": reversing backward immediately moves the camera backward")
	before=rig.camera.global_position
	for i in range(6):camera_step(forward*.1,Vector2.UP)
	check(absf((rig.camera.global_position-before).dot(forward))<.02,label+": backward-to-forward re-arms the buffer")
	for i in range(120):camera_step(Vector3.ZERO,Vector2.ZERO)
	before=rig.camera.global_position
	for i in range(3):camera_step(forward*.2,Vector2.UP,1.0/30.0)
	check(absf((rig.camera.global_position-before).dot(forward))<.02,label+": forward buffer restarts after idle and measures distance at 30 FPS")
	game.reset_player_at(Vector3(0,300,100))
	for i in range(120):camera_step(Vector3.ZERO,Vector2.ZERO)
	before=rig.camera.global_position
	for i in range(6):camera_step(right*.1,Vector2.RIGHT)
	check((rig.camera.global_position-before).dot(right)>.2,label+": sideways travel has no forward buffer")
	game.reset_player_at(Vector3(0,300,100))
	for i in range(120):camera_step(Vector3.ZERO,Vector2.ZERO)
	before=rig.camera.global_position
	for i in range(6):camera_step((right+forward)*.1,Vector2(1,-1).normalized())
	check(absf((rig.camera.global_position-before).dot(forward))<.02 and (rig.camera.global_position-before).dot(right)>.2,label+": diagonal travel buffers only its forward component")
	game.reset_player_at(Vector3(0,300,100))
	for i in range(120):camera_step(Vector3.ZERO,Vector2.UP)
	before=rig.camera.global_position
	for i in range(6):camera_step(forward*.1,Vector2.UP)
	check(absf((rig.camera.global_position-before).dot(forward))<.02,label+": holding forward against a wall does not spend the distance buffer")
	game.reset_player_at(Vector3(0,300,100))
	for i in range(120):camera_step(Vector3.ZERO,Vector2.ZERO)
	for i in range(40):camera_step(forward*.3,Vector2.UP)
	camera_step(-forward*.3,Vector2.DOWN)
	before=rig.camera.global_position
	for i in range(3):camera_step(forward*.3,Vector2.UP)
	check(absf((rig.camera.global_position-before).dot(forward))<.02,label+": restarting from sprint preserves the full buffer despite follow lag and zoom")
	if game.rogue_battle_mode:
		game.boss_active=true
		game.reset_player_at(Vector3(0,300,100))
		for i in range(60):camera_step(Vector3.ZERO,Vector2.UP)
		var size_before=rig.camera.size
		for i in range(60):camera_step(Vector3.ZERO,Vector2.UP)
		check(absf(rig.camera.size-size_before)<.01,label+": blocked forward input does not accumulate boss zoom")
		game.boss_active=false
	if not game.rogue_battle_mode:
		game.reset_player_at(Vector3(0,300,100))
		p.sky_strike.origin=p.position;p.sky_strike.landing=p.position+forward*10
		p.sky_strike.active=true
		for i in range(60):camera_step(Vector3.ZERO,Vector2.ZERO)
		before=rig.follow
		p.sky_strike.active=false
		camera_step(Vector3.ZERO,Vector2.ZERO)
		check(rig.follow.distance_to(before)<2,label+": ending Sky Strike eases out of its cinematic focus")
	var frozen=rig.camera.global_transform
	game.paused=true;camera_step(forward*2,Vector2.UP)
	check(rig.camera.global_transform==frozen,label+": pause freezes the camera")
	game.paused=false
	game.reset_player_at(Vector3(10,300,100))
	check(rig.follow.distance_to(p.position+Vector3.UP*(.8 if game.rogue_battle_mode else 1.4)*p.growth_multiplier())<.01,label+": resets clear camera lag")
	p.smoke_move=Vector2.ZERO;p.velocity=Vector3.ZERO
	p.set_physics_process(true);rig.set_process(true)

func run():
	visual="--movement-camera-visual" in OS.get_cmdline_user_args()
	output_dir="res://tests/movement-camera" if OS.has_feature("editor") else "user://tests/movement-camera"
	if visual:DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output_dir))
	Input.use_accumulated_input=false
	game.tuning=PrototypeTuning.DEFAULTS.duplicate();game.tuning.invincible=true;game.tuning.freeze_ai=true
	game.player.smoke_mode=true
	game.start_mode("defense");pause_fixture_director()
	check(game.is_fire_siege() and game.encounters.get("redesign_mode")==true and game.world.cannon_sites.size()==12,"Testing the v2.32 Fire Siege MVP with twelve construction sites and a goldmine")
	game.encounters.choose_card("supply_cache")
	await clear_enemies()
	if not "--camera-only" in OS.get_cmdline_user_args():await movement_rules()
	await fresh_goemon()
	game.reset_player_at(TEST_ORIGIN+Vector3.UP*5)
	await frames(3)
	game.player.jumps_used=2;game.player.smoke_move=Vector2.DOWN
	aim_world(game.player.position+Vector3(8,0,0));tap("heavy_attack")
	await frames(3)
	check(game.player.attack_left>0 and game.player.facing.dot(Vector3.RIGHT)>.97,"Second-jump attacks retain camera aim while moving backward")
	await fresh_goemon()
	camera_rules("Fire Siege MVP")
	game.player.smoke_mode=true
	game.camera_rig.yaw=PI*.5
	camera_rules("Fire Siege MVP, rotated camera")
	print("MOVEMENT_CAMERA_RESULT checks=",checks," failures=",failures)
	game.show_main_menu();game.sound_library.cancel();game.music.stop()
	for voice in game.voices:voice.stop()
	await get_tree().create_timer(.3).timeout
	get_tree().quit(1 if failures else 0)
