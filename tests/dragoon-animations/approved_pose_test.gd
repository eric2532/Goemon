extends SceneTree
const Actor=preload("res://assets/rogue/scripts/actor.gd")
var failures=0
var checks=0
var data: Dictionary
func check(ok: bool,label: String):
 checks+=1
 if not ok:failures+=1;printerr("FAIL ",label)
func _initialize():call_deferred("run")
func expected(actor,clip: String,frame: int):
 var sk: Skeleton3D=actor.cosplay_rig.skeleton
 var sample: Dictionary=data.clips[clip].frames[frame-1]
 var worst=0.0
 for b in data.bones.size():
  var v: Array=sample.bones[b]
  var idx=sk.find_bone(data.bones[b])
  var pose=sk.get_bone_global_pose(idx)
  var basis=Basis(Quaternion(v[3],v[4],v[5],v[6]).normalized()).scaled(Vector3(v[7],v[8],v[9]))*sk.get_bone_global_rest(idx).basis
  worst=maxf(worst,pose.origin.distance_to(Vector3(v[0],v[1],v[2])))
  for axis in 3:worst=maxf(worst,(pose.basis[axis]-basis[axis]).length())
 check(worst<.001,"Approved "+clip+" full-body pose frame "+str(frame)+" error "+str(worst))
 var v: Array=sample.lance
 var target=Transform3D(Basis(Quaternion(v[3],v[4],v[5],v[6]).normalized()).scaled(Vector3(v[7],v[8],v[9])),Vector3(v[0],v[1],v[2]))
 var actual: Transform3D=sk.global_transform.affine_inverse()*actor.joints.Weapon_Cutlass.node.global_transform
 check(actual.origin.distance_to(target.origin)<.001 and (actual.basis.y-target.basis.y).length()<.001,"Approved "+clip+" lance follows the authored grip")
 check(actor.model.position.length()<.001 and actor.model.quaternion.angle_to(Quaternion.IDENTITY)<.001,"No duplicate visual jump arc or legacy tilt")
func run():
 data=JSON.parse_string(FileAccess.get_file_as_string("res://assets/animations/dragoon_approved.json"))
 var actor=Actor.new();root.add_child(actor);actor.setup("dragoon");actor.seed=0
 actor.animate_pose({"grounded":true,"motionSpeed":0},0,0)
 expected(actor,"idle",1)
 actor.animate_pose({"grounded":true,"attack":{"primary":true,"style":"thrust","index":0,"duration":.36,"contact":.1,"time":.1}},.1,.1)
 expected(actor,"attack",7)
 actor.reset_motion()
 for i in 31:actor.animate_pose({"grounded":false,"vertical":0.0,"motionSpeed":0},.01,i*.01)
 expected(actor,"jump",56)
 actor.animate_pose({"grounded":false,"travel":{"kind":"lance-leap","phase":"drop","time":.5,"duration":.72,"height":0}},0,1)
 expected(actor,"jump_strike",150)
 actor.animate_pose({"grounded":false,"vertical":0.0,"landing":1.25},0,1)
 expected(actor,"jump_strike",180)
 for key in data.clips:
  for frame in range(1,data.clips[key].frames.size()+1):
   actor.cosplay_rig.dragoon_motion.sample(actor,key,frame,1.0)
   expected(actor,key,frame)
 actor.free()
 print("DRAGOON_APPROVED_POSES checks=",checks," failures=",failures)
 quit(1 if failures else 0)
