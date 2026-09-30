extends "res://scripts/scarf_tests.gd"

var capture_index=0
func capture_jump():
	if not visual:return
	var p=game.player
	game.camera_rig.camera.global_position=p.position+Vector3(6,3,-6)
	game.camera_rig.camera.look_at(p.position+Vector3(0,1.6,.2))
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://tests/ronin-jumps/frames/%03d.png" % capture_index)
	capture_index+=1

func measure_jump(stage: int):
	var p=game.player
	await key(KEY_SPACE)
	if stage==1:await wait(.05)
	check(p.jumps_used==stage,"Space launches jump "+str(stage))
	var turn_y=0.0;var turn_x=0.0;var last_y=0.0;var last_x=0.0
	var max_tilt=0.0;var pivot_error=0.0;var rising=true;var origin=p.position
	for frame in range(28):
		await get_tree().physics_frame
		var basis=p.model.body.basis
		var y=atan2(-basis.x.z,basis.x.x)
		var x=atan2(basis.y.z,basis.y.y)
		turn_y+=angle_difference(last_y,y);turn_x+=angle_difference(last_x,x)
		last_y=y;last_x=x
		max_tilt=maxf(max_tilt,absf(p.model.body.rotation.x))
		if stage==4:pivot_error=maxf(pivot_error,(p.model.body.transform*Vector3(0,1.4,0)).distance_to(Vector3(0,1.4,0)))
		if p.air_turn>0:rising=rising and p.velocity.y>0
		if frame%2==0:await capture_jump()
	if stage==1:check(max_tilt<.2,"First jump keeps the original upright lift")
	if stage==2:check(absf(turn_y+TAU)<.12 and absf(turn_x)<.15,"Second jump makes one opposite-direction rising rotation: %.3f rad" % turn_y)
	if stage==3:check(absf(turn_y-TAU)<.12 and absf(turn_x)<.15,"Third jump makes one complete vertical-axis rotation: %.3f rad" % turn_y)
	if stage==4:
		check(absf(turn_x+TAU)<.12 and absf(turn_y)<.15,"Fourth jump makes one complete forward flip: %.3f rad" % turn_x)
		check(pivot_error<.01,"Flip stays centered on the torso rather than orbiting around the feet")
	check(rising and p.position.y>origin.y,"Jump %d rotation takes place during ascent" % stage)
	check(p.air_turn==0 and p.model.body.basis.is_equal_approx(Basis.IDENTITY),"Jump %d returns to the normal pose after its animation" % stage)

func run():
	visual="--ronin-jumps-visual" in OS.get_cmdline_user_args()
	Input.use_accumulated_input=false
	game.tuning=PrototypeTuning.DEFAULTS.duplicate();game.tuning.invincible=true;game.tuning.freeze_ai=true
	game.start_game();game.encounters.enabled=false;game.player.smoke_mode=true
	game.camera_rig.set_process_unhandled_input(false);game.camera_rig.set_process(false);game.camera_rig.camera.fov=43
	get_window().set_flag(Window.FLAG_NO_FOCUS,true);Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	if visual:
		game.hud.hide();DirAccess.make_dir_recursive_absolute("res://tests/ronin-jumps/frames")
	var p=game.player
	await fresh();p.set_scarf_equipped(true);p.invuln=0
	check(p.maximum_jumps()==4 and p.movement_multiplier()==3,"Cloak grants four jumps and keeps the 3× movement boost")
	for stage in range(1,5):await measure_jump(stage)
	# Test the input limit separately from screenshots, which can stall rendering
	# long enough for the character to land on a cold renderer.
	await fresh();p.set_scarf_equipped(true)
	for stage in range(4):await jump_tap()
	var before=p.velocity.y;await jump_tap()
	check(p.jumps_used==4 and p.velocity.y<before,"A fifth jump is rejected")
	await key(KEY_4);await key(KEY_4);before=p.velocity.y;await jump_tap()
	check(p.jumps_used==4 and p.velocity.y<before,"Outfit toggling cannot refill four spent jumps")
	for i in range(240):
		await get_tree().physics_frame
		if p.is_on_floor():break
	await wait(.05)
	check(p.jumps_used==0 and p.air_turn==0,"Landing resets the counter and clears any jump turn")
	await fresh();await key(KEY_4);await jump_tap();await jump_tap();await key(KEY_SPACE)
	game.show_pause();var frozen=p.air_turn;await wait(.12)
	check(p.air_turn==frozen,"Pause freezes the jump animation")
	game.resume();await wait(.48)
	check(p.air_turn==0,"Jump rotation completes after resuming")
	await key(KEY_SPACE);await key(KEY_Q)
	check(p.character_id==2 and p.maximum_jumps()==2 and p.air_turn==0,"Switching to Edo clears the turn and retains his double jump")
	await fresh();await key(KEY_4);await jump_tap();await jump_tap();await key(KEY_SPACE);await key(KEY_4)
	check(p.maximum_jumps()==2 and p.air_turn==0,"Removing the cloak stops its extra-jump animation")
	await fresh();await key(KEY_4);await jump_tap();await jump_tap();await key(KEY_SPACE);await key(KEY_E)
	check(p.forward_dash.active and p.air_turn==0,"E cleanly interrupts a rising spin")
	await fresh();await key(KEY_4);target(Vector3(0,0,-6));await jump_tap();await jump_tap();await key(KEY_SPACE);await key(KEY_T)
	check(p.sky_strike.active and p.air_turn==0,"T cancels the jump turn before beginning Sky Strike")
	print("RONIN_JUMPS_RESULT failures=",failures)
	get_tree().quit(1 if failures else 0)
