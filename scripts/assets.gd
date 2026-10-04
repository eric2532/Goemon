class_name GameAssets
extends RefCounted
# Gameplay owns collision and interaction. This library owns imported visuals only.
static var scenes: Dictionary={}
static var collision_shapes: Dictionary={}
static func instantiate_model(id: String)->Node3D:
	if not scenes.has(id):
		scenes[id]=load("res://assets/models/"+id+".glb")
	assert(scenes[id] is PackedScene,"Missing Blender export: "+id)
	return scenes[id].instantiate()

static func place(parent: Node3D,id: String,p: Vector3=Vector3.ZERO,scale_value: Vector3=Vector3.ONE)->Node3D:
	var visual=instantiate_model(id)
	parent.add_child(visual)
	visual.position=p
	visual.scale=scale_value
	return visual

static func collision_for(node: Node,shared: bool=false):
	if node is MeshInstance3D:
		if shared:
			var key=node.mesh.get_instance_id()
			if not collision_shapes.has(key):collision_shapes[key]=node.mesh.create_trimesh_shape()
			var body=StaticBody3D.new();node.add_child(body)
			var collision=CollisionShape3D.new();collision.shape=collision_shapes[key];body.add_child(collision)
		else:node.create_trimesh_collision()
		for child in node.get_children():
			for shape in child.get_children():
				if shape is CollisionShape3D and shape.shape is ConcavePolygonShape3D: shape.shape.backface_collision=true
	for child in node.get_children():
		if child is Node3D and not child is StaticBody3D: collision_for(child,shared)
