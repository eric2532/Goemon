extends RefCounted
const Profile=preload("res://scripts/forest/forest_structure_profile.gd")
const Contact=preload("res://scripts/forest/forest_enemy_contact.gd")
const Roles=preload("res://scripts/forest/forest_enemy_roles.gd")
var model_ref: WeakRef
var m:
	get:return model_ref.get_ref()
var grid=AStarGrid2D.new()
var terrain_corridors
var revision=-1
var clearance_grids: Dictionary={}
var clearance_revision=-1
var clearance_signature=[]
var clearance_weight_cells:Array=[]
var gate_approach_cache:Dictionary={}
var gate_approach_revision=-1
const MAX_APPROACH_CERTIFICATES=8192
var approach_cache:Dictionary={}
var approach_revision=-1
var approach_terrain=0
var candidate_revision=-1
var tree_candidates: Dictionary={}
var building_candidates: Dictionary={}
var building_contact_bounds:Dictionary={}
var candidate_terrain=0
var path_revision=-1
var path_terrain=0
var path_cache:Dictionary={}
var contact_revision=-1
var contact_terrain=0
var contact_rings:Dictionary={}
const MAX_SHARED_PATHS=8192
func _init(model):
	model_ref=weakref(model);terrain_corridors=preload("res://scripts/forest/forest_terrain_corridors.gd").new(model,self)
func _refresh_candidates():
	var model=m;var current:int=model.navigation_revision;var terrain_id:int=model.terrain.get_instance_id()
	if candidate_revision==current and candidate_terrain==terrain_id:return
	tree_candidates.clear();building_candidates.clear();building_contact_bounds.clear();candidate_revision=current;candidate_terrain=terrain_id
	# Foundations and footprint rectangles are static within this geometry
	# revision. Preserve the original float32 endpoints and contact ordering.
	for b in model.buildings.values():
		var size_:Vector2i=model.dimensions(b.kind,b.rotation,b.get("span",0))
		var first:Vector3=model.point(b.cell)-Vector3(3,0,3)
		building_contact_bounds[b.id]=[first,first+Vector3(size_.x*6,0,size_.y*6)]
		if b.kind=="gate" and b.get("breached",false):
			var center:Vector3=model.center(b)
			var side=Vector3.RIGHT if b.rotation%2==0 else Vector3.BACK
			var half=Vector3(Profile.GATE_PILLAR_WIDTH*.5,0,Profile.GATE_FRAME_DEPTH*.5) if b.rotation%2==0 else Vector3(Profile.GATE_FRAME_DEPTH*.5,0,Profile.GATE_PILLAR_WIDTH*.5)
			var bounds=[]
			for sign_ in [-1,1]:
				var pillar=center+side*Profile.GATE_PILLAR_X*sign_
				bounds.append(pillar-half);bounds.append(pillar+half)
			building_contact_bounds[b.id]=bounds
func _nearby_trees(cell: Vector2i,cells: int)->Array:
	_refresh_candidates()
	var key=Vector3i(cell.x,cell.y,cells)
	if not tree_candidates.has(key):
		var found=[];var model=m
		for dx in range(-cells,cells+1):
			for dz in range(-cells,cells+1):
				var t=cell+Vector2i(dx,dz)
				if model.trees.has(t):found.append(Vector2(t.x*model.CELL,t.y*model.CELL))
		tree_candidates[key]=found
	return tree_candidates[key]
func _nearby_buildings(cell: Vector2i,cells: int)->Array:
	_refresh_candidates()
	var key=Vector3i(cell.x,cell.y,cells)
	if not building_candidates.has(key):
		var ids={};var model=m
		for dx in range(-cells,cells+1):
			for dz in range(-cells,cells+1):
				var id: int=model.occupancy.get(cell+Vector2i(dx,dz),-1)
				if id>=0:ids[id]=true
		# Dictionary insertion order retains the first contact selected by the old scan.
		building_candidates[key]=ids.keys()
	return building_candidates[key]
