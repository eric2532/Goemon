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
 var model=preload("res://scripts/forest/forest_model.gd").new();model.reset(42,{}, {},false)
 runtime.configure_kits(preload("res://scripts/forest/crowd/army_kit_data.gd").from_model(model))
 var ice=runtime.spawn(1,0,0,Vector3.ZERO,192,3.9)
 var slow=runtime.spawn(2,0,0,Vector3(20,0,0),192,3.9)
 var flinch=runtime.spawn(3,0,0,Vector3(40,0,0),192,3.9)
 var ally=runtime.spawn(-1000,1,11,Vector3(60,0,0),200,.4)
 var old=runtime.render_snapshot()
 runtime.apply_hit(ice,{"amount":0,"element":"ice","status_seconds":1.0})
 runtime.apply_hit(slow,{"amount":0,"element":"slow","slow_factor":.5,"status_seconds":1.0})
 runtime.apply_hit(flinch,{"amount":0,"flinch":.2})
 runtime.apply_hit(ally,{"amount":.125})
 var data=runtime.render_snapshot()
 for pair in [[ice,1],[slow,2],[flinch,4],[ally,8]]:
  var index:int=data.handles.find(pair[0])
  check(index>=0 and data.status[index]&pair[1]!=0,"Synchronous hit exports current ice/slow/flinch/invulnerability without advancing simulation")
 check(old.status==PackedInt32Array([0,0,0,0]) and data.hp[3]==199.875,"Earlier snapshots remain owned and fractional damage remains exact")
 runtime.step(1.1,{})
 check(runtime.render_snapshot().status==PackedInt32Array([0,0,0,0]),"Original status expiry still advances only with physics time")
 runtime.free();print("ARMY_STATUS_SYNC_RESULT checks=",checks," failures=",failures);quit(1 if failures else 0)
