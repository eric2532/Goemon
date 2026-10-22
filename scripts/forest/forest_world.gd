extends Sanctuary
const Profile=preload("res://scripts/forest/forest_structure_profile.gd")
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
var ghost_foundation_depth=0.0
var ghost_material: StandardMaterial3D
var sight_ring: MeshInstance3D
var age=0.0
var forest_root: Node3D
var deposit_root: Node3D
var map_features: Node3D
var portal_nodes: Array=[]
var painterly_preview_enabled=false
var painterly_pilot
var road_preview: MultiMeshInstance3D
var portal_ghost: Node3D
var base_ground:MeshInstance3D
var base_ground_collision:StaticBody3D
var kai_materials:Array=[]
var blood_gulch_materials:Array=[]
var blood_gulch_environment
func _ready():
	descent_mode=false;playable_bounds=Rect2(-168,-168,336,336);spawn_point=Vector3(0,.1,18)
	landmarks={"THE FOREST SHRINE":Vector3.ZERO}
	var image=Image.create(80,80,false,Image.FORMAT_RGBA8);image.fill(Color.WHITE)
	fog_texture=ImageTexture.create_from_image(image)
	var environment_=WorldEnvironment.new();var env=Environment.new()
	env.background_mode=Environment.BG_COLOR;env.background_color=Color("435e4e")
	env.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.ambient_light_color=Color("c3d9c7");env.ambient_light_energy=.65
	env.tonemap_mode=Environment.TONE_MAPPER_FILMIC;environment_.environment=env;add_child(environment_)
	var sun=DirectionalLight3D.new();sun.rotation_degrees=Vector3(-52,-35,0);sun.light_color=Color("ffe2b5");sun.light_energy=1.5;sun.shadow_enabled=true;sun.directional_shadow_max_distance=190;add_child(sun)
	ground_material=fog_material(Color("839956"),true)
	base_ground=Geo.box(self,Vector3(-3,-.3,-3),Vector3(480,.6,480),ground_material)
	base_ground_collision=Art.solid(self,Vector3(0,-1,0),Vector3(500,2,500),1,"leaves")
	base_ground_collision.set_meta("halo_ground_model",model)
	make_forest()
	make_deposits()
	make_map_features()
	rally_ring=Geo.torus(self,Vector3.ZERO,29.8,30.05,Geo.mat("f4cf78",0,.6));rally_ring.hide()
	preview=Node3D.new();add_child(preview)
	var material=StandardMaterial3D.new();material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;material.albedo_color=Color(.4,.9,.65,.28)
	preview_mesh=Geo.box(preview,Vector3(0,.16,0),Vector3(6,.2,6),material)
	ghost_material=material.duplicate();ghost_material.albedo_color.a=.35
	sight_ring=Geo.torus(preview,Vector3(0,.12,0),5.95,6.05,Geo.mat("d9c386",0,.3));preview.hide()
	sync(0)
	painterly_pilot=preload("res://scripts/forest/forest_painterly_pilot.gd").new(self)
	painterly_pilot.set_enabled(painterly_preview_enabled)
	apply_map_environment()
func apply_map_environment():
	if blood_gulch_environment==null:blood_gulch_environment=preload("res://scripts/forest/blood_gulch_environment.gd").new(self)
	blood_gulch_environment.apply()
func restore_map_environment():
	if blood_gulch_environment!=null:blood_gulch_environment.restore()
func set_painterly_preview(value: bool):
	painterly_preview_enabled=value
	restore_map_environment()
	if painterly_pilot!=null:painterly_pilot.set_enabled(value)
	apply_map_environment()
func make_deposits():
	deposit_root=Node3D.new();deposit_root.name="MapDeposits";add_child(deposit_root)
	for cell in model.deposits:
		var node=Node3D.new();deposit_root.add_child(node);node.position=model.point(cell)+Vector3(6,0,3)
		for i in range(5):
			var p=Vector3((i%3-1)*3,1.1,i/3*3-1.5)
			Geo.sphere(node,p,Vector3(4,3,3.5),Geo.mat("818478"))
			Geo.spike(node,p+Vector3(0,1,.8),p+Vector3(.6,3.1,1),.6,Geo.mat("e7bb5b",.3,.2))
		deposit_nodes[cell]=node
