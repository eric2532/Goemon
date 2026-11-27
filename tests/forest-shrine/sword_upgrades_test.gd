extends "res://tests/forest-shrine/chest_swords_test.gd"
const UPGRADE_OUT="res://build/Other Files/Asset Toolkit/Chest Swords/Upgrades/"

func _initialize():
 create_timer(240).timeout.connect(func():printerr("SWORD_UPGRADES_TIMEOUT");quit(1))
 run.call_deferred()

func duplicate_sword(id:String,key:String=""):
 var loot=game.exploration_loot
 loot.clear();loot.spawn_chest(0,home,key,true);loot.slots[0].bonus=""
 loot.slots[0].sword=id
 check(loot.open_nearest(),"Open duplicate "+id)

func run():
 DirAccess.make_dir_recursive_absolute(UPGRADE_OUT);root.size=Vector2i(1280,800)
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
 game.settings.chest_swords=[];game.settings.sword_upgrades={}
 reset_case();duplicate_sword("weapon:SW052","first-sword")
 check(game.settings.chest_swords==["weapon:SW052"] and game.settings.sword_upgrades.is_empty(),"First discovery preserves its base stats without an upgrade")
 check(Gear.sanitized_sword_upgrades({"weapon:SW052":2,"weapon:SW016":3,"bad":4,"weapon:SW082":-1,"weapon:SW101":1.5},game.settings.chest_swords)=={"weapon:SW052":2},"Saved ranks validate ownership, IDs and positive integer values")
 check(Gear.sanitized_sword_upgrades([],game.settings.chest_swords).is_empty(),"Malformed rank table is rejected")
 game.settings.chest_swords=Gear.CHEST_SWORDS.duplicate()
 for id in Gear.CHEST_SWORDS:
  equip_sword(id);reset_case()
  var base:Dictionary=Gear.ITEMS[id];var original=base.duplicate(true)
  for rank in [1,2]:
   duplicate_sword(id,"%s-%d"%[id,rank])
   var item=Gear.item_data(id,game.settings)
   var expected=roundf(float(base.effects.attack)*(1+.1*rank))
   check(game.settings.sword_upgrades[id]==rank and item.effects.attack==expected,"Each duplicate adds 10% of original ATK with whole-number rounding")
   check(p.accessory_bonuses.attack==expected and Skills.basic_damage(p.model.normal_attack_pattern(),p)==50+expected,"Equipped sword applies upgraded physical damage immediately")
   check(item.name.ends_with("+%d"%rank) and item.description.contains("ATK +%d"%roundi(expected)) and loot.food_text.text.contains("Upgraded"),"Equipment data and chest receipt show rank and updated ATK")
   check(item.level==base.level and item.effects.get("dodge_chance",0)==base.effects.get("dodge_chance",0) and not item.effects.has("critical_chance") and item.effects.get("sword_fire",0)==base.effects.get("sword_fire",0) and item.effects.get("sword_repeat",0)==base.effects.get("sword_repeat",0),"Item level, dodge chance and special effect remain unchanged")
   check(not loot.open_nearest() and game.settings.sword_upgrades[id]==rank,"A consumed chest cannot upgrade a second time")
  check(Gear.ITEMS[id]==original,"Upgrading does not mutate the shared base item")
 var saved=game.settings.sword_upgrades.duplicate();game.load_settings();Gear.apply(p)
 check(game.settings.sword_upgrades==saved and game.settings.chest_swords==Gear.CHEST_SWORDS,"Ranks and discoveries survive save and reload")
 equip_sword("weapon:SW052");reset_case()
 var before=p.accessory_bonuses.attack
 loot.clear();loot.spawn_chest(0,home,"upgrade-retry",true);loot.slots[0].sword="weapon:SW052";loot.slots[0].bonus=""
 var path=game.settings_path;game.settings_path="user://missing-sword-upgrade-directory/save.cfg"
 loot.open_nearest();loot.open_nearest()
 check(game.settings.sword_upgrades==saved and p.accessory_bonuses.attack==before and loot.slots[0].active and not loot.opened_chests.has("upgrade-retry"),"Repeated failed saves retain prior ranks/stats and the same unopened chest")
 game.settings_path=path;loot.open_nearest()
 check(game.settings.sword_upgrades["weapon:SW052"]==3 and p.accessory_bonuses.attack==390 and loot.opened_chests.has("upgrade-retry"),"Successful retry adds exactly one upgrade")
 game.settings.weapon_slot_unlocks[Gear.character_key(37)]=2
 equip_sword("weapon:SW016","weapon:SW052");reset_case()
 duplicate_sword("weapon:SW052")
 check(p.accessory_bonuses.attack==66,"Upgrading an inactive sword does not add its ATK to the active sword")
 check(Gear.cycle(p) and p.accessory_bonuses.attack==420,"Z switches to the upgraded carried sword")
 game.load_settings();Gear.apply(p)
 check(p.accessory_bonuses.attack==420,"Active upgraded sword survives reload")
 equip_sword("weapon:SW101");reset_case();spawn(Vector3(0,0,-2));sword_swing()
 check(swing_starts==2 and p.accessory_bonuses.attack==360,"Upgraded SW101 retains two normal attacks")
 equip_sword("weapon:SW082");reset_case();spawn(Vector3(0,0,-2));sword_swing()
 check(p.accessory_bonuses.attack==480 and not shots.is_empty() and shots.all(func(shot):return shot.attack_ticket.skill_level==7),"Upgraded SW082 raises physical ATK while retaining level 7 Fire")
 resolve_shots()
 reset_case();equip_sword("weapon:SW052")
 check(p.spell_loadout.equip(37,"special_5","blademaster/mirror-image"),"Equip existing native copy skill")
 var copies=p.spell_loadout.instances["37:blademaster/mirror-image"].controller.mirrors
 var bodies=copies.bodies.duplicate()
 check(not bodies.is_empty() and bodies.all(func(body):return body.accessory_bonuses.attack==420 and body.accessory_bonuses.dodge_chance==40 and not body.accessory_bonuses.has("critical_chance")),"Prepared native copies inherit upgraded ATK and dodge without critical chance")
 duplicate_sword("weapon:SW052")
 check(copies.bodies==bodies and bodies.all(func(body):return body.accessory_bonuses.attack==450),"A duplicate refreshes existing copy bonuses without rebuilding the bodies")
 var created=pool.created
 for i in 6:duplicate_sword("weapon:SW052")
 check(pool.created==created and copies.bodies==bodies,"Repeated upgrades reuse prepared bodies and projectile resources")
 game.show_equipment_hub(true);await frames(3)
 var hub=game.equipment_hub;var item=hub.item_data("weapon:SW052")
 check(item.name.ends_with("+11") and item.description.contains("ATK +630") and hub.stats.attack_damage.text==str(roundi((50+630)*p.damage_multiplier()*p.attack_chain.damage_multiplier())),"Equipment and live stats display the final upgraded ATK")
 hub.inspect_control(hub.inventory[hub.collection.find("weapon:SW052")])
 if DisplayServer.get_name()!="headless":
  await frames(3);await RenderingServer.frame_post_draw
  check(root.get_texture().get_image().save_png(UPGRADE_OUT+"equipment-upgraded-sword.png")==OK,"Capture upgraded sword in Equipment")
 var report={"checks":checks,"failures":failures,"pool_misses":pool.misses}
 var mode="headless" if DisplayServer.get_name()=="headless" else "desktop"
 var file=FileAccess.open(UPGRADE_OUT+"results-"+mode+".json",FileAccess.WRITE);file.store_string(JSON.stringify(report,"  "));file.close()
 print("SWORD_UPGRADES_RESULT ",JSON.stringify(report))
 game.music.stop();game.queue_free();paused=false;await frames(4)
 DirAccess.remove_absolute(cfg)
 quit(1 if failures else 0)
