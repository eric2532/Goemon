extends "res://tests/forest-shrine/pet_attack_skills_test.gd"
const Skills=preload("res://scripts/spells/skill_balance.gd")
const Evidence="res://build/Other Files/Pet Skills/Independent Levels/"
var launches:Array=[]

func first_cast(handle:int):
 var expected=0
 var pictured=false
 for tick in 360:
  advance()
  var starts=game.army_runtime.event_log.filter(func(event):return event.kind=="pet_skill_started" and event.ticket_id==handle)
  if not starts.is_empty():expected=roundi(1.0/float(starts[0].amount))
  var caster=game.army_runtime.pet_skills.casters[Pets.key(0)]
  if not pictured and not starts.is_empty() and caster.current_skill in [Pets.Spells.SURE_STRIKE,"kazi/fire"]:
   pictured=true
   await picture("%s-level-%02d-charge"%[Skills.Levels.family(caster.current_skill),caster.ticket.skill_level])
  if expected>0 and game.army_runtime.event_log.filter(func(event):return event.kind=="pet_skill_contact" and event.ticket_id==handle).size()>=expected:return
 check(false,"Pet completes all native contacts")

func picture(stem:String):
 if DisplayServer.get_name()=="headless":return
 game.army_runtime.flush_presentation();game.forest_ui.sync()
 await process_frame;await RenderingServer.frame_post_draw
 check(root.get_texture().get_image().save_png(Evidence+stem+".png")==OK,"Captured "+stem)

