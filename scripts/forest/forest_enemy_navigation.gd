extends RefCounted
const Contact=preload("res://scripts/forest/forest_enemy_contact.gd")
const Roles=preload("res://scripts/forest/forest_enemy_roles.gd")
var model_ref: WeakRef
var m:
	get:return model_ref.get_ref()
var grid=AStarGrid2D.new()
var revision=-1
func _init(model):model_ref=weakref(model)
func refresh():
	if revision==m.navigation_revision:return
	grid.region=m.REGION;grid.cell_size=Vector2.ONE*m.CELL
	grid.diagonal_mode=AStarGrid2D.DIAGONAL_MODE_NEVER;grid.update()
	# Inflate each obstacle once instead of scanning the tree neighborhood for all6,400 cells.
	for x in range(-40,40):
		for z in range(-40,40):
			var c=Vector2i(x,z);var p: Vector3=m.point(c)
			grid.set_point_solid(c,p.x-14 < -243 or p.z-14 < -243 or p.x+14>237 or p.z+14>237 or not m.terrain.disk_clear(p,14.75) or m.terrain.cliff_cell(c))
	for tree in m.trees:
		for dx in range(-3,4):
			for dz in range(-3,4):
				var c: Vector2i=tree+Vector2i(dx,dz)
				var offset=Vector2(maxf(0,absf(dx*6)-1.25),maxf(0,absf(dz*6)-1.25))
				if m.REGION.has_point(c) and offset.length()<14.05:grid.set_point_solid(c,true)
	var weights={}
	for occupied in m.occupancy:
		for dx in range(-2,3):
			for dz in range(-2,3):
				var c: Vector2i=occupied+Vector2i(dx,dz)
				if m.REGION.has_point(c):weights[c]=weights.get(c,1.0)+3.0
	for c in weights:grid.set_point_weight_scale(c,weights[c])
	revision=m.navigation_revision
func terrain_clear(p: Vector3,radius: float)->bool:
	if not m.terrain.disk_clear(p,14.75 if radius>=8.5 else radius):return false
	# Core clearance is8.5m; its separately fitted fists require a14m tree/edge envelope.
	# This conservative envelope admits turning without clipping trunks at the route corners.
	if radius>=8.5:radius=14.0
	# Tile centers have half-cell boundary padding. Tree trunks are fitted2.5m boxes.
	if p.x-radius < -243 or p.z-radius < -243 or p.x+radius >237 or p.z+radius>237:return false
	var c: Vector2i=m.cell_of(p);var cells=ceili((radius+1.8)/m.CELL)+1
	for dx in range(-cells,cells+1):
		for dz in range(-cells,cells+1):
			var t=c+Vector2i(dx,dz)
			if not m.trees.has(t):continue
			var center: Vector3=m.point(t)
			var offset=Vector2(maxf(0,absf(p.x-center.x)-1.25),maxf(0,absf(p.z-center.z)-1.25))
			if offset.length()<radius+.05:return false
	return true
func building_point(b: Dictionary,p: Vector3)->Vector3:
	var size_: Vector2i=m.dimensions(b.kind,b.rotation,b.get("span",0));var first: Vector3=m.point(b.cell)-Vector3(3,0,3)
	var last=first+Vector3(size_.x*6,0,size_.y*6)
	return Vector3(clampf(p.x,first.x,last.x),0,clampf(p.z,first.z,last.z))
func blocker(p: Vector3,radius: float)->int:
	var c: Vector2i=m.cell_of(p);var cells=ceili((radius+3)/6)+1;var ids={}
	for dx in range(-cells,cells+1):
		for dz in range(-cells,cells+1):
			var id: int=m.occupancy.get(c+Vector2i(dx,dz),-1)
			if id>=0:ids[id]=true
	for id in ids:
		var b: Dictionary=m.buildings.get(id,{})
		if not b.is_empty() and p.distance_to(building_point(b,p))<radius+.05:return id
	return -1
