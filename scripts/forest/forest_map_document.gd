extends RefCounted
## Authored layout only; never serializes live run progress or engine objects.
const Model=preload("res://scripts/forest/forest_model.gd")
const Scenery=preload("res://scripts/forest/forest_scenery.gd")
const Kit=preload("res://scripts/forest/forest_environment_kit.gd")
const WIND_MEADOW_LARGE_PATH="res://assets/maps/forest_wind_meadow_large.json"
const WIND_MEADOW_PATH="res://assets/maps/forest_wind_meadow.json"
const MAP_FOLDER="user://forest_maps"
const MAX_BYTES=524288
const KINDS=["tower","cannon_tower","wall","gate","mine","barracks","tree","rock","deposit","portal","road"]
var include_mines=true
var data: Dictionary={}
var history: Array=[]
var future: Array=[]
var saved_text=""
var path=""
var gate_validation_hash=-1
var gate_validation_model
var reserved_cells:Dictionary={}
var dirty: bool:
	get:return encode()!=saved_text
func _init(allow_mines:bool=true):include_mines=allow_mines
func encode()->String:return JSON.stringify(data)
func capture(model):
	data={"format":"forest_shrine_map","schema":1,"title":"My Forest Map","buildings":[],"trees":[],"deposits":[],"portals":model.portals.map(func(p):return {"x":p.x,"z":p.z,"rotation":p.rotation}),"ramparts":model.ramparts.duplicate(true),"roads":[]}
	if not model.terrain_source.is_empty():data.terrain_source=model.terrain_source
	if model.terrain_source in ["blood_gulch","wind_meadow"] and not is_equal_approx(model.terrain_scale,1.0):data.terrain_scale=model.terrain_scale
	if model.map_expansion!=1.0:data.map_expansion=model.map_expansion
	if model.raised_castle:data.raised_castle=true
	for b in model.buildings.values():
		if b.kind!="shrine":data.buildings.append({"kind":b.kind,"x":b.cell.x,"z":b.cell.y,"rotation":b.rotation,"span":b.get("span",0)})
	for c in model.trees:
		var item={"x":c.x,"z":c.y,"scale":model.trees[c]}
		if model.tree_rotations.has(c):item.rotation=model.tree_rotations[c]
		data.trees.append(item)
	if not model.rocks.is_empty():
		data.rocks=[]
		for c in model.rocks:data.rocks.append({"x":c.x,"z":c.y,"scale":model.rocks[c].scale,"rotation":model.rocks[c].rotation})
	if not model.props.is_empty():
		data.props=[]
		for c in model.props:data.props.append({"kind":model.props[c].kind,"x":c.x,"z":c.y,"scale":model.props[c].scale,"rotation":model.props[c].rotation})
	for group in Scenery.GROUPS:
		var source=model.trees if group=="trees" else model.rocks if group=="rocks" else model.props
		var index=0
		for anchor in source:
			if model.scenery_heights.has(anchor):data[group][index].height=model.scenery_heights[anchor]
			index+=1
	for c in model.deposits:data.deposits.append({"x":c.x,"z":c.y,"amount":maxi(1,model.deposits[c])})
	for c in model.roads:data.roads.append({"x":c.x,"z":c.y})
	history.clear();future.clear();path="";saved_text=encode()
func load_wind_meadow_large()->String:return read_file(WIND_MEADOW_LARGE_PATH)
func load_wind_meadow()->String:return read_file(WIND_MEADOW_PATH)
func read_file(file_path: String)->String:
	var file=FileAccess.open(file_path,FileAccess.READ)
	if file==null:return "Could not open this map."
	if file.get_length()>MAX_BYTES:return "Map file is too large."
	var error=decode(file.get_as_text())
	if error.is_empty():path=file_path
	return error
func decode(source: String)->String:
	if source.to_utf8_buffer().size()>MAX_BYTES:return "Map file is too large."
	var parsed=JSON.new()
	if parsed.parse(source)!=OK:return "This file is not valid map JSON."
	var error=validate(parsed.data)
	if not error.is_empty():return error
	data=parsed.data
	# Normalize JSON number types and discard unsupported fields.
	var model=Model.new();model.reset(42,{},data,include_mines);var title=data.title
	capture(model);data.title=title
	history.clear();future.clear();saved_text=encode();path=""
	return ""