func reload_map():
	restore_map_environment()
	if painterly_pilot!=null:painterly_pilot.restore()
	for nodes in [structure_nodes,worker_nodes]:
		for node in nodes.values():
			remove_child(node);node.queue_free()
		nodes.clear()
	for node in [forest_root,deposit_root,map_features]:
		if is_instance_valid(node):remove_child(node);node.queue_free()
	deposit_nodes.clear();fog_materials=[ground_material]
	make_forest();make_deposits();make_map_features();revision=-1;preview.hide();sync(0);update_fog();apply_map_environment()
func make_portal(portal: Dictionary)->Node3D:
	var root=Node3D.new();root.name="EnemySpawnPortal";root.rotation.y=-int(portal.rotation)*PI*.5
	root.add_child(preload("res://scripts/forest/halo_teleporter.gd").build())
	return root
func make_map_features():
	playable_bounds=Rect2(-234,-234,468,468) if model.has_elevation() else Rect2(-168,-168,336,336)
	if model.terrain_source=="blood_gulch":playable_bounds=Rect2(Vector2(-234,-234)*model.terrain_scale,Vector2(468,468)*model.terrain_scale)
	map_features=Node3D.new();map_features.name="AuthoredMapFeatures";add_child(map_features);portal_nodes.clear()
	kai_materials.clear();blood_gulch_materials.clear()
	var kai=model.terrain_source=="kai_highway"
	var blood_gulch=model.terrain_source=="blood_gulch"
	base_ground.visible=not (kai or blood_gulch);base_ground_collision.collision_layer=0 if kai or blood_gulch else 1
	if kai:preload("res://scripts/forest/forest_kai_highway_art.gd").build(self,map_features)
	if blood_gulch:preload("res://scripts/forest/forest_blood_gulch_art.gd").build(self,map_features)
	preload("res://scripts/forest/forest_rampart_art.gd").build(self,map_features)
	if not model.roads.is_empty():
		var batch=MultiMeshInstance3D.new();batch.name="RoadTiles";batch.multimesh=MultiMesh.new();batch.multimesh.transform_format=MultiMesh.TRANSFORM_3D
		var tile=BoxMesh.new();tile.size=Vector3(6,.05,6);batch.multimesh.mesh=tile;batch.multimesh.use_colors=kai;batch.multimesh.instance_count=model.roads.size();batch.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		batch.material_override=preload("res://scripts/forest/forest_kai_highway_art.gd").road_material(self) if kai else (preload("res://scripts/forest/forest_blood_gulch_art.gd").road_material(self) if blood_gulch else fog_material(Color("af956a")));map_features.add_child(batch)
		var index=0
		for cell in model.roads:
			var p=model.point(cell);var dx=(model.surface_height(p.x+.1,p.z)-model.surface_height(p.x-.1,p.z))/.2;var dz=(model.surface_height(p.x,p.z+.1)-model.surface_height(p.x,p.z-.1))/.2
			var slope=Vector3(-dx,1,-dz).normalized() if absf(dx)<1 and absf(dz)<1 else Vector3.UP
			var basis=Basis(Quaternion(Vector3.UP,slope))
			if absf(dx)>.01 and absf(dx)<1:basis=basis.scaled(Vector3(sqrt(1+dx*dx),1,1))
			if absf(dz)>.01 and absf(dz)<1:basis=basis.scaled(Vector3(1,1,sqrt(1+dz*dz)))
			batch.multimesh.set_instance_transform(index,Transform3D(basis,p+Vector3.UP*.08))
			if kai:batch.multimesh.set_instance_color(index,Color.WHITE if model.terrain.bridge_at(p.x,p.z) else Color(0,1,1))
			index+=1
	for portal in model.portals:
		var node=make_portal(portal);node.position=model.point(Vector2i(portal.x,portal.z));map_features.add_child(node);portal_nodes.append(node)
