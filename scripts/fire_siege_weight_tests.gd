extends "res://scripts/fire_siege_controls_tests.gd"
func run():
 Input.use_accumulated_input=false
 game.smoke_test=true;game.tuning=PrototypeTuning.DEFAULTS.duplicate()
 game.tuning.invincible=true;game.tuning.freeze_ai=true;game.player.smoke_mode=true
 game.start_mode("defense");pause_fixture_director();game.encounters.choose_card("supply_cache")
 for i in range(10):
  await fresh_class(i)
  var actor=game.player.active_ability.visual_actor
  check(is_equal_approx(actor.model.scale.z,1.15) and is_equal_approx(actor.model.scale.x,1),"%s has fuller profile without widening the approved front" % CLASS_IDS[i])
  actor.reset_motion()
  var rest: Vector3 = actor.joints.Arm_R.node.position
  for frame in range(45):actor.animate_pose(motion(10.2),1.0/60,frame/60.0,1)
  check(actor.joints.Body.node.rotation.z<-.05 and actor.joints.Body.node.rotation.z>-.11,"%s keeps a restrained side lean" % CLASS_IDS[i])
  check(actor.model.rotation.y>.45 and actor.model.rotation.y<.56,"%s angles its stepping stance about 30 degrees into strafe" % CLASS_IDS[i])
  check(actor.joints.Arm_R.node.position.distance_to(rest)>.04,"%s carrying arm responds to strafe momentum" % CLASS_IDS[i])
  var head_yaw: float = actor.model.rotation.y+actor.joints.Body.node.rotation.y+actor.joints.Head.node.rotation.y
  check(head_yaw>.4 and head_yaw<.65,"%s head and neck follow the diagonal shoulder turn" % CLASS_IDS[i])
  var before: Vector3 = actor.joints.Arm_R.node.position
  actor.animate_pose(motion(-10.2),1.0/60,1,1)
  check(actor.joints.Arm_R.node.position.distance_to(before)<.035,"%s reversing direction does not snap its carrying hand" % CLASS_IDS[i])
  var wind=actor.get_node_or_null("MovementWind")
  check(wind!=null and wind.visible,"%s movement has visible wind shading" % CLASS_IDS[i])
  if wind!=null:
   var cruise: float=wind.strength
   for frame in range(40):actor.animate_pose(motion(21),1.0/60,2+frame/60.0,1)
   check(wind.strength>cruise+.15,"%s sprint wind is stronger than cruise" % CLASS_IDS[i])
   for frame in range(60):actor.animate_pose(motion(0),1.0/60,3+frame/60.0,0)
   check(not wind.visible,"%s wind fades when stopped" % CLASS_IDS[i])
  actor.reset_motion()
  check(wind==null or not wind.visible,"%s clears wind when switching/resetting" % CLASS_IDS[i])
 await fresh_class(6)
 var actor=game.player.active_ability.visual_actor
 for frame in range(45):actor.animate_pose(motion(10.2),1.0/60,frame/60.0,1)
 var blade: Vector3=actor.model.global_basis.inverse() * actor.joints.Weapon_Cutlass.node.global_basis * actor.WEAPON_AXES["magic-swordsman"]
 check(blade.x<-.4 and blade.y<0,"Left strafe trails the claymore down on the anatomical right")
 var carried: Quaternion = actor.joints.Weapon_Cutlass.node.quaternion
 var entry=motion(10.2);entry.attack={"style":"cutlass","duration":.4,"contact":.1,"time":.003,"index":0}
 actor.animate_pose(entry,1.0/60,1,1)
 check(carried.angle_to(actor.joints.Weapon_Cutlass.node.quaternion)<.2,"Attack starts from moving carry without snapping the blade upright")
 var pose=motion(10.2);pose.attack={"style":"cutlass","duration":.4,"contact":.1,"time":.1,"index":0}
 actor.animate_pose(pose,1.0/60,1,1)
 blade=actor.model.global_basis.inverse()*actor.joints.Weapon_Cutlass.node.global_basis*actor.WEAPON_AXES["magic-swordsman"]
 check(blade.z>1,"Committed contact still swings forward despite carrying inertia")
 pose.attack.time=.397
 actor.animate_pose(pose,1.0/60,1.3,1)
 var recovery: Quaternion = actor.joints.Weapon_Cutlass.node.quaternion
 actor.animate_pose(motion(10.2),1.0/60,1.32,1)
 check(recovery.angle_to(actor.joints.Weapon_Cutlass.node.quaternion)<.2,"Attack recovery returns smoothly to moving carry")
 print("FIRE_SIEGE_WEIGHT_RESULT checks=",checks," failures=",failures)
 get_tree().quit(1 if failures else 0)

func motion(speed: float) -> Dictionary:
 return {"isPlayer":true,"grounded":true,"motionSpeed":absf(speed),"localMotion":Vector3(speed,0,0)}
