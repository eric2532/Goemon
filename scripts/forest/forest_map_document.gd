extends RefCounted
## Authored layout only; never serializes live run progress or engine objects.
const Model=preload("res://scripts/forest/forest_model.gd")
const RAMPARTS_PATH="res://assets/maps/forest_twin_ramparts.json"
const FOUR_GATES_PATH="res://assets/maps/forest_four_gates.json"
const BLOOD_GULCH_PATH="res://assets/maps/forest_blood_gulch.json"
const KAI_HIGHWAY_PATH="res://assets/maps/forest_kai_highway.json"
const ORIGINAL_PATH="res://assets/maps/forest_shrine_original.json"
const MAP_FOLDER="user://forest_maps"
const MAX_BYTES=524288
const KINDS=["tower","wall","gate","mine","barracks","tree","deposit","portal","road"]
var include_mines=true
var data: Dictionary={}
var history: Array=[]
var future: Array=[]
var saved_text=""
var path=""
var gate_validation_text=""
var gate_validation_model
var dirty: bool:
	get:return encode()!=saved_text
func _init(allow_mines:bool=true):include_mines=allow_mines
func encode()->String:return JSON.stringify(data)
func capture(model):
	data={"format":"forest_shrine_map","schema":1,"title":"My Forest Map","buildings":[],"trees":[],"deposits":[],"portals":model.portals.duplicate(true),"ramparts":model.ramparts.duplicate(true),"roads":[]}
	if not model.terrain_source.is_empty():data.terrain_source=model.terrain_source
	if model.terrain_source=="blood_gulch" and not is_equal_approx(model.terrain_scale,1.0):data.terrain_scale=model.terrain_scale
	for b in model.buildings.values():
		if b.kind!="shrine":data.buildings.append({"kind":b.kind,"x":b.cell.x,"z":b.cell.y,"rotation":b.rotation,"span":b.get("span",0)})
	for c in model.trees:data.trees.append({"x":c.x,"z":c.y,"scale":model.trees[c]})
	for c in model.deposits:data.deposits.append({"x":c.x,"z":c.y,"amount":maxi(1,model.deposits[c])})
	for c in model.roads:data.roads.append({"x":c.x,"z":c.y})
	history.clear();future.clear();path="";saved_text=encode()
