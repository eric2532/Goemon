extends SceneTree
var checks=0
var failures=0
var runtime
func check(ok:bool,label_:String):
 checks+=1
 if not ok:failures+=1;printerr("FAIL: ",label_)
func _initialize():run.call_deferred()
func field(slope:float=0)->Dictionary:
 var heights=PackedFloat32Array();var covered=PackedByteArray()
 for z in 33:
  for x in 33:heights.append((x*3-48)*slope);covered.append(1)
 return {"width":33,"spacing":3.0,"origin":Vector3(-48,0,-48),"heights":heights,"covered":covered,"obstacle_min":PackedVector3Array(),"obstacle_max":PackedVector3Array(),"layer_min":PackedVector3Array(),"layer_max":PackedVector3Array(),"pieces":PackedFloat32Array()}
func position(handle:int)->Vector3:
 var snapshot=runtime.snapshot();return snapshot.positions[snapshot.handles.find(handle)]
func move(handle:int,goal:Vector3,speed:float,steps:int):
 var context={"goal_handles":PackedInt64Array([handle]),"goal_positions":PackedVector3Array([goal]),"goal_speeds":PackedFloat32Array([speed])}
 for i in steps:runtime.step(1.0/60,context)
func run():
 runtime=load("res://scripts/forest/crowd/army_runtime.gd").new();runtime.configure(null)
 if not runtime.has_method("set_navigation") or not runtime.has_method("step"):
  check(false,"Shared terrain movement is missing from the native army runtime");runtime.free();finish();return
 var data=field(.1);runtime.set_navigation(1,data)
 var actor:int=runtime.spawn(1,0,0,Vector3(-18,-1.8,0),100,.4)
 for i in 120:
  var before=position(actor);move(actor,Vector3(18,1.8,0),6,1);var after=position(actor)
  check(absf(after.y-after.x*.1)<.0001,"Hill movement uses the original triangulated support height")
  check(after.distance_to(before)<=6.0/60+.0001,"Terrain following never exceeds authored movement speed")
 check(position(actor).x> -7,"Supported movement makes forward progress")
 runtime.clear();data=field();data.obstacle_min=PackedVector3Array([Vector3(-1,0,-1)]);data.obstacle_max=PackedVector3Array([Vector3(1,8,1)])
 runtime.set_navigation(2,data);actor=runtime.spawn(2,0,0,Vector3(-6,0,0),100,.4)
 var crossed=false
 for i in 240:
  move(actor,Vector3(6,0,0),6,1);var p=position(actor)
  var gap=Vector2(maxf(0,absf(p.x)-1),maxf(0,absf(p.z)-1))
  if gap.length()<.399:crossed=true
 check(not crossed and position(actor).distance_to(Vector3(6,0,0))<.3,"Shared routing goes around a wall without tunneling or teleporting")
 runtime.clear();data=field();data.obstacle_min=PackedVector3Array([Vector3(-1,0,-48)]);data.obstacle_max=PackedVector3Array([Vector3(1,8,48)])
 runtime.set_navigation(3,data);actor=runtime.spawn(3,0,0,Vector3(-6,0,0),100,.4)
 move(actor,Vector3(6,0,0),12,120)
 check(position(actor).x<= -1.39,"A closed gate spanning the route blocks the army")
 data.obstacle_min=PackedVector3Array();data.obstacle_max=PackedVector3Array();runtime.set_navigation(4,data)
 move(actor,Vector3(6,0,0),12,120)
 check(position(actor).distance_to(Vector3(6,0,0))<.2,"Opening the gate invalidates shared routes immediately")
 runtime.clear();data=field();data.layer_min=PackedVector3Array([Vector3(-12,5,-4)]);data.layer_max=PackedVector3Array([Vector3(12,5,4)])
 runtime.set_navigation(5,data)
 var lower:int=runtime.spawn(4,0,0,Vector3(-6,0,0),100,.3)
 var upper:int=runtime.spawn(-4,1,11,Vector3(-6,5,0),100,.3)
 move(lower,Vector3(6,0,0),6,120);move(upper,Vector3(6,5,0),6,120)
 check(absf(position(lower).y)<.001 and absf(position(upper).y-5)<.001,"Overlapping bridge and ground supports remain vertically separate")
 move(upper,Vector3(30,5,0),6,240)
 check(position(upper).x<12 and absf(position(upper).y-5)<.001,"An army cannot step off a bridge edge onto a lower surface")
 runtime.clear();data=field()
 for z in 33:
  for x in range(16,33):data.heights[z*33+x]=12
 runtime.set_navigation(6,data);actor=runtime.spawn(5,0,0,Vector3(-6,0,0),100,.4)
 move(actor,Vector3(9,12,0),12,120)
 check(position(actor).x<0 and absf(position(actor).y)<.001,"Steep terrain edges cannot become climbable through tiny simulation steps")
 var paused=position(actor);runtime.step(2,{"paused":true})
 check(position(actor)==paused,"Pause freezes native movement instead of accumulating a catch-up jump")
 if not runtime.has_method("navigation_data"):
  check(false,"The army needs a faithful exporter for the actual Kai map and saved rampart pieces")
 else:
  var doc=load("res://scripts/forest/forest_map_document.gd").new();doc.load_kai_highway()
  var model=load("res://scripts/forest/forest_model.gd").new();model.reset(42,{},doc.data,false)
  runtime.clear();runtime.set_navigation(7,runtime.navigation_data(model,false))
  var samples=0
  for z in range(2,model.terrain.width-2,3):
   if samples>=60:break
   for x in range(2,model.terrain.width-2,3):
    var point=Vector3(x*model.terrain.spacing-240,0,z*model.terrain.spacing-240);point.y=model.surface_height(point.x,point.z)
    var goal=point+Vector3(.05,0,0);goal.y=model.surface_height(goal.x,goal.z)
    if not model.terrain.disk_clear(point,.4) or not model.terrain.disk_clear(goal,.4) or not model.terrain.step_clear(point,goal):continue
    runtime.clear();actor=runtime.spawn(10,0,0,point,100,.4);move(actor,goal,6,1)
    var p=position(actor)
    check(absf(p.y-model.surface_height(p.x,p.z))<.0001 and p.distance_to(goal)<.001,"Actual Kai map movement agrees with source support geometry")
    samples+=1
    if samples>=60:break
  check(samples==60,"Actual-map support comparisons cover sixty distinct supported locations")
  var bridge_samples=0
  for index in model.terrain.bridges.size():
   if model.terrain.bridges[index]==0:continue
   var point=Vector3((index%model.terrain.width)*model.terrain.spacing-240,0,(index/model.terrain.width)*model.terrain.spacing-240)
   point.y=model.surface_height(point.x,point.z)
   var goal=point+Vector3(.05,0,0);goal.y=model.surface_height(goal.x,goal.z)
   if not model.terrain.disk_clear(point,.4) or not model.terrain.disk_clear(goal,.4) or not model.terrain.step_clear(point,goal):continue
   runtime.clear();actor=runtime.spawn(10,0,0,point,100,.4);move(actor,goal,6,1)
   check(position(actor).distance_to(goal)<.001,"Original Kai bridge decks retain their source support and entrance height")
   bridge_samples+=1
   if bridge_samples>=6:break
  check(bridge_samples>=3,"Actual Kai bridge geometry is included in the movement fixture")
  model.reset(42,{}, {},false);model.terrain.configure([{"ax":0,"az":0,"bx":10,"bz":0,"width":3,"h0":0,"h1":18}])
  runtime.clear();runtime.set_navigation(8,runtime.navigation_data(model,false))
  actor=runtime.spawn(11,0,0,Vector3(3,.9,0),100,.4)
  for i in 120:
   move(actor,Vector3(30,9,0),6,1);var p=position(actor)
   check(absf(p.y-model.surface_height(p.x,p.z))<.0001,"Saved analytic rampart slopes retain their original continuous geometry")
 runtime.clear();runtime.set_navigation(9,field())
 var first:int=runtime.spawn(100,0,0,Vector3.ZERO,100,.4)
 var second:int=runtime.spawn(101,0,0,Vector3.ZERO,100,.4)
 var context={"goal_handles":PackedInt64Array([first,second]),"goal_positions":PackedVector3Array([Vector3(12,0,0),Vector3(12,0,0)]),"goal_speeds":PackedFloat32Array([6,6])}
 for i in 60:
  var a=position(first);var b=position(second);runtime.step(1.0/60,context)
  check(position(first).distance_to(a)<=.1001 and position(second).distance_to(b)<=.1001,"Local crowd avoidance never increases either unit's authored speed")
 check(position(first).distance_to(position(second))>.02,"Coincident independent units separate instead of forming a permanent visual stack")
 runtime.free();finish()
func finish():
 print("ARMY_TERRAIN_RESULT checks=",checks," failures=",failures);quit(1 if failures else 0)
