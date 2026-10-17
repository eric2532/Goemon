extends SceneTree
const Model=preload("res://scripts/forest/forest_model.gd")
const Art=preload("res://scripts/forest/forest_art.gd")
var checks=0
var failures=0
func check(ok: bool,label: String):
	checks+=1
	print("PASS: " if ok else "FAIL: ",label)
	if not ok:failures+=1
func _initialize():call_deferred("run")
func run():
	var m=Model.new();preload("res://tests/forest-shrine/empty_settlement.gd").reset(m);m.gold=2000;m.workers.clear();m.hero_position=Vector3(0,0,18)
	for x in range(-15,16):
		for y in range(-15,16):m.explored[Vector2i(x,y)]=true
	check(m.shrine().hp>=3000 and m.shrine().hp==m.shrine().max_hp,"The main base begins with increased usable health")
	var horizontal=m.build("wall",Vector2i(-8,7),0)
	check(not horizontal.is_empty() and [Vector2i(-8,7),Vector2i(-7,7),Vector2i(-6,7),Vector2i(-5,7),Vector2i(-4,7),Vector2i(-3,7)].all(func(c):return m.occupancy.get(c,-1)==horizontal.get("id",-2)),"One horizontal wall reserves six grid cells")
	var vertical=m.build("wall",Vector2i(-8,8),1)
	check(not vertical.is_empty() and [Vector2i(-8,8),Vector2i(-8,9),Vector2i(-8,10),Vector2i(-8,11),Vector2i(-8,12),Vector2i(-8,13)].all(func(c):return m.occupancy.get(c,-1)==vertical.get("id",-2)),"Rotated wall meets a corner and extends six cells vertically")
	var before=m.gold
	check(m.build("wall",Vector2i(-9,7),0).is_empty() and m.gold==before,"Placement rejects overlap anywhere along a long wall")
	var row=m.build_wall_line([Vector2i(3,7),Vector2i(9,7)],0)
	check(row.size()==2 and [3,4,5,6,7,8,9,10,11,12,13,14].all(func(x):return m.occupancy.has(Vector2i(x,7))),"Dragged wall sections join without gaps")
	var gate=m.build("gate",Vector2i(4,7),0)
	check(not gate.is_empty() and m.occupancy.has(Vector2i(3,7)) and m.buildings[m.occupancy[Vector2i(3,7)]].kind=="wall","Cutting a gate preserves the unused end of a long wall")
	check(not gate.is_empty() and not m.allied_grid.is_point_solid(Vector2i(4,7)) and not m.allied_grid.is_point_solid(Vector2i(5,7)),"The gate cut creates a usable passage")
	var stage=Node3D.new();root.add_child(stage)
	var tower=Art.building({"id":90,"kind":"tower","rotation":0});stage.add_child(tower)
	var wall=Art.building({"id":91,"kind":"wall","rotation":0});stage.add_child(wall);wall.position.x=30
	await physics_frame;await physics_frame
	var space=stage.get_world_3d().direct_space_state
	var deck=space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(0,20,0),Vector3(0,0,0),1))
	check(not deck.is_empty() and absf(deck.position.y-8.95)<.04,"Tower floor collision meets the visible wooden deck")
	var roof=space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(0,20,-4),Vector3(0,8,-4),1))
	check(not roof.is_empty() and roof.position.y>13,"Tower roof supports a landing on its visible surface")
	var end_hit=space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(46,2,5),Vector3(46,2,-5),1))
	check(not end_hit.is_empty(),"The far end of the six-cell wall has real collision")
	var body=CharacterBody3D.new();stage.add_child(body);body.collision_layer=2;body.collision_mask=1
	var collider=CollisionShape3D.new();var capsule=CapsuleShape3D.new();capsule.radius=.48;capsule.height=1.9;collider.shape=capsule;collider.position.y=.95;body.add_child(collider)
	body.position=Vector3(0,11,0)
	for i in range(120):
		await physics_frame
		body.velocity.y-=30.0/60;body.move_and_slide()
	check(body.is_on_floor() and absf(body.position.y-8.95)<.08,"A player-sized character lands and stays on the tower deck")
	stage.free()
	await corner_collision()
	var sight=Model.new();sight.reset(42)
	var scout=sight.workers.values()[0];scout.pos=Vector3(90,0,0)
	sight.tick(.25,sight.hero_position)
	check(sight.visible_at(scout.pos),"Preparation visibility follows workers as they move")
	print("FOREST_SETTLEMENT_UPDATE_RESULT checks=",checks," failures=",failures)
	quit(1 if failures else 0)
func corner_collision():
	var m=Model.new();preload("res://tests/forest-shrine/empty_settlement.gd").reset(m);m.gold=2000;m.workers.clear()
	for x in range(-15,16):
		for y in range(-15,16):m.explored[Vector2i(x,y)]=true
	var horizontal=m.build("wall",Vector2i(5,7),0)
	var vertical=m.build("wall",Vector2i(11,7),1)
	var end=m.build("wall",Vector2i(10,13),0)
	var world=load("res://scripts/forest/forest_world.gd").new();world.model=m;root.add_child(world)
	for reversed in [false,true]:
		horizontal.rotation=2 if reversed else 0;vertical.rotation=3 if reversed else 1
		m.revision+=1;world.sync(0)
		await process_frame;await physics_frame;await physics_frame
		var space=world.get_world_3d().direct_space_state
		var corner=space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(64.2,2,39),Vector3(64.2,2,45),1))
		check(not corner.is_empty(),"Horizontal corner blocks the former player-sized gap at rotation %d"%horizontal.rotation)
		corner=space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(63,2,76.2),Vector3(69,2,76.2),1))
		check(not corner.is_empty(),"Vertical corner blocks the former player-sized gap at rotation %d"%vertical.rotation)
	m.demolish(vertical.id);world.sync(0)
	await process_frame;await physics_frame;await physics_frame
	var gap=world.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(64.2,2,39),Vector3(64.2,2,45),1))
	check(gap.is_empty(),"Removing a corner retracts its neighbor's extension and collision")
	world.free()
