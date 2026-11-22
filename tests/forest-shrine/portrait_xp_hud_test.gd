extends SceneTree
const OUT="res://build/Other Files/Asset Toolkit/League HUD/Skills/Portraits/"
var game
var checks=0
var failures=0
var cfg="user://portrait-xp-hud-%d.cfg"%OS.get_process_id()
func _initialize():
 create_timer(120).timeout.connect(func():printerr("FAIL: portrait XP HUD timeout");quit(1))
 run.call_deferred()
func check(ok:bool,message:String):
 checks+=1
 if not ok:failures+=1;printerr("FAIL: "+message)
func frames(n:int=3):
 for i in n:await process_frame
func key(code:int,shift:bool=false):
 var event=InputEventKey.new();event.physical_keycode=code;event.shift_pressed=shift;event.pressed=true;game._input(event)
func capture(stem:String):
 if DisplayServer.get_name()=="headless":return
 game.forest_ui.message_left=0;game.forest_ui.sync()
 await frames();await RenderingServer.frame_post_draw
 check(root.get_texture().get_image().save_png(OUT+stem+".png")==OK,"Captured "+stem)
func verify_layout():
 var ui=game.forest_ui
 check(ui.team_xp_bar.is_visible_in_tree() and ui.team_level_label.is_visible_in_tree(),"Level and XP are visible with the character")
 check(ui.hero_dock.get_global_rect().encloses(ui.team_xp_bar.get_global_rect()) and ui.hero_dock.get_global_rect().encloses(ui.team_level_label.get_global_rect()),"Character hub contains both XP and level")
 check(ui.team_level_label.get_global_rect().intersects(ui.hero_portrait.get_global_rect()) and ui.team_level_label.position.x>ui.hero_portrait.position.x+ui.hero_portrait.size.x*.5,"Level badge sits at the portrait’s lower right")
 check(ui.team_xp_bar is TextureProgressBar and ui.team_xp_bar.radial_fill_degrees==180 and ui.team_xp_bar.fill_mode==TextureProgressBar.FILL_COUNTER_CLOCKWISE,"Purple XP fills a half circle around the portrait")
 check(ui.team_xp_bar.get_global_rect().encloses(ui.hero_portrait.get_global_rect()),"XP semicircle surrounds the original head")
 check(ui.player_health_bar.get_global_rect().encloses(ui.health.get_global_rect()) and ui.health.horizontal_alignment==HORIZONTAL_ALIGNMENT_CENTER,"HP numbers are centered inside the health bar")
 check(ui.health.get_combined_minimum_size().x<=ui.health.size.x,"Current and maximum HP fit inside the bar")
 check(ui.team_level_label.get_combined_minimum_size().x<=ui.team_level_label.size.x,"Level fits without clipping")
 check(root.get_visible_rect().encloses(ui.hero_dock.get_global_rect()),"Character hub fits the viewport")
 if ui.food_effects.visible:check(ui.food_effects.get_global_rect().position.y>=ui.team_xp_bar.get_global_rect().end.y,"Food status stays below XP")
 if ui.hound_dock.visible:check(ui.hound_dock.get_global_rect().position.y>=ui.team_xp_bar.get_global_rect().end.y,"Pet commands stay below XP")
 if ui.loadout_slots.visible:
  check(ui.hero_dock.get_global_rect().encloses(ui.loadout_slots.get_global_rect()),"Skills blend into the character panel")
  check(ui.loadout_slots.get_global_rect().end.y<=ui.player_health_bar.get_global_rect().position.y,"Skills sit directly above player HP")
  if ui.hound_dock.visible:check(ui.hound_dock.get_global_rect().position.y>=ui.loadout_slots.get_global_rect().end.y,"Pet commands sit below the integrated skill row")
func portrait_board():
 if DisplayServer.get_name()=="headless":return
 var board=Panel.new();board.name="PortraitReviewBoard";board.size=Vector2(940,690);board.position=Vector2(170,55);board.mouse_filter=Control.MOUSE_FILTER_IGNORE
 var style=game.forest_ui.skin.lacquer();style.bg_color=Color("201b17");board.add_theme_stylebox_override("panel",style);var layer=CanvasLayer.new();layer.layer=100;root.add_child(layer);layer.add_child(board)
 var index=0
 for id in game.forest_ui.Roster.CROSSGATE:
  var cell=Vector2(12+(index%4)*230,12+(index/4)*164)
  var head=TextureRect.new();head.texture=game.forest_ui.PaintedHeads.portrait(id,game.settings);head.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;head.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;head.position=cell+Vector2(45,0);head.size=Vector2(136,136);head.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST;board.add_child(head)
  var label=Label.new();label.text=game.forest_ui.Roster.name_for(id);label.position=cell+Vector2(0,138);label.size=Vector2(222,26);label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;label.add_theme_color_override("font_color",Color("edc35c"));board.add_child(label);index+=1
 await capture("all-original-heads");layer.queue_free();await frames()
