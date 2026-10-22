extends SceneTree
const Actor=preload("res://assets/rogue/scripts/actor.gd")
const DATA="res://assets/animations/samurai_approved.json"
var checks=0
var failures=0
func _initialize():run.call_deferred()
func check(ok: bool,note: String):
 checks+=1;print("PASS: " if ok else "FAIL: ",note)
 if not ok:failures+=1
func unpack(v: Array)->Transform3D:
 return Transform3D(Basis(Quaternion(v[3],v[4],v[5],v[6]).normalized()).scaled(Vector3(v[7],v[8],v[9])),Vector3(v[0],v[1],v[2]))
func pose_matches(actor,data: Dictionary,sample: Dictionary,note: String):
 var sk: Skeleton3D=actor.cosplay_rig.skeleton
 var distance=0.0;var angle=0.0
 for i in data.bones.size():
  var index=sk.find_bone(data.bones[i]);var expected=unpack(sample.bones[i])
  expected.basis*=sk.get_bone_global_rest(index).basis
  var actual=sk.get_bone_global_pose(index)
  distance=maxf(distance,actual.origin.distance_to(expected.origin))
  angle=maxf(angle,actual.basis.get_rotation_quaternion().angle_to(expected.basis.get_rotation_quaternion()))
 check(distance<.0001 and angle<.002,note+" matches evaluated Blender body (%.6f / %.6f)"%[distance,angle])
 var actual: Transform3D=sk.global_transform.affine_inverse()*actor.joints.Weapon_Cutlass.node.global_transform
 var expected=unpack(sample.weapon)
 check(actual.origin.distance_to(expected.origin)<.0001 and actual.basis.get_rotation_quaternion().angle_to(expected.basis.get_rotation_quaternion())<.002,note+" keeps the katana attached to its authored grip")
