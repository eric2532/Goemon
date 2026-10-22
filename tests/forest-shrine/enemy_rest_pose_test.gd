extends SceneTree
## Resting parts keep exactly the same contacts, including frozen and planted poses.
const Crowd=preload("res://scripts/forest/forest_enemy_crowd.gd")
const Roles=preload("res://scripts/forest/forest_enemy_roles.gd")
const HEIGHTS=Roles.HEIGHTS
var checks=0
var failures=0
func _initialize():run.call_deferred()
func check(ok:bool,label_:String):
 checks+=1
 if not ok:failures+=1;printerr("FAIL: ",label_)
# Frozen reference from the full pose evaluator before the identity shortcut.
# It evaluates every authored stage; it contains no stationary-part shortcut.
static func reference_pose(group: String,data: Dictionary)->Transform3D:
 if int(data.get("variant",0))==Roles.BOSS:return Transform3D.IDENTITY
 if data.get("frozen",0.0)>0 and data.has("frozen_pose"):data=data.frozen_pose
 if group in ["foot_l","foot_r"] and data.get("walk_feet",{}).has(group):return data.walk_feet[group]
 var kind=clampi(int(data.get("variant",0)),0,3)
 var phase=float(data.get("walk_phase",0.0))
 var progress=float(data.get("attack_progress",0.0))
 var action=str(data.get("action","walk"))
 var moving=1.0 if absf(phase)>.00001 else 0.0
 if data.has("velocity"):
  var velocity: Vector3=data.velocity
  moving=clampf(Vector2(velocity.x,velocity.z).length()/float(Roles.DATA[kind].speed),0,1)
 var motion=float(data.get("pose_motion",moving))
 var recoil=float(data.get("hit_recoil",0.0))
 if recoil>0:motion=0.0
 if action=="windup":motion*=1.0-smoothstep(0.0,.2,maxf(0,progress))
 elif action=="recover":motion=0.0
 var pose=Transform3D.IDENTITY
 var giant=kind==2
 if group=="foot_l" or group=="foot_r":
  var offset_phase=phase+(PI if group=="foot_r" else 0)
  pose.origin=Crowd.walking_foot_offset(offset_phase,float(Roles.DATA[kind].stride),.7 if giant else (.6 if kind==3 else .26))*motion
  return pose
 if recoil>0 and not giant:
  # Tilt the body and carried weapon around the hips while the feet stay
  # grounded. Contact queries consume this exact same rigid transform.
  var direction: Vector3=Basis(Vector3.UP,float(data.get("facing",0))).inverse()*Vector3(data.get("hit_direction",Vector3.BACK))
  var axis=Vector3.UP.cross(direction)
  if axis.length_squared()>.001:
   var age=maxf(0,.28-recoil)
   var weight=sin(minf(1,age/.045)*PI*.5)*clampf(recoil/.28,0,1)
   var pivot=Vector3(0,HEIGHTS[kind]*.35,0)
   var basis=Basis(axis.normalized(),weight*(.27 if data.get("hit_heavy",false) else .18))
   return Transform3D(basis,pivot-basis*pivot+direction*weight*.08)
 var rock=sin(phase)*(.022 if giant else .018)*motion
 var pivot=Vector3(0,HEIGHTS[kind]*.35,0)
 pose.basis=Basis(Vector3.FORWARD,rock)
 pose.origin=pivot-pose.basis*pivot+Vector3(0,absf(sin(phase))*HEIGHTS[kind]*.003*motion,0)
 if kind==3:
  pose.origin.y+=absf(sin(phase))*.2*motion
  return pose
 if group=="body":return pose
 var left=group.ends_with("_l")
 var shoulder=Vector3((-8.5 if left else 8.5) if giant else (-.72 if left else .72),12.0 if giant else HEIGHTS[kind]*.59,0)
 var swing=-sin(phase+(0 if left else PI))*(.06 if giant else .24)*motion
 var rotation=Basis(Vector3.RIGHT,swing)
 var arm_pose=Transform3D(rotation,shoulder-rotation*shoulder)
 if kind==1 and absf(progress)>.00001:
  # Ranged contact remains at the worker; the hands draw the local bowstring.
  var draw=smoothstep(0,1,absf(progress))
  return Transform3D(Basis.IDENTITY,Vector3(.18,.75,-.75)*draw if left else Vector3(-1.3,.8,-.15)*draw)
 if not left and absf(progress)>.00001 and data.has("attack_point"):
  # Lift/retract through most of the windup, then drive to exact visible contact.
  var contact=Crowd._fist_contact(kind,false)
  var wind=clampf(progress,0,1)
  var extension=smoothstep(.62,1.0,wind) if progress>=0 else smoothstep(0,1,clampf(-progress,0,1))
  var local_target=Basis(Vector3.UP,float(data.get("facing",0))).inverse()*(Vector3(data.attack_point)-Vector3(data.get("pos",Vector3.ZERO)))
  var lift=sin(wind*PI)*(.9 if giant else .35)
  var delta=(local_target-contact)*extension+Vector3(0,lift,(1.0-extension)*sin(wind*PI)*(.7 if giant else .15))
  # Preserve painted fist geometry; only the short connecting arm extends.
  if group=="arm_r" and giant:
   var rest=contact-shoulder;var next=rest+delta
   var align=Basis(Quaternion(rest.normalized(),next.normalized()))
   var axis=rest.normalized();var stretch=next.length()/rest.length()
   var scale_along=Basis.IDENTITY
   scale_along.x+=axis*axis.x*(stretch-1);scale_along.y+=axis*axis.y*(stretch-1);scale_along.z+=axis*axis.z*(stretch-1)
   var basis=align*scale_along
   return Transform3D(basis,shoulder-basis*shoulder)
  arm_pose=Transform3D(Basis.IDENTITY,delta)
  return arm_pose
 return pose*arm_pose


