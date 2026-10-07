extends Node3D
## One reusable body rim and seven energy wisps. No per-frame effect allocation.
const COLORS = {
 "pirate": Color("619be6"), "samurai": Color("f04e59"),
 "ninja": Color("ad6aef"), "mage": Color("607cff"),
 "knight": Color("579df4"), "dragoon": Color("43d9ee"),
 "magic-swordsman": Color("ba83ff"), "ranger": Color("69cd79"),
 "explorer": Color("49c5ab"), "master-thief": Color("f26346")}
var strength: float = 0.0
var clock: float = 0.0
var body_material: ShaderMaterial
var glow: StandardMaterial3D
var meshes: Array[MeshInstance3D] = []
var wisps: Array[MeshInstance3D] = []
var applied: bool = false

func configure(actor: Node3D, id: String) -> void:
 name = "UltimateAura"
 var color: Color = COLORS.get(id, Color("b9a0ff"))
 body_material = ShaderMaterial.new()
 body_material.shader = preload("res://assets/rogue/shaders/ultimate_rim.gdshader")
 body_material.set_shader_parameter("energy_color", color)
 _collect(actor.model)
 glow = StandardMaterial3D.new()
 glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
 glow.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
 glow.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
 glow.albedo_color = color
 glow.emission_enabled = true
 glow.emission = color
 glow.emission_energy_multiplier = 1.3
 var geometry := SphereMesh.new()
 geometry.radius = 0.065;geometry.height = 0.32
 geometry.radial_segments = 8;geometry.rings = 4
 for i in range(7):
  var wisp := MeshInstance3D.new()
  wisp.mesh = geometry;wisp.material_override = glow
  wisp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
  add_child(wisp);wisps.append(wisp)
 hide()

func _collect(node: Node) -> void:
 if node is MeshInstance3D: meshes.append(node)
 for child in node.get_children(): _collect(child)

func clear() -> void:
 strength = 0.0
 clock = 0.0
 hide()
 for mesh in meshes: mesh.material_overlay = null
 applied = false

func tick(state: Dictionary, dt: float) -> void:
 var remaining: float = maxf(float(state.get("buffTime", 0)), maxf(float(state.get("drink", 0)), float(state.get("ultimatePulse", 0))))
 strength = move_toward(strength, minf(1.0, remaining*4.0), dt*7.0)
 clock += dt
 visible = strength > 0.01
 if visible != applied:
  for mesh in meshes:
   mesh.material_overlay = body_material if visible else null
  applied = visible
 if not visible: return
 body_material.set_shader_parameter("strength", strength*(0.87+sin(clock*5.0)*0.13))
 var color: Color = glow.albedo_color
 color.a = strength*0.55;glow.albedo_color = color
 for i in wisps.size():
  var t: float = fposmod(clock*0.65+i/7.0, 1.0)
  var angle: float = i*TAU/7.0+clock*0.8
  var radius: float = 0.64+sin(t*PI)*0.1
  wisps[i].position = Vector3(cos(angle)*radius, 0.15+t*2.45, sin(angle)*radius)
  wisps[i].scale = Vector3.ONE * sin(t*PI)