func height_at(x: float,z: float)->float:return model.surface_height(x,z)
func raw_height(x: float,z: float)->float:return model.surface_height(x,z)
func surface_height_at(p: Vector3)->float:return model.surface_height(p.x,p.z)
func _process(_delta):pass
func fog_material(color: Color,ground_: bool=false)->ShaderMaterial:
	var mat=ShaderMaterial.new();mat.shader=preload("res://scripts/forest/forest_fog.gdshader")
	mat.set_shader_parameter("visibility_map",fog_texture);mat.set_shader_parameter("base_color",color)
	mat.set_shader_parameter("ground_surface",ground_)
	fog_materials.append(mat);return mat
func make_forest():
	forest_root=Node3D.new();forest_root.name="MapForest";add_child(forest_root)
	var layers=[]
	for i in range(4):
		var mesh=CylinderMesh.new();mesh.radial_segments=7;mesh.rings=1
		mesh.bottom_radius=.55 if i==0 else 4.7-i*.55;mesh.top_radius=.42 if i==0 else .1
		mesh.height=11 if i==0 else 7.5
		var batch=MultiMeshInstance3D.new();batch.multimesh=MultiMesh.new();batch.multimesh.transform_format=MultiMesh.TRANSFORM_3D
		batch.multimesh.mesh=mesh;batch.multimesh.instance_count=model.trees.size()
		batch.material_override=fog_material(Color(["66513b","284c3a","366346","497553"][i]));forest_root.add_child(batch);layers.append(batch)
		batch.material_override.set_shader_parameter("canopy_layer",i>0)
	var index=0
	for cell in model.trees:
		var scale_: float=model.trees[cell]
		for i in range(4):
			var height=5.5 if i==0 else 5+i*3.5
			var transform=Transform3D(Basis.IDENTITY.scaled(Vector3.ONE*scale_),model.point(cell)+Vector3(0,height*scale_,0))
			layers[i].multimesh.set_instance_transform(index,transform)
		Art.solid(forest_root,model.point(cell)+Vector3.UP*4,Vector3(2.5,8,2.5),1,"wood")
		index+=1
func update_fog():
	# Visibility texture stays fully white; scouting no longer darkens scenery.
	ground_material.set_shader_parameter("show_grid",model.phase=="preparing")
	for material in kai_materials+blood_gulch_materials:material.set_shader_parameter("show_grid",model.phase=="preparing")
	for cell in deposit_nodes:deposit_nodes[cell].visible=model.explored.has(cell) and not model.occupancy.has(cell)
func building_visual(b:Dictionary)->Dictionary:
	var visual=b.duplicate()
	visual.foundation_depth=model.terrain.foundation_depth(model.footprint(b.kind,b.cell,b.rotation,b.get("span",0)),model.center(b).y)
	return visual
func show_preview(kind: String,cell: Vector2i,rotation_: int,valid: bool):
	if kind.is_empty():preview.hide();return
	preview_mesh.show()
	if is_instance_valid(road_preview):road_preview.hide()
	if is_instance_valid(portal_ghost):portal_ghost.hide()
	var visual=building_visual({"id":-1,"kind":kind,"cell":cell,"rotation":rotation_})
	if ghost_kind!=kind or ghost_rotation!=rotation_ or not is_equal_approx(ghost_foundation_depth,visual.foundation_depth):
		if is_instance_valid(ghost_art):ghost_art.queue_free()
		ghost_art=Art.building(visual);preview.add_child(ghost_art)
		for body in ghost_art.find_children("*","StaticBody3D",true,false):
			body.collision_layer=0;body.collision_mask=0
		for kind_ in ["MeshInstance3D","MultiMeshInstance3D"]:
			for mesh in ghost_art.find_children("*",kind_,true,false):mesh.material_override=ghost_material;mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		ghost_kind=kind;ghost_rotation=rotation_;ghost_foundation_depth=visual.foundation_depth
	preview.show();ghost_art.show();sight_ring.show();var size_=model.dimensions(kind,rotation_)
	preview.position=model.center(visual)
	preview_mesh.mesh.size=Vector3(size_.x*6,.2,size_.y*6)
	preview_mesh.material_override.albedo_color=Color(.43,.88,.65,.38) if valid else Color(.92,.31,.21,.45)
	ghost_material.albedo_color=Color(.43,.88,.65,.4) if valid else Color(.92,.31,.21,.4)
	sight_ring.scale=Vector3.ONE*model.SIGHT[kind]
