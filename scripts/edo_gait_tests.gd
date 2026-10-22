extends SceneTree
var failures=0
var checks=0
var world: Node3D
func _initialize():call_deferred('run')
func check(ok: bool,label: String):
 checks+=1
 if not ok:failures+=1;push_error('EDO_GAIT_FAIL '+label)
 else:print('PASS '+label)
func model():
 var m=load('res://assets/characters/musashi/model/musashi_model.gd').new();world.add_child(m);return m
func range_of(points: Array,axis: int)->float:
 var lo=INF;var hi=-INF
 for p in points:lo=minf(lo,p[axis]);hi=maxf(hi,p[axis])
 return hi-lo
func sample(m,velocity: Vector3,grounded=true)->Array:
 var trace=[]
 m.locomotion_velocity=velocity
 for frame in range(160):
  m.animate(1.0/60,velocity.length(),grounded,0,0,false,0,false)
  if frame>=50:trace.append(m.skeleton.global_transform*m.skeleton.get_bone_global_pose(m.skeleton.find_bone('Foot_L')).origin)
 return trace
func run():
 world=Node3D.new();root.add_child(world)
 var m=model();var side=sample(m,Vector3(8,0,0))
 check(range_of(side,0)>.12,'Strafing steps laterally instead of marching forward')
 check(range_of(side,2)<.13,'Pure strafe avoids large forward/backward foot swing')
 var knee=0.0
 m.locomotion_velocity=Vector3(0,0,-8)
 for frame in range(160):
  m.animate(1.0/60,8,true,0,0,false,0,false)
  var s=m.skeleton;var hip=s.get_bone_global_pose(s.find_bone('Leg_L')).origin;var k=s.get_bone_global_pose(s.find_bone('Shin_L')).origin;var a=s.get_bone_global_pose(s.find_bone('Foot_L')).origin
  knee=maxf(knee,acos(clampf((k-hip).normalized().dot((a-k).normalized()),-1,1)))
 print('maximum knee flex ',knee)
 check(knee>.8 and knee<2.65,'Running bends the Goemon knee into a bounded heel recovery')
 var rest=sample(m,Vector3.ZERO)
 check(range_of(rest,2)<.04 and range_of(rest,0)<.04,'Stopping settles both feet')
 # Match equivalent distance rather than frame rate: 30Hz and 120Hz should walk alike.
 var a=model();var b=model()
 for i in range(60):a.locomotion_velocity=Vector3(0,0,-8);a.animate(1.0/30,8,true,0,0,false,0,false)
 for i in range(240):b.locomotion_velocity=Vector3(0,0,-8);b.animate(1.0/120,8,true,0,0,false,0,false)
 var ap=a.skeleton.get_bone_global_pose(a.skeleton.find_bone('Foot_L')).origin
 var bp=b.skeleton.get_bone_global_pose(b.skeleton.find_bone('Foot_L')).origin
 check(ap.distance_to(bp)<.10,'Walking cadence remains consistent across frame rates')
 var unturned=model();var turned=model();turned.rotation.y=PI/2
 var straight_strafe=sample(unturned,Vector3(8,0,0));var rotated_strafe=sample(turned,Vector3(0,0,-8))
 var error=0.0
 for i in range(straight_strafe.size()):error=maxf(error,unturned.to_local(straight_strafe[i]).distance_to(turned.to_local(rotated_strafe[i])))
 check(error<.01,'Strafing follows local character axes after a 90-degree turn')
 m.locomotion.reset();var fresh=model()
 var reused_idle=sample(m,Vector3.ZERO);var fresh_idle=sample(fresh,Vector3.ZERO)
 check(reused_idle[-1].distance_to(fresh_idle[-1])<.02,'Reset and reuse clear the previous stride and directional lean')
 var landed=model();landed.landing=1.0
 landed.animate(1.0/60,0,true,0,0,false,0,false)
 check(landed.body.position.y<-.07,'Landing absorbs impact with a short Rogue-style weight drop')
 for i in range(90):landed.animate(1.0/60,0,true,0,0,false,0,false)
 check(absf(landed.body.position.y)<.03,'Landing recovery restores the normal stance')
 world.queue_free();await process_frame;await process_frame
 print('EDO_GAIT_RESULT checks=',checks,' failures=',failures);quit(1 if failures else 0)