static func integer(value,minimum: int,maximum: int)->bool:
	return (value is int or value is float) and is_finite(float(value)) and value==floor(value) and value>=minimum and value<=maximum
static func validate(value)->String:
	if not value is Dictionary or value.get("format")!="forest_shrine_map" or value.get("schema")!=1:return "Unsupported Forest map format."
	if not value.get("title") is String or value.title.strip_edges().is_empty() or value.title.length()>48:return "Map names need 1–48 characters."
	if value.has("terrain_source") and (not value.terrain_source is String or value.terrain_source not in ["","kai_highway","blood_gulch","wind_meadow"]):return "Unsupported map terrain source."
	var scale_=value.get("terrain_scale",1.0)
	if not (scale_ is float or scale_ is int) or not is_finite(float(scale_)) or scale_<1.0 or (scale_>1.25 and not (value.get("terrain_source","")=="wind_meadow" and scale_ in [2.0,3.0])):return "Unsupported terrain scale."
	if value.get("terrain_source","") not in ["blood_gulch","wind_meadow"] and not is_equal_approx(float(scale_),1.0):return "Terrain scaling requires a supported valley or canyon."
	if value.get("terrain_source","")=="wind_meadow" and scale_ not in [1.0,2.0,3.0]:return "Unsupported valley scale."
	var raised=value.get("raised_castle",false)
	if not raised is bool or (raised and value.get("terrain_source","")!="wind_meadow"):return "Raised castles require Wind Meadow Valley."
	var expansion=value.get("map_expansion",1.0)
	if not (expansion is float or expansion is int) or expansion not in Model.WindMeadowTerrain.EXPANSIONS:return "Unsupported map expansion."
	if expansion!=1.0 and value.get("terrain_source","")!="wind_meadow":return "Map expansion requires Wind Meadow Valley."
	var region=Model.region_for(value.get("terrain_source",""),float(scale_)*expansion);var low=region.position.x+1;var high=region.end.x-1
	var build_region=Model.building_region_for(value.get("terrain_source",""),float(scale_)*expansion)
	for key in ["buildings","trees","deposits"]:
		if not value.get(key) is Array:return "Map object lists are missing."
	if value.buildings.size()>512 or value.trees.size()>4096 or value.deposits.size()>64:return "This map has too many objects."
	for key in ["portals","roads","rocks","props"]:
		if value.has(key) and not value[key] is Array:return "Invalid portal or road list."
	if value.get("portals",[]).size()>16 or value.get("roads",[]).size()>8192:return "Use at most 16 portals and 8192 road tiles."
	if value.get("rocks",[]).size()+value.get("props",[]).size()>4096:return "Use at most 4096 rocks."
	if value.get("terrain_source","")=="wind_meadow" and value.get("portals",[]).size()<4:return "The valley needs at least four enemy strongholds."
	var terrain_error=Model.Ramparts.validation_error(value.get("ramparts",[]),region)
	if not terrain_error.is_empty():return terrain_error
	terrain_error=Kit.validation_error(value.get("ramparts",[]))
	if not terrain_error.is_empty():return terrain_error
	var terrain=Model.create_terrain(value.get("terrain_source",""),float(scale_),expansion,raised);terrain.configure(value.get("ramparts",[]))
	for cell in [Vector2i(-1,-1),Vector2i(0,-1),Vector2i(1,-1),Vector2i(-1,0),Vector2i(0,0),Vector2i(1,0),Vector2i(-1,1),Vector2i(0,1),Vector2i(1,1),Vector2i(0,2),Vector2i(0,3)]:
		if terrain.overlaps_tile(cell):return "Keep the base and hero start at ground level."
	var road_cells={}
	for item in value.get("roads",[]):
		if not item is Dictionary or not integer(item.get("x"),low,high) or not integer(item.get("z"),low,high):return "A road tile is outside the map."
		var cell=Vector2i(item.x,item.z)
		if road_cells.has(cell):return "Duplicate road tile."
		road_cells[cell]=true
	var model=Model.new();var occupied={};var deposits={};var structure_tops={};var scenery_boxes={};var scenery_tiles={}
	for c in model.footprint("shrine",Vector2i(-1,-1),0):occupied[c]="shrine"
	for group in ["deposits","buildings","portals","trees","rocks","props"]:
		for item in value.get(group,[]):
			if not item is Dictionary or not integer(item.get("x"),low,high) or not integer(item.get("z"),low,high):return "An object is outside the map."
			var c=Vector2i(item.x,item.z)
			if group=="deposits":
				if not integer(item.get("amount"),1,1000000):return "Invalid gold deposit amount."
				for tile in model.footprint("mine",c,0):
					if not Model.ALLIED_REGION.has_point(tile) or occupied.has(tile) or terrain.overlaps_tile(tile):return "Gold deposits overlap another object or protected ground."
					occupied[tile]="deposit"
				deposits[c]=true
			elif group=="buildings":
				if item.get("kind") not in ["tower","cannon_tower","wall","gate","mine","barracks"] or not integer(item.get("rotation"),0,3) or not integer(item.get("span",0),0,6):return "Invalid structure or rotation."
				if item.kind=="mine" and not deposits.has(c):return "Place a gold deposit before its mine."
				var footprint=model.footprint(item.kind,c,int(item.rotation),int(item.get("span",0)))
				var building_ground_error=terrain.building_error(footprint)
				if not building_ground_error.is_empty():return building_ground_error
				var ground=terrain.building_ground_range(footprint)
				var top=(ground.y if is_finite(ground.y) else terrain.height(c.x*6,c.y*6))+preload("res://scripts/forest/forest_structure_profile.gd").height(item.kind)
				for tile in footprint:
					if not build_region.has_point(tile):return "Keep the whole building inside the map."
					if occupied.has(tile) and not (item.kind=="mine" and occupied[tile]=="deposit"):return "Objects overlap, or touch the base."
					occupied[tile]=item.kind
					structure_tops[tile]=top
			elif group=="portals":
				if not integer(item.get("rotation"),0,3):return "Invalid portal rotation."
				var portal=item.duplicate();portal.castle=value.get("terrain_source","")=="wind_meadow" and scale_ in [2.0,3.0]
				for tile in Model.portal_cells(portal):
					if tile.x<low or tile.x>high or tile.y<low or tile.y>high or occupied.has(tile):return "Keep the portal arch and exit clear of objects and protected ground."
					occupied[tile]="portal"
			else:
				if group=="props" and item.get("kind") not in Scenery.CATALOG:return "Unsupported scenery asset."
				var scale_value=item.get("scale")
				if not (scale_value is float or scale_value is int) or not is_finite(float(scale_value)) or scale_value<Scenery.MIN_SCALE or scale_value>Scenery.MAX_SCALE:return "Scenery size must be between 0.5× and 2×."
				var rotation=item.get("rotation",-1)
				if (group in ["rocks","props"] or item.has("rotation")) and (not (rotation is float or rotation is int) or not is_finite(float(rotation)) or rotation<0 or rotation>=360):return "Scenery rotation must be between 0° and 359°."
				var height=item.get("height",0)
				if not (height is int or height is float) or not is_finite(float(height)) or height<0 or height>Scenery.MAX_HEIGHT:return "Scenery height must be between 0 and 256 metres."
				var box=Scenery.bounds(item.kind if group=="props" else ("tree" if group=="trees" else "rock"),float(scale_value),float(rotation))
				var cells=Scenery.footprint(c,box)
				box.position+=Vector3(c.x*6,terrain.height(c.x*6,c.y*6)+height,c.y*6)
				for tile in cells:
					if tile.x<low or tile.x>high or tile.y<low or tile.y>high:return "Keep the whole scenery piece inside the map."
					if occupied.get(tile,"") in ["shrine","portal","deposit"]:return "Keep the base, portals and deposits clear."
					if structure_tops.has(tile) and box.position.y<structure_tops[tile]-.001:return "Place scenery on top of the structure."
					for other:AABB in scenery_boxes.get(tile,[]):
						if box.grow(-.0001).intersects(other):return "Scenery pieces intersect. Place the new piece on top."
					if not scenery_boxes.has(tile):scenery_boxes[tile]=[]
					scenery_boxes[tile].append(box)
					scenery_tiles[tile]=true
	for module in value.get("ramparts",[]):
		if not module.has("kit"):continue
		var descriptor:Dictionary=module.kit
		for piece in Kit.segments(descriptor.kind,Vector2(descriptor.x,descriptor.z),int(descriptor.rotation),float(descriptor.height)):
			var bounds=Model.Ramparts.bounds(piece)
			var box=AABB(Vector3(bounds.position.x,0,bounds.position.y),Vector3(bounds.size.x,1,bounds.size.y))
			for tile in Scenery.footprint(Vector2i.ZERO,box):
				if occupied.get(tile,"") in ["portal","deposit"]:return "Keep portal exits and deposits clear of terrain modules."
	for item in value.buildings:
		if item.kind!="gate":continue
		var gate={"cell":Vector2i(item.x,item.z),"rotation":int(item.rotation)}
		if raised and terrain.castle_wall_cells(model.footprint("gate",gate.cell,gate.rotation)):continue
		for side in model.gate_approaches(gate):
			for tile in side:
				if not region.has_point(tile) or terrain.cliff_cell(tile) or scenery_tiles.has(tile) or (occupied.has(tile) and occupied[tile]!="gate"):return "Keep the gate passage clear."
	return ""
