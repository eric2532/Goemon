extends SceneTree
const Runtime=preload("res://scripts/forest/crowd/army_runtime.gd")
var checks=0
var failures=0
func check(ok:bool,label_:String):
 checks+=1
 if not ok:failures+=1;printerr("FAIL: ",label_)
func _initialize():run.call_deferred()
func run():
 var source=Runtime.new();source.configure(null);source.native.set_parallel_movement(false)
 var worker=Runtime.new();worker.configure(null);worker.native.set_parallel_movement(true);worker.native.simulation_profile(true)
 var heights=PackedFloat32Array();var covered=PackedByteArray()
 for z in 33:
  for x in 33:heights.append((x*3-48)*.05);covered.append(1)
 var data={"width":33,"spacing":3.0,"origin":Vector3(-48,0,-48),"heights":heights,"covered":covered,"pieces":PackedFloat32Array()}
 data.layer_min=PackedVector3Array([Vector3(-36,8,-18)]);data.layer_max=PackedVector3Array([Vector3(36,8,18)])
 data.obstacle_min=PackedVector3Array([Vector3(-1,0,-16)]);data.obstacle_max=PackedVector3Array([Vector3(1,6,16)])
 data.friendly_navigation=true;data.friendly_obstacle_min=PackedVector3Array();data.friendly_obstacle_max=PackedVector3Array()
 var goals={"goal_handles":PackedInt64Array(),"goal_positions":PackedVector3Array(),"goal_speeds":PackedFloat32Array()}
 for army in [source,worker]:
  army.set_navigation(1,data)
  for i in 256:
   var x=-30+(i%16)*4;var z=-24+((i/16)%16)*3;var upper=i%3==0 and abs(z)<17
   var point=Vector3(x,8 if upper else x*.05,z)
   var h:int=army.spawn((i+1)*(1 if i%2==0 else -1),i%2,0 if i%2==0 else 11,point,192,.4)
   if army==source:goals.goal_handles.append(h);goals.goal_positions.append(Vector3(-x,point.y,-z));goals.goal_speeds.append(6+(i%5))
 for tick in 180:
  if tick==90:
   data.obstacle_min=PackedVector3Array();data.obstacle_max=PackedVector3Array()
   source.set_navigation(2,data);worker.set_navigation(2,data)
  var delta=.05 if tick%17==0 else 1.0/60
  source.step(delta,goals);worker.step(delta,goals)
  check(source.render_snapshot()==worker.render_snapshot(),"Parallel movement preserves exact slopes, overlapping bridge supports, friendly gate access, routes and topology invalidation")
 check(worker.native.simulation_profile(false).movement_jobs>=180,"The terrain comparison exercises actual concurrent movement jobs")
 source.free();worker.free();print("ARMY_PARALLEL_TERRAIN_RESULT checks=",checks," failures=",failures);quit(1 if failures else 0)
