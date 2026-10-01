extends SceneTree
const PACK="res://asset_packs/cedar_pass/"
var lab
var failures=[]
var report={"controller":"res://scripts/player.gd","camera_base":"res://scripts/camera.gd","rooms":{},"failures":[]}
var walked=0.0
func check(ok,message):
 if not ok:failures.append(message);print("FAIL: ",message)
func _initialize():call_deferred("run")
func tick():
 var prev=lab.player.global_position
 await physics_frame
 lab.update_cutaway();lab.camera_rig._process(1.0/60.0)
 walked+=prev.distance_to(lab.player.global_position)
 check(lab.player.jumps_used==0,"Unexpected jump")
 check(lab.player.hp==100,"Unexpected fall / checkpoint reset")
func at(id,p):
 lab.player.set_physics_process(false);lab.player.global_position=lab.rooms[id].root.global_position+p;lab.player.velocity=Vector3.ZERO;lab.player.smoke_move=Vector2.ZERO;lab.player.jumps_used=0;lab.player.jump_buffer=0;lab.player.hp=100
 lab.camera_rig.reset_follow();lab.player.set_physics_process(true)
 for i in range(24):await tick()
func go(id,point,max_ticks=700):
 var goal=lab.rooms[id].root.global_position+point;var reached=false
 for i in range(max_ticks):
  var delta=goal-lab.player.global_position;delta.y=0
  if delta.length()<.13:reached=true;break
  var local=delta.normalized().rotated(Vector3.UP,-lab.camera_rig.yaw)
  lab.player.smoke_move=Vector2(local.x,local.z)*minf(1,delta.length()/.85)
  await tick()
 if not reached:print("MISSED ",id," goal=",goal," actual=",lab.player.global_position)
 lab.player.smoke_move=Vector2.ZERO
 for i in range(8):await tick()
 return reached
