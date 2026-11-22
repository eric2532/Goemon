extends RefCounted
## Authoritative run state, independent of the renderer and input devices.
signal construction_completed(added:Array)
signal wave_started
const ConstructionClearance=preload("res://scripts/forest/forest_construction_clearance.gd")
const Balance=preload("res://scripts/forest/core_balance.gd")
var balance=Balance.defaults()
const Ramparts=preload("res://scripts/forest/forest_ramparts.gd")
const KaiTerrain=preload("res://scripts/forest/forest_kai_terrain.gd")
const WindMeadowTerrain=preload("res://scripts/forest/forest_wind_meadow_terrain.gd")
const Arena=preload("res://scripts/forest/forest_arena.gd")
const FreyjaTerrain=preload("res://scripts/forest/forest_freyja_terrain.gd")
const PalaceArt=preload("res://scripts/forest/forest_falan_palace_art.gd")
const CellarArt=preload("res://scripts/forest/forest_falan_cellar_art.gd")
const Courtyard=preload("res://scripts/forest/forest_falan_courtyard.gd")
const FalanFrontier=preload("res://scripts/forest/forest_falan_frontier.gd")
const CityFortifications=preload("res://scripts/forest/forest_falan_fortifications.gd")
const CityGardens=preload("res://scripts/forest/forest_falan_gardens.gd")
const CitySpecial=preload("res://scripts/forest/forest_falan_special_exteriors.gd")
const CityMagicShop=preload("res://scripts/forest/forest_falan_magic_shop.gd")
const CityWorkshop=preload("res://scripts/forest/forest_falan_workshop.gd")
const CityArchitecture=preload("res://scripts/forest/forest_falan_architecture.gd")
const CityHouses=preload("res://scripts/forest/forest_falan_houses.gd")
const CivicExterior=preload("res://scripts/forest/forest_falan_civic_exterior.gd")
const BloodGulchTerrain=preload("res://scripts/forest/forest_blood_gulch_terrain.gd")
const Scenery=preload("res://scripts/forest/forest_scenery.gd")
const FalkenArt=preload("res://scripts/forest/forest_falken_art.gd")
const CELL=6.0
const TRAINING_DUMMY_CELL=Vector2i(2,2)
const STARTING_GOLD=1000000
const REGION=Rect2i(-40,-40,80,80)
const ALLIED_REGION=Rect2i(-28,-28,56,56)
const COSTS={"mine":150,"tower":120,"cannon_tower":200,"wall":10,"gate":30,"barracks":250}
const HP={"shrine":3000.0,"mine":350.0,"tower":500.0,"cannon_tower":500.0,"wall":7500.0,"gate":2500.0,"barracks":3000.0}
const SIZES={"shrine":Vector2i(3,3),"mine":Vector2i(3,2),"tower":Vector2i(2,2),"cannon_tower":Vector2i(2,2),"wall":Vector2i(6,1),"gate":Vector2i(2,1),"barracks":Vector2i(3,3)}
const SIGHT={"shrine":8,"mine":4,"tower":10,"cannon_tower":10,"wall":1,"gate":1,"barracks":5}
var phase="preparing"
var base_invulnerable=false
var survival_run=false
var gold=STARTING_GOLD
var wave=0
var aggro_kills=0
var seed_value=42
var revision=0
var navigation_revision=0
var buildings: Dictionary={}
var workers: Dictionary={}
var starting_food=10
var fighter_count=0
var fighter_posts:Dictionary={}
var defenders: Dictionary={}
# Army pose fields are derived; position/pose readers synchronize this mirror first.
var enemies: Dictionary={}
var deposits: Dictionary={}
var trees: Dictionary={}
var tree_rotations:Dictionary={}
var rocks:Dictionary={}
var props:Dictionary={}
var scenery_obstacles:Dictionary={}
var scenery_heights:Dictionary={}
var scenery_cells:Dictionary={}
var authored_scenery=false
var portals: Array=[]
var enemy_camps_prototype=false
var camp_obstacle_revision=-1
var camp_obstacles:Array=[]
var camp_grid_cells:Dictionary={}
var enemy_statue:Dictionary={}
var roads: Dictionary={}
var ramparts: Array=[]
var terrain=Ramparts.new()
var terrain_source=""
var terrain_detail=""
const FALAN_SCALE=1.3
const Dungeons=preload("res://scripts/forest/forest_freyja_dungeons.gd")
var falan_scale=1.0
var falan_area=""
var falan_road=""
var falan_floor=0
var falan_areas:Dictionary={}
var falan_garden_plan:Dictionary={}
var falan_frontier_plan:Array=[]
var terrain_scale=1.0
var map_expansion=1.0
var raised_castle=false
var navigation_region=REGION
var occupancy: Dictionary={}
var explored: Dictionary={}
var visible_cells: Dictionary={}
var allied_grid=AStarGrid2D.new()
var enemy_grid=AStarGrid2D.new()
var next_id=1
var events: Array=[]
var team_progression=preload("res://scripts/forest/team_progression.gd").new()
var workforce
var waves
var ryo
var army_runtime:Node
var mines_enabled=true
var hero_targetable=true
var hero_position=Vector3(0,0,18)
var sight_clock=0.0
var sight_cache: Dictionary={}
var gate_access_revision=-1
var gate_access_cache:Array=[]
var _construction_batch=false

