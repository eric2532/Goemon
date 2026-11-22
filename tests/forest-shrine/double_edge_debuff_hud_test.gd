extends "res://tests/forest-shrine/crossgate_blast_coverage_test.gd"
const Evidence="res://build/Other Files/Skill Levels/Double Edge Debuff/"

func picture(filename:String):
 if DisplayServer.get_name()=="headless":return
 game.forest_ui.sync()
 await process_frame;await RenderingServer.frame_post_draw
 check(root.get_texture().get_image().save_png(Evidence+filename+".png")==OK,"Rendered "+filename)

func run():
 create_timer(120).timeout.connect(func():printerr("DOUBLE_EDGE_HUD_TIMEOUT");quit(1))
 DirAccess.make_dir_recursive_absolute(Evidence)
 root.size=Vector2i(1280,800);root.set_flag(Window.FLAG_NO_FOCUS,true)
 var doc=load("res://scripts/forest/forest_map_document.gd").new();doc.load_wind_meadow()
 await setup_fixture(doc.data)
 var p=game.player;var hud=game.forest_ui;var camera=game.camera_rig.camera
 game.set_process(false);game.army_runtime.set_process(false);game.army_runtime.set_physics_process(false);game.camera_rig.set_process(false)
 for node in [game,p,game.camera_rig,hud]:node.set_process_input(false);node.set_process_unhandled_input(false)
 root.gui_disable_input=true
 driver=load("res://tests/forest-shrine/physics_step_driver.gd").new();root.add_child(driver)
 home.y=game.model.surface_height(home.x,home.z)+.05;game.model.update_vision(home)
 p.select_character(37);fresh();p.model.select_stance(2);p.position=home
 await driver.advance(20,advance)
 camera.global_position=home+Vector3(10,8,16);camera.look_at(home+Vector3.UP*2)
 hud.sync();var badge=hud.double_edge_debuff
 check(not badge.visible,"No debuff display before casting")
 for level_ in [1,30]:
  Skills.set_level(p,"shin/double-edge",level_);p.active_ability.cancel(true);p.active_ability.clear_cooldowns()
  p.active_ability.start_shin_area_cast();hud.sync()
  check(badge.visible and hud.double_edge_amount.text==("DEF −10%" if level_==1 else "DEF −39%") and hud.double_edge_time.text=="10.0s","Cast displays the real defense reduction and ten seconds")
  var feet=camera.unproject_position(p.global_position)
  check(badge.position.y>feet.y and absf(badge.get_global_rect().get_center().x-feet.x)<1,"The badge is centred underneath the character's feet")
  await driver.advance(90,advance);hud.sync()
  check(hud.double_edge_time.text=="8.5s","Countdown follows elapsed gameplay time")
  await picture("level-%02d"%level_)
 var original_position=badge.position
 p.position.x+=3;hud.sync()
 check(badge.position.distance_to(original_position)>10,"The debuff follows the moving character")
 var remaining=p.double_edge_left
 game.paused=true;await driver.advance(12,advance);hud.sync()
 check(p.double_edge_left==remaining,"Pausing gameplay also pauses the displayed debuff timer")
 game.paused=false
 p.active_ability.cancel(true);p.active_ability.clear_cooldowns();p.active_ability.start_shin_area_cast();hud.sync()
 check(hud.double_edge_time.text=="10.0s" and hud.double_edge_amount.text=="DEF −39%","Recasting refreshes the existing badge instead of stacking it")
 p.active_ability.cancel(true)
 await driver.advance(610,advance);hud.sync()
 check(not badge.visible and p.double_edge_left==0,"Badge disappears when defense returns to normal")
 p.double_edge_left=3.21;p.double_edge_penalty=.39;hud.sync()
 check(hud.double_edge_time.text=="3.3s","Remaining tenths round up instead of displaying zero early")
 p.hp=0;hud.sync();check(not badge.visible,"A dead character has no floating debuff display");p.hp=p.max_hp
 var pose=camera.global_transform
 camera.look_at(camera.global_position+(camera.global_position-p.global_position));hud.sync()
 check(not badge.visible,"A character behind the camera does not leave an onscreen badge")
 camera.global_transform=pose
 root.size=Vector2i(960,640);game.settings.forest_hud_scale=1.25;await frames(3);hud.sync()
 check(badge.visible and badge.scale==Vector2.ONE*1.25 and root.get_visible_rect().encloses(badge.get_global_rect()),"Badge follows HUD scaling and fits a smaller window")
 await picture("small-window")
 var nodes=get_node_count();var resources=Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)
 for i in 600:p.double_edge_left=10.0-float(i)/60.0;hud.sync_double_edge_debuff()
 check(get_node_count()==nodes and Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)<=resources,"Repeated timer updates reuse the same controls and resources")
 p.double_edge_left=0;hud.sync();check(not badge.visible,"Cleared run debuff hides the badge")
 print("DOUBLE_EDGE_HUD_RESULT checks=%d failures=%d"%[checks,failures])
 game.queue_free();paused=false;await frames(3)
 if FileAccess.file_exists(cfg):DirAccess.remove_absolute(ProjectSettings.globalize_path(cfg))
 quit(1 if failures else 0)