func run():
 Engine.physics_ticks_per_second=240;Engine.time_scale=4
 lab=load(PACK+"interior_lab/lab.gd").new();root.add_child(lab);lab.test_mode=true;lab.player.smoke_mode=true;lab.camera_rig.set_process(false)
 await physics_frame
 var capsule=lab.player.get_children().filter(func(n):return n is CollisionShape3D)[0].shape
 check(is_equal_approx(capsule.radius,.38) and is_equal_approx(capsule.height,1.85),"Actual Hero capsule")
 report["capsule_radius"]=capsule.radius;report["capsule_height"]=capsule.height;report["run_speed"]=lab.tuning.walk_speed;report["player_script_sha256"]=FileAccess.get_sha256("res://scripts/player.gd");report["camera_script_sha256"]=FileAccess.get_sha256("res://scripts/camera.gd")
 var ids=lab.rooms.keys()
 if "--inn-only" in OS.get_cmdline_user_args():ids=["inn"]
 if "--checkpoint" in OS.get_cmdline_user_args():ids=["machiya_open"]
 for id in ids:
  var r=lab.rooms[id];var d=r.data;var result={"repeated_routes":0,"diagonal_entries":0,"furniture_tests":0,"camera_samples":0,"jump_inputs":0}
  lab.camera_rig.yaw=0;Input.action_release("walk_modifier")
  for repeat in range(3):
   await at(id,Vector3(0,.42,d.body_depth/2+3))
   for xy in d.route_blender:
    var ok=await go(id,Vector3(xy[0],d.floor_height,-xy[1]))
    check(ok,id+" route target "+str(xy))
   result.repeated_routes+=1
  for sign in [-1,1]:
   await at(id,Vector3(sign*2.7,.42,d.body_depth/2+3))
   check(await go(id,Vector3(0,.36,d.body_depth/2-1.5)),id+" diagonal entry")
   check(await go(id,Vector3(sign*2.7,0,d.body_depth/2+3)),id+" diagonal exit")
   result.diagonal_entries+=1
  Input.action_press("walk_modifier")
  await at(id,Vector3(0,.42,d.body_depth/2+2.8))
  check(await go(id,Vector3(0,.36,0)),id+" slow walk entry")
  check(await go(id,Vector3(0,0,d.body_depth/2+2.8)),id+" slow walk exit")
  Input.action_release("walk_modifier")
  for test in d.furniture_tests:
   await at(id,Vector3(test.start[0],.42,-test.start[1]))
   var target=Vector3(test.toward[0],0,-test.toward[1]);var start=Vector3(test.start[0],0,-test.start[1]);var direction=(target-start).normalized()
   lab.player.smoke_move=Vector2(direction.x,direction.z)
   for i in range(90):await tick()
   lab.player.smoke_move=Vector2.ZERO
   var pos=lab.player.global_position-r.root.global_position
   var reached_target=Vector2(pos.x-target.x,pos.z-target.z).length()<.3
   check(not reached_target,id+" furniture must block traversal")
   check(await go(id,start),id+" can back away from furniture")
   result.furniture_tests+=1
  # Push into each diagonal boundary, then walk the recorded route back.
  # This checks recovery from furniture/wall corners without teleporting out.
  result["corner_recoveries"]=0
  Input.action_press("walk_modifier")
  for direction in [Vector2(-1,-1),Vector2(1,-1),Vector2(-1,1),Vector2(1,1)]:
   await at(id,Vector3(0,.42,0))
   var breadcrumb=[]
   lab.player.smoke_move=direction.normalized()
   for i in range(120):
    if i%12==0:breadcrumb.append(lab.player.global_position-r.root.global_position)
    await tick()
   lab.player.smoke_move=Vector2.ZERO
   breadcrumb.reverse()
   var recovered=true
   for point in breadcrumb:
    if not await go(id,point,180):recovered=false;break
   check(recovered and await go(id,Vector3(0,.36,0)),id+" corner recovery "+str(direction))
   result.corner_recoveries+=1
  Input.action_release("walk_modifier")
  Input.action_press("sprint")
  await at(id,Vector3(0,.42,d.body_depth/2+3))
  check(await go(id,Vector3(0,.36,0)),id+" sprint entry")
  check(await go(id,Vector3(0,0,d.body_depth/2+3)),id+" sprint exit")
  Input.action_release("sprint")
  result["sprint_entry_exit"]=true
  # Actual camera sampled at four yaw directions inside. Hidden wall collisions
  # remain on player mask; visual obstruction probes use separate layer 8.
  await at(id,Vector3(0,.42,0))
  for yaw in [0,PI/2,PI,-PI/2]:
   lab.camera_rig.yaw=yaw
   for i in range(45):await tick()
   var camera=lab.camera_rig.camera;var p=lab.player.global_position+Vector3.UP*1.2
   check(not camera.is_position_behind(p),id+" camera faces player")
   check(camera.global_position.distance_to(p)>1.5,id+" readable camera distance")
   var ray=PhysicsRayQueryParameters3D.create(p,camera.global_position,8);var hit=lab.get_world_3d().direct_space_state.intersect_ray(ray)
   check(hit.is_empty(),id+" visible architecture does not obscure player")
   result.camera_samples+=1
  lab.camera_rig.yaw=0
  if id=="inn":
   var stair_failures_before=failures.size()
   await at(id,Vector3(3.65,.42,2.6))
   check(await go(id,Vector3(3.65,3.66,-2.6)),"Inn stair ascent")
   check(lab.player.global_position.y>3.45,"Inn reached upper floor")
   check(await go(id,Vector3(1.9,3.66,-2.6)),"Inn landing turn")
   check(await go(id,Vector3(1.9,3.66,0)),"Inn upstairs corridor approach")
   check(await go(id,Vector3(-3.2,3.66,0)),"Inn clear route to both guest futons")
   check(lab.player.global_position.y>3.45,"Inn guest corridor stays on upper floor")
   check(await go(id,Vector3(1.9,3.66,0)),"Inn upstairs corridor return")
   check(await go(id,Vector3(1.9,3.66,-2.6)),"Inn upstairs landing approach")
   check(await go(id,Vector3(3.65,3.66,-2.6)),"Inn return to stair")
   check(await go(id,Vector3(3.65,.36,2.6)),"Inn stair descent")
   check(lab.player.global_position.y<.55,"Inn descent reaches ground floor")
   check(await go(id,Vector3(1.6,.36,2.6)),"Inn bottom landing turn")
   result["stairs_no_jump"]=failures.size()==stair_failures_before
  report.rooms[id]=result;print("ROOM_COMPLETE ",id," failures=",failures.size())
 report["walked_metres"]=walked;report.failures=failures
 var report_name="interior_walk_inn.json" if "--inn-only" in OS.get_cmdline_user_args() else ("interior_walk_checkpoint.json" if "--checkpoint" in OS.get_cmdline_user_args() else "interior_walk.json")
 FileAccess.open(PACK+"verification/"+report_name,FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
 print("INTERIOR_WALK_RESULT failures=",failures.size()," travelled=",walked)
 quit(0 if failures.is_empty() else 1)