func refresh():
	if revision==m.navigation_revision:return
	grid.region=m.navigation_region;grid.cell_size=Vector2.ONE*m.CELL
	grid.diagonal_mode=AStarGrid2D.DIAGONAL_MODE_NEVER;grid.update()
	# Inflate each obstacle once instead of scanning the tree neighborhood for all6,400 cells.
	for x in range(m.navigation_region.position.x,m.navigation_region.end.x):
		for z in range(m.navigation_region.position.y,m.navigation_region.end.y):
			var c=Vector2i(x,z);var p: Vector3=m.point(c)
			grid.set_point_solid(c,not m.world_bounds().grow(-14).has_point(Vector2(p.x,p.z)) or not m.terrain.disk_clear(p,14.75) or m.terrain.cliff_cell(c))
	for tree in m.trees:
		for dx in range(-3,4):
			for dz in range(-3,4):
				var c: Vector2i=tree+Vector2i(dx,dz)
				var offset=Vector2(maxf(0,absf(dx*6)-1.25),maxf(0,absf(dz*6)-1.25))
				if m.navigation_region.has_point(c) and offset.length()<14.05:grid.set_point_solid(c,true)
	var weights={}
	for occupied in m.occupancy:
		for dx in range(-2,3):
			for dz in range(-2,3):
				var c: Vector2i=occupied+Vector2i(dx,dz)
				if m.navigation_region.has_point(c):weights[c]=weights.get(c,1.0)+3.0
	for c in weights:grid.set_point_weight_scale(c,weights[c])
	revision=m.navigation_revision
func terrain_clear(p: Vector3,radius: float)->bool:
	if not m.terrain.disk_clear(p,14.75 if radius>=8.5 else radius):return false
	return terrain_obstacles_clear(p,radius)
func terrain_obstacles_clear(p:Vector3,radius:float)->bool:
	# Caller separately validates the native field, or proves its entire region flat.
	# Core clearance is8.5m; its separately fitted fists require a14m tree/edge envelope.
	# This conservative envelope admits turning without clipping trunks at the route corners.
	if radius>=8.5:radius=14.0
	# Tile centers have half-cell boundary padding. Tree trunks are fitted2.5m boxes.
	if not m.world_bounds().grow(-radius).has_point(Vector2(p.x,p.z)):return false
	var c: Vector2i=m.cell_of(p);var cells=ceili((radius+1.8)/m.CELL)+1
	for center in _nearby_trees(c,cells):
		var offset=Vector2(maxf(0,absf(p.x-center.x)-1.25),maxf(0,absf(p.z-center.y)-1.25))
		if offset.length()<radius+.05:return false
	return true
func building_point(b: Dictionary,p: Vector3)->Vector3:
	var size_: Vector2i=m.dimensions(b.kind,b.rotation,b.get("span",0));var first: Vector3=m.point(b.cell)-Vector3(3,0,3)
	var last=first+Vector3(size_.x*6,0,size_.y*6)
	return Vector3(clampf(p.x,first.x,last.x),first.y,clampf(p.z,first.z,last.z))
func blocker(p: Vector3,radius: float)->int:
	var c: Vector2i=m.cell_of(p);var cells=ceili((radius+3)/6)+1
	for id in _nearby_buildings(c,cells):
		var bounds:Array=building_contact_bounds.get(id,[])
		if bounds.is_empty():continue
		for index in range(0,bounds.size(),2):
			var first:Vector3=bounds[index];var last:Vector3=bounds[index+1]
			var closest=Vector3(clampf(p.x,first.x,last.x),first.y,clampf(p.z,first.z,last.z))
			if p.distance_to(closest)<radius+.05:return id
	return -1
func move_clear(p: Vector3,radius: float)->bool:return terrain_clear(p,radius) and blocker(p,radius)<0
func supported_corridor(from:Vector3,to:Vector3,radius:float,spacing:float,on_road:bool=false,horizontal:bool=false)->Dictionary:
	return terrain_corridors.support(from,to,radius,spacing,on_road,horizontal)