func _commit(candidate: Dictionary)->String:
	var error=validate(candidate)
	if not error.is_empty():return error
	history.append(data.duplicate(true));if history.size()>50:history.pop_front()
	future.clear();data=candidate;return ""
func rename(title: String):
	var value=title.strip_edges().left(48)
	if not value.is_empty():data.title=value
func candidate(kind: String,cell: Vector2,rotation: float,scale_:float=1.0,height:float=0)->Dictionary:
	var next=data.duplicate(true);var item={"x":int(cell.x),"z":int(cell.y)}
	if Kit.is_module(kind):
		if not next.has("ramparts"):next.ramparts=[]
		next.ramparts.append_array(Kit.placement(kind,cell,int(rotation),height))
	elif Scenery.is_piece(kind):
		var group="props" if Scenery.CATALOG.has(kind) else ("trees" if kind=="tree" else "rocks")
		if not next.has(group):next[group]=[]
		item.scale=scale_;item.rotation=rotation
		if height!=0:item.height=height
		if group=="props":item.kind=kind
		next[group].append(item)
	elif kind=="deposit":item.amount=1200;next.deposits.append(item)
	elif kind=="portal":item.rotation=posmod(rotation,4);next.portals.append(item)
	else:item.kind=kind;item.rotation=posmod(rotation,4);item.span=6 if kind=="wall" else 0;next.buildings.append(item)
	return next
