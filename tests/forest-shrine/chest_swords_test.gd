extends "res://tests/forest-shrine/accessory_effects_test.gd"
const SWORD_OUT="res://build/Other Files/Asset Toolkit/Chest Swords/"
var swing_starts=0
var sword_step_ms:Array=[]

func _initialize():
 create_timer(240).timeout.connect(func():printerr("CHEST_SWORDS_TIMEOUT");quit(1))
 run.call_deferred()

func equip_sword(id:String,second:String=""):
 var owner=Gear.character_key(game.player.character_id)
 var slots={"1":id,"active_weapon":"1"}
 if not second.is_empty():slots["2"]=second
 var loadouts=game.settings.gear_loadouts.duplicate(true);loadouts[owner]=slots
 check(game.save_equipment_loadouts(loadouts,{},{}),"Equip "+id)

func sword_swing():
 var p=game.player
 p.active_ability.start_attack()
 var serial=p.crossgate_attack_serial
 swing_starts=1
 for tick in 360:
  var started=Time.get_ticks_usec()
  p.active_ability.tick(DT)
  if serial!=p.crossgate_attack_serial:swing_starts+=1;serial=p.crossgate_attack_serial
  sword_step_ms.append((Time.get_ticks_usec()-started)/1000.0)
  if not p.active_ability.is_attacking():break
 check(not p.active_ability.is_attacking(),"Normal attack and follow-up finish")

func sword_picture(stem:String):
 if DisplayServer.get_name()=="headless":return
 await frames(3);await RenderingServer.frame_post_draw
 check(root.get_texture().get_image().save_png(SWORD_OUT+stem+".png")==OK,"Capture "+stem)

