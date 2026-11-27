extends "res://scripts/recovered_goemon_gameplay_tests.gd"
const Pets=preload("res://scripts/forest/pet_catalog.gd")
const Progression=preload("res://scripts/forest/team_progression.gd")
const Roles=preload("res://scripts/forest/forest_enemy_roles.gd")
const OUT="res://build/Other Files/Asset Toolkit/Pet Progression/"

func arrive():
 for i in 60:
  game.army_runtime.integration_tick(1.0/60)
  if game.army_runtime.pending_hounds.is_empty():break

func unit_checks():
 var p=Progression.new();var key=Pets.key(0)
 check(p.pet_points(key)==0 and p.pet_mana_bonus(key)==0 and p.pet_damage_multiplier(key)==1,"New pets start at base stats without points")
 for level_ in range(2,100):
  var hp=p.pet_growth(key,.08);var damage=p.pet_damage_multiplier(key);var mana=p.pet_mana_bonus(key)
  check(p.award_pet_enemy(key,160*(level_-1))==1 and p.pet_experience[key].level==level_,"Pet reaches level %d"%level_)
  check(p.pet_growth(key,.08)>hp and p.pet_damage_multiplier(key)>damage and p.pet_mana_bonus(key)>mana,"Every level automatically increases HP, damage and MP")
  check(p.pet_points(key)==0 and p.stat_points==0 and p.pet_stat_ranks.is_empty(),"Automatic growth creates no pet or character points")
 check(p.award_pet_enemy(key,10000)==0 and p.pet_experience[key].level==99,"Growth stops at level 99")
 p.pet_stat_ranks[key]={"mana":98}
 check(p.pet_mana_bonus(key)==980,"Previously allocated MP remains within the existing native limit")
 p.pet_stat_ranks.clear()
 for id in ["vitality","mana","damage","attack_speed","speed","dodge_chance","counter_chance","passive","contacts"]:
  check(not p.can_spend_pet_stat(key,id) and not p.spend_pet_stat(key,id),"Manual spending is disabled for "+id)
 check(p.pet_growth(Pets.key(1),.08)==0 and p.pet_mana_bonus(Pets.key(1))==0,"Other pets retain their own base stats")
 p.reset();check(p.pet_stat_ranks.is_empty() and p.pet_experience.is_empty(),"A new run clears pet progression")

 for skin in Pets.COUNT:
  var family=Pets.category(skin);var growth=Progression.new();var pet_key=Pets.key(skin)
  var matches=growth.pet_health_bonus(pet_key)==0 and growth.pet_damage_bonus(pet_key)==0
  var rewarded=0
  for level_ in [2,10,99]:
   var total=80*level_*(level_-1);growth.award_pet_enemy(pet_key,total-rewarded);rewarded=total
   var steps=(level_-1)/(1.0+(level_-1)/20.0)
   var health=150.0*(.16 if family=="Dragon lizards" else .08)*steps
   var damage=50.0*(.20 if family in ["Mantises","Bees"] else .10)*steps
   matches=matches and growth.pet_experience[pet_key].level==level_ and is_equal_approx(growth.pet_health_bonus(pet_key),health) and is_equal_approx(growth.pet_damage_bonus(pet_key),damage) and is_equal_approx(growth.pet_damage_multiplier(pet_key),1+damage/50.0) and is_equal_approx(growth.pet_mana_bonus(pet_key),3.0*steps)
  check(matches,"Family growth preserves level-one stats and applies the correct HP/damage/MP at levels 2/10/99 for pet %d"%skin)

func enemy(at:Vector3,reward:int=160)->int:
 var row=game.model.waves.spawn_enemy(Roles.SLIME,at);row.xp_reward_tenths=reward
 game.army_runtime.import_arrivals()
 return game.army_runtime.handles[row.id]

func capture(stem:String):
 if DisplayServer.get_name()=="headless":return
 await frames(3);RenderingServer.force_draw()
 check(root.get_texture().get_image().save_png(OUT+stem+".png")==OK,"Captured "+stem)

func click(control:Control):
 var event=InputEventMouseButton.new();event.device=104;event.button_index=MOUSE_BUTTON_LEFT;event.pressed=true;event.position=control.get_global_rect().get_center()
 root.push_input(event,true);event=event.duplicate();event.pressed=false;root.push_input(event,true);await frames()

