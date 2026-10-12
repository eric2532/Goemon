extends RefCounted
## Static district geometry, batched by material and 72-metre cell.
var world: Node3D
var batches: Dictionary={}
var materials: Dictionary={}
var shapes: Dictionary={}
var paths: Array=[]
var box_mesh=BoxMesh.new()
var building_lots: Array[Vector3]=[]
static func build(field: Node3D)->void:
	var builder=load("res://scripts/fire_siege_districts.gd").new()
	builder.world=field;builder.construct()
func box(p: Vector3,size: Vector3,color: String,emission: float=0,angle: float=0)->void:
	var key="%s_%s_%d_%d" % [color,emission,floori(p.x/72),floori(p.z/72)]
	if not batches.has(key):batches[key]={"mesh":box_mesh,"material":material(color,emission),"transforms":[]}
	batches[key].transforms.append(Transform3D(Basis(Vector3.UP,angle).scaled_local(size),p))
func material(color: String,emission: float=0)->Material:
	var key=color+str(emission)
	if not materials.has(key):materials[key]=Geo.mat(color,.08,emission)
	return materials[key]
func solid(p: Vector3,size: Vector3)->void:
	var key=Vector2i(floori(p.x/72),floori(p.z/72))
	if not shapes.has(key):
		var body=StaticBody3D.new();body.collision_layer=1;body.collision_mask=0;body.name="DistrictCollision";world.add_child(body);shapes[key]=body
	var node=CollisionShape3D.new();var shape=BoxShape3D.new();shape.size=size;node.shape=shape;node.position=p;shapes[key].add_child(node)
func path(points: Array,width: float=7,color: String="414457")->void:
	paths.append(points)
	for i in range(points.size()-1):
		var a: Vector3=points[i];var b: Vector3=points[i+1]
		box((a+b)*.5+Vector3.UP*.055,Vector3(width,.04,a.distance_to(b)+.6),color,0,atan2(b.x-a.x,b.z-a.z))
func construct()->void:
	box_mesh.size=Vector3.ONE
	box(Vector3(-110,.018,222),Vector3(80,.02,116),"45505a")
	box(Vector3(110,.018,260),Vector3(90,.02,120),"414257")
	box(Vector3(0,.018,440),Vector3(150,.02,112),"354644")
	path([Vector3(0,0,220),Vector3(-30,0,220),Vector3(-30,0,245),Vector3(-95,0,245),Vector3(-95,0,210)])
	path([Vector3(-95,0,210),Vector3(-120,0,185),Vector3(-125,0,245),Vector3(-95,0,245)],6,"4d3c54")
	path([Vector3(0,0,220),Vector3(30,0,220),Vector3(30,0,245),Vector3(95,0,245),Vector3(95,0,240)])
	path([Vector3(95,0,240),Vector3(105,0,252),Vector3(85,0,252),Vector3(85,0,240)],5,"353d56")
	for side in [-1,1]:path([Vector3(side*30,0,245),Vector3(side*40,0,300),Vector3(side*40,0,365),Vector3(0,0,400)],7,"39444f")
	path([Vector3(0,0,400),Vector3(-30,0,420),Vector3(0,0,445),Vector3(30,0,420),Vector3(0,0,400)],6,"455350")
	world.set_meta("exploration_paths",paths)
	japanese_districts()
	for item in [["grove",Vector3(-95,0,210),"SAKURA GROVE","d99ad0"],["village",Vector3(95,0,240),"NEON VILLAGE","65e9ee"],["watchpost",Vector3(0,0,400),"RUINED WATCHPOST","e4c593"]]:
		world._world_label(item[2],item[1]+Vector3.UP*9,Color(item[3]),.027)
		cache(item[0],item[1],item[3])
	woodland()
	flush()
# Imported meshes are flattened into shared material/cell batches at load time.
# Buildings use simple gameplay hulls; dressing has no scripts or dynamic lights.
func asset(id: String,p: Vector3,scale_value: float=1,angle: float=0,weathered: bool=false)->void:
	var model=GameAssets.instantiate_model(id)
	var placement=Transform3D(Basis(Vector3.UP,angle).scaled_local(Vector3.ONE*scale_value),p)
	batch_model(model,placement,weathered)
	model.free()
func batch_model(node: Node,parent_transform: Transform3D,weathered: bool)->void:
	var transform=parent_transform*node.transform if node is Node3D else parent_transform
	if node is MeshInstance3D and node.mesh:
		for surface in range(node.mesh.get_surface_count()):
			var source=node.mesh;var mat=node.get_active_material(surface)
			var key="Asset_%d_%d_%d_%d_%s" % [source.get_instance_id(),surface,floori(transform.origin.x/72),floori(transform.origin.z/72),weathered]
			if not batches.has(key):
				var mesh=ArrayMesh.new();mesh.add_surface_from_arrays(source.surface_get_primitive_type(surface),source.surface_get_arrays(surface))
				if weathered and mat is StandardMaterial3D:
					mat=mat.duplicate();mat.albedo_color*=Color(.55,.62,.62);mat.roughness=1.0
				batches[key]={"mesh":mesh,"material":mat,"transforms":[]}
			batches[key].transforms.append(transform)
	for child in node.get_children():batch_model(child,transform,weathered)
