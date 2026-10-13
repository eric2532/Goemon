extends Node
var game
var output="user://tests/edo-redesign"
func frames(count: int):
 for i in range(count):await get_tree().physics_frame
func shot(label: String):
 game.player.invuln=0;game.player.model.visible=true
 await RenderingServer.frame_post_draw
 get_tree().root.get_texture().get_image().save_png(ProjectSettings.globalize_path(output+"/"+label+".png"))
 print("EDO_DESIGN_CAPTURE ",label)
func input_action(action: String,down: bool):
 var e=InputEventAction.new();e.action=action;e.pressed=down;Input.parse_input_event(e);Input.flush_buffered_events()
func reset():
 var p=game.player
 input_action("light_attack",false);p.cancel_charge();p.clear_powerups();p.musashi.shield_cooldown=0
 for n in get_tree().get_nodes_in_group("projectiles"):n.queue_free()
 game.reset_player_at(Vector3(0,.1,205));p.facing=Vector3.FORWARD;p.model.rotation.y=0
 await frames(16)
func view(offset: Vector3,target: Vector3=Vector3(0,1.35,0)):
 var p=game.player;game.camera_rig.camera.global_position=p.global_position+offset
 game.camera_rig.camera.look_at(p.global_position+target)
func run():
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
 await frames(4)
 game.smoke_test=true;game.tuning.freeze_ai=true;game.tuning.invincible=true;game.settings.volume=0.0
 ProjectSettings.set_setting("goemon/experimental_crosshair",true)
 game.player.smoke_mode=true;game.start_mode("defense");game.encounters.enabled=false;game.player.select_character(2)
 game.camera_rig.set_process(false);game.camera_rig.set_process_unhandled_input(false);Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
 for e in game.enemies:if is_instance_valid(e):e.queue_free()
 game.enemies.clear();await reset()
 for v in [["idle-front",Vector3(0,1.55,-5.5)],["idle-side",Vector3(5.5,1.55,0)],["idle-three-quarter",Vector3(3.1,1.85,-5.0)],["idle-back",Vector3(0,1.55,5.5)]]:
  view(v[1]);await frames(2);await shot(v[0])
 view(Vector3(3.1,1.85,-5.0));input_action("light_attack",true);await frames(1);input_action("light_attack",false)
 await frames(3);await shot("volley-windup");await frames(4);await shot("volley-release");await frames(8);await shot("volley-follow-through")
 await reset();view(Vector3(3.1,1.85,-5.0));input_action("heavy_attack",true);await frames(1);input_action("heavy_attack",false)
 await frames(4);await shot("giant-windup");await frames(7);await shot("giant-release");await frames(9);await shot("giant-follow-through")
 await reset();view(Vector3(3.1,1.85,-5.0));input_action("sky_strike",true);await frames(1);input_action("sky_strike",false)
 await frames(12);await shot("meteor-arm-raised");await frames(20);await shot("meteor-ground-strike")
 view(Vector3(8,7,-16),Vector3(0,1.2,-8));await frames(30);await shot("meteor-falling");await frames(25);await shot("meteor-impact")
 await reset();view(Vector3(3.1,1.85,-5.0));input_action("surge",true);await frames(1);input_action("surge",false);await frames(20);await shot("blue-surge")
 input_action("light_attack",true);await frames(20);await shot("beam-brace");input_action("light_attack",false);await frames(3)
 await reset();view(Vector3(4,3,-8));input_action("equip",true);await frames(1);input_action("equip",false);await frames(4);await shot("fire-dodge")
 await frames(30);await shot("dodge-arrival")
 game.show_main_menu();game.sound_library.cancel();game.music.stop()
 for voice in game.voices:voice.stop()
 await frames(10)
 print("EDO_REDESIGN_TOUR_OK ",Engine.get_version_info().string)
 get_tree().quit()
