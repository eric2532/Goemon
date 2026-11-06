@static_unload
extends RefCounted
## Shared fort layout, collision and batched intact/ruined panels.
const Art=preload("res://scripts/forest/forest_art.gd")
const Profile=preload("res://scripts/forest/forest_structure_profile.gd")
const Meadow=preload("res://scripts/forest/forest_wind_meadow_assets.gd")
const STATUE=preload("res://assets/models/forest/skullpion_stone_statue.res")
static var pieces:Array=[]
static func prepare():
	if not pieces.is_empty():return
	var model=load("res://scripts/forest/forest_model.gd").new()
	model._make_starter_fort()
	for b in model.buildings.values():
		var position_:Vector3=model.center(b)-Vector3(6,0,6)
		if b.kind!="wall":
			_add_piece(b,position_);continue
		var extension:Vector2=model.wall_extensions(b)
		if b.rotation%4 in [1,2]:extension=Vector2(extension.y,extension.x)
		var length_:float=b.span*6+extension.x+extension.y
		var count=ceili(length_/6.0);var segment=length_/count
		for i in count:
			var panel=b.duplicate();panel.span=1;panel.wall_extensions=Vector2.ONE*(segment-6)*.5
			_add_piece(panel,position_+Basis(Vector3.UP,b.rotation*PI*.5)*Vector3((extension.y-extension.x)*.5-length_*.5+segment*(i+.5),0,0))
static func _add_piece(b:Dictionary,position_:Vector3):
	var item=b.duplicate();item.id=pieces.size();item.wind_meadow=true;item.enemy_castle=true
	var piece={"building":item,"position":position_,"boxes":[]}
	var node=Art.building(item);node.position=position_
	if b.kind=="gate":node.get_node("GateDoor").position.y=Profile.GATE_OPEN_Y
	for shape:CollisionShape3D in node.find_children("*","CollisionShape3D",true,false):
		var transform_=shape.transform;var parent=shape.get_parent()
		while parent!=node:transform_=parent.transform*transform_;parent=parent.get_parent()
		transform_=node.transform*transform_
		if shape.shape is BoxShape3D:piece.boxes.append(transform_*AABB(-shape.shape.size*.5,shape.shape.size))
	node.free();pieces.append(piece)
static func basis(portal:Dictionary)->Basis:return Basis(Vector3.UP,(2-int(portal.rotation))*PI*.5)
static func statue_boxes(portal:Dictionary)->Array[AABB]:
	var result:Array[AABB]=[AABB(Vector3(-15.3,0,-15.3),Vector3(30.6,Profile.PEDESTAL_HEIGHT,30.6))]
	var transform_=Transform3D(basis(portal),Vector3.UP*Profile.PEDESTAL_HEIGHT)
	for box:AABB in STATUE.get_meta("part_boxes"):result.append(transform_*box)
	return result
static func build_statue(parent:Node3D,portal:Dictionary):
	var root=Node3D.new();root.name="SkullpionStatue";root.basis=basis(portal);root.set_meta("native_terrain",true);parent.add_child(root)
	var pedestal=Node3D.new();pedestal.scale=Vector3(1.8,1,1.8);root.add_child(pedestal)
	preload("res://scripts/forest/forest_stone_fort.gd").pedestal(pedestal)
	var mesh=MeshInstance3D.new();mesh.name="CarvedSkullpion";mesh.mesh=STATUE;mesh.position.y=Profile.PEDESTAL_HEIGHT;root.add_child(mesh)
static func section_boxes(portal:Dictionary,index:int)->Array[AABB]:
	prepare()
	var result:Array[AABB]=[];var transform_=Transform3D(basis(portal),Vector3.ZERO)
	for box in pieces[index].boxes:result.append(transform_*box)
	return result
static func boxes(portal:Dictionary)->Array[AABB]:
	prepare()
	var result:Array[AABB]=[]
	for i in pieces.size():
		if portal.has("sections") and portal.sections[i].hp<=0:continue
		result.append_array(section_boxes(portal,i))
	return result
