extends SceneTree
## Pure source-context check, separate from actual gate/house/navigation evidence.
const Region=preload("res://scripts/forest/forest_east_region.gd")
const Full=preload("res://scripts/forest/forest_east_alyut_source_completion.gd")
const Regions=preload("res://scripts/forest/forest_freyja_regions.gd")
const FOLDER="res://build/Other Files/Asset Toolkit/East Gate Region/Village Props/Cliff Audit/Alyut Complete Candidate/"
class Model extends RefCounted:
 var falan_area="north_coast"
 var falan_floor=0
var checks=0
var failures=0
func _initialize():run.call_deferred()
func check(ok:bool,label:String):
 checks+=1
 if not ok:failures+=1;printerr("FAIL ",label)
func run():
 Full.review_root=FOLDER
 var handoffs:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(FOLDER+"gate-handoffs.json"));var model=Model.new();var unique={}
 var frame=Regions.village_transform("alyut")
 for warp:Dictionary in handoffs.source_warps:
  for row:Array in warp.handoff_cells:
   var cell=Vector2i(row[0],row[1]);unique[cell]=true
   check(not Full.source_open(cell),"Original2400 post-warp buffer stays source-closed")
   check(Full.field_handoff(cell),"Exact source100 road owns the physical handoff")
   for offset in[Vector2.ZERO,Vector2(.49,.49),Vector2(-.49,-.49)]:
    var local=Regions.Sites.VILLAGES.alyut[2]+(Vector2(cell)+offset)*3.
    check(Region.current_source(model,frame*local)==100,"Source predicates use100 throughout the original handoff tile")
   var interior=Vector2i(warp.first_village_open_after_buffer[0],warp.first_village_open_after_buffer[1])
   var local=Regions.Sites.VILLAGES.alyut[2]+Vector2(interior)*3.
   check(Region.current_source(model,frame*local)==2400,"Actual village floor retains2400 source identity")
 check(unique.size()==12,"Only the twelve original handoff buffers change source context")
 Full.review_root="res://build/Other Files/Asset Toolkit/East Gate Region/does-not-exist/"
 check(not Full.field_handoff(Vector2i(58,28)),"Unavailable candidate never changes canonical source context")
 Full.review_root=""
 print("EAST_ALYUT_SOURCE_HANDOFF_RESULT checks=",checks," failures=",failures)
 quit(failures)
