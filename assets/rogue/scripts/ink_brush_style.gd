extends RefCounted
## Palette and clock only. This helper never reads or changes combat state.
static func material(tint: Color, energy: float=1.0, fade: float=1.0) -> ShaderMaterial:
 var ink=ShaderMaterial.new()
 ink.shader=preload("res://assets/rogue/shaders/magic_ink_brush.gdshader")
 ink.set_shader_parameter("custom_palette",true)
 ink.set_shader_parameter("ink_tint",tint)
 ink.set_shader_parameter("energy",energy)
 ink.set_shader_parameter("fade",fade)
 return ink

static func animate(node: Node3D, delta: float) -> void:
 var clock=float(node.get_meta("ink_clock",0.0))+delta
 node.set_meta("ink_clock",clock)
 for ink in node.get_meta("ink_materials",[]):ink.set_shader_parameter("brush_clock",clock)

static var _wake: ArrayMesh
static func wake_mesh() -> ArrayMesh:
 if _wake!=null:return _wake
 var arrays: Array=[];arrays.resize(Mesh.ARRAY_MAX)
 arrays[Mesh.ARRAY_VERTEX]=PackedVector3Array([Vector3(-.12,0,0),Vector3(.12,0,0),Vector3(.38,0,1.5),Vector3(-.38,0,1.5)])
 arrays[Mesh.ARRAY_TEX_UV]=PackedVector2Array([Vector2(1,0),Vector2(1,1),Vector2(0,1),Vector2(0,0)])
 arrays[Mesh.ARRAY_INDEX]=PackedInt32Array([0,1,2,0,2,3])
 _wake=ArrayMesh.new();_wake.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
 return _wake

static func attach_wake(parent: Node3D,tint: Color,size: float=1.0) -> MeshInstance3D:
 var node=MeshInstance3D.new();node.name="PaintedWake";node.mesh=wake_mesh();node.material_override=material(tint,.7,.7)
 var ancestor: Node=parent
 while is_instance_valid(ancestor):
  if ancestor.has_method("is_fire_siege"):
   if ancestor.settings.get("reduced_flashes",false):node.material_override.set_shader_parameter("energy",.28)
   break
  ancestor=ancestor.get_parent()
 node.scale=Vector3.ONE*size;node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 parent.add_child(node)
 var inks: Array=parent.get_meta("ink_materials",[]);inks.append(node.material_override);parent.set_meta("ink_materials",inks)
 return node