func reset(value: int,config: Dictionary={},layout: Dictionary={},include_mines:bool=true):
	aggro_kills=0
	remove_meta("joined_village")
	team_progression.reset();team_progression.rng.seed=value
	balance=Balance.sanitized(config)
	balance.enemy_size_mult*=preload("res://scripts/forest/forest_enemy_roles.gd").MAP_ENEMY_SCALE
	mines_enabled=include_mines
	ryo=preload("res://scripts/forest/forest_ryo_economy.gd").new(self)
	seed_value=value;phase="preparing";base_invulnerable=false;gold=balance.starting_gold;wave=0;next_id=1;hero_targetable=true
	starting_food=10;fighter_count=0;fighter_posts.clear()
	buildings.clear();workers.clear();defenders.clear();enemies.clear();deposits.clear();trees.clear();occupancy.clear()
	tree_rotations.clear();rocks.clear();props.clear();scenery_heights.clear()
	portals.clear();roads.clear();ramparts.clear()
	enemy_camps_prototype=bool(layout.get("enemy_camps_prototype",false));terrain_source=str(layout.get("terrain_source",""))
	enemy_statue={"hp":1200.0,"max_hp":1200.0} if enemy_camps_prototype else {}
	explored.clear();visible_cells.clear();events.clear();sight_cache.clear()
	if layout.is_empty():
		if mines_enabled:deposits[Vector2i(-5,1)]=1200;deposits[Vector2i(5,1)]=1200
		var rng=RandomNumberGenerator.new();rng.seed=71013
		for x in range(-39,40):
			for z in range(-39,40):
				# A broad open clearing and winding, connected forest approaches.
				if Vector2(x,z).length()<16:continue
				# Thirty-metre cardinal approaches accommodate the massive siege enemy.
				if abs(x)<3 or abs(z)<3:continue
				if absf(x-2*sin(z*.2))<2 or absf(z-2*sin(x*.23))<2:continue
				if absf(abs(x)-abs(z))<5:continue
				if rng.randf()<.17:trees[Vector2i(x,z)]=rng.randf_range(.85,1.4)
	else:
		if mines_enabled:
			for item in layout.deposits:deposits[Vector2i(item.x,item.z)]=int(item.amount)
		load_scenery(layout)
		for item in layout.get("portals",[]):portals.append({"x":int(item.x),"z":int(item.z),"rotation":int(item.rotation)})
		for item in layout.get("roads",[]):roads[Vector2i(item.x,item.z)]=true
	terrain_scale=float(layout.get("terrain_scale",1.0)) if terrain_source in ["blood_gulch","wind_meadow"] else 1.0
	map_expansion=float(layout.get("map_expansion",1.0)) if terrain_source=="wind_meadow" else 1.0
	terrain_detail=str(layout.get("terrain_detail",""))
	if has_enemy_camps():
		for camp in portals:initialize_enemy_camp(camp)
	ramparts=layout.get("ramparts",[]).duplicate(true)
	terrain_source=str(layout.get("terrain_source",""))
	terrain_detail=str(layout.get("terrain_detail",""))
	falan_area=str(layout.get("falan_area",""))
	falan_floor=int(layout.get("falan_floor",0))
	falan_areas=layout.get("falan_areas",{})
	falan_scale=FALAN_SCALE if not falan_area.is_empty() or terrain_detail==FreyjaTerrain.ID else 1.0
	navigation_region=region_for(terrain_source,terrain_scale*map_expansion)
	if falan_area=="interior" and preload("res://scripts/forest/forest_original_maps.gd").owns(falan_floor):
		var original_floor=preload("res://scripts/forest/forest_original_maps.gd").floor_info(falan_floor,seed_value)
		var low=Vector2i(((original_floor[1]-Vector2.ONE*1.5)/CELL).floor())
		var high=Vector2i(((original_floor[1]+Vector2(original_floor[0])*3.0)/CELL).ceil())
		navigation_region=Rect2i(low,high-low)
	raised_castle=terrain_source=="wind_meadow" and bool(layout.get("raised_castle",false))
	terrain=create_terrain(terrain_source,terrain_scale,map_expansion,raised_castle,terrain_detail,falan_area)
	falan_road=terrain.variant if terrain is FreyjaTerrain and FalanFrontier.FRAMES.has(terrain.variant) else ""
	terrain.configure(ramparts)
	if terrain is FreyjaTerrain and terrain.variant=="east_gate":
		var bounds:Rect2=terrain.mask_bounds()
		var low=Vector2i((bounds.position/6.0).floor())
		navigation_region=Rect2i(low,Vector2i((bounds.end/6.0).ceil())-low)
	hero_position=point(Vector2i(0,3))
	waves=load("res://scripts/forest/forest_waves.gd").new(self)
	survival_run=uses_survival_rules(falan_area,terrain_detail)
	if survival_run:next_id+=1 # Keep the reserved shrine ID out of the structure roster.
	else:_make_building("shrine",Vector2i(-1,-1),0)
	if layout.is_empty():
		for deposit in deposits:_make_building("mine",deposit,0)
		_make_starter_fort()
	else:
		for item in layout.buildings:
			if item.kind=="mine" and not mines_enabled:continue
			var building=_make_building(item.kind,Vector2i(item.x,item.z),int(item.rotation),int(item.get("span",0)))
			if item.kind=="gate" and terrain is FreyjaTerrain and terrain.bridge_bounds().has_area():
				building.freyja_arch=true
				building.falan_gate_area=terrain.variant
				building.breached=true
				building.door_removed=true
		for x in range(-7,10):
			for z in range(-5,8):explored[Vector2i(x,z)]=true
	if has_elevation():
		for cell in roads:explored[cell]=true
		for portal in portals:
			for cell in portal_cells(portal):explored[cell]=true
	rebuild_navigation();revision+=1
	if ResourceLoader.exists("res://scripts/forest/forest_workforce.gd"):
		workforce=load("res://scripts/forest/forest_workforce.gd").new(self)
	update_vision(hero_position)

func _make_starter_fort():
	# One closed perimeter around the shrine and both deposits. Corners belong
	# to horizontal sections; vertical sections join them through wall extensions.
	for x in range(-7,10):
		for z in range(-5,8):explored[Vector2i(x,z)]=true
	for x in range(-7,10,6):_make_building("wall",Vector2i(x,-5),0,mini(6,10-x))
	for interval in [Vector2i(-7,0),Vector2i(2,10)]:
		for x in range(interval.x,interval.y,6):_make_building("wall",Vector2i(x,7),0,mini(6,interval.y-x))
	_make_building("gate",Vector2i(0,7),0)
	for x in [-7,9]:
		for z in range(-4,7,6):_make_building("wall",Vector2i(x,z),1,mini(6,7-z))
	_make_building("tower",Vector2i(-4,4),2)
	_make_building("tower",Vector2i(3,4),2)

func initialize_enemy_camp(camp:Dictionary):
	camp.hp=balance.enemy_castle_health if has_enemy_castles() else 600.0;camp.max_hp=camp.hp
	camp.spawn_distance=72.0 if has_enemy_castles() else 24.0;camp.castle=has_enemy_castles()
	if not camp.castle:return
	camp.damage_revision=0;camp.sections=[]
	var castle=preload("res://scripts/forest/forest_enemy_castle.gd");castle.prepare()
	for piece in castle.pieces:camp.sections.append({"hp":balance.enemy_wall_health,"max_hp":balance.enemy_wall_health,"kind":piece.building.kind})
