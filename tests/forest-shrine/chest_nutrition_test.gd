extends "res://scripts/recovered_goemon_gameplay_tests.gd"
const Nutrition=preload("res://scripts/forest/chest_food.gd")
const Progression=preload("res://scripts/forest/team_progression.gd")
const Loot=preload("res://scripts/forest/exploration_loot.gd")
const Pets=preload("res://scripts/forest/pet_catalog.gd")
const OUT="res://build/Other Files/Asset Toolkit/Chest Nutrition/"
var captures=false
var serial=0

func _initialize():
 create_timer(180,true,false,true).timeout.connect(func():printerr("CHEST_NUTRITION_TIMEOUT");quit(1))
 run.call_deferred()

func unit_checks():
 var p=Progression.new();p.cards_enabled=false
 var saved=Nutrition.sanitized({"stats":{"vitality":2,"attack":1,"garbage":7,"dodge_chance":1000},"levels":3,"pets":{Pets.key(0):{"damage":2,"levels":1},"bad":{"mana":99}}})
 check(saved.stats.dodge_chance==100 and not saved.stats.has("garbage") and saved.pets.size()==1,"Saved food validates IDs, pet identities and caps")
 check(Nutrition.sanitized("bad").levels==0 and Nutrition.count(NAN)==0 and Nutrition.count("2")==0 and Nutrition.count(-2)==0,"Malformed and nonfinite saves cannot grant food growth")
 p.award_enemy(25);p.apply_food_progress(saved)
 check(p.level==4 and p.stat_points==3 and p.experience()==2.5 and p.stat_ranks.vitality==0 and p.stat_rank("vitality")==2,"Whole food levels preserve XP and grant normal character points; stats require no spending")
 check(p.stat_health_bonus()==260 and p.stat_regeneration()==2 and is_equal_approx(p.stat_damage_multiplier(),1.24),"Permanent ranks enter the existing HP, regeneration and attack formulas once")
 check(p.pet_experience[Pets.key(0)].level==2 and p.pet_rank(Pets.key(0),"damage")==2 and p.pet_stat_ranks.is_empty(),"Pet food reuses individual growth without restoring manual pet allocation")
 p.apply_food_progress(saved)
 check(p.level==4 and p.stat_points==3 and p.pet_experience[Pets.key(0)].level==2,"Repeated saved-food application never duplicates levels")
 p.reset()
 check(p.level==1 and p.stat_rank("vitality")==0 and p.pet_experience.is_empty() and p.food_levels==0 and p.pet_food_levels.is_empty(),"A fresh run clears food stats and character/pet levels")
 p.award_kills(1000000);Progression.grant_food_levels(p,3)
 check(p.level==99 and p.stat_points==98,"Level food respects the existing level and point caps")

func chest(id:String):
 var loot=game.exploration_loot;loot.clear();serial+=1
 check(loot.spawn_chest(serial%3,game.player.position,"nutrition-%d"%serial),"Spawn chest for "+id)
 loot.slots[0].reward=id
 var event=InputEventKey.new();event.physical_keycode=KEY_F;event.pressed=true
 game._input(event)
 check(loot.slots[0].active and loot.slots[0].get("flying",false),"F reveals food before consuming: "+id)
 check(not loot.open_nearest(),"Airborne chest food cannot be opened twice")
 loot._process(Loot.CONSUME_TIME)
 check(not loot.slots[0].active and loot.opened_chests.has("nutrition-%d"%serial),"F consumes saved reward exactly once: "+id)
 check(loot.food_text.text.contains("Rest of run"),"Reward receipt explains run lifetime: "+id)

func picture(stem:String):
 if DisplayServer.get_name()=="headless":return
 await frames(3);await RenderingServer.frame_post_draw
 check(root.get_texture().get_image().save_png(OUT+stem+".png")==OK,"Capture "+stem)

func arrive():
 for i in 60:
  game.army_runtime.integration_tick(1.0/60)
  if game.army_runtime.pending_hounds.is_empty():break