func building(id: String,p: Vector3,angle: float=0)->void:
	building_lots.append(p);asset("town/"+id,p,1.5,angle)
	if id=="open_teahouse":
		# Rear and side walls leave the front porch accessible.
		solid(p+Vector3(0,2.5,-3.3)*1.5,Vector3(8.1,5,.3)*1.5)
		for side in [-1,1]:solid(p+Vector3(side*3.8,2.5,0)*1.5,Vector3(.3,5,6.6)*1.5)
	else:
		var size=Vector3(11.4,8 if id=="two_story_inn" else 6.5,9.3)
		if absf(sin(angle))>.5:size=Vector3(size.z,size.y,size.x)
		solid(p+Vector3.UP*size.y*.5,size)
	# Warm frontage lanterns, cool/magenta neon edges on village roofs.
	var front=Vector3(0,0,5.8).rotated(Vector3.UP,angle)
	asset("town_props/paper_lantern",p+front+Vector3(4,2.4,0).rotated(Vector3.UP,angle))
	if p.x>45:
		box(p+front+Vector3.UP*6.8,Vector3(12,.12,.12),"dc68b0",1.2,angle)
		box(p+front+Vector3.UP*2.9,Vector3(3,.15,.12),"68dfe4",.8,angle)
func japanese_districts()->void:
	var kit=load("res://scripts/map_pieces.gd")
	# Sakura Grove: shrine grounds, an open tea house and timber hamlet.
	for p in [Vector3(-65,0,245),Vector3(-138,0,231)]:
		var gate=kit.build(world,"torii",true);gate.position=p;gate.rotation.y=PI/2 if p.z==245 else 0
	building("open_teahouse",Vector3(-107,0,268))
	for p in [Vector3(-72,0,277),Vector3(-144,0,252),Vector3(-68,0,198)]:building("timber_house",p)
	asset("cedar_pass/shrine",Vector3(-138,0,209),1.2);building_lots.append(Vector3(-138,0,209))
	solid(Vector3(-138,2.4,209),Vector3(7.8,4.8,6.5))
	path([Vector3(-95,0,245),Vector3(-95,0,281),Vector3(-136,0,281)],5,"514458")
	path([Vector3(-125,0,245),Vector3(-125,0,220),Vector3(-138,0,220)],4,"514458")
	# Quiet pond with a timber footbridge and stone banks.
	box(Vector3(-90,.04,177),Vector3(22,.05,14),"315c70",.08)
	box(Vector3(-90,.15,177),Vector3(3,.22,16),"675066")
	for side in [-1,1]:box(Vector3(-90+side*1.7,.75,177),Vector3(.15,.15,16),"725969")
	for p in [Vector3(-102,.2,177),Vector3(-78,.2,177)]:box(p,Vector3(2,.5,16),"656070")
	path([Vector3(-95,0,210),Vector3(-90,0,194),Vector3(-90,0,185)],4,"514458")
	asset("town_props/wayside_shrine",Vector3(-138,0,219),1.2)
	asset("town_props/offering_box",Vector3(-138,0,222))
	discovery("grove_chest",Vector3(-134,0,281),2,"SAKURA GROVE · HIDDEN CHEST · +2 GOLD","d99ad0")
	discovery("grove_lore",Vector3(-138,0,224),0,"FOX ALTAR · Travelers leave bells here to guide lost spirits home.","d99ad0")
	# Neon Village: dense shopfronts with clear market streets and a rear alley.
	for item in [["noren_shop",Vector3(70,0,214),0],["two_story_inn",Vector3(95,0,210),0],["corner_house",Vector3(121,0,214),0],["noren_shop",Vector3(70,0,267),PI],["plaster_storehouse",Vector3(120,0,283),PI],["timber_house",Vector3(120,0,265),PI],["noren_shop",Vector3(141,0,241),-PI/2],["timber_house",Vector3(69,0,296),PI],["plaster_storehouse",Vector3(120,0,307),PI]]:
		building(item[0],item[1],item[2])
	path([Vector3(95,0,252),Vector3(95,0,300),Vector3(103,0,300)],5,"353d56")
	for item in [["noodle_stall",Vector3(76,0,237)],["dumpling_stall",Vector3(121,0,237)]]:
		asset("town_props/"+item[0],item[1],1.7);solid(item[1]+Vector3.UP,Vector3(5,2,2.6))
		asset("town_props/bowl_shop_sign",item[1]+Vector3(3,2.6,0),1.3)
	asset("cedar_pass/well",Vector3(82,0,283),1.2);solid(Vector3(82,1,283),Vector3(3,2,3))
	discovery("village_chest",Vector3(103,0,300),2,"NEON VILLAGE · MERCHANT'S CHEST · +2 GOLD","65e9ee")
	discovery("village_lore",Vector3(95,0,280),0,"LANTERN MARKET · Old shop signs still glow from the shrine's energy.","65e9ee")
	# Ruined Watchpost: damaged walls, storehouses, a gatehouse and lookout.
	for p in [Vector3(-38,0,391),Vector3(38,0,391),Vector3(-38,0,425),Vector3(38,0,425)]:
		box(p+Vector3.UP*1.8,Vector3(8,3.6,2),"465568");solid(p+Vector3.UP*1.8,Vector3(8,3.6,2))
		box(p+Vector3.UP*3.65,Vector3(8.4,.25,2.4),"263345")
	for p in [Vector3(-53,0,385),Vector3(53,0,385),Vector3(-53,0,441),Vector3(53,0,441)]:
		asset("cedar_pass/warehouse",p,1.3,0,true);building_lots.append(p);solid(p+Vector3.UP*3,Vector3(10,6,9))
	asset("cedar_pass/gatehouse",Vector3(0,0,471),1.6,0,true);building_lots.append(Vector3(0,0,471))
	for side in [-1,1]:solid(Vector3(side*8.2,4.5,471),Vector3(5,9,11))
	path([Vector3(0,0,445),Vector3(0,0,485),Vector3(-24,0,485)],6,"455350")
	for side in [-1,1]:
		for z in [414,438]:box(Vector3(side*70,1,z),Vector3(9,2,2),"465568");solid(Vector3(side*70,1,z),Vector3(9,2,2))
	var watch=kit.build(world,"pavilion",true);watch.position=Vector3(0,0,424)
	for x in [66,74]:
		for z in [392,400]:box(Vector3(x,6,z),Vector3(.6,12,.6),"544351");solid(Vector3(x,6,z),Vector3(.6,12,.6))
	box(Vector3(70,9,396),Vector3(9,.5,9),"544351")
	asset("edo/roof",Vector3(70,12,396),1.2);building_lots.append(Vector3(70,0,396))
	discovery("watchpost_chest",Vector3(-24,0,485),2,"RUINED WATCHPOST · GUARD'S CHEST · +2 GOLD","e4c593")
	discovery("watchpost_lore",Vector3(0,0,452),0,"LAST WATCH · The guards held this pass until the shrine's bell fell silent.","e4c593")
	# Garden islands, street goods and overgrowth fill the spaces beside the routes.
	for p in [Vector3(-114,0,220),Vector3(-109,0,289),Vector3(-78,0,260),Vector3(-134,0,195)]:
		box(p+Vector3.UP*.06,Vector3(10,.08,8),"555766")
		asset("cedar_pass/moss_boulder",p+Vector3(-2,0,0),1.1)
		asset("cedar_pass/bamboo_cluster",p+Vector3(3,0,1),1.3)
		for step in range(4):box(p+Vector3(step*1.5-2,.15,-3),Vector3(.8,.2,.8),"bd81a5")
	for p in [Vector3(65,0,247),Vector3(128,0,248),Vector3(78,0,273)]:
		asset("cedar_pass/cart",p,1.1)
		box(p+Vector3(4,.7,0),Vector3(1.6,1.4,1.5),"705367")
	for p in [Vector3(-26,0,390),Vector3(25,0,440),Vector3(-25,0,465),Vector3(35,0,474)]:
		box(p+Vector3.UP*.06,Vector3(9,.08,7),"3d514e")
		asset("cedar_pass/moss_boulder",p,1.5)
		asset("cedar_pass/bamboo_cluster",p+Vector3(3,0,-2),1.5)
		box(p+Vector3(0,.4,2),Vector3(5,.8,1.2),"53615e",0,.25)
	# Repeating lanterns make the return routes readable without extra light sources.
	for route in paths:
		for i in range(route.size()-1):
			var a: Vector3=route[i];var b: Vector3=route[i+1];var direction=(b-a).normalized();var side=direction.cross(Vector3.UP)
			for step in range(1,ceili(a.distance_to(b)/16)):
				asset("town_props/stone_lantern",a+direction*step*16+side*4.7,1.25)
	world.set_meta("exploration_paths",paths)