func enemy_castle_placement_error(cell:Vector2i,rotation:int)->String:
	if phase!="preparing":return "Place enemy castles between waves"
	if not has_enemy_castles():return "Enemy castle testing is available in Wind Meadow Valley"
	if rotation<0 or rotation>3:return "Choose a valid rotation"
	if portals.size()>=16:return "Use at most 16 enemy castles"
	var cells=portal_cells({"x":cell.x,"z":cell.y,"rotation":rotation,"castle":true})
	var reserved={}
	for camp in portals:
		for tile in portal_cells(camp):reserved[tile]=true
	for tile in cells:
		if not navigation_region.grow(-1).has_point(tile):return "Keep the castle and its exit inside the map"
		if reserved.has(tile):return "Keep other castles and their exits clear"
		for anchor in scenery_cells.get(tile,[]):
			if rocks.has(anchor) or (props.has(anchor) and not Scenery.is_tree(props[anchor].kind)):return "Keep scenery clear of the castle and its exit"
		if occupancy.has(tile):return "Ground is occupied"
		if deposits.has(tile):return "Keep gold deposits clear"
		if cell_of(hero_position)==tile:return "Keep the player clear"
		for worker in workers.values():
			if cell_of(worker.pos)==tile:return "Keep workers clear"
		for defender in defenders.values():
			if cell_of(defender.pos)==tile:return "Keep mercenaries clear"
		for post in fighter_posts.values():
			if cell_of(post)==tile:return "Keep mercenaries clear"
	var error=terrain.building_error(cells)
	if not error.is_empty():return error
	var half=Vector2i(8,6) if rotation%2==0 else Vector2i(6,8)
	var foundation=[]
	for x in range(-half.x,half.x+1):
		for z in range(-half.y,half.y+1):foundation.append(cell+Vector2i(x,z))
	var ground=terrain.building_ground_range(foundation)
	if ground.y-ground.x>.7:return "Enemy castles need level ground"
	return ""
func place_enemy_castle(cell:Vector2i,rotation:int)->Dictionary:
	if not enemy_castle_placement_error(cell,rotation).is_empty():return {}
	var camp={"x":cell.x,"z":cell.y,"rotation":rotation}
	initialize_enemy_camp(camp);portals.append(camp)
	for tile in portal_cells(camp):explored[tile]=true;trees.erase(tile);tree_rotations.erase(tile)
	for tile in portal_cells(camp):
		if props.has(tile) and Scenery.is_tree(props[tile].kind):props.erase(tile)
	rebuild_navigation();revision+=1
	return camp

func has_enemy_castles()->bool:return terrain_source=="wind_meadow" and terrain_detail!=Arena.ID and terrain_scale in [2.0,3.0]
func has_enemy_camps()->bool:return enemy_camps_prototype or (terrain_source=="wind_meadow" and terrain_detail!=Arena.ID)
func active_enemy_camps()->int:
	var count=0
	if has_enemy_camps():
		for camp in portals:
			if camp.hp>0:count+=1
	return count
func damage_enemy_objective(index:int,amount:float,section:int=-1):
	if not has_enemy_camps() or phase!="wave" or not is_finite(amount) or amount<=0:return
	if index< -1 or index>=portals.size():return
	if index<0 and (enemy_statue.is_empty() or active_enemy_camps()>0):return
	var target:Dictionary=enemy_statue if index<0 else portals[index]
	if target.hp<=0:return
	var camp=target
	if section>=0:
		if not camp.get("castle",false) or section>=camp.sections.size():return
		target=camp.sections[section]
		if target.hp<=0:return
	target.hp=maxf(0,target.hp-amount)
	if camp.get("castle",false):camp.damage_revision+=1
	if target.hp==0:
		if section<0:
			for part in camp.get("sections",[]):part.hp=0.0
		navigation_revision+=1;revision+=1
		if has_enemy_castles():refresh_camp_grid()
		if section<0 and not survival_run and (index<0 or (terrain_source=="wind_meadow" and active_enemy_camps()==0)):phase="victory";events.append({"kind":"victory"})

func cell_of(p: Vector3)->Vector2i:return Vector2i(roundi(p.x/CELL),roundi(p.z/CELL))
func food_capacity()->int:
	var total=starting_food
	for b in buildings.values():
		if b.kind=="barracks" and b.hp>0:total+=5
	return total
func food_used()->int:return workers.size()+fighter_count*2
func can_recruit(food:int)->bool:return food>0 and food_used()+food<=food_capacity()
func worker_targetable(id:int)->bool:
	var w:Dictionary=workers.get(id,{})
	return not w.is_empty() and w.hp>0 and w.state!="wounded" and not w.has("sheltered_building")
func nearest_barracks(from:Vector3)->Dictionary:
	var origin=nearest_open(cell_of(from));var best={};var distance=INF
	for b in buildings.values():
		if b.kind!="barracks" or b.hp<=0:continue
		var path=route(origin,entry(b))
		if not path.is_empty() and path.size()<distance:best=b;distance=path.size()
	return best
static func portal_direction(portal: Dictionary)->Vector2i:return [Vector2i.UP,Vector2i.RIGHT,Vector2i.DOWN,Vector2i.LEFT][int(portal.rotation)%4]
static func portal_cells(portal: Dictionary)->Array:
	var result=[];var anchor=Vector2i(portal.x,portal.z);var exit=anchor+portal_direction(portal)*3
	if portal.get("castle",false):
		var half=Vector2i(8,6) if int(portal.rotation)%2==0 else Vector2i(6,8)
		for x in range(-half.x,half.x+1):
			for z in range(-half.y,half.y+1):result.append(anchor+Vector2i(x,z))
		exit=anchor+portal_direction(portal)*12
	for center_ in [anchor,exit]:
		for x in range(-2,3):
			for z in range(-2,3):
				var cell=center_+Vector2i(x,z)
				if cell not in result:result.append(cell)
	return result
static func region_for(source:String,scale_:float=1.0)->Rect2i:
	var extent=ceili(40*scale_) if source in ["blood_gulch","wind_meadow"] else 40
	return Rect2i(-extent,-extent,extent*2,extent*2)
static func building_region_for(source:String,scale_:float=1.0)->Rect2i:
	return region_for(source,scale_).grow(-1)
static func create_terrain(source:String,scale_:float=1.0,expansion:float=1.0,raised:bool=false,detail:String="",area:String="")->RefCounted:
	match source:
		"wind_meadow":
			var meadow=Arena.new() if detail==Arena.ID else FreyjaTerrain.new() if detail==FreyjaTerrain.ID or not area.is_empty() else WindMeadowTerrain.new()
			if not area.is_empty():meadow.variant=area
			meadow.horizontal_scale=scale_;meadow.expansion=expansion;meadow.raised_castle=raised;return meadow
		"kai_highway":return KaiTerrain.new()
		"blood_gulch":
			var native=BloodGulchTerrain.new();native.horizontal_scale=scale_;return native
	return Ramparts.new()
func world_bounds()->Rect2:
	return Rect2(Vector2(navigation_region.position)*CELL-Vector2.ONE*3,Vector2(navigation_region.size)*CELL)
