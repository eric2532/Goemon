class_name TidefallTown
extends Node3D
## Enlarged main-area town. Reserved original routes/courts remain unobstructed.
var world
var buildings: Array[Node3D]=[]
var footprints: Array[Rect2]=[]
var streets: Array=[]
const BUILDING_SCALE=4.0
const TARGET_COUNT=48
const HEIGHTS={"timber_house":5.6,"noren_shop":4.4,"corner_house":5.6,"plaster_storehouse":4.4,"two_story_inn":6.7,"open_teahouse":4.4}
const OPEN_LOTS=[Vector2(-40,35),Vector2(-116,14),Vector2(62,18)]
const OPEN_ANGLES=[PI/2,PI/2,-PI/2]
const OPEN_NAMES=["Tea House","Travelers' Hall","Merchant House"]
static func footprint(p: Vector2)->Rect2:return Rect2(p-Vector2(12,16),Vector2(24,32))
static func original_routes(world=null)->Array:
	var routes=[[Vector2(0,44),Vector2(-8,-29),4.8],[Vector2(-4,-8),Vector2(16,-8),4.0],[Vector2(32,-8),Vector2(45,-36),4.0],[Vector2(-7,8),Vector2(-43,-5),3.0],[Vector2(-43,-5),Vector2(-23,-36),3.0]]
	for side in [-1,1]:
		routes.append([Vector2(side*43,-24),Vector2(side*76,-51),5.5])
		routes.append([Vector2(side*76,-51),Vector2(side*38,-81),5.5])
		routes.append([Vector2(side*38,-81),Vector2(-10,-56),5.5])
	if world:
		for route in world.outer_routes:routes.append([Vector2(route[0].x,route[0].z),Vector2(route[1].x,route[1].z),7.0])
	return routes
static func safe_lot(p: Vector2,existing: Array,world)->bool:
	var rect=footprint(p)
	if not world.playable_bounds.grow(-7).encloses(rect.grow(3)):return false
	for item in existing:
		if absf(p.x-item[0].x)<36 and absf(p.y-item[0].y)<42:return false
	var circles=[[Vector2(-10,-37),20.0],[Vector2(-44,-5),17.0],[Vector2(45,-40),14.0],[Vector2(-76,-51),14.0],[Vector2(76,-51),14.0],[Vector2(0,41),19.0]]
	for point in world.outposts:
		circles.append([Vector2(point.x,point.z),29.0]);circles.append([Vector2(point.x,point.z-34),12.0])
	for circle in circles:
		var nearest=Vector2(clampf(circle[0].x,rect.position.x,rect.end.x),clampf(circle[0].y,rect.position.y,rect.end.y))
		if nearest.distance_to(circle[0])<circle[1]+3:return false
	for route in original_routes(world):
		var reserved=rect.grow(route[2]*.5+4)
		var steps=ceili(route[0].distance_to(route[1])/2)
		for i in range(steps+1):
			if reserved.has_point(route[0].lerp(route[1],float(i)/steps)):return false
	return true
static func layout(world)->Array:
	var result=[]
	for i in OPEN_LOTS.size():result.append([OPEN_LOTS[i],OPEN_ANGLES[i],"open_teahouse","tidefall-open-%02d" % (i+1)])
	var kinds=["timber_house","noren_shop","corner_house","plaster_storehouse","two_story_inn"]
	var index=0
	if world.descent_mode:
		var layout_rng=RandomNumberGenerator.new();layout_rng.seed=world.generation_seed+307
		# Rejection sampling preserves courts, entrance clearances and main routes.
		for attempt in range(4000):
			var p=Vector2(layout_rng.randf_range(-275,275),layout_rng.randf_range(-465,35))
			if not safe_lot(p,result,world):continue
			result.append([p,PI/2 if p.x<0 else -PI/2,kinds[layout_rng.randi_range(0,kinds.size()-1)],"tidefall-building-%02d" % (index+1)])
			index+=1
			if result.size()>=TARGET_COUNT:return result
		return result
	for z in [40,-8,-56,-104,-152,-200,-248,-296,-344,-392]:
		for x in [-40,62,-100,122,-160,182,-220,242,-268]:
			var p=Vector2(x,z)
			if safe_lot(p,result,world):
				result.append([p,PI/2 if x<0 else -PI/2,kinds[index%kinds.size()],"tidefall-building-%02d" % (index+1)])
				index+=1
				if result.size()>=TARGET_COUNT:return result
	# Two closer residential lots fill the town after the large district grid.
	for p in [Vector2(-76,8),Vector2(-124,-40)]:
		if safe_lot(p,result,world):
			result.append([p,PI/2,kinds[index%kinds.size()],"tidefall-building-%02d" % (index+1)]);index+=1
	return result
static func level_open_lots(world,x: float,z: float,h: float)->float:
	# Only three interior lots and their 6m entrance transition are leveled.
	for i in OPEN_LOTS.size():
		var rect=footprint(OPEN_LOTS[i]);var point=Vector2(x,z)
		if not rect.grow(6).has_point(point):continue
		var door=OPEN_LOTS[i]+Vector2(12 if OPEN_ANGLES[i]>0 else -12,0)
		var floor_y=WorldExpansion.flatten(world,door.x,door.y,world.raw_height(door.x,door.y))
		var nearest=Vector2(clampf(x,rect.position.x,rect.end.x),clampf(z,rect.position.y,rect.end.y))
		return lerpf(floor_y,h,smoothstep(0,6,point.distance_to(nearest)))
	return h