func _placement_gate_error(kind:String,cell:Vector2i,rotation:float,scale_:float=1.0)->String:
	if (kind not in ["tower","cannon_tower","wall","mine","barracks"] and not Scenery.is_piece(kind)) or not data.buildings.any(func(item):return item.kind=="gate"):return ""
	var model=validation_model()
	return model.gate_route_error(Scenery.footprint(cell,Scenery.bounds(kind,scale_,rotation)) if Scenery.is_piece(kind) else model.footprint(kind,cell,int(rotation)))
func cache_preview(model):
	gate_validation_model=model;gate_validation_hash=data.hash();reserved_cells.clear()
	for portal in data.get("portals",[]):
		var camp=portal.duplicate();camp.castle=model.has_enemy_castles()
		for cell in Model.portal_cells(camp):reserved_cells[cell]="portal"
	for deposit in data.deposits:
		for cell in model.footprint("mine",Vector2i(deposit.x,deposit.z),0):reserved_cells[cell]="deposit"
	for building in model.buildings.values():
		if building.kind!="gate":continue
		if model.raised_castle and model.terrain.castle_wall_cells(model.footprint("gate",building.cell,building.rotation)):continue
		for side in model.gate_approaches(building):
			for cell in side:reserved_cells[cell]="gate"
func validation_model():
	if gate_validation_model==null or gate_validation_hash!=data.hash():
		var model=Model.new();model.reset(42,{},data,include_mines);cache_preview(model)
	return gate_validation_model
