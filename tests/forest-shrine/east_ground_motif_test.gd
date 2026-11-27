extends SceneTree
const Motifs=preload("res://scripts/forest/forest_east_ground_motifs.gd")
const Art=preload("res://scripts/forest/forest_original_map_art.gd")
var checks=0
var failures=0
func _initialize():run.call_deferred()
func check(ok:bool,label:String):
 checks+=1
 if not ok:failures+=1;printerr("FAIL ",label)
func run():
 Art.load_east();var report=[]
 for serial in Motifs.IDS:
  var g:Dictionary=Art.data().graphics[str(serial)];var mesh=Motifs.mesh(serial,g);var arrays=mesh.surface_get_arrays(0);var pixels=[Vector2.ZERO,Vector2(g.rect[2],0),Vector2(g.rect[2],g.rect[3]),Vector2(0,g.rect[3])];var order=[0,1,2,0,2,3]
  check(Motifs.mesh(serial,g)==mesh,"One shared immutable ground motif "+str(serial))
  check(arrays[Mesh.ARRAY_VERTEX].size()==6 and mesh.get_surface_count()==1,"One bounded full-extent native quad "+str(serial))
  for i in 6:
   var p:Vector3=arrays[Mesh.ARRAY_VERTEX][i];var native=Vector2((p.x+p.z)*32./3.,(p.z-p.x)*8.);var expected=pixels[order[i]]+Vector2(g.origin[0],g.origin[1])
   check(native.distance_to(expected)<.001 and is_equal_approx(p.y,.025) and arrays[Mesh.ARRAY_NORMAL][i].distance_to(Vector3.UP)<.001,"Original full source pixel bound/origin preserved "+str(serial)+":"+str(i))
  report.append({"graphic":serial,"bounds":var_to_str(mesh.get_aabb()),"source_rgba_sha256":g.rgba_sha256})
 var path="res://build/Other Files/Asset Toolkit/East Gate Region/Visual Landmarks/Remaining Fallback Audit/flat-motif-contract.json";var f=FileAccess.open(path,FileAccess.WRITE);f.store_string(JSON.stringify({"checks":checks,"failures":failures,"graphics":report,"helper_sha256":FileAccess.get_sha256("res://scripts/forest/forest_east_ground_motifs.gd"),"scope":"Pure source/mesh projection contract only; no actual gameplay-camera or route claim. Cached renderer shutdown diagnostics are reported separately."},"  "));f.close();print("EAST_GROUND_MOTIF_RESULT checks=",checks," failures=",failures);quit(failures)
