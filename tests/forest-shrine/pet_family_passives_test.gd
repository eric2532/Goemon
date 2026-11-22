extends "res://tests/forest-shrine/pet_progression_test.gd"
const EVIDENCE="res://build/Other Files/Asset Toolkit/Pet Family Passives/"

func unit_checks():
 var state=Progression.new();var dragon=Pets.key(41);var mantis=Pets.key(21)
 check(range(Pets.COUNT).filter(func(i):return Pets.passive(i).get("stat")=="regeneration")==range(41,61),"All twenty 水龍 family variants have regeneration")
 check(range(Pets.COUNT).filter(func(i):return Pets.passive(i).get("stat")=="critical_chance")==range(21,41),"All twenty 螳螂 family variants have critical chance")
 check(Pets.passive(-1).is_empty() and Pets.passive(Pets.COUNT).is_empty(),"Invalid appearances have no passive")
 check(not state.spend_pet_stat(dragon,"passive"),"A new pet cannot buy an unearned passive rank")
 state.award_pet_enemy(dragon,160)
 check(state.pet_passive_level(dragon)==1 and state.pet_points(dragon)==1,"Pet leveling earns a point without automatically buying a passive")
 check(state.spend_pet_stat(dragon,"passive") and state.pet_passive_level(dragon)==2 and state.pet_points(dragon)==0,"One pet point buys one passive rank")
 check(not state.spend_pet_stat(dragon,"passive") and state.pet_passive_level(Pets.key(42))==1 and state.stat_points==0,"Exhausted points, other pets and character points remain independent")
 check(state.party_passive_bonus([dragon,Pets.key(58)],"regeneration")==15,"Different dragon variants stack their own passive ranks")
 state.award_pet_enemy(mantis,20000)
 for i in 6:check(state.spend_pet_stat(mantis,"passive"),"Mantis can train toward guaranteed crit")
 var points=state.pet_points(mantis)
 check(state.pet_passive_level(mantis)==7 and state.party_passive_bonus([mantis],"critical_chance")==100 and not state.spend_pet_stat(mantis,"passive") and state.pet_points(mantis)==points,"Mantis stops training at its own 100% cap without wasting points")
 for skin in [0,61]:
  state.award_pet_enemy(Pets.key(skin),160)
  check(not state.spend_pet_stat(Pets.key(skin),"passive"),"Hounds and fixed Bee Mirage cannot train these family passives")
 state.reset()
 check(state.pet_stat_ranks.is_empty() and state.pet_passive_level(dragon)==1,"New runs reset passive ranks with existing pet progression")

func capture(stem:String):
 if DisplayServer.get_name()=="headless":return
 await frames(3);RenderingServer.force_draw()
 check(root.get_texture().get_image().save_png(EVIDENCE+stem+".png")==OK,"Captured "+stem)