func show_editor_marker(cell: Vector2i,dimensions: Vector2i,valid: bool,selected: bool=false):
	preview.show();preview_mesh.show();sight_ring.hide()
	if is_instance_valid(road_preview):road_preview.hide()
	if is_instance_valid(portal_ghost):portal_ghost.hide()
	if is_instance_valid(ghost_art):ghost_art.hide()
	preview.position=model.point(cell)+Vector3(dimensions.x-1,0,dimensions.y-1)*3
	preview_mesh.mesh.size=Vector3(dimensions.x*6,.2,dimensions.y*6)
	preview_mesh.material_override.albedo_color=Color(.95,.76,.3,.45) if selected else (Color(.43,.88,.65,.4) if valid else Color(.92,.31,.21,.45))
func show_portal_preview(cell: Vector2i,rotation_: int,valid: bool):
	show_editor_marker(cell-Vector2i(2,2),Vector2i(5,5),valid)
	if not is_instance_valid(portal_ghost):portal_ghost=make_portal({"rotation":0});preview.add_child(portal_ghost)
	portal_ghost.rotation.y=-rotation_*PI*.5;portal_ghost.show()
func show_road_preview(points: Array,width: int,valid: bool):
	preview.show();preview.position=Vector3.ZERO;preview_mesh.hide();sight_ring.hide()
	if is_instance_valid(ghost_art):ghost_art.hide()
	if is_instance_valid(portal_ghost):portal_ghost.hide()
	if not is_instance_valid(road_preview):
		road_preview=MultiMeshInstance3D.new();road_preview.multimesh=MultiMesh.new();road_preview.multimesh.transform_format=MultiMesh.TRANSFORM_3D
		var tile=BoxMesh.new();tile.size=Vector3(5.8,.12,5.8);road_preview.multimesh.mesh=tile;road_preview.material_override=ghost_material.duplicate();road_preview.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;preview.add_child(road_preview)
	var cells=preload("res://scripts/forest/forest_map_document.gd").road_tiles(points,width)
	road_preview.multimesh.instance_count=cells.size()
	for i in range(cells.size()):road_preview.multimesh.set_instance_transform(i,Transform3D(Basis.IDENTITY,model.point(cells[i])+Vector3.UP*.2))
	road_preview.material_override.albedo_color=Color(.4,.9,.65,.4) if valid else Color(.92,.3,.2,.45);road_preview.show()
