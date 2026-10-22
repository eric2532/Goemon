extends SceneTree
const Model=preload("res://scripts/forest/forest_model.gd")
var checks=0
var failures=0
func _initialize():run.call_deferred()
func check(ok: bool,label: String):
	checks+=1
	if not ok:failures+=1;printerr("FAIL: "+label)
func run():
	var m=Model.new();m.reset(42)
	var gates=m.buildings.values().filter(func(b):return b.kind=="gate")
	var towers=m.buildings.values().filter(func(b):return b.kind=="tower")
	var walls=m.buildings.values().filter(func(b):return b.kind=="wall")
	check(gates.size()==1,"A fresh camp has exactly one gate")
	check(towers.size()==2,"A fresh camp has two watchtowers")
	check(not walls.is_empty(),"The fort starts with real defensive walls")
	check(m.gold==1000000,"Starter fort does not charge the testing treasury")
	check(m.workers.size()==8,"Six miners and two tower guards start without recruitment")
	if gates.size()!=1 or towers.size()!=2 or walls.is_empty():finish();return
	var gate: Dictionary=gates[0]
	var interior=inside_cells(m,false)
	check(not interior.escaped,"Closed wall-and-gate perimeter completely encloses the camp")
	for b in m.buildings.values():
		for cell in m.footprint(b.kind,b.cell,b.rotation,b.get("span",0)):
			check(m.occupancy.get(cell,-1)==b.id,"Starter structures have no overlapping footprints")
		if b.kind in ["shrine","mine","tower"]:
			check(m.footprint(b.kind,b.cell,b.rotation).all(func(c):return interior.cells.has(c)),"Shrine, mines and towers lie inside the defensive perimeter")
			check(not m.route(m.shrine_entry(),m.entry(b)).is_empty(),"Every staffed workplace has an inside walking route")
		if b.kind=="mine":check(m.workforce.count_job(b.id)==3,"Each mine retains its full three-person crew")
	for tower in towers:
		var guards=m.workers.values().filter(func(w):return w.job==tower.id)
		check(guards.size()==1 and guards[0].state=="garrison","Each tower already has a guard on its deck")
	for outside in [Vector2i(0,15),Vector2i(0,-15),Vector2i(-15,0),Vector2i(15,0)]:
		var route=m.route(m.shrine_entry(),outside)
		check(not route.is_empty() and route.any(func(c):return m.occupancy.get(c,-1)==gate.id),"Friendly travel in every direction crosses the single gate")
	var before=m.gold
	for i in range(120):m.tick(.1,m.hero_position)
	check(m.gold==before,"Ready fort produces no gold during preparation")
	check(m.workers.values().all(func(w):return w.state in ["mine","garrison"]),"Starter jobs stay useful without any player commands")
	await physical_perimeter(m,walls,gate)
	# Real breach pressure must remain possible against the ready enclosure.
	m.start_wave();m.waves.spawn_clock=100000
	var target=m.waves.spawn_enemy(0,m.center(gate)+Vector3(0,0,12));target.hp=1000;target.stun=100
	m.workforce.tick(.1,m.hero_position)
	check(m.events.filter(func(e):return e.kind=="arrow").size()==2,"Both ready guards shoot without any player assignment")
	m.enemies.clear();m.workforce.arrows.clear();m.events.clear()
	var wall: Dictionary=walls[0];var hp=wall.hp
	var p=m.center(wall);m.waves.spawn_enemy(3,p+Vector3(0,0,-12))
	for i in range(160):m.tick(.1,Vector3(150,0,150))
	check(not m.buildings.has(wall.id) or wall.hp<hp,"Enemies can attack and breach the starter enclosure")
	m.reset(7)
	check(m.buildings.values().filter(func(b):return b.kind=="gate").size()==1 and m.workers.size()==8,"Retry restores the same ready fort and staffed jobs")
	finish()
func inside_cells(m,allow_gate: bool)->Dictionary:
	var start=m.cell_of(m.center(m.shrine()));var queue=[start];var found={start:true};var index=0;var escaped=false
	while index<queue.size():
		var c: Vector2i=queue[index];index+=1
		if c.x in [-40,39] or c.y in [-40,39]:escaped=true
		for offset in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
			var next: Vector2i=c+offset
			if not m.REGION.has_point(next) or found.has(next) or m.trees.has(next):continue
			var b: Dictionary=m.buildings.get(m.occupancy.get(next,-1),{})
			if b.get("kind","")=="wall" or (not allow_gate and b.get("kind","")=="gate"):continue
			found[next]=true;queue.append(next)
	return {"cells":found,"escaped":escaped}
func physical_perimeter(m,walls: Array,gate: Dictionary):
	var world=load("res://scripts/forest/forest_world.gd").new();world.model=m;root.add_child(world)
	await process_frame;await physics_frame;await physics_frame
	var min_x=INF;var max_x=-INF;var min_z=INF;var max_z=-INF
	for wall in walls:
		for c in m.footprint(wall.kind,wall.cell,wall.rotation,wall.span):
			var p: Vector3=m.point(c);min_x=minf(min_x,p.x);max_x=maxf(max_x,p.x);min_z=minf(min_z,p.z);max_z=maxf(max_z,p.z)
	var query=PhysicsShapeQueryParameters3D.new();var capsule=CapsuleShape3D.new();capsule.radius=.48;capsule.height=1.9;query.shape=capsule;query.collision_mask=33
	var space=world.get_world_3d().direct_space_state;var gaps=0
	for x in range(roundi(min_x*2),roundi(max_x*2)+1):
		for z in [min_z,max_z]:
			query.transform=Transform3D(Basis.IDENTITY,Vector3(x*.5,1.1,z+(5 if z==min_z else -5)));query.motion=Vector3(0,0,-10 if z==min_z else 10)
			if space.cast_motion(query)[0]>=1.0:gaps+=1
	for z in range(roundi(min_z*2),roundi(max_z*2)+1):
		for x in [min_x,max_x]:
			query.transform=Transform3D(Basis.IDENTITY,Vector3(x+(5 if x==min_x else -5),1.1,z*.5));query.motion=Vector3(-10 if x==min_x else 10,0,0)
			if space.cast_motion(query)[0]>=1.0:gaps+=1
	check(gaps==0,"Player-sized sweeps find no physical holes along any wall, corner or gate join")
	query.collision_mask=1;query.transform=Transform3D(Basis.IDENTITY,m.center(gate)+Vector3(0,1.1,-5));query.motion=Vector3(0,0,10)
	check(space.cast_motion(query)[0]>=1.0,"The one gate admits the hero through its real collider")
	query.collision_mask=33
	check(space.cast_motion(query)[0]<1.0,"The same gate blocks enemies")
	world.free();await process_frame
func finish():
	print("FOREST_STARTER_FORT_RESULT checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)
