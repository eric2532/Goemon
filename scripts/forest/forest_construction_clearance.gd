extends RefCounted
## Move standing allies to the closest free edge after construction commits.
static func bounds(m,b:Dictionary)->Rect2:
	return Rect2(Vector2(b.cell)*m.CELL-Vector2.ONE*m.CELL*.5,Vector2(m.dimensions(b.kind,b.rotation,b.get("span",0)))*m.CELL)
static func covered(m,point:Vector3,added:Array,radius:float=.55)->bool:
	if not point.is_finite():return false
	for b in added:
		if bounds(m,b).grow(radius+.1).has_point(Vector2(point.x,point.z)):return true
	return false
static func reserve(occupied:Array,point:Vector3,radius:float=.55):
	if point.is_finite():occupied.append({"point":point,"radius":radius})
static func open_point(m,point:Vector3,radius:float,occupied:Array)->bool:
	var cell:Vector2i=m.cell_of(point)
	if not m.navigation_region.has_point(cell) or m.occupancy.has(cell) or m.allied_grid.is_point_solid(cell):return false
	if cell==m.TRAINING_DUMMY_CELL or not m.terrain.disk_clear(point,radius):return false
	# The center can be in an empty cell while the body clips a neighboring
	# building corner or tree. Check the whole disk against nearby solid tiles.
	var reach=ceili((radius+.1)/m.CELL)+1
	var flat=Vector2(point.x,point.z)
	for x in range(-reach,reach+1):
		for z in range(-reach,reach+1):
			var neighbor=cell+Vector2i(x,z)
			if not m.navigation_region.has_point(neighbor):continue
			if not m.occupancy.has(neighbor) and not m.allied_grid.is_point_solid(neighbor) and neighbor!=m.TRAINING_DUMMY_CELL:continue
			var center=Vector2(neighbor)*m.CELL;var half=Vector2.ONE*m.CELL*.5
			if flat.distance_to(flat.clamp(center-half,center+half))<radius+.1:return false
	for row in occupied:
		if Vector2(point.x-row.point.x,point.z-row.point.z).length()<radius+row.radius+.1:return false
	return true
static func nearest(m,point:Vector3,added:Array,occupied:Array,radius:float=.55,height:float=.15)->Vector3:
	if not covered(m,point,added,radius):return point
	var candidates:Array[Vector3]=[]
	for b in added:
		var edge=bounds(m,b).grow(radius+.2)
		var x=clampf(point.x,edge.position.x,edge.end.x);var z=clampf(point.z,edge.position.y,edge.end.y)
		for p in [Vector2(edge.position.x,z),Vector2(edge.end.x,z),Vector2(x,edge.position.y),Vector2(x,edge.end.y)]:
			candidates.append(Vector3(p.x,m.surface_height(p.x,p.y)+height,p.y))
	candidates.sort_custom(func(a:Vector3,b:Vector3):return Vector2(a.x-point.x,a.z-point.z).length_squared()<Vector2(b.x-point.x,b.z-point.z).length_squared())
	for candidate in candidates:
		if not covered(m,candidate,added,radius) and open_point(m,candidate,radius,occupied):return candidate
	# A nearby edge can be occupied by another building or a cliff. Search the
	# local grid outwards only until an open ring is found.
	var origin:Vector2i=m.cell_of(point)
	for distance in range(1,maxi(m.navigation_region.size.x,m.navigation_region.size.y)):
		var best=Vector3.INF;var score=INF
		for x in range(-distance,distance+1):
			for z in range(-distance,distance+1):
				if maxi(absi(x),absi(z))!=distance:continue
				var cell=origin+Vector2i(x,z)
				if not m.navigation_region.has_point(cell):continue
				var candidate:Vector3=m.point(cell)+Vector3.UP*height
				if covered(m,candidate,added,radius) or not open_point(m,candidate,radius,occupied):continue
				var gap=Vector2(candidate.x-point.x,candidate.z-point.z).length_squared()
				if gap<score:best=candidate;score=gap
		if best.is_finite():return best
	return point
