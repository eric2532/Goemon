extends "res://scripts/map_builder_tour.gd"

func frames(count: int):
 for i in range(count):await get_tree().physics_frame

func hold_key(code: int,held: bool):
 var event=InputEventKey.new();event.keycode=code;event.physical_keycode=code;event.pressed=held
 Input.parse_input_event(event);Input.flush_buffered_events()

func run():
 report_dir="res://build/auto-attack/tour" if OS.has_feature("editor") else "user://build/auto-attack/tour"
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(report_dir))
 if DisplayServer.get_name()=="headless":check(false,"Auto attack tour requires rendering");finish();return
 get_tree().root.size=Vector2i(1440,900);Input.use_accumulated_input=false
 game.smoke_test=true;game.tuning=PrototypeTuning.DEFAULTS.duplicate();game.tuning.invincible=true;game.tuning.freeze_ai=true
 game.player.smoke_mode=true;game.camera_rig.set_process_unhandled_input(false)
 game.start_mode("defense")
 for director in [game.encounters,game.kennel,game.barracks]:director.set_physics_process(false)
 var p=game.player;p.select_character(10);game.reset_player_at(Vector3(0,.15,195));game.camera_rig.reset_follow();await frames(12)
 check(game.is_fire_siege() and not p.auto_attack_enabled,"Latest Fire Siege starts with automatic attack OFF")
 await key(KEY_J);await frames(60)
 var a=p.active_ability
 check(p.auto_attack_enabled and a.player.rangerShots>=3 and not Input.is_action_pressed("light_attack"),"Real J starts repeated Ranger shots without clicking")
 await shot("01-ranger-auto-attack")
 await key(KEY_ESCAPE);var shots=a.player.rangerShots;await frames(15)
 check(game.paused and a.player.rangerShots==shots and p.auto_attack_enabled,"Native Escape pauses automatic fire")
 game.resume();await frames(20);check(a.player.rangerShots>shots,"Automatic fire resumes after pause")
 await key(KEY_J);await frames(35);shots=a.player.rangerShots;await frames(30)
 check(not p.auto_attack_enabled and a.player.rangerShots==shots,"Real J stops repeated Ranger shots")
 p.cancel_charge();a.reset_run();p.position+=Vector3.UP*20;await frames(2)
 p.velocity=Vector3(0,-5,0);p.jumps_used=2;p.coyote=0;p.jump_buffer=0
 hold_key(KEY_SPACE,true);await key(KEY_J);await frames(35)
 check(a.player.rangerGliding and a.player.rangerShots>=2 and a.projectiles.any(func(pr):return pr.vel.y<0),"Held Space and J fire downward fans during Ranger glide")
 await shot("02-ranger-gliding-auto-fan")
 hold_key(KEY_SPACE,false);await key(KEY_J)
 game.reset_player_at(Vector3(0,.15,195));p.cancel_charge();await frames(10)
 await key(KEY_J);await key(KEY_C)
 check(p.auto_attack_enabled and not p.auto_attack_running(),"Quick roll suspends new automatic attacks")
 await frames(30);check(p.auto_attack_running(),"Automatic attacks resume after the quick roll")
 await key(KEY_J);game.show_main_menu();await frames(3);game.sound_library.cancel();game.music.stop();finish()

func finish():
 var result={"suite":"auto-attack-v244","checks":checks,"failures":failures,"screenshots":captures}
 FileAccess.open(report_dir.path_join("verification-manifest.json"),FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
 print("AUTO_ATTACK_TOUR_RESULT checks=",checks," failures=",failures," captures=",captures.size())
 get_tree().quit(1 if failures else 0)
