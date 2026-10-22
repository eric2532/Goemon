extends "res://scripts/fire_siege_controls_tests.gd"
## Deterministic visual review; uses the real map, player and native action system.
func run():
 Input.use_accumulated_input=false
 game.smoke_test=true;game.tuning=PrototypeTuning.DEFAULTS.duplicate()
 game.tuning.invincible=true;game.tuning.freeze_ai=true;game.player.smoke_mode=true
 game.start_mode("defense");pause_fixture_director();game.encounters.choose_card("supply_cache")
 var p=game.player
 for id in range(3,13):
  press("light_attack",false);press("heavy_attack",false)
  p.select_character(id);p.cancel_charge();p.clear_powerups();p.smoke_move=Vector2.ZERO
  p.active_ability.reset_run();await clear_enemies()
  game.reset_player_at(Vector3(0,.1,205));p.facing=Vector3.FORWARD;p.model.rotation.y=0
  game.camera_rig.yaw=PI;game.camera_rig.pitch=.25;game.camera_rig.distance=6.5;game.camera_rig.reset_follow()
  game.toast("%s · Goemon-style character review" % p.RogueRoster.name_for(id))
  await frames(25)
  for frame in range(75):
   game.camera_rig.yaw=PI+float(frame)/75*TAU
   await frames(1)
  game.camera_rig.yaw=0;game.camera_rig.pitch=.38;game.camera_rig.distance=8
  for frame in range(60):
   p.smoke_move=Vector2(sin(float(frame)/60*TAU),-cos(float(frame)/60*TAU))*.6
   await frames(1)
  p.smoke_move=Vector2.ZERO
  tap("jump");await frames(34);tap("dodge");await frames(35)
  fixture(Vector3(0,0,-2.5));press("light_attack");await frames(95);press("light_attack",false)
  press("heavy_attack");await frames(55);press("heavy_attack",false)
  tap("surge");await frames(35)
  print("FIRE_SIEGE_ART_TOUR hero=",id," complete")
 game.show_rogue_roster();await frames(75)
 print("FIRE_SIEGE_ART_TOUR_COMPLETE")
 get_tree().quit()
