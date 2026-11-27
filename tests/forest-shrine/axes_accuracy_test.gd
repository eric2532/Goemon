extends "res://tests/forest-shrine/chest_swords_test.gd"
const AXE_OUT="res://build/Other Files/Asset Toolkit/Axes and Accuracy/"

func _initialize():
 create_timer(300).timeout.connect(func():printerr("AXES_ACCURACY_TIMEOUT");quit(1))
 run.call_deferred()

func axe_picture(stem:String):
 game.army_runtime.flush_presentation()
 if stem in ["axe-sure-strike","axe-normal-click","axe-miss"]:
  game.camera_rig.camera.top_level=true
  game.camera_rig.camera.global_position=home+Vector3(6,10,15)
  game.camera_rig.camera.look_at(home+Vector3(0,2,-2))
  game.crowd.present_army(game.army_runtime.render_snapshot(),[])
  var fx=game.crowd.army.presentation
  for effect in fx.effects:
   if effect.kind=="shin_sure_strike":effect.age=5*fx.SURE_STRIKE_FRAME_TIME
  fx.draw_effects()
 if DisplayServer.get_name()=="headless":return
 await frames(3);RenderingServer.force_draw(false)
 check(root.get_texture().get_image().save_png(AXE_OUT+stem+".png")==OK,"Capture "+stem)

