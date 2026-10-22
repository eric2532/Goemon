extends Node3D
## Persistent aiming surface. Independent of transient combat effects and budgets.
var visual: MeshInstance3D
var radius=0.0
func _init():
 process_mode=Node.PROCESS_MODE_ALWAYS
 name="DragoonLeapPreview"
 visual=MeshInstance3D.new();visual.name="DamageArea"
 var plane=PlaneMesh.new();plane.size=Vector2(2,2)
 visual.mesh=plane
 var material=ShaderMaterial.new()
 material.shader=preload("res://assets/vfx/dragoon/leap_preview.gdshader")
 visual.material_override=material
 visual.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 add_child(visual)
 hide()
func set_area(point: Vector3,radii: Vector3):
 if not point.is_finite() or not radii.is_finite() or radii.z<=0:hide();return
 radius=radii.z
 global_position=point+Vector3.UP*.045
 visual.scale=Vector3(radius,1,radius)
 var material: ShaderMaterial=visual.material_override
 material.set_shader_parameter("inner_ratio",radii.x/radius)
 material.set_shader_parameter("middle_ratio",radii.y/radius)
 show()

func _process(_delta: float):
 # End-phase overlays pause the combat controller before it can hide us.
 if get_tree().paused:hide()