func corridor_walls_clear(points:PackedVector3Array,radius:float)->bool:
	return terrain_corridors.walls_clear(points,radius)
func route_entry_clear(e: Dictionary,to: Vector3)->bool:
	var radius:float=Roles.footprint_radius(e.variant)
	if not move_clear(e.pos,radius):return false
	var supported=supported_corridor(e.pos,to,radius,.25)
	if not supported.clear:return false
	return corridor_walls_clear(supported.points,radius)
func clearance_grid(variant: int)->AStarGrid2D:
	# Soldiers share one terrain/immutable-wall topology. Door revisions update
	# route weights without rebuilding the terrain grid for every breach.
	if clearance_revision!=m.navigation_revision:
		var walls=[]
		for b in m.buildings.values():
			if b.kind=="wall":walls.append([b.id,b.cell,b.rotation,b.get("span",0)])
		var signature=[m.terrain.get_instance_id(),m.ramparts.hash(),m.trees.hash(),walls]
		if clearance_signature!=signature:
			clearance_grids.clear();clearance_weight_cells.clear();clearance_signature=signature
		for existing in clearance_grids.values():
			for cell in clearance_weight_cells:existing.set_point_weight_scale(cell,1.0)
			for cell in m.occupancy:existing.set_point_weight_scale(cell,12.0)
		clearance_weight_cells=m.occupancy.keys();clearance_revision=m.navigation_revision
	var radius: float=Roles.footprint_radius(variant)
	if clearance_grids.has(radius):return clearance_grids[radius]
	var result=AStarGrid2D.new();result.region=m.navigation_region;result.cell_size=Vector2.ONE*m.CELL
	result.diagonal_mode=AStarGrid2D.DIAGONAL_MODE_NEVER;result.update()
	for x in range(m.navigation_region.position.x,m.navigation_region.end.x):
		for z in range(m.navigation_region.position.y,m.navigation_region.end.y):
			var cell=Vector2i(x,z)
			var point:Vector3=m.point(cell)
			var solid=m.terrain.cliff_cell(cell) or not terrain_clear(point,radius)
			var occupied:Dictionary=m.buildings.get(m.occupancy.get(cell,-1),{})
			# Grid centers describe gate connectivity; their final +/-3m offset
			# is resolved by the centered crossing, never by widening the frame.
			if not solid and occupied.get("kind","")!="gate":
				for id in _nearby_buildings(cell,ceili((radius+3)/6)+1):
					var b:Dictionary=m.buildings[id]
					if b.kind=="wall" and point.distance_to(building_point(b,point))<radius+.05:solid=true;break
			result.set_point_solid(cell,solid)
	for occupied in m.occupancy:result.set_point_weight_scale(occupied,12.0)
	clearance_grids[radius]=result;return result
func _find_grid_path(grid_:AStarGrid2D,from:Vector2i,to:Vector2i)->Array:
	return Array(grid_.get_id_path(from,to))
func _grid_path(grid_:AStarGrid2D,from:Vector2i,to:Vector2i)->Array:
	var model=m;var terrain_id:int=model.terrain.get_instance_id()
	if path_revision!=model.navigation_revision or path_terrain!=terrain_id:
		path_cache.clear();path_revision=model.navigation_revision;path_terrain=terrain_id
	var key=[grid_.get_instance_id(),from,to]
	if not path_cache.has(key):
		if path_cache.size()>=MAX_SHARED_PATHS:path_cache.clear()
		path_cache[key]=_find_grid_path(grid_,from,to)
	# Enemies pop/append their own waypoints; the shared path is never lent.
	return path_cache[key].duplicate()