func run():
 check(FileAccess.file_exists(DATA),"Approved Samurai animation is in the runtime package")
 if not FileAccess.file_exists(DATA):quit(1);return
 var data: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(DATA))
 var actor=Actor.new();root.add_child(actor);actor.setup("samurai")
 actor.animate_pose({"grounded":true},0,0,0)
 check(actor.model.find_child("SamuraiRedScabbard",true,false)==null,"Samurai carries the drawn katana without a scabbard")
 check(actor.model.find_child("Katana_Blade*",true,false)!=null,"Approved maroon blade replaces the old katana")
 var motion=actor.cosplay_rig.get("samurai_motion")
 check(motion!=null,"Samurai uses the approved Blender choreography")
 if motion==null:actor.free();quit(1);return
 pose_matches(actor,data,data.clips.idle.frames[0],"Two-handed low guard")
 motion.idle_time=2.0-1.0/30;actor.animate_pose({"grounded":true},1.0/30,0,0)
 pose_matches(actor,data,data.clips.idle.frames[0],"Idle loop seam")
 actor.locomotion.stride_speed=6;actor.locomotion.phase=TAU*.25
 actor.animate_pose({"grounded":true,"motionSpeed":6,"localMotion":Vector3.BACK*6},0,0,1)
 pose_matches(actor,data,data.clips.run.frames[6],"Drawn-katana running")
 var starts=[1,20,38,56,74];var hits=[12,30,48,66,87];var ends=[20,38,56,74,105]
 for stage in 5:
  var a={"primary":true,"style":"samurai-cut","index":stage,"time":0.0,"contact":.075,"duration":.4}
  for pair in [[0.0,starts[stage]],[.075,hits[stage]],[.4,ends[stage]]]:
   a.time=pair[0];actor.animate_pose({"grounded":true,"attack":a},0,0,0)
   pose_matches(actor,data,data.clips.combo.frames[pair[1]-1],"Strike %d at %.3fs"%[stage+1,pair[0]])
  a.time=.075
  actor.animate_pose({"grounded":false,"vertical":4,"attack":a},0,0,0)
  pose_matches(actor,data,data.clips.combo.frames[hits[stage]-1],"Airborne strike %d"%[stage+1])
 var tip=Vector3(data.weapon_tip[0],data.weapon_tip[1],data.weapon_tip[2])
 check(actor.WEAPON_AXES.samurai.distance_to(tip)<.0001,"Reach and sword effects follow the new enlarged blade tip")
 var scaled={"grounded":true,"attack":{"primary":true,"style":"samurai-cut","index":0,"time":.075,"contact":.075,"duration":.4},"meleeVisualScale":1.5}
 actor.animate_pose(scaled,0,0,0)
 var first_scale: Vector3=actor.joints.Weapon_Cutlass.node.global_basis.get_scale()
 actor.animate_pose(scaled,0,0,0)
 check(first_scale.distance_to(actor.joints.Weapon_Cutlass.node.global_basis.get_scale())<.0001 and absf(first_scale.x-1.5)<.0001,"Adjustable attack reach scales the new weapon once without accumulation")
 var scarf: Node3D=actor.model.find_child("ScarfTail",true,false)
 var sk: Skeleton3D=actor.cosplay_rig.skeleton
 var scarf_grip=(sk.global_transform*actor.cosplay_rig.pose("Head")).affine_inverse()*scarf.global_transform
 scaled.attack.index=4;actor.animate_pose(scaled,0,0,0)
 var other_grip=(sk.global_transform*actor.cosplay_rig.pose("Head")).affine_inverse()*scarf.global_transform
 check(scarf_grip.origin.distance_to(other_grip.origin)<.0001,"Scarf stays attached to the animated head through the new combo")
 var hilt: Node3D=actor.model.find_child("Katana_Hilt",true,false)
 if hilt==null:hilt=actor.model.find_child("Katana_Blade_Maroon",true,false)
 for amount in [1.5,2.0,3.0]:
  scaled.meleeVisualScale=1.0;actor.animate_pose(scaled,0,0,0)
  var grips=[]
  for side in ["R","L"]:grips.append(hilt.to_local(sk.global_transform*actor.cosplay_rig.pose("Hand_"+side).origin))
  scaled.meleeVisualScale=amount;actor.animate_pose(scaled,0,0,0)
  for i in 2:
   var hand_world=sk.global_transform*actor.cosplay_rig.pose("Hand_"+["R","L"][i]).origin
   check(hilt.to_global(grips[i]).distance_to(hand_world)<.0001,"Reach %.1fx keeps %s hand on the unchanged hilt"%[amount,["right","left"][i]])
 var support=Vector3.ZERO
 for stage in range(1,5):
  actor.reset_motion();actor.animate_pose({"grounded":true},.2,0,0)
  support=hilt.to_local(sk.global_transform*actor.cosplay_rig.pose("Hand_L").origin)
  var before_hand=sk.global_transform*actor.cosplay_rig.pose("Hand_R").origin
  var before_tip=actor.joints.Weapon_Cutlass.node.to_global(tip)
  var delayed={"primary":true,"style":"samurai-cut","index":stage,"time":0.0,"contact":.075,"duration":.4}
  actor.animate_pose({"grounded":true,"attack":delayed},1.0/60,0,0)
  check(before_hand.distance_to(sk.global_transform*actor.cosplay_rig.pose("Hand_R").origin)<.001 and before_tip.distance_to(actor.joints.Weapon_Cutlass.node.to_global(tip))<.001,"Delayed combo follow-up %d starts at the last visible idle without snapping"%[stage+1])
  for t in [.005,.01,.015,.02,.03]:
   delayed.time=t;actor.animate_pose({"grounded":true,"attack":delayed},.005,0,0)
   check(hilt.to_global(support).distance_to(sk.global_transform*actor.cosplay_rig.pose("Hand_L").origin)<.002,"Delayed strike %d keeps its support hand on the hilt during entry at %.3f"%[stage+1,t])
  delayed.time=.075;actor.animate_pose({"grounded":true,"attack":delayed},1.0/60,0,0)
  pose_matches(actor,data,data.clips.combo.frames[hits[stage]-1],"Delayed follow-up contact %d"%[stage+1])
 for i in 6:
  actor.animate_pose({"grounded":true},.025,0,0)
  check(hilt.to_global(support).distance_to(sk.global_transform*actor.cosplay_rig.pose("Hand_L").origin)<.002,"Recovery keeps both grips connected at step %d"%i)
 for speed in [.2,.6,1.2,1.8]:
  actor.reset_motion();actor.locomotion.stride_speed=speed;actor.locomotion.phase=TAU*.25
  actor.animate_pose({"grounded":true,"motionSpeed":speed},0,0,1)
  check(hilt.to_global(support).distance_to(sk.global_transform*actor.cosplay_rig.pose("Hand_L").origin)<.002,"Walking/run blend keeps the support grip at speed %.1f"%speed)
 for state in [{"grounded":true,"shot":.2},{"grounded":true,"roll":.15,"rollDuration":.32,"rollStyle":"dodge"},{"grounded":false,"vertical":6}]:
  actor.animate_pose(state,1.0/60,0,0)
  check(motion.last_clip=="","Bow, evade and free jump retain control: "+str(state.keys()))
  check(actor.joints.Weapon_Cutlass.node.global_basis.get_scale().distance_to(Vector3.ONE)<.0001,"Approved katana size stays consistent during bow, dodge and jump")
 actor.reset_motion();check(motion.idle_time==0 and motion.last_clip=="","Restart clears Samurai animation history")
 actor.free()
 print("SAMURAI_AUTHORED_RESULT checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)
