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
