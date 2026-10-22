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
 if not runtime.native.has_method("query_stats"):
  check(false,"Native query diagnostics expose candidate work by team");finish(runtime);return
 var model=preload("res://scripts/forest/forest_model.gd").new();model.reset(42,{}, {},false)
 runtime.configure_kits(preload("res://scripts/forest/crowd/army_kit_data.gd").from_model(model))
 var enemy=runtime.spawn(1,0,0,Vector3.ZERO,192,3.9)
 for i in 2000:runtime.spawn(-1000-i,1,12,Vector3(3,60,0) if i==0 else Vector3(30+i*.007,0,30),200,.4)
 runtime.native.set_targets({"ids":PackedInt64Array([100]),"kinds":PackedInt32Array([2]),"positions":PackedVector3Array([Vector3(60,0,0)]),"hp":PackedFloat32Array([1000]),"minimum":PackedVector3Array([Vector3(59,0,-1)]),"maximum":PackedVector3Array([Vector3(61,6,1)])})
 runtime.native.query_stats(true);runtime.step(1.0/60,{})
 var stats=runtime.native.query_stats(false)
 check(runtime.unit_state(enemy).target_id==-1000,"Source nearest-objective choice retains horizontal range despite vertical height")
 check(stats.ally_candidates<32,"Soldier nearest targeting stops after proving a local winner instead of fitting2000 distant allies")
 # Equal-distance ties retain the original sorted native query order.
 runtime.set_pose(runtime.handles[-1001],Vector3(-3,0,0),0);runtime.set_pose(enemy,Vector3(0,0,10),0)
 runtime.native.set_guard(enemy,Vector3(0,0,10),0);runtime.step(1.0/60,{})
 check(runtime.unit_state(enemy).target_id==-1001,"Equal-distance root targets preserve logical-ID ordering")
 runtime.clear()
 for i in 2000:runtime.spawn(2000-i,0,0,Vector3(20+(i%40)*.1,0,20+(i/40)*.1),192,3.9)
 var ally=runtime.spawn(-1,1,11,Vector3.ZERO,200,.4)
 runtime.native.set_guard(ally,Vector3.ZERO,200)
 runtime.native.query_stats(true);runtime.step(1.0/60,{})
 var nearest_work=runtime.native.query_stats(false)
 check(nearest_work.get("enemy_sorted_items",-1)==0,"Nearest-body selection does not sort dense candidate lists; ties are compared explicitly")
 check(runtime.unit_state(ally).target_id>0,"Dense nearest-body query still acquires a real soldier")
 finish(runtime)
func finish(runtime):
 runtime.free();print("ARMY_TARGET_QUERY_COST_RESULT checks=",checks," failures=",failures);quit(1 if failures else 0)
