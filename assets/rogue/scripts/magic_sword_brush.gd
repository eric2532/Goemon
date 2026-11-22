extends MeshInstance3D
## One bounded ribbon per swing, sampled AFTER the authored weapon pose.
const MAX_SAMPLES = 18
const SUBDIVISIONS = 3
static var ribbon_layouts:Dictionary={}
var samples: Array = []
var histories: Array = []
var original_brush:MeshInstance3D
var wave_scale=1.0

func _init() -> void:
 name = "MagicSwordInkBrush"
 mesh = ArrayMesh.new()
 cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 var material = ShaderMaterial.new()
 material.shader = preload("res://assets/rogue/shaders/magic_ink_brush.gdshader")
 material_override = material

func sample_blade(base: Vector3, tip: Vector3) -> void:
 sample_blades([[base,tip]])

func sample_blades(poses: Array) -> void:
 if original_brush!=null:
  var physical=[]
  for pair in poses:physical.append([pair[0],pair[0]+(pair[1]-pair[0])/wave_scale])
  original_brush.sample_blades(physical)
 # Both hands share one admitted ribbon; at most two finite surfaces.
 while histories.size()<mini(2,poses.size()):histories.append([])
 mesh.clear_surfaces()
 for blade in range(mini(2,poses.size())):
  samples=histories[blade]
  samples.append([to_local(poses[blade][0]),to_local(poses[blade][1])])
  if samples.size()>MAX_SAMPLES:samples.pop_front()
  if samples.size()<2:continue
  _surface()

func _surface() -> void:
 mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,surface_arrays(samples))

static func surface_arrays(poses:Array) -> Array:
 var vertices = PackedVector3Array()
 var points = (poses.size()-1)*SUBDIVISIONS+1
 var layout=ribbon_layouts.get(points)
 if layout==null:
  var uvs=PackedVector2Array()
  var indices=PackedInt32Array()
  var widths=PackedFloat64Array()
  for i in range(points):
   var u=float(i)/float(points-1)
   widths.append(.76*pow(maxf(0,sin(PI*u)),.55))
   uvs.append(Vector2(u,0));uvs.append(Vector2(u,1))
   if i>0:
    var n=i*2
    indices.append_array(PackedInt32Array([n-2,n-1,n,n-1,n+1,n]))
  layout=[uvs,indices,widths]
  if poses.size()<=MAX_SAMPLES:ribbon_layouts[points]=layout
 var widths:PackedFloat64Array=layout[2]
 vertices.resize(points*2)
 for i in range(points):
  var segment = mini(i/SUBDIVISIONS,poses.size()-2)
  var t = float(i-segment*SUBDIVISIONS)/SUBDIVISIONS
  var a: Array = poses[maxi(0,segment-1)]
  var b: Array = poses[segment]
  var c: Array = poses[segment+1]
  var d: Array = poses[mini(poses.size()-1,segment+2)]
  var curve_base: Vector3 = _curve(a[0],b[0],c[0],d[0],t)
  var curve_tip: Vector3 = _curve(a[1],b[1],c[1],d[1],t)
  # Smooth the recorded path into a pointed crescent, keeping its leading tip
  # exactly on the current sword. Never predict future weapon positions.
  vertices[i*2]=curve_tip.lerp(curve_base,widths[i])
  vertices[i*2+1]=curve_tip
 var arrays: Array = []
 arrays.resize(Mesh.ARRAY_MAX)
 arrays[Mesh.ARRAY_VERTEX]=vertices;arrays[Mesh.ARRAY_TEX_UV]=layout[0];arrays[Mesh.ARRAY_INDEX]=layout[1]
 return arrays

static func _curve(a: Vector3,b: Vector3,c: Vector3,d: Vector3,t: float) -> Vector3:
 return .5*((2*b)+(-a+c)*t+(2*a-5*b+4*c-d)*t*t+(-a+3*b-3*c+d)*t*t*t)