static func build(parent:Node3D,portal:Dictionary)->Dictionary:
	prepare()
	var root=Node3D.new();root.name="EnemyCastle";root.basis=basis(portal);parent.add_child(root)
	var result={"nodes":[],"wall_slots":{},"wall_poses":[],"walls":[]}
	for i in pieces.size():
		var piece:Dictionary=pieces[i];var b:Dictionary=piece.building
		var node=Art.building(b);node.position=piece.position;root.add_child(node);result.nodes.append(node)
		if b.kind=="gate":node.get_node("GateDoor").position.y=Profile.GATE_OPEN_Y
		if b.kind=="wall":
			# Keep all panels in one mesh batch while their hit targets stay independent.
			node.get_node("WindMeadowWall").free()
			result.wall_slots[i]=result.wall_poses.size()
			var length_:float=6+b.wall_extensions.x+b.wall_extensions.y
			result.wall_poses.append(Transform3D(Basis(Vector3.UP,b.rotation*PI*.5).scaled_local(Vector3(length_/6,1,1)),piece.position))
	var walls=Node3D.new();walls.name="WallBatch";root.add_child(walls)
	Meadow.batch(walls,"buildings/wall_section",result.wall_poses);result.walls=walls.get_children()
	return result
static func build_ruins(parent:Node3D,portal:Dictionary,art:Dictionary)->Dictionary:
	var root=Node3D.new();root.name="CastleRuins";root.basis=basis(portal);parent.add_child(root)
	var poses={"wall_ruins":[],"gate_ruins":[],"tower_ruins":[]};var states=[]
	for i in pieces.size():
		var piece:Dictionary=pieces[i];var b:Dictionary=piece.building
		var asset="wall_ruins" if b.kind=="wall" else ("gate_ruins" if b.kind=="gate" else "tower_ruins")
		var transform_=Transform3D(Basis(Vector3.UP,b.rotation*PI*.5),piece.position)
		if b.kind=="wall":
			var length_:float=6+b.wall_extensions.x+b.wall_extensions.y
			transform_.basis=transform_.basis*Basis(Vector3.UP,PI if i%2 else 0.0).scaled(Vector3(length_/6,.75+.25*(i%3),1))
		states.append({"asset":asset,"slot":poses[asset].size(),"pose":transform_,"batches":[]})
		poses[asset].append(Transform3D(Basis.IDENTITY.scaled(Vector3.ZERO),piece.position))
	for asset in poses:
		var group=Node3D.new();root.add_child(group);Meadow.batch(group,"buildings/"+asset,poses[asset])
		for state in states:
			if state.asset==asset:state.batches=group.get_children()
	var keep=Node3D.new();keep.name="StatueRuins";parent.add_child(keep)
	var rubble=[]
	for i in 9:rubble.append(Transform3D(Basis(Vector3.UP,i*2.4).scaled_local(Vector3(1.5,.35,1.2)),Vector3((i%3-1)*8,.1,(i/3-1)*8)))
	Meadow.batch(keep,"buildings/stone_block",rubble);keep.hide()
	var collapse=preload("res://scripts/forest/forest_wall_collapse.gd").new();root.add_child(collapse);collapse.setup(art.wall_poses)
	return {"states":states,"keep":keep,"collapse":collapse}
static func breach(art:Dictionary,ruins:Dictionary,index:int):
	if art.wall_slots.has(index):
		var slot:int=art.wall_slots[index]
		for batch in art.walls:batch.multimesh.set_instance_transform(slot,Transform3D(Basis.IDENTITY.scaled(Vector3.ZERO),art.wall_poses[slot].origin))
		ruins.collapse.play(slot)
	var state:Dictionary=ruins.states[index]
	var pose:Transform3D=state.pose
	# Flatten wall debris so the newly traversable gap also reads as open ground.
	if pieces[index].building.kind=="wall":pose.basis=pose.basis.scaled_local(Vector3(1,.18,1))
	for batch in state.batches:batch.multimesh.set_instance_transform(state.slot,pose)
