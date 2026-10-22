extends Node3D
## Contact-only accents for Rogue Battle. Existing weapon trails, poses, damage,
## sound and actor hit pauses remain owned by the normal combat system.

const MAX_IMPACTS: int = 16
const SPARK_COUNT: int = 5
var game: Node
var enabled: bool = false
var active_count: int = 0
var slots: Array[Dictionary] = []
var _cursor: int = 0
var _spark_mesh: ArrayMesh
var _ring_mesh: ArrayMesh
var _arc_mesh: ArrayMesh

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	set_process(enabled)

func set_enabled(value: bool) -> void:
	enabled = value
	if value:
		_prepare_pool()
	else:
		clear()
	set_process(value)

func clear() -> void:
	for slot in slots:
		slot.root.hide()
		slot.age = -1.0
	active_count = 0
	_cursor = 0

func impact(_victim: Node3D, point: Vector3, direction: Vector3, strength: int, projectile: bool) -> void:
	if not enabled:
		return
	_prepare_pool()
	var slot: Dictionary = slots[_cursor]
	_cursor = (_cursor + 1) % MAX_IMPACTS
	if slot.age < 0.0:
		active_count += 1
	var weight: int = clampi(strength, 0, 2)
	var forward: Vector3 = direction.normalized() if direction.length_squared() > 0.0001 else Vector3.FORWARD
	var side: Vector3 = forward.cross(Vector3.UP).normalized()
	if side.length_squared() < 0.001:
		side = Vector3.RIGHT
	var camera: Camera3D = get_viewport().get_camera_3d()
	var view_basis: Basis = camera.global_basis.orthonormalized() if camera != null else Basis.IDENTITY
	var screen_direction: Vector2 = Vector2(forward.dot(view_basis.x), forward.dot(view_basis.y))
	var angle: float = screen_direction.angle() if screen_direction.length_squared() > 0.001 else -0.35
	slot.root.global_position = point
	slot.root.show()
	slot.age = 0.0
	slot.lifetime = 0.18 + weight * 0.035
	slot.weight = weight
	slot.projectile = projectile
	slot.forward = forward
	slot.size = 0.62 + weight * 0.16
	# Two fine cutting marks read at the battle camera's distance without a
	# large opaque flash obscuring the victim's existing recoil animation.
	for i in range(slot.cuts.size()):
		var cut: MeshInstance3D = slot.cuts[i]
		cut.basis = view_basis
		cut.rotate_object_local(Vector3.BACK, angle + (0.48 if i == 0 else -0.74))
		cut.position = Vector3.ZERO
		cut.scale = Vector3(slot.size * (1.0 if i == 0 else 0.67), 0.035 + weight * 0.009, 1.0)
	slot.arc.basis = view_basis
	slot.arc.rotate_object_local(Vector3.BACK, angle + 0.6)
	slot.arc.position = Vector3.ZERO
	slot.arc.visible = not projectile
	slot.ring.visible = weight > 0
	slot.ring.position = Vector3.ZERO
	for i in range(SPARK_COUNT):
		var spread: float = float(i) - (SPARK_COUNT - 1) * 0.5
		var velocity: Vector3 = forward * (2.0 + weight * 0.65) + side * spread * 0.82 + Vector3.UP * (0.5 + float(i % 3) * 0.72)
		slot.velocities[i] = velocity
		var spark: MeshInstance3D = slot.sparks[i]
		spark.position = Vector3.ZERO
		spark.basis = view_basis
		var screen_velocity: Vector2 = Vector2(velocity.dot(view_basis.x), velocity.dot(view_basis.y))
		spark.rotate_object_local(Vector3.BACK, screen_velocity.angle())
	_update_slot(slot)

func _process(delta: float) -> void:
	if not enabled:
		return
	if is_instance_valid(game) and (not game.playing or game.paused or game.transitioning):
		return
	# The effect clock continues through actor hit pauses, as it does in Rogue.
	for slot in slots:
		if slot.age < 0.0:
			continue
		slot.age += delta
		if slot.age >= slot.lifetime:
			slot.root.hide()
			slot.age = -1.0
			active_count -= 1
			continue
		_update_slot(slot)

