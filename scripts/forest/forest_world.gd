extends Sanctuary
const Art=preload("res://scripts/forest/forest_art.gd")
var model
var structure_nodes: Dictionary={}
var worker_nodes: Dictionary={}
var deposit_nodes: Dictionary={}
var fog_materials: Array=[]
var fog_texture: ImageTexture
var ground_material: ShaderMaterial
var revision=-1
var vision_clock=0.0
var rally_ring: MeshInstance3D
var preview: Node3D
var preview_mesh: MeshInstance3D
var ghost_art: Node3D
var ghost_kind=""
var ghost_rotation=-1
var ghost_material: StandardMaterial3D
var sight_ring: MeshInstance3D
var age=0.0
func _ready():
	descent_mode=false;playable_bounds=Rect2(-168,-168,336,336);spawn_point=Vector3(0,.1,18)
	landmarks={"THE FOREST SHRINE":Vector3.ZERO}
	var image=Image.create(80,80,false,Image.FORMAT_RGBA8);image.fill(Color.BLACK)
	fog_texture=ImageTexture.create_from_image(image)
	var environment_=WorldEnvironment.new();var env=Environment.new()
	env.background_mode=Environment.BG_COLOR;env.background_color=Color("24392f")
	env.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.ambient_light_color=Color("c3d9c7");env.ambient_light_energy=.65
	env.tonemap_mode=Environment.TONE_MAPPER_FILMIC;environment_.environment=env;add_child(environment_)
	var sun=DirectionalLight3D.new();sun.rotation_degrees=Vector3(-52,-35,0);sun.light_color=Color("ffe2b5");sun.light_energy=1.5;sun.shadow_enabled=true;sun.directional_shadow_max_distance=190;add_child(sun)
	ground_material=fog_material(Color("839956"),true)
	Geo.box(self,Vector3(-3,-.3,-3),Vector3(480,.6,480),ground_material)
	Art.solid(self,Vector3(0,-1,0),Vector3(500,2,500))
	make_forest()
	for cell in model.deposits:
		var node=Node3D.new();add_child(node);node.position=model.point(cell)+Vector3(6,0,3)
		for i in range(5):
			var p=Vector3((i%3-1)*3,1.1,i/3*3-1.5)
			Geo.sphere(node,p,Vector3(4,3,3.5),Geo.mat("818478"))
			Geo.spike(node,p+Vector3(0,1,.8),p+Vector3(.6,3.1,1),.6,Geo.mat("e7bb5b",.3,.2))
		Art.label(node,"GOLD DEPOSIT",5.3);deposit_nodes[cell]=node
	rally_ring=Geo.torus(self,Vector3.ZERO,29.8,30.05,Geo.mat("f4cf78",0,.6));rally_ring.hide()
	preview=Node3D.new();add_child(preview)
	var material=StandardMaterial3D.new();material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;material.albedo_color=Color(.4,.9,.65,.28)
	preview_mesh=Geo.box(preview,Vector3(0,.16,0),Vector3(6,.2,6),material)
	ghost_material=material.duplicate();ghost_material.albedo_color.a=.35
	sight_ring=Geo.torus(preview,Vector3(0,.12,0),5.95,6.05,Geo.mat("d9c386",0,.3));preview.hide()
	sync(0)
func height_at(_x: float,_z: float)->float:return 0.0
func raw_height(_x: float,_z: float)->float:return 0.0
func surface_height_at(_p: Vector3)->float:return 0.0
func _process(_delta):pass
func fog_material(color: Color,ground_: bool=false)->ShaderMaterial:
	var mat=ShaderMaterial.new();mat.shader=preload("res://scripts/forest/forest_fog.gdshader")
	mat.set_shader_parameter("visibility_map",fog_texture);mat.set_shader_parameter("base_color",color)
	mat.set_shader_parameter("ground_surface",ground_);mat.set_shader_parameter("hide_unknown",not ground_)
	fog_materials.append(mat);return mat
func make_forest():
	var layers=[]
	for i in range(4):
		var mesh=CylinderMesh.new();mesh.radial_segments=7;mesh.rings=1
		mesh.bottom_radius=.55 if i==0 else 4.7-i*.55;mesh.top_radius=.42 if i==0 else .1
		mesh.height=11 if i==0 else 7.5
		var batch=MultiMeshInstance3D.new();batch.multimesh=MultiMesh.new();batch.multimesh.transform_format=MultiMesh.TRANSFORM_3D
		batch.multimesh.mesh=mesh;batch.multimesh.instance_count=model.trees.size()
		batch.material_override=fog_material(Color(["66513b","284c3a","366346","497553"][i]));add_child(batch);layers.append(batch)
		batch.material_override.set_shader_parameter("canopy_layer",i>0)
	var index=0
	for cell in model.trees:
		var scale_: float=model.trees[cell]
		for i in range(4):
			var height=5.5 if i==0 else 5+i*3.5
			var transform=Transform3D(Basis.IDENTITY.scaled(Vector3.ONE*scale_),model.point(cell)+Vector3(0,height*scale_,0))
			layers[i].multimesh.set_instance_transform(index,transform)
		Art.solid(self,model.point(cell)+Vector3.UP*4,Vector3(2.5,8,2.5))
		index+=1
func update_fog():
	var image=Image.create(80,80,false,Image.FORMAT_RGBA8);image.fill(Color(0,0,0,1))
	for cell in model.explored:image.set_pixel(cell.x+40,cell.y+40,Color(1,1 if model.visible_cells.has(cell) else 0,0,1))
	fog_texture.update(image)
	ground_material.set_shader_parameter("show_grid",model.phase=="preparing")
	for cell in deposit_nodes:deposit_nodes[cell].visible=model.explored.has(cell) and not model.occupancy.has(cell)
	for deposit in deposit_nodes.values():
		for label_ in deposit.find_children("*","Label3D",false,false):label_.pixel_size=.045 if model.phase=="preparing" else .026
