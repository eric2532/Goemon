extends "res://scripts/fire_siege_mvp_tests.gd"
func run():
 game.smoke_test=true;game.tuning=PrototypeTuning.DEFAULTS.duplicate();game.tuning.freeze_ai=true;game.tuning.invincible=true;game.player.smoke_mode=true
 game.start_mode("defense");await frames(3)
 var run=game.encounters;var p=game.player;run.set_physics_process(false)
 var site=game.world.cannon_sites[4];var tower=run.site_states[4].cannon
 check(not tower.visual_root.visible,"Distant empty tower spot hides its full model")
 tower.set_proximity(true,true);tower.set_build_progress(.25,true)
 var fill=tower.progress_fill as MeshInstance3D
 var bounds=fill.mesh.get_aabb() if fill!=null else AABB()
 check(fill!=null and bounds.position.x<-.6 and bounds.end.x<.001 and bounds.position.y>-.001 and bounds.end.y>.6 and bounds.size.z<.001,"Quarter-circle construction fills from twelve o'clock counterclockwise to nine o'clock")
 tower.set_proximity(false,true);tower.set_build_progress(0,false)
 game.reset_player_at(site.build_position);await frames(20);p.set_physics_process(false);p.velocity=Vector3.ZERO
 press("siege_build",false);run.tick(1.5)
 check(is_equal_approx(run.site_states[4].progress,.5) and run.money==10,"Standing beside a tower automatically builds halfway without B")
 check(game.siege_building() and tower.visual_root.visible and tower.progress_root.visible,"Automatic construction owns hero interaction and shows preview and progress")
 var ghost=tower.visual_root.find_children("*","MeshInstance3D",true,false).any(func(mesh):return mesh.material_override is StandardMaterial3D and mesh.material_override.albedo_color.a<.5)
 check(ghost,"Nearby unpaid tower is translucent")
 p.position+=Vector3(20,0,0);run.tick(1)
 check(is_equal_approx(run.site_states[4].progress,.25) and not tower.visual_root.visible,"Leaving decays unpaid progress and hides distant preview")
 game.reset_player_at(site.build_position);p.velocity=Vector3(3,0,0);run.tick(.5)
 check(not run.building,"Moving beside the spot cannot automatically buy a tower")
 p.velocity=Vector3.ZERO;run.tick(2.625)
 check(run.site_states[4].level==1 and run.money==5 and tower.completion_events==1,"Standing again resumes and charges five gold once")
 check(tower.completed and tower.visual_root.visible and not tower.progress_root.visible and tower.visual_root.find_children("*","MeshInstance3D",true,false).all(func(mesh):return not (mesh.material_override is StandardMaterial3D and mesh.material_override.albedo_color.a<.5)),"Completed tower becomes opaque and hides construction ring")
 run.tick(4);check(run.money==5 and tower.completion_events==1,"Staying after completion cannot charge twice")
 game.reset_player_at(game.world.cannon_sites[5].build_position);p.velocity=Vector3.ZERO;run.money=4;run.tick(4)
 check(run.site_states[5].level==0 and run.site_states[5].progress==0 and not game.siege_building(),"Insufficient gold prevents automatic construction and preserves attacks")
 run.money=5;run.tick(1);game.show_pause();var before=run.site_states[5].progress;run.tick(4)
 check(run.site_states[5].progress==before,"Pause freezes automatic construction")
 game.resume();p.velocity=Vector3.ZERO;run.tick(2)
 check(run.site_states[5].level==1 and run.money==0,"Resume finishes nearby automatic construction")
 game.reset_player_at(game.world.mine_build_position);p.velocity=Vector3.ZERO;run.money=10;run.tick(4)
 check(run.mine_built and run.money==0,"Mine uses automatic four-second construction and one ten-gold payment")
 p.set_physics_process(true);game.show_main_menu();finish()
func finish():
 print("AUTO_BUILD_RESULT checks=",checks," failures=",failures)
 game.sound_library.cancel();game.music.stop();await frames(3);get_tree().quit(1 if failures else 0)
