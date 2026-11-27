extends SceneTree
## Resource-owned original flat arrays survive batching without a setup GPU readback.
const Art=preload("res://scripts/forest/forest_original_map_art.gd")
const Forms=preload("res://scripts/forest/forest_original_map_solids.gd")
var checks=0
var failures=0
func check(ok:bool,label_:String):
 checks+=1
 if not ok:failures+=1;printerr("ORIGINAL_GROUND_ARRAYS_FAIL "+label_)
func _initialize():run.call_deferred()
func run():
 var rows=[]
 for spec in [[7807,"floor"],[5000,"water"],[10506,"detail_flat_panel"]]:
  var serial:int=spec[0];var family:String=spec[1]
  var graphic:Dictionary=Art.data().graphics[str(serial)]
  var texture=load(Art.ROOT+Art.data().pages[int(graphic.page)])
  var mesh=Forms.mesh(serial,family,graphic,texture)
  var cpu:Variant=mesh.get_meta("source_surface_arrays",null)
  check(cpu is Array,"Original flat builder owns CPU arrays "+str(serial))
  if not cpu is Array:continue
  var gpu:Array=mesh.surface_get_arrays(0)
  check(cpu[Mesh.ARRAY_VERTEX].size()==6 and gpu[Mesh.ARRAY_VERTEX].size()==6,"Complete two-triangle source surface "+str(serial))
  var difference={"vertices":0.,"normals":0.,"uv":0.}
  for i in cpu[Mesh.ARRAY_VERTEX].size():
   difference.vertices=maxf(difference.vertices,cpu[Mesh.ARRAY_VERTEX][i].distance_to(gpu[Mesh.ARRAY_VERTEX][i]))
   difference.normals=maxf(difference.normals,cpu[Mesh.ARRAY_NORMAL][i].distance_to(gpu[Mesh.ARRAY_NORMAL][i]))
   difference.uv=maxf(difference.uv,cpu[Mesh.ARRAY_TEX_UV][i].distance_to(gpu[Mesh.ARRAY_TEX_UV][i]))
  check(difference.vertices<.000001 and difference.normals<.0001 and difference.uv<.00001,"CPU positions/normals/UV match the existing committed mesh "+str(serial))
  var before=var_to_bytes(cpu)
  check(Forms.mesh(serial,family,graphic,texture)==mesh,"Repeated placements share the same resource owner "+str(serial))
  check(var_to_bytes(mesh.get_meta("source_surface_arrays"))==before,"Cached source arrays remain unchanged "+str(serial))
  rows.append({"serial":serial,"family":family,"maximum_difference":difference,"exact_array_bytes":before==var_to_bytes(gpu)})
 var output="res://build/Other Files/Asset Toolkit/Sokia Venoa Coverage/Cape caves/ground-arrays.json"
 var file=FileAccess.open(output,FileAccess.WRITE);file.store_string(JSON.stringify({"checks":checks,"failures":failures,"rows":rows},"  "));file.close()
 print("ORIGINAL_GROUND_ARRAYS_RESULT checks=",checks," failures=",failures)
 quit(1 if failures else 0)
