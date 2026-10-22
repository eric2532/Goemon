extends RefCounted
## Shared native emissive meshes. Four flight and four impact slots per tower.
static var material: StandardMaterial3D
static var bolt_mesh: BoxMesh
static var crystal_mesh: PrismMesh
static var ring_mesh: TorusMesh
var root: Node3D
var visuals: Array[MeshInstance3D]=[]
var impacts: Array[Dictionary]=[]
func configure(tower: Node3D)->void:
	if material==null:
		material=StandardMaterial3D.new();material.albedo_color=Color("93e9ff")
		material.emission_enabled=true;material.emission=Color("37aeea");material.emission_energy_multiplier=1.6
		material.roughness=.3
		bolt_mesh=BoxMesh.new();bolt_mesh.size=Vector3(.18,.18,1.4)
		crystal_mesh=PrismMesh.new();crystal_mesh.size=Vector3(.6,1.4,.6)
		ring_mesh=TorusMesh.new();ring_mesh.inner_radius=.65;ring_mesh.outer_radius=.78;ring_mesh.rings=16;ring_mesh.ring_segments=4
	root=Node3D.new();root.name="IceCrystalAdapter";tower.add_child(root)
	for side in [-1,0,1]:
		var crystal=make(crystal_mesh);crystal.position=Vector3(side*.46,2.2-abs(side)*.3,0);crystal.rotation.z=-side*.3
	for i in range(4):
		var bolt=make(bolt_mesh);bolt.set_as_top_level(true);bolt.hide();visuals.append(bolt)
		var ring=make(ring_mesh);ring.set_as_top_level(true);ring.hide();impacts.append({"node":ring,"left":0.0})
func make(mesh: Mesh)->MeshInstance3D:
	var visual=MeshInstance3D.new();visual.mesh=mesh;visual.material_override=material
	visual.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;visual.visibility_range_end=100;root.add_child(visual);return visual
func acquire()->MeshInstance3D:
	for visual in visuals:
		if not visual.visible:visual.show();return visual
	return null
func release(visual: MeshInstance3D)->void:
	if is_instance_valid(visual):visual.hide()
func impact(point: Vector3)->void:
	for effect in impacts:
		if effect.left<=0:effect.left=.25;effect.node.global_position=point;effect.node.show();return
func tick(delta: float)->void:
	for effect in impacts:
		if effect.left<=0:continue
		effect.left=maxf(0,effect.left-delta);effect.node.scale=Vector3.ONE*(1+(1-effect.left/.25)*.5)
		effect.node.visible=effect.left>0
func clear()->void:
	for visual in visuals:visual.hide()
	for effect in impacts:effect.left=0;effect.node.hide()
