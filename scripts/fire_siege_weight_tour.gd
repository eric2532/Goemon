extends "res://scripts/fire_siege_controls_tests.gd"
## Actual player motion plus fixed front/profile cameras for visual review.
func run():
 Input.use_accumulated_input=false
 game.smoke_test=true;game.tuning=PrototypeTuning.DEFAULTS.duplicate()
 game.tuning.invincible=true;game.tuning.freeze_ai=true;game.player.smoke_mode=true
 game.start_mode("defense");pause_fixture_director();game.encounters.choose_card("supply_cache")
 game.camera_rig.set_process(false)
 output_dir=OS.get_environment("GOEMON_REVIEW_DIR")
 if output_dir.is_empty():output_dir="user://tests/fire-siege-weight"
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output_dir))
 var p=game.player
 for i in range(10):
  await fresh_class(i)
  game.reset_player_at(Vector3(0,.1,205));game.camera_rig.yaw=0
  p.facing=Vector3.FORWARD;p.model.rotation.y=0;p.active_ability.reset_run()
  var actor=p.active_ability.visual_actor
  actor.model.scale.z=1
  game.toast("%s · Previous profile" % CLASS_IDS[i]);await view_frames(18,Vector3(6,2.7,.1))
  await capture("%s-before" % CLASS_IDS[i])
  actor.model.scale.z=1.15
  game.toast("%s · Fuller profile +15%%" % CLASS_IDS[i]);await view_frames(18,Vector3(6,2.7,.1))
  await capture("%s-after" % CLASS_IDS[i])
  game.toast("%s · Side weight and weapon follow-through" % CLASS_IDS[i])
  p.smoke_move=Vector2(-.7,0);await view_frames(38,Vector3(0,2.9,-6.7))
  await capture("%s-left" % CLASS_IDS[i])
  p.smoke_move=Vector2(.7,0);await view_frames(55,Vector3(0,2.9,-6.7))
  await capture("%s-right" % CLASS_IDS[i])
  p.smoke_move=Vector2.ZERO;await view_frames(25,Vector3(0,2.9,-6.7))
  game.toast("%s · Accelerate, sprint, stop" % CLASS_IDS[i])
  press("sprint");p.smoke_move=Vector2(0,-1);await view_frames(42,Vector3(5,3,4))
  await capture("%s-sprint" % CLASS_IDS[i])
  press("sprint",false);p.smoke_move=Vector2.ZERO;await view_frames(30,Vector3(5,3,4))
  if i==6:
   game.reset_player_at(Vector3(0,.1,205));p.active_ability.reset_run()
   p.smoke_move=Vector2(-.6,0);await view_frames(25,Vector3(0,2.9,-6.7))
   tap("light_attack");await view_frames(35,Vector3(0,2.9,-6.7))
   p.smoke_move=Vector2(.6,0);tap("heavy_attack");await view_frames(30,Vector3(0,2.9,-6.7))
   tap("jump");await view_frames(12,Vector3(5,3,4));tap("jump");await view_frames(60,Vector3(5,3,4))
   tap("surge");await view_frames(25,Vector3(5,3,4));p.smoke_move=Vector2.ZERO
  print("WEIGHT_TOUR hero=",CLASS_IDS[i]," complete")
 print("WEIGHT_TOUR_COMPLETE output=",ProjectSettings.globalize_path(output_dir))
 get_tree().quit()

func view_frames(count: int, offset: Vector3):
 for n in range(count):
  game.camera_rig.camera.global_position=game.player.global_position+offset
  game.camera_rig.camera.look_at(game.player.global_position+Vector3.UP*1.25)
  await frames(1)

func capture(label: String):
 await RenderingServer.frame_post_draw
 get_viewport().get_texture().get_image().save_png(output_dir.path_join(label+".png"))
