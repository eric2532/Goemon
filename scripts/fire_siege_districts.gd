extends RefCounted
## Static district geometry, batched by material and 72-metre cell.
var world: Node3D
var batches: Dictionary={}
var materials: Dictionary={}
var shapes: Dictionary={}
var paths: Array=[]
var box_mesh=BoxMesh.new()
static func build(field: Node3D)->void:
	var builder=load("res://scripts/fire_siege_districts.gd").new()
	builder.world=field;builder.construct()
func box(p: Vector3,size: Vector3,color: String,emission: float=0,angle: float=0)->void:
	var key="%s_%s_%d_%d" % [color,emission,floori(p.x/72),floori(p.z/72)]
	if not batches.has(key):batches[key]={"mesh":box_mesh,"material":material(color,emission),"transforms":[]}
	batches[key].transforms.append(Transform3D(Basis(Vector3.UP,angle).scaled(size),p))
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
	path([Vector3(0,0,220),Vector3(-30,0,220),Vector3(-30,0,245),Vector3(-95,0,245),Vector3(-95,0,210)])
	path([Vector3(-95,0,210),Vector3(-120,0,185),Vector3(-125,0,245),Vector3(-95,0,245)],6,"4d3c54")
	path([Vector3(0,0,220),Vector3(30,0,220),Vector3(30,0,245),Vector3(95,0,245),Vector3(95,0,240)])
	path([Vector3(95,0,240),Vector3(105,0,252),Vector3(85,0,252),Vector3(85,0,240)],5,"353d56")
	for side in [-1,1]:path([Vector3(side*30,0,245),Vector3(side*40,0,300),Vector3(side*40,0,365),Vector3(0,0,400)],7,"39444f")
	path([Vector3(0,0,400),Vector3(-30,0,420),Vector3(0,0,445),Vector3(30,0,420),Vector3(0,0,400)],6,"455350")
	world.set_meta("exploration_paths",paths)
	var kit=load("res://scripts/map_pieces.gd")
	var pavilion=kit.build(world,"pavilion",true);pavilion.position=Vector3(-105,0,215)
	var torii=kit.build(world,"torii",true);torii.position=Vector3(-65,0,245);torii.rotation.y=PI/2
	for p in [Vector3(70,0,215),Vector3(95,0,210),Vector3(120,0,215),Vector3(70,0,265),Vector3(95,0,280),Vector3(120,0,265),Vector3(140,0,240)]:house(p)
	for p in [Vector3(-38,0,391),Vector3(38,0,391),Vector3(-38,0,425),Vector3(38,0,425)]:
		box(p+Vector3.UP*1.8,Vector3(8,3.6,2),"465568");solid(p+Vector3.UP*1.8,Vector3(8,3.6,2))
		box(p+Vector3.UP*3.65,Vector3(8.4,.25,2.4),"263345")
	var watch=kit.build(world,"pavilion",true);watch.position=Vector3(0,0,424)
	for item in [["grove",Vector3(-95,0,210),"SAKURA GROVE","d99ad0"],["village",Vector3(95,0,240),"NEON VILLAGE","65e9ee"],["watchpost",Vector3(0,0,400),"RUINED WATCHPOST","e4c593"]]:
		world._world_label(item[2],item[1]+Vector3.UP*9,Color(item[3]),.027)
		cache(item[0],item[1],item[3])
	woodland()
	flush()
func house(p: Vector3)->void:
	box(p+Vector3.UP*2.2,Vector3(10,4.4,8),"322e46");solid(p+Vector3.UP*2.2,Vector3(10,4.4,8))
	box(p+Vector3.UP*4.6,Vector3(12,.6,10),"202b41")
	box(p+Vector3(0,4.9,-5),Vector3(12,.08,.08),"d875b5",1.25)
	for x in [-3,0,3]:
		box(p+Vector3(x,2.5,-4.04),Vector3(2.2,2.2,.08),"78b7cd",.4)
		for offset in [-.7,0,.7]:box(p+Vector3(x+offset,2.5,-4.11),Vector3(.06,2.3,.09),"403850")
		box(p+Vector3(x,2.5,-4.12),Vector3(2.3,.07,.08),"403850")
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
