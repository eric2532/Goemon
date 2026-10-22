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
 if not runtime.native.has_method("simulation_profile"):
  check(false,"Native subphase attribution is available");finish(runtime);return
 var initial=runtime.native.simulation_profile(false)
 check(not initial.enabled and initial.steps==0,"Native timing is disabled for ordinary gameplay")
 runtime.spawn(1,0,0,Vector3.ZERO,192,3.9);runtime.spawn(-1,1,11,Vector3(0,0,20),200,.4)
 runtime.native.simulation_profile(true);var old=runtime.render_snapshot()
 for i in 120:runtime.step(1.0/60,{})
 var data=runtime.native.simulation_profile(false)
 check(data.enabled and data.steps==120,"Every real native substep is counted once")
 check(data.grid_ms>=0 and data.decisions_ms>=0 and data.movement_ms>=0 and data.combat_ms>=0 and data.animation_ms>=0,"Measured native subphases are nonnegative wall durations")
 check(data.total_ms>=data.grid_ms+data.decisions_ms+data.movement_ms+data.combat_ms+data.animation_ms-.001,"Subphase durations fit inside the measured full-step duration")
 check(runtime.render_snapshot().hp==old.hp,"Instrumentation does not advance or alter combat itself")
 runtime.native.simulation_profile(true);check(runtime.native.simulation_profile(false).steps==0,"Warmup attribution can be reset independently of simulation")
 finish(runtime)
func finish(runtime):
 runtime.free();print("ARMY_STEP_PROFILE_RESULT checks=",checks," failures=",failures);quit(1 if failures else 0)
