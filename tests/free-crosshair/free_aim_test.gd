extends "res://tests/forest-shrine/explorer_close_assist_test.gd"
func motion(point: Vector2,relative: Vector2=Vector2(50,-30)):
	var event=InputEventMouseMotion.new();event.position=point;event.relative=relative
	game._input(event);game.camera_rig._unhandled_input(event)
func middle(pressed: bool):
	var event=InputEventMouseButton.new();event.button_index=MOUSE_BUTTON_MIDDLE;event.pressed=pressed
	game._input(event)
func alt(pressed: bool):
	var event=InputEventKey.new();event.physical_keycode=KEY_ALT;event.pressed=pressed
	game._input(event)
func shot(label: String):
	if DisplayServer.get_name()=="headless":return
	await process_frame;await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://tests/free-crosshair/"+label+".png")
func finish():
	Input.action_release("jump");Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	game.queue_free();paused=false;await frames(3)
	print("FREE_CROSSHAIR_RESULT checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)
func run():
	game=load("res://scenes/forest_shrine.tscn").instantiate();root.add_child(game);current_scene=game
	await frames(3)
	check(game.has_method("crosshair_screen_position") and game.has_method("free_crosshair_enabled"),"Forest exposes an independently movable crosshair")
	if failures:await finish();return
	check(Input.mouse_mode==Input.MOUSE_MODE_VISIBLE,"Preparation retains the normal building pointer")
	game.start_wave();game.model.waves.spawn_clock=10000;game.model.waves.pending=0
	game.set_physics_process(false);game.player.set_physics_process(false);game.camera_rig.set_process(false)
	game.tuning.invincible=true;game.player.smoke_mode=true;game.player.smoke_move=Vector2.ZERO
	await fresh(8);var c=game.player.active_ability
	var size_: Vector2=root.get_visible_rect().size
	var point=size_*Vector2(.64,.43)
	var yaw: float=game.camera_rig.yaw;var pitch: float=game.camera_rig.pitch
	motion(point)
	check(game.crosshair_screen_position().distance_to(point)<.1,"Mouse movement puts the crosshair at the pointer")
	check(game.camera_rig.yaw==yaw and game.camera_rig.pitch==pitch,"Free aiming leaves the camera direction still")
	check(DisplayServer.get_name()=="headless" or Input.mouse_mode==Input.MOUSE_MODE_HIDDEN,"Combat shows only the movable reticle, without a second arrow cursor")
	var aimed: Vector3=game.crosshair_target()
	check(game.camera_rig.camera.unproject_position(aimed).distance_to(point)<1,"Actual targeting uses the off-centre cursor ray")
	var origin: Vector3=game.player.position+Vector3.UP*1.1
	check(game.projectile_direction(origin).dot((aimed-origin).normalized())>.9999,"Projectiles converge on the movable crosshair")
	var flat=(aimed-game.player.position);flat.y=0
	check(game.attack_direction().dot(flat.normalized())>.9999,"Goemon and shared melee aim toward the free cursor")
	motion(size_*Vector2(.38,.58));var other: Vector3=game.crosshair_target()
	check(other.distance_to(aimed)>3,"Moving the crosshair changes the world aim without orbiting")
	var retained: Vector2=game.crosshair_screen_position()
	middle(true)
	check(game.free_aim_looking,"Middle mouse begins camera look")
	motion(size_*.5)
	check(game.crosshair_screen_position().distance_to(retained)<.1,"Camera look preserves the chosen crosshair position")
	check(DisplayServer.get_name()=="headless" or game.camera_rig.yaw!=yaw,"Middle mouse look rotates the native camera")
	middle(false)
	check(not game.free_aim_looking and game.crosshair_screen_position().distance_to(retained)<.1,"Releasing middle mouse restores free aim at the same screen position")
	alt(true);middle(true);middle(false)
	check(game.free_aim_looking,"Alt supports camera look and remains held when middle mouse releases")
	alt(false);check(not game.free_aim_looking,"Releasing the last camera-look control restores free aim")
	middle(true);game.show_pause()
	check(not game.free_aim_looking and Input.mouse_mode==Input.MOUSE_MODE_VISIBLE and not game.forest_ui.crosshair_visible(),"Pause during camera look releases the cursor and clears the held state")
	game.resume();motion(point)
	game._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	check(not game.free_aim_looking and Input.mouse_mode==Input.MOUSE_MODE_VISIBLE,"Losing application focus releases the pointer")
	var saved: Vector2=game.crosshair_screen_position();motion(size_*.5)
	check(game.crosshair_screen_position()==saved,"Inactive window input cannot move the aim point")
	game._notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	game.show_rogue_roster();check(Input.mouse_mode==Input.MOUSE_MODE_VISIBLE,"Hero selection retains its normal pointer")
	game.choose_rogue_character(8);await fresh(8);c=game.player.active_ability
	game.camera_rig.camera.global_position=game.player.position+Vector3(0,8,12)
	game.camera_rig.camera.look_at(game.player.position+Vector3(0,0,-18))
	game.player.jump_buffer=.15;Input.action_press("jump")
	for i in 50:c.physics_step(1.0/60)
	motion(size_*Vector2(.6,.58));c._update_leap_preview()
	var marker=c._leap_preview;var first: Vector3=c.dragoon_landing_target()
	check(marker!=null and marker.visible and marker.global_position.distance_to(first+Vector3.UP*.045)<.1,"Dragoon's airborne circle follows the free crosshair")
	motion(size_*Vector2(.35,.58));c._update_leap_preview()
	check(marker.global_position.distance_to(first)>2,"Moving the mouse moves the predicted landing circle")
	await shot("free-aim")
	c.action("cutlass");var target_: Vector3=c.player.travel.target
	motion(size_*Vector2(.8,.4));c._update_leap_preview()
	check(marker.global_position.distance_to(target_+Vector3.UP*.045)<.1,"Attacking locks Dragon Leap's real landing target despite later mouse movement")
	c.cancel();game.model.phase="preparing";game.set_phase_view()
	check(Input.mouse_mode==Input.MOUSE_MODE_VISIBLE and not game.forest_ui.crosshair_visible(),"Returning to building restores the normal pointer")
	await finish()