func show_preview(kind: String,cell: Vector2i,rotation_: int,valid: bool):
	if kind.is_empty():preview.hide();return
	if ghost_kind!=kind or ghost_rotation!=rotation_:
		if is_instance_valid(ghost_art):ghost_art.queue_free()
		ghost_art=Art.building({"id":-1,"kind":kind,"rotation":rotation_});preview.add_child(ghost_art)
		for body in ghost_art.find_children("*","StaticBody3D",true,false):
			body.collision_layer=0;body.collision_mask=0
		for mesh in ghost_art.find_children("*","MeshInstance3D",true,false):mesh.material_override=ghost_material;mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		ghost_kind=kind;ghost_rotation=rotation_
	preview.show();ghost_art.show();sight_ring.show();var size_=model.dimensions(kind,rotation_)
	preview.position=model.point(cell)+Vector3(size_.x-1,0,size_.y-1)*3
	preview_mesh.mesh.size=Vector3(size_.x*6,.2,size_.y*6)
	preview_mesh.material_override.albedo_color=Color(.43,.88,.65,.38) if valid else Color(.92,.31,.21,.45)
	ghost_material.albedo_color=Color(.43,.88,.65,.4) if valid else Color(.92,.31,.21,.4)
	sight_ring.scale=Vector3.ONE*model.SIGHT[kind]
func sync(delta: float):
	age+=delta
	if revision!=model.revision:
		for id in structure_nodes.keys():
			if not model.buildings.has(id):structure_nodes[id].queue_free();structure_nodes.erase(id)
		for b in model.buildings.values():
			if not structure_nodes.has(b.id):
				var node=Art.building(b);add_child(node);node.position=model.center(b);structure_nodes[b.id]=node
				Art.label(node,{"shrine":"FOREST SHRINE","mine":"GOLD MINE","tower":"WATCHTOWER","wall":"","gate":"GATE"}[b.kind],16 if b.kind in ["shrine","tower"] else 6)
				var health=Geo.box(node,Vector3(0,15 if b.kind in ["shrine","tower"] else 5,0),Vector3(5,.25,.35),Geo.mat("d7b65f",0,.3));health.name="Health"
		for w in model.workers.values():
			if not worker_nodes.has(w.id):var node=Art.worker(w.id);add_child(node);worker_nodes[w.id]=node
		revision=model.revision;update_fog()
	for b in model.buildings.values():
		var health=structure_nodes[b.id].get_node("Health");health.visible=b.hp<b.max_hp;health.scale.x=maxf(.01,b.hp/b.max_hp)
		for label_ in structure_nodes[b.id].find_children("*","Label3D",false,false):label_.pixel_size=.045 if model.phase=="preparing" else .026
		if b.kind=="gate":
			var open_=model.hero_position.distance_to(model.center(b))<10
			for w in model.workers.values():
				if w.state!="wounded" and w.pos.distance_to(model.center(b))<10:open_=true
			var door=structure_nodes[b.id].get_node("GateDoor")
			door.position.y=lerpf(door.position.y,6.5 if open_ else 2.4,minf(1,delta*6))
	for w in model.workers.values():
		var node: Node3D=worker_nodes[w.id];var offset=Vector3.UP*(8.8 if w.state=="garrison" else w.get("deck_height",0.0))
		var move_: Vector3=w.pos-node.position+offset
		if Vector2(move_.x,move_.z).length()>.015:node.rotation.y=atan2(move_.x,move_.z)
		node.position=w.pos+offset;node.rotation.z=PI*.5 if w.state=="wounded" else 0.0
		node.get_node("Cargo").visible=w.cargo>0
		node.get_node("Selected").visible=w.follow
		node.get_node("Bow").visible=w.state=="garrison"
		var moving=w.state in ["follow","travel","deliver","move","retreat"]
		for side in ["L","R"]:
			var amount=sin(age*9+w.id)*(1 if side=="L" else -1)*.55 if moving else 0.0
			node.get_node("Leg"+side).rotation.x=amount
			node.get_node("Arm"+side).rotation.x=-amount if w.state not in ["repair","mine"] else sin(age*6)*.8
	vision_clock-=delta
	for material in fog_materials:
		material.set_shader_parameter("hero_position",Vector2(model.hero_position.x,model.hero_position.z))
		material.set_shader_parameter("canopy_cutaway",model.phase=="wave")
	if vision_clock<=0:update_fog();vision_clock=.2
	rally_ring.visible=model.workforce!=null and model.workforce.held and model.phase=="wave"
	rally_ring.position=Vector3(model.hero_position.x,.15,model.hero_position.z)

func show_wall_preview(cells: Array,valid: bool):
	if cells.is_empty():return
	preview.show();sight_ring.hide()
	if is_instance_valid(ghost_art):ghost_art.hide()
	var first=model.point(cells.front());var last=model.point(cells.back())
	preview.position=(first+last)*.5
	var vertical=absf(last.z-first.z)>absf(last.x-first.x)
	preview_mesh.mesh.size=Vector3(1.3 if vertical else absf(last.x-first.x)+6,3.5,absf(last.z-first.z)+6 if vertical else 1.3)
	preview_mesh.material_override.albedo_color=Color(.43,.88,.65,.38) if valid else Color(.92,.31,.21,.45)
