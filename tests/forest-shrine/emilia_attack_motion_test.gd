extends "res://tests/forest-shrine/emilia_skin_review_test.gd"
## Replay the fitted attacks on flat ground without an interactive popup.
func run():
 create_timer(240).timeout.connect(func():printerr("EMILIA_ATTACK_MOTION_TIMEOUT");quit(1))
 root.size=Vector2i(1280,800);root.gui_disable_input=true
 game=load("res://scenes/forest_title.tscn").instantiate();game.settings_path=cfg;root.add_child(game);current_scene=game;await frames(3)
 game.set_process(false);game.set_physics_process(false);game.player.set_physics_process(false)
 game.army_runtime.set_process(false);game.army_runtime.set_physics_process(false);game.camera_rig.set_process(false)
 game.settings.forest_pet_loadout=[];game.settings.gear_loadouts={};game.settings.disable_character_cooldowns=false
 game.begin_arena();game.choose_rogue_character(42);await frames(3)
 game.equipment_hub.enter_button.pressed.emit();await frames(3)
 game.clear_menu();game.forest_ui.hide();game.playing=true;game.paused=false;paused=false
 home=Vector3(0,0,60);home.y=game.model.world_height(home.x,home.z)+.05
 game.player.position=home;game.player.set_auto_attack(false)
 game.model.waves.patrol_posts.clear();game.model.waves.crossgate_pet_test=true
 if is_instance_valid(game.training_dummy):game.training_dummy.home=home+Vector3.DOWN*1000;game.training_dummy.position=game.training_dummy.home
 game.camera_rig.camera.global_position=home+Vector3(0,4,14);game.camera_rig.camera.look_at(home+Vector3.UP*1.6)
 for skin in [120387,120388,111669]:
  choose_skin(42,skin)
  game.player.position=home;game.player.model.show()
  game.camera_rig.camera.global_position=home+Vector3(0,4,14);game.camera_rig.camera.look_at(home+Vector3.UP*1.6);game.camera_rig.camera.make_current()
  print("EMILIA_MOTION_VIEW skin=",skin," player=",game.player.global_position," camera=",game.camera_rig.camera.global_position," scale=",game.model.falan_scale)
  await review_attack_motion(game.player.model,skin)
 print("EMILIA_ATTACK_MOTION_RESULT checks=%d failures=%d"%[checks,failures])
 game.queue_free();current_scene=null;paused=false;await frames(4)
 DirAccess.remove_absolute(ProjectSettings.globalize_path(cfg));quit(1 if failures else 0)
