extends SceneTree
const OUT="res://build/Other Files/Asset Toolkit/Mana and Stats/"
const Icons=preload("res://scripts/forest/forest_hud_icons.gd")
var game
var checks=0
var failures=0
var cfg="user://mana-stats-hud-%d.cfg"%OS.get_process_id()
func _initialize():
 create_timer(180).timeout.connect(func():printerr("Mana/stats HUD timeout");quit(1))
 run.call_deferred()
func check(ok:bool,message:String):
 checks+=1
 if not ok:failures+=1;printerr("FAIL: "+message)
func frames(n:int=3):
 for i in n:await process_frame
func capture(stem:String):
 if DisplayServer.get_name()=="headless":return
 await frames();await RenderingServer.frame_post_draw
 check(root.get_texture().get_image().save_png(OUT+stem+".png")==OK,"Captured "+stem)
func click(control:Control):
 var event=InputEventMouseButton.new();event.device=104;event.button_index=MOUSE_BUTTON_LEFT;event.pressed=true;event.position=control.get_global_rect().get_center()
 root.push_input(event,true);event=event.duplicate();event.pressed=false;root.push_input(event,true);await frames()
func fit():
 var ui=game.forest_ui
 check(ui.player_mana_bar.position.y>=ui.player_health_bar.position.y+ui.player_health_bar.size.y+2,"Mana has a gap below health")
 check(ui.player_mana_bar.size.x==ui.player_health_bar.size.x,"Mana and HP share width")
 check(ui.hero_dock.get_global_rect().encloses(ui.player_mana_bar.get_global_rect()),"Hero dock contains mana")
 check(not ui.player_mana_bar.get_global_rect().intersects(ui.team_level_label.get_global_rect()),"Mana clears level badge")
 if ui.hound_dock.visible:check(not ui.player_mana_bar.get_global_rect().intersects(ui.hound_dock.get_global_rect()),"Mana clears pets")
func mana_checks(p:Hero):
 var spells=p.spell_loadout
 var catalog=spells.Catalog
 for id in catalog.all():
  if catalog.available(catalog.all()[id]):check(catalog.mana_cost(id)>0,"Active skill has a mana cost: "+id)
 var tap=func():
  spells.number_input(6,true)
  spells.number_input(6,false)
 p.mana=7;tap.call()
 check(p.mana==7 and spells.current==null,"Insufficient mana preserves the action and pool")
 p.mana=8;tap.call()
 check(p.mana==0 and spells.current!=null,"Qi starts on exact mana and spends eight once")
 spells.interrupt();tap.call()
 check(p.mana==0 and spells.current==null,"Interrupted Qi keeps its cost")
 p.tick_mana(4)
 check(p.mana==8,"The player regenerates two mana per second")
 p.mana=49;p.tick_mana(1)
 check(p.mana==50,"Regeneration caps at maximum mana")
 p.mana=0;p.active_ability.start_basic_attack(Vector3.FORWARD)
 check(p.mana==0 and p.active_ability.is_attacking(),"A normal attack works with zero mana")
 p.active_ability.cancel(true)
 p.accessory_bonuses.primary="fire";spells.prepare()
 check(spells.accessory_attack() and spells.current!=null and p.mana==0,"A weapon that casts Fire as its basic attack stays free")
 spells.interrupt();p.accessory_bonuses.erase("primary")
 check(spells.equip(p.character_id,"special_6",catalog.KAGEROU),"Equip the sustained mana skill")
 p.mana=11;tap.call()
 check(p.active_ability.kagerou_enabled and p.mana==6,"Kagerou spends five to activate")
 p.tick_mana(1)
 check(p.mana==3,"Kagerou drains five while two mana regenerate")
 p.tick_mana(1)
 check(p.mana==0 and not p.active_ability.kagerou_enabled,"Kagerou switches off at zero mana")
 check(spells.equip(p.character_id,"special_6","kazi/qigong"),"Restore Qi to its fixture slot")