func load_original()->String:return read_file(ORIGINAL_PATH)
func load_ramparts()->String:return read_file(RAMPARTS_PATH)
func load_four_gates()->String:return read_file(FOUR_GATES_PATH)
func load_blood_gulch()->String:return read_file(BLOOD_GULCH_PATH)
func load_kai_highway()->String:return read_file(KAI_HIGHWAY_PATH)
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
	if value.has("terrain_source") and (not value.terrain_source is String or value.terrain_source not in ["","kai_highway","blood_gulch"]):return "Unsupported map terrain source."
	var scale_=value.get("terrain_scale",1.0)
	if not (scale_ is float or scale_ is int) or not is_finite(float(scale_)) or scale_<1.0 or scale_>1.25:return "Unsupported terrain scale."
	if value.get("terrain_source","")!="blood_gulch" and not is_equal_approx(float(scale_),1.0):return "Terrain scaling requires Blood Gulch."
	var region=Model.region_for(value.get("terrain_source",""),float(scale_));var low=region.position.x+1;var high=region.end.x-1
	var build_region=Model.building_region_for(value.get("terrain_source",""),float(scale_))
	for key in ["buildings","trees","deposits"]:
		if not value.get(key) is Array:return "Map object lists are missing."
	if value.buildings.size()>512 or value.trees.size()>4096 or value.deposits.size()>64:return "This map has too many objects."
	for key in ["portals","roads"]:
		if value.has(key) and not value[key] is Array:return "Invalid portal or road list."
	if value.get("portals",[]).size()>16 or value.get("roads",[]).size()>4096:return "Use at most 16 portals and 4096 road tiles."
	var terrain_error=Model.Ramparts.validation_error(value.get("ramparts",[]))
	if not terrain_error.is_empty():return terrain_error
	var terrain=Model.create_terrain(value.get("terrain_source",""),float(scale_));terrain.configure(value.get("ramparts",[]))
	for cell in [Vector2i(-1,-1),Vector2i(0,-1),Vector2i(1,-1),Vector2i(-1,0),Vector2i(0,0),Vector2i(1,0),Vector2i(-1,1),Vector2i(0,1),Vector2i(1,1),Model.TRAINING_DUMMY_CELL,Vector2i(0,2),Vector2i(0,3)]:
		if terrain.overlaps_tile(cell):return "Keep the base, hero start and training dummy at ground level."
	var road_cells={}
	for item in value.get("roads",[]):
		if not item is Dictionary or not integer(item.get("x"),low,high) or not integer(item.get("z"),low,high):return "A road tile is outside the map."
		var cell=Vector2i(item.x,item.z)
		if road_cells.has(cell):return "Duplicate road tile."
		road_cells[cell]=true
	var model=Model.new();var occupied={};var deposits={}
	for c in model.footprint("shrine",Vector2i(-1,-1),0):occupied[c]="shrine"
	occupied[Model.TRAINING_DUMMY_CELL]="training dummy"
	for group in ["deposits","buildings","portals","trees"]:
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
				if item.get("kind") not in ["tower","wall","gate","mine","barracks"] or not integer(item.get("rotation"),0,3) or not integer(item.get("span",0),0,6):return "Invalid structure or rotation."
				if item.kind=="mine" and not deposits.has(c):return "Place a gold deposit before its mine."
				var footprint=model.footprint(item.kind,c,int(item.rotation),int(item.get("span",0)))
				var building_ground_error=terrain.building_error(footprint)
				if not building_ground_error.is_empty():return building_ground_error
				for tile in footprint:
					if not build_region.has_point(tile):return "Keep the whole building inside the map."
					if occupied.has(tile) and not (item.kind=="mine" and occupied[tile]=="deposit"):return "Objects overlap, or touch the base or training dummy."
					occupied[tile]=item.kind
			elif group=="portals":
				if not integer(item.get("rotation"),0,3):return "Invalid portal rotation."
				for tile in Model.portal_cells(item):
					if tile.x<low or tile.x>high or tile.y<low or tile.y>high or occupied.has(tile):return "Keep the portal arch and exit clear of objects and protected ground."
					occupied[tile]="portal"
			else:
				var scale_value=item.get("scale")
				if not (scale_value is float or scale_value is int) or not is_finite(float(scale_value)) or scale_value<.5 or scale_value>2:return "Invalid tree size."
				if terrain.overlaps_tile(c):return "Place trees on clear, level ground." if value.get("terrain_source","") in ["kai_highway","blood_gulch"] else "Keep trees off raised wall routes."
				if occupied.has(c) or road_cells.has(c):return "Trees overlap an object, road or protected ground."
				occupied[c]="tree"
	for item in value.buildings:
		if item.kind!="gate":continue
		var gate={"cell":Vector2i(item.x,item.z),"rotation":int(item.rotation)}
		for side in model.gate_approaches(gate):
			for tile in side:
				if not region.has_point(tile) or terrain.cliff_cell(tile) or (occupied.has(tile) and occupied[tile]!="gate"):return "Keep the gate passage clear."
	return ""
func _commit(candidate: Dictionary)->String:
	var error=validate(candidate)
	if not error.is_empty():return error
	history.append(data.duplicate(true));if history.size()>50:history.pop_front()
	future.clear();data=candidate;return ""
func rename(title: String):
	var value=title.strip_edges().left(48)
	if not value.is_empty():data.title=value
func candidate(kind: String,cell: Vector2i,rotation: int)->Dictionary:
	var next=data.duplicate(true);var item={"x":cell.x,"z":cell.y}
	if kind=="tree":item.scale=1.0;next.trees.append(item)
	elif kind=="deposit":item.amount=1200;next.deposits.append(item)
	elif kind=="portal":item.rotation=posmod(rotation,4);next.portals.append(item)
	else:item.kind=kind;item.rotation=posmod(rotation,4);item.span=6 if kind=="wall" else 0;next.buildings.append(item)
	return next
func _placement_gate_error(kind:String,cell:Vector2i,rotation:int)->String:
	if kind not in ["tower","wall","mine","barracks","tree"] or not data.buildings.any(func(item):return item.kind=="gate"):return ""
	var text=encode()
	if gate_validation_model==null or gate_validation_text!=text:
		gate_validation_model=Model.new();gate_validation_model.reset(42,{},data,include_mines)
		gate_validation_text=text
	return gate_validation_model.gate_route_error([cell] if kind=="tree" else gate_validation_model.footprint(kind,cell,rotation))
