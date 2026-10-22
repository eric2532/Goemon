class_name RecoveredGoemonWeapons
extends RefCounted
## Vertices, UVs and triangles extracted directly from ROM model file 0x120.
## Mesh coordinates retain original model units; the native model applies weapon
## part matrices from motion.json with the same source-space conversion as its body.
const ROOT := "res://assets/characters/recovered_goemon/weapons/"
const GOLD_LINEAR_SHADER := preload("res://assets/characters/recovered_goemon/weapons/gold_pipe_linear.gdshader")
static var _data: Dictionary = {}

static func data() -> Dictionary:
	if _data.is_empty():
		var file := FileAccess.open(ROOT + "weapons.json", FileAccess.READ)
		if file != null:
			var parsed: Variant = JSON.parse_string(file.get_as_text())
			if parsed is Dictionary:
				_data = parsed
	return _data

static func create_part(part_name: String, source_scale: float = 1.0) -> MeshInstance3D:
	var mesh_node := MeshInstance3D.new()
	mesh_node.name = part_name
	var part: Dictionary = data().get("parts", {}).get(part_name, {})
	if part.is_empty():
		return mesh_node
	var vertices: Array = part.get("vertices", [])
	var mesh := ArrayMesh.new()
	for surface: Dictionary in part.get("surfaces", []):
		var positions := PackedVector3Array()
		var normals := PackedVector3Array()
		var uvs := PackedVector2Array()
		var size: Array = surface.get("texture_size", [32, 32])
		for face: Array in surface.get("faces", []):
			# Preserve the source winding; material is double sided for reflected mounts.
			for vertex_index: int in face:
				var vertex: Dictionary = vertices[vertex_index]
				var p: Array = vertex["position"]
				var n: Array = vertex["normal"]
				var uv: Array = vertex["uv_raw"]
				positions.append(Vector3(p[0], p[1], p[2]) * source_scale)
				normals.append(Vector3(n[0], n[1], n[2]).normalized())
				uvs.append(Vector2(float(uv[0]) / 64.0 / float(size[0]), float(uv[1]) / 64.0 / float(size[1])))
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = positions
		arrays[Mesh.ARRAY_NORMAL] = normals
		arrays[Mesh.ARRAY_TEX_UV] = uvs
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		var material := StandardMaterial3D.new()
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
		material.roughness = 0.55
		var texture_file := String(surface.get("texture_file", ""))
		if not texture_file.is_empty():
			material.albedo_texture = load(ROOT + texture_file) as Texture2D
		var color: Array = surface.get("primitive_color", [1, 1, 1, 1])
		material.albedo_color = Color.WHITE if not texture_file.is_empty() else Color(color[0], color[1], color[2], color[3])
		if surface.get("texture_coordinate_mode", "") == "n64_generated_linear":
			var native_material := ShaderMaterial.new()
			native_material.shader = GOLD_LINEAR_SHADER
			native_material.set_shader_parameter("source_texture", load(ROOT + texture_file) as Texture2D)
			var native_scale: Array = surface.get("uv_scale", [0.03125, 0.0625])
			native_material.set_shader_parameter("source_texture_scale", Vector2(native_scale[0], native_scale[1]))
			native_material.set_shader_parameter("source_texture_size", Vector2(size[0], size[1]))
			mesh.surface_set_material(mesh.get_surface_count() - 1, native_material)
		else:
			mesh.surface_set_material(mesh.get_surface_count() - 1, material)
	mesh_node.mesh = mesh
	return mesh_node

static func install(model: Node3D) -> void:
	if model.get_meta("rom_pipe_installed", false):
		return
	var pivot: Node3D = model.pipe
	for child in pivot.get_children():
		pivot.remove_child(child)
		child.queue_free()
	var gold_pipe=create_part("gold_pipe")
	gold_pipe.name="GoldPipe"
	pivot.add_child(gold_pipe)
	model.pipe_bounds.clear()
	model.set_meta("rom_pipe_installed", true)

static func install_chain(model: Node3D) -> void:
	var chain: ChainPipeVisual = model.chain_pipe
	if not is_instance_valid(chain) or chain.get_meta("rom_chain_installed", false):
		return
	var grip := create_part("chain_pipe_grip", 0.01)
	var tip := create_part("chain_pipe_projectile_head", 0.01)
	var link := create_part("chain_link", 0.0068)
	for child in chain.get_children():
		if child is MeshInstance3D and child != chain.head:
			if child.mesh == ChainPipeVisual.meshes.get("Chain_Handle"):
				child.mesh = grip.mesh
				child.rotation.y = PI / 2.0
			elif child.mesh == ChainPipeVisual.meshes.get("Handle_Attachment"):
				child.hide()
	chain.head.mesh = tip.mesh
	for child in chain.head.get_children():
		if child is MeshInstance3D:
			child.hide()
	chain.links.multimesh.mesh = link.mesh
	grip.free();tip.free();link.free()
	chain.set_meta("rom_chain_installed", true)

static func create_coin() -> Node3D:
	var node := Node3D.new()
	node.name = "OriginalROMCoin"
	var part := create_part("coin_projectile_plane", 0.01)
	# Native coin plane has X=0. A quarter turn places it on a billboard's XY plane.
	var baked := ArrayMesh.new()
	var turn := Basis(Vector3.UP, PI / 2.0)
	for surface_index in range(part.mesh.get_surface_count()):
		var arrays: Array = part.mesh.surface_get_arrays(surface_index)
		var positions: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		for vertex_index in range(positions.size()):
			positions[vertex_index] = turn * positions[vertex_index]
			normals[vertex_index] = turn * normals[vertex_index]
		arrays[Mesh.ARRAY_VERTEX] = positions
		arrays[Mesh.ARRAY_NORMAL] = normals
		baked.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		baked.surface_set_material(surface_index, part.mesh.surface_get_material(surface_index))
	part.mesh = baked
	for i in range(part.mesh.get_surface_count()):
		var material := part.mesh.surface_get_material(i) as StandardMaterial3D
		if material != null:
			material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
			material.cull_mode = BaseMaterial3D.CULL_BACK
			material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
	node.add_child(part)
	return node