func scenery_error(kind:String,cell:Vector2i,rotation:float,scale_:float,ignore=null,height:float=0)->String:
	if not is_finite(scale_) or scale_<Scenery.MIN_SCALE or scale_>Scenery.MAX_SCALE:return "Scenery size must be between 0.5× and 2×."
	if not is_finite(rotation) or rotation<0 or rotation>=360:return "Scenery rotation must be between 0° and 359°."
	if not is_finite(height) or height<0 or height>Scenery.MAX_HEIGHT:return "Scenery height must be between 0 and 256 metres."
	var model=validation_model();var region:Rect2i=model.navigation_region
	var box=Scenery.bounds(kind,scale_,rotation);var cells=Scenery.footprint(cell,box)
	box.position+=model.point(cell)+Vector3.UP*height
	for tile in cells:
		if tile.x<region.position.x+1 or tile.y<region.position.y+1 or tile.x>region.end.x-1 or tile.y>region.end.y-1:return "Keep the whole scenery piece inside the map."
		if reserved_cells.has(tile):return "Keep portals, deposits and gate passages clear."
		if model.occupancy.has(tile):
			var building:Dictionary=model.buildings[model.occupancy[tile]]
			if building.kind=="shrine":return "Keep the base clear."
			if box.position.y<model.center(building).y+preload("res://scripts/forest/forest_structure_profile.gd").height(building.kind)-.001:return "Place scenery on top of the structure."
		for anchor in model.scenery_cells.get(tile,[]):
			if not is_same(anchor,ignore) and box.grow(-.0001).intersects(model.scenery_obstacles[anchor]):return "Scenery pieces intersect. Place the new piece on top."
	return ""
func building_error(kind:String,cell:Vector2i,rotation:float)->String:
	if not integer(rotation,0,3):return "Invalid structure or rotation."
	if data.buildings.size()>=512:return "This map has too many objects."
	var model=validation_model();var cells=model.footprint(kind,cell,int(rotation))
	var error=model.terrain.building_error(cells)
	if not error.is_empty():return error
	var region=Model.building_region_for(model.terrain_source,model.terrain_scale*model.map_expansion)
	for tile in cells:
		if not region.has_point(tile):return "Keep the whole building inside the map."
		if model.occupancy.has(tile) or model.scenery_cells.has(tile):return "Objects overlap, or touch the base."
		if reserved_cells.has(tile) and not (kind=="gate" and reserved_cells[tile]=="gate"):return "Keep portals, deposits and gate passages clear."
	if kind=="gate" and not (model.raised_castle and model.terrain.castle_wall_cells(cells)):
		for side in model.gate_approaches({"cell":cell,"rotation":int(rotation)}):
			for tile in side:
				var building:Dictionary=model.buildings.get(model.occupancy.get(tile,-1),{})
				if not model.navigation_region.has_point(tile) or model.terrain.cliff_cell(tile) or model.scenery_cells.has(tile) or (not building.is_empty() and building.kind!="gate") or reserved_cells.get(tile,"") in ["portal","deposit"]:return "Keep the gate passage clear."
	return ""
func portal_error(cell:Vector2i,rotation:float)->String:
	if not is_finite(rotation):return "Invalid portal rotation."
	if data.portals.size()>=16:return "Use at most 16 portals and 8192 road tiles."
	var model=validation_model();var region:Rect2i=model.navigation_region
	var portal={"x":cell.x,"z":cell.y,"rotation":posmod(rotation,4),"castle":model.has_enemy_castles()}
	for tile in Model.portal_cells(portal):
		if tile.x<region.position.x+1 or tile.y<region.position.y+1 or tile.x>region.end.x-1 or tile.y>region.end.y-1:return "Keep the portal arch and exit clear of objects and protected ground."
		if model.occupancy.has(tile) or model.scenery_cells.has(tile) or reserved_cells.has(tile):return "Keep the portal arch and exit clear of objects and protected ground."
	return ""
