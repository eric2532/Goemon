extends Node
var game: Node
var failures=0

func check(condition: bool,message: String):
	if condition: print("PASS: ",message)
	else:
		failures+=1
		push_error("EXPANSION TEST: "+message)

func key(code: Key):
	var event=InputEventKey.new()
	event.physical_keycode=code
	event.pressed=true
	Input.parse_input_event(event)
	var release=InputEventKey.new()
	release.physical_keycode=code
	release.pressed=false
	Input.parse_input_event(release)
	await get_tree().process_frame
	await get_tree().physics_frame

func settle(seconds: float=0.2):
	await get_tree().create_timer(seconds).timeout

func gate_travel(destination: int):
	for gate in game.gates:
		if gate.destination==destination:
			game.player.position=gate.position+Vector3(0,0.1,2.4)
			game.player.velocity=Vector3.ZERO
			await key(KEY_F)
			var deadline=Time.get_ticks_msec()+15000
			while game.transitioning and Time.get_ticks_msec()<deadline: await settle(0.05)
			check(game.area_index==destination and not game.transitioning,"F doorway transition to area "+str(destination))
			return
	check(false,"Missing door to area "+str(destination))

func stop_enemies():
	for e in game.enemies:
		if is_instance_valid(e): e.set_physics_process(false)

