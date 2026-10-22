extends "res://scripts/fire_siege_controls_tests.gd"
## Real-world regressions: acceleration, aerial pose, utility buffering and wave contacts.
func run():
 Input.use_accumulated_input=false
 game.smoke_test=true;game.tuning=PrototypeTuning.DEFAULTS.duplicate()
 game.tuning.invincible=true;game.tuning.freeze_ai=true;game.player.smoke_mode=true
 game.start_mode("defense");pause_fixture_director();game.encounters.choose_card("supply_cache")
 var p=game.player
 for i in range(10):
  await fresh_class(i)
  var a=p.active_ability
  p.smoke_move=Vector2(0,-1)
  await frames(2)
  var early=Vector2(p.velocity.x,p.velocity.z).length()
  await frames(25)
  var full=Vector2(p.velocity.x,p.velocity.z).length()
  check(early>0 and early<full*.85,"%s accelerates without snapping to full speed" % CLASS_IDS[i])
  check(absf(full-game.tuning.walk_speed*a.class_data().speed/5.15)<.1,"%s preserves cruising speed" % CLASS_IDS[i])
  p.smoke_move=Vector2.ZERO;await frames(20)
  check(Vector2(p.velocity.x,p.velocity.z).length()<.01,"%s stops without drifting" % CLASS_IDS[i])
  tap("jump");await frames(12);tap("jump");await frames(14)
  check(p.jumps_used==2 and a.visual_actor.model.basis.y.y<-.3,"%s second jump visibly flips forward" % CLASS_IDS[i])
  # Dragoon now has twice the jump height and correspondingly longer airtime.
  # Check the landing event rather than the old common 75-frame landing time.
  for landing_frame in range(120):
   if p.is_on_floor():break
   await frames(1)
  await frames(2)
  check(Vector2(a.visual_actor.model.position.x,a.visual_actor.model.position.z).length()<.01,"%s flip keeps the mesh over its collision body" % CLASS_IDS[i])
  check(p.is_on_floor() and a.visual_actor.model.basis.y.y>.9,"%s lands upright after the flip" % CLASS_IDS[i])
  tap("surge");await frames(10)
  var aura=a.visual_actor.get_node_or_null("UltimateAura")
  check(aura!=null and aura.visible,"%s ultimate has attached energy" % CLASS_IDS[i])
  a.reset_run()
  check(aura==null or not aura.visible,"%s ultimate energy clears immediately on reset" % CLASS_IDS[i])
 await fresh_class(6)
 var a=p.active_ability
 var edge=fixture(Vector3(5,0,1.95))
 tap("heavy_attack")
 check(not a.projectiles.is_empty() and a.projectiles[0].mesh.position.y-p.position.y>1.5,"Wave travels at raised chest height")
 await frames(45)
 check(edge.hp<10000,"Wider wave reaches enemies near its visible edge")
 check(is_equal_approx(10000-edge.hp,100),"Piercing wave applies its current 100 damage exactly once")
 await fresh_class(7);a=p.active_ability
 p.smoke_move=Vector2.RIGHT;tap("dodge");p.smoke_move=Vector2.ZERO
 check(a.player.roll>0 and a.player.rollDir.dot(Vector3.RIGHT.rotated(Vector3.UP,game.camera_rig.yaw))>.999,"Ranger tumble follows directional input")
 for i in range(10):
  await fresh_class(i);a=p.active_ability
  if a.has_extra_utility():a.evade_cooldown=.09
  else:a.player.cooldowns.roll=.09
  tap("dodge");await frames(9)
  check(a.player.roll>0 or a.player.travel!=null or (i==3 and a.player.cooldowns.roll>1),"%s buffers evade just before cooldown ends" % CLASS_IDS[i])
 await fresh_class(4);a=p.active_ability
 tap("jump");await frames(10);tap("jump");await frames(2);tap("dodge");await frames(14)
 check(a.visual_actor.model.basis.y.y>.8,"Aerial Knight dodge does not resume an interrupted flip")
 print("FIRE_SIEGE_MOTION_RESULT checks=",checks," failures=",failures)
 game.show_main_menu();game.sound_library.cancel();game.music.stop()
 for voice in game.voices:voice.stop()
 await frames(30)
 get_tree().quit(1 if failures else 0)