func navigation_bounds()->Rect2:
	# Native corridor integrations use this name; share the world domain.
	return world_bounds()
func has_elevation()->bool:return terrain_source in ["kai_highway","blood_gulch","wind_meadow"] or not ramparts.is_empty()
func surface_height(x: float,z: float)->float:
	if falan_area=="interior":
		if falan_floor==FalkenArt.Route.ROOM:return FalkenArt.Dais.height(x,z)
		if falan_floor==1511:return PalaceArt.surface_height(falan_floor,x,z)
		if falan_floor in CellarArt.RAISED_FLOORS:return CellarArt.surface_height(falan_floor,x,z)
		if falan_floor in CivicExterior.Mansion.STAGES:return CivicExterior.Mansion.surface_height(falan_floor,x,z)
		if falan_floor in CivicExterior.Arena.RAISED:return CivicExterior.Arena.surface_height(falan_floor,x,z)
	return terrain.height(x,z)
# The archive grid stays in source coordinates. Only the playable world is scaled.
func world_height(x:float,z:float)->float:return surface_height(x/falan_scale,z/falan_scale)*falan_scale
func world_point(at:Vector2,lift:float=0.0)->Vector3:
	return Vector3(at.x,surface_height(at.x,at.y),at.y)*falan_scale+Vector3.UP*lift
func point(c: Vector2i)->Vector3:return Vector3(c.x*CELL,surface_height(c.x*CELL,c.y*CELL),c.y*CELL)
func dimensions(kind: String, rotation: int, span: int=0)->Vector2i:
	var size_: Vector2i=SIZES.get(kind,Vector2i.ONE)
	if kind=="wall" and span>0:size_.x=span
	return Vector2i(size_.y,size_.x) if rotation%2 else size_
func footprint(kind: String,c: Vector2i,rotation: int,span: int=0)->Array:
	var out=[];var size_=dimensions(kind,rotation,span)
	for x in size_.x:
		for y in size_.y:out.append(c+Vector2i(x,y))
	return out
func center(b: Dictionary)->Vector3:
	var size_=dimensions(b.kind,b.rotation,b.get("span",0))
	var base=point(b.cell)+Vector3(size_.x-1,0,size_.y-1)*CELL*.5
	if terrain_source in ["kai_highway","blood_gulch","wind_meadow"] and b.kind in ["tower","cannon_tower","barracks","wall","gate"]:
		var ground=terrain.building_ground_range(footprint(b.kind,b.cell,b.rotation,b.get("span",0)))
		if is_finite(ground.y):base.y=ground.y
	return base
func wall_extensions(b: Dictionary)->Vector2:
	# Reach the center of a perpendicular neighbor's occupied cell at each end.
	# Keeping joins inside occupied cells leaves gate openings and free ground clear.
	var axis=Vector2i.RIGHT if b.rotation%2==0 else Vector2i.DOWN
	var ends=[b.cell-axis,b.cell+axis*b.get("span",SIZES.wall.x)]
	var extension=Vector2.ZERO
	for i in range(2):
		var neighbor: Dictionary=buildings.get(occupancy.get(ends[i],-1),{})
		if neighbor.get("kind","")=="wall" and neighbor.rotation%2!=b.rotation%2:
			extension[i]=CELL*.5
	return extension
func entry(b: Dictionary)->Vector2i:
	var size_=dimensions(b.kind,b.rotation,b.get("span",0))
	var entrances=[Vector2i(size_.x/2,size_.y),Vector2i(size_.x,size_.y/2),Vector2i(size_.x/2,-1),Vector2i(-1,size_.y/2)]
	return b.cell+entrances[b.rotation%4]
func shrine()->Dictionary:return buildings.get(1,{})
static func uses_survival_rules(area:String,detail:String)->bool:
	return not area.is_empty() or detail in [FreyjaTerrain.ID,Arena.ID] or uses_slime_waves()
static func uses_slime_waves()->bool:
	return OS.has_feature("crossgate_pet_test") or "--crossgate-pet-test" in OS.get_cmdline_user_args()
func fort_center()->Vector3:return point(Vector2i.ZERO) if shrine().is_empty() else center(shrine())
func shrine_entry()->Vector2i:return Vector2i(0,2)
func _make_building(kind: String,c: Vector2i,rotation: int,span: int=0)->Dictionary:
	var b={"id":next_id,"kind":kind,"cell":c,"rotation":rotation%4,"hp":HP[kind],"max_hp":HP[kind],"clock":0.0}
	if kind in ["tower","cannon_tower"]:b.hp=balance.tower_health;b.max_hp=balance.tower_health
	if kind=="gate":
		b.breached=raised_castle and terrain.castle_wall_cells(footprint(kind,c,rotation))
		if b.breached:b.door_removed=true
	if kind=="wall":
		b.span=span if span>0 else SIZES.wall.x
		b.max_hp=HP.wall*b.span/float(SIZES.wall.x);b.hp=b.max_hp
	next_id+=1;buildings[b.id]=b
	for tile in footprint(kind,c,rotation,b.get("span",0)):occupancy[tile]=b.id
	return b
func load_scenery(layout:Dictionary):
	trees.clear();tree_rotations.clear();rocks.clear();props.clear();scenery_heights.clear()
	var city=layout.get("falan_area")=="city"
	for item in layout.trees:
		if city and CityGardens.is_legacy(item,CityGardens.Data.LEGACY_TREES):continue
		var cell=Scenery.anchor(item);trees[cell]=float(item.scale)
		if item.has("rotation") or item.get("height",0)!=0:tree_rotations[cell]=float(item.get("rotation",0))
	for item in layout.get("rocks",[]):rocks[Scenery.anchor(item)]={"scale":float(item.scale),"rotation":float(item.rotation)}
	for item in layout.get("props",[]):
		if city and (CityFortifications.is_legacy(item) or (item.kind=="shrub" and CityGardens.is_legacy(item,CityGardens.Data.LEGACY_SHRUBS))):continue
		props[Scenery.anchor(item)]={"kind":str(item.kind),"scale":float(item.scale),"rotation":float(item.rotation)}
	for group in Scenery.GROUPS:
		for item in layout.get(group,[]):
			if item.get("height",0)!=0:scenery_heights[Scenery.anchor(item)]=float(item.height)
func scenery_point(anchor_)->Vector3:return point(Scenery.cell(anchor_))+Vector3.UP*float(scenery_heights.get(anchor_,0))
static func changed_terrain_bounds(previous:Array,next:Array)->Array:
	var regions=[]
	for piece in previous:
		if piece not in next:regions.append(Ramparts.bounds(piece))
	for piece in next:
		if piece not in previous:regions.append(Ramparts.bounds(piece))
	return regions
