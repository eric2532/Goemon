extends "res://tests/forest-shrine/timed_dodge_test.gd"
const Gear=preload("res://scripts/forest/equipment.gd")
const CLOTHING_OUT="res://build/Other Files/Asset Toolkit/Accessories/Clothing/"

func wear(numbers:Array):
 var slots={}
 for i in numbers.size():slots[Gear.ACCESSORY_SLOTS[i]]="accessory:%d"%numbers[i]
 var loadouts={} if slots.is_empty() else {Gear.character_key(game.player.character_id):slots}
 check(game.save_equipment_loadouts(loadouts,{},{}),"Save clothing accessories %s"%str(numbers))

func picture(stem:String):
 if DisplayServer.get_name()=="headless":return
 game.army_runtime.flush_presentation();game.forest_ui.sync()
 await frames(2);RenderingServer.force_draw()
 check(root.get_texture().get_image().save_png(CLOTHING_OUT+stem+".png")==OK,"Captured "+stem)

func run():
 create_timer(240).timeout.connect(func():printerr("CLOTHING_ACCESSORIES_TIMEOUT");quit(1))
 DirAccess.make_dir_recursive_absolute(CLOTHING_OUT);root.size=Vector2i(1280,800)
 var doc=load("res://scripts/forest/forest_map_document.gd").new();doc.load_wind_meadow();await setup_fixture(doc.data)
 game.set_process(false);game.army_runtime.set_process(false);game.army_runtime.set_physics_process(false)
 game.set_process_input(false);game.set_process_unhandled_input(false)
 game.music.stop();game.settings.forest_pet_loadout=[];game.tuning.invincible=false;game.tuning.enemy_damage=1
 game.model.waves.crossgate_pet_test=true;game.model.waves.patrol_posts.clear();game.model.team_progression.reset()
 game.training_dummy.position=home+Vector3.DOWN*1000
 driver=load("res://tests/forest-shrine/physics_step_driver.gd").new();root.add_child(driver)
 home.y=game.model.surface_height(home.x,home.z)+.05;game.model.update_vision(home)
 game.camera_rig.camera.global_position=home+Vector3(8,4,0);game.camera_rig.camera.look_at(home+Vector3.UP*1.2)
 var p=game.player;var army=game.army_runtime
 game.impact_confirmed.connect(func(_target,_strength,_duration):hits+=1)
 preload("res://scripts/character_projectile_pool.gd").service(game).launched.connect(func(shot):shots.append(shot);shot.set_physics_process(false))
 for id in p.RogueRoster.CROSSGATE:
  if id in [34,36]:game.settings.kaz_skin=preload("res://scripts/kaz_skins.gd").MAZE if id==36 else preload("res://scripts/kaz_skins.gd").DEFAULT
  await settle(id);p.timed_dodge.shadow_counter_enabled=false;wear([21669])
  game.update_character_tuning(id,"accuracy",100)
  key();key(false)
  check(not p.timed_dodge.reacting and not p.model.stat_counter_shadow.visible,"Shadow Vest alone preserves the manual warning requirement for %d"%id)
  var row=spawn();check(await wait_warning(),"Native manual dodge warning for %d"%id)
  var enemy=army.enemy_target(row.id);var hp_before:float=enemy.hp;var anchor:Vector3=p.position
  check(not p.active_ability.counter_after_hit(Vector3.BACK,row.id,true),"Ordinary counters still respect zero Counter Chance for %d"%id)
  key();key(false)
  check(not p.active_ability.shin_counter.is_empty() and not p.active_ability.shin_counter.after_dodge and p.active_ability.shin_counter.target==enemy and p.active_ability.shin_counter.origin.is_equal_approx(anchor) and p.model.stat_counter_shadow.visible,"Manual dodge automatically starts the regular counter at zero Counter Chance for %d"%id)
  var counter:Dictionary=p.active_ability.shin_counter
  var travel:Vector3=p.model.kagerou_step*p.model.KAGEROU_BACK_TICKS
  key();key(false);key(true,true);key(false)
  check(p.active_ability.shin_counter==counter and p.active_ability.shin_counter_pending.is_empty() and p.timed_dodge.step_ticks==0,"Repeated Space and key echoes cannot start extra counters")
  check(p.timed_dodge.counter_source==0 and not p.timed_dodge.counter_origin.is_finite(),"No click-triggered counter is banked for %d"%id)
  if id==p.RogueRoster.KAZI_ID:await picture("21669-manual-shadow")
  await driver.advance(1,func(_dt):advance(10,false))
  if id==p.RogueRoster.KAZI_ID:
   await picture("21669-counterattack")
  await driver.advance(1,func(_dt):advance(25,false))
  check(Vector3(p.position.x-anchor.x,0,p.position.z-anchor.z).distance_to(travel)<.1 and not p.timed_dodge.reacting,"Automatic retaliation preserves the full manual dodge for %d"%id)
  finish_counter()
  check(enemy.hp<hp_before and not p.model.stat_counter_shadow.visible and p.active_ability.shin_counter.is_empty(),"Without any attack click the shadow deals damage and retires for %d: damage %.1f"%[id,hp_before-enemy.hp])
  p.active_ability.cancel(true);p.active_ability.clear_shin_counter();p.timed_dodge.reset();p.model.clear_kagerou_dodge();p.invuln=0;p.impact_pause=0
  wear([21669,21678]);p.hp=p.max_hp
  var health:float=p.hp
  p.take_hit_from(100,Vector3.BACK,false,row.id)
  check(p.effective_dodge_chance()==100 and p.hp==health and p.model.kagerou_tick>=0 and not p.model.stat_counter_shadow.visible and not p.timed_dodge.counter_origin.is_finite() and p.active_ability.shin_counter.is_empty(),"21678 guarantees a stat dodge while 21669 grants no automatic shadow at zero Counter Chance for %d"%id)
  p.model.clear_kagerou_dodge();p.invuln=0;p.hp=p.max_hp
  p.take_hit_from(100,Vector3.BACK,false,row.id,false,false,false,false,true)
  check(is_equal_approx(p.hp,p.max_hp-50) and p.extra_defense()==100,"21678 gives 100 real physical defense for %d"%id)
  p.invuln=0;p.hp=p.max_hp
  p.take_hit_from(100,Vector3.BACK,false,row.id,false,false,true,false,true)
  check(is_equal_approx(p.hp,p.max_hp-100) and p.extra_defense(true)==0,"Physical clothing defense leaves magic defense unchanged for %d"%id)
  wear([])
  check(p.effective_dodge_chance()==0 and p.extra_defense()==0 and not p.model.stat_counter_shadow.visible,"Unequip removes both bonuses for %d"%id)

 game.settings.kaz_skin=preload("res://scripts/kaz_skins.gd").DEFAULT
 await settle(p.RogueRoster.KAZI_ID);p.timed_dodge.shadow_counter_enabled=false;wear([21669,21678,21884])
 game.load_settings();Gear.apply(p)
 check(p.accessory_bonuses.get("manual_dodge_shadow")==1 and p.effective_dodge_chance()==100 and p.extra_defense()==100,"Both clothing accessories survive save/reload")
 for serial in [21669,21678]:
  var texture:Texture2D=Gear.ITEMS["accessory:%d"%serial].icon
  var original=Image.load_from_file(texture.resource_path);original.convert(Image.FORMAT_RGBA8)
  var imported=texture.get_image();imported.convert(Image.FORMAT_RGBA8)
  check(original.get_data()==imported.get_data(),"Imported clothing %d preserves original pixels"%serial)
 var owner=Gear.character_key(p.character_id)
 check(not game.save_equipment_loadouts({owner:{"accessory:1":"accessory:21678","accessory:2":"accessory:21678"}},{},{}),"Duplicate evasion clothing cannot stack")
 check(not game.save_equipment_loadouts({"pet:invalid":{"accessory:1":"accessory:21669"}},{},{}),"Invalid wearers cannot equip clothing")
 for gate in ["paused","transitioning"]:
  game.set(gate,true);key();key(false);game.set(gate,false)
  check(not p.timed_dodge.counter_origin.is_finite() and not p.model.stat_counter_shadow.visible,"%s prevents manual shadow creation"%gate)
 var jump=InputEventKey.new();jump.physical_keycode=KEY_SPACE;jump.shift_pressed=true;jump.pressed=true;root.push_input(jump,true)
 jump.pressed=false;root.push_input(jump,true)
 check(p.jump_buffer>0 and not p.timed_dodge.counter_origin.is_finite(),"Shift+Space remains a jump without a counter shadow")
 p.jump_buffer=0
 key();key(false)
 check(not p.model.stat_counter_shadow.visible and not p.timed_dodge.counter_origin.is_finite() and p.active_ability.shin_counter.is_empty(),"An empty free step has no counter target, matching regular counter rules")
 await driver.advance(1,func(_dt):advance(50,false))
 check(not p.model.stat_counter_shadow.visible and p.active_ability.shin_counter.is_empty(),"An empty free-step shadow fades without banking an attack")
 var target=spawn();var enemy=army.enemy_target(target.id);var health:float=enemy.hp
 finish_counter()
 check(enemy.hp==health,"An enemy arriving later cannot trigger an old empty dodge")
 p.position=home;p.velocity=Vector3.ZERO;p.timed_dodge.cooldown=0
 key();key(false)
 check(not p.active_ability.shin_counter.is_empty() and p.active_ability.shin_counter.target==enemy,"A free-step shadow automatically selects a nearby visible enemy")
 await driver.advance(1,func(_dt):advance(20,false));finish_counter()
 check(enemy.hp<health and not p.model.stat_counter_shadow.visible,"A free-step shadow deals counter damage without a click")
 p.position=home;p.velocity=Vector3.ZERO;p.timed_dodge.cooldown=0
 p.active_ability.counter_after_hit(Vector3.BACK,target.id,true,false,Vector3.INF,true)
 var active:Dictionary=p.active_ability.shin_counter
 key();key(false)
 check(p.active_ability.shin_counter==active and not p.active_ability.shin_counter_pending.is_empty() and p.active_ability.shin_counter_pending.origin.is_equal_approx(home),"A manual dodge queues behind an existing counter without restarting its swing")
 finish_counter()
 check(p.active_ability.shin_counter.is_empty() and p.active_ability.shin_counter_pending.is_empty(),"Both automatic counters finish through the existing bounded queue")
 var node_count=0;var resource_count=0.0
 for cycle in 35:
  p.position=home;p.velocity=Vector3.ZERO;p.impact_pause=0;p.timed_dodge.cooldown=0
  if cycle==5:node_count=get_node_count();resource_count=Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)
  key();key(false);await driver.advance(1,func(_dt):advance(20,false))
  finish_counter()
  check(not p.timed_dodge.counter_origin.is_finite() and p.active_ability.shin_counter.is_empty(),"Repeated manual dodge automatically completes its counter")
 await create_timer(.6).timeout;await frames(2)
 check(get_node_count()<=node_count and Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)<=resource_count,"Thirty warmed dodge/counter cycles reuse existing nodes and resources")
 p.timed_dodge.cooldown=0;key();key(false);wear([21678])
 check(not p.timed_dodge.counter_origin.is_finite() and not p.model.stat_counter_shadow.visible and p.active_ability.shin_counter.is_empty() and p.active_ability.shin_counter_pending.is_empty(),"Removing 21669 clears its automatic counter and shadow")
 p.apply_food_buff("defense")
 check(p.extra_defense()==120 and p.extra_defense(true)==20,"Clothing stacks with food defense without changing magic defense")
 p.clear_food_buffs()
 game.show_equipment_hub(true);await frames(3)
 var hub=game.equipment_hub;hub.show_page("accessories")
 for serial in [21669,21678]:
  hub.selected_slot="accessory:1" if serial==21669 else "accessory:2";hub.selected_item="accessory:%d"%serial;hub.equip_selected()
  check(hub.collection.has(hub.selected_item) and hub.accessory_buttons[hub.selected_slot].get_node("GearIcon").texture==Gear.ITEMS[hub.selected_item].icon,"Equipment shows and equips clothing %d"%serial)
 await picture("clothing-equipped")
 game.back_from_equipment();game.show_status_panel();await frames(2);game.status_panel.refresh()
 check(game.status_panel.values[5].text=="100" and game.status_panel.values[8].text=="100.0%","Stats displays +100 defense and 100% dodge")
 await picture("21678-stats")
 game.close_status_panel()
 var report={"checks":checks,"failures":failures,"roster":p.RogueRoster.CROSSGATE.size(),"rendered":DisplayServer.get_name()!="headless"}
 FileAccess.open(CLOTHING_OUT+DisplayServer.get_name()+".json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
 print("CLOTHING_ACCESSORIES_RESULT ",JSON.stringify(report))
 game.queue_free();current_scene=null;await frames(3)
 DirAccess.remove_absolute(ProjectSettings.globalize_path(cfg));quit(1 if failures else 0)