func _ready():
	name="TidefallTown";assert(world.area_index==0)
	for item in layout(world):place_building(item[0],item[1],item[2],item[3])
	street(Vector2(-2,53),Vector2(-2,-355),26)
	for x in [-70,-130,-190,-250,92,152,212,272]:street(Vector2(x,45),Vector2(x,-355),14)
	for z in [17,-32,-80,-128,-176,-224,-272,-320]:street(Vector2(-276,z),Vector2(276,z),9)
	# Hide only dressing inside new house footprints; clear its collision for usable interiors.
	for child in world.get_children():
		if child==self or not child is Node3D:continue
		if contains_body(Vector2(child.position.x,child.position.z)):
			if child.scene_file_path.contains("/edo/") or (child is MeshInstance3D and child.mesh.get_aabb().size.length()<16):
				child.hide();disable_collision(child)
		if child is MultiMeshInstance3D and child.multimesh.instance_count in [3400,360]:
			for i in child.multimesh.instance_count:
				var t=child.multimesh.get_instance_transform(i)
				if contains_body(Vector2(t.origin.x,t.origin.z)) or (child.multimesh.instance_count==3400 and contains_street(Vector2(t.origin.x,t.origin.z))):
					t.origin.y-=12;child.multimesh.set_instance_transform(i,t)
	TownProps.add_to(self)
func disable_collision(node: Node):
	if node is CollisionShape3D:node.disabled=true
	for child in node.get_children():disable_collision(child)
func contains_street(p: Vector2)->bool:
	for road in streets:
		if Geometry2D.get_closest_point_to_segment(p,road[0],road[1]).distance_to(p)<road[2]*.5:return true
	return false
func contains_body(p: Vector2)->bool:
	for rect in footprints:
		if rect.has_point(p):return true
	return false
func place_building(p: Vector2,angle: float,kind: String,building_id: String):
	var rect=footprint(p);footprints.append(rect)
	var y=-INF
	for dx in [-12,12]:
		for dz in [-16,16]:y=maxf(y,world.height_at(p.x+dx,p.y+dz))
	if kind=="open_teahouse":y=world.height_at(p.x,p.y)
	var house=Node3D.new();house.name=building_id;add_child(house)
	house.position=Vector3(p.x,y,p.y);house.rotation.y=angle
	var visual=GameAssets.place(house,"town/"+kind,Vector3.ZERO,Vector3.ONE*BUILDING_SCALE);visual.name="BuildingVisual"
	house.set_meta("town_variant",kind);house.set_meta("footprint",rect);house.set_meta("building_scale",BUILDING_SCALE)
	house.set_meta("enterable",kind=="open_teahouse");buildings.append(house)
	if kind=="open_teahouse":
		GameAssets.collision_for(visual)
		var index=OPEN_LOTS.find(p);house.set_meta("interior_name",OPEN_NAMES[index])
		var sign=Label3D.new();sign.text=OPEN_NAMES[index];sign.font_size=48;sign.pixel_size=.016
		sign.position=Vector3(0,11,12.3);house.add_child(sign)
		var light=OmniLight3D.new();light.name="InteriorLanternLight";light.position=Vector3(0,5,0)
		light.light_color=Color("ffe6bd");light.light_energy=2.2;light.omni_range=30;light.shadow_enabled=false;house.add_child(light)
		for side in [-1,1]:
			GameAssets.place(house,"town_props/paper_lantern",Vector3(side*6,3.6,0))
			Geo.beam(house,Vector3(side*6,4,0),Vector3(side*6,16.6,0),.025,EdoEnvironment.material("735344"))
		BreakableBuilding.attach(house,world)
		return
	var body=StaticBody3D.new();body.name="ClosedBuildingCollision";house.add_child(body)
	var shape=CollisionShape3D.new();var box=BoxShape3D.new()
	box.size=Vector3(8,HEIGHTS[kind]+2,6)*BUILDING_SCALE
	shape.shape=box;shape.position.y=(HEIGHTS[kind]-2)*BUILDING_SCALE/2;body.add_child(shape)
	GameAssets.collision_for(visual.find_child("Roof",true,false))
	BreakableBuilding.attach(house,world)
func street(a: Vector2,b: Vector2,width: float):
	streets.append([a,b,width])
	var side=(b-a).orthogonal().normalized()*width*.5
	var count=ceili(a.distance_to(b)/3)
	var st=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(count):
		var p=a.lerp(b,float(i)/count);var q=a.lerp(b,float(i+1)/count)
		var across=ceili(width/3)
		for j in range(across):
			var left=side*lerpf(-1,1,float(j)/across);var right=side*lerpf(-1,1,float(j+1)/across)
			for v in [p+left,p+right,q+left,p+right,q+right,q+left]:st.add_vertex(Vector3(v.x,world.height_at(v.x,v.y)+.095,v.y))
	st.generate_normals()
	var paving=Geo.mesh(self,st.commit(),Vector3.ZERO,EdoEnvironment.surface("sand"));paving.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
