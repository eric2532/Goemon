extends "res://tests/forest-shrine/explorer_close_assist_test.gd"
func move_mouse(delta: Vector2):
	var motion=InputEventMouseMotion.new();motion.relative=delta
	motion.position=root.get_visible_rect().size*Vector2(.8,.2)
	game._input(motion);game.camera_rig._unhandled_input(motion)
func shot(label: String):
	if DisplayServer.get_name()=="headless":return
	await process_frame;await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://tests/third-person-aim/"+label+".png")
func run():
	game=load("res://scenes/forest_shrine.tscn").instantiate();root.add_child(game);current_scene=game
	await frames(3)
	check(Input.mouse_mode==Input.MOUSE_MODE_VISIBLE,"Building retains the normal pointer")
	game.start_wave();game.model.waves.spawn_clock=10000;game.model.waves.pending=0
	game.set_physics_process(false);game.player.set_physics_process(false);game.camera_rig.set_process(false)
	game.tuning.invincible=true;game.player.smoke_mode=true;game.player.smoke_move=Vector2.ZERO
	await fresh(8);var combat=game.player.active_ability;var rig=game.camera_rig
	var center: Vector2=root.get_visible_rect().size*.5
	var yaw: float=rig.yaw;var pitch: float=rig.pitch
	move_mouse(Vector2(100,60))
	check(DisplayServer.get_name()=="headless" or (rig.yaw!=yaw and rig.pitch!=pitch),"Ordinary mouse movement turns the camera without a held modifier")
	check(game.crosshair_screen_position().distance_to(center)<.1,"Crosshair stays centred when the mouse moves")
	check(DisplayServer.get_name()=="headless" or Input.mouse_mode==Input.MOUSE_MODE_CAPTURED,"Combat captures mouse movement for continuous camera look")
	rig.yaw=0;rig.pitch=pitch;rig.current_distance=10;rig.reset_follow();rig._process(.2)
	var head: Vector2=rig.camera.unproject_position(game.player.position+Vector3.UP*2.45)
	check(head.y>center.y and head.y<center.y+180,"The higher camera keeps the character's head below the aiming point")
	var aimed: Vector3=game.crosshair_target()
	var ground_distance=Vector2(aimed.x-game.player.position.x,aimed.z-game.player.position.z).length()
	check(ground_distance>6 and ground_distance<25,"Default downward view aims at useful nearby ground")
	check(rig.camera.unproject_position(aimed).distance_to(center)<1,"The actual targeting ray passes through the fixed reticle")
	await shot("grounded")
	# move_and_slide must run from a physics frame after the render capture.
	await physics_frame
	game.player.jump_buffer=.15;Input.action_press("jump")
	for i in 95:
		combat.physics_step(1.0/60);rig._process(1.0/60)
	check(not game.player.is_on_floor(),"Dragoon still reaches and holds his airborne pose")
	var close: Vector3=combat.dragoon_landing_target()
	check(Vector2(close.x-game.player.position.x,close.z-game.player.position.z).length()<=30.01,"Airborne landing preview remains within thirty metres at base range")
	rig.pitch=-.10;rig._process(.1);combat._update_leap_preview()
	var far: Vector3=combat.dragoon_landing_target()
	var distance=Vector2(far.x-game.player.position.x,far.z-game.player.position.z).length()
	check(distance>25 and distance<=30.01,"Near-horizon aiming reaches a useful maximum landing range")
	check(combat._leap_preview!=null and combat._leap_preview.visible and combat._leap_preview.global_position.distance_to(far+Vector3.UP*.045)<.1,"Blue circle matches the bounded landing solution")
	game.player.powerups.range=20
	var extended: Vector3=combat.dragoon_landing_target()
	var extended_distance=Vector2(extended.x-game.player.position.x,extended.z-game.player.position.z).length()
	check(extended_distance>40 and extended_distance<=45.01,"Existing range upgrades extend the thirty-metre base landing range")
	game.player.powerups.range=0
	rig.pitch=.9;rig._process(.1);combat._update_leap_preview()
	var near: Vector3=combat.dragoon_landing_target()
	check(Vector2(near.x-game.player.position.x,near.z-game.player.position.z).length()<distance-5,"Looking down brings the landing area closer")
	await shot("airborne")
	combat.action("cutlass");var committed: Vector3=combat.player.travel.target
	move_mouse(Vector2(-180,-80));rig._process(.1);combat._update_leap_preview()
	check(combat._leap_preview.global_position.distance_to(committed+Vector3.UP*.045)<.1,"Camera movement after attacking leaves the committed landing circle fixed")
	combat.cancel();Input.action_release("jump")
	game.show_pause()
	check(Input.mouse_mode==Input.MOUSE_MODE_VISIBLE and not game.forest_ui.crosshair_visible(),"Pause releases the pointer and hides the reticle")
	game.resume();game._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	check(Input.mouse_mode==Input.MOUSE_MODE_VISIBLE,"Switching away from the app releases the pointer")
	game._notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	check(DisplayServer.get_name()=="headless" or Input.mouse_mode==Input.MOUSE_MODE_CAPTURED,"Returning to gameplay restores ordinary camera look")
	game.show_rogue_roster();check(Input.mouse_mode==Input.MOUSE_MODE_VISIBLE,"Hero selection uses the normal pointer")
	game.choose_rogue_character(7)
	check(DisplayServer.get_name()=="headless" or Input.mouse_mode==Input.MOUSE_MODE_CAPTURED,"Choosing a hero returns to mouse look")
	game.model.phase="preparing";game.set_phase_view()
	check(Input.mouse_mode==Input.MOUSE_MODE_VISIBLE,"Between waves restores building controls")
	game.queue_free();paused=false;await frames(3)
	print("THIRD_PERSON_AIM_RESULT checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)
