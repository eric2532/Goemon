extends "res://scripts/musashi_tests.gd"
func hold(code: Key,down: bool):
	var event=InputEventKey.new();event.physical_keycode=code;event.pressed=down
	Input.parse_input_event(event);Input.flush_buffered_events()
	await get_tree().physics_frame
func clear_foes():
	for e in game.enemies:
		if is_instance_valid(e):e.queue_free()
	game.enemies.clear();await wait(.05)
func capture(label: String):
	if not visual:return
	game.hud.banner_time=0;game.hud.toast_time=0
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://tests/aoe-pursuit-edo/"+label+".png")
func run():
	Input.use_accumulated_input=false
	game.tuning=PrototypeTuning.DEFAULTS.duplicate();game.start_game();game.encounters.enabled=false
	game.tuning.freeze_ai=true;game.tuning.invincible=true;game.player.smoke_mode=true
	game.camera_rig.set_process_unhandled_input(false);get_window().set_flag(Window.FLAG_NO_FOCUS,true)
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE;visual="--aoe-edo-visual" in OS.get_cmdline_user_args()
	await wait(.3)
	var p=game.player
	if "--wall-only" in OS.get_cmdline_user_args():
		await wall_check();print("WALL_RESULT failures=",failures);get_tree().quit(1 if failures else 0);return
	if "--pursuit-only" in OS.get_cmdline_user_args():
		await pursuit_checks();print("PURSUIT_RESULT failures=",failures);get_tree().quit(1 if failures else 0);return
	await clear_foes();await reset()
	var origin=p.position
	var e=dummy(Vector3(0,0,-6));var side=dummy(Vector3(3,0,-7));var outside=dummy(Vector3(9,0,-7))
	await key(KEY_T);await wait(.26)
	check(e.hp==840 and side.hp==840 and outside.hp==1000,"Stomp hits all enemies in its five-metre radius once")
	await capture("01-area-stomp");await wait(.3)
	check(p.position.distance_to(origin)<.12,"AoE preserves original leap and return")
	await key(KEY_T);await key(KEY_T);await key(KEY_T);await wait(1.4)
	check(e.hp==360 and side.hp==360 and outside.hp==1000,"Rapid T spam applies one AoE per landing")
	await clear_foes();await reset()
	e=dummy(Vector3(0,0,-6));side=dummy(Vector3(3,0,-6))
	var wall=Geo.box(game,p.position+Vector3(1.8,1.5,-6),Vector3(.3,3,4),Geo.mat("888888"),true)
	await wait(.1);await key(KEY_T);await wait(.6)
	check(e.hp==840 and side.hp==1000,"Stomp area damage respects solid cover")
	wall.queue_free();await wait(.05)
	await fresh();e=dummy(Vector3(0,0,-6));p.soft_target=true
	await key(KEY_2);await mouse(true);await wait(1.3)
	check(e.hp==976 and p.musashi.beam==null and not p.musashi.is_charging(),"Holding LMB fires one normal fireball without charging")
	await mouse(false);await wait(.3);check(e.hp==976,"LMB release does not fire a second projectile")
	await fresh();e=dummy(Vector3(0,0,-6));e.hp=10000;e.max_hp=10000
	game.tuning.beam_width=4;game.tuning.beam_length=45
	await hold(KEY_T,true);await wait(.1)
	check(p.musashi.beam.balance.beam_radius==2 and p.musashi.beam.balance.beam_length==45,"Held beam uses Settings width and length")
	check(is_instance_valid(p.musashi.beam) and p.musashi.beam_held,"T immediately starts a beam from fists mode")
	await capture("02-held-beam");await wait(5.5)
	check(is_instance_valid(p.musashi.beam) and e.hp<9600,"Held T beam lasts beyond the old five-second duration and deals damage")
	await hold(KEY_T,false);await wait(.1)
	check(p.musashi.beam==null and not p.musashi.beam_guard,"Releasing T ends the beam and automatic shield")
	p.musashi.shield_cooldown=0;await key(KEY_R);await hold(KEY_T,true);await wait(.2);await hold(KEY_T,false)
	check(p.musashi.shield_left>0 and is_instance_valid(p.musashi.shield),"Independent R shield survives T release")
	await fresh();e=dummy(Vector3(2,0,0));origin=p.position
	var mode=p.musashi.ranged_mode
	await key(KEY_E);var arrival=dummy(p.musashi.teleport.destination-p.position+Vector3.RIGHT*2);await wait(.03)
	check(p.musashi.teleport.active and e.hp==988 and p.model.body.position.y>.1,"E smoke deals a small hit and gives Edo a hop")
	await capture("03-smoke-departure");await wait(.1)
	check(not p.model.visible,"Edo disappears in the departure smoke")
	await wait(.22);await capture("04-smoke-arrival")
	var travel=p.position.distance_to(origin)
	check(travel>=7 and travel<=75 and p.model.visible,"Edo reappears at a random destination within one hundred footsteps")
	await wait(.3)
	check(not p.musashi.teleport.active and p.model.visible and p.musashi.ranged_mode==mode,"Teleport finishes with visibility and weapon selection intact")
	check(e.hp==988 and arrival.hp==988,"Departure and arrival smoke each damage nearby enemies once")
	var positions=[]
	for i in range(12):
		p.dodge_cooldown=0;origin=p.position;await key(KEY_E);await wait(.6)
		var floor_hit=game.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(p.position+Vector3.UP,p.position-Vector3.UP,1))
		check(p.position.distance_to(origin)<=75.1 and not floor_hit.is_empty() and floor_hit.normal.y>.7,"Random teleport %d lands safely within range" % i)
		positions.append(p.position)
	check(positions[0].distance_to(positions[1])>5,"Successive teleports choose different destinations")
	await fresh();await hold(KEY_T,true);await key(KEY_E);await wait(.6)
	check(p.musashi.beam==null,"Smoke teleport cancels a held beam safely");await hold(KEY_T,false)
	await fresh();await hold(KEY_T,true);await key(KEY_C);await wait(.1)
	check(p.musashi.beam==null,"Standard dodge cancels held beam");await hold(KEY_T,false)
	await fresh();await hold(KEY_T,true);game.show_pause();await wait(.1)
	check(p.musashi.beam==null,"Pause cancels held beam");game.resume();await hold(KEY_T,false)
	await fresh();await hold(KEY_T,true);await key(KEY_Q)
	check(p.musashi.beam==null and p.character_id==1,"Character switch cancels held beam");await hold(KEY_T,false)
	await pursuit_checks()
	if visual:
		var gate=game.gates[0];game.camera_rig.set_process(false)
		game.camera_rig.camera.global_position=gate.global_position+Vector3(12,9,19)
		game.camera_rig.camera.look_at(gate.global_position+Vector3.UP*5)
		await wait(.3);await capture("05-energy-portal")
	check(game.gates[0].unlocked,"Energy portal remains open for map travel")
	print("AOE_EDO_RESULT failures=",failures)
	get_tree().quit(1 if failures else 0)