func icon_board():
 if DisplayServer.get_name()=="headless":return
 var layer=CanvasLayer.new();layer.layer=100;root.add_child(layer)
 var board=Panel.new();board.position=Vector2(90,120);board.size=Vector2(1100,560);layer.add_child(board)
 var style=game.forest_ui.skin.lacquer();style.bg_color=Color("181d23");board.add_theme_stylebox_override("panel",style)
 var title=Label.new();title.text="CROSS GATE  /  STAT ICONS";title.position=Vector2(36,20);title.add_theme_font_size_override("font_size",26);board.add_child(title)
 var names=["Health / Vitality","Regeneration","Attack","Magic power","Attack speed","Defense","Damage reduction","Critical chance","Dodge","Counter attack","Mana","Upgrade point"]
 var index=0
 for id in Icons.STATS:
  var cell=Vector2(25+(index%6)*180,85+(index/6)*220)
  var view=TextureRect.new();view.texture=Icons.STATS[id];view.position=cell+Vector2(42,0);view.size=Vector2(96,96);view.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;board.add_child(view)
  var small=TextureRect.new();small.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;small.texture=view.texture;small.position=cell+Vector2(78,112);small.size=Vector2(24,24);board.add_child(small)
  var label=Label.new();label.text=names[index];label.position=cell+Vector2(0,147);label.size=Vector2(180,30);label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;label.add_theme_font_size_override("font_size",17);board.add_child(label);index+=1
 await capture("chosen-icons");layer.queue_free();await frames()