func run():
 DirAccess.make_dir_recursive_absolute(OUT);root.size=Vector2i(1280,800)
 game=load("res://scenes/forest_shrine.tscn").instantiate();game.settings_path=cfg;root.add_child(game);current_scene=game;await frames()
 game.set_process(false);game.set_physics_process(false);game.player.set_physics_process(false)
 game.army_runtime.set_process(false);game.army_runtime.set_physics_process(false)
 var ui=game.forest_ui;ui.set_process(false)
 var xp=game.model.team_progression;xp.cards_enabled=false
 check(ui.PaintedHeads.routes.size()>=ui.Roster.CROSSGATE.size(),"Every selectable Cross Gate model/skin has a original model-head route")
 var panel_style=ui.hero_dock.get_theme_stylebox("panel")
 check(panel_style is StyleBoxFlat and panel_style.bg_color.r>panel_style.bg_color.b,"HUD panel uses warm charcoal instead of teal")
 check(ui.player_health_bar.get_theme_stylebox("fill").bg_color==Color("62c477"),"Healthy HP uses green")
 check(ui.find_child("CharacterStatsButton",true,false)==null and ui.find_child("PetLoadoutButton",true,false)==null,"Bottom shortcut buttons are removed")
 check(not ui.shrine_health_dock.visible and not ui.shrine_health_bar.is_visible_in_tree(),"Arena has no empty bottom level panel")
 check(ui.team_xp_bar.texture_progress==ui.skin.texture("xp_fill"),"EXP reuses the prepared purple arc texture")
 xp.award_enemy(26);ui.sync();await frames()
 check(is_equal_approx(ui.team_xp_bar.value,2.6/16) and ui.team_level_label.text=="1" and ui.team_level_label.tooltip_text.contains("2.6 / 16 XP"),"Purple meter and tooltip show fractional progress toward 16 XP")
 verify_layout();await capture("preparing")
 game.player.hp=20;ui.sync();check(ui.health.text=="20 / %d"%ceili(game.player.max_hp),"In-bar numbers follow damage");await capture("low-health")
 game.player.hp=game.player.max_hp;ui.sync()
 game.start_wave();game.model.waves.spawn_clock=100000
 xp.reset();xp.award_kills(16);ui.sync();await frames()
 check(ui.team_level_label.text=="2" and ui.team_xp_bar.value==0 and ui.team_level_label.tooltip_text.contains("0 / 32 XP"),"Level-up resets the bar and shows the new 32 XP requirement")
 for id in ui.Roster.CROSSGATE:
  game.player.select_character(id);ui.sync();await frames(1)
  check(ui.team_level_label.text=="2" and ui.team_xp_bar.get_parent()==ui.hero_dock,"Cross Gate fighter %d keeps shared level beside its portrait"%id)
  check(ui.hero_portrait.texture==ui.PaintedHeads.portrait(id,game.settings) and ui.hero_portrait.material==null,"Fighter %d shows the original cropped head without a circular mask"%id)
  check(ui.hero_portrait.texture.get_size()==Vector2(256,256),"Fighter %d uses the bounded HUD import"%id)
  check(ui.hero_name.visible and ui.hero_name.text==ui.Roster.name_for(ui.Roster.gallery_id(id)),"Head keeps the correct gallery identity for fighter %d"%id)
  await capture("fighter-%d"%id)
 await portrait_board()
 game.player.select_character(ui.Roster.KAZI_ID);xp.award_enemy(97);ui.sync();await frames();await capture("combat-level-2")
 key(KEY_I);key(KEY_P,true);await frames();check(not is_instance_valid(game.status_panel) and not is_instance_valid(game.pet_loadout_panel),"Retired I and Shift+P shortcuts do not open extra windows")
 key(KEY_Q);await frames();check(is_instance_valid(game.equipment_hub) and game.equipment_hub.stats.embedded,"Q opens Equipment with the shared Stats view")
 game.equipment_hub.show_page("pets");await frames();check(game.equipment_hub.pet_picker.embedded,"Equipment contains pet selection")
 key(KEY_Q);await frames();check(not is_instance_valid(game.equipment_hub),"Q closes the combined window")
 game.player.position=Vector3(-120,game.model.surface_height(-120,125),125)
 key(KEY_P)
 for i in 90:game.army_runtime.integration_tick(1.0/60);game.army_runtime.flush_presentation()
 ui.sync();await frames();check(ui.hound_dock.visible,"Pet layout is tested with real living companions");verify_layout()
 for food in [3,4,5,6,7,8]:game.exploration_loot.eat(food)
 xp.award_kills(1000000);ui.sync();await frames()
 check(ui.team_level_label.text=="99" and ui.team_level_label.tooltip_text.contains("MAX LEVEL") and ui.team_xp_bar.value==1,"Maximum level retains its number and fills the purple bar")
 await capture("max-level-food-pets")
 for dimensions in [Vector2i(1280,800),Vector2i(960,640)]:
  root.size=dimensions;await frames()
  for factor in [.65,1.0,1.3]:
   game.settings.forest_hud_scale=factor;ui.sync();await frames();verify_layout()
 await capture("small-window")
 var nodes=int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT));var resources=int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT))
 for i in 120:ui.sync()
 check(int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))==nodes and int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT))==resources,"Repeated updates reuse controls and resources")
 xp.reset();ui.sync();check(ui.team_level_label.text=="1" and ui.team_xp_bar.value==0,"Reset restores level one and an empty meter")
 game.sound_library.cancel();game.music.stop();game.queue_free();paused=false;await frames(4)
 DirAccess.remove_absolute(ProjectSettings.globalize_path(cfg))
 print("PORTRAIT_XP_HUD_RESULT checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)