func _update_slot(slot: Dictionary) -> void:
	var t: float = clampf(slot.age / slot.lifetime, 0.0, 1.0)
	var fade: float = (1.0 - t) * (1.0 - t)
	_set_alpha(slot.core_material, clampf(1.0 - t * 2.0, 0.0, 1.0) * 0.9)
	_set_alpha(slot.spark_material, fade * 0.9)
	_set_alpha(slot.arc_material, fade * 0.65)
	_set_alpha(slot.ring_material, fade * 0.3)
	slot.arc.scale = Vector3.ONE * slot.size * (0.55 + t * 0.38)
	slot.ring.scale = Vector3.ONE * slot.size * (0.25 + t * 0.8)
	for i in range(SPARK_COUNT):
		var spark: MeshInstance3D = slot.sparks[i]
		spark.position = slot.velocities[i] * slot.age + Vector3.DOWN * slot.age * slot.age * 3.0
		spark.scale = Vector3((0.13 + slot.weight * 0.04) * (1.0 - t * 0.5), 0.018 * (1.0 - t * 0.75), 1.0)

func _set_alpha(material: StandardMaterial3D, alpha: float) -> void:
	var color: Color = material.albedo_color
	color.a = alpha
	material.albedo_color = color

func _prepare_pool() -> void:
	if not slots.is_empty():
		return
	_spark_mesh = _diamond()
	_ring_mesh = _ribbon(TAU, 0.038, true)
	_arc_mesh = _ribbon(2.15, 0.12, false)
	for index in range(MAX_IMPACTS):
		var root: Node3D = Node3D.new()
		root.name = "RogueContact%02d" % index
		add_child(root)
		root.hide()
		var core: StandardMaterial3D = _material(Color("fff4ce"))
		var sparks: StandardMaterial3D = _material(Color("ffd184"))
		var arc: StandardMaterial3D = _material(Color("ffe5a4"))
		var ring: StandardMaterial3D = _material(Color("8be8d7"))
		var cut_nodes: Array[MeshInstance3D] = []
		var spark_nodes: Array[MeshInstance3D] = []
		var velocities: Array[Vector3] = []
		for i in range(2):
			cut_nodes.append(_mesh(root, _spark_mesh, core))
		for i in range(SPARK_COUNT):
			spark_nodes.append(_mesh(root, _spark_mesh, sparks))
			velocities.append(Vector3.ZERO)
		slots.append({"root": root, "age": -1.0, "lifetime": 0.2, "weight": 0, "size": 1.0,
			"projectile": false, "forward": Vector3.FORWARD, "cuts": cut_nodes,
			"sparks": spark_nodes, "velocities": velocities,
			"arc": _mesh(root, _arc_mesh, arc), "ring": _mesh(root, _ring_mesh, ring),
			"core_material": core, "spark_material": sparks, "arc_material": arc, "ring_material": ring})

func _material(color: Color) -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	material.albedo_color = color
	return material

func _mesh(parent: Node3D, geometry: ArrayMesh, material: StandardMaterial3D) -> MeshInstance3D:
	var mesh: MeshInstance3D = MeshInstance3D.new()
	mesh.mesh = geometry
	mesh.material_override = material
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mesh)
	return mesh

func _diamond() -> ArrayMesh:
	var surface: SurfaceTool = SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var points: Array[Vector3] = [Vector3(-1, 0, 0), Vector3(0, 1, 0), Vector3(1, 0, 0), Vector3(0, -1, 0)]
	for i in [0, 1, 2, 0, 2, 3]:
		surface.set_normal(Vector3.BACK)
		surface.add_vertex(points[i])
	return surface.commit()

func _ribbon(arc: float, width: float, horizontal: bool) -> ArrayMesh:
	var surface: SurfaceTool = SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var segments: int = 32
	for i in range(segments):
		var points: Array[Vector3] = []
		for step in [i, i + 1]:
			var t: float = float(step) / segments
			var angle: float = (t - 0.5) * arc
			var thickness: float = width if horizontal else width * sin(PI * t)
			for radius in [1.0, 1.0 - thickness]:
				points.append(Vector3(sin(angle) * radius, 0, cos(angle) * radius) if horizontal else Vector3(sin(angle) * radius, cos(angle) * radius, 0))
		for vertex in [0, 1, 2, 2, 1, 3]:
			surface.set_normal(Vector3.UP if horizontal else Vector3.BACK)
			surface.add_vertex(points[vertex])
	return surface.commit()