func route(e: Dictionary,destination: Vector3)->Array:
	if e.variant==2:
		refresh()
		var start: Vector2i=m.cell_of(e.pos);var goal: Vector2i=m.cell_of(destination)
		if not m.navigation_region.has_point(start) or grid.is_point_solid(start):return []
		if not m.navigation_region.has_point(goal) or grid.is_point_solid(goal):return []
		return _grid_path(grid,start,goal)
	# Every broad actor needs its own supported corridor, not the small-unit
	# grid whose shortest path can graze the outside edge of a raised bridge.
	var actor_grid: AStarGrid2D=clearance_grid(e.variant) if Roles.footprint_radius(e.variant)>3 else m.enemy_grid
	var goal: Vector2i=m.nearest_open(m.cell_of(destination),true)
	var start: Vector2i=m.cell_of(e.pos)
	if not m.navigation_region.has_point(start) or not m.navigation_region.has_point(goal) or actor_grid.is_point_solid(goal):return []
	if not actor_grid.is_point_solid(start):return _grid_path(actor_grid,start,goal)
	# A clear offset spawn or lane can round into a conservatively blocked
	# cliff cell. Walk onto a reachable neighboring center; never teleport.
	var entries=[]
	for dx in range(-1,2):
		for dz in range(-1,2):
			var cell=start+Vector2i(dx,dz)
			if m.navigation_region.has_point(cell) and not actor_grid.is_point_solid(cell):entries.append(cell)
	entries.sort_custom(func(a,b):return e.pos.distance_squared_to(m.point(a))<e.pos.distance_squared_to(m.point(b)))
	for entry in entries:
		if not route_entry_clear(e,m.point(entry)):continue
		var path=_grid_path(actor_grid,entry,goal)
		if not path.is_empty():return path
	return []
func gate_outward(b: Dictionary)->Vector3:
	var normal: Vector3=[Vector3.BACK,Vector3.RIGHT,Vector3.FORWARD,Vector3.LEFT][int(b.rotation)%4]
	if normal.dot(m.center(b)-m.center(m.shrine()))<0:normal=-normal
	return normal
func gate_crossing_depth(e:Dictionary)->float:
	return Roles.footprint_radius(e.variant)+Profile.GATE_FRAME_DEPTH*.5+.25
func gate_crossing_complete(e:Dictionary,b:Dictionary)->bool:
	return float(e.get("crossing_direction",-1))*gate_outward(b).dot(e.pos-m.center(b))>=gate_crossing_depth(e)
func gate_breach_waypoint(e:Dictionary,b:Dictionary,direction:int=-1)->Dictionary:
	if not b.get("breached",false) or Roles.footprint_radius(e.variant)*2+.1>Profile.GATE_OPENING_WIDTH:return {}
	var normal=gate_outward(b);var center:Vector3=m.center(b)
	var depth=gate_crossing_depth(e)
	if e.get("crossing_gate",-1)==b.id:direction=int(e.get("crossing_direction",-1))
	var point=center+normal*depth*direction
	if e.get("crossing_gate",-1)!=b.id:
		point=center-normal*depth*direction
		# Certify the complete approach before taking ownership of the narrow lane.
		# This keeps distant actors on their existing supported grid route.
		if horizontal_path_lower_bound(e.pos,point)>18:return {}
		var corridor=supported_corridor(e.pos,point,Roles.footprint_radius(e.variant),.25)
		if not corridor.clear or not corridor_walls_clear(corridor.points,Roles.footprint_radius(e.variant)):return {}
		e.crossing_gate=b.id;e.crossing_aligned=false;e.crossing_direction=direction
	if not e.get("crossing_aligned",false):point=center-normal*depth*direction
	point.y=m.surface_height(point.x,point.z)
	return {"point":point,"aligned":e.get("crossing_aligned",false)}
func gate_exterior(e: Dictionary,b: Dictionary)->bool:
	# An actor that has crossed a door must not turn around toward another entrance.
	return gate_outward(b).dot(e.pos-m.center(b))>=2.9