func discovery(id: String,point: Vector3,reward: int,message: String,color: String)->void:
	var visual=Node3D.new();visual.name="Discovery_"+id;visual.position=point;world.add_child(visual)
	if reward>0:
		Geo.box(visual,Vector3.UP*.4,Vector3(1.4,.8,.9),material("514052"))
		Geo.box(visual,Vector3.UP*.82,Vector3(1.5,.12,1),material(color,.6))
		for x in [-.45,.45]:Geo.box(visual,Vector3(x,.4,-.46),Vector3(.12,.8,.06),material("e5bd80",.25))
	else:
		Geo.box(visual,Vector3.UP*.7,Vector3(.8,1.4,.12),material("594e64"))
		Geo.box(visual,Vector3(0,.8,-.07),Vector3(.5,.7,.03),material(color,.6))
	var label=Label3D.new();label.text="HIDDEN CHEST · +2 GOLD" if reward>0 else "DISCOVER";label.position.y=1.8
	label.font_size=26;label.pixel_size=.013;label.billboard=BaseMaterial3D.BILLBOARD_ENABLED;label.modulate=Color(color);label.visibility_range_end=18;visual.add_child(label)
	world.exploration_discoveries.append({"id":StringName(id),"position":point,"visual":visual,"reward":reward,"message":message})
