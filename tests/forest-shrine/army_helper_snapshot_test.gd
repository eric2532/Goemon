extends SceneTree
const Runtime=preload("res://scripts/forest/crowd/army_runtime.gd")
var checks=0
var failures=0
func check(ok:bool,label_:String):
 checks+=1
 if not ok:failures+=1;printerr("FAIL: ",label_)
func _initialize():run.call_deferred()
func run():
 var army=Runtime.new();army.configure(null)
 if not army.native.has_method("capture_helper_snapshot") or not army.native.has_method("sync_helper_snapshot"):
  check(false,"Paid helper state can be captured before simulation and mirrored from immutable input");finish(army);return
 var unmanaged:int=army.spawn(-999,1,11,Vector3.ZERO,200,.4)
 for i in 1999:
  var h:int=army.spawn(-1000-i,1,11,Vector3(i*.05,0,20),200.125,.4)
  army.native.set_guard(h,Vector3(i*.05,0,20),18)
 check(army.native.capture_helper_snapshot().logical_ids.size()==1999,"Unmanaged fixture allies are excluded from paid ownership")
 army.despawn(unmanaged)
 var last:int=army.spawn(-2999,1,11,Vector3(99.95,0,20),200.125,.4);army.native.set_guard(last,Vector3(99.95,0,20),18)
 var expected={900:{"id":900,"hp":999,"pos":Vector3.ZERO}};var expected_posts={}
 check(army.native.sync_helper_mirrors(expected,expected_posts)==2000,"Original live mirror owns all2000 paid helpers only")
 var captured:Dictionary=army.native.capture_helper_snapshot()
 check(captured.logical_ids.size()==2000,"Capture retains every independent paid helper")
 army.native.begin_step(.5)
 var actual={900:{"id":900,"hp":999,"pos":Vector3.ZERO}};var posts={}
 check(army.native.sync_helper_snapshot(captured,actual,posts)==2000 and actual==expected and posts==expected_posts,"Pending simulation cannot change pre-step collector/food/post state")
 army.native.finish_step()
 var handle:int=army.handles[-1000];army.set_pose(handle,Vector3(40,2,10),.7);army.native.apply_hit(handle,{"amount":.125})
 var latest={900:{"id":900,"hp":999,"pos":Vector3.ZERO}};var latest_posts={}
 army.native.sync_helper_mirrors(latest,latest_posts)
 check(latest!=expected,"The current state really differs from the retained snapshot")
 army.native.sync_helper_snapshot(captured,actual,posts)
 check(actual==expected and posts==expected_posts,"Captured numeric arrays stay immutable after health and pose changes")
 var row=actual[-1000];army.native.sync_helper_snapshot(captured,actual,posts)
 check(is_same(row,actual[-1000]),"Existing owned rows are reused without altering foreign defenders")
 var sheltered=captured.duplicate(true);sheltered.shelter_modes[0]=2;sheltered.status[1]=96
 var hidden_id:int=sheltered.logical_ids[0];var marked_id:int=sheltered.logical_ids[1]
 check(army.native.sync_helper_snapshot(sheltered,actual,posts)==2000 and not actual.has(hidden_id) and posts.has(hidden_id),"Captured shelter state retains food and posts while removing exposed targeting")
 check(not actual[marked_id].targetable and actual[marked_id].taunting,"Captured status bits retain exact targetability and taunt")
 army.native.sync_helper_snapshot(captured,actual,posts)
 var invalid=captured.duplicate(true);invalid.hp.resize(1);var held=actual.duplicate(true);var held_posts=posts.duplicate(true)
 check(army.native.sync_helper_snapshot(invalid,actual,posts)==-1 and actual==held and posts==held_posts,"Malformed capture is rejected before any owner rows/posts change")
 army.clear();var empty:Dictionary=army.native.capture_helper_snapshot()
 check(army.native.sync_helper_snapshot(empty,actual,posts)==0 and actual=={900:{"id":900,"hp":999,"pos":Vector3.ZERO}} and posts.is_empty(),"Cleared capture retires previous paid rows while preserving foreign defenders")
 finish(army)
func finish(army):
 army.free();print("ARMY_HELPER_SNAPSHOT_RESULT checks=",checks," failures=",failures);quit(1 if failures else 0)
