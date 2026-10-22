extends SceneTree
var game
var failures=0
func check(ok: bool,message: String):
	print("PASS: " if ok else "FAIL: ",message)
	if not ok:failures+=1
func _initialize():call_deferred("run")
func legacy_shapes(node: Node,result: Array):
	if node is TidefallTown:return
	if node is CollisionShape3D:
		result.append([str(node.global_transform),str(node.shape.get_faces()).sha256_text(),node.disabled])
	for child in node.get_children():legacy_shapes(child,result)
func belongs_to(node: Node,ancestor: Node)->bool:
	while node:
		if node==ancestor:return true
		node=node.get_parent()
	return false
func run():
	game=load("res://scenes/main.tscn").instantiate();root.add_child(game)
	await process_frame
	game.smoke_test=true;game.start_game();game.encounters.set_physics_process(false)
	game.player.smoke_mode=true;game.player.set_physics_process(false);game.tuning.freeze_ai=true
	game.world.set_process(false)
	await physics_frame
	var town=game.world.get_node("TidefallTown")
	check(town.buildings.size()==24,"24 main-area buildings instantiate")
	var variants={}
	for house in town.buildings:variants[house.get_meta("town_variant")]=true
	check(variants.size()==5,"All five Blender building variants appear")
	var before=JSON.parse_string(FileAccess.get_file_as_string("res://tests/tidefall-town/before-audit.json"))["0"]
	var shapes=[];legacy_shapes(game.world,shapes);shapes.sort_custom(func(a,b):return str(a)<str(b))
	check(shapes==before.collisions,"All 712 pre-existing collision shapes/transforms remain exact")
	var heights=[]
	for x in range(-280,281,7):
		for z in range(-440,280,7):heights.append(game.world.height_at(x,z))
	check(str(heights).sha256_text()==before.heights,"All 8,343 terrain height samples remain exact")
	check(str(game.world.rng.state)==before.rng_state,"Town does not consume the environment RNG")
	check(str(game.world.outposts)==before.outposts and str(game.world.playable_bounds)==before.bounds,"Existing outposts and map bounds stay unchanged")
	var routes=[[Vector2(0,44),Vector2(-8,-29),4.8],[Vector2(-4,-8),Vector2(16,-8),4.0],[Vector2(32,-8),Vector2(45,-36),4.0],[Vector2(-7,8),Vector2(-43,-5),3.0],[Vector2(-43,-5),Vector2(-23,-36),3.0]]
	for side in [-1,1]:
		routes.append([Vector2(side*43,-24),Vector2(side*76,-51),5.5])
		routes.append([Vector2(side*76,-51),Vector2(side*38,-81),5.5])
		routes.append([Vector2(side*38,-81),Vector2(-10,-56),5.5])
	var blocked=0
	for route in routes:
		for i in range(201):
			var p=route[0].lerp(route[1],i/200.0)
			for rect in town.footprints:
				if rect.grow(route[2]*.5+.7).has_point(p):blocked+=1
	check(blocked==0,"11 original route corridors plus player clearance remain outside all buildings (%d overlaps)" % blocked)
	var courts=[Vector2(45,-40),Vector2(-76,-51),Vector2(76,-51)]
	var court_overlap=false
	for center in courts:
		for rect in town.footprints:
			var nearest=Vector2(clampf(center.x,rect.position.x,rect.end.x),clampf(center.y,rect.position.y,rect.end.y))
			if nearest.distance_to(center)<13:court_overlap=true
	check(not court_overlap,"All three established combat courts and their rims stay open")
	var space=game.get_world_3d().direct_space_state
	var capsule=CapsuleShape3D.new();capsule.radius=.72;capsule.height=1.85
	var query=PhysicsShapeQueryParameters3D.new();query.shape=capsule;query.collision_mask=1
	var filled=0;var solid_fronts=0;var solid_roofs=0
	for house in town.buildings:
		query.transform=Transform3D(Basis.IDENTITY,house.global_position+Vector3.UP)
		for hit in space.intersect_shape(query,32):
			if belongs_to(hit.collider,house):filled+=1;break
		var front=house.to_global(Vector3(0,1.5,3.2));var back=house.to_global(Vector3(0,1.5,0))
		var hit=space.intersect_ray(PhysicsRayQueryParameters3D.create(front,back,1))
		if not hit.is_empty() and belongs_to(hit.collider,house):solid_fronts+=1
		hit=space.intersect_ray(PhysicsRayQueryParameters3D.create(house.global_position+Vector3.UP*15,house.global_position+Vector3.UP*3,1))
		if not hit.is_empty() and belongs_to(hit.collider,house):solid_roofs+=1
	check(filled==24,"All 24 building interiors reject enemy/player capsule placement")
	check(solid_fronts==24,"All 24 closed shopfronts stop movement/combat rays")
	check(solid_roofs==24,"All 24 roof silhouettes have matching solid collision")
	game.pursuit.refresh_field(game.player.position)
	var connected=0
	for p in [Vector2(-2,20),Vector2(-2,1),Vector2(-52,34),Vector2(47.5,33),Vector2(47.5,0),Vector2(-10,-18)]:
		var point=Vector3(p.x,game.world.height_at(p.x,p.y),p.y);var cell=game.pursuit.cell_of(point)
		if game.pursuit.distances.has(cell):connected+=1
	check(connected==6,"Existing navigation field connects six town street/plaza destinations (%d/6)" % connected)
	# Confirm camera probes at the normal gameplay settings remain unobstructed along the principal views.
	var camera_clear=0
	for p in [Vector2(0,41),Vector2(-2,20),Vector2(-2,1),Vector2(47.5,33),Vector2(-10,-18)]:
		game.player.position=Vector3(p.x,game.world.height_at(p.x,p.y)+.2,p.y);game.camera_rig.yaw=0;game.camera_rig.reset_follow()
		for i in range(30):game.camera_rig._process(1.0/30.0)
		if game.camera_rig.current_distance>13.5:camera_clear+=1
	check(camera_clear==5,"Five principal views retain the normal 14m gameplay camera (%d/5)" % camera_clear)
	var placements=[]
	for house in town.buildings:
		placements.append({"instance_id":str(house.name),"asset_id":"town/"+house.get_meta("town_variant"),"position_xyz":[house.position.x,house.position.y,house.position.z],"yaw_radians":house.rotation.y})
	DirAccess.make_dir_recursive_absolute("res://docs/tidefall-town")
	FileAccess.open("res://docs/tidefall-town/placements.json",FileAccess.WRITE).store_string(JSON.stringify(placements,"\t"))
	print("TIDEFALL_TOWN_RESULT failures=",failures)
	game.quit_clean()