func run():
 create_timer(300).timeout.connect(func():printerr("PET_SKILL_LEVELS_TIMEOUT");quit(1))
 DirAccess.make_dir_recursive_absolute(Evidence);root.size=Vector2i(1280,800);root.set_flag(Window.FLAG_NO_FOCUS,true)
 var doc=load("res://scripts/forest/forest_map_document.gd").new();doc.load_wind_meadow()
 await setup_fixture(doc.data)
 var p=game.player;var army=game.army_runtime;var state=game.model.team_progression
 game.set_process(false);army.set_process(false);army.set_physics_process(false);game.camera_rig.set_process(false)
 p.select_character(37);fresh();state.reset();p.model.select_stance(1)
 home.y=game.model.surface_height(home.x,home.z)+.05;p.position=home+Vector3.RIGHT*30
 game.training_dummy.position=home+Vector3.DOWN*1000
 game.model.falan_floor=0;game.model.waves.patrol_posts.clear();game.model.waves.crossgate_pet_test=true;army.record_events=true
 for node in [game,p,game.camera_rig,game.forest_ui]:node.set_process_input(false);node.set_process_unhandled_input(false)
 root.gui_disable_input=true;game.model.update_vision(home)
 var pool=Pool.service(game)
 pool.launched.connect(func(shot):
  if is_instance_valid(shot.hero) and shot.hero.get("pet_key")!=null:
   shots.append(shot);shot.set_physics_process(false)
   launches.append({"ticket":shot.attack_ticket.duplicate(true),"damage":shot.damage}))
 var saved=FileAccess.get_sha256(game.settings_path)
 for id in Pets.SKILLS:
  if id==Pets.Spells.BEE_FLURRY:continue # Covered by the five-hit native flurry fixture.
  if Skills.Levels.stats(id,1).is_empty():continue
  for level_ in [1,30]:
   await equip_pack([0],[[id,"",""]])
   launches.clear()
   var caster=army.pet_skills.casters[Pets.key(0)]
   Skills.set_level(caster,id,level_)
   var handle:int=army.handles[army.HOUND_ID];var at:Vector3=army.unit_state(handle).position
   var victim=spawn(at-home+Vector3.FORWARD*3);var before=victim.hp
   game.camera_rig.camera.global_position=at+Vector3(8,8,14);game.camera_rig.camera.look_at(at+Vector3(0,2,-2))
   check(caster.team_progression==state and Skills.level_for(caster,id)==level_ and Skills.level_for(p,id)==1,"Pet owns its %s Lv%d independently of the character"%[id,level_])
   await first_cast(handle)
   check(caster.ticket.skill_level==level_ and caster.ticket.skill_rules==Skills.Levels.stats(id,level_),"Real pet cast snapshots its own level with the shared formulas: %s Lv%d"%[id,level_])
   check(pool.misses==0,"Upgraded %s capacity is prepared before casting"%id)
   if id==Pets.Spells.SURE_STRIKE:
    check(is_equal_approx(before-victim.hp,250.0*(1.0+.1*level_)),"Pet 乾坤 applies shared damage across its native contacts")
    check(caster.charge.texture==caster.ShineTiers.textures["110103" if level_==1 else "111016"],"Pet physical shine follows the learned tier")
   elif id==Pets.Spells.COMBO:
    check(is_equal_approx(before-victim.hp,250.0*float(Skills.Levels.stats(id,level_).damage)),"Pet 連擊 applies shared level damage per native hop")
   else:
    check(not launches.is_empty() and launches.all(func(shot):return shot.ticket.skill_level==level_),"Every pet projectile retains the learned level: %s"%id)
    if id in ["kazi/qigong",Pets.Spells.MAZE_QI,Pets.Spells.MOON]:
     check(shots.size()==int(Skills.effective(caster,id,"count")),"Pet %s emits the total level-based quota once across all contacts"%id)
     check(launches.all(func(shot):return is_equal_approx(shot.damage,Skills.damage(caster,caster.ticket,0))),"Pet %s uses the shared level damage formula"%id)
   var snapshot=caster.ticket.duplicate(true)
   Skills.set_level(caster,id,1 if level_==30 else 30)
   check(caster.ticket==snapshot,"A level purchase does not rewrite an active pet cast: %s"%id)
 # The Pets tab spends the same points for the chosen pet only.
 state.pet_skill_levels.clear()
 await equip_pack([0],[[Pets.Spells.SURE_STRIKE,"",""]])
 var caster=army.pet_skills.casters[Pets.key(0)]
 var owner_id=caster.get_instance_id()
 state.stat_points=1;game.show_status_panel();await frames()
 var panel=game.status_panel;panel.find_child("PetsTab",true,false).pressed.emit();await frames()
 check(panel.pets_content.visible and not panel.skills_content.visible and not panel.stats_content.visible,"Pets opens beside Stats and Skills")
 root.gui_disable_input=false
 var event=InputEventMouseButton.new();event.device=104;event.button_index=MOUSE_BUTTON_LEFT;event.pressed=true;event.position=panel.pet_skill_buttons[0].get_global_rect().get_center()
 root.push_input(event,true);event=event.duplicate();event.pressed=false;root.push_input(event,true);await frames()
 root.gui_disable_input=true
 check(state.stat_points==0 and Skills.level_for(caster,Pets.Spells.SURE_STRIKE)==2 and Skills.level_for(p,Pets.Spells.SURE_STRIKE)==1,"A pointer purchase spends one shared point on the selected pet only")
 check(panel.pet_skill_buttons[0].disabled and panel.point_label.text=="0" and not game.spend_pet_skill(Pets.key(0),Pets.Spells.SURE_STRIKE),"No-point and stale requests cannot overspend")
 await picture("pet-skill-points")
 root.size=Vector2i(960,640);await frames();await picture("pet-skill-points-small")
 check(root.get_visible_rect().encloses(panel.panel.get_global_rect()) and panel.panel.get_global_rect().encloses(panel.pet_skill_buttons[2].get_global_rect()),"The Pets tab and upgrade buttons fit the smaller window")
 root.size=Vector2i(1280,800)
 game.close_status_panel();await frames()
 check(caster.get_instance_id()==owner_id,"Upgrading preserves the summoned pet's caster")
 var handle:int=army.handles[army.HOUND_ID];var at:Vector3=army.unit_state(handle).position
 var victim=spawn(at-home+Vector3.FORWARD*3);var before=victim.hp
 await first_cast(handle)
 check(caster.ticket.skill_level==2 and is_equal_approx(before-victim.hp,300),"The existing pet's next cast uses the purchased level")
 for fighter in p.RogueRoster.CROSSGATE:
  p.select_character(fighter)
  check(Skills.level_for(caster,Pets.Spells.SURE_STRIKE)==2,"Changing Cross Gate character retains shared pet levels: %d"%fighter)
 check(FileAccess.get_sha256(game.settings_path)==saved,"Pet levels and point purchases preserve saved settings")
 await equip_pack([0,21],[[Pets.Spells.SURE_STRIKE,"",""],[Pets.Spells.SURE_STRIKE,"",""]])
 check(Skills.level_for(army.pet_skills.casters[Pets.key(0)],Pets.Spells.SURE_STRIKE)==2 and Skills.level_for(army.pet_skills.casters[Pets.key(21)],Pets.Spells.SURE_STRIKE)==1,"Different pets retain separate levels for the same skill")
 Skills.set_level(p, Pets.Spells.SURE_STRIKE,10)
 check(Skills.pet_level_for(state,Pets.key(0),Pets.Spells.SURE_STRIKE)==2 and Skills.pet_level_for(state,Pets.key(21),Pets.Spells.SURE_STRIKE)==1,"Upgrading the character does not change either pet's levels")
 game.show_status_panel();await frames();panel=game.status_panel;panel.show_pets();panel.select_pet(1);state.stat_points=2;panel.refresh()
 panel.pet_skill_buttons[0].pressed.emit()
 check(state.stat_points==1 and Skills.pet_level_for(state,Pets.key(21),Pets.Spells.SURE_STRIKE)==2,"Selecting the second pet upgrades its own skill")
 check(not game.spend_pet_skill("missing",Pets.Spells.SURE_STRIKE) and not game.spend_pet_skill(Pets.key(21),"kazi/fire") and not game.spend_pet_skill(Pets.key(21),""),"Unknown pets and unequipped/empty skills cannot spend points")
 Skills.set_level(army.pet_skills.casters[Pets.key(21)],Pets.Spells.SURE_STRIKE,30);panel.refresh()
 check(panel.pet_skill_buttons[0].disabled and panel.pet_skill_levels[0].text=="Lv 30 MAX" and not game.spend_pet_skill(Pets.key(21),Pets.Spells.SURE_STRIKE) and state.stat_points==1,"Maximum levels and stale clicks preserve points")
 game.settings.forest_pet_skills[Pets.key(21)][1]=Pets.Spells.SPIRIT;panel.refresh()
 check(panel.pet_skill_buttons[1].disabled and not game.spend_pet_skill(Pets.key(21),Pets.Spells.SPIRIT) and state.stat_points==1,"Spirit cannot consume points without defined level rules")
 game.settings.forest_pet_skills[Pets.key(21)][1]=""
 Skills.set_level(army.pet_skills.casters[Pets.key(21)],Pets.Spells.SURE_STRIKE,29)
 army.despawn(army.handles[army.HOUND_ID-21]);panel.refresh();panel.pet_skill_buttons[0].pressed.emit()
 check(state.stat_points==0 and Skills.pet_level_for(state,Pets.key(21),Pets.Spells.SURE_STRIKE)==30 and army.pet_skills.casters[Pets.key(21)].native_handle==0,"A selected unsummoned pet can be trained without summoning it")
 panel.show_skills(true);check(not panel.pets_content.visible and panel.skills_content.visible,"Skills switches back from Pets")
 panel.show_skills(false);check(not panel.pets_content.visible and panel.stats_content.visible,"Stats switches back from Pets")
 game.close_status_panel();await frames()
 await equip_pack([21],[[Pets.Spells.SURE_STRIKE,"",""]])
 await equip_pack([0],[[Pets.Spells.SURE_STRIKE,"",""]])
 check(Skills.pet_level_for(state,Pets.key(0),Pets.Spells.SURE_STRIKE)==2 and Skills.pet_level_for(state,Pets.key(21),Pets.Spells.SURE_STRIKE)==30,"Removing and resummoning pets preserves their individual run levels")
 await equip_pack([0],[[Pets.Spells.COMBO,"",""]])
 var combo_pet=Pets.key(0)
 caster=army.pet_skills.casters[combo_pet]
 Skills.set_level(caster,"shin/combo",25)
 check(Skills.level_for(caster,Pets.Spells.COMBO)==25,"Shin's Combo alias sets the pet's shared skill level")
 state.cards_enabled=true;state.rarity_bag.assign([2])
 game.award_team_kill(state.kills_required()*10);game._process(0)
 var combo_card=Pets.Spells.COMBO+"|"+combo_pet
 check(is_instance_valid(game.team_upgrade_picker) and combo_card in state.offer,"Level-up offers the equipped pet combo")
 check(game.choose_team_upgrade(combo_card,state.choice_level()) and Skills.level_for(caster,Pets.Spells.COMBO)==30,"Diamond raises the summoned pet's combo level by five")
 handle=army.handles[army.HOUND_ID];at=army.unit_state(handle).position
 var combo_victim=spawn(at-home+Vector3.FORWARD*3,1.0);combo_victim.freeze_for(1000)
 var victim_id:int=combo_victim.forest_id;var kills_before:int=game.kills
 var xp_before:int=state.pet_experience[combo_pet].total_kills if state.pet_experience.has(combo_pet) else 0
 for tick in 1200:advance()
 var combo_starts=army.event_log.filter(func(event):return event.kind=="pet_skill_started" and event.ticket_id==handle)
 var combo_contacts=army.event_log.filter(func(event):return event.kind=="pet_skill_contact" and event.ticket_id==handle)
 var hops=int(Skills.effective(caster,Pets.Spells.COMBO,"count"))
 check(hops==17 and combo_starts.size()==hops and combo_starts.all(func(event):return event.projectile_id==combo_starts[0].projectile_id),"The upgraded pet completes all 17 native hops in one cast")
 check(combo_contacts.size()==hops*Pets.attack_pattern(0).contacts.size() and combo_contacts.all(func(event):return event.target_id==victim_id) and game.kills==kills_before+1,"After a lethal hit, the remaining contacts finish on the same target and award one kill total")
 check(state.pet_experience.has(combo_pet) and state.pet_experience[combo_pet].total_kills==xp_before+1,"A real pet skill kill awards XP to that appearance once")
 # Qi color aliases prepare every matching controller before the next cast.
 await equip_pack([0],[[Pets.Spells.MAZE_QI,"",""]])
 caster=army.pet_skills.casters[Pets.key(0)]
 Skills.set_level(caster,"kazi/qigong",1);Skills.set_level(caster,"kazi/qigong",30)
 var qi=caster.controllers[Pets.Spells.MAZE_QI]
 check(pool.all[qi.pool_key].size()>=32,"A normal-Qi upgrade prepares the gold-Qi pet's level-30 quota")
 await equip_pack([0],[[Pets.Spells.COMBO,"",""]])
 caster=army.pet_skills.casters[Pets.key(0)]
 Skills.set_level(caster,"kazi/combo",30);game.update_skill_balance(Pets.Spells.COMBO,"count",32)
 check(Skills.effective(caster,Pets.Spells.COMBO,"count")==41,"Level 30 combo plus saved tuning retains all 41 hops")
 game.reset_skill_balance(Pets.Spells.COMBO)
 # Five individually upgraded pets reuse the existing prepared resources.
 await equip_pack([0,21,41,61,81],[["kazi/qigong","",""] , ["kazi/qigong","",""], ["kazi/qigong","",""], ["kazi/qigong","",""], ["kazi/qigong","",""]])
 for pet in army.pet_skills.casters.values():Skills.set_level(pet,"kazi/qigong",30)
 for i in 5:spawn(Vector3((i-2)*10,0,-4))
 for tick in 600:advance()
 check(army.pet_skills.casters.size()==5 and army.pet_skills.casters.values().all(func(pet):return pet.ticket.get("skill_level",0)==30),"All five independently upgraded pets cast their level-30 skill")
 await frames(3)
 var nodes=get_node_count();var resources=Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT);var created=pool.created
 var sample_start=costs.size()
 for tick in 600:advance()
 await frames(3)
 check(get_node_count()==nodes and Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)<=resources and pool.created==created and pool.misses==0,"Repeated level-30 pet casts retain warmed nodes, resources and pool capacity")
 var samples=costs.slice(sample_start);samples.sort()
 print("PET_INDEPENDENT_LEVEL_STEP_US p95=",samples[floori(samples.size()*.95)]," max=",samples.back()," pool_misses=",pool.misses)
 game.camera_rig.camera.global_position=home+Vector3(0,24,30);game.camera_rig.camera.look_at(home+Vector3(0,2,-4))
 await picture("five-level-30-pets")
 game.show_pet_loadout();await frames()
 check(game.pet_loadout_panel.find_child("PetSkill0_0",true,false)==null and Skills.pet_level_for(state,Pets.key(0),"kazi/qigong")==30,"The pet picker has no duplicate skill dropdown and preserves the learned Qi level")
 await picture("individual-level-loadout")
 game.close_pet_loadout();await frames()
 game.settings.forest_pet_skills[Pets.key(0)]=["kazi/qigong","kazi/fire",Pets.Spells.SPIRIT]
 army.reconcile_pet_loadout();Skills.set_level(army.pet_skills.casters[Pets.key(0)],"kazi/fire",10)
 state.stat_points=2;game.show_status_panel();await frames();panel=game.status_panel;panel.show_pets()
 check(panel.pet_selectors.all(func(choice):return not choice.disabled) and panel.pet_skill_ids==["kazi/qigong","kazi/fire",Pets.Spells.SPIRIT],"Five pet portraits and the selected pet's three skills appear together")
 check(panel.pet_skill_levels[0].text=="Lv 30 MAX" and panel.pet_skill_levels[1].text=="Lv 10 → 11" and panel.pet_skill_buttons[2].disabled,"Each row shows its own level, cap or undefined upgrade state")
 await picture("pets-tab-five-pets-three-skills")
 panel.pet_skill_buttons[1].pressed.emit()
 check(state.stat_points==1 and Skills.pet_level_for(state,Pets.key(0),"kazi/fire")==11 and Skills.level_for(p,"kazi/fire")==1 and Skills.pet_level_for(state,Pets.key(21),"kazi/fire")==1,"The second skill row spends only on this pet and this skill")
 game.close_status_panel();await frames()
 # A fresh run rebinds retained adapters to the new progression object.
 var next_state=load("res://scripts/forest/team_progression.gd").new()
 game.model.team_progression=next_state;p.team_progression=next_state
 army.reconcile_pet_loadout()
 check(army.pet_skills.casters.values().all(func(pet):return pet.team_progression==next_state and Skills.level_for(pet,"kazi/qigong")==1),"Fresh-run pets use the new run's level-one skills")
 game.settings.forest_pet_loadout=[];army.reconcile_pet_loadout();game.show_status_panel();await frames();panel=game.status_panel;panel.show_pets()
 check(panel.pet_skill_buttons.all(func(plus):return plus.disabled) and panel.pet_name.text.contains("Q Equipment") and not game.spend_pet_skill(Pets.key(0),Pets.Spells.COMBO),"An empty pack points to Q Equipment and cannot spend points")
 game.close_status_panel();await frames()
 game.queue_free();paused=false;await frames(4)
 if FileAccess.file_exists(cfg):DirAccess.remove_absolute(ProjectSettings.globalize_path(cfg))
 print("PET_SKILL_LEVELS_RESULT checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)