func terrain_error(kind:String,cell:Vector2,rotation:float,height:float)->String:
	if not integer(rotation,0,3) or not is_finite(height) or height<0 or height+(12 if kind=="ramp_12" else 6)>Model.Ramparts.MAX_HEIGHT:return "Use quarter turns and a base height between 0 and %d m."%(Model.Ramparts.MAX_HEIGHT-(12 if kind=="ramp_12" else 6))
	var model=validation_model();var pieces=Kit.placement(kind,cell,int(rotation),height)
	for piece in data.get("ramparts",[]):
		if piece.get("kit",{})==pieces[0].kit:return "This terrain module is already here."
	if data.get("ramparts",[]).size()+pieces.size()>24:return "Use at most 24 terrain segments."
	var error=Model.Ramparts.validation_error(pieces,model.navigation_region)
	if not error.is_empty():return error
	for piece in pieces:
		var bounds=Model.Ramparts.bounds(piece)
		var box=AABB(Vector3(bounds.position.x,0,bounds.position.y),Vector3(bounds.size.x,1,bounds.size.y))
		for tile in Scenery.footprint(Vector2i.ZERO,box):
			if model.occupancy.has(tile) or reserved_cells.has(tile):return "Keep the base, structures and portal exits clear."
	return ""
func placement_error(kind: String,cell: Vector2,rotation: float,scale_:float=1.0,height:float=0)->String:
	if Kit.is_module(kind):return terrain_error(kind,cell,rotation,height)
	var grid_cell=Vector2i(cell)
	if not include_mines and kind in ["mine","deposit"]:return "Gold mines are unavailable."
	if kind not in KINDS and not Scenery.CATALOG.has(kind):return "Choose an object."
	if kind=="road":return road_error([grid_cell],1)
	var error=""
	if Scenery.is_piece(kind):error=scenery_error(kind,grid_cell,rotation,scale_,null,height)
	elif kind in ["tower","cannon_tower","wall","gate","barracks"]:error=building_error(kind,grid_cell,rotation)
	elif kind=="portal":error=portal_error(grid_cell,rotation)
	else:error=validate(candidate(kind,cell,rotation,scale_))
	return error if not error.is_empty() else _placement_gate_error(kind,grid_cell,rotation,scale_)
func place(kind: String,cell: Vector2,rotation: float,scale_:float=1.0,height:float=0)->String:
	var error=placement_error(kind,cell,rotation,scale_,height)
	if not error.is_empty():return error
	if kind=="road":return paint_road([Vector2i(cell)],1)
	return _commit(candidate(kind,cell,rotation,scale_,height))
static func road_tiles(points: Array,width: int)->Array:
	var tiles={};var radius=width/2
	for point in points:
		for x in range(-radius,radius+1):
			for z in range(-radius,radius+1):tiles[point+Vector2i(x,z)]=true
	return tiles.keys()
func road_candidate(points: Array,width: int)->Dictionary:
	var next=data.duplicate(true);var tiles={}
	for item in next.roads:tiles[Vector2i(item.x,item.z)]=true
	for cell in road_tiles(points,width):tiles[cell]=true
	next.roads=[]
	for cell in tiles:next.roads.append({"x":cell.x,"z":cell.y})
	next.trees=next.trees.filter(func(item):return not scenery_footprint("trees",item).any(func(cell):return tiles.has(cell)))
	if next.has("props"):next.props=next.props.filter(func(item):return not (Scenery.is_tree(item.kind) and scenery_footprint("props",item).any(func(cell):return tiles.has(cell))))
	return next
func road_error(points: Array,width: int)->String:
	if width not in [1,3,5] or points.is_empty() or points.size()>6400:return "Choose a road width of 1, 3 or 5 tiles."
	var model=validation_model();var region:Rect2i=model.navigation_region;var added=0
	for cell in road_tiles(points,width):
		if cell.x<region.position.x+1 or cell.y<region.position.y+1 or cell.x>region.end.x-1 or cell.y>region.end.y-1:return "A road tile is outside the map."
		if not model.roads.has(cell):added+=1
		for anchor in model.scenery_cells.get(cell,[]):
			if model.rocks.has(anchor) or (model.props.has(anchor) and not Scenery.is_tree(model.props[anchor].kind)):return "Scenery overlaps an object, road or protected ground."
	if model.roads.size()+added>8192:return "Use at most 16 portals and 8192 road tiles."
	return ""
