extends "res://tests/forest-shrine/unified_equipment_test.gd"

func capture(stem:String):
 if DisplayServer.get_name()=="headless":return
 await frames();RenderingServer.force_draw()
 check(root.get_texture().get_image().save_png(OUT+stem+".png")==OK,"Captured "+stem)

func choose_pet(skin:int):
 var picker=game.equipment_hub.pet_picker
 picker.filter(Pets.category(skin));await frames()
 picker.cards[skin].grab_focus();await frames();await click(picker.cards[skin])

func run():
 DirAccess.make_dir_recursive_absolute(OUT);root.size=Vector2i(1280,800)
 game=load("res://scenes/forest_title.tscn").instantiate();game.settings_path=cfg;root.add_child(game);current_scene=game;await frames(4)
 game.set_process(false);game.set_physics_process(false);game.player.set_physics_process(false);game.army_runtime.set_process(false);game.army_runtime.set_physics_process(false)
 game.settings.forest_pet_loadout=[Pets.key(0),Pets.key(21),Pets.key(41)]
 game.settings.forest_pet_skills={Pets.key(0):["kazi/fire","",""],Pets.key(21):["kazi/qigong","",""],Pets.key(61):[Pets.Spells.BEE_FLURRY,"kazi/wind",""]};game.save_settings()
 game.begin_arena();game.choose_rogue_character(34);await frames()
 var hub=game.equipment_hub;var xp=game.model.team_progression;xp.award_kills(48);game.player.refresh_max_health(true)
 var p:Hero=game.player
 var base_dodge=p.effective_dodge_chance()
 check(range(Pets.COUNT).filter(Pets.has_bee_dodge)==range(61,82),"All 21 bee variants share the innate passive")
 check(is_equal_approx(base_dodge,5.0),"A party without bees keeps the base dodge chance")
 xp.pet_skill_levels={Pets.key(0):{"fire":4},Pets.key(21):{"qigong":9}};hub.refresh()
 var saved=FileAccess.get_sha256(cfg);var points=xp.stat_points
 await click(hub.party[1])
 check(hub.selected_pet_slot==0 and hub.party[1].get_node("SelectedOutline").visible and hub.stats.heading_label.text=="PET STATS","Selecting a pet highlights its slot and switches the right panel")
 check(hub.stats.name_label.text=="Ember" and hub.party[1].text=="Ember" and hub.stats.pet_stats_content.visible and not hub.stats.character_stats_content.visible,"A catalog pet name is visible in the roster and stats")
 check(hub.pet_name_field.placeholder_text=="Ember" and hub.pet_name_field.tooltip_text.is_empty(),"The name field displays the catalog name without a hover prompt")
 check(Pets.display_name(115,{})=="Pet 116","A pet with only a generic variant label keeps a numbered name")
 check(hub.stats.level_label.text=="Lv 1" and hub.stats.pet_state.text.contains("0 / 16 XP") and hub.stats.pet_profile.max_hp==150 and hub.stats.pet_profile.damage==50,"A new pet starts at level one with its own XP and base stats")
 check(hub.stats.pet_mana.text=="50 MAX" and hub.stats.pet_mana_bar.value==50,"Unsummoned pet shows 50 maximum mana")
 check(hub.stats.pet_values.attack_speed.text=="1.0×" and hub.stats.pet_values.dodge_chance.text=="0%" and hub.stats.pet_values.counter_chance.text=="0%","Pet starts with ordinary attack speed and zero reaction chances")
 check(not hub.stats.pet_profile.summoned and hub.stats.pet_health.text.ends_with("MAX"),"An unsummoned pet shows maximum health without claiming live health")
 check(hub.stats.pet_summary_levels[0].text=="Lv 4" and hub.stats.pet_summary_names[0].text==Pets.SKILLS["kazi/fire"],"The right panel shows this pet's equipped skill and learned level")
 check(not hub.stats.pet_passive.visible,"Non-bee pet stats hide the bee passive")
 check(hub.passive_slot.visible and hub.passive_icon.texture==null,"A pet without a passive has one empty passive cell")
 hub.stats.buttons.attack.pressed.emit();check(xp.stat_points==points and xp.stat_ranks.attack==0,"Stale player-stat clicks cannot spend points while inspecting a pet")
 await click(hub.party[2]);check(hub.stats.name_label.text=="Green" and hub.stats.pet_summary_levels[0].text=="Lv 9","Another pet shows its own name and skill levels")
 check(FileAccess.get_sha256(cfg)==saved,"Inspecting pets does not change saved settings")
 await click(hub.pet_name_field)
 for input in [[KEY_Q,81],[KEY_SPACE,32],[KEY_NONE,"雪".unicode_at(0)]]:
  var typed=InputEventKey.new();typed.keycode=input[0];typed.physical_keycode=input[0];typed.unicode=input[1];typed.pressed=true
  root.push_input(typed,true)
 check(is_instance_valid(hub) and hub.pet_name_field.text=="Q 雪","Typing accepts spaces, Unicode and the Q shortcut in the name field")
 await click(hub.save_pet_name_button)
 check(hub.party[2].text=="Q 雪" and hub.stats.name_label.text=="Q 雪" and hub.party[1].text=="Ember","Saving updates only the selected pet's roster and stats labels")
 var name_config=ConfigFile.new()
 check(name_config.load(cfg)==OK and name_config.get_value("settings","forest_pet_names")=={Pets.key(21):"Q 雪"},"The custom name is saved by stable pet key")
 await click(hub.pet_name_field);hub.pet_name_field.clear()
 var enter=InputEventKey.new();enter.keycode=KEY_ENTER;enter.physical_keycode=KEY_ENTER;enter.pressed=true
 root.push_input(enter,true);await frames()
 check(hub.party[2].text=="Green" and game.settings.forest_pet_names.is_empty(),"Submitting an empty name restores the catalog name")
 var settings_path=game.settings_path
 game.settings_path="user://missing-pet-flow-folder/settings.cfg"
 hub.pet_name_field.text="Unsaved";await click(hub.save_pet_name_button)
 check(hub.party[2].text=="Green" and game.settings.forest_pet_names.is_empty() and hub.pet_name_field.text=="Unsaved" and hub.status.text.contains("Could not"),"A failed rename preserves saved labels and leaves the typed name available to retry")
 game.settings_path=settings_path
 hub.pet_name_field.text="  Quartz  ";await click(hub.save_pet_name_button)
 game.load_settings()
 hub.select_owner(1);hub.select_owner(2)
 check(game.settings.forest_pet_names=={Pets.key(21):"Quartz"} and game.settings.forest_pet_skills.has(Pets.key(21)),"Reload restores the trimmed name and preserves saved pet skills")
 check(hub.pet_name_field.text=="Quartz" and hub.stats.name_label.text=="Quartz","The saved name is visible in the field when reselecting the pet")
 check(not hub.party[4].disabled and hub.party[4].text=="Add pet" and hub.party[5].disabled,"Only the next free slot offers Add pet, preserving the saved party order")
 check(hub.find_child("PetsPage",true,false)==null and hub.party[0].get_node_or_null("RemovePet")==null,"The roster has no Manage Pets button or character removal")
 for i in range(1,hub.party.size()):
  check(hub.party[i].get_node("RemovePet").visible==(i<4),"Only occupied pet slots show a removal cross")
 await capture("pet-selected-stats")
 await click(hub.party[4]);check(hub.selected_pet_slot==3 and hub.stats.pet_profile.is_empty() and hub.stats.name_label.text=="Empty pet slot" and hub.page=="pets" and not hub.pet_name_field.visible,"An empty slot opens its add flow and hides the name field")
 await click(hub.change_pet_button)
 check(not hub.change_pet_button.visible and hub.party[4].text=="Add pet" and hub.page!="pets","Canceling an add returns to the roster's Add pet control")
 await click(hub.party[4])
 await choose_pet(61)
 check(game.settings.forest_pet_loadout==[Pets.key(0),Pets.key(21),Pets.key(41),Pets.key(61)] and hub.selected_pet_slot==3 and hub.wearer_key==hub.Gear.pet_key(Pets.key(61)) and hub.page!="pets","Choosing a new pet fills the selected empty slot and returns to inspection")
 check(hub.stats.pet_passive.visible and is_instance_valid(hub.stats.pet_passive.get_node("BeeMirageIcon").texture) and hub.stats.pet_passive.find_children("*","BaseButton",true,false).is_empty(),"Bee stats show the passive artwork as a read-only entry")
 var third_skill:Control=hub.skill_buttons.values()[2]
 check(hub.passive_slot.visible and hub.passive_icon.texture==hub.stats.BEE_MIRAGE and hub.passive_slot.position.x>third_skill.position.x+third_skill.size.x and hub.passive_slot.position.y==third_skill.position.y,"The separate passive cell sits to the right of the three skill cells")
 var previous_slot:String=hub.selected_slot;var previous_page:String=hub.page
 await click(hub.passive_slot)
 check(hub.selected_slot==previous_slot and hub.page==previous_page and hub.passive_slot.focus_mode==Control.FOCUS_NONE,"The passive cell cannot select or equip a skill")
 check(not hub.stats.pet_profile.summoned and is_equal_approx(p.effective_dodge_chance(),base_dodge+10),"One selected bee grants 10 points before summoning")
 await capture("pet-bee-passive")
 root.size=Vector2i(960,640);await frames()
 check(hub.panel.get_node("EquippedItemsFrame").get_global_rect().encloses(hub.passive_slot.get_global_rect()),"The single passive cell fits in the smaller Equipment panel")
 await capture("pet-bee-passive-small")
 root.size=Vector2i(1280,800);await frames()
 await click(hub.party[5]);await choose_pet(81)
 check(game.settings.forest_pet_loadout.size()==5,"The fifth selected slot fills without exceeding the native pack limit")
 hub.select_owner(0)
 check(not hub.passive_slot.visible,"The pet passive cell stays out of character equipment")
 check(hub.stats.overview_values[8].text=="25%" and is_equal_approx(p.effective_dodge_chance(),base_dodge+20),"Ordinary and XL bee dodge stack in combat and in player Stats")
 await click(hub.party[2]);await click(hub.change_pet_button)
 var picker=hub.pet_picker;var before=game.settings.forest_pet_loadout.duplicate();saved=FileAccess.get_sha256(cfg)
 check(picker.target_slot==1 and picker.cards[0].disabled and picker.cards[0].text.contains("Slot 1") and picker.cards[0].accessibility_name.contains("Equipped · Slot 1"),"The catalog names equipped slots and disables equipped choices")
 picker.toggle(0);check(game.settings.forest_pet_loadout==before and FileAccess.get_sha256(cfg)==saved,"Choosing an equipped pet cannot remove it or consume a save")
 await capture("pet-change-slot-catalog")
 var reward=Pets.skin("ex:1705")
 await choose_pet(reward)
 var replaced=before.duplicate();replaced[1]=Pets.key(reward)
 check(game.settings.forest_pet_loadout==replaced and hub.selected_pet_slot==1 and picker.target_slot==1,"A full-party replacement changes only the explicitly selected slot")
 picker.toggle(83);check(game.settings.forest_pet_loadout==replaced,"A stale hidden catalog action cannot cycle or replace another pet")
 check(game.settings.forest_pet_skills.has(Pets.key(21)) and Skills.pet_level_for(xp,Pets.key(21),"kazi/qigong")==9,"Replacing a pet preserves its saved skills and learned levels")
 check(hub.party[2].text=="拳擊火焰舞者" and picker.cards[21].text=="Quartz" and not picker.cards[21].disabled,"The replacement shows its catalog name and the saved name follows its original pet")
 await click(hub.change_pet_button);saved=FileAccess.get_sha256(cfg);await click(hub.change_pet_button)
 check(hub.page!="pets" and game.settings.forest_pet_loadout==replaced and FileAccess.get_sha256(cfg)==saved,"Cancel change returns to the pet without saving a different selection")
 await click(hub.party[4]);await click(hub.party[3].get_node("RemovePet"))
 replaced.remove_at(2)
 check(game.settings.forest_pet_loadout==replaced and hub.selected_pet_slot==2 and hub.wearer_key==hub.Gear.pet_key(Pets.key(61)),"The cross removes its own pet and keeps inspecting the same surviving pet")
 check(hub.party[5].text=="Add pet" and not hub.party[5].get_node("RemovePet").visible,"After removal the freed slot offers Add pet")
 await click(hub.party[1]);await click(hub.change_pet_button)
 var path=game.settings_path;game.settings_path="user://missing-pet-flow-folder/settings.cfg"
 await choose_pet(83);game.settings_path=path
 check(game.settings.forest_pet_loadout==replaced and picker.selected==Pets.sanitized(replaced) and picker.target_slot==0 and not picker.status.text.is_empty() and hub.wearer_key==hub.Gear.pet_key(Pets.key(0)),"A failed replacement preserves the exact slot, party and inspected pet")
 await click(hub.change_pet_button);game.settings_path="user://missing-pet-flow-folder/settings.cfg";await click(hub.party[1].get_node("RemovePet"));game.settings_path=path
 check(game.settings.forest_pet_loadout==replaced and hub.selected_pet_slot==0 and not hub.status.text.is_empty(),"A failed removal preserves the selected pet")
 for dimensions in [Vector2i(1280,800),Vector2i(960,640)]:
  root.size=dimensions;await frames();fit(hub)
  check(hub.panel.get_node("EquippedItemsFrame").get_global_rect().encloses(hub.change_pet_button.get_global_rect()),"Change pet fits its equipment frame")
  var left_panel:Rect2=hub.panel.get_node("EquippedItemsFrame").get_global_rect()
  check(left_panel.encloses(hub.pet_name_field.get_global_rect()) and left_panel.encloses(hub.save_pet_name_button.get_global_rect()),"Pet name and Save fit the left Equipment panel")
  for i in range(1,5):
   var slot:Rect2=hub.party[i].get_global_rect();var cross:Rect2=hub.party[i].get_node("RemovePet").get_global_rect()
   check(slot.encloses(cross) and cross.position.x>slot.get_center().x and cross.end.y<slot.get_center().y,"The cross fits in the upper-right corner of the pet slot")
 await capture("pet-stats-small")
 root.size=Vector2i(1280,800);await frames();hub.enter_map();await frames()
 var army=game.army_runtime;p.position=Vector3(-150,game.model.surface_height(-150,127),127)
 game.update_character_tuning(p.character_id,"dodge_chance",85)
 p.active_ability.kagerou_enabled=false;p.model.clear_kagerou_dodge();p.invuln=0;game.tuning.invincible=false
 check(p.effective_dodge_chance()==100.0,"Bee dodge caps at 100%")
 var player_hp=p.hp
 for i in 3:
  p.take_hit(1.0,Vector3.BACK)
  check(p.hp==player_hp and p.model.kagerou_tick==0,"Bee dodge avoids an actual incoming hit")
  p.model.clear_kagerou_dodge()
 game.update_character_tuning(p.character_id,"dodge_chance",base_dodge);p.model.clear_kagerou_dodge()
 army.queue_hounds()
 for i in 80:
  army.integration_tick(1.0/60);army.flush_presentation()
  if army.pending_hounds.is_empty():break
 var handle:int=army.handles.get(army.HOUND_ID,0)
 check(handle!=0,"The selected pet arrives through the existing native owner")
 if handle!=0:
  var native_pet=army.unit_state(handle)
  check(native_pet.mana==50 and native_pet.max_mana==50 and native_pet.dodge_chance==0 and native_pet.counter_chance==0,"Native pet starts with 50 mana and zero reaction chances")
  army.apply_hit(handle,{"amount":30.0});var wounded=army.unit_state(handle).hp
  key(KEY_Q);await frames();hub=game.equipment_hub;await click(hub.party[1])
  check(hub.stats.pet_profile.summoned and is_equal_approx(hub.stats.pet_profile.hp,wounded) and is_equal_approx(hub.stats.pet_health_bar.value,wounded),"The right panel displays the actual wounded native pet")
  check(hub.stats.pet_mana.text=="50 / 50" and hub.stats.pet_mana_bar.value==50,"Pet panel displays live native mana")
  hub.pet_name_field.text="Flint";await click(hub.save_pet_name_button)
  check(hub.stats.name_label.text=="Flint" and army.handles.get(army.HOUND_ID)==handle and is_equal_approx(army.unit_state(handle).hp,wounded),"Renaming a living pet preserves its native handle and wounds")
  await capture("pet-live-health")
  hub.show_page("skills");await click(hub.skill_buttons.equip)
  check(hub.skill_levels.equip.text=="Lv4" and hub.stats.pet_summary_levels[0].text=="Lv 4" and xp.stat_points==points,"The equipped slot and right panel show the pet's learned level during inspection")
  var crowned="ex:1102"
  await click(hub.party[2]);await click(hub.change_pet_button);await choose_pet(Pets.skin(crowned))
  check(game.settings.forest_pet_loadout[1]==crowned and army.handles.get(army.HOUND_ID)==handle and is_equal_approx(army.unit_state(handle).hp,wounded),"Equipping the crowned rabbit preserves another pet's native handle and wounds")
  hub.select_owner(0);check(hub.stats.overview_content.visible and hub.stats.tabs[0].visible and not hub.stats.pet_stats_content.visible,"Returning to the character restores its combat stats")
  await click(hub.stats.tabs[1]);await click(hub.party[1]);hub.select_owner(0)
  check(hub.stats.character_stats_content.visible and hub.stats.tabs[1].button_pressed,"Switching owners remembers the character's Upgrades tab")
  await click(hub.party[1]);await frames(5)
  var nodes=int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT));var resources=int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT))
  for i in 40:hub.select_owner(i%hub.owners.size())
  check(int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))==nodes and int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT))==resources,"Switching character and pet stats reuses controls/resources")
  await click(hub.party[4].get_node("RemovePet"))
  check(is_equal_approx(p.effective_dodge_chance(),base_dodge+10),"Removing a bee subtracts its bonus immediately")
  key(KEY_ESCAPE);await frames();check(not is_instance_valid(game.equipment_hub) and not game.paused,"Equipment still returns to the running battle")
 game.sound_library.cancel();game.music.stop();game.queue_free();paused=false;await frames(5);DirAccess.remove_absolute(ProjectSettings.globalize_path(cfg))
 print("PET_EQUIPMENT_FLOW_RESULT checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)