func gate_failure_cell_invariant(e:Dictionary)->bool:
	# On an open grid cell every offset uses the same A* corridor. If its
	# center cannot reach any exterior gate, changing the first leg cannot
	# repair the unsupported remainder. Blocked cells can choose different
	# neighboring entries and therefore need actor-specific retry budgets.
	if e.variant not in [0,1,3]:return false
	var cell:Vector2i=m.cell_of(e.pos);var actor_grid=clearance_grid(e.variant)
	if not m.navigation_region.has_point(cell) or actor_grid.is_point_solid(cell):return false
	var center:Vector3=m.point(cell);var probe:Dictionary=e.duplicate();probe.pos=center
	for gate in m.buildings.values():
		if gate.kind!="gate":continue
		var side=gate_outward(gate).dot(center-m.center(gate))
		# Exterior classification must be the same throughout the entire cell.
		if absf(side-2.9)<=3.001:return false
		if side<2.9:continue
		if not gate_approach(probe,gate).is_empty():return false
	return true
func gate_approach(e: Dictionary,b: Dictionary)->Dictionary:
	if gate_approach_revision!=m.navigation_revision:
		gate_approach_cache.clear();gate_approach_revision=m.navigation_revision
	if not gate_exterior(e,b):return {}
	var cell:Vector2i=m.cell_of(e.pos)
	var key=Vector4i(cell.x,cell.y,roundi(Roles.footprint_radius(e.variant)*1000),int(b.id))
	var cached:Dictionary=gate_approach_cache.get(key,{})
	if not cached.is_empty():
		var point:Vector3=m.point(cached.result.path[0])
		if Vector3(cached.start).is_equal_approx(e.pos) or route_entry_clear(e,point):
			var result:Dictionary=cached.result.duplicate(true)
			result.cost+=Vector3(e.pos).distance_to(point)-Vector3(cached.start).distance_to(point)
			return result
	var result=_gate_approach_uncached(e,b)
	# Positive routes have a certified native terrain corridor. Empty results
	# are not shared: another offset root may have a reachable cell entry.
	if not result.is_empty():gate_approach_cache[key]={"start":e.pos,"result":result.duplicate(true)}
	return result
func _gate_approach_uncached(e: Dictionary,b: Dictionary)->Dictionary:
	if not gate_exterior(e,b):return {}
	var normal=gate_outward(b);var step=Vector2i(roundi(normal.x),roundi(normal.z))
	var radius: float=Roles.footprint_radius(e.variant)
	var best={};var cost=INF
	# Stage outside the footprint, then aim at the gate itself. Short melee
	# reaches are smaller than the 3m gap from a neighboring grid center;
	# the normal collision sweep stops that final approach before body overlap.
	var padding=maxi(1,ceili((radius+3.15)/6.0))
	for cell in m.footprint(b.kind,b.cell,b.rotation):
		var staging: Vector2i=cell+step*padding
		var point: Vector3=m.point(staging)
		if not move_clear(point,radius):continue
		var path=route(e,point)
		if path.is_empty():continue
		var previous: Vector3=e.pos;var supported=true;var total=0.0
		for c in path:
			var next: Vector3=m.point(c)
			if not supported_corridor(previous,next,radius,1.5).clear:supported=false;break
			if m.occupancy.has(c):total+=24.0
			total+=previous.distance_to(next);previous=next
		if not supported:continue
		total+=point.distance_to(m.point(cell))
		if total>=cost:continue
		# Intermediate outside cells retain turns and collision handling for wide actors.
		for remaining in range(padding-1,-1,-1):path.append(cell+step*remaining)
		cost=total;best={"point":point,"path":path,"cost":cost}
	return best
func approach(e: Dictionary,b: Dictionary)->Dictionary:
	if b.kind=="gate" and gate_exterior(e,b):return gate_approach(e,b)
	# Interior gates use the same contact ring as other nearby structures.
	# General contact searches are pure geometry at an exact actor root.
	# Keep failures too: crowds blocked at a castle corner otherwise repeat
	# every A* candidate after each retry budget. No positions are quantized.
	var model=m;var terrain_id:int=model.terrain.get_instance_id()
	if approach_revision!=model.navigation_revision or approach_terrain!=terrain_id:
		approach_cache.clear();approach_revision=model.navigation_revision;approach_terrain=terrain_id
	var key=[e.pos,int(e.variant),int(b.id)]
	if approach_cache.has(key):return approach_cache[key].duplicate(true)
	var result=_sample_approach(e,b)
	if approach_cache.size()>=MAX_APPROACH_CERTIFICATES:approach_cache.clear()
	approach_cache[key]=result.duplicate(true)
	return result