func move_clear(p: Vector3,radius: float)->bool:return terrain_clear(p,radius) and blocker(p,radius)<0
func route(e: Dictionary,destination: Vector3)->Array:
	if e.variant!=2:
		var goal: Vector2i=m.nearest_open(m.cell_of(destination),true)
		return m.route(m.cell_of(e.pos),goal,true)
	refresh()
	var start: Vector2i=m.cell_of(e.pos);var goal: Vector2i=m.cell_of(destination)
	if not m.REGION.has_point(start) or grid.is_point_solid(start):return []
	if not m.REGION.has_point(goal) or grid.is_point_solid(goal):return []
	return Array(grid.get_id_path(start,goal))
func approach(e: Dictionary,b: Dictionary)->Dictionary:
	# Choose a valid contact ring route. Buildings are costly route cells because they can be breached.
	var size_: Vector2i=m.dimensions(b.kind,b.rotation,b.get("span",0))
	var radius: float=Roles.footprint_radius(e.variant);var reach: float=Roles.stats(e.variant).range
	var padding=ceili((reach+3)/6);var best={};var cost=INF
	for x in range(b.cell.x-padding,b.cell.x+size_.x+padding):
		for z in range(b.cell.y-padding,b.cell.y+size_.y+padding):
			var p: Vector3=m.point(Vector2i(x,z))
			if horizontal_path_lower_bound(e.pos,p)>=cost:continue
			var distance=p.distance_to(building_point(b,p))
			if distance<radius+.15 or distance>reach:continue
			if not move_clear(p,radius):continue
			var path=route(e,p)
			if path.is_empty():continue
			var total=path.size()*6.0+e.pos.distance_to(m.point(path.front()))
			for c in path:
				if m.occupancy.has(c):total+=24
			if total<cost:cost=total;best={"point":p,"path":path,"cost":total}
	return best
func approach_points(variant: int,b: Dictionary)->Array:
	# Staging only needs existence of a route, not the cheapest of every route.
	# Validate the shared contact ring once for all possible spawn positions.
	var points: Array=[];var size_: Vector2i=m.dimensions(b.kind,b.rotation,b.get("span",0))
	var radius: float=Roles.footprint_radius(variant);var reach: float=Roles.stats(variant).range
	var padding=ceili((reach+3)/6)
	for x in range(b.cell.x-padding,b.cell.x+size_.x+padding):
		for z in range(b.cell.y-padding,b.cell.y+size_.y+padding):
			var p: Vector3=m.point(Vector2i(x,z));var distance=p.distance_to(building_point(b,p))
			if distance<radius+.15 or distance>reach:continue
			if move_clear(p,radius):points.append(p)
	return points
func has_approach(e: Dictionary,points: Array)->bool:
	for p in points:
		if not route(e,p).is_empty():return true
	return false
func full_unseen(p: Vector3,variant: int)->bool:
	var radius=14.0 if variant==2 else Roles.footprint_radius(variant)
	var c: Vector2i=m.cell_of(p);var cells=ceili((radius+4.25)/6)
	for dx in range(-cells,cells+1):
		for dz in range(-cells,cells+1):
			var t=c+Vector2i(dx,dz);var q: Vector3=m.point(t)
			if Vector2(q.x-p.x,q.z-p.z).length()<=radius+4.25 and m.visible_cells.has(t):return false
	return true
func line_clear(from: Vector3,to: Vector3,ignore_building: int=-1)->bool:
	var steps=maxi(1,ceili(from.distance_to(to)/.5))
	for i in range(1,steps):
		var p=from.lerp(to,float(i)/steps);var c: Vector2i=m.cell_of(p)
		if p.y<m.surface_height(p.x,p.z)-.05:return false
		if m.trees.has(c):
			var q: Vector3=m.point(c)
			if absf(p.x-q.x)<1.5 and absf(p.z-q.z)<1.5 and p.y<12:return false
		var id: int=m.occupancy.get(c,-1)
		if id>=0 and id!=ignore_building and m.buildings.has(id):
			var b: Dictionary=m.buildings[id];var h=14.0 if b.kind in ["tower","shrine"] else (6.0 if b.kind in ["mine","gate"] else 4.0)
			if p.y<h:return false
	return true

func horizontal_path_lower_bound(from: Vector3,to: Vector3)->float:return absf(from.x-to.x)+absf(from.z-to.z)

