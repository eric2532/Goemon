extends "res://scripts/recovered_goemon_gameplay_tests.gd"
const Pets=preload("res://scripts/forest/pet_catalog.gd")
const OUT="res://build/Other Files/Asset Toolkit/Qi Skill Selection/"
func press_p(shift:bool=false):
 if shift:
  if is_instance_valid(game.pet_loadout_panel):game.close_pet_loadout()
  else:game.show_pet_loadout()
  return
 var event=InputEventKey.new();event.physical_keycode=KEY_P;event.pressed=true;event.shift_pressed=shift;game._input(event)
func click(control:Control):
 var event=InputEventMouseButton.new();event.device=104;event.button_index=MOUSE_BUTTON_LEFT;event.pressed=true;event.position=control.get_global_rect().get_center()
 root.push_input(event,true);event=event.duplicate();event.pressed=false;root.push_input(event,true);await frames()
func capture(stem:String):
 if DisplayServer.get_name()=="headless":return
 await frames(3);await RenderingServer.frame_post_draw
 check(root.get_texture().get_image().save_png(OUT+stem+".png")==OK,"Captured "+stem)
func arrive():
 for i in 50:
  game.army_runtime.integration_tick(1.0/60);game.army_runtime.flush_presentation()
  if game.army_runtime.pending_hounds.is_empty():break
 game.forest_ui.sync()
func population()->int:
 var data:Dictionary=game.army_runtime.render_snapshot();var total=0
 for i in data.kinds.size():
  if data.kinds[i]==19 and data.teams[i]==1:total+=1
 return total