func _contact_ring(e:Dictionary,b:Dictionary)->Array:
	var model=m;var terrain_id:int=model.terrain.get_instance_id()
	if contact_revision!=model.navigation_revision or contact_terrain!=terrain_id:
		contact_rings.clear();contact_revision=model.navigation_revision;contact_terrain=terrain_id
	var radius:float=Roles.footprint_radius(e.variant);var reach:float=Roles.stats(e.variant).range
	var key=[b.id,radius,reach]
	if contact_rings.has(key):return contact_rings[key]
	var size_:Vector2i=model.dimensions(b.kind,b.rotation,b.get("span",0));var padding=ceili((reach+3)/6);var points=[]
	for x in range(b.cell.x-padding,b.cell.x+size_.x+padding):
		for z in range(b.cell.y-padding,b.cell.y+size_.y+padding):
			var p:Vector3=model.point(Vector2i(x,z));var distance=p.distance_to(building_point(b,p))
			if distance<radius+.15 or distance>reach+6.0:continue
			if move_clear(p,radius):points.append([p,distance,Vector2i(x,z)])
	if contact_rings.size()>=MAX_APPROACH_CERTIFICATES:contact_rings.clear()
	contact_rings[key]=points;return points
func _sample_approach(e:Dictionary,b:Dictionary)->Dictionary:
	# Contact geometry is shared; route costs and root entry checks stay actor-specific.
	var size_:Vector2i=m.dimensions(b.kind,b.rotation,b.get("span",0));var reach:float=Roles.stats(e.variant).range
	var best={};var cost=INF
	for contact in _contact_ring(e,b):
		var p:Vector3=contact[0];var distance:float=contact[1];var cell:Vector2i=contact[2]
		if horizontal_path_lower_bound(e.pos,p)>=cost:continue
		var path=route(e,p)
		if path.is_empty():continue
		var total=path.size()*6.0+e.pos.distance_to(m.point(path.front()))
		if distance>reach:
			var terminal=Vector2i(clampi(cell.x,b.cell.x,b.cell.x+size_.x-1),clampi(cell.y,b.cell.y,b.cell.y+size_.y-1))
			total+=p.distance_to(m.point(terminal));path.append(terminal)
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
func full_unseen(_p: Vector3,_variant: int)->bool:
	# Visible portal/edge arrivals are allowed now that scouting is removed.
	return true
func line_clear(from: Vector3,to: Vector3,ignore_building: int=-1)->bool:
	var steps=maxi(1,ceili(from.distance_to(to)/.5))
	for i in range(1,steps):
		var p=from.lerp(to,float(i)/steps);var c: Vector2i=m.cell_of(p)
		if p.y<m.surface_height(p.x,p.z)-.05:return false
		if m.trees.has(c):
			var q: Vector3=m.point(c)
			if absf(p.x-q.x)<1.5 and absf(p.z-q.z)<1.5 and p.y<q.y+12:return false
		var id: int=m.occupancy.get(c,-1)
		if id>=0 and id!=ignore_building and m.buildings.has(id):
			var b: Dictionary=m.buildings[id];var h=Profile.height(b.kind)
			h+=m.center(b).y
			if p.y<h:
				if b.kind=="gate" and b.get("breached",false) and p.y<m.center(b).y+Profile.GATE_OPENING_HEIGHT:
					_refresh_candidates()
					var frame:Array=building_contact_bounds.get(id,[]);var hits_frame=false
					for index in range(0,frame.size(),2):
						var first:Vector3=frame[index];var last:Vector3=frame[index+1]
						if p.x>=first.x and p.x<=last.x and p.z>=first.z and p.z<=last.z:hits_frame=true;break
					if not hits_frame:continue
				return false
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
			var h=Profile.height(b.kind)
			var foundation: float=m.center(b).y
			if box.position.y>=h+foundation:continue
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
