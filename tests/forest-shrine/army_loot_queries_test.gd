extends SceneTree
var checks=0
var failures=0
func check(ok,label_):
 checks+=1
 if not ok:failures+=1;printerr("FAIL: ",label_)
func _initialize():run.call_deferred()
func model():
 var m=load("res://scripts/forest/forest_model.gd").new();m.reset(42,{}, {"buildings":[],"trees":[],"deposits":[]},false);m.phase="wave";return m
func run():
 var army=load("res://scripts/forest/crowd/army_runtime.gd").new();army.configure(null)
 if not army.native.has_method("nearby_points"):
  check(false,"Loot selection needs native nearest-first filtering of captured collector points");army.free();finish();return
 var points=PackedVector3Array([Vector3(2,1,0),Vector3(-2,1,0),Vector3(0,1,0),Vector3(0,11,0)])
 check(army.native.nearby_points(points,Vector3(0,1,0),10)==PackedInt64Array([2,1,0,3]),"Nearest collector filtering retains the original cell-order tie and inclusive radius")
 var source=model();var native=model();native.army_runtime=army
 var collectors=[];seed(81121)
 for i in 300:collectors.append({"id":"ally_%d"%i,"pos":Vector3(randf_range(-30,30),0,randf_range(40,80)),"hp":100,"active":i%13!=0})
 for i in 30:
  var enemy={"id":i+10000,"variant":[0,1,3][i%3],"hp":0,"pos":Vector3(randf_range(-30,30),0,randf_range(40,80))}
  source.ryo.spawn_enemy_drop(enemy);native.ryo.spawn_enemy_drop(enemy)
 var counts={"source":0,"native":0,"ordered":0}
 var clear_source=func(_a,b):counts.source+=1;return b.x<10
 var clear_native=func(_a,b):counts.native+=1;return b.x<10
 for frame in 180:
  source.ryo.tick(1.0/60,collectors,false,clear_source);native.ryo.tick(1.0/60,collectors,false,clear_native)
  check(source.gold==native.gold and source.ryo.drops.keys()==native.ryo.drops.keys(),"Packed loot keeps exact pickup value and live drop identities")
  var same=true
  for id in source.ryo.drops:
   var a=source.ryo.drops[id];var b=native.ryo.drops[id]
   same=same and a.pos.distance_to(b.pos)<.00001 and a.target_id==b.target_id and a.value==b.value
  check(same,"Packed loot keeps exact trajectories and selected collectors through covered candidates")
 check(counts.native>0 and counts.native<=counts.source,"Native nearest-first search does not add speculative cover rays")
 # Force an unlucky collector insertion order to prove that fitted scenery
 # rays follow nearest-first order without changing the resulting recipient.
 var costs=model();costs.army_runtime=army;var descending=[]
 for i in 1000:descending.append({"id":str(i),"pos":Vector3(9-float(i)*.008,0,60),"hp":100})
 costs.ryo.spawn_enemy_drop({"id":10000,"variant":0,"hp":0,"pos":Vector3(0,0,60)})
 var clear=func(_a,_b):counts.ordered+=1;return true
 costs.ryo.tick(.2,descending,false,clear)
 check(counts.ordered==1,"One coin uses one exact cover ray rather than fitting every progressively closer collector")
 army.free();finish()
func finish():
 print("ARMY_LOOT_QUERIES_RESULT checks=",checks," failures=",failures);quit(1 if failures else 0)
