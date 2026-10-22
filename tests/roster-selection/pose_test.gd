extends SceneTree
## Render sampling must match native gameplay idle bones AND carried equipment.
const Sampler=preload("res://tools/roster_selection_pose.gd")
var checks=0
var failures=0
func _initialize():run.call_deferred()
func check(ok:bool,label_:String):
 checks+=1
 if not ok:failures+=1;printerr("FAIL: "+label_)
func run():
 var sampler=Sampler.new()
 check(sampler.has_method("create"),"Selection portraits sample the gameplay models instead of separate studio poses")
 if not sampler.has_method("create"):finish();return
 for id in range(1,13):
  var preview=sampler.call("create",id,root);sampler.call("sample",preview)
  var live
  if id==1:live=load("res://scripts/hero_model.gd").new()
  elif id==2:live=load("res://assets/characters/musashi/model/musashi_model.gd").new()
  else:
   live=load("res://scripts/rogue_hero_model.gd").new();live.class_id=Sampler.HEROES[id-1]
  root.add_child(live)
  if id==1:live.ronin_scarf.hide()
  if id>=3:live.actor.seed=0
  for frame in range(1,61):
   if id>=3:live.actor.animate_pose({"grounded":true,"vertical":0.0,"motionSpeed":0.0,"localMotion":Vector3.ZERO,"flip":-1.0},1.0/60,frame/60.0,0)
   else:live.animate(1.0/60,0,true,0,0,false,0,false);live.sync_skeleton()
  var a:Skeleton3D=preview.actor.cosplay_rig.skeleton if id>=3 else preview.skeleton
  var b:Skeleton3D=live.actor.cosplay_rig.skeleton if id>=3 else live.skeleton
  for bone in a.get_bone_count():check(a.get_bone_global_pose(bone).is_equal_approx(b.get_bone_global_pose(bone)),"%s selection uses gameplay idle bone %s"%[Sampler.HEROES[id-1],a.get_bone_name(bone)])
  if id>=3:
   for key in ["Weapon_Cutlass","Weapon_Pistol"]:
    if not preview.actor.joints.has(key):continue
    var first=preview.global_transform.affine_inverse()*preview.actor.joints[key].node.global_transform
    var second=live.global_transform.affine_inverse()*live.actor.joints[key].node.global_transform
    check(first.is_equal_approx(second),"%s retains the gameplay idle %s grip"%[Sampler.HEROES[id-1],key])
   if id==5:check(preview.actor.cosplay_rig.ninja_motion.last_clip=="idle","Ninja selection includes the user's authored gameplay idle")
   if id==11:check(preview.actor.cosplay_rig.explorer_motion.last_clip=="idle","Explorer selection includes the user's authored gameplay idle")
  preview.free();live.free()
 finish()
func finish():
 print("ROSTER_GAMEPLAY_IDLE_RESULT checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)
