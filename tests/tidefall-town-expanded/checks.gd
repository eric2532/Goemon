extends SceneTree
var game
var town
var failures=0
var checks=0
func _initialize():call_deferred("run")
func check(ok: bool,label: String):
	checks+=1;print("PASS: " if ok else "FAIL: ",label)
	if not ok:failures+=1
func belongs_to(node: Node,ancestor: Node)->bool:
	while node:
		if node==ancestor:return true
		node=node.get_parent()
	return false
func walk_to(target: Vector3,frames: int=260)->bool:
	var p=game.player
	p.set_physics_process(true)
	for i in frames:
		var d=target-p.position;d.y=0
		if d.length()<.5:break
		p.smoke_move=Vector2(d.x,d.z).normalized()
		await physics_frame
	p.smoke_move=Vector2.ZERO
	for i in 20:await physics_frame
	p.set_physics_process(false)
	return Vector2(p.position.x-target.x,p.position.z-target.z).length()<.7 and absf(p.position.y-target.y)<.5
func capture(label: String,p: Vector3,yaw: float,pitch: float=.36):
	game.player.position=p;game.player.velocity=Vector3.ZERO
	var rig=game.camera_rig;rig.yaw=yaw;rig.pitch=pitch;rig.current_distance=14;rig.reset_follow()
	for i in 30:rig._process(1.0/30)
	await process_frame;await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("/tmp/goemon-town-expanded-"+label+".png")
	print("NATIVE_CAPTURE ",label," camera_distance=",rig.current_distance)
