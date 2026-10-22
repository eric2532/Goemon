extends "res://scripts/musashi_tests.gd"
var label="before"
var report={}
var spamming=false
var tap_clock=0.0
func _process(delta):
	if not spamming:return
	tap_clock-=delta
	if tap_clock<=0:tap_clock=.16;game.player.sky_strike.request()

func sample(name: String,frames: int=120):
	for i in range(24):await get_tree().process_frame
	var timings=[];var last=Time.get_ticks_usec()
	for i in range(frames):
		await get_tree().process_frame
		var now=Time.get_ticks_usec();timings.append((now-last)/1000.0);last=now
	var sum=0.0
	for value in timings:sum+=value
	timings.sort()
	report[name]={"mean_ms":sum/frames,"p95_ms":timings[int(frames*.95)],"draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),"primitives":Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME),"nodes":Performance.get_monitor(Performance.OBJECT_NODE_COUNT),"physics_ms":Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)*1000}
	print("PROFILE ",name," ",JSON.stringify(report[name]))
func run():
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--label="):label=arg.trim_prefix("--label=")
	game.tuning=PrototypeTuning.DEFAULTS.duplicate();game.tuning.invincible=true;game.start_game();game.encounters.enabled=false
	game.player.smoke_mode=true;game.camera_rig.set_process_unhandled_input(false)
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE;DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED);Engine.max_fps=0
	get_window().set_flag(Window.FLAG_NO_FOCUS,true)
	await wait(.5)
	if "--legs-only" not in OS.get_cmdline_user_args():
		await sample("full_map")
		game.player.smoke_move=Vector2(0,-1)
		await sample("moving_map")
		game.player.smoke_move=Vector2.ZERO
		# Controlled crowd, representative of the all-map pursuit converging on the hero.
		game.tuning.freeze_ai=true
		game.reset_player_at(Vector3(0,game.world.height_at(0,41)+.05,41));await wait(.25)
		for i in range(game.enemies.size()):
			var e=game.enemies[i];var angle=i*2.399963;var radius=6+sqrt(float(i)/game.enemies.size())*29
			var point=game.player.position+Vector3(cos(angle),0,sin(angle))*radius+Vector3(0,0,-28)
			point.y=game.world.height_at(point.x,point.z)+.1;e.position=point
		await sample("crowd_541_frozen")
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://tests/performance-legs/"+label+"-crowd.png")
		game.tuning.freeze_ai=false
		await sample("crowd_541_active")
		var near=0
		for enemy in game.enemies:
			if enemy.position.distance_to(game.player.position)<65:near+=1
		print("CROWD_NEARBY ",near)
		spamming=true;await sample("crowd_stomp_spam");spamming=false;game.player.sky_strike.cancel()
		game.tuning.freeze_ai=true
		for e in game.enemies:
			if is_instance_valid(e):e.model.set_process(false)
		await sample("crowd_no_skeleton_sync")
		if "crowd" in game:game.crowd.set_process(false);game.crowd.hide()
		for e in game.enemies:
			if is_instance_valid(e):e.hide();e.set_physics_process(false)
		game.pursuit.set_physics_process(false)
		await sample("world_without_enemies")
		FileAccess.open("res://tests/performance-legs/"+label+".json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	for e in game.enemies:
		if is_instance_valid(e):e.queue_free()
	game.enemies.clear();game.tuning.freeze_ai=true
	game.hud.hide();game.camera_rig.set_process(false);game.player.soft_target=false
	for speed in [10.2,18.0]:
		game.reset_player_at(Vector3(0,game.world.height_at(0,41)+.05,41));game.tuning.walk_speed=speed
		game.player.invuln=0;game.player.smoke_move=Vector2(0,-1);await wait(.25)
		for i in range(8):
			game.camera_rig.camera.global_position=game.player.position+Vector3(3.0,1.7,2.5)
			game.camera_rig.camera.look_at(game.player.position+Vector3.UP*.9)
			game.player.invuln=0;game.player.model.show()
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png("res://tests/performance-legs/%s-run-%s-%02d.png" % [label,str(speed),i])
			await wait(.05)
	game.player.smoke_move=Vector2.ZERO
	print("PERFORMANCE_AUDIT_COMPLETE ",label);get_tree().quit()