func run():
 create_timer(180).timeout.connect(func():quit(1));DirAccess.make_dir_recursive_absolute(OUT)
 check(Pets.motions().variants.size()==Pets.COUNT and Pets.COUNT>82,"Catalog preserves the original 82 choices and adds the reviewed families")
 check(Pets.sanitized(null)==Pets.DEFAULT,"Malformed saved type restores the five defaults")
 check(Pets.sanitized([]).is_empty(),"An intentionally empty pack stays empty")
 check(Pets.sanitized([Pets.key(0),Pets.key(0),"missing",3,Pets.key(21)])==[Pets.key(0),Pets.key(21)],"Saved keys reject duplicates, unknown entries and wrong types")
 check(Pets.sanitized(Pets.motions().variants.map(func(v):return v.key)).size()==5,"Oversized saves are capped at five")
 check(Pets.SKILLS.keys().slice(0,11)==[Pets.Spells.SURE_STRIKE,Pets.Spells.COMBO,"kazi/qigong",Pets.Spells.MAZE_QI,Pets.Spells.MOON,"kazi/fire","kazi/ice","kazi/wind","kazi/meteor",Pets.Spells.SPIRIT,Pets.Spells.BEE_FLURRY] and Pets.MAX_SKILLS==3,"The existing eleven native skill codes and three slots retain their order")
 check(Pets.skill_codes(["kazi/qigong",Pets.Spells.MAZE_QI,"kazi/fire"])==PackedInt32Array([3,4,6]),"Qi aliases and later spells retain their native wire codes")
 for pair in [["kazi/qigong",Pets.Spells.MAZE_QI],[Pets.Spells.MAZE_QI,"kazi/qigong"]]:
  check(Pets.sanitized_skills({Pets.key(0):[pair[0],pair[1],"kazi/fire"]})[Pets.key(0)]==[pair[0],"","kazi/fire"],"Saved Qi colors share one slot; the first assignment and other skills survive")
 for invalid in [null,[],"fire",{Pets.key(0):"fire"},{"missing":"fire"},{Pets.key(0):3},{3:"fire"},{Pets.key(0):""}]:
  check(Pets.sanitized_skills(invalid).is_empty(),"Unsupported pet skill assignments are safely discarded: "+str(invalid))
 check(Pets.key(31)=="puk3:823" and Pets.skin("puk3:909")==-1,"The retired snow mantis keeps its exact source instead of the newer unrelated creature")
 root.size=Vector2i(1280,800);root.set_flag(Window.FLAG_NO_FOCUS,true)
 var doc=load("res://scripts/forest/forest_map_document.gd").new()
 if "--large" in OS.get_cmdline_user_args():doc.load_wind_meadow_large()
 else:doc.load_wind_meadow()
 await setup_fixture(doc.data)
 game.player.select_character(34);fresh()
 game.set_process(false);game.army_runtime.set_process(false);game.army_runtime.set_physics_process(false)
 game.player.position=Vector3(-150,0,127);game.player.position.y=game.model.surface_height(-150,127)
 var army=game.army_runtime;var selected:Array=game.settings.forest_pet_loadout.duplicate()
 check(game.settings.forest_pet_skills.is_empty(),"Existing settings without pet skills start with no assignments")
 game.settings.volume=.37
 press_p(true);await frames()
 var panel=game.pet_loadout_panel
 check(panel.find_child("SavePetLoadout",true,false)==null,"Pet choices need no separate Save button")
 check(is_instance_valid(panel) and game.paused and paused and Input.mouse_mode==Input.MOUSE_MODE_VISIBLE,"The pet fixture opens and safely pauses the run")
 check(panel.cards.size()==Pets.COUNT and panel.slots.size()==5 and panel.cards.all(func(c):return c.icon!=null),"Every selectable variant has a real portrait and only five loadout slots")
 check(panel.find_children("PetSkill*","OptionButton",true,false).is_empty() and panel.find_children("*","OptionButton",true,false).size()==1,"The pet picker keeps its category filter and removes duplicate skill dropdowns")
 check(not panel.status.visible and panel.find_child("PetChoices",true,false).size.y>=300,"The pet grid uses the freed skill-control space")
 var first_pet=panel.selected[0]
 var equipped=[Pets.Spells.SURE_STRIKE,Pets.Spells.COMBO,"kazi/qigong"]
 check(game.save_pet_loadout(panel.selected,{first_pet:equipped}),"Existing shared skill assignments save independently of the pet picker")
 panel.apply();game.load_settings()
 check(game.settings.forest_pet_skills[first_pet]==equipped,"Saving the pet pack preserves all three existing skill assignments")
 check(army.pet_skills.casters.has(first_pet) and army.pet_skills.casters[first_pet].controllers.has("kazi/qigong"),"Preserved assignments retain the existing prepared caster")
 check(Pets.sanitized_skills({first_pet:"kazi/qigong"})[first_pet]==["kazi/qigong","",""],"A prior single-skill save migrates into slot one")
 check(Pets.sanitized_skills({first_pet:[equipped[0],equipped[0],"missing","kazi/qigong"]})[first_pet]==[equipped[0],"",""],"Invalid, duplicate and fourth skill slots cannot be activated")
 var aliases={first_pet:[Pets.Spells.MAZE_QI,"","kazi/fire"]}
 check(game.save_pet_loadout(panel.selected,aliases),"A saved Qi alias remains valid in the shared skill settings")
 panel.apply();game.load_settings()
 check(game.settings.forest_pet_skills==aliases,"An already-open pet picker preserves later skill changes and their exact saved aliases")
 check(army.pet_skills.casters[first_pet].controllers.has(Pets.Spells.MAZE_QI) and not army.pet_skills.casters[first_pet].controllers.has("kazi/qigong"),"One saved Qi alias prepares only one Qi controller")
 await capture("picker-without-skill-dropdowns")
 check(game.save_pet_loadout(panel.selected,{}),"Shared skill settings can clear the prepared caster")
 panel.apply();await frames(3)
 check(game.settings.forest_pet_skills.is_empty() and army.pet_skills.casters.is_empty(),"The pet picker preserves cleared skill settings")
 var cycle=selected.duplicate()
 for i in 7:
  var index=61+i;cycle[i%5]=Pets.key(index);panel.select_slot(i%5);panel.toggle(index)
  check(panel.selected==cycle and panel.selected.size()==5,"Full-pack picks replace only the explicitly selected slot")
 check(not panel.status.visible,"Cycling pets does not add instruction text")
 panel.selected.assign(selected);panel.select_slot(0);panel.refresh()
 panel.toggle(61);check(panel.selected==[Pets.key(61)]+selected.slice(1) and panel.target_slot==0,"A replacement keeps its explicitly selected slot")
 panel.remove(0)
 check(not panel.slots[4].disabled,"The next empty party position can be selected")
 panel.select_slot(4)
 panel.toggle(61)
 check(not panel.slots[4].disabled and Pets.display_name(61,game.settings.forest_pet_names) in panel.slots[4].text and panel.slots[4].tooltip_text.is_empty(),"The party slot shows its selected pet without a redundant tooltip")
 check(panel.cards[61].accessibility_name.begins_with(Pets.display_name(61,game.settings.forest_pet_names)),"Pet cards keep their selected source names accessible")
 check(panel.selected.size()==5 and Pets.key(61) in panel.selected,"Removing a slot permits one replacement")
 panel.filter("Mantises");check(panel.cards.filter(func(c):return c.visible).size()==20,"Mantises category contains all twenty reviewed variants")
 await capture("loadout-mantises")
 panel.filter("Dragon lizards");check(panel.cards.filter(func(c):return c.visible).size()==20,"Dragon-lizard filter shows only the twenty approved IDs")
 check(Pets.key(54)=="puk3:821" and Pets.skin("puk3:907")==-1,"The snow dragon keeps its exact archived key")
 await capture("loadout-dragon-lizards")
 panel.filter("Bees");check(panel.cards.filter(func(c):return c.visible).size()==21,"Bees filter contains exactly the 21 reviewed IDs")
 check(Pets.key(74)=="puk3:822" and Pets.skin("puk3:908")==-1 and Pets.skin("original:2865")==-1,"Snow bee uses its retired exact key; old bee versions are excluded")
 check(Pets.portrait(81).get_image().get_used_rect().has_area(),"The twenty-first bee has a nonempty image")
 await capture("loadout-bees")
 check(game.settings.forest_pet_loadout==panel.selected,"Choosing pets saves the actual image selection immediately")
 game.load_settings();check(game.settings.forest_pet_loadout==panel.selected and is_equal_approx(game.settings.volume,.37),"Selection survives settings reload without changing unrelated preferences")
 var saved_config=ConfigFile.new();saved_config.load(game.settings_path)
 check(saved_config.get_value("settings","forest_pet_skills",null)=={} and game.settings.forest_pet_skills=={},"The empty per-pet skill assignments are explicitly saved and reload safely")
 panel.filter("Hounds");check(panel.cards.filter(func(c):return c.visible).size()==21,"Hounds category preserves all original choices")
 panel.filter("Aura & effects");check(panel.cards.filter(func(c):return c.visible).size()==range(Pets.COUNT).filter(func(i):return Pets.listed(i) and Pets.effect(i)).size(),"Aura filter includes distinct reviewed source effects")
 panel.filter("All");await capture("loadout-all")
 root.size=Vector2i(960,640);await frames();await capture("loadout-small")
 check(root.get_visible_rect().encloses(panel.panel.get_global_rect()),"The page fits a 960 by 640 window")
 check(panel.panel.get_global_rect().encloses(panel.find_child("ClosePetLoadout",true,false).get_global_rect()),"Close remains reachable in a smaller window")
 check(panel.slots.all(func(slot):return panel.panel.get_global_rect().encloses(slot.get_global_rect())),"All five party portraits remain usable in a smaller window")
 var before_removal=panel.selected.duplicate();panel.remove(0)
 check(game.settings.forest_pet_loadout==before_removal.slice(1),"Removing a pet saves immediately")
 press_p(true);await frames()
 check(not is_instance_valid(game.pet_loadout_panel) and not paused and not game.paused,"Closing the pet fixture resumes the saved selection")
 game.load_settings();check(game.settings.forest_pet_loadout==before_removal.slice(1),"Closing and reload retain the chosen removal")
 check(game.settings.forest_pet_skills.is_empty(),"Automatic selection saves preserve independent skill settings")
 check(game.save_pet_loadout(before_removal),"Restore the five-pet fixture for lifecycle checks")
 root.size=Vector2i(1280,800)
 army.queue_hounds();army.queue_hounds();check(army.pending_hounds.size()==5,"Missing-only queuing queues each selected pet once")
 arrive();check(population()==5 and army.pending_hounds.is_empty(),"Exactly five selected pets arrive through the native placement queue")
 var skin=Pets.skin(game.settings.forest_pet_loadout[0]);var id=army.HOUND_ID-skin;var handle:int=army.handles[id]
 var pet_state=army.unit_state(handle)
 check(pet_state.hp==150 and pet_state.max_hp==150 and pet_state.mana==50 and pet_state.max_mana==50,"Selected pets arrive with 150 HP and 50 mana")
 army.apply_hit(handle,{"amount":30.0});arrive();var wounded:float=army.unit_state(handle).hp
 army.queue_hounds();arrive();check(population()==5 and army.handles[id]==handle and army.unit_state(handle).hp==wounded,"Missing-only queuing never duplicates or heals a living pet")
 check(game.save_pet_loadout(game.settings.forest_pet_loadout) and army.unit_state(handle).hp==wounded and army.handles[id]==handle,"Saving the same selection preserves the living pet and its wounds")
 army.begin_integration(1.0/60,false);army.queue_hounds()
 check(not army.integration_pending and population()==5,"Missing-only queuing finishes an in-flight native step before reconciling selected pets")
 for i in 24:army.integration_tick(1.0/60)
 army.apply_hit(handle,{"amount":100000.0});army.queue_hounds()
 check(army.pending_hounds==[skin],"A death queues only that selected missing pet")
 arrive();check(population()==5 and army.handles[id]!=handle,"A fallen pet returns with a fresh native handle")
 pet_state=army.unit_state(army.handles[id])
 check(pet_state.hp==150 and pet_state.mana==50,"A replacement arrives with full health and mana")
 check(army.native.set_pet_mana(army.handles[id],12.0) and army.recall_hounds(),"Recall a companion with depleted mana")
 check(army.pet_stats(skin).mana==12,"Recall preserves mana in Equipment")
 army.queue_hounds();arrive()
 check(army.unit_state(army.handles[id]).mana>=12 and army.unit_state(army.handles[id]).mana<13,"Resummoning starts the same pet at its saved mana")
 game.show_pet_loadout();await frames();panel=game.pet_loadout_panel
 panel.selected=Pets.sanitized([Pets.key(61),Pets.key(74),Pets.key(75),Pets.key(76),Pets.key(81)]);panel.refresh();panel.apply()
 check(population()<=5 and army.pending_hounds.is_empty(),"Changing the pack retires removed pets before more can arrive")
 game.close_pet_loadout();army.queue_hounds();arrive()
 check(population()==5 and army.pending_hounds.is_empty(),"Five simultaneous lightning, snow and XL bees use the existing native lifecycle")
 var step_times=[]
 for i in 120:
  var started=Time.get_ticks_usec()
  army.integration_tick(1.0/60);army.flush_presentation();game.crowd.army.presentation.tick(1.0/60)
  step_times.append((Time.get_ticks_usec()-started)/1000.0)
 step_times.sort();print("BEE_PACK_STEP p95_ms=",step_times[113]," max_ms=",step_times[-1])
 game.forest_ui.sync()
 game.camera_rig.set_process(false);game.camera_rig.set_physics_process(false)
 var camera=game.camera_rig.camera;camera.global_position=game.player.position+Vector3(-4,18,30);camera.look_at(game.player.position+Vector3.UP)
 game.crowd.army.presentation.tick(1.0);game.crowd.present_army(army.render_snapshot(),[]);await capture("bee-pack")
 var before_nodes=int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT));var before_resources=int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT));var times=[]
 for i in 12:
  var started=Time.get_ticks_usec();game.show_pet_loadout();times.append((Time.get_ticks_usec()-started)/1000.0);await frames();game.close_pet_loadout();await frames()
 check(int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))<=before_nodes+2 and int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT))<=before_resources+2,"Repeated picker openings retain no extra controls or resources")
 times.sort();print("PET_PANEL_OPEN p95_ms=",times[10]," max_ms=",times[-1]," nodes=",Performance.get_monitor(Performance.OBJECT_NODE_COUNT)," resources=",Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT))
 game.show_pet_loadout();panel=game.pet_loadout_panel;var saved=game.settings.forest_pet_loadout.duplicate();var path:String=game.settings_path
 var previous_skills={Pets.key(0):"rollback-marker"};game.settings.forest_pet_skills=previous_skills
 game.settings_path="user://missing-pet-directory/settings.cfg";var previous_next=panel.target_slot;panel.remove(0)
 check(game.settings.forest_pet_loadout==saved and population()==5 and "Could not" in panel.status.text,"Failed saves retain the previous selection and all living pets")
 check(panel.selected==saved and panel.target_slot==previous_next,"A failed automatic save restores the visible selection and replacement position")
 check(game.settings.forest_pet_skills==previous_skills,"Failed saves restore the previous skill settings together with the party")
 game.settings_path=path
 while not panel.selected.is_empty():panel.remove(0)
 game.close_pet_loadout();army.queue_hounds();arrive()
 check(population()==0 and army.pending_hounds.is_empty(),"An empty saved pack recalls pets and P summons nothing")
 game.load_settings();check(game.settings.forest_pet_loadout.is_empty(),"The empty pack persists across reloads")
 game.queue_free();current_scene=null;paused=false;await frames(4);DirAccess.remove_absolute(ProjectSettings.globalize_path(cfg))
 print("PET_LOADOUT_RESULT checks=",checks," failures=",failures);quit(1 if failures else 0)