func run():
 var random=RandomNumberGenerator.new();random.seed=840231
 var rests=[]
 for kind in 5:
  for sample_ in 300:
   var data={"variant":kind,"pos":Vector3(20,1,-30),"facing":random.randf_range(-PI,PI),"walk_phase":random.randf_range(-7,7),"attack_progress":random.randf_range(-1,1),"action":["walk","windup","recover"][sample_%3],"velocity":Vector3.ZERO if sample_%2==0 else Vector3(1,0,-2)}
   if sample_%4==0:data.pose_motion=0.0
   if sample_%5==0:data.attack_point=Vector3(5,3,-20)
   if sample_%7==0:data.hit_recoil=.12;data.hit_direction=Vector3.LEFT;data.hit_heavy=sample_%2==0
   if sample_%11==0:data.walk_feet={"foot_l":Transform3D(Basis(Vector3.UP,.5),Vector3(1,2,3))}
   if sample_%13==0:data.frozen_pose=data.duplicate(true);data.frozen=1.0;data.velocity=Vector3(1,0,-2);data.walk_phase=20.0
   if sample_%17==0:data.erase("velocity")
   for group in ["body","foot_l","foot_r","fist_l","fist_r","arm_l","arm_r"]:
    check(reference_pose(group,data)==Crowd.part_pose(group,data),"Role %d state %d %s retains exact authored pose"%[kind,sample_,group])
   if kind<4:rests.append({"variant":kind,"pos":data.pos,"facing":data.facing,"walk_phase":data.walk_phase,"velocity":Vector3.ZERO,"attack_progress":0.0,"action":"walk"})
 # Explicit hand-derived exceptions ensure the reference cannot conceal a
 # shared regression in planted feet, recoil, bow draw, or frozen motion.
 var planted=Transform3D(Basis(Vector3.UP,.5),Vector3(1,2,3))
 var anchor={"variant":2,"velocity":Vector3.ZERO,"walk_feet":{"foot_l":planted}}
 check(Crowd.part_pose("foot_l",anchor)==planted,"A stationary planted foot keeps its world anchor")
 var recoil={"variant":0,"velocity":Vector3.ZERO,"hit_recoil":.18,"hit_direction":Vector3.LEFT}
 check(Crowd.part_pose("body",recoil)!=Transform3D.IDENTITY,"Stationary recoil still tilts the body")
 var draw={"variant":1,"velocity":Vector3.ZERO,"attack_progress":.9}
 check(Crowd.part_pose("arm_l",draw).origin.y>0,"A stationary archer still draws its bow")
 var frozen={"variant":0,"velocity":Vector3.ZERO,"frozen":1.0,"frozen_pose":{"variant":0,"velocity":Vector3.RIGHT,"walk_phase":1.2}}
 check(Crowd.part_pose("body",frozen)!=Transform3D.IDENTITY,"A frozen moving pose cannot become an idle pose")
 if "--benchmark" in OS.get_cmdline_user_args():
  var baseline=[];var optimized=[]
  for trial in 5:
   var stamp=Time.get_ticks_usec()
   for repeat_ in 30:
    for data in rests:reference_pose("body",data)
   baseline.append(Time.get_ticks_usec()-stamp)
   stamp=Time.get_ticks_usec()
   for repeat_ in 30:
    for data in rests:Crowd.part_pose("body",data)
   optimized.append(Time.get_ticks_usec()-stamp)
  baseline.sort();optimized.sort()
  var ratio=float(optimized[2])/float(baseline[2])
  print("REST_POSE_TIMING reference_us=",baseline[2]," current_us=",optimized[2]," ratio=",ratio)
  check(ratio<.9,"Exact stationary poses avoid at least 10 percent of full evaluation work")
 print("FOREST_REST_POSE_RESULT checks=",checks," failures=",failures)
 quit(1 if failures else 0)