func run():
 DirAccess.make_dir_recursive_absolute(OUT);root.size=Vector2i(1280,800)
 unit_checks()
 var doc=load("res://scripts/forest/forest_map_document.gd").new();doc.load_wind_meadow()
 cfg="/tmp/crossgate-chest-glide-%d.cfg"%OS.get_process_id()
 await setup_fixture(doc.data)
 game.set_process(false);game.army_runtime.set_process(false);game.army_runtime.set_physics_process(false)
 var loot=game.exploration_loot;loot.set_process(false)
 var army=game.army_runtime;var p=game.model.team_progression
 p.cards_enabled=false;game.settings.forest_level_up_cards=false
 game.player.select_character(37);game.player.position=Vector3(-150,game.model.surface_height(-150,127),127)
 game.player.refresh_max_health();game.player.hp=game.player.max_hp
 game.camera_rig.camera.global_position=game.player.position+Vector3(6,8,15);game.camera_rig.camera.look_at(game.player.position+Vector3.UP*2)
 game.settings.forest_pet_loadout=[Pets.key(0),Pets.key(21),Pets.key(41),Pets.key(61)]
 army.reconcile_pet_loadout();army.queue_hounds();arrive()
 loot.reward_bag.clear();loot.rng.seed=622
 for cycle in 3:
  var counts={}
  for i in Nutrition.ITEMS.size():
   var id=loot.draw_reward();counts[id]=counts.get(id,0)+1
  check(counts.size()==Nutrition.ITEMS.size() and Nutrition.ITEMS.keys().all(func(id):return counts.get(id,0)==1),"Regular chest bag contains every eligible food once")
 var baseline_hp:float=game.player.max_hp
 var baseline_damage:float=game.player.damage_multiplier()
 var baseline_magic:float=game.player.magic_damage_multiplier()
 var baseline_speed:float=game.player.base_attack_speed_multiplier()
 for id in Nutrition.ITEMS:
  chest(id)
  check(loot.food_icon.texture==Nutrition.ICONS[id],"Receipt shows original food art: "+id)
 check(is_equal_approx(game.player.max_hp,baseline_hp+180) and p.stat_regeneration()==1,"Saved vitality and four gained levels reach the live player")
 check(is_equal_approx(game.player.damage_multiplier(),baseline_damage*1.27) and is_equal_approx(game.player.magic_damage_multiplier(),baseline_magic*1.27),"Physical and magic food use their matching live damage paths")
 check(is_equal_approx(game.player.base_attack_speed_multiplier(),baseline_speed*1.1) and p.stat_defense()==18 and p.stat_magic_defense()==18,"Speed and both defenses receive permanent ranks plus normal level growth")
 for stat in ["critical_chance","dodge_chance","counter_chance","accuracy"]:
  check(p.stat_chance_bonus(stat)==1,"Chance/accuracy food reaches its existing stat owner: "+stat)
 for key in game.settings.forest_pet_loadout:
  var stats=army.pet_stats(Pets.skin(key))
  check(stats.level==2 and is_equal_approx(stats.max_hp,150+p.pet_health_bonus(key)) and stats.max_mana>60 and stats.damage>55,"Party pet receives saved HP, MP, attack and level: "+key)
  var handle:int=army.handles.get(army.HOUND_ID-Pets.skin(key),0)
  if handle!=0:
   var live=army.unit_state(handle)
   check(is_equal_approx(live.max_hp,stats.max_hp) and is_equal_approx(live.max_mana,stats.max_mana),"Food updates the existing native pet body")
 var latest=game.voices.filter(func(voice):return voice.get_meta("kind","")=="pickup")
 var latest_chest=latest[0]
 for voice in latest:
  if voice.get_meta("order",0)>latest_chest.get_meta("order",0):latest_chest=voice
 check(latest_chest.stream==Loot.FOOD_SOUND,"Chest food finishes with the prepared eating sound")
 loot.clear();loot.spawn_food(0,game.player.position);loot._process(.1);loot._process(Loot.CONSUME_TIME)
 latest=game.voices.filter(func(voice):return voice.get_meta("kind","")=="pickup")
 var newest=latest[0]
 for voice in latest:
  if voice.get_meta("order",0)>newest.get_meta("order",0):newest=voice
 check(newest.stream==Loot.FOOD_SOUND,"Actual food pickup uses cgsys03")
 # Run food does not depend on writing preferences.
 loot.clear();loot.spawn_chest(0,game.player.position,"failed-food");loot.slots[0].reward="power-steak"
 var saved_before=game.settings.chest_nutrition.duplicate(true)
 var path=game.settings_path;game.settings_path="user://missing-nutrition-folder/save.cfg"
 loot.open_nearest();loot._process(Loot.CONSUME_TIME)
 check(not loot.slots[0].active and loot.opened_chests.has("failed-food") and game.settings.chest_nutrition==saved_before and p.food_ranks.attack==2,"Run food applies once without changing saved nutrition, even when preferences cannot be written")
 game.settings_path=path
 army.recall_pet(0);var before_pet:float=army.pet_stats(0).max_hp
 chest("pet-stew")
 check(not army.handles.has(army.HOUND_ID) and is_equal_approx(army.pet_stats(0).max_hp,before_pet+30),"Selected recalled pets receive food without being summoned")
 army.queue_hounds();arrive()
 check(is_equal_approx(army.unit_state(army.handles[army.HOUND_ID]).max_hp,before_pet+30),"Resummoning restores native food growth exactly once")
 var saved=Nutrition.sanitized({"stats":p.food_ranks,"levels":p.food_levels,"pets":p.pet_food_ranks});var points=p.stat_points
 game.settings.chest_nutrition={"stats":{"attack":99},"levels":98,"pets":{Pets.key(0):{"levels":98,"damage":99}}}
 check(game.save_settings()==OK,"Preserve a legacy nutrition save for restart coverage")
 game.load_settings()
 check(p.food_ranks==saved.stats and p.pet_food_ranks==saved.pets and p.stat_points==points,"Settings reload keeps current run food and ignores legacy saved bonuses")
 loot.clear();loot.spawn_chest(1,game.player.position,"nutrition-boss",true);loot.slots[0].bonus="";loot.slots[0].reward="weapon";loot.sword_bag=["weapon:SW016"]
 loot.open_nearest();check("weapon:SW016" in game.settings.chest_swords,"Weapon rewards retain the same persistent collection route")
 var cap=p.level;p.level=99
 check(not Nutrition.eligible(game,"growth-rice") and not Nutrition.eligible(game,"royal-feast"),"Max-level characters cannot waste a level meal")
 p.level=cap
 var party=game.settings.forest_pet_loadout;game.settings.forest_pet_loadout=[]
 check(not Nutrition.eligible(game,"pet-stew") and not Nutrition.eligible(game,"pet-feast"),"No-party bags exclude pet food")
 game.settings.forest_pet_loadout=party
 # If party eligibility changes in flight, restore the unopened chest for retry.
 loot.clear();loot.spawn_chest(0,game.player.position,"party-changed");loot.slots[0].reward="pet-stew"
 var original:Vector3=loot.slots[0].pos
 loot.open_nearest();loot._process(.2)
 game.settings.forest_pet_loadout=[];loot._process(Loot.CONSUME_TIME)
 check(loot.slots[0].active and not loot.slots[0].get("flying",false) and loot.slots[0].pos==original and not loot.opened_chests.has("party-changed"),"Changed party restores the same chest without consuming an ineligible meal")
 game.settings.forest_pet_loadout=party
 loot.open_nearest();loot._process(Loot.CONSUME_TIME)
 check(not loot.slots[0].active and loot.opened_chests.has("party-changed"),"Restored party can finish the original chest food once")
 # Twenty warm saved rewards must reuse presentation, resources and the native owner.
 chest("power-steak");await frames(3)
 var nodes=Performance.get_monitor(Performance.OBJECT_NODE_COUNT);var resources=Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)
 var samples=[]
 for cycle in 20:
  var start=Time.get_ticks_usec();chest("power-steak");chest("pet-stew")
  samples.append((Time.get_ticks_usec()-start)/1000.0)
 check(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)==nodes and Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)==resources,"Repeated player/party food uses prepared nodes, resources and native growth")
 game.forest_ui.message_left=0
 game.show_equipment_hub(true);await frames()
 await picture("character-stats");game.equipment_hub.select_owner(1);await picture("pet-stats")
 game.back_from_equipment();game.paused=false;paused=false
 chest("royal-feast");await picture("royal-feast-receipt")
 root.size=Vector2i(960,640);chest("pet-feast");await picture("pet-feast-receipt-small")
 check(root.get_visible_rect().encloses(loot.food_text.get_global_rect()),"Long permanent food receipt fits the small viewport")
 var before_travel=game.model.team_progression
 game.preview_forest_map(doc.data,false,false,true)
 check(game.model.team_progression==before_travel,"Travel retains food and existing run progression")
 game.preview_forest_map(doc.data,false)
 p=game.model.team_progression
 check(p.level==1 and p.total_kills==0 and p.stat_points==0 and p.food_ranks.is_empty() and p.pet_food_ranks.is_empty() and p.pet_experience.is_empty(),"Fresh runs reset XP, level, points and all character/pet food bonuses despite legacy saves")
 check(is_equal_approx(game.player.max_hp,baseline_hp) and is_equal_approx(game.player.damage_multiplier(),baseline_damage),"Fresh run restores live character health and damage baselines")
 for key in game.settings.forest_pet_loadout:
  check(army.pet_stats(Pets.skin(key)).level==1,"Fresh run restores pet level one: "+key)
 check(Nutrition.ITEMS["sage-jelly"].name=="Sage soup" and Nutrition.ITEMS["ward-jelly"].name=="Ward soup","Saved food IDs retain effects under the new soup names")
 check(Nutrition.ITEMS["pet-melon"].name=="Pet mana broth" and Nutrition.ICONS["pet-melon"].resource_path.ends_with("pet-mana-broth.png"),"Pet mana meal keeps its effect without sharing the enemy-invitation icon")
 check(Nutrition.ICONS.values().all(func(icon):return not icon.resource_path.ends_with("jelly.png")),"No active chest food uses reserved jelly artwork")
 var manifest=JSON.parse_string(FileAccess.get_file_as_string("res://assets/items/crossgate/provenance.json"))
 for id in Nutrition.ICONS:
  var hash=HashingContext.new();hash.start(HashingContext.HASH_SHA256);hash.update(Nutrition.ICONS[id].get_image().get_data())
  check(hash.finish().hex_encode()==manifest[Nutrition.ICONS[id].resource_path.get_file().get_basename()].rgba_sha256,"Imported food pixels match preserved source: "+id)
 samples.sort()
 print("CHEST_NUTRITION_RESULT checks=",checks," failures=",failures," paired_reward_p95_ms=",samples[18]," max_ms=",samples[19])
 game.music.stop();game.queue_free();current_scene=null;paused=false;await frames(5)
 game=load("res://scenes/forest_shrine.tscn").instantiate();game.settings_path=cfg;root.add_child(game);current_scene=game;await frames(3)
 p=game.model.team_progression
 check(p.level==1 and p.food_ranks.is_empty() and p.pet_food_ranks.is_empty() and p.pet_experience.is_empty(),"Restarted scene starts fresh instead of restoring legacy food or levels")
 check("weapon:SW016" in game.settings.chest_swords and game.settings.chest_nutrition.levels==98,"Restart preserves weapon collection and archived nutrition data")
 print("CHEST_NUTRITION_RESTART_RESULT checks=",checks," failures=",failures)
 game.music.stop();game.queue_free();current_scene=null;paused=false;await frames(5)
 DirAccess.remove_absolute(ProjectSettings.globalize_path(cfg));quit(1 if failures else 0)