func sync(delta: float):
	age+=delta
	for node in portal_nodes:node.visible=model.explored_at(node.position)
	if revision!=model.revision:
		for id in structure_nodes.keys():
			if not model.buildings.has(id):structure_nodes[id].queue_free();structure_nodes.erase(id)
		for b in model.buildings.values():
			var extensions=model.wall_extensions(b) if b.kind=="wall" else Vector2.ZERO
			if structure_nodes.has(b.id) and b.kind=="wall" and (structure_nodes[b.id].get_meta("wall_extensions",Vector2.ZERO)!=extensions or structure_nodes[b.id].get_meta("wall_rotation",0)!=b.rotation):
				structure_nodes[b.id].queue_free();structure_nodes.erase(b.id)
			if not structure_nodes.has(b.id):
				var visual=building_visual(b);visual.wall_extensions=extensions
				var node=Art.building(visual);add_child(node);node.position=model.center(b);structure_nodes[b.id]=node
				node.set_meta("wall_extensions",extensions);node.set_meta("wall_rotation",b.rotation)
				var health=Geo.box(node,Vector3(0,Profile.height(b.kind)+1.0,0),Vector3(5,.25,.35),Geo.mat("d7b65f",0,.3));health.name="Health"
		for w in model.workers.values():
			if not worker_nodes.has(w.id):var node=Art.worker(w.id);add_child(node);worker_nodes[w.id]=node
		revision=model.revision;update_fog()
		if painterly_pilot!=null:painterly_pilot.refresh()
	for b in model.buildings.values():
		var health=structure_nodes[b.id].get_node("Health");health.visible=b.kind!="wall" and (b.hp<b.max_hp or b.get("breached",false));health.scale.x=maxf(.01,b.hp/b.max_hp)
		if b.kind=="gate":
			var center_:Vector3=model.center(b)
			var open_=model.hero_position.distance_to(center_)<10
			for w in model.workers.values():
				if w.state not in ["wounded","repair"] and w.pos.distance_to(center_)<10:open_=true
			for defender in model.defenders.values():
				if defender.hp>0 and defender.pos.distance_to(center_)<10:open_=true
			var door=structure_nodes[b.id].get_node("GateDoor")
			var breached:bool=b.get("breached",false)
			door.visible=not breached
			var collider=door.get_node("GateDoorCollider")
			var collision_layer=0 if breached else 32
			if collider.collision_layer!=collision_layer:collider.collision_layer=collision_layer
			var footing=float(door.get_meta("foundation_depth",0.0))
			var door_height=Profile.GATE_OPEN_Y+footing*.5 if open_ else Profile.GATE_CLOSED_Y-footing*.5
			door.position.y=lerpf(door.position.y,door_height,minf(1,delta*6))
		if b.kind in ["wall","gate"]:
			var damage=structure_nodes[b.id].get_node("WallDamage")
			damage.sync_health(b.max_hp if b.kind=="wall" else b.hp,b.max_hp,delta)
			if b.get("breached",false):damage.hide()
	for w in model.workers.values():
		var node: Node3D=worker_nodes[w.id];var offset=Vector3.UP*(Profile.TOWER_DECK_HEIGHT if w.state=="garrison" else w.get("deck_height",0.0))
		node.visible=not w.has("sheltered_building")
		var move_: Vector3=w.pos-node.position+offset
		if Vector2(move_.x,move_.z).length()>.015:node.rotation.y=atan2(move_.x,move_.z)
		if w.state=="garrison":node.rotation.y=w.get("facing",node.rotation.y)
		node.position=w.pos+offset;node.rotation.z=PI*.5 if w.state=="wounded" else 0.0
		node.get_node("Cargo").visible=w.cargo>0
		node.get_node("Selected").visible=w.follow
		node.get_node("Bow").visible=w.state=="garrison"
		Art.animate_worker(node,w,age)
	vision_clock-=delta
	for material in fog_materials:
		material.set_shader_parameter("hero_position",Vector2(model.hero_position.x,model.hero_position.z))
		material.set_shader_parameter("canopy_cutaway",model.phase=="wave")
	var environment_=get_world_3d().environment
	if environment_!=null:
		for material in kai_materials:
			material.set_shader_parameter("compensate_filmic",environment_.tonemap_mode==Environment.TONE_MAPPER_FILMIC)
			material.set_shader_parameter("scene_exposure",environment_.tonemap_exposure);material.set_shader_parameter("scene_white",environment_.tonemap_white)
	if vision_clock<=0:update_fog();vision_clock=.2
	rally_ring.visible=model.workforce!=null and model.workforce.held and model.phase=="wave"
	rally_ring.position=Vector3(model.hero_position.x,model.surface_height(model.hero_position.x,model.hero_position.z)+.15,model.hero_position.z)

func show_wall_preview(cells: Array,rotation_: int,valid: bool):
	if cells.is_empty():return
	preview.show();preview_mesh.show();sight_ring.hide()
	if is_instance_valid(road_preview):road_preview.hide()
	if is_instance_valid(portal_ghost):portal_ghost.hide()
	if is_instance_valid(ghost_art):ghost_art.hide()
	var size_=model.dimensions("wall",rotation_)
	var center_offset=Vector3(size_.x-1,0,size_.y-1)*model.CELL*.5
	var first=model.point(cells.front())+center_offset;var last=model.point(cells.back())+center_offset
	preview.position=(first+last)*.5+Vector3.UP*1.6
	preview_mesh.mesh.size=Vector3(absf(last.x-first.x)+size_.x*model.CELL,3.5,absf(last.z-first.z)+size_.y*model.CELL)
	preview_mesh.material_override.albedo_color=Color(.43,.88,.65,.38) if valid else Color(.92,.31,.21,.45)
