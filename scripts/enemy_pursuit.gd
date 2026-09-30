class_name EnemyPursuit
extends Node
# One shared, cached navigation field serves the entire pursuing population.
const CELL=5.0
const STEPS=[Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]
var game: Node
var bounds: Rect2
var dimensions=Vector2i.ZERO
var cells: Dictionary={}
var edges: Dictionary={}
var distances: Dictionary={}
var target_cell=Vector2i(-999,-999)
var clock=0.0
var ready_field=false
var build_queue: Array[Vector2i]=[]
var build_distances: Dictionary={}
var build_index=0
var build_target=Vector2i.ZERO
var building=false
var shape: CapsuleShape3D
var probe: PhysicsShapeQueryParameters3D
func configure():
	bounds=game.world.playable_bounds.grow(-1)
	dimensions=Vector2i(ceili(bounds.size.x/CELL),ceili(bounds.size.y/CELL))
	building=false;build_queue.clear();build_distances.clear()
	cells.clear();edges.clear();distances.clear();target_cell=Vector2i(-999,-999);clock=0;ready_field=false
	shape=CapsuleShape3D.new();shape.radius=.7;shape.height=1.8
	probe=PhysicsShapeQueryParameters3D.new();probe.shape=shape;probe.collision_mask=1
func cell_of(point: Vector3)->Vector2i:
	return Vector2i(floori((point.x-bounds.position.x)/CELL),floori((point.z-bounds.position.y)/CELL))
func ground(cell: Vector2i):
	if cells.has(cell):return cells[cell]
	if cell.x<0 or cell.y<0 or cell.x>=dimensions.x or cell.y>=dimensions.y:return null
	var point=Vector3(bounds.position.x+(cell.x+.5)*CELL,0,bounds.position.y+(cell.y+.5)*CELL)
	point.y=game.world.height_at(point.x,point.z)
	if point.y<-.5:cells[cell]=null;return null
	var space=game.get_world_3d().direct_space_state
	var floor_hit=space.intersect_ray(PhysicsRayQueryParameters3D.create(point+Vector3.UP*.8,point-Vector3.UP*1.2,1))
	if floor_hit.is_empty() or floor_hit.normal.y<.72:cells[cell]=null;return null
	point.y=floor_hit.position.y+.1
	probe.transform=Transform3D(Basis.IDENTITY,point+Vector3.UP*.95)
	if not space.intersect_shape(probe,1).is_empty():cells[cell]=null;return null
	cells[cell]=point;return point
func connected(a: Vector2i,b: Vector2i)->bool:
	var key=Vector4i(a.x,a.y,b.x,b.y)
	if edges.has(key):return edges[key]
	var start=ground(a);var end=ground(b)
	var clear=start!=null and end!=null
	if clear:
		clear=absf(start.y-end.y)<2.0
		if clear:
			var query=PhysicsRayQueryParameters3D.create(start+Vector3.UP*.8,end+Vector3.UP*.8,1)
			clear=game.get_world_3d().direct_space_state.intersect_ray(query).is_empty()
	edges[key]=clear;edges[Vector4i(b.x,b.y,a.x,a.y)]=clear
	return clear
func start_build(point: Vector3)->bool:
	var seed=cell_of(point)
	if seed==target_cell and ready_field:return false
	if ground(seed)==null:
		var best=INF;var candidate=seed
		for x in range(-3,4):
			for y in range(-3,4):
				var id=seed+Vector2i(x,y);var p=ground(id)
				if p!=null and p.distance_squared_to(point)<best:best=p.distance_squared_to(point);candidate=id
		seed=candidate
	if ground(seed)==null:return false
	build_target=cell_of(point);build_distances={seed:0};build_queue=[seed];build_index=0;building=true
	return true
func advance_build(budget_usec: int=1500):
	var deadline=Time.get_ticks_usec()+budget_usec
	while build_index<build_queue.size():
		var cell=build_queue[build_index];build_index+=1
		for step in STEPS:
			var next=cell+step
			if build_distances.has(next) or not connected(cell,next):continue
			build_distances[next]=build_distances[cell]+1;build_queue.append(next)
		if build_index%16==0 and Time.get_ticks_usec()>=deadline:return
	distances=build_distances;target_cell=build_target;ready_field=true;building=false
	build_queue=[];build_distances={}
func refresh_field(point: Vector3):
	# Explicit synchronous entry point for tests; gameplay spreads work over frames.
	if start_build(point):advance_build(10000000)
func destination()->Vector3:
	return game.player.sky_strike.origin if game.player.sky_strike.active else game.player.global_position
func direction(point: Vector3,formation_index: int=-1)->Vector3:
	var target=destination();var cell=cell_of(point)
	var distance=point.distance_to(target)
	if formation_index>=0 and distance>10 and distance<70:
		# Independent approach lanes and a short movement lead prevent a shared
		# navigation-cell center from gathering every pursuer into the same line.
		var lead=Vector3(game.player.velocity.x,0,game.player.velocity.z).limit_length(16)*.5
		var angle=formation_index*2.399963
		var flank=target+lead+Vector3(cos(angle),0,sin(angle))*minf(8,distance*.22)
		flank.y=game.world.height_at(flank.x,flank.z)
		if flank.y>=0 and clear_segment(point,flank):return Vector3(flank.x-point.x,0,flank.z-point.z).normalized()
	if point.distance_squared_to(target)<225:
		var ray=PhysicsRayQueryParameters3D.create(point+Vector3.UP,target+Vector3.UP,1)
		if game.get_world_3d().direct_space_state.intersect_ray(ray).is_empty():return Vector3(target.x-point.x,0,target.z-point.z).normalized()
	var best=float(distances.get(cell,INF));var next_point=null
	for step in STEPS:
		var neighbor=cell+step;var score=float(distances.get(neighbor,INF))
		if score<best and (ground(cell)==null or connected(cell,neighbor)) and clear_segment(point,ground(neighbor)):
			best=score;next_point=ground(neighbor)
	if next_point!=null:return Vector3(next_point.x-point.x,0,next_point.z-point.z).normalized()
	# Recover from a blocked grid cell by moving onto the closest reachable cell.
	if not distances.has(cell):
		var recovery_score=INF
		for x in range(-2,3):
			for y in range(-2,3):
				var candidate=cell+Vector2i(x,y)
				if not distances.has(candidate):continue
				var pos: Vector3=ground(candidate)
				var score=point.distance_to(pos)+float(distances[candidate])*CELL*.05
				if score<recovery_score and clear_segment(point,pos):recovery_score=score;next_point=pos
		if next_point!=null:return Vector3(next_point.x-point.x,0,next_point.z-point.z).normalized()
	return Vector3(target.x-point.x,0,target.z-point.z).normalized()
func clear_segment(from: Vector3,to: Vector3)->bool:
	var query=PhysicsRayQueryParameters3D.create(from+Vector3.UP*.8,to+Vector3.UP*.8,1)
	return game.get_world_3d().direct_space_state.intersect_ray(query).is_empty()
func _physics_process(delta):
	if not game.playing or game.paused or game.transitioning or game.tuning.freeze_ai:return
	clock-=delta
	if not building and clock<=0:
		clock=.4;start_build(destination())
	if building:advance_build()
