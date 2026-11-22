extends "res://scripts/recovered_leaders_tests.gd"
const MenuSkin=preload("res://scripts/forest/preparation_skin.gd")
const OUT="res://build/Other Files/Cross Gate Menu and Waves/"
func settle():
 for i in 14:await process_frame
func shot(label_:String):
 if DisplayServer.get_name()=="headless":return
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(OUT+label_+".png")
func fits(control:Control,label_:String):
 check(root.get_visible_rect().encloses(control.get_global_rect()),label_+" fits the window")
func run():
 create_timer(180).timeout.connect(func():quit(1))
 DirAccess.make_dir_recursive_absolute(OUT)
 root.content_scale_size=Vector2i.ZERO;root.size=Vector2i(1280,800)
 set_meta("forest_painterly_preview",true)
 game=load("res://scenes/forest_title.tscn").instantiate()
 game.settings_path="user://crossgate-menu-%d.cfg"%OS.get_process_id()
 root.add_child(game);current_scene=game;await settle()
 game.set_physics_process(false);game.set_process(false);game.player.set_physics_process(false)
 AudioServer.set_bus_mute(0,true)
 check(MenuSkin.PANEL.resource_path.ends_with("crossgate/menu/panel.svg"),"Shared panels use the recovered ivory frame")
 check(MenuSkin.button_style("normal").texture==MenuSkin.BUTTON and MenuSkin.INK==Color("25343c"),"Shared buttons use ivory with slate labels")
 for dimensions in [Vector2i(1280,800),Vector2i(960,600)]:
  root.size=dimensions;await settle()
  var suffix="-%dx%d"%[dimensions.x,dimensions.y]
  game.show_title();await settle()
  fits(game.find_child("TitleFrame",true,false),"Title")
  await shot("title"+suffix)
  game.begin_forest();await settle()
  var picker=game.menu.find_child("RosterGrid",true,false).get_parent().get_parent().get_parent().get_parent()
  fits(picker.find_child("RosterToolbar",true,false),"Character toolbar")
  for card in picker.cards:
   check(card.get_global_rect().encloses(card.get_child(0).get_global_rect()),"Character card contents fit: "+card.name+suffix)
   check(card.get_theme_stylebox("normal").texture==MenuSkin.COMPACT,"Character card shares the ivory frame")
  await shot("characters"+suffix)
  check(picker.find_child("SpellEquipmentButton",true,false)==null,"Character selection leaves loadout editing to Equipment")
  game.choose_rogue_character(34);await settle()
  fits(game.equipment_hub.panel,"Equipment")
  await shot("equipment"+suffix)
  game.show_pet_loadout();await settle()
  fits(game.pet_loadout_panel.panel,"Pet picker")
  fits(game.pet_loadout_panel.find_child("ClosePetLoadout",true,false),"Pet close button")
  await shot("pets"+suffix)
  game.close_pet_loadout();game.equipment_hub.enter_map();await settle()
  var waves=game.model.waves
  waves.released_waves=2;game.model.wave=2;waves.wave_clock=10
  game.forest_ui.sync();await settle()
  var timer=game.forest_ui.wave_countdown
  check(timer.text.contains("N · E OPENS 00:10"),"HUD shows the active entrance and incoming side")
  check(timer.size.y>=timer.get_combined_minimum_size().y,"Three-line wave timer fits its frame")
  fits(timer,"Wave timer")
  check(not timer.get_global_rect().intersects(game.forest_ui.hero_dock.get_global_rect()),"Wave timer clears the hero HUD")
  for factor in [.65,1.25]:
   game.settings.forest_hud_scale=factor;game.forest_ui.sync();await settle()
   fits(timer,"Scaled wave timer")
   check(not timer.get_global_rect().intersects(game.forest_ui.hero_dock.get_global_rect()),"Scaled wave timer clears the hero HUD")
  game.settings.forest_hud_scale=1.0;game.forest_ui.sync();await settle()
  await shot("warning"+suffix)
  game.show_pause();await settle();fits(game.forest_ui.overlay,"Pause menu");await shot("pause"+suffix)
  game.show_settings(true);await settle()
  for control in game.menu.find_child("SettingsCanvas",true,false).get_children():fits(control,"Settings control")
  await shot("settings"+suffix);game.resume()
  var progression=game.model.team_progression
  progression.cards_enabled=true;progression.award_enemy(progression.kills_required()*10)
  game.show_team_upgrade();await settle()
  fits(game.team_upgrade_picker.panel,"Upgrade picker")
  for card in game.team_upgrade_picker.buttons:
   check(card.get_theme_stylebox("normal").texture==MenuSkin.PANEL,"Upgrade cards share the recovered frame")
  await shot("upgrades"+suffix)
  game.choose_team_upgrade(progression.offer[0],progression.choice_level());await settle()
 var path=game.settings_path
 stop_audio(game);current_scene=null;game.queue_free();paused=false;await settle()
 DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
 print("CROSSGATE_MENU_RESULT checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)
