extends "res://scripts/fire_siege_controls_tests.gd"
## Input-driven review on the unchanged Fire Siege battlefield.
func run():
 Input.use_accumulated_input=false
 game.smoke_test=true;game.tuning=PrototypeTuning.DEFAULTS.duplicate()
 game.tuning.invincible=true;game.player.smoke_mode=true
 game.selected_rogue_id=1;game.start_mode("defense");await frames(4)
 game.encounters.choose_card("supply_cache");await frames(4)
 var p=game.player
 var gate:Vector3=game.world.lanes[1][0]
 game.reset_player_at(gate+Vector3(0,.1,40));game.camera_rig.yaw=0;game.camera_rig.distance=11
 game.camera_rig.pitch=.46;game.camera_rig.reset_follow()
 print("FIRE_SIEGE_TOUR live straight-lane wave")
 for i in range(12):
  p.smoke_move=Vector2(0,-.16) if i<5 else Vector2.ZERO
  tap("light_attack")
  if i==7:tap("dodge")
  if i==9:tap("jump")
  await frames(60)
 p.smoke_move=Vector2.ZERO
 pause_fixture_director();game.tuning.freeze_ai=true
 for id in range(1,13):
  press("light_attack",false);press("heavy_attack",false)
  p.cancel_charge();p.clear_powerups();p.select_character(id)
  if p.is_rogue_character():p.active_ability.reset_run()
  await clear_enemies();game.reset_player_at(TEST_ORIGIN)
  p.hp=p.max_hp;p.facing=Vector3.FORWARD;p.soft_target=false
  game.camera_rig.yaw=0;game.camera_rig.pitch=.46;game.camera_rig.distance=10;game.camera_rig.reset_follow()
  var near=fixture(Vector3(0,0,-2.3));var far=fixture(Vector3(0,0,-7.5))
  print("FIRE_SIEGE_TOUR hero=",id)
  game.toast("%s · CAMERA-FACING CONTROLS" % (p.RogueRoster.name_for(id) if p.is_rogue_character() else p.ROSTER[id].name))
  await frames(25);press("light_attack");await frames(110);press("light_attack",false);await frames(30)
  press("heavy_attack");await frames(60);press("heavy_attack",false);await frames(20)
  tap("dodge");await frames(35)
  if id in [1,2,11,12]:tap("equip");await frames(35)
  tap("jump");await frames(50)
  tap("surge");await frames(20);tap("light_attack");await frames(60)
  p.smoke_move=Vector2(0,-.45)
  for frame in range(50):
   game.camera_rig.yaw+=.012
   await frames(1)
  p.smoke_move=Vector2.ZERO;await frames(15)
  print("FIRE_SIEGE_TOUR hero=",id," near damage=",10000-near.hp," far damage=",10000-far.hp)
 game.show_rogue_roster();await frames(100)
 print("FIRE_SIEGE_TOUR_COMPLETE")
 get_tree().quit()
