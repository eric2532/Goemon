extends SceneTree
const Runtime=preload("res://scripts/forest/crowd/army_runtime.gd")
var checks=0
var failures=0
func check(ok:bool,label_:String):
 checks+=1
 if not ok:failures+=1;printerr("FAIL: ",label_)
func _initialize():run.call_deferred()
func run():
 var runtime=Runtime.new();runtime.configure(null)
 if not runtime.native.has_method("sync_helper_mirrors"):
  check(false,"Native paid-ally mirror batch is available");finish(runtime);return
 var rows={-55:{"id":-55,"foreign":true}};var posts={};var handles=[]
 for i in 2000:
  var id=-1000-i;var point=Vector3(i,2,3);var handle=runtime.spawn(id,1,11,point,200,.4)
  runtime.native.set_guard(handle,point+Vector3(1,0,2),18);handles.append(handle)
 check(runtime.native.sync_helper_mirrors(rows,posts)==2000,"All2000 independent paid allies retain population and food ownership")
 check(posts.keys()==range(-1000,-3000,-1) and rows.keys().slice(1)==posts.keys(),"Post and target insertion order matches paid pool creation order")
 var row:Dictionary=rows[-1000];row.retained=true
 runtime.set_pose(handles[0],Vector3(4,5,6),1.0);runtime.native.apply_hit(handles[0],{"amount":.125})
 check(runtime.native.sync_helper_mirrors(rows,posts)==2000 and is_same(row,rows[-1000]) and row.retained,"Existing target rows remain the same owned objects")
 check(row.pos==Vector3(4,5,6) and row.hp==199.875 and row.targetable and not row.taunting,"Live pose, fractional HP and targetability remain exact")
 runtime.despawn(handles[0]);check(runtime.native.sync_helper_mirrors(rows,posts)==1999 and not rows.has(-1000) and not posts.has(-1000),"Dead handles retire targeting and food posts immediately")
 var fresh=runtime.spawn(-1000,1,11,Vector3(7,8,9),200,.4);runtime.native.set_guard(fresh,Vector3(9,8,7),18)
 runtime.native.sync_helper_mirrors(rows,posts)
 check(posts.keys()[0]==-1000 and rows[-1000].pos==Vector3(7,8,9) and posts[-1000]==Vector3(9,8,7),"Recycled native slots retain original paid-pool order and new placement")
 runtime.clear();check(runtime.native.sync_helper_mirrors(rows,posts)==0 and posts.is_empty() and rows=={-55:{"id":-55,"foreign":true}},"Clear removes only owned helper rows and preserves other defenders")
 runtime.spawn(-9,1,11,Vector3.ZERO,200,.4)
 check(runtime.native.sync_helper_mirrors(rows,posts)==0 and posts.is_empty(),"Unmanaged target fixtures do not acquire food or paid ownership")
 finish(runtime)
func finish(runtime):
 runtime.free();print("ARMY_NATIVE_HELPER_MIRROR_RESULT checks=",checks," failures=",failures);quit(1 if failures else 0)
