extends SceneTree
const Actor=preload("res://assets/rogue/scripts/actor.gd")
const DATA="res://assets/animations/pirate_approved.json"
var checks=0
var failures=0
var data: Dictionary
func _initialize():run.call_deferred()
func check(ok: bool,note: String):
 checks+=1
 if not ok:failures+=1;printerr("FAIL: ",note)
func unpack(v: Array)->Transform3D:
 return Transform3D(Basis(Quaternion(v[3],v[4],v[5],v[6]).normalized()).scaled(Vector3(v[7],v[8],v[9])),Vector3(v[0],v[1],v[2]))
func difference(a: Transform3D,b: Transform3D)->float:
 return maxf(a.origin.distance_to(b.origin),maxf((a.basis.x-b.basis.x).length(),maxf((a.basis.y-b.basis.y).length(),(a.basis.z-b.basis.z).length())))
func expected(actor,key: String,frame: int):
 var sk=actor.cosplay_rig.skeleton
 var sample=data.clips[key].frames[frame-int(data.clips[key].start_frame)]
 var worst=0.0
 for i in data.bones.size():
  var index=sk.find_bone(data.bones[i]);var target=unpack(sample.bones[i]);target.basis*=sk.get_bone_global_rest(index).basis
  worst=maxf(worst,difference(sk.get_bone_global_pose(index),target))
 check(worst<.001,"Blender body %s frame %d error %f"%[key,frame,worst])
 for side in ["right","left"]:
  var weapon=actor.joints["Weapon_Cutlass" if side=="right" else "Weapon_Pistol"].node
  check(difference(sk.global_transform.affine_inverse()*weapon.global_transform,unpack(sample.weapons[side]))<.001,"Blender grip %s %s frame %d"%[key,side,frame])