func placement_error(kind: String,cell: Vector2i,rotation: int)->String:
	if not include_mines and kind in ["mine","deposit"]:return "Gold mines are unavailable."
	if kind not in KINDS:return "Choose an object."
	if kind=="road":return road_error([cell],1)
	var error=validate(candidate(kind,cell,rotation))
	return error if not error.is_empty() else _placement_gate_error(kind,cell,rotation)
func place(kind: String,cell: Vector2i,rotation: int)->String:
	var error=placement_error(kind,cell,rotation)
	if not error.is_empty():return error
	if kind=="road":return paint_road([cell],1)
	return _commit(candidate(kind,cell,rotation))
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
	next.trees=next.trees.filter(func(item):return not tiles.has(Vector2i(item.x,item.z)))
	return next
func road_error(points: Array,width: int)->String:
	if width not in [1,3,5] or points.is_empty() or points.size()>6400:return "Choose a road width of 1, 3 or 5 tiles."
	return validate(road_candidate(points,width))
func paint_road(points: Array,width: int)->String:
	var error=road_error(points,width)
	if not error.is_empty():return error
	var next=road_candidate(points,width)
	if JSON.stringify(next)==encode():return ""
	return _commit(next)
func object_at(cell: Vector2i)->Dictionary:
	var model=Model.new()
	if cell in model.footprint("shrine",Vector2i(-1,-1),0):return {"group":"shrine","index":-1}
	for i in range(data.portals.size()):
		var portal=data.portals[i]
		if absi(cell.x-int(portal.x))<=2 and absi(cell.y-int(portal.z))<=2:return {"group":"portals","index":i}
	for i in range(data.buildings.size()):
		var item=data.buildings[i]
		if cell in model.footprint(item.kind,Vector2i(item.x,item.z),int(item.rotation),int(item.get("span",0))):return {"group":"buildings","index":i}
	for group in ["trees","deposits","roads"]:
		for i in range(data[group].size()):
			var item=data[group][i];var c=Vector2i(item.x,item.z)
			if cell==c or (group=="deposits" and cell in model.footprint("mine",c,0)):return {"group":group,"index":i}
	return {}
func selected_item(selection: Dictionary)->Dictionary:
	var group=selection.get("group","");var index=int(selection.get("index",-1))
	if not data.has(group) or index<0 or index>=data[group].size():return {}
	return data[group][index]
func rotate(selection: Dictionary)->String:
	if selection.get("group") not in ["buildings","portals"]:return "Select a structure or portal to rotate."
	var item=selected_item(selection)
	if item.is_empty():return "Select a structure to rotate."
	var next=data.duplicate(true);next[selection.group][int(selection.index)].rotation=(int(item.rotation)+1)%4
	return _commit(next)
func remove(selection: Dictionary)->String:
	if selected_item(selection).is_empty():return "The base is protected. Select an editable object."
	var next=data.duplicate(true);next[selection.group].remove_at(int(selection.index));return _commit(next)
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
	var stem=""
	for letter in data.title.to_lower():stem+=letter if letter in "abcdefghijklmnopqrstuvwxyz0123456789-_" else "_"
	stem=stem.left(32)+"-"+data.title.sha256_text().left(8)
	var destination=folder.path_join(stem+".json")
	if destination.begins_with("res://"):return "The bundled original is read-only."
	if DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))!=OK:return "Could not create the map folder."
	var file=FileAccess.open(destination+".tmp",FileAccess.WRITE)
	if file==null:return "Could not save this map."
	file.store_string(encode());file.flush();var result=file.get_error();file.close()
	if result!=OK:return "Could not finish writing the map."
	if DirAccess.rename_absolute(ProjectSettings.globalize_path(destination+".tmp"),ProjectSettings.globalize_path(destination))!=OK:return "Could not replace the saved map."
	path=destination;saved_text=encode();return ""
static func list_maps(folder: String=MAP_FOLDER)->Array:
	var result=[]
	if not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(folder)):return result
	for filename in DirAccess.get_files_at(folder):
		if filename.get_extension()!="json":continue
		var document=load("res://scripts/forest/forest_map_document.gd").new()
		if document.read_file(folder.path_join(filename)).is_empty():result.append({"title":document.data.title,"path":folder.path_join(filename)})
	result.sort_custom(func(a,b):return a.title.naturalnocasecmp_to(b.title)<0)
	return result