func run():
	game=load("res://scenes/main.tscn").instantiate();root.add_child(game);await process_frame
	game.smoke_test=true;game.tuning=PrototypeTuning.DEFAULTS.duplicate();game.tuning.freeze_ai=true;game.tuning.invincible=true
	game.start_game();game.encounters.enabled=false;game.encounters.pending=0;game.orb_system.active=false
	game.player.smoke_mode=true;game.player.set_physics_process(false);game.player.select_character(2)
	game.camera_rig.set_process(false);game.camera_rig.set_process_unhandled_input(false);game.world.set_process(false)
	for e in get_nodes_in_group("enemies"):e.queue_free()
	await process_frame;await physics_frame
	town=game.world.get_node("TidefallTown")
	print("TOWN_ACTUAL_COUNT ",town.buildings.size())
	check(town.buildings.size()==48,"48 town buildings (24 added)")
	var enterable=[];var scales=true;var variants={}
	for h in town.buildings:
		scales=scales and h.get_node("BuildingVisual").scale.is_equal_approx(Vector3.ONE*4)
		variants[h.get_meta("town_variant")]=true
		if h.get_meta("enterable"):enterable.append(h)
	check(scales,"Every town visual uses exact 4x linear scale")
	check(variants.size()==6,"Five original variants plus original open house")
	check(enterable.size()==3,"Three houses have real open-door interiors")
	var before=JSON.parse_string(FileAccess.get_file_as_string("res://tests/tidefall-town/before-audit.json"))["0"]
	check(str(game.world.outposts)==before.outposts and str(game.world.playable_bounds)==before.bounds,"Outposts and map bounds remain exact")
	check(str(game.world.rng.state)==before.rng_state,"Town consumes no environment RNG")
	var reserved_clear=true
	for route in TidefallTown.original_routes(game.world):
		for i in range(201):
			var p=route[0].lerp(route[1],i/200.0)
			for rect in town.footprints:
				if rect.grow(route[2]*.5+.7).has_point(p):reserved_clear=false
	check(reserved_clear,"All original and outer route corridors retain player clearance")
	var courts_clear=true
	for center in [Vector2(45,-40),Vector2(-76,-51),Vector2(76,-51),Vector2(0,41)]:
		for rect in town.footprints:
			var nearest=Vector2(clampf(center.x,rect.position.x,rect.end.x),clampf(center.y,rect.position.y,rect.end.y))
			if nearest.distance_to(center)<13:courts_clear=false
	check(courts_clear,"Spawn and three combat courts remain open")
	var heights_exact=true
	for x in range(-280,281,7):
		for z in range(-440,63,7):
			var inside=false
			for lot in TidefallTown.OPEN_LOTS:
				if TidefallTown.footprint(lot).grow(6).has_point(Vector2(x,z)):inside=true
			if inside:continue
			var h=game.world.coastal_height(x,z)
			for side in [-1,1]:
				var d=Vector2(x-side*76,z+51).length()
				if d<17:h=lerpf(game.world.coastal_height(side*76,-51),h,smoothstep(12,17,d))
			heights_exact=heights_exact and is_equal_approx(game.world.height_at(x,z),WorldExpansion.flatten(game.world,x,z,h))
	check(heights_exact,"Terrain stays unchanged outside the three entrance lots")
	var space=game.get_world_3d().direct_space_state
	var closed_count=0;var roofs=0
	for h in town.buildings:
		var hit=space.intersect_ray(PhysicsRayQueryParameters3D.create(h.to_global(Vector3(0,2,15)),h.to_global(Vector3(0,2,0)),1))
		if not h.get_meta("enterable") and not hit.is_empty() and belongs_to(hit.collider,h):closed_count+=1
		hit=space.intersect_ray(PhysicsRayQueryParameters3D.create(h.position+Vector3.UP*40,h.position+Vector3.UP*3,1))
		if not hit.is_empty() and belongs_to(hit.collider,h):roofs+=1
	check(closed_count==45,"All 45 closed houses block entry")
	check(roofs==48,"All 48 roofs have matching solid collision")
	game.pursuit.refresh_field(Vector3(0,game.world.height_at(0,41),41))
	var important_connected=true
	for point in game.world.outposts+[Vector3(-76,0,-51),Vector3(76,0,-51),Vector3(45,0,-40),Vector3(-10,0,-18)]:
		var cell=game.pursuit.cell_of(point);var nearby=false
		for dx in range(-1,2):
			for dz in range(-1,2):
				var c=cell+Vector2i(dx,dz)
				if game.pursuit.distances.has(c):
					var ground=game.pursuit.ground(c)
					if Vector2(ground.x-point.x,ground.z-point.z).length()<6:nearby=true
		important_connected=important_connected and nearby
	check(important_connected,"All nine outposts, court approaches, and temple approach remain connected within 6m")
	for h in enterable:
		var center=h.to_global(Vector3(0,.14,0));var outside=h.to_global(Vector3(0,.14,18))
		outside.y=game.world.height_at(outside.x,outside.z)+.14
		var id=str(h.name)
		check(game.pursuit.distances.has(game.pursuit.cell_of(center)),id+" interior reachable by enemy navigation from spawn")
		var clear=space.intersect_ray(PhysicsRayQueryParameters3D.create(outside+Vector3.UP,center+Vector3.UP,1)).is_empty()
		check(clear,id+" doorway has a clear walking/combat-ray path")
		var floor_hit=space.intersect_ray(PhysicsRayQueryParameters3D.create(center+Vector3.UP,center-Vector3.UP,1))
		check(not floor_hit.is_empty() and belongs_to(floor_hit.collider,h) and floor_hit.normal.y>.99,id+" interior floor is real and level")
		var wall_hit=space.intersect_ray(PhysicsRayQueryParameters3D.create(center+Vector3.UP,h.to_global(Vector3(18,1,0)),1))
		check(not wall_hit.is_empty() and belongs_to(wall_hit.collider,h),id+" side wall stops collision")
		game.player.position=outside;game.player.velocity=Vector3.ZERO;game.camera_rig.yaw=0
		for repeat in 2:
			check(await walk_to(center),id+" player enters on foot repeat "+str(repeat+1))
			check(await walk_to(outside),id+" player exits on foot repeat "+str(repeat+1))
		game.player.position=center;game.player.velocity=Vector3.ZERO
		game.pursuit.refresh_field(center)
		game.encounters.spawn_rng.seed=90824
		var spawns_connected=true
		for sample in 12:
			game.encounters.total_spawned=sample;var spawn=game.encounters.wave_spawn_point()
			spawns_connected=spawns_connected and spawn!=null
			if spawn!=null:spawns_connected=spawns_connected and (game.pursuit.clear_segment(spawn,center) or game.pursuit.distances.has(game.pursuit.cell_of(spawn)))
		check(spawns_connected,id+" all 12 nearby enemy spawn samples connect through town")
		var enemy=Ninja.new();enemy.game=game;enemy.practice=true;enemy.position=outside;game.add_child(enemy);enemy.cooldown=999;enemy.alerted=true
		game.tuning.freeze_ai=false
		for i in 420:
			await physics_frame
			if enemy.position.distance_to(center)<3:break
		game.tuning.freeze_ai=true
		print("ENEMY_DOOR_DISTANCE ",id," ",enemy.position.distance_to(center)," state=",enemy.state," position=",enemy.position)
		check(enemy.position.distance_to(center)<3,id+" pursuing enemy enters through doorway")
		enemy.queue_free();await process_frame
		game.camera_rig.yaw=h.rotation.y;game.camera_rig.current_distance=14;game.camera_rig.reset_follow()
		for i in 30:game.camera_rig._process(1.0/30)
		var ray=PhysicsRayQueryParameters3D.create(game.camera_rig.follow,game.camera_rig.camera.position,1)
		check(game.camera_rig.current_distance>3 and space.intersect_ray(ray).is_empty(),id+" interior camera remains usable without wall clipping")
	var camera_clear=0
	for p in [Vector2(0,41),Vector2(-2,20),Vector2(-2,1),Vector2(47.5,33),Vector2(-10,-18)]:
		game.player.position=Vector3(p.x,game.world.height_at(p.x,p.y)+.14,p.y);game.camera_rig.yaw=0;game.camera_rig.reset_follow();game.camera_rig.current_distance=14
		for i in 30:game.camera_rig._process(1.0/30)
		if game.camera_rig.current_distance>13.5:camera_clear+=1
	check(camera_clear==5,"Five principal views keep the normal 14m camera")
	check(game.active_enemy_limit==200 and game.crowd.batches.size()==4,"Enemy cap 200 and all four species remain active")
	check(game.player.model.rig_visual.scene_file_path==MusashiModel.REVIEW_MODEL,"Expanded town keeps colored V05 Edo integrated")
	if "--visual" in OS.get_cmdline_user_args():
		root.size=Vector2i(1024,720);root.set_flag(Window.FLAG_NO_FOCUS,true);game.hud.hide();Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
		await capture("spawn",Vector3(0,game.world.height_at(0,41)+.14,41),0)
		await capture("street",Vector3(-2,game.world.height_at(-2,20)+.14,20),PI/2)
		var h=enterable[0]
		await capture("doorway",h.to_global(Vector3(0,.14,20)),h.rotation.y)
		await capture("interior",h.to_global(Vector3(0,.14,1)),h.rotation.y)
		var cam=game.camera_rig.camera;cam.position=h.to_global(Vector3(0,5,9));cam.look_at(h.to_global(Vector3(0,1,-5)));cam.fov=75
		await process_frame;await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png("/tmp/goemon-town-expanded-interior-wide.png")
		cam.position=Vector3(95,70,80);cam.look_at(Vector3(-35,5,-80));cam.fov=75
		await process_frame;await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png("/tmp/goemon-town-expanded-overview.png")
	var placements=[]
	for h in town.buildings:placements.append({"id":str(h.name),"variant":h.get_meta("town_variant"),"position":[h.position.x,h.position.y,h.position.z],"scale":4,"enterable":h.get_meta("enterable")})
	FileAccess.open("/tmp/goemon-town-expanded-placements.json",FileAccess.WRITE).store_string(JSON.stringify(placements,"\t"))
	print("TOWN_EXPANDED_RESULT checks=",checks," failures=",failures)
	game.queue_free();await process_frame;await process_frame;quit(1 if failures else 0)
