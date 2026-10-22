extends SceneTree
var checks=0
var failures=0
func check(ok:bool,label_:String):
 checks+=1
 if not ok:failures+=1;printerr("FAIL: ",label_)
func _initialize():run.call_deferred()
func run():
 var path="res://tests/forest-shrine/army_benchmark_metrics.gd"
 if not ResourceLoader.exists(path):check(false,"Real-battle acceptance must reject idle, paused, underpopulated and dropped-time measurements");finish();return
 var metrics=load(path)
 var good={"enemies":2000,"allies":2000,"minimum_enemies":2000,"minimum_allies":2000,"wall_seconds":60.0,"simulation_seconds":60.0,"frames":3600,"attacks":4000,"damage_events":6000,"deaths":1000,"replacements":1000,"foreground":true,"normal_stats":true,"frame_ms":[16.0,17.0,16.5,18.0],"dropped_hits":0}
 good.frame_ms.resize(3600);good.frame_ms.fill(1000.0/60);good.activity=[]
 for i in 6:good.activity.append({"seconds":10.0,"attacks":100,"damage_events":150,"deaths":20})
 check(metrics.violations(good).is_empty(),"A full-population normal-stat active battle can pass")
 for key in ["attacks","damage_events","deaths"]:
  var bad=good.duplicate(true);bad[key]=0;check(not metrics.violations(bad).is_empty(),"Idle-only measurement fails without "+key)
 for key in ["minimum_enemies","minimum_allies"]:
  var bad=good.duplicate(true);bad[key]=1999;check(not metrics.violations(bad).is_empty(),"An underpopulated "+key+" measurement fails")
 for seconds in [0.0,30.0,59.0]:
  var bad=good.duplicate(true);bad.simulation_seconds=seconds;check(not metrics.violations(bad).is_empty(),"Paused/dropped simulation time fails: %.1f"%seconds)
 for key in ["foreground","normal_stats"]:
  var bad=good.duplicate(true);bad[key]=false;check(not metrics.violations(bad).is_empty(),"Diagnostic fixture cannot claim real acceptance: "+key)
 var dropped=good.duplicate(true);dropped.dropped_hits=1;check(not metrics.violations(dropped).is_empty(),"No omitted gameplay hit may count as success")
 var slow=good.duplicate(true);slow.frames=1200;slow.frame_ms=[20,40,80,120];check(not metrics.violations(slow).is_empty(),"Frame-time gates reject a slow full-size battle")
 for key in ["attacks","damage_events","deaths"]:
  var bad=good.duplicate(true);bad.activity.back()[key]=0
  check(not metrics.violations(bad).is_empty(),"A battle that becomes idle after initial warmup fails sustained "+key)
 var soak=good.duplicate(true);soak.wall_seconds=600;soak.simulation_seconds=600;soak.frames=36000
 soak.frame_ms.resize(36000);soak.frame_ms.fill(1000.0/60);soak.activity=[]
 for i in 60:soak.activity.append({"seconds":10.0,"attacks":100,"damage_events":150,"deaths":20})
 soak.memory_samples=[[300,300000000,8000,1100],[400,301000000,8001,1100],[500,302000000,8002,1100],[600,303000000,8003,1100]]
 check(metrics.violations(soak).is_empty(),"A bounded full-population ten-minute resource soak can pass")
 for pair in [[1,100000000],[2,1000],[3,100]]:
  var bad=soak.duplicate(true);bad.memory_samples.back()[pair[0]]+=pair[1]
  check(not metrics.violations(bad).is_empty(),"A soak rejects accumulating memory/nodes/resources column%d"%pair[0])
 var runtime=load("res://scripts/forest/crowd/army_runtime.gd").new();runtime.configure(null)
 var model=load("res://scripts/forest/forest_model.gd").new();model.reset(42,{}, {},false)
 runtime.configure_kits(load("res://scripts/forest/crowd/army_kit_data.gd").from_model(model));runtime.set_navigation(1,{"width":0})
 var previous=PackedInt64Array()
 for cycle in 4:
  for i in 2000:
   runtime.spawn(i+1,0,[0,1,3][i%3],Vector3((i%50)*1.2,0,(i/50)*1.2),192,3.9)
   runtime.spawn(-i-1,1,[11,5,7,8,10][i%5],Vector3((i%50)*1.2,0,2+(i/50)*1.2),200,.4)
  var snapshot=runtime.snapshot();check(snapshot.handles.size()==4000,"Recycle%d preserves every independent unit"%cycle)
  for h in previous:check(not runtime.valid(h),"Recycled generation cannot revive a stale handle")
  runtime.step(.25,{});var events=runtime.take_events();check(not events.is_empty(),"Normal-stat full crowd produces independent combat events")
  previous=snapshot.handles.slice(0,8);runtime.clear()
  check(runtime.snapshot().handles.is_empty() and runtime.render_snapshot().projectile_ids.is_empty() and runtime.take_events().is_empty(),"Recycle%d clears bodies, casts and event ownership"%cycle)
 runtime.free();finish()
func finish():
 print("LARGE_ARMY_STABILITY_RESULT checks=",checks," failures=",failures);quit(1 if failures else 0)
