extends SceneTree
var checks=0
var failures=0
func check(ok:bool,label_:String):
 checks+=1
 if not ok:failures+=1;printerr("FAIL: ",label_)
func _initialize():run.call_deferred()
func run():
 var path="res://scripts/forest/crowd/army_runtime.gd"
 if not ResourceLoader.exists(path):
  check(false,"Native army runtime is missing");finish();return
 var runtime=load(path).new();runtime.configure(null,4000)
 var rows=[]
 for team in 2:
  for i in 2000:
   var id=(i+1)*(1 if team==0 else -1)
   var point=Vector3((i%50)*3,team*5,(i/50)*3)
   var radius=.25+float(i%7)*.2
   var handle:int=runtime.spawn(id,team,0 if team==0 else 11,point,100,radius)
   check(handle>0,"Each of the 4000 independent live slots can be allocated")
   rows.append({"id":id,"handle":handle,"team":team,"point":point,"radius":radius})
 check(runtime.spawn(99999,0,0,Vector3.ZERO,100,.4)==0,"A full enemy team explicitly rejects a 2001st unit")
 check(runtime.spawn(-99999,1,11,Vector3.ZERO,100,.4)==0,"A full ally team explicitly rejects a 2001st unit")
 var snapshot=runtime.snapshot()
 check(snapshot.handles.size()==4000 and snapshot.teams.count(0)==2000 and snapshot.teams.count(1)==2000,"Both complete 2000-unit armies are independently represented")
 var rng=RandomNumberGenerator.new();rng.seed=1234
 for trial in 100:
  var box=AABB(Vector3(rng.randf_range(-4,148),rng.randf_range(-5,8),rng.randf_range(-4,118)),Vector3(5,4,7))
  var team=trial%2;var expected=[]
  var ordered=rows.filter(func(row):return row.team==team)
  ordered.sort_custom(func(a,b):return a.id<b.id)
  for row in ordered:
   var pad=Vector3.ONE*row.radius
   if AABB(row.point-pad,pad*2).intersects(box):expected.append(row.handle)
  check(Array(runtime.query_aabb(box,team))==expected,"Spatial query matches brute-force bounds and stable tie order")
 var original:int=rows[0].handle
 runtime.despawn(original)
 var replacement:int=runtime.spawn(99999,0,0,Vector3.ZERO,100,.4)
 check(replacement>0 and replacement!=original and not runtime.valid(original),"Recycling a slot cannot revive an old projectile victim handle")
 check(not runtime.valid(-1) and not runtime.valid(9223372036854775807),"Malformed or unknown handles are safely rejected")
 check(snapshot.handles.size()==4000 and snapshot.handles[0]==original,"Published snapshots survive mutation of native live state")
 check(runtime.query_aabb(AABB(Vector3(NAN,0,0),Vector3.ONE),0).is_empty(),"Non-finite query geometry fails safely")
 runtime.clear()
 check(runtime.snapshot().handles.is_empty() and not runtime.valid(replacement),"Clearing an army invalidates all live handles")
 runtime.configure(null,4000)
 var fresh:int=runtime.spawn(1,0,0,Vector3.ZERO,10,.4)
 check(fresh!=original and fresh!=replacement,"Reconfiguration cannot resurrect handles from a previous run")
 runtime.clear();runtime.free();finish()
func finish():
 print("ARMY_RUNTIME_RESULT checks=",checks," failures=",failures);quit(1 if failures else 0)
