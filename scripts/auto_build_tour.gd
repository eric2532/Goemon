extends "res://scripts/auto_attack_tour.gd"
func run():
 report_dir="res://build/auto-build/tour" if OS.has_feature("editor") else "user://build/auto-build/tour"
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(report_dir))
 if DisplayServer.get_name()=="headless":check(false,"Automatic construction tour requires rendering");finish();return
 get_tree().root.size=Vector2i(1440,900);Input.use_accumulated_input=false
 game.smoke_test=true;game.tuning=PrototypeTuning.DEFAULTS.duplicate();game.tuning.invincible=true;game.tuning.freeze_ai=true
 game.player.smoke_mode=true;game.camera_rig.set_process_unhandled_input(false)
 game.start_mode("defense");game.player.select_character(10);await frames(12)
 var run=game.encounters;var p=game.player;p.smoke_mode=false
 var site=game.world.cannon_sites[4];var tower=run.site_states[4].cannon
 check(not tower.visual_root.visible and not Input.is_action_pressed("siege_build"),"Distant empty sites remain subtle without build input")
 game.hud.banner_time=0;game.hud.toast_time=0;await shot("01-subtle-empty-sites")
 game.reset_player_at(site.build_position);game.camera_rig.yaw=0;game.camera_rig.pitch=.48;game.camera_rig.distance=12;game.camera_rig.reset_follow()
 await key(KEY_J);await frames(60)
 check(run.building and run.site_states[4].progress>.2 and run.site_states[4].progress<.6 and not Input.is_action_pressed("siege_build"),"Standing automatically progresses construction without B")
 check(tower.visual_root.visible and tower.progress_root.visible and not p.auto_attack_running(),"Ghost and circular ring show while automatic attacks pause")
 game.hud.banner_time=0;game.hud.toast_time=0;await shot("02-translucent-tower-counterclockwise-ring")
 hold_key(KEY_S,true);await frames(40);hold_key(KEY_S,false);await frames(20)
 check(not run.building and not tower.visual_root.visible,"Native movement away stops work and hides the preview")
 check(p.auto_attack_running(),"Automatic normal attacks resume away from construction")
 await key(KEY_J);game.reset_player_at(site.build_position);game.camera_rig.reset_follow();await frames(210)
 check(tower.completed and tower.visual_root.visible and not tower.progress_root.visible and run.money==5,"Returning finishes construction once and restores solid tower")
 game.hud.banner_time=0;game.hud.toast_time=0;await shot("03-completed-solid-tower")
 await frames(25);check(run.money==5 and tower.completion_events==1,"Standing after completion never pays twice")
 # A real jump and roll remain available while standing at an unfinished spot.
 game.reset_player_at(game.world.cannon_sites[5].build_position);await frames(20)
 await key(KEY_SPACE);await frames(12)
 check(not p.is_on_floor() and not run.building,"Native Space escapes automatic construction")
 await frames(60);await key(KEY_C)
 check(not run.building and p.active_ability.player.roll>0,"Native C quick roll escapes automatic construction")
 game.show_main_menu();await frames(3);game.sound_library.cancel();game.music.stop();finish()
func finish():
 var result={"suite":"automatic-construction-v245","checks":checks,"failures":failures,"screenshots":captures}
 FileAccess.open(report_dir.path_join("verification-manifest.json"),FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
 print("AUTO_BUILD_TOUR_RESULT checks=",checks," failures=",failures," captures=",captures.size())
 get_tree().quit(1 if failures else 0)