func run():
 DirAccess.make_dir_recursive_absolute(SWORD_OUT);root.size=Vector2i(1280,800)
 var doc=load("res://scripts/forest/forest_map_document.gd").new();doc.load_wind_meadow()
 await setup_fixture(doc.data)
 for node in [game,game.player,game.camera_rig,game.army_runtime]:node.set_process(false);node.set_physics_process(false)
 game.settings.forest_pet_loadout=[];game.settings.forest_level_up_cards=false
 game.model.waves.patrol_posts.clear();game.model.waves.crossgate_pet_test=true
 game.training_dummy.home=Vector3(0,-1000,0);game.training_dummy.position=game.training_dummy.home
 var p=game.player;var loot=game.exploration_loot;var pool=Pool.service(game)
 loot.set_process(false);game.paused=false;paused=false
 p.select_character(37);home=Vector3(40,0,60);home.y=game.model.surface_height(home.x,home.z)+.05
 game.model.update_vision(home)
 game.camera_rig.camera.global_position=home+Vector3(6,8,15);game.camera_rig.camera.look_at(home+Vector3(0,2,-3))
 pool.launched.connect(func(shot):shots.append(shot);shot.set_physics_process(false))
 game.settings.chest_swords=[]
 check(not Gear.can_equip(Gear.character_key(37),"weapon:SW016",game.settings),"Undiscovered sword cannot be equipped")
 check(not game.save_equipment_loadouts({Gear.character_key(37):{"1":"weapon:SW016"}},{},{}),"Save rejects an unowned sword")
 check(Gear.sanitized_swords(["bad","weapon:SW016","weapon:SW016",1])==["weapon:SW016"] and Gear.sanitized_swords("bad").is_empty(),"Saved collection validates IDs and removes duplicates")
 loot.sword_bag.clear();loot.rng.seed=812
 for cycle in 3:
  var found=[]
  for i in 6:found.append(loot.draw_sword())
  found.sort();var expected=Gear.CHEST_SWORDS.duplicate();expected.sort()
  check(found==expected,"Each complete shuffle bag draws every sword exactly once")
 loot.sword_bag.clear()
 for i in 6:
  reset_case();loot.clear();p.hp=1
  check(loot.spawn_chest(i%3,home,"sword-%d"%i),"Spawn existing chest variant")
  var before=game.settings.chest_swords.size()
  check(loot.open_nearest() and game.settings.chest_swords.size()==before+1,"Chest grants and saves a new sword")
  check(p.hp==1 and p.food_buff_stacks.values().all(func(value):return value==0),"Sword replaces food without healing or buffing")
  check(loot.opened_chests.has("sword-%d"%i) and loot.nearest()==-1,"Chest consumed once after saved reward")
 check(game.settings.chest_swords==Gear.CHEST_SWORDS,"All six swords are collected")
 var collected=game.settings.chest_swords.duplicate();game.load_settings()
 check(game.settings.chest_swords==collected,"Collection survives settings reload")
 reset_case();loot.clear();game.settings.chest_swords=[]
 loot.sword_bag=["weapon:SW082"];loot.spawn_chest(0,home,"save-retry")
 var path=game.settings_path;game.settings_path="user://missing-chest-swords-directory/save.cfg"
 loot.open_nearest()
 check(game.settings.chest_swords.is_empty() and loot.slots[0].active and loot.slots[0].sword=="weapon:SW082" and not loot.opened_chests.has("save-retry"),"Failed save keeps the same reward, chest and prior inventory")
 game.settings_path=path;loot.open_nearest()
 check(game.settings.chest_swords==["weapon:SW082"] and loot.opened_chests.has("save-retry"),"Retry saves the same reward and consumes chest")
 game.settings.chest_swords=collected;game.save_settings()
 var stats=[["SW016",3,55,10],["SW020",6,150,20],["SW042",2,45,30],["SW052",6,300,40],["SW082",10,400,0],["SW101",10,300,0]]
 var baseline=p.effective_dodge_chance()
 var critical_baseline=p.combat_tuning("critical_chance")
 for row in stats:
  equip_sword("weapon:"+row[0]);reset_case()
  check(Gear.ITEMS["weapon:"+row[0]].level==row[1] and p.accessory_bonuses.attack==float(row[2]),"Exact item level and ATK: "+row[0])
  check(is_equal_approx(p.effective_dodge_chance(),minf(100,baseline+row[3])),"Exact additive dodge bonus: "+row[0])
  check(p.combat_tuning("critical_chance")==critical_baseline and not p.accessory_bonuses.has("critical_chance"),"Sword grants no critical bonus: "+row[0])
  check(Skills.basic_damage(p.model.normal_attack_pattern(),p)==50+row[2],"Normal damage adds ATK once: "+row[0])
 game.settings.weapon_slot_unlocks[Gear.character_key(37)]=2
 equip_sword("weapon:SW016","weapon:SW052")
 check(p.accessory_bonuses.attack==55 and p.accessory_bonuses.dodge_chance==10,"Inactive carried sword adds no stats")
 check(Gear.cycle(p) and p.accessory_bonuses.attack==300 and p.accessory_bonuses.dodge_chance==40,"Z switches same-family sword stats")
 game.update_character_tuning(37,"dodge_chance",90)
 check(p.effective_dodge_chance()==100,"Sword dodge chance caps at 100%")
 p.active_ability.kagerou_enabled=false;p.model.clear_kagerou_dodge();p.invuln=0;game.tuning.invincible=false
 var hp=p.hp
 p.take_hit(10,Vector3.FORWARD)
 check(p.hp==hp and p.model.kagerou_tick==0,"Sword dodge avoids an actual incoming hit at 100%")
 p.model.clear_kagerou_dodge()
 game.update_character_tuning(37,"dodge_chance",baseline)
 outfit([])
 check(p.effective_dodge_chance()==baseline and p.combat_tuning("critical_chance")==critical_baseline,"Unequipping restores dodge and preserves critical chance")
 for character in Gear.Roster.CROSSGATE:
  if not Gear.allowed(character,game.settings).has("sword"):continue
  p.select_character(character);equip_sword("weapon:SW101");reset_case()
  var enemy=spawn(Vector3(0,0,-2));var before=enemy.hp
  sword_swing()
  check(swing_starts==2,"One click gives two native normal swings: %d"%character)
  check(enemy.hp<before and shots.is_empty(),"Double sword uses normal melee without spell effects")
  p.active_ability.start_attack();p.active_ability.cancel(true)
  var serial=p.crossgate_attack_serial
  for tick in 180:p.active_ability.tick(DT)
  check(p.crossgate_attack_serial==serial,"Cancelled windup cannot leave a delayed second swing")
 p.select_character(37);equip_sword("weapon:SW082");reset_case()
 game.update_character_tuning(37,"critical_chance",0)
 Skills.set_level(p,"kazi/fire",30)
 var enemy=spawn(Vector3(0,0,-2));var neighbor=spawn(Vector3(10,0,-2))
 var before=enemy.hp;var other_hp=neighbor.hp;var mana=p.mana
 sword_swing()
 check(swing_starts==1 and enemy.hp<before and not shots.is_empty(),"Fire sword keeps its normal swing and physical contact")
 check(p.spell_loadout.current==null and p.mana==mana and Skills.level_for(p,"kazi/fire")==30,"Proc does not cast, spend mana or change learned Fire")
 check(shots.all(func(shot):return shot.attack_ticket.skill_level==7 and shot.attack_ticket.magical and not shot.attack_ticket.has("sword_fire_ticket")),"Every proc snapshots level 7 with no recursive proc")
 var fire_damage=0.0
 for shot in shots:fire_damage+=shot.damage*p.attack_chain.damage_for(shot.attack_ticket)
 before=enemy.hp
 resolve_shots()
 check(is_equal_approx(before-enemy.hp,fire_damage) and neighbor.hp==other_hp,"Pooled level 7 Fire adds exact damage only to struck targets (actual %.3f expected %.3f neighbor %.3f)"%[before-enemy.hp,fire_damage,other_hp-neighbor.hp])
 Skills.set_level(p,"kazi/fire",1)
 var misses=pool.misses;var created=pool.created
 for cycle in 12:
  reset_case();spawn(Vector3(0,0,-2));sword_swing();resolve_shots()
 check(pool.misses==misses and pool.created==created,"Repeated Fire hits reuse prepared projectiles without growth")
 reset_case();sword_swing()
 check(shots.is_empty(),"A missed swing creates no Fire")
 reset_case();enemy=spawn(Vector3(0,0,-2))
 p.active_ability.start_attack();p.active_ability.cancel(true)
 for tick in 180:p.active_ability.tick(DT)
 check(shots.is_empty(),"Interrupted Fire sword windup creates no effect")
 equip_sword("weapon:SW052")
 game.show_equipment_hub(true);await frames(3)
 var hub=game.equipment_hub
 check(hub.stats.overview_values[8].text=="%.0f%%"%p.effective_dodge_chance() and p.accessory_bonuses.dodge_chance==40,"Equipment Stats displays active sword dodge")
 check(Gear.CHEST_SWORDS.all(func(id):return id in hub.available_items()),"Equipment collection lists all six discovered sword icons")
 hub.selected_item="weapon:SW052";hub.inspect_control(hub.inventory[hub.collection.find("weapon:SW052")])
 check(hub.detail.text.contains("Dodge chance +40") and not hub.detail.text.contains("Critical"),"Sword description displays dodge instead of critical chance")
 await sword_picture("equipment-swords")
 game.back_from_equipment();game.paused=false;paused=false
 equip_sword("weapon:SW082")
 reset_case();enemy=spawn(Vector3(0,0,-2));p.active_ability.start_attack()
 for tick in 120:
  p.active_ability.tick(DT)
  if not shots.is_empty():break
 if not shots.is_empty():
  var shot=shots[0]
  shot._physics_process(.35)
  await sword_picture("normal-swing-fire")
 var rendered_frames=[]
 for code in ["SW101","SW082"]:
  equip_sword("weapon:"+code);reset_case();enemy=spawn(Vector3(0,0,-2))
  p.active_ability.primary_tab_target=weakref(enemy)
  var event=InputEventAction.new();event.action="light_attack";event.pressed=true
  var serial=p.crossgate_attack_serial
  p._unhandled_input(event);event.pressed=false;p._input(event)
  for tick in 120:
   var started=Time.get_ticks_usec()
   p._physics_process(DT)
   for shot in shots:
    if is_instance_valid(shot) and shot.pool_live:shot._physics_process(DT)
   if DisplayServer.get_name()!="headless":
    await physics_frame
    rendered_frames.append((Time.get_ticks_usec()-started)/1000.0)
    if tick==20:await sword_picture("click-"+code.to_lower())
  check(p.crossgate_attack_serial-serial==(2 if code=="SW101" else 1),"Pressed and released LMB performs the requested normal attacks: "+code)
  check(p.model.current_clip.begins_with("0:") or p.model.current_clip.begins_with("5:"),"LMB returns through normal sword animation rather than a casting pose")
 equip_sword("weapon:SW082");reset_case();enemy=spawn(Vector3(0,0,-2))
 var copies=preload("res://scripts/warcraft_mirrors.gd").new(p,0)
 for i in 5:check(copies.reinforce(37,home),"Fire sword ally uses native lifecycle")
 check(copies.bodies.all(func(body):return body.accessory_bonuses.get("attack",0)==400 and body.accessory_bonuses.get("sword_fire",0)==7),"Five native allies inherit active sword stats and prepared Fire")
 var warmed_created=pool.created;var warmed_misses=pool.misses
 for cycle in 3:
  shots.clear()
  for body in copies.bodies:
   body.position=home;body.ai_aim=enemy.global_position;body.ai_target=enemy
   body.attack_chain.reset();body.active_ability.cancel(true);body.active_ability.start_attack()
  var before_hp=enemy.hp
  for tick in 180:
   for body in copies.bodies:body.active_ability.tick(DT)
   resolve_shots(1)
  check(enemy.hp<before_hp and shots.size()>=5 and shots.all(func(shot):return not shot.pool_live),"Simultaneous native sword contacts deliver and retire all Fire effects")
 check(pool.created==warmed_created and pool.misses==warmed_misses,"Repeated simultaneous Fire reuses warmed ally pools")
 copies.dispose();await frames(3)
 var report={"checks":checks,"failures":failures,"created_projectiles":pool.created,"pool_misses":pool.misses,"attack_step_max_ms":sword_step_ms.max()}
 if not rendered_frames.is_empty():
  rendered_frames.sort();report.rendered_p95_ms=rendered_frames[floori(rendered_frames.size()*.95)];report.rendered_max_ms=rendered_frames.max()
 var file=FileAccess.open(SWORD_OUT+"results.json",FileAccess.WRITE);file.store_string(JSON.stringify(report,"  "));file.close()
 print("CHEST_SWORDS_RESULT ",JSON.stringify(report))
 game.music.stop();game.queue_free();paused=false;await frames(4)
 DirAccess.remove_absolute(cfg)
 quit(1 if failures else 0)
