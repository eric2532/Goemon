extends "res://scripts/fire_siege_controls_tests.gd"

func run():
 Input.use_accumulated_input=false
 game.smoke_test=true;game.tuning=PrototypeTuning.DEFAULTS.duplicate()
 game.tuning.invincible=true;game.tuning.freeze_ai=true;game.player.smoke_mode=true
 game.start_mode("defense");pause_fixture_director();game.encounters.choose_card("supply_cache")
 var p=game.player
 for id in [1,9,5,7]:
  p.select_character(id);p.cancel_charge();p.smoke_move=Vector2.ZERO
  p.facing=Vector3.FORWARD;game.reset_player_at(Vector3(0,.1,205));p.model.rotation.y=0
  if p.is_rogue_character():p.active_ability.reset_run()
  game.camera_rig.yaw=0;game.camera_rig.pitch=.4;game.camera_rig.distance=9;game.camera_rig.reset_follow()
  game.toast("%s · Idle camera orbit: body stays planted" % (p.RogueRoster.name_for(id) if id>2 else "Goemon"))
  await frames(25)
  for frame in range(120):
   game.camera_rig.yaw=sin(float(frame)/119*TAU)*.9
   await frames(1)
  game.toast("Side-step / backpedal · Smooth body turn")
  game.camera_rig.yaw=.8;p.smoke_move=Vector2.RIGHT;await frames(45)
  p.smoke_move=Vector2(0,.6);await frames(40)
  p.smoke_move=Vector2.ZERO;game.camera_rig.yaw=0;await frames(25)
  tap("light_attack");await frames(70)
 game.show_pause();await frames(60);get_tree().quit()