func update_editor_terrain(layout:Dictionary)->Array:
	var regions=changed_terrain_bounds(ramparts,layout.get("ramparts",[]));var cells={}
	for bounds:Rect2 in regions:
		for x in range(floori(bounds.position.x/CELL)-1,ceili(bounds.end.x/CELL)+2):
			for z in range(floori(bounds.position.y/CELL)-1,ceili(bounds.end.y/CELL)+2):cells[Vector2i(x,z)]=true
	# Cliff checks are local; keep prepared results outside the changed surface and its neighbours.
	var cliffs={}
	if terrain is KaiTerrain:cliffs=terrain.cliff_cache;terrain.cliff_cache={}
	ramparts=layout.get("ramparts",[]).duplicate(true);terrain.configure(ramparts)
	if terrain is KaiTerrain:
		terrain.cliff_cache=cliffs
		for cell in cells:terrain.cliff_cache.erase(cell)
	for cell in cells:
		if not navigation_region.has_point(cell):continue
		var b:Dictionary=buildings.get(occupancy.get(cell,-1),{})
		var blocked=scenery_cells.has(cell) or terrain.cliff_cell(cell) or camp_grid_cells.has(cell)
		allied_grid.set_point_solid(cell,blocked or (not b.is_empty() and b.kind!="gate"));enemy_grid.set_point_solid(cell,blocked)
	navigation_revision+=1;sight_cache.clear()
	return regions
func update_scenery(layout:Dictionary):
	var previous=scenery_cells
	load_scenery(layout);scenery_cells={};rebuild_scenery()
	var changed=previous.duplicate();changed.merge(scenery_cells)
	for cell in changed:
		if previous.has(cell)==scenery_cells.has(cell) or not navigation_region.has_point(cell):continue
		var blocked=scenery_cells.has(cell) or terrain.cliff_cell(cell) or camp_grid_cells.has(cell)
		var building:Dictionary=buildings.get(occupancy.get(cell,-1),{})
		allied_grid.set_point_solid(cell,blocked or (not building.is_empty() and building.kind!="gate"));enemy_grid.set_point_solid(cell,blocked)
	navigation_revision+=1;sight_cache.clear()
func update_editor_buildings(layout:Dictionary):
	# Editor commits are validated; reuse the normal building/worker lifecycle.
	var previous=occupancy.duplicate();var retained={};var requested={}
	for b in buildings.values():
		if b.kind!="shrine":retained[[b.kind,b.cell,b.rotation,b.get("span",0)]]=b.id
	for item in layout.buildings:
		if item.kind=="mine" and not mines_enabled:continue
		requested[[item.kind,Vector2i(item.x,item.z),int(item.rotation),int(item.get("span",0))]]=true
	for key in retained:
		if not requested.has(key):_remove_building(retained[key])
	for key in requested:
		if not retained.has(key):_make_building(key[0],key[1],key[2],key[3])
	var changed=previous.duplicate();changed.merge(occupancy)
	for cell in changed:
		if previous.get(cell)==occupancy.get(cell):continue
		var b:Dictionary=buildings.get(occupancy.get(cell,-1),{})
		var blocked=scenery_cells.has(cell) or terrain.cliff_cell(cell) or camp_grid_cells.has(cell)
		allied_grid.set_point_solid(cell,blocked or (not b.is_empty() and b.kind!="gate"))
		enemy_grid.set_point_solid(cell,blocked)
		enemy_grid.set_point_weight_scale(cell,(6.0 if b.kind in ["wall","gate"] else 12.0) if not b.is_empty() else 1.0)
	navigation_revision+=1;sight_cache.clear();revision+=1
func rebuild_scenery():
	var workshop=falan_area=="city" and CityWorkshop.active(self)
	var magic_shop=falan_area=="city" and CityMagicShop.active(self)
	falan_garden_plan={}
	falan_frontier_plan=[]
	scenery_obstacles.clear();scenery_cells.clear();authored_scenery=not rocks.is_empty() or not tree_rotations.is_empty() or not props.is_empty()
	var groups={"tree":trees,"rock":rocks,"props":props}
	for group in groups:
		for cell in groups[group]:
			var kind:String=props[cell].kind if group=="props" else group
			if falan_area=="castle" and Courtyard.replaces_saved_scenery(kind,Vector2(Scenery.cell(cell))*CELL):continue
			var scale_:float=trees[cell] if group=="tree" else groups[group][cell].scale
			var rotation:float=tree_rotations.get(cell,-1) if group=="tree" else groups[group][cell].rotation
			if FalanFrontier.replaces_saved_scenery(falan_road,Scenery.cell(cell),kind,scale_,rotation,scenery_heights.get(cell,0)):continue
			if group=="props" and falan_area=="city" and CitySpecial.retired(self,cell):continue
			if group=="props" and workshop and cell is Vector2i and cell==Vector2i(-35,24):continue
			var box=Scenery.bounds(kind,scale_,rotation)
			if group=="props" and falan_area=="city":
				var civic=CivicExterior.shell(cell,props[cell])
				if not civic.is_empty():box=CivicExterior.collision_parts(cell,civic)[0]
				if workshop and cell is Vector2i and cell==Vector2i(-38,26):box=CityWorkshop.bounds(cell)
				if magic_shop and cell is Vector2i and cell==CityMagicShop.ANCHOR:box=CityMagicShop.bounds()
				var special=CitySpecial.spec(self,cell)
				if not special.is_empty():box=CitySpecial.bounds(cell,special)
				if CityHouses.source_centered(self,cell):box=CityArchitecture.collision(CityHouses.ArchitectureData.BINDINGS[cell][0])
				box.position+=CityHouses.offset(self,cell)
			for tile in Scenery.footprint(Scenery.cell(cell),box):
				if not scenery_cells.has(tile):scenery_cells[tile]=[]
				scenery_cells[tile].append(cell)
			box.position+=scenery_point(cell);scenery_obstacles[cell]=box
	if terrain is FreyjaTerrain and (FalanFrontier.FRAMES.has(terrain.variant) or FreyjaTerrain.Regions.has_land(terrain.variant)):
		falan_frontier_plan=FalanFrontier.outer_plan(self)
		for index in falan_frontier_plan.size():register_archive_obstacle(falan_frontier_plan[index][2],index)
		FalanFrontier.prepare_village(self)
	if falan_area in ["castle","city"]:
		var parts=Courtyard.obstacles() if falan_area=="castle" else CityFortifications.obstacles()
		for index in parts.size():register_archive_obstacle(parts[index],index)
		if falan_area=="city":
			var civic_index=20000
			for cell in props:
				var civic=CivicExterior.shell(cell,props[cell])
				if civic.is_empty():continue
				var bodies=CivicExterior.collision_parts(cell,civic)
				for i in range(1,bodies.size()):
					var box:AABB=bodies[i];box.position+=scenery_point(cell)
					register_archive_obstacle(box,civic_index);civic_index+=1
			for i in CityArchitecture.Data.UNMARKED.size():register_archive_obstacle(CityArchitecture.unmarked_bounds(self,i),parts.size()+10000+i)
			falan_garden_plan=CityGardens.plan(self)
			for index in falan_garden_plan.obstacles.size():
				register_archive_obstacle(falan_garden_plan.obstacles[index][0],parts.size()+index)
