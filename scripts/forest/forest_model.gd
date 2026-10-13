extends RefCounted
## Authoritative run state, independent of the renderer and input devices.
const CELL=6.0
const REGION=Rect2i(-40,-40,80,80)
const ALLIED_REGION=Rect2i(-28,-28,56,56)
const COSTS={"mine":150,"tower":120,"wall":10,"gate":30}
const HP={"shrine":1000.0,"mine":350.0,"tower":500.0,"wall":300.0,"gate":400.0}
const SIZES={"shrine":Vector2i(3,3),"mine":Vector2i(3,2),"tower":Vector2i(2,2),"wall":Vector2i.ONE,"gate":Vector2i(2,1)}
const SIGHT={"shrine":8,"mine":4,"tower":10,"wall":1,"gate":1}
var phase="preparing"
var gold=400
var wave=0
var seed_value=42
var revision=0
var navigation_revision=0
var buildings: Dictionary={}
var workers: Dictionary={}
var enemies: Dictionary={}
var deposits: Dictionary={}
var trees: Dictionary={}
var occupancy: Dictionary={}
var explored: Dictionary={}
var visible_cells: Dictionary={}
var allied_grid=AStarGrid2D.new()
var enemy_grid=AStarGrid2D.new()
var next_id=1
var events: Array=[]
var workforce
var waves
var hero_targetable=true
var hero_position=Vector3(0,0,18)
var sight_clock=0.0
var sight_cache: Dictionary={}

func reset(value: int):
	seed_value=value;phase="preparing";gold=400;wave=0;next_id=1;hero_targetable=true
	buildings.clear();workers.clear();enemies.clear();deposits.clear();trees.clear();occupancy.clear()
	explored.clear();visible_cells.clear();events.clear();sight_cache.clear()
	deposits[Vector2i(-5,1)]=1200;deposits[Vector2i(5,1)]=1200
	var rng=RandomNumberGenerator.new();rng.seed=71013
	for x in range(-39,40):
		for z in range(-39,40):
			# A broad open clearing and winding, connected forest approaches.
			if Vector2(x,z).length()<16:continue
			if absf(x-2*sin(z*.2))<2 or absf(z-2*sin(x*.23))<2:continue
			if absf(abs(x)-abs(z))<2:continue
			if rng.randf()<.17:trees[Vector2i(x,z)]=rng.randf_range(.85,1.4)
	_make_building("shrine",Vector2i(-1,-1),0)
	rebuild_navigation();revision+=1
	if ResourceLoader.exists("res://scripts/forest/forest_workforce.gd"):
		workforce=load("res://scripts/forest/forest_workforce.gd").new(self)
		for i in range(6):workforce.recruit(true)
	if ResourceLoader.exists("res://scripts/forest/forest_waves.gd"):
		waves=load("res://scripts/forest/forest_waves.gd").new(self)
	update_vision(hero_position)

func cell_of(p: Vector3)->Vector2i:return Vector2i(roundi(p.x/CELL),roundi(p.z/CELL))
func point(c: Vector2i)->Vector3:return Vector3(c.x*CELL,0,c.y*CELL)
func dimensions(kind: String, rotation: int)->Vector2i:
	var size_: Vector2i=SIZES.get(kind,Vector2i.ONE)
	return Vector2i(size_.y,size_.x) if rotation%2 else size_
func footprint(kind: String,c: Vector2i,rotation: int)->Array:
	var out=[];var size_=dimensions(kind,rotation)
	for x in size_.x:
		for y in size_.y:out.append(c+Vector2i(x,y))
	return out
func center(b: Dictionary)->Vector3:
	var size_=dimensions(b.kind,b.rotation)
	return point(b.cell)+Vector3(size_.x-1,0,size_.y-1)*CELL*.5
func entry(b: Dictionary)->Vector2i:
	var size_=dimensions(b.kind,b.rotation)
	var entrances=[Vector2i(size_.x/2,size_.y),Vector2i(size_.x,size_.y/2),Vector2i(size_.x/2,-1),Vector2i(-1,size_.y/2)]
	return b.cell+entrances[b.rotation%4]
func shrine()->Dictionary:return buildings.get(1,{})
func shrine_entry()->Vector2i:return Vector2i(0,2)
func _make_building(kind: String,c: Vector2i,rotation: int)->Dictionary:
	var b={"id":next_id,"kind":kind,"cell":c,"rotation":rotation%4,"hp":HP[kind],"max_hp":HP[kind],"clock":0.0}
	next_id+=1;buildings[b.id]=b
	for tile in footprint(kind,c,rotation):occupancy[tile]=b.id
	return b
