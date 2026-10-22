extends Node
## Actual collision/movement and casting; deterministic captures are not an FPS test.
var game
var output="user://tests/edo-gait"
var frame_id=0
var capturing=false
var offset=Vector3(4.8,2.4,-2.8)
func input_action(action: String,down: bool):
 var event=InputEventAction.new();event.action=action;event.pressed=down;Input.parse_input_event(event);Input.flush_buffered_events()
func frames(count: int):
 for i in range(count):
  await get_tree().physics_frame
  var p=game.player
  game.camera_rig.camera.global_position=p.global_position+offset
  game.camera_rig.camera.look_at(p.global_position+Vector3.UP*1.35)
  if capturing and i%3==0:
   p.invuln=0;p.model.visible=true
   await RenderingServer.frame_post_draw
   var img=get_tree().root.get_texture().get_image();img.resize(768,480,Image.INTERPOLATE_LANCZOS)
   img.save_png(ProjectSettings.globalize_path(output+"/%04d.png"%frame_id));frame_id+=1
func section(label: String,movement: Vector2,count=60):
 game.player.smoke_move=Vector2.ZERO;game.player.cancel_charge()
 game.reset_player_at(Vector3(0,.1,205));game.player.facing=Vector3.FORWARD;game.player.model.rotation.y=0
 await frames(18)
 game.toast(label);game.player.smoke_move=movement
 capturing=true;await frames(count);capturing=false
 print('EDO_GAIT_CAPTURE ',label)
func run():
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
 game.smoke_test=true;game.tuning.freeze_ai=true;game.tuning.invincible=true;game.settings.volume=0.0
 game.player.smoke_mode=true;game.start_mode('defense');game.encounters.enabled=false
 game.camera_rig.set_process(false);game.camera_rig.set_process_unhandled_input(false);game.camera_rig.yaw=0
 Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
 for enemy in game.enemies:if is_instance_valid(enemy):enemy.queue_free()
 game.enemies.clear();await frames(12)
 for id in [2,11,5]:
  game.player.select_character(id);game.player.clear_powerups()
  if game.player.is_rogue_character():game.player.active_ability.reset_run()
  output='user://tests/edo-gait/hero-'+str(id);DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output));frame_id=0
  await section('Walk · '+str(id),Vector2(0,-.65))
  await section('Turn and strafe · '+str(id),Vector2(1,0))
  offset=Vector3(4.8,2.1,2.8);input_action('sprint',true)
  await section('Run · '+str(id),Vector2(0,-1));input_action('sprint',false)
  input_action('jump',true);await frames(1);input_action('jump',false)
  game.toast('Jump and land · '+str(id));capturing=true;await frames(80);capturing=false
  offset=Vector3(4.8,2.4,-2.8)
  game.player.smoke_move=Vector2.ZERO;game.reset_player_at(Vector3(0,.1,205));await frames(18)
  game.toast('Moving attack · '+str(id));game.player.smoke_move=Vector2(.65,-.5);input_action('light_attack',true)
  capturing=true;await frames(80);capturing=false;input_action('light_attack',false)
  game.toast('Stop and settle · '+str(id));game.player.smoke_move=Vector2.ZERO;capturing=true;await frames(50);capturing=false
  print('EDO_GAIT_HERO_COMPLETE ',id,' frames=',frame_id)
 game.show_main_menu();game.sound_library.cancel();game.music.stop()
 for voice in game.voices:voice.stop()
 await frames(8)
 print('EDO_GAIT_TOUR_OK');get_tree().quit()
