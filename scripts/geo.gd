class_name Geo
extends RefCounted

static var mats: Dictionary = {}
static func mat(hex: String, metallic: float = 0.0, glow: float = 0.0) -> StandardMaterial3D:
	var key = hex + str(metallic) + str(glow)
	if mats.has(key): return mats[key]
	var m = StandardMaterial3D.new()
	m.albedo_color = Color(hex)
	m.roughness = 0.72
	m.metallic = metallic
	if glow > 0:
		m.emission_enabled = true
		m.emission = Color(hex)
		m.emission_energy_multiplier = glow
	mats[key] = m
	return m

static func mesh(parent: Node3D, resource: Mesh, p: Vector3, material: Material, collision: bool = false) -> MeshInstance3D:
	var n = MeshInstance3D.new()
	n.mesh = resource
	n.position = p
	n.material_override = material
	parent.add_child(n)
	if collision:
		n.create_trimesh_collision()
		for body in n.get_children():
			for shape in body.get_children():
				if shape is CollisionShape3D and shape.shape is ConcavePolygonShape3D:
					shape.shape.backface_collision=true
	return n

static func box(parent: Node3D, p: Vector3, size: Vector3, material: Material, collision: bool = false) -> MeshInstance3D:
	var m = BoxMesh.new()
	m.size = size
	return mesh(parent, m, p, material, collision)

static func sphere(parent: Node3D, p: Vector3, size: Vector3, material: Material) -> MeshInstance3D:
	var m = SphereMesh.new()
	m.radius = 0.5
	m.height = 1.0
	m.radial_segments = 16
	m.rings = 8
	var n = mesh(parent, m, p, material)
	n.scale = size
	return n

static func cylinder(parent: Node3D, p: Vector3, radius: float, height: float, material: Material, collision: bool = false, top: float = -1.0) -> MeshInstance3D:
	var m = CylinderMesh.new()
	m.bottom_radius = radius
	m.top_radius = radius if top < 0 else top
	m.height = height
	m.radial_segments = 12
	return mesh(parent, m, p, material, collision)

static func beam(parent: Node3D, a: Vector3, b: Vector3, width: float, material: Material, collision: bool = false) -> MeshInstance3D:
	var n = cylinder(parent, (a+b)*0.5, width, a.distance_to(b), material, collision)
	n.quaternion = Quaternion(Vector3.UP, (b-a).normalized())
	return n

static func torus(parent: Node3D, p: Vector3, inner: float, outer: float, material: Material) -> MeshInstance3D:
	var m = TorusMesh.new()
	m.inner_radius = inner
	m.outer_radius = outer
	m.rings = 32
	m.ring_segments = 8
	return mesh(parent, m, p, material)

static func spike(parent: Node3D, base: Vector3, tip: Vector3, width: float, material: Material) -> MeshInstance3D:
	var n = cylinder(parent, (base+tip)/2.0, width, base.distance_to(tip), material, false, 0.0)
	n.quaternion = Quaternion(Vector3.UP, (tip-base).normalized())
	return n