func fitted_blocker(e: Dictionary,p: Vector3)->int:
	var core=blocker(p,Roles.footprint_radius(e.variant))
	if core>=0 or e.variant!=2:return core
	var pose=Transform3D(Basis(Vector3.UP,float(e.facing)),p)
	for item in Contact.shapes(2):
		if item.group not in ["fist_l","fist_r"]:continue
		var box: AABB=(pose*item.bounds).grow(.1)
		for b in m.buildings.values():
			var h=14.0 if b.kind in ["tower","shrine"] else (6.0 if b.kind in ["mine","gate"] else 4.0)
			if box.position.y>=h:continue
			var size_: Vector2i=m.dimensions(b.kind,b.rotation,b.get("span",0))
			var first: Vector3=m.point(b.cell)-Vector3(3,0,3)
			var building_box=AABB(first,Vector3(size_.x*6,h,size_.y*6))
			if box.intersects(building_box):return b.id
	return -1

func yaw_sweep(e: Dictionary,rotation: float)->Dictionary:
	var steps=maxi(1,ceili(absf(rotation)/.01))
	var probe=e.duplicate()
	var facing: float=e.facing
	for i in range(steps):
		probe.facing=facing+rotation/steps
		var obstacle=fitted_blocker(probe,e.pos)
		if obstacle>=0:return {"facing":facing,"blocker":obstacle}
		facing=probe.facing
	return {"facing":facing,"blocker":-1}

func fixed_facing_segment_clear(e: Dictionary,from: Vector3,to: Vector3)->bool:
	if not terrain_clear(to,8.5) or fitted_blocker(e,to)>=0:return false
	var steps=maxi(1,ceili(from.distance_to(to)/.25))
	for i in range(1,steps+1):
		var p=from.lerp(to,float(i)/steps)
		if not terrain_clear(p,8.5) or fitted_blocker(e,p)>=0:return false
	return true

func turn_clearance_point(p: Vector3)->bool:
	# Bounding-box corners of the exported fists stay inside this complete yaw envelope.
	return terrain_clear(p,8.5) and blocker(p,14.75)<0

func turning_retreat(e: Dictionary,obstacle: int)->Array:
	var directions=[]
	if m.buildings.has(obstacle):
		var away: Vector3=e.pos-building_point(m.buildings[obstacle],e.pos)
		if away.length_squared()>.001:directions.append(away.normalized())
	for i in range(8):directions.append(Vector3(sin(i*TAU/8),0,cos(i*TAU/8)))
	var best: Array=[];var distance=INF
	for direction in directions:
		var path: Array=[];var previous: Vector3=e.pos
		for step in range(1,25):
			var point: Vector3=e.pos+direction*step*1.5
			if not fixed_facing_segment_clear(e,previous,point):break
			path.append(point);previous=point
			if turn_clearance_point(point):
				if step*1.5<distance:distance=step*1.5;best=path
				break
	if not best.is_empty():return best
	# A bent retreat can be necessary between adjacent structures. Search a bounded
	# connected neighborhood at the current orientation; rotation is deferred until clear.
	for spacing in [1.5,6.0]:
		var result=connected_turning_retreat(e,spacing,32 if spacing<2 else 80)
		if not result.is_empty():return result
	return []

func connected_turning_retreat(e: Dictionary,spacing: float,extent: int)->Array:
	var start=Vector2i.ZERO;var queue=[start];var parents={start:start};var index=0
	while index<queue.size():
		var cell: Vector2i=queue[index];index+=1
		var point: Vector3=e.pos+Vector3(cell.x,0,cell.y)*spacing
		if cell!=start and turn_clearance_point(point):
			var result=[]
			while cell!=start:
				result.push_front(e.pos+Vector3(cell.x,0,cell.y)*spacing);cell=parents[cell]
			return result
		for offset in [Vector2i(0,1),Vector2i(1,0),Vector2i(0,-1),Vector2i(-1,0),Vector2i(1,1),Vector2i(1,-1),Vector2i(-1,1),Vector2i(-1,-1)]:
			var next: Vector2i=cell+offset
			if absi(next.x)>extent or absi(next.y)>extent or parents.has(next):continue
			var to: Vector3=e.pos+Vector3(next.x,0,next.y)*spacing
			if not fixed_facing_segment_clear(e,point,to):continue
			parents[next]=cell;queue.append(next)
	return []