func run():
 create_timer(180).timeout.connect(func():printerr("PET_PROGRESSION_TIMEOUT");quit(1))
 DirAccess.make_dir_recursive_absolute(OUT);root.size=Vector2i(1280,800)
 unit_checks()
 var doc=load("res://scripts/forest/forest_map_document.gd").new();doc.load_wind_meadow()
 await setup_fixture(doc.data)
 game.player.select_character(game.player.RogueRoster.KAZI_ID)
 game.set_process(false);game.army_runtime.set_process(false);game.army_runtime.set_physics_process(false)
 var army=game.army_runtime;var p=game.model.team_progression
 p.cards_enabled=false;game.settings.forest_level_up_cards=false
 game.player.position=Vector3(-150,game.model.surface_height(-150,127),127)
 game.settings.forest_pet_loadout=[Pets.key(0),Pets.key(21),Pets.key(61)]
 game.settings.forest_pet_skills={Pets.key(0):["kazi/fire","",""]}
 army.reconcile_pet_loadout();army.queue_hounds();arrive()
 var pet:int=army.handles[army.HOUND_ID];var helper:int=army.handles[army.HOUND_ID-21]
 var at:Vector3=army.unit_state(pet).position+Vector3.FORWARD*3
 army.apply_hit(pet,{"amount":40.0})
 var foe=enemy(at)
 army.apply_hit(foe,{"amount":1.0,"source_id":army.HOUND_ID})
 army.native.rest_tick(1.0)
 army.apply_hit(foe,{"amount":1.0,"source_id":army.HOUND_ID-21})
 army.native.rest_tick(1.0)
 army.apply_hit(foe,{"amount":100000.0,"source_id":0})
 var row=army.unit_state(pet)
 check(army.pet_stats(0).level==2 and army.pet_stats(21).level==2 and army.pet_stats(61).level==1,"Two assisting pets earn full XP from a character kill; an idle pet earns none")
 check(row.hp==row.max_hp and row.max_hp>Pets.BASE_HEALTH and p.pet_points(Pets.key(0))==0,"Level-up heals the pet to its new maximum without granting points")
 check(army.pet_participants.is_empty(),"A defeated enemy releases participation records")
 var xp:float=p.pet_experience[Pets.key(0)].experience()
 check(not army.apply_hit(foe,{"amount":100000.0,"source_id":0}).accepted and p.pet_experience[Pets.key(0)].experience()==xp,"A stale death cannot award pet XP twice")
 # Taking a hit also counts, even when this pet never hits that enemy.
 army.native.rest_tick(1.0);foe=enemy(at)
 var foe_id:int=army.unit_state(foe).logical_id
 army.apply_hit(helper,{"amount":2.0,"source_id":foe_id})
 army.apply_hit(foe,{"amount":100000.0,"source_id":0})
 check(p.pet_experience[Pets.key(21)].experience()==16 and p.pet_experience[Pets.key(0)].experience()==xp,"A pet that takes a hit participates only in that enemy's fight")
 foe=enemy(at);foe_id=army.unit_state(foe).logical_id
 army.apply_hit(foe,{"amount":1.0,"source_id":army.HOUND_ID})
 army.despawn(foe)
 check(not army.pet_participants.has(foe_id),"Despawning an enemy releases unfinished participation")
 army.record_pet_participation({"amount":1.0,"team":1,"source_id":foe_id,"target_id":army.HOUND_ID})
 check(army.pet_participants.is_empty(),"Late damage from a retired enemy cannot retain orphan fight credit")
 game.show_equipment_hub(true);await frames()
 var hub=game.equipment_hub;hub.select_owner(1)
 check(not hub.stats.point_header.visible and hub.stats.pet_growth_note.visible and hub.stats.find_children("SpendPet*","Button",true,false).is_empty(),"Pet Equipment explains automatic growth and has no point counter or upgrade buttons")
 check(p.stat_points==1,"Pet growth preserves the character's earned point")
 var caster=army.pet_skills.casters[Pets.key(0)]
 check(is_equal_approx(caster.damage_multiplier(),p.pet_damage_multiplier(Pets.key(0))),"Prepared skill casters share automatic damage growth")
 check(not game.spend_pet_stat(Pets.key(0),"damage") and not game.spend_pet_stat(Pets.key(21),"passive"),"Old spending routes cannot change stats or passives")
 var low=army.pet_stats(0)
 p.award_pet_enemy(Pets.key(0),20000)
 army.apply_pet_growth(pet,Pets.key(0),true);hub.refresh();row=army.unit_state(pet)
 var mana_max:float=Pets.BASE_MANA+p.pet_mana_bonus(Pets.key(0))
 check(is_equal_approx(row.max_hp,150*(1+p.pet_growth(Pets.key(0),.08))) and is_equal_approx(row.max_mana,mana_max),"Level growth reaches live native HP and MP maximums")
 check(row.max_hp>low.max_hp and row.max_mana>low.max_mana and army.pet_stats(0).damage>low.damage,"Multiple earned levels automatically improve all three stats")
 check(row.dodge_chance==0 and row.counter_chance==0 and army.pet_stats(0).attack_speed==1 and is_equal_approx(army.pet_stats(0).speed,Roles.stats(19).speed),"Growth preserves reaction chances and movement/attack timing")
 hub.select_owner(0)
 check(hub.stats.point_header.visible and not hub.stats.pet_growth_note.visible and hub.stats.point_label.text==str(p.stat_points),"Character selection restores its point counter")
 hub.select_owner(1)
 var character_points=p.stat_points
 await capture("pet-auto-growth");root.size=Vector2i(960,640);await frames()
 check(root.get_visible_rect().encloses(hub.stats.panel.get_global_rect()),"Automatic pet stats fit the small Equipment view")
 await capture("pet-auto-growth-small");root.size=Vector2i(1280,800)
 game.back_from_equipment()
 army.native.rest_allies()
 check(army.apply_hit(pet,{"amount":40.0,"source_id":army.HOUND_ID}).accepted,"Wound preservation starts with an accepted hit outside recovery")
 row=army.unit_state(pet);var wounds:float=row.max_hp-row.hp
 army.apply_pet_growth(pet,Pets.key(0));army.refresh_kits();row=army.unit_state(pet)
 check(is_equal_approx(row.max_hp-row.hp,wounds) and wounds>0,"Stat/profile refresh keeps wounds; only a level-up fully heals")
 army.native.rest_allies();row=army.unit_state(pet)
 check(is_equal_approx(row.max_mana,mana_max) and row.dodge_chance==0,"Between-wave rest retains automatic MP growth")
 var maximum:float=row.max_hp
 army.refresh_kits();check(is_equal_approx(army.unit_state(pet).max_hp,maximum),"Rest and kit refresh retain automatic HP growth")
 var nodes=int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT));var resources=int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT))
 for i in 100:army.apply_pet_growth(pet,Pets.key(0))
 check(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)==nodes and Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)==resources,"Repeated stat application reuses the native body and prepared resources")
 check(army.native.set_pet_training(pet,1,1,0,false) and not army.native.set_pet_training(pet,NAN,1,0,false) and not army.native.set_pet_training(pet,1,-1,0,false),"Native training validates finite stat ranges")
 army.apply_pet_growth(pet,Pets.key(0))
 army.recall_hounds();army.queue_hounds();arrive()
 row=army.unit_state(army.handles[army.HOUND_ID])
 check(is_equal_approx(row.max_hp,maximum) and row.hp==row.max_hp and is_equal_approx(row.max_mana,mana_max) and p.stat_points==character_points,"Recall and resummon retain grown stats and character points")
 game.settings.forest_pet_loadout=[Pets.key(0),Pets.key(21),Pets.key(41),Pets.key(61),Pets.key(81)]
 army.reconcile_pet_loadout();army.queue_hounds();arrive()
 nodes=int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT));resources=int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT))
 for round_ in 4:
  for skin in [0,21,41,61,81]:
   var before=army.pet_stats(skin)
   check(army.award_pet_kill(army.HOUND_ID-skin,160*before.level),"Family %d earns an automatic level in round %d"%[skin,round_])
   var after=army.pet_stats(skin)
   check(after.level==before.level+1 and after.max_hp>before.max_hp and after.max_mana>before.max_mana and after.damage>before.damage and after.hp==after.max_hp,"All five families receive live automatic HP, MP, damage and healing")
   var steps=(after.level-1)/(1.0+(after.level-1)/20.0)
   var expected_hp=150.0*(1.0+(.16 if skin==41 else .08)*steps)
   var expected_damage=50.0*(1.0+(.20 if skin in [21,61,81] else .10)*steps)
   check(is_equal_approx(after.max_hp,expected_hp) and is_equal_approx(after.damage,expected_damage),"Live family growth matches double 水龍 HP / double 螳螂 and bee damage")
 check(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)==nodes and Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)==resources,"Repeated five-family level-ups reuse prepared nodes and resources")
 check(p.stat_points==character_points and p.pet_stat_ranks.is_empty(),"Simultaneous pet progression leaves character points and allocations alone")
 var retained=p.pet_experience.duplicate()
 game.preview_forest_map(doc.data,false,false,true)
 check(game.model.team_progression==p and p.pet_experience==retained and army.pet_participants.is_empty(),"Retained-run travel keeps levels and clears old fight credit")
 game.queue_free();current_scene=null;paused=false;await frames(4);DirAccess.remove_absolute(ProjectSettings.globalize_path(cfg))
 print("PET_PROGRESSION_RESULT checks=",checks," failures=",failures);quit(1 if failures else 0)
