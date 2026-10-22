extends SceneTree
const Runtime=preload("res://scripts/forest/crowd/army_runtime.gd")
var checks=0
var failures=0
func check(ok:bool,label_:String):
 checks+=1
 if not ok:failures+=1;printerr("FAIL: ",label_)
func _initialize():run.call_deferred()
func run():
 var source=Runtime.new();source.configure(null)
 var worker=Runtime.new();worker.configure(null)
 if not worker.native.has_method("begin_step") or not worker.native.has_method("finish_step"):
  check(false,"Native worker offers explicit submission and completion barriers");finish(source,worker);return
 source.native.set_parallel_movement(false);worker.native.set_parallel_movement(true);worker.native.simulation_profile(true)
 var model=preload("res://scripts/forest/forest_model.gd").new();model.reset(42)
 var kits=preload("res://scripts/forest/crowd/army_kit_data.gd").from_model(model)
 for army in [source,worker]:
  army.set_navigation(1,{"width":0});army.configure_kits(kits)
  for i in 2000:
   var point=Vector3((i%50)*2-50,0,(i/50)*2+15)
   army.spawn(i+1,0,[0,1,3][i%3],point,192,3.9)
   var h:int=army.spawn(-i-1,1,[11,5,8,10,7][i%5],point+Vector3(0,0,-30),200,.4)
   army.native.set_guard(h,point+Vector3(0,0,-30),18)
 var activity={}
 for i in 60:
  source.step(1.0/60,{})
  check(worker.native.begin_step(1.0/60),"Every positive simulation delta is submitted")
  # These two helpers use only their input arrays/dictionaries and may overlap.
  var captured=worker.native.collector_snapshot({"pos":Vector3(1,0,2),"hp":100},{},{},10,1,3)
  var nearby=worker.native.nearby_points(captured.positions,Vector3.ZERO,20)
  check(captured.valid and captured.ids==["player"] and nearby==PackedInt64Array([0]),"Pure coin helpers remain valid during an outstanding simulation job")
  # Reading state must join automatically; callers cannot observe a half-step.
  check(worker.render_snapshot()==source.render_snapshot(),"Barrier-protected reads retain every packed combat/movement field exactly")
  var expected_events=source.native.take_events();var actual_events=worker.native.take_events()
  for event in expected_events:activity[event.kind]=int(activity.get(event.kind,0))+1
  check(actual_events==expected_events,"Ordered attacks, damage, deaths and projectile events match synchronous simulation")
 check(activity.get("damage",0)>0 and activity.get("death",0)>0 and activity.get("bullet",0)>0,"Full independent armies perform real attacks, kills and projectiles during comparison")
 check(worker.native.simulation_profile(false).movement_jobs==60,"Every full-capacity movement step joins both teams before attack resolution")
 source.step(.05,{});worker.native.begin_step(.05)
 var h:int=source.render_snapshot().handles[0]
 var hit={"amount":.125,"element":"ice","status_seconds":.1}
 var expected=source.native.apply_hit(h,hit)
 check(expected.accepted,"The barrier hit fixture exercises a live target")
 check(worker.native.apply_hit(h,hit)==expected,"A synchronous hit waits for pending movement and applies exactly once")
 check(worker.render_snapshot()==source.render_snapshot(),"Post-hit HP, status and pose agree after the automatic barrier")
 worker.native.begin_step(.05);worker.native.clear()
 check(worker.render_snapshot().handles.is_empty(),"Clear joins pending work before retiring all slots")
 worker.native.begin_step(.05);worker.native.finish_step()
 check(worker.render_snapshot().handles.is_empty(),"Explicit completion cannot resurrect cleared state")
 finish(source,worker)
func finish(source,worker):
 source.free();worker.free();print("ARMY_WORKER_RESULT checks=",checks," failures=",failures);quit(1 if failures else 0)
