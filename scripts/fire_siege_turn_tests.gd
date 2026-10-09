extends "res://scripts/fire_siege_controls_tests.gd"

func run():
 Input.use_accumulated_input=false
 game.smoke_test=true;game.tuning=PrototypeTuning.DEFAULTS.duplicate()
 game.tuning.invincible=true;game.tuning.freeze_ai=true;game.player.smoke_mode=true
 game.start_mode("defense");pause_fixture_director()
 game.encounters.choose_card("supply_cache")
 var p=game.player
 for index in range(10):
  await fresh_class(index)
  p.facing=Vector3.FORWARD;p.model.rotation.y=0;p.active_ability.reset_run()
  game.camera_rig.yaw=0;await frames(5)
  game.camera_rig.yaw=PI/2;await frames(24)
  check(p.facing.dot(Vector3.FORWARD)>.99 and absf(angle_difference(p.model.rotation.y,0))<.02,"%s keeps body planted while idle camera orbits" % CLASS_IDS[index])
  p.smoke_move=Vector2.DOWN;await frames(2)
  var turn=absf(angle_difference(p.model.rotation.y,0))
  check(turn>.01 and turn<.8,"%s begins a smooth body turn instead of snapping" % CLASS_IDS[index])
  p.smoke_move=Vector2.RIGHT
  await frames(24)
  check(p.facing.dot(Vector3.FORWARD)>.99,"%s turns into sideways travel relative to the rotated camera" % CLASS_IDS[index])
  p.smoke_move=Vector2(0,1);await frames(20)
  check(p.facing.dot(Vector3.RIGHT)>.99,"%s turns around to face backward travel" % CLASS_IDS[index])
  p.smoke_move=Vector2.ZERO;game.camera_rig.yaw=0;await frames(20)
  tap("light_attack");await frames(1)
  if index==3:
   check(not p.active_ability.projectiles.is_empty() and p.active_ability.projectiles[0].vel.normalized().dot(Vector3.FORWARD)>.99,"Mage releases fireball along the camera heading after idle orbit")
  else:
   check(p.active_ability.player.attack!=null and p.active_ability.front(p.active_ability.player.attack.angle).dot(Vector3.FORWARD)>.99,"%s attacks the camera heading after idle orbit" % CLASS_IDS[index])
 await fresh_class(4)
 press("heavy_attack");await frames(25);game.camera_rig.yaw=PI/2;await frames(25)
 check(p.active_ability.player.blocking and p.facing.dot(Vector3.LEFT)>.99,"Held Knight block follows the camera while standing still")
 press("heavy_attack",false)
 game.show_main_menu();game.sound_library.cancel();game.music.stop()
 for voice in game.voices:voice.stop()
 await get_tree().create_timer(.3).timeout
 print("FIRE_SIEGE_TURN_RESULT checks=",checks," failures=",failures)
 get_tree().quit(1 if failures else 0)