func run():
 check(FileAccess.file_exists(DATA),"Approved Pirate poses are included in the game")
 if not FileAccess.file_exists(DATA):quit(1);return
 data=JSON.parse_string(FileAccess.get_file_as_string(DATA))
 var actor=Actor.new();root.add_child(actor);actor.setup("pirate");actor.seed=0
 actor.animate_pose({"grounded":true},0,0,0)
 var motion=actor.cosplay_rig.get("pirate_motion")
 check(motion!=null,"Pirate uses the approved Blender controller")
 if motion==null:actor.free();quit(1);return
 expected(actor,"idle",0)
 check(actor.cosplay_rig.skeleton.get_bone_count()==22,"Shared original skeleton remains 22 bones")
 check(actor.WEAPON_AXES.pirate.distance_to(Vector3(data.weapon_tip[0],data.weapon_tip[1],data.weapon_tip[2]))<.0001,"Combat trails use the resized cutlass tip")
 for side in ["right","left"]:
  var name_="Weapon_Cutlass" if side=="right" else "Weapon_Pistol"
  var mesh=actor.model.find_child(name_+"_Geometry",true,false)
  check(mesh is MeshInstance3D,"Approved "+side+" weapon geometry is installed")
  if mesh is MeshInstance3D:
   var bounds: AABB=mesh.get_aabb()
   var expected_min=Vector3(data.weapon_bounds[side].min[0],data.weapon_bounds[side].min[1],data.weapon_bounds[side].min[2])
   var expected_max=Vector3(data.weapon_bounds[side].max[0],data.weapon_bounds[side].max[1],data.weapon_bounds[side].max[2])
   check(bounds.position.distance_to(expected_min)<.001 and bounds.end.distance_to(expected_max)<.001,"Approved "+side+" dimensions match Blender without repeated scaling")
   for surface in mesh.mesh.get_surface_count():
    var mat=mesh.get_active_material(surface)
    check(mat is StandardMaterial3D and mat.albedo_texture!=null,"Approved weapon art is baked into a runtime texture")
 for key in data.clips:
  for frame in range(int(data.clips[key].start_frame),int(data.clips[key].end_frame)+1):
   motion.sample(actor,key,frame,1);expected(actor,key,frame)
 # Actual combat contact timestamps, including the accelerated forest attacks.
 for durations in [[.29,.075],[.33,.095],[.49,.15]]:
  var index=0 if durations[0]==.29 else (1 if durations[0]==.33 else 2)
  for contact in [durations[1],minf(durations[1]*.62,.12)]:
   actor.animate_pose({"grounded":true,"attack":{"primary":true,"style":"cutlass","index":index,"time":contact,"contact":contact,"duration":durations[0]}},0,0,0)
   check(motion.last_clip=="slash" and is_equal_approx(motion.last_frame,float([13,29,48][index])),"Slash %d meets the real damage contact"%index)
   expected(actor,"slash",[13,29,48][index])
 var scaled={"grounded":true,"meleeVisualScale":2.0,"attack":{"primary":true,"style":"sword","index":0,"time":.05,"contact":.05,"duration":.29}}
 for i in 8:
  actor.animate_pose(scaled,0,0,0)
  var weapon=actor.joints.Weapon_Cutlass.node
  var relative: Transform3D=actor.cosplay_rig.skeleton.global_transform.affine_inverse()*weapon.global_transform
  check(relative.basis.get_scale().distance_to(Vector3.ONE*2)<.001,"Range bonuses scale the authored cutlass once around its grip")
 actor.animate_pose({"grounded":true,"shot":.2},0,0,0);expected(actor,"shot",0)
 actor.animate_pose({"grounded":true,"shot":.000001},0,0,0)
 check(motion.last_clip=="shot" and motion.last_frame>23.99,"Shot reaches the user's authored end")
 actor.reset_motion()
 actor.animate_pose({"grounded":false,"vertical":10.7},1.0/60,0,0)
 check(motion.last_clip=="jump" and motion.last_frame==1,"Takeoff begins at Explorer's launch")
 for i in 24:actor.animate_pose({"grounded":false,"vertical":2.0},1.0/60,0,0)
 expected(actor,"jump",43)
 for i in 180:actor.animate_pose({"grounded":false,"vertical":-30.0},1.0/60,0,0)
 expected(actor,"jump",60)
 actor.animate_pose({"grounded":true},1.0/60,0,0)
 check(motion.last_clip=="jump" and motion.landing_age<.05,"Floor contact starts the authored landing")
 for i in 30:actor.animate_pose({"grounded":true},1.0/60,0,0)
 check(motion.last_clip=="idle","Landing returns to user idle frame zero")
 for busy in [{"roll":.2},{"drinkGesture":.5},{"blocking":true},{"crouched":true},{"travel":{"kind":"dash"}}]:
  var state={"grounded":true};state.merge(busy,true);actor.animate_pose(state,1.0/60,0,0)
  check(motion.last_clip=="","Native action retains control: "+str(busy))
 for native in [{"roll":.32},{"drinkGesture":.8}]:
  var state={"grounded":true};state.merge(native,true)
  actor.reset_motion();actor.animate_pose(state,0,0,0)
  var sk=actor.cosplay_rig.skeleton;var expected_native=[]
  for bone in sk.get_bone_count():expected_native.append(sk.get_bone_global_pose(bone))
  state.shot=.2;state.attack={"primary":true,"style":"sword","index":1,"time":.06,"contact":.06,"duration":.33}
  actor.reset_motion();actor.animate_pose(state,0,0,0)
  check(motion.last_clip=="","Native dodge/drink interrupts overlapping attack and shot")
  var error=0.0
  for bone in sk.get_bone_count():error=maxf(error,difference(sk.get_bone_global_pose(bone),expected_native[bone]))
  check(error<.001,"Interrupted attack retains the native action's body pose")
 actor.reset_motion();check(motion.last_clip=="" and motion.landing_age>10,"Restart clears animation history")
 actor.free();print("PIRATE_MOTION_RESULT checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)