func rebuild_navigation():
	for grid in [allied_grid,enemy_grid]:
		grid.region=REGION;grid.cell_size=Vector2.ONE*CELL
		grid.diagonal_mode=AStarGrid2D.DIAGONAL_MODE_NEVER;grid.update()
	for x in range(-40,40):
		for y in range(-40,40):
			var c=Vector2i(x,y)
			allied_grid.set_point_solid(c,not ALLIED_REGION.has_point(c) or trees.has(c))
			enemy_grid.set_point_solid(c,trees.has(c))
	for c in occupancy:
		var b: Dictionary=buildings[occupancy[c]]
		if b.kind!="gate":allied_grid.set_point_solid(c,true)
		enemy_grid.set_point_weight_scale(c,6.0 if b.kind in ["wall","gate"] else 12.0)
	navigation_revision+=1;sight_cache.clear()
func nearest_open(c: Vector2i,enemy: bool=false)->Vector2i:
	var grid=enemy_grid if enemy else allied_grid
	if REGION.has_point(c) and not grid.is_point_solid(c):return c
	for radius in range(1,5):
		for x in range(-radius,radius+1):
			for y in range(-radius,radius+1):
				var candidate=c+Vector2i(x,y)
				if REGION.has_point(candidate) and not grid.is_point_solid(candidate):return candidate
	return Vector2i(-999,-999)
func route(from: Vector2i,to: Vector2i,enemy: bool=false)->Array:
	var grid=enemy_grid if enemy else allied_grid
	if not REGION.has_point(from) or not REGION.has_point(to):return []
	if grid.is_point_solid(from) or grid.is_point_solid(to):return []
	return Array(grid.get_id_path(from,to))
func placement_error(kind: String,c: Vector2i,rotation: int)->String:
	if phase!="preparing":return "Build between waves"
	if not COSTS.has(kind):return "Choose a building"
	if gold<COSTS[kind]:return "Not enough gold"
	if kind=="mine" and not deposits.has(c):return "Needs a gold deposit"
	var replacement_ids=[]
	for tile in footprint(kind,c,rotation):
		if not ALLIED_REGION.has_point(tile):return "Beyond the settlement boundary"
		if not explored.has(tile):return "Unexplored terrain"
		if trees.has(tile):return "Trees block this ground"
		if occupancy.has(tile):
			if kind=="gate" and buildings[occupancy[tile]].kind=="wall":replacement_ids.append(occupancy[tile])
			else:return "Ground is occupied"
		if kind!="mine":
			for deposit in deposits:
				if footprint("mine",deposit,0).has(tile):return "Keep this deposit clear for a mine"
		for w in workers.values():
			if w.state!="wounded" and cell_of(w.pos)==tile:return "A worker is standing here"
		if cell_of(hero_position)==tile:return "Goemon is standing here"
	# Validate prospective routes before committing the purchase.
	var altered=[]
	for tile in footprint(kind,c,rotation):
		altered.append([tile,allied_grid.is_point_solid(tile)])
		allied_grid.set_point_solid(tile,kind!="gate")
	var destinations=[shrine_entry()]
	for b in buildings.values():
		if b.kind in ["tower","mine"] or (workforce!=null and workforce.count_job(b.id)>0):destinations.append(entry(b))
	if kind in ["tower","mine"]:destinations.append(entry({"kind":kind,"cell":c,"rotation":rotation}))
	for w in workers.values():
		if w.state!="wounded":destinations.append(nearest_open(cell_of(w.pos)))
	var blocked=false
	for target in destinations:
		if route(shrine_entry(),target).is_empty():blocked=true;break
	for old in altered:allied_grid.set_point_solid(old[0],old[1])
	return "Leave an entrance and a route through a gate" if blocked else ""
func build(kind: String,c: Vector2i,rotation: int)->Dictionary:
	if not placement_error(kind,c,rotation).is_empty():return {}
	if kind=="gate":
		var replace=[]
		for tile in footprint(kind,c,rotation):
			if occupancy.has(tile) and not replace.has(occupancy[tile]):replace.append(occupancy[tile])
		for id in replace:_remove_building(id)
	gold-=COSTS[kind]
	var b=_make_building(kind,c,rotation)
	rebuild_navigation();revision+=1;update_vision(hero_position)
	return b