func run():
	game.tuning=PrototypeTuning.DEFAULTS.duplicate()
	game.start_game()
	game.player.smoke_mode=true
	await settle(0.6)
	stop_enemies()
	await key(KEY_2)
	check(game.player.weapon_slot==2 and game.player.model.coin.visible and not game.player.model.equipped,"2 selects the visible coin weapon")
	await key(KEY_1)
	check(game.player.weapon_slot==1 and game.player.model.equipped and not game.player.model.coin.visible,"1 selects the golden pipe")
	await key(KEY_SPACE)
	await settle(0.22)
	var first_y=game.player.position.y
	game.player.smoke_move=Vector2(1,0)
	await key(KEY_SPACE)
	await settle(0.1)
	check(game.player.jumps_used==2 and game.player.position.y>first_y and game.player.velocity.x>7,"Second Space jumps again and redirects momentum")
	var before=game.player.velocity.y
	await key(KEY_SPACE)
	await settle(0.06)
	check(game.player.jumps_used==2 and game.player.velocity.y<before,"Third Space cannot grant another air jump")
	game.player.smoke_move=Vector2.ZERO
	await settle(1.3)
	check(game.player.is_on_floor() and game.player.jumps_used==0,"Landing restores both jumps")
	game.reset_player_at(Vector3(0,game.world.height_at(0,41)+0.05,41))
	await settle(0.3)
	var target=game.enemies[0]
	target.position=Vector3(0,game.world.height_at(0,29),29)
	game.camera_rig.yaw=0
	await key(KEY_2)
	game.send_action("light_attack")
	await settle(0.75)
	check(target.hp==46,"Thrown coin travels and deals 20 damage")
	# A physical wall must block both aim assist and the projectile itself.
	var wall=Geo.box(game,Vector3(0,3,35),Vector3(4,5,0.4),Geo.mat("665544"),true)
	await settle(0.1)
	var hp=target.hp
	game.send_action("light_attack")
	await settle(0.8)
	check(target.hp==hp,"Gold coins cannot damage through solid walls")
	wall.queue_free()
	await settle(0.1)
	game.send_action("heavy_attack")
	await settle(0.85)
	check(is_instance_valid(target) and target.hp==22,"Center coin of split fan deals 24 damage")
	game.player.position=game.gates[0].position+Vector3(0,0.1,2.4)
	game.player.velocity=Vector3.ZERO
	await key(KEY_F)
	await settle(0.1)
	while game.transitioning:await settle(.05)
	check(game.area_index==1,"Forward door opens before the guardian is defeated")
	await gate_travel(0)
	stop_enemies()
	game.boss_enemy.take_hit(5000,Vector3.FORWARD,true)
	await settle(0.2)
	check(game.area_cleared.get(0,false) and not game.won,"First guardian clears only the first area")
	await gate_travel(1)
	check(game.world is ExpeditionArea,"A generated map replaces the sanctuary")
	stop_enemies()
	var layout=game.world.centers.duplicate()
	var seed=game.world.generation_seed
	game.enemies[0].take_hit(10,Vector3.FORWARD,false)
	game.world.motes[0].hide()
	await gate_travel(0)
	check(game.area_cleared.get(0,false) and not is_instance_valid(game.boss_enemy),"Defeated guardian remains defeated when backtracking")
	await gate_travel(1)
	stop_enemies()
	check(game.world.centers==layout and game.world.generation_seed==seed,"Returning to an area preserves its generated layout")
	check(game.enemies[0].hp==56 and not game.world.motes[0].visible,"Backtracking preserves damage and collected sparks")
	for index in range(1,4):
		stop_enemies()
		var boss=game.boss_enemy
		check(boss.boss_style==index,"Distinct guardian variant in area "+str(index))
		# Terrain and collision samples cover every generated path edge.
		for route in game.world.routes:
			for j in range(11):
				var p=route[0].lerp(route[1],j/10.0)
				p.y=game.world.height_at(p.x,p.z)
				var ray=PhysicsRayQueryParameters3D.create(p+Vector3.UP*0.7,p-Vector3.UP,1)
				check(not game.get_world_3d().direct_space_state.intersect_ray(ray).is_empty(),"Walkable floor on area %d route sample" % index)
		# Walk the first route using the actual character controller, not teleports.
		game.reset_player_at(game.world.spawn_point)
		game.player.invuln=100
		game.camera_rig.yaw=0
		var destination=game.world.centers[1]
		var walk_deadline=Time.get_ticks_msec()+12000
		while Vector2(game.player.position.x-destination.x,game.player.position.z-destination.z).length()>1.0 and Time.get_ticks_msec()<walk_deadline:
			game.player.smoke_move=Vector2(destination.x-game.player.position.x,destination.z-game.player.position.z).normalized()
			await settle(0.08)
		game.player.smoke_move=Vector2.ZERO
		check(Vector2(game.player.position.x-destination.x,game.player.position.z-destination.z).length()<1.5,"Physical traversal from entrance to first court in area "+str(index))
		# Verify each boundary really has a collision wall.
		var border=PhysicsRayQueryParameters3D.create(Vector3(game.world.playable_bounds.end.x-4,20,0),Vector3(game.world.playable_bounds.end.x+6,20,0),1)
		check(not game.get_world_3d().direct_space_state.intersect_ray(border).is_empty(),"Confined boundary in area "+str(index))
		game.player.position=boss.position+Vector3(0,0,7)
		game.player.velocity=Vector3.ZERO
		game.player.invuln=0
		game.player.hp=100
		await settle(0.2)
		if index==1:
			boss.fire_fan()
			await settle(0.55)
			check(game.player.hp<100,"Hisui crystal volley can damage the player")
		elif index==2:
			var wave=BossWave.new()
			wave.game=game
			wave.position=boss.position
			game.add_child(wave)
			await settle(0.85)
			check(game.player.hp<100,"Hanami ground wave hits grounded players")
			game.player.invuln=0
			game.player.hp=100
			await key(KEY_SPACE)
			var airborne=BossWave.new()
			airborne.game=game
			airborne.position=boss.position
			game.add_child(airborne)
			await settle(0.3)
			await key(KEY_SPACE)
			await settle(0.45)
			check(game.player.hp==100,"Double jump evades Hanami's expanding wave")
		boss.take_hit(5000,Vector3.FORWARD,true)
		await settle(0.2)
		if index<3: await gate_travel(index+1)
	check(game.won and game.area_cleared.size()==4,"Only defeating all four bosses wins the expedition")
	# Seeded generation: repeated seeds match, different seeds change the route graph.
	for index in range(1,4):
		var a=ExpeditionArea.new()
		var b=ExpeditionArea.new()
		a.area_index=index
		b.area_index=index
		a.generation_seed=11223
		b.generation_seed=11223
		a.plan_layout()
		b.plan_layout()
		check(a.centers==b.centers,"Deterministic generation for area "+str(index))
		b.generation_seed=98766
		b.plan_layout()
		check(a.centers!=b.centers,"Different seed changes area "+str(index))
		a.free()
		b.free()
	game.restart_area()
	check(game.area_index==3 and game.player.hp==100 and not game.area_cleared.has(3) and game.area_cleared.size()==3,"Retry resets only the current room")
	game.show_pause()
	check(get_tree().paused,"Pause still works in a generated area")
	game.resume()
	print("EXPANSION_TEST_RESULT failures=",failures)
	game.playing=false
	game.music.stop()
	for voice in game.voices: voice.stop()
	await settle(0.3)
	get_tree().quit(0 if failures==0 else 1)