func paint_road(points: Array,width: int)->String:
	var error=road_error(points,width)
	if not error.is_empty():return error
	var next=road_candidate(points,width)
	if JSON.stringify(next)==encode():return ""
	return _commit(next)
func object_at(cell: Vector2i,anchor=null,terrain_index:int=-1)->Dictionary:
	if anchor!=null:
		for group in Scenery.GROUPS:
			for index in data.get(group,[]).size():
				if is_same(Scenery.anchor(data[group][index]),anchor):return {"group":group,"index":index}
	if terrain_index>=0 and terrain_index<data.get("ramparts",[]).size():
		for index in range(terrain_index,-1,-1):
			var item:Dictionary=data.get("ramparts",[])[index]
			if item.has("kit"):
				if terrain_index<index+Kit.segments(item.kit.kind,Vector2(item.kit.x,item.kit.z),int(item.kit.rotation),float(item.kit.height)).size():return {"group":"ramparts","index":index}
				break
	var model=Model.new()
	if cell in model.footprint("shrine",Vector2i(-1,-1),0):return {"group":"shrine","index":-1}
	for i in range(data.portals.size()):
		var portal=data.portals[i]
		if cell in Model.portal_cells(portal):return {"group":"portals","index":i}
	for i in range(data.buildings.size()):
		var item=data.buildings[i]
		if cell in model.footprint(item.kind,Vector2i(item.x,item.z),int(item.rotation),int(item.get("span",0))):return {"group":"buildings","index":i}
	for group in ["trees","rocks","props","deposits","roads"]:
		for i in range(data.get(group,[]).size()):
			var item=data[group][i];var c=Vector2i(item.x,item.z)
			if group in Scenery.GROUPS and cell in scenery_footprint(group,item):return {"group":group,"index":i}
			if cell==c or (group=="deposits" and cell in model.footprint("mine",c,0)):return {"group":group,"index":i}
	return {}
func selected_item(selection: Dictionary)->Dictionary:
	var group=selection.get("group","");var index=int(selection.get("index",-1))
	if not data.has(group) or index<0 or index>=data[group].size():return {}
	return data[group][index].get("kit",{}) if group=="ramparts" else data[group][index]
func transform_terrain(selection:Dictionary,rotation:int,height:float)->String:
	var item=selected_item(selection)
	if selection.get("group")!="ramparts" or item.is_empty():return "Select a terrain module."
	if not integer(rotation,0,3) or not is_finite(height) or height<0 or height+(12 if item.kind=="ramp_12" else 6)>Model.Ramparts.MAX_HEIGHT:return "Invalid terrain height or quarter turn."
	var next=data.duplicate(true);var index=int(selection.index)
	var count=Kit.segments(item.kind,Vector2(item.x,item.z),int(item.rotation),float(item.height)).size()
	next.ramparts=next.ramparts.slice(0,index)+Kit.placement(item.kind,Vector2(item.x,item.z),rotation,height)+next.ramparts.slice(index+count)
	return _commit(next)
static func scenery_rotation(group:String,item:Dictionary)->float:
	return float(item.get("rotation",fposmod(rad_to_deg(item.x*.79+item.z*1.73),360) if group=="trees" else 0))
static func scenery_footprint(group:String,item:Dictionary)->Array:
	return Scenery.footprint(Vector2i(item.x,item.z),Scenery.bounds(item.kind if group=="props" else ("tree" if group=="trees" else "rock"),float(item.scale),float(item.get("rotation",-1))))
