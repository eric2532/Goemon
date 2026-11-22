extends "res://scripts/recovered_goemon_gameplay_tests.gd"
const OUT="res://build/Other Files/Asset Toolkit/League HUD/Skills/"
const Roster=preload("res://scripts/rogue_roster.gd")
func capture(stem:String):
 if DisplayServer.get_name()=="headless":return
 await frames(3);await RenderingServer.frame_post_draw
 check(root.get_texture().get_image().save_png(OUT+stem+".png")==OK,"Captured "+stem)
func run():
 create_timer(180).timeout.connect(func():printerr("SKILL_KEY_HUB_TIMEOUT");quit(1))
 DirAccess.make_dir_recursive_absolute(OUT)
 root.content_scale_size=Vector2i.ZERO;root.size=Vector2i(1280,800)
 game=load("res://scenes/forest_title.tscn").instantiate();game.settings_path=cfg;root.add_child(game);current_scene=game;await frames(5)
 game.begin_arena();game.choose_rogue_character(34);await frames(3);game.equipment_hub.enter_map();await frames(3)
 game.set_process(false);game.set_physics_process(false);game.player.set_physics_process(false)
 game.army_runtime.set_process(false);game.army_runtime.set_physics_process(false)
 game.camera_rig.set_process(false);game.forest_ui.set_process(false)
 AudioServer.set_bus_mute(0,true);Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
 var ui=game.forest_ui;var p=game.player
 p.position=Vector3(-150,game.model.surface_height(-150,127)+.1,127)
 game.camera_rig.camera.global_position=p.position+Vector3(0,7,13);game.camera_rig.camera.look_at(p.position+Vector3.UP)
 ui.message_left=0;ui.sync();await frames(3)
 for id in Roster.CROSSGATE:
  p.select_character(id);ui.sync();await frames(3)
  var slots=p.spell_loadout.numbered_slots
  for i in slots.size():
   var button=ui.loadout_buttons[i]
   check(button.text.is_empty() and button.name=="LoadoutSlot%d"%(i+1) and button.disabled==slots[i].is_empty(),"Fighter %d key %d retains its key mapping and empty state"%[id,i+1])
   if not button.visible:continue
   check(button.get_global_rect().encloses(ui.helper_portraits[i].get_global_rect()),"Skill artwork fits its frame")
   check(button.get_global_rect().encloses(ui.loadout_cooldowns[i].get_global_rect()),"Status fits its frame")
   check(not ui.helper_portraits[i].get_global_rect().intersects(ui.loadout_cooldowns[i].get_global_rect()),"Status clears the artwork")
   check(button.get_node("Shortcut").text==str(i+1),"Each skill shows its actual number key")
   var frame=button.get_theme_stylebox("normal")
   check(frame is StyleBoxFlat and frame.border_color==ui.skin.attack_style().border_color and frame.corner_radius_top_left==1,"Square skill frames match the health/portrait panel")
  await capture("fighter-%d"%id)
 p.select_character(34)
 var catalog=p.spell_loadout.Catalog
 for entry in [["equip",catalog.DOUBLE_EDGE],["surge",catalog.COMBO],["sky_strike",catalog.SURE_STRIKE],["special_4",catalog.BEARS],["special_5",catalog.RECOVERY],["special_6",catalog.KAGEROU]]:
  check(p.spell_loadout.equip(34,entry[0],entry[1]),"Equipped reviewed skill for the combined HUD")
 ui.sync();await frames(3);await capture("integrated-six-skills")
 for dimensions in [Vector2i(1280,800),Vector2i(960,640)]:
  root.size=dimensions;await frames(4)
  for factor in [.65,1.0,1.25]:
   game.settings.forest_hud_scale=factor;ui.sync();await frames(3)
   check(root.get_visible_rect().encloses(ui.loadout_slots.get_global_rect()),"The six-key bar fits %s at %.2f HUD scale"%[dimensions,factor])
   check(ui.hero_dock.get_global_rect().encloses(ui.loadout_slots.get_global_rect()),"The skill row fits inside the hero frame")
   check(ui.loadout_slots.get_global_rect().end.y<=ui.player_health_bar.get_global_rect().position.y and is_equal_approx(ui.loadout_slots.get_global_rect().position.x,ui.player_health_bar.get_global_rect().position.x),"Skills align directly above health")
   check(not ui.hint.get_global_rect().intersects(ui.hero_dock.get_global_rect()),"Notifications clear the wider combined HUD")
   await capture("layout-%dx%d-%.2f"%[dimensions.x,dimensions.y,factor])
 root.size=Vector2i(1280,800);game.settings.forest_hud_scale=1.0;ui.sync();await frames(3)
 p.spell_loadout.number_input(6,true);p.spell_loadout.number_input(6,false);ui.sync()
 check(p.active_ability.kagerou_enabled and ui.loadout_buttons[5].button_pressed and ui.loadout_cooldowns[5].text=="ON","Key 6 retains its toggle and selected presentation")
 await capture("toggle-on")
 p.spell_loadout.number_input(6,true);p.spell_loadout.number_input(6,false);ui.sync()
 check(not p.active_ability.kagerou_enabled and not ui.loadout_buttons[5].button_pressed and ui.loadout_cooldowns[5].text=="OFF","Key 6 restores its inactive presentation")
 p.active_ability.combo_cooldown=4.2;ui.sync()
 check(ui.loadout_cooldowns[1].text=="4.2s","The original combo cooldown remains readable")
 check(ui.helper_portraits[1].modulate.r==.5 and ui.helper_portraits[1].get_global_rect().intersects(ui.loadout_cooldowns[1].get_global_rect()),"Cooldown sits over dimmed skill artwork")
 check(ui.loadout_buttons[1].get_global_rect().encloses(ui.loadout_cooldowns[1].get_global_rect()),"Cooldown stays within its skill frame")
 await capture("cooldown")
 p.active_ability.combo_cooldown=0;ui.sync();await frames(5)
 check(ui.helper_portraits[1].modulate==Color.WHITE and ui.loadout_cooldowns[1].position.y==41,"Ready skills restore artwork and their level footer")
 var nodes=get_node_count();var resources=Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)
 for i in 120:ui.sync()
 check(get_node_count()==nodes and Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)==resources,"Repeated HUD updates reuse prepared controls and resources")
 await finish()
func finish():
 var path=game.settings_path
 game.sound_library.cancel();game.music.stop();game.queue_free();paused=false;await frames(4)
 DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
 print("SKILL_KEY_HUB_RESULT checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)
