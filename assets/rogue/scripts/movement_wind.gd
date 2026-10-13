extends Node3D
## A fixed ribbon mesh: soft airflow shading, with no spawned particle nodes.
var strength: float = 0.0
var clock: float = 0.0
var previous_speed: float = 0.0
var direction := Vector3.BACK
var mesh := ImmediateMesh.new()
var ink := StandardMaterial3D.new()
var ribbon: MeshInstance3D

func _init() -> void:
 name = "MovementWind"
 ink.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
 ink.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
 ink.vertex_color_use_as_albedo = true
 ink.cull_mode = BaseMaterial3D.CULL_DISABLED
 ink.no_depth_test = false
 ink.albedo_color = Color(0.72,0.83,0.89,1)
 ribbon = MeshInstance3D.new()
 ribbon.mesh = mesh;ribbon.material_override = ink
 ribbon.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 add_child(ribbon)
 hide()

func clear() -> void:
 strength = 0.0;previous_speed = 0.0;clock = 0.0;direction = Vector3.BACK
 mesh.clear_surfaces();hide()

func tick(state: Dictionary, dt: float) -> void:
 var speed: float = float(state.get("motionSpeed",0))
 var local: Vector3 = state.get("localMotion",Vector3.ZERO)
 var acceleration: float = maxf(0,(speed-previous_speed)/maxf(dt,.001))
 previous_speed = speed
 var target: float = clampf((speed-3.0)/20.0,0,.9)
 if speed > 3:target = minf(1,target+minf(.25,acceleration*.006))
 if not state.get("isPlayer",false):target = 0
 strength = lerpf(strength,target,1-exp(-dt*12))
 clock += dt
 if local.length_squared()>.1:direction = direction.lerp(local.normalized(),1-exp(-dt*18)).normalized()
 visible = strength > .025
 mesh.clear_surfaces()
 if not visible:return
 var side := Vector3(direction.z,0,-direction.x)
 mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
 for i in range(7):
  var phase: float = fposmod(clock*(.9+speed*.055)+float(i)*.173,1)
  var envelope: float = sin(phase*PI)
  var sign_: float = -1 if i%2==0 else 1
  var start: Vector3 = side*sign_*(.48+float(i%3)*.14)+Vector3.UP*(.42+float(i)*.21)-direction*(phase*.7)
  var length_: float = .35+strength*1.35
  for segment in range(5):
   var a: float = segment/5.0
   var b: float = (segment+1)/5.0
   var pa: Vector3 = start-direction*a*length_+side*sign_*sin(a*PI)*.12
   var pb: Vector3 = start-direction*b*length_+side*sign_*sin(b*PI)*.12
   var wa: Vector3 = Vector3.UP*sin(a*PI)*(.018+strength*.018)
   var wb: Vector3 = Vector3.UP*sin(b*PI)*(.018+strength*.018)
   var color := Color(1,1,1,strength*envelope*.38)
   for vertex in [pa-wa,pa+wa,pb+wb,pa-wa,pb+wb,pb-wb]:
    mesh.surface_set_color(color);mesh.surface_add_vertex(vertex)
 mesh.surface_end()
