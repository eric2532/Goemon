extends RefCounted
## Portal arrivals choose an accessible exterior gate; roads remain authored scenery.
const Roles=preload("res://scripts/forest/forest_enemy_roles.gd")
var reference: WeakRef
var m:
	get:return reference.get_ref()
var portal_cursor=0
var road_cache: Dictionary={}
var gate_cache: Dictionary={}
var revision=-1
func _init(model):reference=weakref(model)
static func direction(portal: Dictionary)->Vector3:
	return [Vector3.FORWARD,Vector3.RIGHT,Vector3.BACK,Vector3.LEFT][int(portal.rotation)%4]
static func exit_point(portal: Dictionary,variant: int)->Vector3:
	return Vector3(portal.x*6,0,portal.z*6)+direction(portal)*(18.0 if variant==2 else 6.0)
func guidance(point: Vector3,variant: int=0)->Array:
	if revision!=m.navigation_revision:road_cache.clear();gate_cache.clear();revision=m.navigation_revision
	var start: Vector2i=m.cell_of(point)
	var key=Vector3i(start.x,start.y,variant if variant in [2,4] else 0)
	if road_cache.has(key):return road_cache[key].duplicate()
	if m.roads.is_empty():return []
	var anchor=start;var closest=3
	for dx in range(-2,3):
		for dz in range(-2,3):
			var cell=start+Vector2i(dx,dz);var distance=absi(dx)+absi(dz)
			if m.roads.has(cell) and distance<closest:anchor=cell;closest=distance
	if closest==3:road_cache[key]=[];return []
	var queue=[anchor];var parents={anchor:anchor};var index=0;var end=anchor
	var goal: Vector2i=m.shrine_entry();var best=absi(anchor.x-goal.x)+absi(anchor.y-goal.y)
	while index<queue.size():
		var cell: Vector2i=queue[index];index+=1
		var distance=absi(cell.x-goal.x)+absi(cell.y-goal.y)
		if distance<best:best=distance;end=cell
		for step in [Vector2i.UP,Vector2i.RIGHT,Vector2i.DOWN,Vector2i.LEFT]:
			var next=cell+step
			if m.roads.has(next) and not parents.has(next) and (not m.has_elevation() or (not m.enemy_grid.is_point_solid(next) and m.waves.navigation.terrain_clear(m.point(next),Roles.footprint_radius(variant)) and m.terrain.step_clear(m.point(cell),m.point(next)))):parents[next]=cell;queue.append(next)
	var path=[];var cursor=end
	while cursor!=anchor:path.push_front(cursor);cursor=parents[cursor]
	path.push_front(anchor)
	if anchor!=start:
		var entry=m.route(start,anchor,true)
		if entry.is_empty():road_cache[key]=[];return []
		entry.pop_back();path=entry+path
	road_cache[key]=path;return path.duplicate()
func spawn(variant: int,reserved: Array,portal_index: int=-1)->bool:
	var navigation=m.waves.navigation
	for offset in range(1 if portal_index>=0 else m.portals.size()):
		var index=portal_index if portal_index>=0 else (portal_cursor+offset)%m.portals.size();var portal: Dictionary=m.portals[index]
		var forward=direction(portal);var side=Vector3(-forward.z,0,forward.x)
		for lateral in ([0] if variant in [2,4] else [0,3,-3,6,-6,9,-9,12,-12]):
			var point=exit_point(portal,variant)+side*lateral
			point.y=m.surface_height(point.x,point.z)
			if m.trees.has(m.cell_of(point)):continue
			var facing=atan2(-forward.x,-forward.z);var probe={"pos":point,"variant":variant,"facing":facing}
			if not navigation.move_clear(point,Roles.footprint_radius(variant)) or navigation.fitted_blocker(probe,point)>=0:continue
			var clear=true
			var radius=Roles.visibility_radius(variant)
			if m.hero_position.y-point.y<Roles.height(variant)+3 and m.waves.horizontal_distance(point,m.hero_position)<radius+1.2:continue
			for worker in m.workers.values():
				if worker.state!="wounded" and m.waves.horizontal_distance(point,worker.pos)<radius+1.0:clear=false;break
			if not clear:continue
			if not m.waves.spawn_space_clear(point,radius):continue
			for position in reserved:
				if position.distance_to(point)<1.8:clear=false;break
			if not clear:continue
			var enemy=m.waves.spawn_enemy(variant,point);enemy.facing=facing;enemy.portal_index=index;enemy.road_path=[];m.waves.register_spawn(enemy)
			portal_cursor=(index+1)%m.portals.size();reserved.append(point);return true
	return false
