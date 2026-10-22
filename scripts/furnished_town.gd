class_name FurnishedTown
extends Node3D
const BUILDING_SCALE=1.5
const IDS=["machiya_open","inn","tea_house_open","warehouse","shrine","gatehouse"]
var world
var rooms: Array=[]
var indoor=false
var camera_exclusions: Array[RID]=[]

static func plan(world):
	world.furnished_districts.clear();world.furnished_lots.clear();world.furnished_cells.clear()
	for x in [-420,420]:
		for z in [-120,-330,-540,-750,-910]:world.furnished_districts.append(Vector3(x,world.raw_height(x,z),z))
	for x in [-210,0,210]:
		for z in [-600,-850]:world.furnished_districts.append(Vector3(x,world.raw_height(x,z),z))
	var layout_rng=RandomNumberGenerator.new();layout_rng.seed=world.generation_seed+211
	if world.descent_mode:
		for i in world.furnished_districts.size():
			var point=world.furnished_districts[i]+Vector3(layout_rng.randf_range(-40,40),0,layout_rng.randf_range(-22,22))
			point.x=clampf(point.x,world.playable_bounds.position.x+46,world.playable_bounds.end.x-46)
			point.z=clampf(point.z,world.playable_bounds.position.y+42,world.playable_bounds.end.y-42)
			point.y=world.raw_height(point.x,point.z);world.furnished_districts[i]=point
	for district in world.furnished_districts:
		var district_pad={"point":district,"rect":Rect2(Vector2(district.x-48,district.z-34),Vector2(96,68))}
		var pad=district_pad.rect.grow(6)
		for gx in range(floori(pad.position.x/32),floori(pad.end.x/32)+1):
			for gz in range(floori(pad.position.y/32),floori(pad.end.y/32)+1):
				var key=Vector2i(gx,gz)
				if not world.furnished_cells.has(key):world.furnished_cells[key]=[]
				world.furnished_cells[key].append(district_pad)
		for i in range(6):
			var point=district+Vector3((i%3-1)*26,0,-22 if i<3 else 22)
			world.furnished_lots.append({"point":point,"angle":0.0 if i<3 else PI,"id":IDS[i],"rect":Rect2(Vector2(point.x-13.5,point.z-13.5),Vector2(27,27))})

static func level_lots(world,x: float,z: float,height: float)->float:
	var point=Vector2(x,z)
	for lot in world.furnished_cells.get(Vector2i(floori(x/32),floori(z/32)),[]):
		var rect: Rect2=lot.rect
		var nearest=Vector2(clampf(x,rect.position.x,rect.end.x),clampf(z,rect.position.y,rect.end.y))
		var distance=point.distance_to(nearest)
		if distance<6:return lerpf(lot.point.y,height,smoothstep(0,6,distance))
	return height

static func cv(v)->Vector3:return Vector3(v[0],v[2],-v[1])

func _ready():
	name="FurnishedDistricts"
	var metadata=JSON.parse_string(FileAccess.get_file_as_string("res://assets/models/cedar_pass/interiors.json"))
	for lot in world.furnished_lots:
		var data=metadata[lot.id]
		var root=GameAssets.place(self,"cedar_pass/"+lot.id,lot.point,Vector3.ONE*BUILDING_SCALE)
		root.rotation.y=lot.angle
		var meshes={};var bodies={}
		for mesh in root.find_children("*","MeshInstance3D",true,false):
			mesh.material_override=preload("res://assets/models/cedar_pass/shared_matte.tres")
			mesh.visibility_range_end=90 if "Furniture" in String(mesh.name) or "Interior" in String(mesh.name) else 420
			mesh.visibility_range_end_margin=15
			meshes[String(mesh.name).trim_prefix("CP_")]=mesh
		for c in data.colliders:
			var body=StaticBody3D.new();body.name="Collision_"+c.name;body.collision_layer=1;body.collision_mask=2|4;root.add_child(body)
			var node=CollisionShape3D.new();body.add_child(node)
			if c.type=="box":
				var shape=BoxShape3D.new();shape.size=cv(c.size_blender).abs();node.shape=shape;body.position=cv(c.position_blender)
			else:
				var shape=ConvexPolygonShape3D.new();var points=PackedVector3Array()
				for vertex in c.vertices_blender:points.append(cv(vertex))
				shape.points=points;node.shape=shape
			if not bodies.has(c.group):bodies[c.group]=[]
			bodies[c.group].append(body)
		for point in data.lights_blender:
			var light=OmniLight3D.new();light.position=cv(point);light.light_color=Color("ffdba5");light.light_energy=.35;light.omni_range=5;light.shadow_enabled=false;light.distance_fade_enabled=true;light.distance_fade_begin=45;light.distance_fade_length=15;root.add_child(light)
		BreakableBuilding.attach(root,world)
		rooms.append({"root":root,"data":data,"meshes":meshes,"bodies":bodies,"hidden":false})
	for district in world.furnished_districts:
		var nearest=world.outposts[0]
		for court in world.outposts:
			if court.distance_squared_to(district)<nearest.distance_squared_to(district):nearest=court
		WorldExpansion.path(world,nearest,district)
		WorldExpansion.path(world,district+Vector3(-44,0,0),district+Vector3(44,0,0))
		Geo.box(self,district+Vector3.UP*.03,Vector3(96,.08,18),EdoEnvironment.surface("sand"))
		for x in [-26,0,26]:
			for z in [-12,12]:Geo.box(self,district+Vector3(x,.04,z),Vector3(4,.08,10),EdoEnvironment.surface("sand"))
		for x in [-44,44]:
			for z in [-28,28]:
				var tree=GameAssets.place(self,"cedar_pass/"+("sakura" if z<0 else "cloud_pine"),district+Vector3(x,0,z))
				for mesh in tree.find_children("*","MeshInstance3D",true,false):mesh.material_override=preload("res://assets/models/cedar_pass/shared_matte.tres")
			for z in [-7,7]:
				var lantern=GameAssets.place(self,"cedar_pass/lantern",district+Vector3(x,0,z))
				for mesh in lantern.find_children("*","MeshInstance3D",true,false):mesh.material_override=preload("res://assets/models/cedar_pass/shared_matte.tres")


func update_cutaway(point: Vector3,yaw: float):
	indoor=false;camera_exclusions.clear()
	for room in rooms:
		if room.root.get_meta("destroyed",false):continue
		# Avoid inverse transforms for rooms far above/below or across the map.
		if not room.hidden and room.root.global_position.distance_squared_to(point)>32*32:continue
		var local=room.root.to_local(point);var data=room.data
		var inside=absf(local.x)<data.body_width/2+.1 and absf(local.z)<data.body_depth/2+1.3 and local.y>-.5 and local.y<9
		if not inside and not room.hidden:continue
		var hidden=[]
		if inside:
			indoor=true;hidden=["Roof"]
			var angle=yaw-room.root.rotation.y
			if cos(angle)>=-.15:hidden.append("Wall_Front")
			if cos(angle)<.15:hidden.append("Wall_Back")
			if sin(angle)>.15:hidden.append("Wall_Right")
			if sin(angle)<-.15:hidden.append("Wall_Left")
			if data.id=="inn" and local.y<2.2:hidden.append_array(["UpperFloor","UpperFurniture"])
		for group in room.meshes:room.meshes[group].visible=not group in hidden and not room.meshes[group].get_meta("damage_hidden",false)
		for group in hidden:
			for body in room.bodies.get(group,[]):camera_exclusions.append(body.get_rid())
		room.hidden=inside
