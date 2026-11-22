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
 check(p.pet_points(key)==0 and not p.spend_pet_stat(key,"damage"),"New pets cannot spend unearned points")
 p.award_pet_enemy(key,5760)
 check(p.pet_experience[key].level==9 and p.pet_points(key)==8 and p.stat_points==0,"Pet XP earns exactly one separate point per level, including overflow")
 for id in p.PET_STATS:check(p.spend_pet_stat(key,id) and p.pet_rank(key,id)==1,"Can upgrade pet "+id)
 check(p.pet_points(key)==1 and not p.spend_pet_stat(key,"contacts") and not p.spend_pet_stat(Pets.key(1),"damage"),"Invalid stats and another pet cannot consume these points")
 check(p.spend_pet_stat(key,"damage") and p.pet_points(key)==0 and not p.spend_pet_stat(key,"damage"),"The last point cannot be spent twice")
 check(is_equal_approx(p.pet_damage_multiplier(key),1+p.pet_growth(key,.1)+.2),"Damage upgrades add base damage alongside natural growth")
 p.reset();check(p.pet_stat_ranks.is_empty() and p.pet_experience.is_empty(),"A new run clears pet XP and allocated stats")

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
 check(row.hp==row.max_hp and row.max_hp>Pets.BASE_HEALTH and p.pet_points(Pets.key(0))==1,"Level-up heals the pet to its new natural maximum and grants a point")
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
 check(hub.stats.point_label.text=="1" and not hub.stats.pet_stat_buttons.damage.disabled,"Q Equipment shows selected pet points and upgrade controls")
 await click(hub.stats.pet_stat_buttons.damage)
 check(p.pet_points(Pets.key(0))==0 and p.pet_rank(Pets.key(0),"damage")==1 and p.stat_points==1,"The UI spends this pet's point without spending character points")
 var caster=army.pet_skills.casters[Pets.key(0)]
 check(is_equal_approx(caster.damage_multiplier(),p.pet_damage_multiplier(Pets.key(0))),"Prepared skill casters share the upgraded damage multiplier")
 check(not game.spend_pet_stat(Pets.key(21),"damage") and not game.spend_pet_stat(Pets.key(0),"contacts"),"Stale wearer and unsupported requests cannot spend points")
 p.award_pet_enemy(Pets.key(0),20000)
 army.apply_pet_growth(pet,Pets.key(0),true);hub.refresh()
 for id in p.PET_STATS:
  check(game.spend_pet_stat(Pets.key(0),id),"Equipment upgrades live "+id)
 hub.refresh();row=army.unit_state(pet)
 check(is_equal_approx(row.max_hp,150*(1+p.pet_growth(Pets.key(0),.08))+30) and row.max_mana==60,"HP and MP upgrades update live native maximums")
 check(is_equal_approx(row.dodge_chance,.01) and is_equal_approx(row.counter_chance,.01),"Dodge and counter upgrades reach native combat")
 check(is_equal_approx(army.pet_stats(0).attack_speed,1.1) and is_equal_approx(army.pet_stats(0).speed,Roles.stats(19).speed*1.05),"Equipment reports the upgraded attack and movement speeds")
 var character_points=p.stat_points
 await capture("pet-upgrades");root.size=Vector2i(960,640);await frames()
 check(root.get_visible_rect().encloses(hub.stats.panel.get_global_rect()),"Pet stats and upgrades fit the small Equipment view")
 await capture("pet-upgrades-small");root.size=Vector2i(1280,800)
 game.back_from_equipment()
 army.native.rest_allies()
 check(army.apply_hit(pet,{"amount":40.0,"source_id":army.HOUND_ID}).accepted,"Wound preservation starts with an accepted hit outside recovery")
 row=army.unit_state(pet);var wounds:float=row.max_hp-row.hp
 army.apply_pet_growth(pet,Pets.key(0));army.refresh_kits();row=army.unit_state(pet)
 check(is_equal_approx(row.max_hp-row.hp,wounds) and wounds>0,"Stat/profile refresh keeps wounds; only a level-up fully heals")
 army.native.rest_allies();row=army.unit_state(pet)
 check(row.max_mana==60 and row.dodge_chance==.01,"Between-wave rest retains trained mana and reactions")
 var maximum:float=row.max_hp
 army.refresh_kits();check(is_equal_approx(army.unit_state(pet).max_hp,maximum),"Rest and kit refresh retain natural and allocated HP bonuses")
 var nodes=int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT));var resources=int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT))
 for i in 100:army.apply_pet_growth(pet,Pets.key(0))
 check(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)==nodes and Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)==resources,"Repeated stat application reuses the native body and prepared resources")
 check(army.native.set_pet_training(pet,1,1,0,false) and not army.native.set_pet_training(pet,NAN,1,0,false) and not army.native.set_pet_training(pet,1,-1,0,false),"Native training validates finite stat ranges")
 army.apply_pet_growth(pet,Pets.key(0))
 army.recall_hounds();army.queue_hounds();arrive()
 row=army.unit_state(army.handles[army.HOUND_ID])
 check(is_equal_approx(row.max_hp,maximum) and row.hp==row.max_hp and row.max_mana==60 and p.stat_points==character_points,"Recall and resummon retain trained stats and character points")
 var retained=p.pet_stat_ranks.duplicate(true)
 game.preview_forest_map(doc.data,false,false,true)
 check(game.model.team_progression==p and p.pet_stat_ranks==retained and army.pet_participants.is_empty(),"Retained-run travel keeps allocations and clears old fight credit")
 game.queue_free();current_scene=null;paused=false;await frames(4);DirAccess.remove_absolute(ProjectSettings.globalize_path(cfg))
 print("PET_PROGRESSION_RESULT checks=",checks," failures=",failures);quit(1 if failures else 0)
