extends "res://scripts/musashi_tests.gd"
var old_size=Vector2(186,163)
func capture(label: String):
	if not visual:return
	game.hud.banner_time=0;game.hud.toast_time=0
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://tests/sky-smoke-world/"+label+".png")
func clear_foes():
	for e in game.enemies:
		if is_instance_valid(e):e.queue_free()
	game.enemies.clear()
	await wait(.05)
func heard(name: String)->bool:
	for voice in game.voices:
		if voice.stream==game.sounds[name]:return true
	return false
func run():
	Input.use_accumulated_input=false
	game.tuning=PrototypeTuning.DEFAULTS.duplicate();game.start_game();game.encounters.enabled=false
	game.tuning.freeze_ai=true;game.player.smoke_mode=true
	game.camera_rig.set_process_unhandled_input(false);get_window().set_flag(Window.FLAG_NO_FOCUS,true)
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE;visual="--sky-world-visual" in OS.get_cmdline_user_args()
	await wait(.3)
	var p=game.player
	check(SkyStrike.OUT_TIME==.24 and SkyStrike.BACK_TIME==.19,"Original leap and return timings are unchanged")
	check(game.sounds.sky_leap.get_length()>.2 and game.sounds.sky_stomp.get_length()>.3,"Dedicated leap and stomp WAVs are loaded")
	check(SkySmoke.meshes.size()==3,"Three Blender smoke billow meshes are cached")
	for area in range(4):
		game.area_states.clear();game.rebuild_area(area);game.reset_player_at(game.world.spawn_point);await wait(.3)
		var bounds=game.world.playable_bounds
		var before=186.0*(163 if area==0 else 186)
		check(is_equal_approx(bounds.get_area()/before,10.0),"Area %d has exactly ten times its previous playable area" % area)
		check(game.enemies.size()==(541 if area==0 else 361),"Area %d has ten times its regular enemies and one guardian" % area)
		check(game.world.outposts.size()==9 and game.world.outer_routes.size()>9,"Area %d has nine connected outer outposts" % area)
		var sleeping=0
		for e in game.enemies:
			if e.distance_asleep:sleeping+=1
		check(sleeping>250,"Area %d sleeps distant enemies while keeping them targetable" % area)
		var invalid=0
		for c in game.world.outposts:
			for offset in [Vector3.ZERO,Vector3(17,0,0),Vector3(-17,0,0),Vector3(0,0,17)]:
				var point=c+offset
				var ray=PhysicsRayQueryParameters3D.create(point+Vector3.UP,point-Vector3.UP,1)
				if game.get_world_3d().direct_space_state.intersect_ray(ray).is_empty():invalid+=1
		check(invalid==0,"Every outer court in area %d has walkable collision" % area)
		var center=bounds.get_center()
		var wall=game.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(bounds.end.x-4,20,center.y),Vector3(bounds.end.x+6,20,center.y),1))
		check(not wall.is_empty(),"Area %d boundary moved to the new edge" % area)
		for gate in game.gates:check(bounds.has_point(Vector2(gate.position.x,gate.position.z)) and gate.unlocked,"Area travel remains available")
		# Walk across an outer court using the actual player controller.
		var court=game.world.outposts[0];game.reset_player_at(court+Vector3(-7,.3,0));p.smoke_move=Vector2.RIGHT
		await wait(.8);p.smoke_move=Vector2.ZERO
		check(p.position.x>court.x-1 and p.position.y>court.y-.3,"Player physically traverses outer court %d" % area)
		if visual and area==0:
			game.camera_rig.set_process(false);get_window().size=Vector2i(1200,800)
			game.camera_rig.camera.global_position=Vector3(370,400,210);game.camera_rig.camera.look_at(Vector3(0,0,-185))
			await capture("01-tenfold-map")
	game.rebuild_area(0);game.reset_player_at(Vector3(0,game.world.height_at(0,41)+.05,41));await clear_foes()
	var e=dummy(Vector3(0,0,-6));var farther=dummy(Vector3(6,0,-8));var origin=p.position
	if visual:
		game.camera_rig.set_process(true);game.camera_rig.reset_follow();await wait(.3)
	await key(KEY_T);await wait(.1)
	check(p.sky_strike.active and p.sky_strike.target==e and p.sky_strike.arc_height==6,"Close leap keeps its original arc and chooses the nearest enemy")
	check(heard("sky_leap"),"Takeoff plays the leap sound")
	check(get_tree().get_nodes_in_group("sky_smoke").size()==1,"Takeoff emits the Blender smoke plume")
	await capture("02-leap-smoke")
	await wait(.15)
	check(e.hp==840 and farther.hp==1000,"Stomp retains the original 160 damage")
	check(heard("sky_stomp"),"Landing plays the stomp sound")
	await capture("03-stomp-smoke")
	await wait(.25);check(p.position.distance_to(origin)<.12,"Leap still returns to the exact origin")
	await key(KEY_T);await key(KEY_T);await key(KEY_T);await wait(1.4)
	check(e.hp==360 and farther.hp==1000,"Rapid T remains cooldown-free and each cast chooses the closest living enemy")
	check(not p.sky_strike.active and p.position.distance_to(origin)<.12,"Rapid sequence returns safely after every stomp")
	await wait(1.1);check(get_tree().get_nodes_in_group("sky_smoke").is_empty(),"Smoke cleans itself up after rapid spam")
	await clear_foes();game.reset_player_at(Vector3(0,game.world.height_at(0,41)+.05,41));await wait(.1)
	# Across the former boundary, beyond the old 32m limit and even beyond 300m.
	var remote=Vector3(0,game.world.height_at(0,-275)+.15,-275)
	e=dummy(remote-p.position);e.training_dummy=false;e.practice=false
	farther=dummy(Vector3(195,game.world.height_at(195,-397)-p.position.y,-397-p.position.z))
	await wait(.1);check(e.distance_asleep,"Remote target starts asleep")
	origin=p.position;await key(KEY_T)
	check(p.sky_strike.active and p.sky_strike.target==e,"T finds and launches toward the closest enemy over 300m away")
	await wait(.3);check(e.hp==840,"Unlimited-range stomp reaches and damages a remote target")
	await wait(.3);check(not p.sky_strike.active and p.position.distance_to(origin)<.12,"Cross-map leap returns with original timing")
	# Nearest dying during travel must never leave the hero stranded.
	await key(KEY_T);await wait(.08);e.take_hit(10000,Vector3.BACK,false);await wait(.5)
	check(not p.sky_strike.active and p.position.distance_to(origin)<.12,"Distant target death still returns safely")
	await key(KEY_T);await wait(.08);p.select_character(2)
	check(not p.sky_strike.active and p.position.distance_to(origin)<.12,"Switching characters cancels the distant leap safely")
	p.select_character(1)
	SkySmoke.emit(game,p.position,true);await wait(.1);var smoke=get_tree().get_nodes_in_group("sky_smoke")[-1];var age=smoke.age
	game.paused=true;await wait(.25);check(smoke.age==age,"Pause freezes smoke lifetime and motion");game.paused=false
	game.rebuild_area(1);await wait(.1);check(get_tree().get_nodes_in_group("sky_smoke").is_empty(),"Area travel clears the old area's smoke")
	game.reset_player_at(game.world.spawn_point)
	# Sample actual rendering performance after all level construction has finished.
	var started=Time.get_ticks_usec()
	for i in range(120):await get_tree().process_frame
	print("PERFORMANCE_120_FRAMES_MS ",(Time.get_ticks_usec()-started)/1000.0)
	print("SKY_WORLD_RESULT failures=",failures)
	get_tree().quit(1 if failures else 0)