func gate_target(enemy: Dictionary)->int:
	var navigation=m.waves.navigation
	var selected: int=enemy.get("entry_gate",-1)
	var start: Vector2i=m.cell_of(enemy.pos)
	if selected<0 and enemy.get("entry_gate_nav",-1)==m.navigation_revision and enemy.get("entry_gate_query_cell",Vector2i(9999,9999))==start and (float(enemy.get("entry_gate_retry",0))>0 or enemy.get("entry_gate_query_pos",Vector3.INF).is_equal_approx(enemy.pos)):return -1
	if selected>=0 and m.buildings.has(selected):
		var gate: Dictionary=m.buildings[selected]
		if gate.get("breached",false) and enemy.get("crossing_gate",-1)==selected and not navigation.gate_crossing_complete(enemy,gate):return selected
		if navigation.gate_exterior(enemy,gate) and enemy.get("entry_gate_nav",-1)==m.navigation_revision:return selected
	var key=Vector3i(start.x,start.y,roundi(Roles.footprint_radius(int(enemy.variant))*1000))
	if revision!=m.navigation_revision:road_cache.clear();gate_cache.clear();revision=m.navigation_revision
	var cached: Dictionary=gate_cache.get(key,{})
	if not cached.is_empty():
		var usable=cached.id<0 and (cached.get("cell_failure",false) or cached.get("start",Vector3.INF).is_equal_approx(enemy.pos))
		if cached.id>=0 and m.buildings.has(cached.id):
			var gate: Dictionary=m.buildings[cached.id]
			usable=navigation.gate_exterior(enemy,gate) and not navigation.gate_approach(enemy,gate).is_empty()
		if usable:
			enemy.entry_gate=cached.id;enemy.entry_gate_nav=m.navigation_revision
			if cached.id<0:enemy.entry_gate_query_cell=start;enemy.entry_gate_query_pos=enemy.pos;enemy.entry_gate_retry=.75
			return cached.id
	var best=-1;var cost=INF
	for gate in m.buildings.values():
		if gate.kind!="gate" or not navigation.gate_exterior(enemy,gate):continue
		var lower: float=navigation.horizontal_path_lower_bound(enemy.pos,m.center(gate))-Roles.stats(enemy.variant).range
		if lower>cost:continue
		var approach: Dictionary=navigation.gate_approach(enemy,gate)
		if not approach.is_empty() and approach.cost<cost:best=gate.id;cost=approach.cost
	var cell_failure=best<0 and navigation.has_method("gate_failure_cell_invariant") and navigation.gate_failure_cell_invariant(enemy)
	gate_cache[key]={"id":best,"start":enemy.pos,"cell_failure":cell_failure}
	enemy.entry_gate=best;enemy.entry_gate_nav=m.navigation_revision
	enemy.entry_gate_query_cell=start;enemy.entry_gate_query_pos=enemy.pos;enemy.entry_gate_retry=.75 if best<0 else 0.0
	return best
func following(_enemy: Dictionary,_hero: Vector3)->bool:
	# Roads describe useful ground (including bridges), never mandatory checkpoints.
	# Normal target routes already respect the terrain and allow nearby combat.
	return false
func movement_path(enemy: Dictionary)->Array:
	if enemy.get("road_join_nav",-1)!=m.navigation_revision:enemy.erase("road_join")
	if not enemy.get("road_join",[]).is_empty():return enemy.road_join
	var path: Array=enemy.road_path
	if path.is_empty():return []
	if not m.roads.has(m.cell_of(enemy.pos)) or enemy.pos.distance_to(m.point(path[0]))>8:
		var connector=m.waves.navigation.route(enemy,m.point(path[0]))
		while not connector.is_empty() and enemy.pos.distance_to(m.point(connector[0]))<.25:connector.pop_front()
		enemy.road_join=connector;enemy.road_join_nav=m.navigation_revision;return connector
	return path
static func validate_portals(model)->String:
	if model.portals.is_empty():return ""
	var nav=model.waves.navigation;var contacts=nav.approach_points(2,model.shrine());var routes=load("res://scripts/forest/forest_routes.gd").new(model)
	for portal in model.portals:
		var point=exit_point(portal,2);point.y=model.surface_height(point.x,point.z);var forward=direction(portal);var probe={"pos":point,"variant":2,"facing":atan2(-forward.x,-forward.z)}
		if not nav.move_clear(point,8.5) or nav.fitted_blocker(probe,point)>=0:return "Clear a five-tile-wide exit in front of each portal for the giant."
		if not nav.has_approach(probe,contacts):return "Keep a clear approach from every portal to the base."
		for variant in [0,2]:
			for cell in routes.guidance(exit_point(portal,variant),variant):
				if not nav.terrain_clear(model.point(cell),8.5 if not model.has_elevation() else Roles.footprint_radius(variant)):return "Widen the portal road near (%d, %d) to five tiles and clear nearby trees."%[cell.x,cell.y]
	return ""