static func relocate_workers(m,added:Array):
	var occupied=[]
	if not covered(m,m.hero_position,added):reserve(occupied,m.hero_position)
	for defender in m.defenders.values():
		if not covered(m,defender.pos,added):reserve(occupied,defender.pos)
	for w in m.workers.values():
		if not covered(m,w.pos,added) and not covered(m,w.get("exit_point",Vector3.INF),added):reserve(occupied,w.pos)
	for w in m.workers.values():
		var exit_blocked=covered(m,w.get("exit_point",Vector3.INF),added)
		if not covered(m,w.pos,added) and not exit_blocked:continue
		var obstacles=added
		# A worker still descending from an old tower can have a clear current
		# position but a newly blocked landing. Set it safely down beside that
		# tower as well; its old straight descent must not cross the new building.
		var current_id:int=m.occupancy.get(m.cell_of(w.pos),-1)
		if exit_blocked and m.buildings.has(current_id):
			obstacles=added.duplicate();obstacles.append(m.buildings[current_id])
		w.pos=nearest(m,w.pos,obstacles,occupied,.55,0)
		w.erase("exit_point");w.erase("exit_start");w.deck_height=0.0
		if w.state=="garrison":w.state="travel" if w.get("job",-1)!=-1 else "idle"
		w.path=[];w.destination=Vector2i(-999,-999);w.nav=-1
		reserve(occupied,w.pos)
static func move_body(unit,point:Vector3):
	unit.global_position=point;unit.velocity=Vector3.ZERO
	if unit.is_rogue_character() and unit.active_ability!=null:unit.active_ability.player.pos=point
static func relocate_game(game,added:Array):
	var m=game.model;var occupied=[]
	for w in m.workers.values():reserve(occupied,w.pos)
	var hero_radius:float=.5*game.player.growth_multiplier()
	if not covered(m,game.player.global_position,added,hero_radius):reserve(occupied,game.player.global_position,hero_radius)
	for unit in game.gate_defenders.units.values():
		if is_instance_valid(unit) and not covered(m,unit.global_position,added):reserve(occupied,unit.global_position)
	for unit in game.explorer_helpers.active_units():
		if not covered(m,unit.global_position,added):reserve(occupied,unit.global_position)
	var hero:Vector3=nearest(m,game.player.global_position,added,occupied,hero_radius)
	if hero!=game.player.global_position:move_body(game.player,hero);reserve(occupied,hero,hero_radius)
	m.hero_position=game.player.global_position
	for unit in game.gate_defenders.units.values():
		if not is_instance_valid(unit):continue
		var point:Vector3=nearest(m,unit.global_position,added,occupied)
		var moved=point!=unit.global_position
		if covered(m,unit.post,added):unit.post=point-Vector3.UP*.15 if moved else nearest(m,unit.post,added,occupied,.55,0)
		if moved:
			move_body(unit,point);unit.ai_move=Vector3.ZERO;unit.route.clear();unit.route_goal=Vector2i(-999,-999);unit.route_revision=-1
			reserve(occupied,point)
	for unit in game.explorer_helpers.active_units():
		var point:Vector3=nearest(m,unit.global_position,added,occupied,.55,.12)
		var moved=point!=unit.global_position
		var post:Vector3=unit.guard_post
		if covered(m,post,added):post=point if moved else nearest(m,post,added,occupied,.55,.12)
		if not moved and post==unit.guard_post:continue
		unit.assign_guard_post(post)
		# A post may be covered while its owner is standing somewhere else.
		# Keep that actor's position, while updating the authoritative post.
		if is_instance_valid(game.army_runtime):
			unit.global_position=point;unit.velocity=Vector3.ZERO
			game.army_runtime.set_pose(unit.handle,point,unit.rotation.y)
		else:move_body(unit,point)
		if moved:reserve(occupied,point)
	game.gate_defenders.sync_model();game.explorer_helpers.sync_targets()