func run():
 DirAccess.make_dir_recursive_absolute(OUT);root.size=Vector2i(1280,800)
 game=load("res://scenes/forest_shrine.tscn").instantiate();game.settings_path=cfg;root.add_child(game);current_scene=game;await frames()
 game.set_process(false);game.set_physics_process(false);game.player.set_physics_process(false)
 game.army_runtime.set_process(false);game.army_runtime.set_physics_process(false)
 var ui=game.forest_ui;ui.set_process(false)
 var p=game.player;var xp=game.model.team_progression;xp.cards_enabled=false
 check(p.mana==50 and p.max_mana==50,"Player starts with 50 mana")
 ui.sync();fit()
 check(ui.player_mana_bar.get_theme_stylebox("fill").bg_color==Color("278fdb"),"Mana is blue")
 await capture("preparing")
 game.start_wave();game.model.waves.spawn_clock=100000;p.hp=p.max_hp*.7;p.mana=42.5;ui.sync();await frames();fit()
 check(ui.player_mana_bar.value==42.5 and ui.mana.text=="43 / 50","Live mana supports partial values")
 await capture("combat-mana")
 for amount in [-10.0,0.0,50.0,200.0]:
  p.mana=amount;ui.sync();check(ui.player_mana_bar.value==clampf(amount,0,50),"Meter clamps boundary %s"%amount)
 p.mana=42.5
 for id in ui.Roster.CROSSGATE:
  p.select_character(id);ui.sync();check(p.mana==42.5 and ui.player_mana_bar.value==42.5 and p.max_hp==200,"Cross Gate fighter %d has 200 base health and keeps current mana"%id)
 p.select_character(ui.Roster.KAZI_ID)
 var spells=p.spell_loadout;var skills=preload("res://scripts/spells/skill_balance.gd")
 var equipped=[spells.Catalog.COMBO,"kazi/fire","kazi/ice","kazi/wind","kazi/moon","kazi/qigong"]
 for i in equipped.size():check(spells.equip(p.character_id,spells.Catalog.SLOTS.keys()[i],equipped[i]),"Equip real skill %s"%equipped[i])
 mana_checks(p)
 var pet_key=ui.Pets.key(0);game.settings.forest_pet_skills[pet_key]=["kazi/fire","kazi/qigong","kazi/ice"]
 xp.award_kills(48);p.refresh_max_health();ui.sync()
 var saved=FileAccess.get_sha256(cfg);var settings=game.settings.duplicate(true)
 game.show_status_panel();await frames();var panel=game.status_panel
 check(panel.buttons.size()==9 and panel.stat_icons.size()==9 and panel.values.size()==11,"All allocations and derived values include Magic defense")
 check(panel.stat_icons.all(func(view):return view.texture!=null and not view.tooltip_text.is_empty()),"Every stat uses an icon with an explanatory tooltip")
 check(panel.stat_icons.all(func(view):return view.size==Vector2(32,32)),"Stat symbols fit their cards instead of keeping source texture dimensions")
 check(panel.buttons.values().all(func(button_):return not button_.accessibility_name.is_empty()),"Icon-based upgrades retain readable accessibility names")
 for label in panel.stats_content.find_children("*","Label",true,false):check(label.text not in xp.STAT_NAMES.values(),"Stats uses symbols instead of stat-name labels")
 await click(panel.buttons.attack)
 check(xp.stat_ranks.attack==1 and xp.stat_points==1 and panel.values[2].text=="x%.2f"%p.damage_multiplier(),"Actual + click spends one point and updates damage")
 await capture("stats")
 await click(panel.find_child("SkillsTab",true,false));check(panel.skills_content.visible and not panel.stats_content.visible and panel.tabs[1].button_pressed,"Skills tab still switches and marks the current page")
 check(panel.skill_ids==equipped and panel.skill_icons.all(func(view):return view.texture!=null),"All explicitly equipped skills keep their original icons")
 await click(panel.skill_buttons[5]);check(skills.level_for(p,"kazi/qigong")==2 and xp.stat_points==0,"A skill + click spends the same remaining point")
 await capture("skills")
 xp.stat_points=1;panel.refresh()
 await click(panel.find_child("PetsTab",true,false));check(panel.pets_content.visible and not panel.skills_content.visible and panel.tabs[2].button_pressed,"Pets tab still switches and marks the current page")
 await click(panel.pet_skill_buttons[0]);check(skills.pet_level_for(xp,pet_key,"kazi/fire")==2 and xp.stat_points==0,"A pet skill + click spends one shared point for the selected pet")
 await capture("pets")
 await click(panel.find_child("StatsTab",true,false))
 root.size=Vector2i(960,640);await frames()
 check(root.get_visible_rect().encloses(panel.panel.get_global_rect()),"Stats fits small windows")
 for button_ in panel.buttons.values():check(panel.panel.get_global_rect().encloses(button_.get_global_rect()),"All + buttons stay inside panel")
 await capture("stats-small")
 game.close_status_panel();await frames()
 for dimensions in [Vector2i(1280,800),Vector2i(960,640)]:
  root.size=dimensions;await frames()
  for scale_ in [.65,1.0,1.3]:game.settings.forest_hud_scale=scale_;ui.sync();await frames();fit()
 game.settings=settings;ui.sync()
 var nodes=int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT));var resources=int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT))
 for i in 120:ui.sync()
 check(int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))==nodes and int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT))==resources,"HUD updates reuse nodes and resources")
 game.show_status_panel();await frames();game.close_status_panel();await frames(6)
 nodes=int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT));resources=int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT))
 for i in 8:game.show_status_panel();await frames();game.close_status_panel();await frames(6)
 check(int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))==nodes and int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT))<=resources,"Repeated panel use retains no nodes or resources")
 check(FileAccess.get_sha256(cfg)==saved,"UI changes leave saved settings untouched")
 game.preview_forest_map(game.active_forest_map(),false);await frames();check(p.mana==50 and p.hp==200 and p.max_hp==200,"New runs restore 200 health and 50 mana")
 root.size=Vector2i(1280,800);await frames();await icon_board()
 game.sound_library.cancel();game.music.stop();game.queue_free();paused=false;await frames(5);DirAccess.remove_absolute(ProjectSettings.globalize_path(cfg))
 print("MANA_STATS_HUD_RESULT checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)