func transform_scenery(selection:Dictionary,scale_:float,rotation:float,height:float=NAN)->String:
	if selection.get("group") not in Scenery.GROUPS or selected_item(selection).is_empty():return "Select a scenery piece."
	var next=data.duplicate(true);var item:Dictionary=next[selection.group][int(selection.index)]
	item.scale=scale_;item.rotation=rotation
	if not is_nan(height):
		if height==0:item.erase("height")
		else:item.height=height
	if next==data:return ""
	var kind=item.kind if selection.group=="props" else ("tree" if selection.group=="trees" else "rock")
	var error=scenery_error(kind,Vector2i(item.x,item.z),rotation,scale_,Scenery.anchor(selected_item(selection)),float(item.get("height",0)))
	if not error.is_empty():return error
	var old_cells=scenery_footprint(selection.group,selected_item(selection))
	var added=scenery_footprint(selection.group,item).filter(func(cell):return cell not in old_cells)
	if not added.is_empty():
		error=validation_model().gate_route_error(added)
		if not error.is_empty():return error
	return _commit(next)
func rotate(selection: Dictionary)->String:
	if selection.get("group") not in ["buildings","portals","trees","rocks","props","ramparts"]:return "Select a structure, terrain module or scenery piece to rotate."
	var item=selected_item(selection)
	if selection.group=="ramparts" and not item.is_empty():return transform_terrain(selection,(int(item.rotation)+1)%4,float(item.height))
	if item.is_empty():return "Select a structure to rotate."
	if selection.group in Scenery.GROUPS:return transform_scenery(selection,float(item.scale),fposmod(scenery_rotation(selection.group,item)+Scenery.TURN,360))
	var next=data.duplicate(true);next[selection.group][int(selection.index)].rotation=(int(item.rotation)+1)%4
	return _commit(next)
func remove(selection: Dictionary)->String:
	if selected_item(selection).is_empty():return "The base is protected. Select an editable object."
	var next=data.duplicate(true);var index=int(selection.index)
	if selection.group=="ramparts":
		var item=selected_item(selection);var count=Kit.segments(item.kind,Vector2(item.x,item.z),int(item.rotation),float(item.height)).size()
		next.ramparts=next.ramparts.slice(0,index)+next.ramparts.slice(index+count)
	else:next[selection.group].remove_at(index)
	return _commit(next)
func undo()->bool:
	if history.is_empty():return false
	var title=data.title
	future.append(data.duplicate(true));data=history.pop_back();data.title=title;return true
func redo()->bool:
	if future.is_empty():return false
	var title=data.title
	history.append(data.duplicate(true));data=future.pop_back();data.title=title;return true
func play_error()->String:
	var error=validate(data)
	if not error.is_empty():return error
	var model=Model.new();model.reset(42,{},data,include_mines)
	return load("res://scripts/forest/forest_routes.gd").validate_portals(model)
func save(folder: String=MAP_FOLDER)->String:
	var error=validate(data)
	if not error.is_empty():return error
	var encoded=encode()
	if encoded.to_utf8_buffer().size()>MAX_BYTES:return "Map file is too large."
	var stem=""
	for letter in data.title.to_lower():stem+=letter if letter in "abcdefghijklmnopqrstuvwxyz0123456789-_" else "_"
	stem=stem.left(32)+"-"+data.title.sha256_text().left(8)
	var destination=folder.path_join(stem+".json")
	if destination.begins_with("res://"):return "The bundled original is read-only."
	if DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))!=OK:return "Could not create the map folder."
	var file=FileAccess.open(destination+".tmp",FileAccess.WRITE)
	if file==null:return "Could not save this map."
	file.store_string(encoded);file.flush();var result=file.get_error();file.close()
	if result!=OK:return "Could not finish writing the map."
	if DirAccess.rename_absolute(ProjectSettings.globalize_path(destination+".tmp"),ProjectSettings.globalize_path(destination))!=OK:return "Could not replace the saved map."
	path=destination;saved_text=encode();return ""
static func list_maps(folder: String=MAP_FOLDER)->Array:
	var result=[]
	if not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(folder)):return result
	for filename in DirAccess.get_files_at(folder):
		if filename.get_extension()!="json":continue
		var path_=folder.path_join(filename);var file=FileAccess.open(path_,FileAccess.READ)
		if file==null or file.get_length()>MAX_BYTES:continue
		var parsed=JSON.new()
		if parsed.parse(file.get_as_text())==OK and validate(parsed.data).is_empty():result.append({"title":parsed.data.title,"path":path_})
	result.sort_custom(func(a,b):return a.title.naturalnocasecmp_to(b.title)<0)
	return result
