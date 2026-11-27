extends SceneTree
const Displays=preload("res://scripts/forest/forest_east_display_furniture.gd")
const Art=preload("res://scripts/forest/forest_original_map_art.gd")
var checks=0
var failures=0
func check(ok:bool,label:String):
 checks+=1
 if not ok:failures+=1;printerr("FAIL ",label)
func _initialize():run.call_deferred()
func run():
 Art.load_east()
 for serial in Displays.IDS:
  var mesh=Displays.mesh(serial,Art.data().graphics[str(serial)])
  check(mesh==Displays.mesh(serial,Art.data().graphics[str(serial)]),"Prepared immutable display "+str(serial))
  check(mesh.get_meta("source_rgba_sha256")==Art.data().graphics[str(serial)].rgba_sha256,"Native source pin "+str(serial))
  var bounds=mesh.get_aabb();check(bounds.size.y>.1 and bounds.size.x>.1 and bounds.size.z>.1,"Physical display depth "+str(serial))
  var finite_=true
  for arrays:Array in mesh.get_meta("east_cpu_arrays"):
   for point:Vector3 in arrays[Mesh.ARRAY_VERTEX]:finite_=finite_ and point.is_finite()
  check(finite_,"Finite display vertices "+str(serial))
 print("EAST_DISPLAY_FURNITURE_RESULT checks=",checks," failures=",failures);quit(failures)
