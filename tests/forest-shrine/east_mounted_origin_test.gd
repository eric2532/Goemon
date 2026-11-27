extends SceneTree
## A wall detail must retain its native plane and hanging datum, without floor fitting.
const Mounted=preload("res://scripts/forest/forest_east_mounted_details.gd")
const Art=preload("res://scripts/forest/forest_original_map_art.gd")
var checks=0
var failures=0
func _initialize():run.call_deferred()
func check(ok:bool,label:String):
 checks+=1
 if not ok:failures+=1;printerr("FAIL ",label)
func run():
 Art.load_east()
 for serial in Mounted.IDS:
  var g:Dictionary=Mounted.data().graphics[str(serial)]
  if g.mode=="floor":continue
  var mesh:Mesh=Mounted.mesh(serial,Art.data().graphics[str(serial)])
  var arrays:Array=mesh.get_meta("east_cpu_arrays")[1]
  var points:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
  var uv:PackedVector2Array=arrays[Mesh.ARRAY_TEX_UV]
  var retained=true
  for i in points.size():
   var p:Vector3=points[i]
   var actual=Vector2((p.x+p.z)*32./3.,(p.z-p.x)*8.-p.y/.045)
   var expected=Vector2(g.origin[0],g.origin[1])+uv[i]*Vector2(g.size[0],g.size[1])
   retained=retained and actual.distance_to(expected)<.001
  check(retained,"Original source-facing pixel plane "+str(serial))
  var paint:ShaderMaterial=mesh.surface_get_material(1)
  check(paint.get_shader_parameter("base_texture").resource_path==Mounted.ROOT+str(serial)+"-front.png","Native art is on the source face, not the displaced reverse "+str(serial))
  if serial==10567:
   check(mesh.get_aabb().position.y>2.,"Wall clock remains hung above the ground")
   check(absf(mesh.get_aabb().get_center().z)<.2 and mesh.get_aabb().get_center().x<3.,"Clock retains native wall plane instead of floor-fit room displacement")
 print("EAST_MOUNTED_ORIGIN_RESULT checks=",checks," failures=",failures)
 quit(failures)