func register_archive_obstacle(box:AABB,index:int):
	var anchor=Vector3i(0,0,-1-index)
	scenery_obstacles[anchor]=box
	for tile in Scenery.footprint(Vector2i.ZERO,box):
		# The 3 m archive can center a passage between 6 m route cells.
		if not box.has_point(Vector3(tile.x*CELL,box.get_center().y,tile.y*CELL)):continue
		if not scenery_cells.has(tile):scenery_cells[tile]=[]
		scenery_cells[tile].append(anchor)
func rebuild_navigation():
	rebuild_scenery()
	for grid in [allied_grid,enemy_grid]:
		grid.region=navigation_region;grid.cell_size=Vector2.ONE*CELL
		grid.diagonal_mode=AStarGrid2D.DIAGONAL_MODE_NEVER;grid.update()
	for x in range(navigation_region.position.x,navigation_region.end.x):
		for y in range(navigation_region.position.y,navigation_region.end.y):
			var c=Vector2i(x,y)
			allied_grid.set_point_solid(c,scenery_cells.has(c) or terrain.cliff_cell(c))
			enemy_grid.set_point_solid(c,scenery_cells.has(c) or terrain.cliff_cell(c))
	for c in occupancy:
		var b: Dictionary=buildings[occupancy[c]]
		if b.kind!="gate":allied_grid.set_point_solid(c,true)
		enemy_grid.set_point_weight_scale(c,6.0 if b.kind in ["wall","gate"] else 12.0)
	navigation_revision+=1;sight_cache.clear()
	camp_grid_cells.clear();refresh_camp_grid()
func refresh_camp_grid():
	for cell in camp_grid_cells:
		var blocked=scenery_cells.has(cell) or terrain.cliff_cell(cell)
		allied_grid.set_point_solid(cell,blocked or occupancy.has(cell));enemy_grid.set_point_solid(cell,blocked)
	camp_grid_cells.clear()
	if not has_enemy_castles():return
	for box:AABB in preload("res://scripts/forest/forest_camp_prototype.gd").obstacles(self):
		for x in range(ceili(box.position.x/CELL),floori(box.end.x/CELL)+1):
			for z in range(ceili(box.position.z/CELL),floori(box.end.z/CELL)+1):
				var cell=Vector2i(x,z)
				if not navigation_region.has_point(cell):continue
				var floor_=surface_height(x*CELL,z*CELL)
				if box.position.y<=floor_+.1 and box.end.y>floor_+.1:
					camp_grid_cells[cell]=true;allied_grid.set_point_solid(cell,true);enemy_grid.set_point_solid(cell,true)
func nearest_open(c: Vector2i,enemy: bool=false)->Vector2i:
	var grid=enemy_grid if enemy else allied_grid
	if navigation_region.has_point(c) and not grid.is_point_solid(c):return c
	for radius in range(1,5):
		for x in range(-radius,radius+1):
			for y in range(-radius,radius+1):
				var candidate=c+Vector2i(x,y)
				if navigation_region.has_point(candidate) and not grid.is_point_solid(candidate):return candidate
	return Vector2i(-999,-999)
func route(from: Vector2i,to: Vector2i,enemy: bool=false)->Array:
	var grid=enemy_grid if enemy else allied_grid
	if not navigation_region.has_point(from) or not navigation_region.has_point(to):return []
	if grid.is_point_solid(from) or grid.is_point_solid(to):return []
	return Array(grid.get_id_path(from,to))
func gate_approaches(gate:Dictionary)->Array:
	var normal=Vector2i.DOWN if int(gate.rotation)%2==0 else Vector2i.RIGHT
	var cells=footprint("gate",gate.cell,int(gate.rotation))
	return [cells.map(func(cell):return cell-normal),cells.map(func(cell):return cell+normal)]
func gate_clearance_error(cells:Array,new_gate:Dictionary={})->String:
	for gate in buildings.values():
		if gate.kind!="gate":continue
		for side in gate_approaches(gate):
			for tile in side:
				if tile in cells:return "Keep the gate passage clear"
	if not new_gate.is_empty():
		for side in gate_approaches(new_gate):
			for tile in side:
				if not navigation_region.has_point(tile) or scenery_cells.has(tile) or terrain.cliff_cell(tile):return "Keep the gate passage clear"
				if occupancy.has(tile) and buildings[occupancy[tile]].kind!="gate":return "Keep the gate passage clear"
				for portal in portals:
					if tile in portal_cells(portal):return "Keep the gate passage clear"
				for deposit in deposits:
					if tile in footprint("mine",deposit,0):return "Keep the gate passage clear"
	return ""
func _gate_access_paths(gate:Dictionary,side:Array,blocked:Dictionary={})->Dictionary:
	# Search each face independently, without walking back through this gate.
	# The witnesses reserve no land: only a placement which cuts an existing
	# connection to the shrine or the outer map needs another route search.
	var excluded=blocked.duplicate()
	for cell in footprint("gate",gate.cell,int(gate.rotation)):excluded[cell]=true
	var shrine_cells={}
	for x in range(-2,3):
		shrine_cells[Vector2i(x,-2)]=true;shrine_cells[Vector2i(x,2)]=true
	for z in range(-1,2):
		shrine_cells[Vector2i(-2,z)]=true;shrine_cells[Vector2i(2,z)]=true
	var exits={}
	for portal in portals:exits[Vector2i(portal.x,portal.z)+portal_direction(portal)*3]=true
	var queue=[];var parents={};var paths={"shrine":[],"exterior":[]}
	for cell in side:
		if navigation_region.has_point(cell) and not excluded.has(cell) and not allied_grid.is_point_solid(cell):
			queue.append(cell);parents[cell]=cell
	var index=0
	while index<queue.size():
		var cell:Vector2i=queue[index];index+=1
		var targets=[]
		if paths.shrine.is_empty() and shrine_cells.has(cell):targets.append("shrine")
		if paths.exterior.is_empty() and (exits.has(cell) or cell.x==navigation_region.position.x or cell.y==navigation_region.position.y or cell.x==navigation_region.end.x-1 or cell.y==navigation_region.end.y-1):targets.append("exterior")
		for target in targets:
			var path=[cell];var cursor=cell
			while parents[cursor]!=cursor:cursor=parents[cursor];path.append(cursor)
			paths[target]=path
		if not paths.shrine.is_empty() and not paths.exterior.is_empty():break
		for step in [Vector2i.UP,Vector2i.RIGHT,Vector2i.DOWN,Vector2i.LEFT]:
			var next=cell+step
			if navigation_region.has_point(next) and not parents.has(next) and not excluded.has(next) and not allied_grid.is_point_solid(next):
				parents[next]=cell;queue.append(next)
	return paths