func run():
 DirAccess.make_dir_recursive_absolute(AXE_OUT);root.size=Vector2i(1280,800);root.set_flag(Window.FLAG_NO_FOCUS,true)
 var doc=load("res://scripts/forest/forest_map_document.gd").new();doc.load_wind_meadow()
 await setup_fixture(doc.data)
 for node in [game,game.player,game.camera_rig,game.army_runtime]:node.set_process(false);node.set_physics_process(false)
 game.settings.forest_pet_loadout=[];game.settings.forest_level_up_cards=false
 game.model.waves.patrol_posts.clear();game.model.waves.crossgate_pet_test=true
 game.training_dummy.home=Vector3(0,-1000,0);game.training_dummy.position=game.training_dummy.home
 game.exploration_loot.set_process(false);game.paused=false;paused=false
 var p=game.player;var loot=game.exploration_loot;var army=game.army_runtime
 p.select_character(37);home=Vector3(40,0,60);home.y=game.model.surface_height(home.x,home.z)+.05
 game.model.update_vision(home)
 game.camera_rig.camera.global_position=home+Vector3(6,8,15);game.camera_rig.camera.look_at(home+Vector3(0,2,-3))
 army.record_events=true
 game.settings.chest_swords=[]
 check(not Gear.can_equip(Gear.character_key(37),"weapon:AX018",game.settings),"Undiscovered axe is locked")
 check(not game.save_equipment_loadouts({Gear.character_key(37):{"1":"weapon:AX018"}},{},{}),"Unowned axe cannot be saved as equipment")
 loot.sword_bag.clear();loot.rng.seed=981
 for cycle in 3:
  var found=[]
  for i in Gear.CHEST_WEAPONS.size():found.append(loot.draw_sword())
  found.sort();var expected=Gear.CHEST_WEAPONS.duplicate();expected.sort()
  check(found==expected,"Nine-item bag includes each sword and axe exactly once")
 for id in Gear.CHEST_AXES:
  reset_case();loot.clear();p.hp=1
  loot.sword_bag=[id];check(loot.spawn_chest(0,home,id,true),"Spawn axe chest");loot.slots[0].reward="weapon";loot.slots[0].bonus=""
  check(loot.open_nearest() and id in game.settings.chest_swords and p.hp==1,"Chest saves axe without healing")
 game.load_settings()
 check(game.settings.chest_swords==Gear.CHEST_AXES,"Axe ownership survives reload")
 # Duplicate upgrades use the existing shared collection and rollback contract.
 reset_case();loot.clear();loot.sword_bag=["weapon:AX018"];loot.spawn_chest(0,home,"upgrade",true);loot.slots[0].reward="weapon";loot.slots[0].bonus=""
 var path=game.settings_path;game.settings_path="user://missing-axe-folder/save.cfg";loot.open_nearest()
 check(game.settings.sword_upgrades.is_empty() and loot.slots[0].active,"Failed axe upgrade save rolls back and preserves chest")
 game.settings_path=path;loot.open_nearest()
 check(game.settings.sword_upgrades.get("weapon:AX018")==1 and Gear.item_data("weapon:AX018",game.settings).effects.attack==165,"Duplicate axe adds 10% original ATK")
 game.settings.sword_upgrades={};game.save_settings()
 var base_crit=p.combat_tuning("critical_chance")
 var rows=[["AX018",3,150,30],["AX013",4,300,30],["AX024",8,500,0]]
 for row in rows:
  equip_sword("weapon:"+row[0]);reset_case()
  check(Gear.ITEMS["weapon:"+row[0]].level==row[1] and p.accessory_bonuses.attack==row[2],"Exact axe level and ATK "+row[0])
  check(p.combat_tuning("critical_chance")==minf(100,base_crit+row[3]),"Exact additive axe critical bonus "+row[0])
  check(p.combat_tuning("accuracy")==-10,"Every selected axe subtracts 10 Accuracy")
  var enemy=spawn(Vector3(0,0,-2))
  check(army.unit_state(enemy.handle).evasion_chance==5,"Enemy has a native 5% dodge stat")
  if row[0]!="AX024":
   var misses=0;var ticket=p.attack_chain.make_ticket("kazi_sword");ticket.critical_chance=0
   for i in 100:
    if not enemy.take_hit(1,Vector3.FORWARD,false,ticket):misses+=1
   check(misses==15,"Axe accuracy penalty gives exactly 15 misses per 100-marble bag")
 game.settings.weapon_slot_unlocks[Gear.character_key(37)]=2
 equip_sword("weapon:AX018","weapon:AX024")
 check(p.accessory_bonuses.attack==150 and p.accessory_bonuses.critical_chance==30 and not p.accessory_bonuses.has("axe_sure_strike"),"Inactive carried axe adds no ATK, critical chance or on-hit effect")
 check(Gear.cycle(p) and p.accessory_bonuses.attack==500 and p.combat_tuning("critical_chance")==base_crit and p.combat_tuning("accuracy")==-10,"Z switches axe stats and applies Accuracy penalty once")
 var enemy_balance=preload("res://scripts/forest/enemy_balance.gd")
 check(enemy_balance.sanitized({"20":{"dodge_chance":125}},[20])["20"].dodge_chance==100 and enemy_balance.sanitized({"20":{"dodge_chance":NAN}},[20]).is_empty(),"Enemy Dodge tuning clamps valid values and rejects nonfinite values")
 outfit([],"axe");check(p.combat_tuning("accuracy")==-10,"Generic axe also has the penalty")
 outfit([],"sword");check(p.combat_tuning("accuracy")==0,"Sword removes the axe penalty")
 equip_sword("weapon:AX024");reset_case()
 var progression=game.model.team_progression;progression.stat_points=15
 for i in 15:check(progression.spend_stat("accuracy"),"Spend one stat point on Accuracy")
 check(p.combat_tuning("accuracy")==5 and progression.stat_points==0,"Accuracy upgrades offset axe penalty and enemy dodge")
 check(not progression.spend_stat("accuracy"),"No free Accuracy without stat points")
 game.update_character_tuning(37,"critical_chance",0)
 var enemy=spawn(Vector3(0,0,-2));var before=enemy.hp;var mana=p.mana
 p.active_ability.start_attack()
 var normal=p.active_ability.ticket.duplicate()
 check(normal.axe_sure_ticket.skill_level==4 and normal.axe_sure_ticket.skill_id==Skills.Catalog.SURE_STRIKE,"AX024 snapshots level 4 乾坤")
 check(not normal.axe_sure_ticket.has("axe_sure_ticket") and normal.axe_sure_ticket.action=="axe_sure_strike","Extra strike cannot trigger itself")
 var expected=float(normal.normal_attack_damage)*p.damage_multiplier()*p.attack_chain.damage_for(normal)+float(normal.axe_sure_damage)*p.attack_chain.damage_for(normal.axe_sure_ticket)
 army.event_log.clear()
 enemy.take_hit(float(normal.normal_attack_damage)*p.damage_multiplier(),Vector3.FORWARD,false,normal)
 check(is_equal_approx(before-enemy.hp,expected),"Connected normal hit adds exact level 4 乾坤 damage (%.3f / %.3f)"%[before-enemy.hp,expected])
 check(p.mana==mana and p.spell_loadout.current==null,"On-hit 乾坤 costs no mana and starts no casting controller")
 check(army.event_log.filter(func(event):return event.kind=="damage").size()==2,"One connected contact delivers normal damage plus one extra strike")
 before=enemy.hp
 var tuned=normal.duplicate(true);tuned.axe_sure_ticket.skill_damage=2.0
 var tuned_expected=float(tuned.normal_attack_damage)*p.damage_multiplier()*p.attack_chain.damage_for(tuned)+float(tuned.axe_sure_damage)*p.attack_chain.damage_for(tuned.axe_sure_ticket)
 enemy.take_hit(float(tuned.normal_attack_damage)*p.damage_multiplier(),Vector3.FORWARD,false,tuned)
 check(is_equal_approx(before-enemy.hp,tuned_expected),"Extra 乾坤 applies skill damage tuning exactly once")
 await axe_picture("axe-sure-strike")
 p.active_ability.cancel(true)
 reset_case();enemy=spawn(Vector3(0,0,-2));game.update_character_tuning(37,"accuracy",0);progression.stat_ranks.accuracy=0
 before=enemy.hp
 var misses=0
 for i in 100:
  if not enemy.take_hit(float(normal.normal_attack_damage)*p.damage_multiplier(),Vector3.FORWARD,false,normal):misses+=1
 check(misses==0,"Snapshotted Accuracy stays stable after live stat changes")
 # A guaranteed miss must not trigger the bonus strike.
 army.flush_presentation();game.crowd.army.presentation.clear()
 normal.accuracy=-100;before=enemy.hp;army.event_log.clear()
 check(not enemy.take_hit(100,Vector3.FORWARD,false,normal) and enemy.hp==before and not army.event_log.any(func(event):return event.kind=="damage"),"Missed normal hit triggers no 乾坤")
 army.flush_presentation();game.crowd.army.presentation.tick(DT)
 check(game.crowd.army.presentation.labels.any(func(label):return label.visible and label.text=="MISS"),"A native physical miss displays pooled MISS feedback")
 await axe_picture("axe-miss")
 game.update_character_tuning(37,"accuracy",100)
 for character in Gear.Roster.CROSSGATE:
  if not Gear.allowed(character,game.settings).has("axe"):continue
  p.select_character(character);game.update_character_tuning(character,"accuracy",100);game.update_character_tuning(character,"critical_chance",0)
  equip_sword("weapon:AX024");reset_case();enemy=spawn(Vector3(0,0,-2));before=enemy.hp
  sword_swing()
  check(enemy.hp<before and swing_starts==1,"Axe uses original normal animation and extra damage: %d"%character)
  p.active_ability.start_attack();p.active_ability.cancel(true);before=enemy.hp
  for tick in 120:p.active_ability.tick(DT)
  check(enemy.hp==before,"Cancelled axe windup leaves no delayed strike")
 p.select_character(37);game.update_character_tuning(37,"accuracy",100);equip_sword("weapon:AX024");reset_case()
 enemy=spawn(Vector3(0,0,-2));before=enemy.hp
 p.active_ability.primary_tab_target=weakref(enemy)
 var click_event=InputEventAction.new();click_event.action="light_attack";click_event.pressed=true
 var serial=p.crossgate_attack_serial
 print("AXE_CLICK_BEFORE ",p.active_ability.mode," target=",p.active_ability.primary_click_target()," grounded=",p.is_on_floor()," paused=",game.paused)
 p._unhandled_input(click_event);click_event.pressed=false;p._input(click_event)
 var rendered_ms=[];var click_captured=false
 for tick in 120:
  var started=Time.get_ticks_usec();p._physics_process(DT)
  army.flush_presentation();game.crowd.army.presentation.tick(DT)
  if DisplayServer.get_name()!="headless":
   await physics_frame;rendered_ms.append((Time.get_ticks_usec()-started)/1000.0)
   if not click_captured and game.crowd.army.presentation.effects.any(func(effect):return effect.kind=="shin_sure_strike"):
    await axe_picture("axe-normal-click");click_captured=true
 check(p.crossgate_attack_serial-serial==1 and enemy.hp<before,"Actual LMB press/release performs one axe swing with its extra hit (swings=%d damage=%.3f mode=%s)"%[p.crossgate_attack_serial-serial,before-enemy.hp,p.active_ability.mode])
 game.update_character_tuning(37,"accuracy",0);reset_case()
 game.show_equipment_hub(true);await frames(3)
 var hub=game.equipment_hub
 check(hub.stats.overview_values[11].text=="-10","Equipment Stats displays negative axe Accuracy")
 check(hub.stats.buttons.has("accuracy") and hub.stats.buttons.accuracy.accessibility_name=="Upgrade Accuracy","Accuracy is an accessible stat upgrade")
 check(Gear.CHEST_AXES.all(func(id):return id in hub.available_items()),"Equipment lists all discovered axes")
 hub.selected_item="weapon:AX024";hub.inspect_control(hub.inventory[hub.collection.find("weapon:AX024")])
 check(hub.detail.text.contains("500") and hub.detail.text.contains("level 4") and hub.detail.text.contains("−10"),"Axe details expose stats and on-hit behavior")
 await axe_picture("axe-equipment-stats")
 hub.stats.show_equipment_tab(false);await axe_picture("accuracy-upgrades")
 game.back_from_equipment();game.paused=false;paused=false
 # Repeated copies retain the shared native lifecycle and cannot leak per-contact effects.
 game.update_character_tuning(37,"accuracy",100);reset_case();enemy=spawn(Vector3(0,0,-2))
 var copies=preload("res://scripts/warcraft_mirrors.gd").new(p,0)
 for i in 5:check(copies.reinforce(37,home),"Axe ally uses native lifecycle")
 check(copies.bodies.all(func(body):return body.accessory_bonuses.get("axe_sure_strike")==4 and body.combat_tuning("accuracy")==90),"Native copies inherit axe bonus and Accuracy penalty")
 var warm_nodes=0;var warm_resources=0
 for cycle in 4:
  var hp=enemy.hp
  for body in copies.bodies:
   body.position=home;body.ai_aim=enemy.global_position;body.ai_target=enemy;body.attack_chain.reset();body.active_ability.cancel(true);body.active_ability.start_attack()
  for tick in 180:
   for body in copies.bodies:body.active_ability.tick(DT)
   army.flush_presentation();game.crowd.army.presentation.tick(DT)
  check(enemy.hp<hp,"Repeated simultaneous axe strikes deliver damage")
  if cycle==0:
   warm_nodes=int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT));warm_resources=int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT))
  else:
   check(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)==warm_nodes and Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)==warm_resources,"Warm repeated axe effects retain node and resource counts")
 copies.dispose();await frames(3)
 var report={"checks":checks,"failures":failures,"attack_step_max_ms":sword_step_ms.max()}
 if not rendered_ms.is_empty():
  rendered_ms.sort();report.rendered_p95_ms=rendered_ms[floori(rendered_ms.size()*.95)];report.rendered_max_ms=rendered_ms.max()
 report.warm_nodes=warm_nodes;report.warm_resources=warm_resources
 var file=FileAccess.open(AXE_OUT+"results.json",FileAccess.WRITE);file.store_string(JSON.stringify(report,"  "));file.close()
 print("AXES_ACCURACY_RESULT ",JSON.stringify(report))
 game.music.stop();game.queue_free();paused=false;await frames(4);DirAccess.remove_absolute(cfg)
 quit(1 if failures else 0)
