extends "res://scripts/fire_siege_controls_tests.gd"
## Front-facing view makes the shoulder/neck weight shift easy to compare.
func run():
 Input.use_accumulated_input=false
 game.smoke_test=true;game.tuning=PrototypeTuning.DEFAULTS.duplicate()
 game.tuning.invincible=true;game.tuning.freeze_ai=true;game.player.smoke_mode=true
 game.start_mode("defense");pause_fixture_director();game.encounters.choose_card("supply_cache")
 var p=game.player
 game.camera_rig.set_process(false)
 var sound_only: bool = "--fire-siege-sound-tour" in OS.get_cmdline_user_args()
 for i in range(0 if sound_only else 10):
  await fresh_class(i)
  game.reset_player_at(Vector3(0,.1,205));game.camera_rig.yaw=0
  p.facing=Vector3.FORWARD;p.model.rotation.y=0;p.active_ability.reset_run()
  var camera=game.camera_rig.camera
  camera.global_position=Vector3(0,3.5,198);camera.look_at(Vector3(0,1.3,205))
  game.toast("%s · Shoulder and neck weight shift" % CLASS_IDS[i])
  await frames(18)
  p.smoke_move=Vector2(.45,0);await frames(20)
  p.smoke_move=Vector2(-.45,0);await frames(40)
  p.smoke_move=Vector2(.45,0);await frames(20)
  p.smoke_move=Vector2.ZERO;await frames(25)
  print("LEAN_TOUR hero=",i+3," complete")
 # Keep the actual collision/contact path, but isolate the sword audio from music.
 await fresh_class(6)
 game.reset_player_at(Vector3(0,.1,205));game.camera_rig.yaw=0
 p.facing=Vector3.FORWARD;p.model.rotation.y=0;p.active_ability.reset_run()
 game.camera_rig.camera.global_position=Vector3(5,3.7,199)
 game.camera_rig.camera.look_at(Vector3(0,1.2,204))
 game.music.stop();game.sound_library.cancel()
 for voice in game.voices:voice.stop()
 game.toast("Magic Swordsman · Empty swing, then three sword contacts")
 await frames(20)
 tap("light_attack");await frames(75)
 var victim=fixture(Vector3(0,0,-2.3));victim.training_dummy=true
 press("light_attack");await frames(100);press("light_attack",false)
 await frames(45)
 if sound_only:
  await clear_enemies()
  p.active_ability.reset_run()
  game.reset_player_at(Vector3(0,.1,205));game.camera_rig.yaw=0
  game.camera_rig.camera.global_position=Vector3(4,3.7,211)
  game.camera_rig.camera.look_at(Vector3(0,1.3,201))
  game.toast("Energy wave · Blade release and travelling energy")
  await frames(20);tap("heavy_attack");await frames(140)
  fixture(Vector3(0,0,-6));tap("heavy_attack");await frames(120)
 print("LEAN_AUDIO_TOUR_COMPLETE")
 get_tree().quit()