func _remove_building(id: int):
	if not buildings.has(id):return
	var b: Dictionary=buildings[id]
	for c in footprint(b.kind,b.cell,b.rotation):occupancy.erase(c)
	for w in workers.values():
		if w.job==id:
			workforce.leave_tower(w)
			if phase=="preparing" and w.has("exit_point"):
				w.pos=w.exit_point;w.erase("exit_point");w.deck_height=0.0
			w.job=-1;w.state="idle";w.path=[]
	buildings.erase(id)
func demolish(id: int)->bool:
	if phase!="preparing" or id==1 or not buildings.has(id):return false
	gold+=int(COSTS[buildings[id].kind]*.5)
	_remove_building(id);rebuild_navigation();revision+=1;update_vision(hero_position);return true
func repair(id: int)->bool:
	if phase!="preparing" or not buildings.has(id):return false
	var b: Dictionary=buildings[id];var cost=ceili((b.max_hp-b.hp)/10.0)
	if cost<=0 or gold<cost:return false
	gold-=cost;b.hp=b.max_hp;revision+=1;return true
func damage_building(id: int,amount: float):
	if phase!="wave" or not buildings.has(id):return
	var b: Dictionary=buildings[id];b.hp=maxf(0,b.hp-amount)
	if b.hp<=0:
		if id==1:phase="defeat";events.append({"kind":"defeat"});return
		_remove_building(id);rebuild_navigation();revision+=1;update_vision(hero_position)
func visible_at(p: Vector3)->bool:return visible_cells.has(cell_of(p))
func explored_at(p: Vector3)->bool:return explored.has(cell_of(p))
func _line_visible(a: Vector2i,b: Vector2i,high: bool)->bool:
	if high:return true
	var delta_=b-a;var steps=maxi(absi(delta_.x),absi(delta_.y))
	for i in range(1,steps):
		var c=a+Vector2i(roundi(delta_.x*float(i)/steps),roundi(delta_.y*float(i)/steps))
		if trees.has(c):return false
		if occupancy.has(c) and buildings[occupancy[c]].kind in ["wall","gate"]:return false
	return true
func update_vision(hero: Vector3):
	hero_position=hero;visible_cells.clear()
	var sources=[[cell_of(hero),6,false]]
	for b in buildings.values():sources.append([cell_of(center(b)),SIGHT[b.kind],b.kind=="tower"])
	for w in workers.values():
		if w.state!="wounded":sources.append([cell_of(w.pos),3,false])
	for source in sources:
		var c: Vector2i=source[0];var radius: int=source[1]
		var key=Vector4i(c.x,c.y,radius,1 if source[2] else 0)
		if not sight_cache.has(key):
			var cells=[]
			for x in range(-radius,radius+1):
				for y in range(-radius,radius+1):
					var target=c+Vector2i(x,y)
					if x*x+y*y<=radius*radius and REGION.has_point(target) and _line_visible(c,target,source[2]):cells.append(target)
			sight_cache[key]=cells
		for tile in sight_cache[key]:visible_cells[tile]=true;explored[tile]=true
	if sight_cache.size()>512:sight_cache.clear()

func start_wave()->bool:
	return waves.begin() if waves!=null else false
func tick(delta: float,hero: Vector3):
	hero_position=hero
	if phase!="wave":return
	waves.tick(delta,hero)
	if phase!="wave":return
	workforce.tick(delta,hero)
	sight_clock-=delta
	if sight_clock<=0:update_vision(hero);sight_clock=.2
func rally(held: bool,hero: Vector3):
	if workforce!=null:workforce.rally(held,hero)
func damage_worker(id: int,amount: float):
	if workforce!=null:workforce.damage(id,amount)
func damage_enemy(id: int,amount: float):
	if phase=="wave" and enemies.has(id):enemies[id].hp=maxf(0,enemies[id].hp-amount)

func build_wall_line(cells: Array,rotation: int)->Array:
	if phase!="preparing" or cells.is_empty() or cells.size()>40 or gold<cells.size()*COSTS.wall:return []
	var saved_buildings=buildings.duplicate(true);var saved_occupancy=occupancy.duplicate()
	var saved_explored=explored.duplicate();var saved_gold=gold;var saved_id=next_id;var saved_revision=revision
	var added=[]
	for c in cells:
		var b=build("wall",c,rotation)
		if b.is_empty():
			buildings=saved_buildings;occupancy=saved_occupancy;explored=saved_explored
			gold=saved_gold;next_id=saved_id;revision=saved_revision
			rebuild_navigation();update_vision(hero_position);return []
		added.append(b)
	return added
