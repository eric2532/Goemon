extends RefCounted
## Deform only the authored scarf tail; the fitted collar and face wrap stay fixed.
## Each actor owns its mesh so preview, player and enemies cannot share motion.
var tail: MeshInstance3D
var mesh: ArrayMesh
var rest_surfaces: Array = []
var clock: float = 0.0
var airflow: float = 0.0
var length_: float = 1.0

func configure(model: Node3D) -> void:
	tail = model.find_child("ScarfTail_Geometry", true, false) as MeshInstance3D
	if not is_instance_valid(tail) or not tail.mesh is ArrayMesh:
		return
	mesh = ArrayMesh.new()
	rest_surfaces.clear()
	length_ = 0.01
	for surface in range(tail.mesh.get_surface_count()):
		var arrays: Array = tail.mesh.surface_get_arrays(surface)
		# Actor setup has already duplicated active materials for hit-flash safety.
		rest_surfaces.append({"arrays": arrays, "material": tail.get_active_material(surface), "primitive": tail.mesh.surface_get_primitive_type(surface)})
		for vertex in arrays[Mesh.ARRAY_VERTEX]:
			length_ = maxf(length_, -vertex.z)
	# Vertex positions use local -Z along the tail, +Y up, X across the cloth.
	# The importer may keep tight original bounds, so include the full wind swing.
	tail.custom_aabb = tail.mesh.get_aabb().grow(0.4)
	tail.mesh = mesh
	clear()

func clear() -> void:
	clock = 0.0
	airflow = 0.0
	if mesh == null:
		return
	mesh.clear_surfaces()
	for surface in rest_surfaces:
		mesh.add_surface_from_arrays(surface.primitive, surface.arrays)
		mesh.surface_set_material(mesh.get_surface_count() - 1, surface.material)

func tick(state: Dictionary, dt: float) -> void:
	if not is_instance_valid(tail) or mesh == null or dt <= 0.0:
		return
	clock += dt
	var speed: float = float(state.get("motionSpeed", 0.0))
	airflow = lerpf(airflow, clampf(speed / 10.2, 0.0, 1.5), 1.0 - exp(-dt * 6.0))
	mesh.clear_surfaces()
	for surface in rest_surfaces:
		var arrays: Array = surface.arrays.duplicate()
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX].duplicate()
		for i in range(vertices.size()):
			var vertex: Vector3 = vertices[i]
			var along: float = clampf((-vertex.z - 0.10) / maxf(0.01, length_ - 0.10), 0.0, 1.0)
			var weight: float = along * along
			var phase: float = clock * (3.5 + airflow * 1.8) - along * 7.5
			vertex.x += weight * (sin(phase) * (0.075 + airflow * 0.10) + sin(phase * 1.71 + 0.6) * 0.022)
			vertex.y += weight * (sin(phase - 1.1) * (0.035 + airflow * 0.055) + airflow * 0.10)
			vertices[i] = vertex
		arrays[Mesh.ARRAY_VERTEX] = vertices
		arrays[Mesh.ARRAY_NORMAL] = _normals(vertices, arrays[Mesh.ARRAY_INDEX], surface.arrays[Mesh.ARRAY_NORMAL])
		mesh.add_surface_from_arrays(surface.primitive, arrays)
		mesh.surface_set_material(mesh.get_surface_count() - 1, surface.material)

func _normals(vertices: PackedVector3Array, indices: PackedInt32Array, original: PackedVector3Array) -> PackedVector3Array:
	var normals := PackedVector3Array()
	normals.resize(vertices.size())
	var count: int = indices.size() if not indices.is_empty() else vertices.size()
	for triangle in range(0, count - 2, 3):
		var a: int = indices[triangle] if not indices.is_empty() else triangle
		var b: int = indices[triangle + 1] if not indices.is_empty() else triangle + 1
		var c: int = indices[triangle + 2] if not indices.is_empty() else triangle + 2
		var normal: Vector3 = (vertices[b] - vertices[a]).cross(vertices[c] - vertices[a])
		if normal.dot(original[a] + original[b] + original[c]) < 0:
			normal = -normal
		normals[a] += normal
		normals[b] += normal
		normals[c] += normal
	for i in range(normals.size()):
		normals[i] = normals[i].normalized() if normals[i].length_squared() > 0.00000001 else original[i]
	return normals
