extends MeshInstance3D
## One bounded ribbon per swing, sampled AFTER the authored weapon pose.
const MAX_SAMPLES = 18
const SUBDIVISIONS = 3
var samples: Array = []

func _init() -> void:
 name = "MagicSwordInkBrush"
 mesh = ArrayMesh.new()
 cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 var material = ShaderMaterial.new()
 material.shader = preload("res://assets/rogue/shaders/magic_ink_brush.gdshader")
 material_override = material

func sample_blade(base: Vector3, tip: Vector3) -> void:
 samples.append([to_local(base), to_local(tip)])
 if samples.size()>MAX_SAMPLES:samples.pop_front()
 if samples.size()<2:return
 var vertices = PackedVector3Array()
 var uvs = PackedVector2Array()
 var indices = PackedInt32Array()
 var points = (samples.size()-1)*SUBDIVISIONS+1
 for i in range(points):
  var segment = mini(i/SUBDIVISIONS,samples.size()-2)
  var t = float(i-segment*SUBDIVISIONS)/SUBDIVISIONS
  var a: Array = samples[maxi(0,segment-1)]
  var b: Array = samples[segment]
  var c: Array = samples[segment+1]
  var d: Array = samples[mini(samples.size()-1,segment+2)]
  var curve_base: Vector3 = _curve(a[0],b[0],c[0],d[0],t)
  var curve_tip: Vector3 = _curve(a[1],b[1],c[1],d[1],t)
  var u = float(i)/float(points-1)
  var width = .76*pow(maxf(0,sin(PI*u)),.55)
  # Smooth the recorded path into a pointed crescent, keeping its leading tip
  # exactly on the current sword. Never predict future weapon positions.
  vertices.append(curve_tip.lerp(curve_base,width))
  vertices.append(curve_tip)
  uvs.append(Vector2(u,0));uvs.append(Vector2(u,1))
  if i>0:
   var n = i*2
   indices.append_array(PackedInt32Array([n-2,n-1,n,n-1,n+1,n]))
 var arrays: Array = []
 arrays.resize(Mesh.ARRAY_MAX)
 arrays[Mesh.ARRAY_VERTEX]=vertices;arrays[Mesh.ARRAY_TEX_UV]=uvs;arrays[Mesh.ARRAY_INDEX]=indices
 mesh.clear_surfaces()
 mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)

func _curve(a: Vector3,b: Vector3,c: Vector3,d: Vector3,t: float) -> Vector3:
 return .5*((2*b)+(-a+c)*t+(2*a-5*b+4*c-d)*t*t+(-a+3*b-3*c+d)*t*t*t)