func cache(id: String,point: Vector3,color: String)->void:
	var visual=Node3D.new();visual.name="SupplyCache_"+id;visual.position=point;world.add_child(visual)
	Geo.box(visual,Vector3.UP*.45,Vector3(1.3,.9,1),material("59475b"))
	Geo.box(visual,Vector3.UP*.93,Vector3(1.4,.08,1.1),material(color,1))
	var ring=Geo.torus(visual,Vector3.UP*.09,1.5,1.58,material(color,1));ring.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var label=Label3D.new();label.text="SUPPLIES · +3 GOLD";label.position.y=2;label.font_size=28;label.pixel_size=.013
	label.billboard=BaseMaterial3D.BILLBOARD_ENABLED;label.modulate=Color(color);label.visibility_range_end=35;visual.add_child(label)
	world.exploration_caches.append({"id":StringName(id),"position":point,"visual":visual})
func near_path(p: Vector3)->bool:
	for route in paths:
		for i in range(route.size()-1):
			if Geometry3D.get_closest_point_to_segment(p,route[i],route[i+1]).distance_squared_to(p)<64:return true
	return false
func woodland()->void:
	var trunk=CylinderMesh.new();trunk.height=1;trunk.bottom_radius=.4;trunk.top_radius=.2;trunk.radial_segments=6
	var leaf=SphereMesh.new();leaf.radius=.5;leaf.height=1;leaf.radial_segments=8;leaf.rings=4
	var rng=RandomNumberGenerator.new();rng.seed=world.generation_seed+901
	var count=0
	for attempt in range(500):
		if count>=140:break
		var p=Vector3(rng.randf_range(-147,147),0,rng.randf_range(70,510))
		if absf(p.x)<36 and p.z<285:continue
		if p.z>180 and p.z<235 and absf(p.x)<88:continue
		if near_path(p):continue
		var near_lot=false
		for lot in building_lots:
			if p.distance_squared_to(lot)<16*16:near_lot=true;break
		if near_lot:continue
		if p.distance_squared_to(Vector3(95,0,240))<55*55:continue
		if p.distance_squared_to(Vector3(0,0,424))<15*15:continue
		var h=rng.randf_range(8,13)
		var cell="%d_%d" % [floori(p.x/72),floori(p.z/72)]
		instance("Trunk_"+cell,trunk,material("443546"),Transform3D(Basis.from_scale(Vector3(1,h,1)),p+Vector3.UP*h*.5))
		var cherry=p.x<-45 and p.z<310
		instance(("Sakura_" if cherry else "Canopy_")+cell,leaf,material("b777af" if cherry else "31494b"),Transform3D(Basis.from_scale(Vector3(9,5,8)),p+Vector3.UP*(h+1)))
		count+=1
	world.set_meta("district_trees",count)
func instance(key: String,mesh: Mesh,mat: Material,t: Transform3D)->void:
	if not batches.has(key):batches[key]={"mesh":mesh,"material":mat,"transforms":[]}
	batches[key].transforms.append(t)
func flush()->void:
	var root=Node3D.new();root.name="ExplorationDistricts";world.add_child(root)
	for key in batches:
		var data=batches[key];var multi=MultiMesh.new();multi.transform_format=MultiMesh.TRANSFORM_3D;multi.mesh=data.mesh;multi.instance_count=data.transforms.size()
		for i in range(data.transforms.size()):multi.set_instance_transform(i,data.transforms[i])
		var node=MultiMeshInstance3D.new();node.name=key;node.multimesh=multi;node.material_override=data.material
		node.visibility_range_end=190;node.visibility_range_end_margin=15;node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;root.add_child(node)