func gate_route_error(cells:Array)->String:
	if gate_access_revision!=navigation_revision:
		gate_access_cache.clear()
		for gate in buildings.values():
			if gate.kind!="gate":continue
			for side in gate_approaches(gate):gate_access_cache.append({"gate":gate,"side":side,"paths":_gate_access_paths(gate,side)})
		gate_access_revision=navigation_revision
	var blocked={}
	for cell in cells:blocked[cell]=true
	for access in gate_access_cache:
		var affected=[]
		for target in ["shrine","exterior"]:
			if access.paths[target].any(func(cell):return blocked.has(cell)):affected.append(target)
		if affected.is_empty():continue
		var remaining=_gate_access_paths(access.gate,access.side,blocked)
		for target in affected:
			if remaining[target].is_empty():return "Keep a route through the gate clear"
	return ""
func placement_error(kind: String,c: Vector2i,rotation: int)->String:
	if phase!="preparing":return "Build between waves"
	if not COSTS.has(kind):return "Choose a building"
	if kind=="mine" and not mines_enabled:return "Gold mines are unavailable"
	if gold<COSTS[kind]:return "Not enough gold"
	if kind=="mine" and not deposits.has(c):return "Needs a gold deposit"
	var cells=footprint(kind,c,rotation)
	var ground_error=terrain.building_error(cells)
	if not ground_error.is_empty():return ground_error
	var build_region=building_region_for(terrain_source,terrain_scale*map_expansion)
	for tile in cells:
		for portal in portals:
			if tile in portal_cells(portal):return "Keep the spawn portal and its exit clear"
		if not build_region.has_point(tile):return "Keep the whole building inside the map"
		if scenery_cells.has(tile):return "Trees or rocks block this ground"
		if occupancy.has(tile) and not (kind=="gate" and buildings[occupancy[tile]].kind=="wall"):return "Ground is occupied"
		if kind!="mine":
			for deposit in deposits:
				if footprint("mine",deposit,0).has(tile):return "Keep this deposit clear for a mine"
	var gate_error=gate_clearance_error(cells,{"cell":c,"rotation":rotation} if kind=="gate" else {})
	if not gate_error.is_empty():return gate_error
	return "" if kind=="gate" else gate_route_error(cells)
func resolve_placement(kind:String,c:Vector2i,rotation:int,radius:int=1)->Dictionary:
	var error=placement_error(kind,c,rotation)
	var result={"cell":c,"rotation":rotation,"error":error,"adjusted":false}
	if error.is_empty() or phase!="preparing" or not COSTS.has(kind) or gold<COSTS[kind] or kind=="mine":return result
	var candidates=[];var reach=clampi(radius,0,2)
	for x in range(-reach,reach+1):
		for z in range(-reach,reach+1):
			if x!=0 or z!=0:candidates.append(Vector2i(x,z))
	candidates.sort_custom(func(a:Vector2i,b:Vector2i):
		if a.length_squared()!=b.length_squared():return a.length_squared()<b.length_squared()
		return a.x<b.x if a.x!=b.x else a.y<b.y)
	for offset in candidates:
		var candidate=c+offset
		if placement_error(kind,candidate,rotation).is_empty():
			return {"cell":candidate,"rotation":rotation,"error":"","adjusted":true}
	return result
func build(kind: String,c: Vector2i,rotation: int)->Dictionary:
	if not placement_error(kind,c,rotation).is_empty():return {}
	if kind=="gate":
		var replace=[]
		var gate_tiles=footprint(kind,c,rotation)
		for tile in gate_tiles:
			if occupancy.has(tile) and not replace.has(occupancy[tile]):replace.append(occupancy[tile])
		for id in replace:
			var wall: Dictionary=buildings[id].duplicate()
			var remaining=footprint("wall",wall.cell,wall.rotation,wall.get("span",0)).filter(func(tile):return not gate_tiles.has(tile))
			_remove_building(id)
			# A gate cuts only its own opening, retaining either end of a long wall.
			var run=[]
			for tile in remaining:
				if not run.is_empty() and (tile-run.back()).length_squared()>1:
					_restore_wall_end(wall,run);run=[]
				run.append(tile)
			if not run.is_empty():_restore_wall_end(wall,run)
	gold-=COSTS[kind]
	var b=_make_building(kind,c,rotation)
	rebuild_navigation();revision+=1;update_vision(hero_position)
	if not _construction_batch:_finish_construction([b])
	return b
func _finish_construction(added:Array):
	ConstructionClearance.relocate_workers(self,added)
	construction_completed.emit(added)
func _restore_wall_end(original: Dictionary,cells: Array):
	var end=_make_building("wall",cells.front(),original.rotation,cells.size())
	end.hp=end.max_hp*original.hp/original.max_hp
func _remove_building(id: int):
	if not buildings.has(id):return
	var b: Dictionary=buildings[id]
	for c in footprint(b.kind,b.cell,b.rotation,b.get("span",0)):occupancy.erase(c)
	for w in workers.values():
		if w.job==id:
			workforce.leave_shelter(w)
			workforce.leave_tower(w)
			if phase=="preparing" and w.has("exit_point"):
				w.pos=w.exit_point;w.erase("exit_point");w.deck_height=0.0
			w.job=-1;w.state="idle";w.path=[]
	buildings.erase(id)
func demolish(id: int)->bool:
	if phase!="preparing" or id==1 or not buildings.has(id):return false
	var b: Dictionary=buildings[id]
	gold+=int(COSTS[b.kind]*.5*(b.get("span",SIZES.wall.x)/float(SIZES.wall.x) if b.kind=="wall" else 1.0))
	_remove_building(id);rebuild_navigation();revision+=1;update_vision(hero_position);return true
func repair(id: int)->bool:
	if phase!="preparing" or not buildings.has(id):return false
	var b: Dictionary=buildings[id];var cost=ceili((b.max_hp-b.hp)/10.0)
	if b.kind=="wall":return false
	if cost<=0 or gold<cost:return false
	gold-=cost;b.hp=b.max_hp
	if b.kind=="gate":close_repaired_gate(id)
	revision+=1;return true