func pursuit_checks():
	var p=game.player
	var e: Ninja
	var origin: Vector3
	await clear_foes();await reset()
	var remote=Vector3(0,game.world.height_at(0,-275)+.2,-275)
	e=dummy(remote-p.position);e.training_dummy=false;e.practice=false
	var before=e.position;game.tuning.freeze_ai=false
	var started=Time.get_ticks_usec();game.pursuit.refresh_field(p.position)
	print("NAV_BUILD_MS ",(Time.get_ticks_usec()-started)/1000.0," CELLS ",game.pursuit.distances.size())
	await wait(3)
	check(e.position.distance_to(before)>5 and e.position.distance_to(p.position)<before.distance_to(p.position),"Enemy more than 300 metres away pursues the player")
	check(game.pursuit.distances.has(game.pursuit.cell_of(e.position)),"Remote outpost connects to shared pursuit routes")
	game.tuning.freeze_ai=true;before=e.position;await wait(.4)
	check(Vector2(e.position.x-before.x,e.position.z-before.z).length()<.1,"Freeze AI still stops cross-map pursuit")
	# Exercise global pursuit on the entire actual population in every map.
	for area in range(4):
		game.area_states.clear();game.rebuild_area(area);game.reset_player_at(game.world.spawn_point);await wait(.3)
		var starts=[]
		for foe in game.enemies:starts.append(foe.position)
		game.tuning.freeze_ai=false;await wait(3)
		var moving=0;var reachable=0
		for i in range(game.enemies.size()):
			var foe=game.enemies[i]
			if Vector2(foe.position.x-starts[i].x,foe.position.z-starts[i].z).length()>.5:moving+=1
			if game.pursuit.distances.has(game.pursuit.cell_of(foe.position)):reachable+=1
		print("PURSUIT_AREA ",area," moving=",moving," reachable=",reachable," total=",game.enemies.size())
		check(moving>game.enemies.size()*.85,"Map %d enemies pursue across the enlarged area" % area)
		game.tuning.freeze_ai=true
	await wall_check()

func wall_check():
	var p=game.player
	var e: Ninja
	game.rebuild_area(0);game.reset_player_at(Vector3(0,game.world.height_at(0,41)+.05,41));await clear_foes()
	var wall=Geo.box(game,p.position+Vector3(0,2,-10),Vector3(12,4,1),Geo.mat("888888"),true)
	e=dummy(Vector3(0,0,-22));e.training_dummy=false;e.practice=false
	await wait(.1);game.pursuit.configure();game.tuning.freeze_ai=false
	await wait(12)
	print("WALL_END ",e.position," player ",p.position," route ",e.route_direction," field ",game.pursuit.ready_field," cells ",game.pursuit.distances.size())
	check(e.position.distance_to(p.position)<7,"Enemy routes around a wide solid wall to reach the player")
	game.tuning.freeze_ai=true;wall.queue_free()