func run():
 create_timer(180).timeout.connect(func():printerr("PET_FAMILY_PASSIVES_TIMEOUT");quit(1))
 DirAccess.make_dir_recursive_absolute(EVIDENCE);root.size=Vector2i(1280,800)
 unit_checks()
 var doc=load("res://scripts/forest/forest_map_document.gd").new();doc.load_wind_meadow()
 await setup_fixture(doc.data)
 var player=game.player;player.select_character(player.RogueRoster.KAZI_ID)
 game.set_process(false);game.army_runtime.set_process(false);game.army_runtime.set_physics_process(false)
 var army=game.army_runtime;var state=game.model.team_progression
 state.cards_enabled=false;game.settings.forest_level_up_cards=false
 player.position=Vector3(-150,game.model.surface_height(-150,127),127)
 game.settings.forest_pet_loadout=[]
 var base_crit=player.combat_tuning("critical_chance");var base_dodge=player.effective_dodge_chance()
 game.settings.forest_pet_loadout=[Pets.key(21),Pets.key(36),Pets.key(41),Pets.key(58),Pets.key(61)]
 army.reconcile_pet_loadout();army.queue_hounds();arrive()
 check(player.health_regeneration()==10 and player.combat_tuning("critical_chance")==base_crit+30 and player.effective_dodge_chance()==base_dodge+10,"Two dragons, two mantises and a bee stack their separate player bonuses")
 state.stat_ranks.vitality=2;state.stat_ranks.critical_chance=2
 var gear_crit:float=player.accessory_bonuses.get("critical_chance",0)
 player.accessory_bonuses.critical_chance=gear_crit+10
 check(player.health_regeneration()==12 and player.combat_tuning("critical_chance")==base_crit+42,"Family passives add to existing Vitality, allocated crit and equipment bonuses")
 state.stat_ranks.vitality=0;state.stat_ranks.critical_chance=0;player.accessory_bonuses.critical_chance=gear_crit
 state.award_pet_enemy(Pets.key(41),160);state.award_pet_enemy(Pets.key(21),160)
 game.show_equipment_hub(true);await frames()
 var hub=game.equipment_hub;hub.select_owner(3)
 check(hub.stats.pet_passive.visible and hub.stats.pet_passive_button.visible and not hub.stats.pet_passive_button.disabled and hub.stats.pet_passive_heading.text=="PASSIVE · Lv 1","Selected dragon offers its level-one passive and earned upgrade")
 check(hub.passive_icon.texture==hub.stats.FAMILY_PASSIVE_ICONS.regeneration and hub.stats.pet_passive_icon.texture==hub.passive_icon.texture and hub.passive_slot.tooltip_text.contains("+5 HP"),"Both dragon passive displays use the original water dragon energy icon and explain its player bonus")
 var handle:int=army.handles[army.HOUND_ID-41]
 army.apply_hit(handle,{"amount":25.0});var wounds:float=army.unit_state(handle).max_hp-army.unit_state(handle).hp
 await click(hub.stats.pet_passive_button)
 check(state.pet_passive_level(Pets.key(41))==2 and state.pet_points(Pets.key(41))==0 and player.health_regeneration()==15,"Actual pointer buying raises only the selected dragon's regen immediately")
 check(hub.stats.pet_passive_value.text=="+10 HP/sec" and hub.stats.pet_passive_button.disabled and hub.passive_slot.tooltip_text.contains("Lv 2"),"Both passive displays refresh and prevent spending the same point again")
 check(is_equal_approx(army.unit_state(handle).max_hp-army.unit_state(handle).hp,wounds),"Buying the passive preserves live native pet wounds")
 check(not game.spend_pet_stat(Pets.key(21),"passive"),"Stale wearer requests cannot train another pet")
 await capture("dragon-passive")
 hub.select_owner(1);await click(hub.stats.pet_passive_button)
 check(hub.passive_icon.texture==hub.stats.FAMILY_PASSIVE_ICONS.critical_chance and hub.stats.pet_passive_icon.texture==hub.passive_icon.texture,"Both mantis passive displays use the original mantis critical icon")
 check(state.pet_passive_level(Pets.key(21))==2 and player.combat_tuning("critical_chance")==base_crit+45 and hub.stats.pet_passive_value.text=="+30% Crit","Mantis pointer upgrade adds fifteen crit points and shows its own rank")
 check(state.pet_passive_level(Pets.key(36))==1 and state.stat_points==0,"Another mantis and character points stay independent")
 await capture("mantis-passive")
 root.size=Vector2i(960,640);await frames()
 check(hub.stats.panel.get_global_rect().encloses(hub.stats.pet_passive_button.get_global_rect()) and not hub.stats.pet_passive_button.get_global_rect().intersects(hub.stats.pet_passive_value.get_global_rect()),"Passive upgrade fits the small panel and clears its value")
 await capture("mantis-passive-small")
 hub.select_owner(5)
 check(hub.stats.pet_passive.visible and not hub.stats.pet_passive_button.visible and player.effective_dodge_chance()==base_dodge+10,"Bee Mirage stays fixed and read-only")
 hub.select_owner(0)
 check(hub.stats.overview_values[1].text=="15 / sec" and hub.stats.overview_values[7].text=="%d%%"%(base_crit+45),"Character Stats shows actual combined regen and crit")
 var ticket=player.attack_chain.make_ticket("crossgate_melee")
 check(ticket.critical_chance==base_crit+45,"Normal attack tickets snapshot the passive's critical chance")
 state.award_pet_enemy(Pets.key(21),20000);hub.select_owner(1)
 for i in 5:check(game.spend_pet_stat(Pets.key(21),"passive"),"Selected mantis can reach the permanent per-pet crit cap")
 hub.refresh()
 check(player.combat_tuning("critical_chance")==100 and hub.stats.pet_passive_button.disabled,"Combined crit caps at 100 and fully trained mantis disables upgrades")
 ticket=player.attack_chain.make_ticket("crossgate_melee")
 check(ticket.critical_chance==100 and preload("res://scripts/critical_hits.gd").roll(ticket),"Guaranteed passive crit reaches the shared combat roll")
 var foe=enemy(player.position+Vector3.FORWARD*4)
 var target=army.enemy_target(army.unit_state(foe).logical_id)
 var enemy_hp:float=army.unit_state(foe).hp
 check(target.take_hit(1.0,Vector3.FORWARD,false,ticket) and is_equal_approx(enemy_hp-army.unit_state(foe).hp,2.0),"A passive-capped player ticket deals an actual double-damage native critical hit")
 army.despawn(foe)
 var mirrors=preload("res://scripts/warcraft_mirrors.gd").new(player,0)
 check(mirrors.reinforce(player.character_id,player.global_position+Vector3.RIGHT*4),"Native allied fighter prepares through the existing owner")
 var body=mirrors.bodies[0]
 check(body.pet_passive_bonus("critical_chance")==0 and body.health_regeneration()==0 and body.combat_tuning("critical_chance")==game.balance_value(body.character_id,"critical_chance"),"Player family bonuses do not leak into ordinary allied fighters")
 mirrors.dispose()
 game.back_from_equipment();await frames()
 player.hp=player.max_hp-40;var hp:float=player.hp
 player._physics_process(.2)
 check(is_equal_approx(player.hp,hp+3),"The actual player physics tick heals fifteen HP per second")
 player.hp=player.max_hp-1;player._physics_process(.2)
 check(player.hp==player.max_hp,"Regeneration cannot exceed maximum health")
 army.recall_hounds();army.queue_hounds();arrive()
 check(player.health_regeneration()==15 and state.pet_passive_level(Pets.key(41))==2,"Recall and resummon retain passive ranks and party effects")
 game.settings.forest_pet_loadout=[Pets.key(41)];army.reconcile_pet_loadout()
 check(player.health_regeneration()==10 and player.combat_tuning("critical_chance")==base_crit and player.effective_dodge_chance()==base_dodge,"Removing party members immediately removes exactly their bonuses")
 check(ticket.critical_chance==100,"Already committed attack tickets retain their critical snapshot after removal")
 var retained=state.pet_stat_ranks.duplicate(true)
 game.preview_forest_map(doc.data,false,false,true)
 check(game.model.team_progression==state and state.pet_stat_ranks==retained and player.health_regeneration()==10,"Retained-run travel keeps trained passives")
 var nodes=int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT));var resources=int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT))
 for i in 100:
  player.health_regeneration();player.combat_tuning("critical_chance");player.effective_dodge_chance()
 check(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)==nodes and Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)==resources,"Repeated bonus lookups create no nodes or resources")
 game.queue_free();current_scene=null;paused=false;await frames(4);DirAccess.remove_absolute(ProjectSettings.globalize_path(cfg))
 print("PET_FAMILY_PASSIVES_RESULT checks=",checks," failures=",failures);quit(1 if failures else 0)