func close_repaired_gate(id:int)->bool:
	var b:Dictionary=buildings.get(id,{})
	if b.get("kind","")!="gate" or b.get("door_removed",false) or not b.get("breached",false) or b.hp<b.max_hp:return false
	sync_enemy_records()
	# Finish rebuilding before sealing, and never trap an actor mid-passage.
	var size_:Vector2i=dimensions(b.kind,b.rotation)
	var low:Vector3=point(b.cell)-Vector3(3,0,3)
	var high=low+Vector3(size_.x*CELL,0,size_.y*CELL)
	for enemy in enemies.values():
		if enemy.hp<=0:continue
		var p:Vector3=enemy.pos
		var radius:float=preload("res://scripts/forest/forest_enemy_roles.gd").footprint_radius(int(enemy.get("variant",0)),balance.enemy_size_mult)+.1
		var closest=Vector2(clampf(p.x,low.x,high.x),clampf(p.z,low.z,high.z))
		if Vector2(p.x,p.z).distance_squared_to(closest)<radius*radius:return false
	b.breached=false;rebuild_navigation();revision+=1;update_vision(hero_position);return true
func damage_building(id: int,amount: float):
	if phase!="wave" or not buildings.has(id):return
	var b: Dictionary=buildings[id]
	if b.kind=="shrine" and base_invulnerable:return
	if b.kind=="wall" or b.get("breached",false) or amount<=0:return
	var previous_hp:float=b.hp;b.hp=maxf(0,b.hp-amount*(.5 if b.kind=="barracks" else 1.0))
	if b.kind=="barracks" and b.hp<previous_hp:b.damage_serial=int(b.get("damage_serial",0))+1
	if b.kind in ["wall","gate"] and b.hp<previous_hp:
		events.append({"kind":"wall_damage","id":id,"point":center(b)+Vector3.UP*2.5,"damage":previous_hp-b.hp,"max_hp":b.max_hp,"destroyed":b.hp<=0})
	if b.hp<=0:
		if id==1:phase="defeat";events.append({"kind":"defeat"});return
		if b.kind=="gate":
			b.breached=true;rebuild_navigation();revision+=1;update_vision(hero_position);return
		if b.kind=="cannon_tower":events.append({"kind":"cannon_sound","event":"death","point":center(b)})
		_remove_building(id);rebuild_navigation();revision+=1;update_vision(hero_position)
func visible_at(p: Vector3)->bool:return visible_cells.has(cell_of(p))
func explored_at(p: Vector3)->bool:return explored.has(cell_of(p))
func _line_visible(a: Vector2i,b: Vector2i,high: bool)->bool:
	if high:return true
	var delta_=b-a;var steps=maxi(absi(delta_.x),absi(delta_.y))
	for i in range(1,steps):
		var c=a+Vector2i(roundi(delta_.x*float(i)/steps),roundi(delta_.y*float(i)/steps))
		if scenery_cells.has(c):return false
		if occupancy.has(c):
			var structure:Dictionary=buildings[occupancy[c]]
			if structure.kind in ["wall","gate"] and not structure.get("breached",false):return false
	return true
func update_vision(hero: Vector3):
	hero_position=hero
	# Fog of war is retired. Reveal once, then skip per-unit sight circles/LOS
	# scans entirely, including when large armies update their positions.
	if visible_cells.size()==navigation_region.get_area() and explored.size()>=navigation_region.get_area():return
	visible_cells.clear();explored.clear();sight_cache.clear()
	for x in range(navigation_region.position.x,navigation_region.end.x):
		for z in range(navigation_region.position.y,navigation_region.end.y):
			var cell=Vector2i(x,z);visible_cells[cell]=true;explored[cell]=true

func start_wave()->bool:
	return waves.begin() if waves!=null else false

func sync_enemy_records(handles:PackedInt64Array=PackedInt64Array()):
	if is_instance_valid(army_runtime) and army_runtime.has_method("publish_model_rows"):army_runtime.publish_model_rows(handles)
func sync_enemy_targets(ids:Array):
	if not is_instance_valid(army_runtime) or not army_runtime.has_method("publish_model_rows"):return
	var handles=PackedInt64Array()
	for id in ids:
		var handle:int=army_runtime.handles.get(id,0)
		if handle!=0:handles.append(handle)
	if not handles.is_empty():army_runtime.publish_model_rows(handles)
func tick(delta: float,hero: Vector3):
	hero_position=hero
	if phase=="preparing":
		workforce.prepare_tick(delta)
		if waves!=null and waves.giant_pending:waves.navigation.refresh()
	elif phase=="wave":
		waves.tick(delta,hero)
		if phase!="wave":return
		workforce.tick(delta,hero)
	else:return
	_tick_sight(delta,hero)
func _tick_sight(delta:float,hero:Vector3):
	sight_clock-=delta
	if sight_clock<=0:update_vision(hero);sight_clock=.2
func rally(held: bool,hero: Vector3):
	if workforce!=null:workforce.rally(held,hero)
func damage_worker(id: int,amount: float):
	if workforce!=null:workforce.damage(id,amount)
func damage_enemy(id: int,amount: float):
	if is_instance_valid(army_runtime):army_runtime.damage_enemy(id,amount)

func build_wall_line(cells: Array,rotation: int)->Array:
	if phase!="preparing" or cells.is_empty() or cells.size()>40 or gold<cells.size()*COSTS.wall:return []
	var saved_buildings=buildings.duplicate(true);var saved_occupancy=occupancy.duplicate()
	var saved_explored=explored.duplicate();var saved_gold=gold;var saved_id=next_id;var saved_revision=revision
	var added=[]
	_construction_batch=true
	for c in cells:
		var b=build("wall",c,rotation)
		if b.is_empty():
			_construction_batch=false
			buildings=saved_buildings;occupancy=saved_occupancy;explored=saved_explored
			gold=saved_gold;next_id=saved_id;revision=saved_revision
			rebuild_navigation();update_vision(hero_position);return []
		added.append(b)
	_construction_batch=false
	_finish_construction(added)
	return added

func apply_tower_balance(config: Dictionary):
	var accepted=Balance.sanitized(config)
	for row in Balance.ROWS:
		if row[0].begins_with("tower_"):balance[row[0]]=accepted[row[0]]
	for b in buildings.values():
		if b.kind not in ["tower","cannon_tower"]:continue
		var fraction: float=b.hp/maxf(1,b.max_hp)
		b.max_hp=balance.tower_health;b.hp=b.max_hp*fraction
		b.clock=minf(b.clock,workforce.attack_interval(b))
	revision+=1
