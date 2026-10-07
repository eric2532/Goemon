extends "res://scripts/fire_siege_controls_tests.gd"
## All ten heroes: starts, stops, strafing, sprint, double jump, utility, ultimate.
func run():
 Input.use_accumulated_input=false
 game.smoke_test=true;game.tuning=PrototypeTuning.DEFAULTS.duplicate()
 game.tuning.invincible=true;game.tuning.freeze_ai=true;game.player.smoke_mode=true
 game.start_mode("defense");pause_fixture_director();game.encounters.choose_card("supply_cache")
 var p=game.player
 for id in range(3,13):
  press("light_attack",false);press("heavy_attack",false);press("sprint",false)
  p.select_character(id);p.cancel_charge();p.clear_powerups();p.smoke_move=Vector2.ZERO
  p.active_ability.reset_run();await clear_enemies()
  game.reset_player_at(Vector3(0,.1,205));p.facing=Vector3.FORWARD;p.model.rotation.y=0
  game.camera_rig.yaw=.7;game.camera_rig.pitch=.25;game.camera_rig.distance=7;game.camera_rig.reset_follow()
  game.toast("%s · Movement, double jump, utility & ultimate" % p.RogueRoster.name_for(id))
  await frames(20)
  for frame in range(96):
   p.smoke_move=Vector2(sin(float(frame)/96*TAU),-cos(float(frame)/96*TAU))*.7
   await frames(1)
  p.smoke_move=Vector2.ZERO;await frames(12)
  press("sprint");p.smoke_move=Vector2(0,-1);await frames(25)
  press("sprint",false);tap("jump");await frames(12);tap("jump");await frames(46)
  p.smoke_move=Vector2.ZERO;await frames(15)
  tap("dodge");await frames(40)
  if id==11:
   fixture(game.attack_direction()*8);tap("equip");await frames(38)
  elif id==12:
   tap("equip");await frames(18);tap("equip");await frames(18)
  # Return to a known patch so all previews remain on the actual straight lane.
  game.reset_player_at(Vector3(0,.1,205));p.active_ability.reset_run()
  game.camera_rig.yaw=PI-.5;game.camera_rig.pitch=.18;game.camera_rig.distance=6.4
  await frames(15)
  tap("surge");await frames(16)
  press("light_attack");await frames(42);press("light_attack",false)
  tap("heavy_attack");await frames(40)
  p.smoke_move=Vector2(.6,-.4);await frames(25);p.smoke_move=Vector2.ZERO;await frames(15)
  print("FIRE_SIEGE_MOTION_TOUR hero=",id," complete")
 game.show_rogue_roster();await frames(30)
 print("FIRE_SIEGE_MOTION_TOUR_COMPLETE")
 get_tree().quit()
