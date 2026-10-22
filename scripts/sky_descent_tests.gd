extends "res://scripts/combat_tests.gd"
var visual=false

func frames(count: int):
	for i in range(count):await get_tree().physics_frame

func capture(label: String):
	if not visual:return
	game.hud.banner_time=0;game.hud.toast_time=0;game.player.invuln=0
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://tests/sky-descent/"+label+".png")

func walk_toward(target: Vector3,limit: int=1200)->bool:
	var p=game.player
	for i in range(limit):
		var offset=target-p.position;offset.y=0
		if offset.length()<1.0 and p.is_on_floor():p.smoke_move=Vector2.ZERO;return true
		var local=offset.normalized().rotated(Vector3.UP,-game.camera_rig.yaw)
		p.smoke_move=Vector2(local.x,local.z)
		await frames(1)
	p.smoke_move=Vector2.ZERO;return false

func run():
	visual="--descent-visual" in OS.get_cmdline_user_args()
	Input.use_accumulated_input=false
	game.tuning=PrototypeTuning.DEFAULTS.duplicate();game.tuning.invincible=true;game.tuning.freeze_ai=true
	game.start_game();game.player.smoke_mode=true
	game.camera_rig.set_process_unhandled_input(false);get_window().set_flag(Window.FLAG_NO_FOCUS,true);Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	var p=game.player;var sky=game.world.sky_islands;var run=game.encounters
	await frames(15)
	check(sky.islands.size()==784 and sky.clouds.size()>150 and sky.clouds.size()<350 and sky.cedar_count==784,"784 islands, sparse solid Blender clouds, and merged Cedar Pass props are present")
	check(p.is_on_floor() and sky.island_at(p.position)==0,"Start on the highest island")
	var geometry_ok=true
	for layer in range(sky.LAYERS):
		for slot in range(sky.PER_LAYER):
			var index=layer*sky.PER_LAYER+slot;var point=sky.islands[index]
			geometry_ok=geometry_ok and is_equal_approx(point.y,sky.islands[layer*sky.PER_LAYER].y)
			var hit=game.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(point+Vector3.UP*2,point-Vector3.UP*2,1))
			geometry_ok=geometry_ok and not hit.is_empty() and hit.normal.y>.9
	check(geometry_ok,"All 14 layers have 56 same-height, physically walkable islands")
	var clouds_ok=true
	for point in sky.cloud_origins:
		var hit=game.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(point+Vector3.UP*2,point-Vector3.UP*2,1))
		clouds_ok=clouds_ok and not hit.is_empty() and hit.normal.y>.99 and absf(hit.position.y-point.y)<.03
	check(clouds_ok,"Every cloud has a flat visible collision surface")
	check(game.enemies.size()==40 and run.remaining_on(4)==4,"Ten nearest encounters are ready")
	if visual:
		game.camera_rig.set_process(false)
		var center=sky.ground_point+Vector3(55,sky.LAYERS*sky.DROP,-30)
		game.camera_rig.camera.global_position=center+Vector3(95,105,145)
		game.camera_rig.camera.look_at(center-Vector3.UP*15);game.camera_rig.camera.fov=70
		await capture("07-choose-your-island")
		game.hud.hide();game.camera_rig.camera.global_position=center+Vector3(290,-170,420)
		game.camera_rig.camera.look_at(center-Vector3.UP*330)
		await capture("08-cloud-archipelago")
		game.hud.show();game.camera_rig.set_process(true);game.camera_rig.reset_follow()
	# Clouds are isolated rest stops, so validate a real gravity landing.
	game.reset_player_at(sky.cloud_origins[0]+Vector3.UP*3);await frames(45)
	check(p.is_on_floor(),"Land on an isolated cloud through normal gravity")
	var cloud_y=p.position.y
	await frames(45)
	check(p.is_on_floor() and absf(p.position.y-cloud_y)<.05 and sky.cloud_at(p.position)==0,"Cloud supports the player steadily without drift or teleport")
	await key(KEY_SPACE);await frames(14)
	check(p.position.y>cloud_y+1 and not p.is_on_floor(),"Jump works normally from a cloud")
	await frames(65)
	check(p.is_on_floor() and absf(p.position.y-cloud_y)<.08,"Jump lands back on the cloud")
	game.reset_player_at(sky.islands[1]+Vector3.UP*3);await frames(45)
	check(p.is_on_floor(),"A different same-layer island remains a valid landing destination")
	await frames(3)
	check(run.current_island==1 and run.visited.has(1),"Chosen island becomes the active encounter")
	p.hp=40
	var defeated_id=""
	for enemy in game.enemies:
		if enemy.island_index==1:
			defeated_id=enemy.encounter_id
			enemy.take_hit(100000,Vector3.UP,true);enemy.take_hit(100000,Vector3.UP,true);break
	check(p.progression.level==2 and is_equal_approx(p.max_hp,100+300.0/98),"Chosen-island kill grants one level and health exactly once")
	var kills=p.progression.total_kills
	# Initialize independent landing cases, then let normal gravity land the hero.
	game.reset_player_at(sky.islands[4*sky.PER_LAYER+3]+Vector3.UP*7);await frames(65)
	check(run.current_island==4*sky.PER_LAYER+3 and p.is_on_floor() and run.recoveries==0,"Skip several layers and land on any island without forced return")
	check(p.progression.total_kills==kills and run.remaining_on(0)>=sky.enemy_count(0) and not run.cleared.has(0),"Unloaded skipped islands grant no kills, levels or clears")
	game.reset_player_at(sky.islands[1]+Vector3.UP*3);await frames(45)
	check(run.current_island==1 and run.defeated.has(defeated_id) and not game.enemies.any(func(enemy):return is_instance_valid(enemy) and not enemy.dead and enemy.encounter_id==defeated_id),"Returning to an earlier island retains its defeated enemy")
	game.reset_player_at(sky.islands[0]+Vector3.UP*3);await frames(45)
	check(run.current_island==0,"Lower-numbered islands remain selectable")
	# Validate each island as an independent landing destination and encounter.
	var route_ok=true
	var samples=[]
	for layer in range(sky.LAYERS):
		for slot in [0,sky.COLUMNS-1,sky.PER_LAYER-sky.COLUMNS,sky.PER_LAYER-1,sky.PER_LAYER/2]:samples.append(layer*sky.PER_LAYER+int(slot))
	for index in samples:
		game.reset_player_at(sky.islands[index]+Vector3.UP*.12);await frames(10)
		route_ok=route_ok and p.is_on_floor() and run.current_island==index and game.active_enemy_count()<=120
	check(route_ok,"All map corners and central landing samples activate with bounded nearby encounters")
	game.reset_player_at(sky.cloud_origins[-1]+Vector3.UP*3);await frames(45)
	check(p.is_on_floor() and sky.cloud_at(p.position)>=0 and not run.completed,"A low cloud is still a sky platform, not a ground arrival")
	check(absf(game.world.surface_height_at(p.position)-p.position.y)<.05,"Ability height queries use the physical cloud surface")
	# A fresh run falls the entire height through an open lane, without visiting the last island.
	var original_islands=sky.islands.duplicate();var original_clouds=sky.cloud_origins.duplicate()
	game.restart_area();await frames(15);run=game.encounters;sky=game.world.sky_islands
	check(sky.islands==original_islands and sky.cloud_origins==original_clouds,"Retry preserves the seeded island and cloud layout")
	game.reset_player_at(Vector3(game.world.playable_bounds.end.x+4,sky.islands[0].y-100,-185))
	var edge_height=p.position.y
	await frames(3)
	check(p.position.y<=edge_height and p.position.y>edge_height-1 and p.hp==100,"World edge limits horizontal movement without an uphill reset or health penalty")
	# Pick a real open fall lane in this seed; a fixed X/Z may now hit a cloud.
	var fall_origin=Vector3.ZERO
	for x in range(-22,23,4):
		for z in range(-22,23,4):
			var start=sky.ground_point+Vector3(x,sky.LAYERS*sky.DROP+4,z)
			var hit=game.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(start,start-Vector3.UP*900,1))
			if not hit.is_empty() and absf(hit.position.y-game.world.height_at(start.x,start.z))<.3:
				fall_origin=start;break
		if fall_origin!=Vector3.ZERO:break
	check(fall_origin!=Vector3.ZERO,"Generated map contains an unobstructed full-height fall lane")
	game.reset_player_at(fall_origin)
	var previous_y=p.position.y;var uninterrupted=true
	for i in range(1100):
		await frames(1)
		if p.position.y>previous_y+.1:uninterrupted=false
		previous_y=p.position.y
		if run.completed:break
	check(uninterrupted and run.recoveries==0 and run.completed,"Uninterrupted freefall reaches ground directly without visiting intermediate islands")
	check(p.progression.level==1 and run.cleared.is_empty(),"Skipping the sky preserves level 1 and awards no unearned progress")
	await frames(90) # Ground arrivals are spread across frames.
	check(run.ground_remaining()==50,"Ground giants activate even when every lower island was skipped")
	p.progression.award_kills(98);p.refresh_max_health(true)
	check(p.progression.level==99 and is_equal_approx(p.max_hp,400),"Level cap and 400 maximum health remain intact")
	if visual:
		await capture("09-freefall-ground")
		game.show_main_menu();await capture("05-main-menu")
	print("DESCENT_RESULT failures=",failures)
	get_tree().quit(1 if failures else 0)
