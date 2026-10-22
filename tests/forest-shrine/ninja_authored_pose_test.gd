extends SceneTree
const Actor=preload("res://assets/rogue/scripts/actor.gd")
const DATA="res://assets/animations/ninja_approved.json"
var checks=0
var failures=0
func _initialize():run.call_deferred()
func check(ok: bool,note: String):
 checks+=1;print("PASS: " if ok else "FAIL: ",note)
 if not ok:failures+=1
func unpack(v: Array)->Transform3D:
 return Transform3D(Basis(Quaternion(v[3],v[4],v[5],v[6]).normalized()).scaled(Vector3(v[7],v[8],v[9])),Vector3(v[0],v[1],v[2]))
func pose_matches(actor,data: Dictionary,sample: Dictionary,note: String):
 var sk=actor.cosplay_rig.skeleton;var position_error=0.0;var angle_error=0.0
 for i in data.bones.size():
  var index=sk.find_bone(data.bones[i]);var expected=unpack(sample.bones[i]);expected.basis*=sk.get_bone_global_rest(index).basis
  var actual=sk.get_bone_global_pose(index)
  position_error=maxf(position_error,actual.origin.distance_to(expected.origin))
  angle_error=maxf(angle_error,actual.basis.get_rotation_quaternion().angle_to(expected.basis.get_rotation_quaternion()))
 check(position_error<.0001 and angle_error<.002,note+" body matches Blender (%.6fm / %.6frad)"%[position_error,angle_error])
 for side in ["right","left"]:
  var weapon: Node3D=actor.joints["Weapon_Cutlass" if side=="right" else "Weapon_Pistol"].node
  var actual: Transform3D=sk.global_transform.affine_inverse()*weapon.global_transform
  var expected=unpack(sample.weapons[side])
  check(actual.origin.distance_to(expected.origin)<.0001 and actual.basis.get_rotation_quaternion().angle_to(expected.basis.get_rotation_quaternion())<.002,note+" "+side+" grip matches Blender")
func run():
 check(FileAccess.file_exists(DATA),"Authored Ninja data is included in the game package")
 if not FileAccess.file_exists(DATA):quit(1);return
 var data: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(DATA))
 var actor=Actor.new();root.add_child(actor);actor.setup("ninja")
 var idle={"grounded":true};actor.animate_pose(idle,0,0,0)
 var motion=actor.cosplay_rig.get("ninja_motion")
 check(motion!=null,"Ninja uses the player's authored Blender poses")
 if motion==null:actor.free();quit(1);return
 pose_matches(actor,data,data.clips.idle.frames[0],"New idle")
 motion.idle_time=3.6-1.0/60;actor.animate_pose(idle,1.0/60,0,0)
 pose_matches(actor,data,data.clips.idle.frames[0],"Idle loop seam")
 var mesh: Node3D=actor.model.find_child("Weapon_Cutlass_Geometry",true,false)
 check(mesh.scale.distance_to(Vector3(2,1.5,1))<.0001,"User's enlarged blade is in the runtime model")
 check(actor.WEAPON_AXES.ninja.distance_to(Vector3(data.weapon_tip[0],data.weapon_tip[1],data.weapon_tip[2]))<.00001,"Combat and trails use the enlarged blade's actual tip")
 var state={"grounded":true,"roll":.42,"rollDuration":.42,"rollStyle":"dash-cut","dashAttack":{"style":"dash-cut","weaponScale":1.0}}
 actor.animate_pose(state,0,0,0);pose_matches(actor,data,data.clips.slash.frames[0],"RMB start")
 state.roll=.000001;actor.animate_pose(state,1.0/60,0,0);pose_matches(actor,data,data.clips.slash.frames[1],"RMB finish")
 state.roll=0;state.dashAttack=null;actor.animate_pose(state,1.0/60,0,0)
 pose_matches(actor,data,data.clips.slash.frames[1],"Recovery begins at authored finish")
 check(motion.last_clip=="recovery","RMB recovers after the actual dash timer ends")
 var before=actor.cosplay_rig.pose("Hand_R").origin
 actor.animate_pose(idle,.08,0,0)
 var middle=actor.cosplay_rig.pose("Hand_R").origin
 check(before.distance_to(middle)>.01,"Recovery moves smoothly toward idle")
 actor.animate_pose(idle,.1,0,0);check(motion.last_clip=="idle","Recovery completes without extending dash physics")
 # A primary or ranged shot immediately owns the arms, even during recovery.
 for interrupt in [{"attack":{"primary":true,"style":"ninja","index":0,"time":.06,"contact":.06,"duration":.21}},{"shot":.2},{"grounded":false,"vertical":4},{"roll":.1,"rollStyle":"dodge"},{"crouched":true}]:
  motion.was_dash=true
  var busy=idle.duplicate();busy.merge(interrupt,true)
  actor.animate_pose(busy,1.0/60,0,0)
  check(motion.last_clip=="" and motion.recovery_age>=motion.RECOVERY,"Actions interrupt authored recovery: "+str(interrupt.keys()))
 actor.reset_motion();check(not motion.was_dash and motion.recovery_age>=motion.RECOVERY and motion.idle_time==0,"Restart cancels authored animation history")
 # Repeated pose probes must not accumulate dash reach scaling.
 state.roll=.21;state.dashAttack={"style":"dash-cut","weaponScale":2.0}
 var scales=[]
 for i in 8:
  actor.animate_pose(state,0,0,0);scales.append(actor.joints.Weapon_Cutlass.node.global_basis.get_scale().length())
 check(absf(scales[0]-scales[-1])<.0001 and absf(scales[0]-sqrt(3)*2.3)<.0001,"Dash reach scales once about the authored grip")
 actor.free()
 print("NINJA_AUTHORED_POSE_RESULT checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)
