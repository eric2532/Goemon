extends "res://tests/forest-shrine/shin_sword_rush_test.gd"
const CYCLE_OUT="res://build/Other Files/Asset Toolkit/Shin Water Dragon/Primary Cycle/"

func cycle_capture(stem:String):
 if DisplayServer.get_name()=="headless":return
 await RenderingServer.frame_post_draw
 check(root.get_texture().get_image().save_png(CYCLE_OUT+stem+".png")==OK,"Captured "+stem)

func cycle_heard(after:int,kind:String)->Array:
 var result=[]
 for voice in game.voices:
  if int(voice.get_meta("order",-1))>after and voice.get_meta("kind")==kind:result.append(voice.stream)
 return result

func run():
 create_timer(240).timeout.connect(func():printerr("WATER_PRIMARY_CYCLE_TIMEOUT");quit(1))
 DirAccess.make_dir_recursive_absolute(CYCLE_OUT);root.size=Vector2i(1280,800)
 var doc=load("res://scripts/forest/forest_map_document.gd").new();doc.load_wind_meadow();await setup_fixture(doc.data)
 game.set_process(false);game.army_runtime.set_process(false);game.army_runtime.set_physics_process(false)
 game.music.stop();game.settings.forest_pet_loadout=[];game.settings.gear_loadouts={}
 game.model.waves.crossgate_pet_test=true;game.model.waves.patrol_posts.clear()
 game.training_dummy.position=home+Vector3.DOWN*1000
 root.gui_release_focus();game.set_process_input(false);game.set_process_unhandled_input(false)
 driver=load("res://tests/forest-shrine/physics_step_driver.gd").new();root.add_child(driver)
 home.y=game.model.surface_height(home.x,home.z)+.05;game.model.update_vision(home)
 await settle(37);game.select_shin_skin(37,900050)
 var p=game.player;var model=p.model;var kit=p.active_ability
 var gear=preload("res://scripts/forest/equipment.gd")
 p.timed_dodge.shadow_counter_enabled=false
 var target=place_target(kit.melee_visual_reach()*.65)
 await aim_sword(target)
 check(model.weapon_combo_clips.is_empty(),"Ordinary sword does not prepare the combo")
 for i in 3:
  click_attack()
  check(kit.is_attacking() and model.weapon_combo_step==-1 and model.body_clip(5,"5:0")==model.motions.clips["5:0"],"Ordinary sword stays sword on every click")
  await driver.advance(1,func(_dt):advance(100,false))
 check(game.save_equipment_loadouts({gear.character_key(37):{"1":"weapon:three-weapon"}},{},{}),"Save/equip the separate Three-Weapon Combo item")
 game.load_settings()
 check(gear.equipped(game.settings.gear_loadouts,37)=="weapon:three-weapon","The combo item survives save/reload")
 await aim_sword(target)
 check(model.weapon_combo_clips.size()==3 and model.weapon_combo_next==0,"Water Dragon prepares three existing motions at selection")
 var baseline:Dictionary=model.normal_attack_pattern()
 var reach:float=kit.primary_reach()
 var damage:float=kit.Skills.basic_damage(baseline)*p.damage_multiplier()
 var pages=model.atlases.duplicate();var materials=model.body_materials.duplicate()
 var swings=[];var impacts=[]
 for stage in 3:
  for facing in 8:
   var key_="5:%d"%facing
   var original:Dictionary=model.appearance.clips[key_]
   var attack:Dictionary=model.weapon_combo_clips[stage][key_]
   var audio_source:Dictionary=model.appearance.clips[key_] if stage==0 else model.profile(model.native_root+(["polearm","axe"][stage-1])+"/").clips[key_]
   check(attack.audio_cues==audio_source.audio_cues and model.attack_sound(false,0,attack)!=null and model.single_strike_sound(attack)!=null,"Stage %d facing %d caches its own weapon swing and impact"%[stage,facing])
   if facing==0:
    swings.append(model.attack_sound(false,0,attack));impacts.append(model.single_strike_sound(attack))
   check(attack.duration==original.duration and attack.contact==original.contact and attack.frames.size()==original.frames.size(),"Sword clock retained for stage %d facing %d"%[stage,facing])
   for frame in attack.frames:
    var texture=model.atlases[int(frame[0])]
    check(frame[1]>=0 and frame[2]>=0 and frame[1]+frame[3]<=texture.get_width() and frame[2]+frame[4]<=texture.get_height(),"Borrowed frame fits its cached atlas")
   if stage>0:
    var donor_root=model.native_root+(["polearm","axe"][stage-1])+"/"
    var donor:Dictionary=model.profile(donor_root).clips[key_]
    var contact_frame:Array=attack.frames[floori(float(attack.contact)*attack.frames.size())]
    var donor_frame:Array=donor.frames[floori(float(donor.contact)*donor.frames.size())]
    check(contact_frame.slice(1)==donor_frame.slice(1),"Borrowed contact pose aligns to sword contact for stage %d facing %d"%[stage,facing])
 check(swings[0]!=swings[1] and swings[1]!=swings[2] and swings[0]!=swings[2] and impacts[0]!=impacts[1] and impacts[1]!=impacts[2] and impacts[0]!=impacts[2],"All three weapons have distinct existing swing and ice-impact samples")
 for swing in 6:
  var hp:float=target.hp
  var voice_cursor:int=game.voice_idx
  click_attack()
  check(kit.mode=="attack" and model.weapon_combo_step==swing%3,"Actual left click cycles sword, spear, axe: %d"%swing)
  var next:int=model.weapon_combo_next
  click_attack()
  check(model.weapon_combo_next==next,"Busy clicks cannot skip a motion")
  check(model.current_weapon()=="sword" and is_equal_approx(kit.primary_reach(),reach) and model.normal_attack_pattern().contacts==baseline.contacts,"Motion does not change equipped sword, reach or contacts")
  await driver.advance(1,func(_dt):advance(8,false))
  if swing<3:await cycle_capture("%d-windup"%swing)
  var rate:float=kit.primary_attack_tempo()
  var ticks=maxi(0,ceili((kit.shin_contact-kit.elapsed)/rate/DT))
  await driver.advance(1,func(_dt):advance(ticks,false))
  if swing<3:await cycle_capture("%d-contact"%swing)
  await driver.advance(1,func(_dt):advance(90,false))
  var expected=damage*p.attack_chain.damage_for(kit.ticket)
  check(is_equal_approx(hp-target.hp,expected) and not kit.is_attacking(),"Each motion lands exactly one sword-damage hit: %.2f / %.2f"%[hp-target.hp,expected])
  check(cycle_heard(voice_cursor,"swing")==[swings[swing%3]] and cycle_heard(voice_cursor,"hit")==[impacts[swing%3]],"Actual sword, spear, axe clicks each play their matching swing and confirmed impact")
  check(model.weapon_combo_step==-1,"Recovery clears the temporary motion")
 var next:int=model.weapon_combo_next
 tap("heavy_attack")
 check(not kit.is_attacking() and model.weapon_combo_step==-1 and model.weapon_combo_next==next,"Right click leaves the player's attack and combo stage alone")
 kit.cancel(true)
 click_attack();kit.interrupt_for_dodge()
 check(model.weapon_combo_step==-1,"Dodge interruption clears the temporary pose")
 var nodes=get_node_count();var resources=Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)
 for i in 30:
  click_attack();kit.cancel(true)
 check(model.atlases==pages and model.body_materials==materials and get_node_count()==nodes and Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)<=resources,"Thirty repeated clicks reuse prepared textures/materials without resource growth")
 game.save_equipment_loadouts({gear.character_key(37):{"1":"weapon:axe"}},{},{})
 click_attack()
 check(model.current_weapon()=="axe" and model.weapon_combo_step==-1,"Equipping another weapon keeps its own attack")
 kit.cancel(true)
 game.save_equipment_loadouts({gear.character_key(37):{"1":"weapon:sword"}},{},{})
 for i in 3:
  click_attack();check(model.weapon_combo_step==-1,"Re-equipping ordinary sword disables the cycle");kit.cancel(true)
 game.save_equipment_loadouts({gear.character_key(37):{"1":"weapon:three-weapon"}},{},{})
 check(model.weapon_combo_next==0,"Re-equipping the combo starts a fresh cycle")
 var mirrors=preload("res://scripts/warcraft_mirrors.gd").new(p,0)
 check(mirrors.reinforce(37,home+Vector3.RIGHT*2),"Water Dragon companion uses the existing native owner")
 for body in mirrors.bodies:
  check(body.model.shin_skin==900050 and body.model.weapon_combo_clips.is_empty(),"Native companion retains its equipped sword without player-only combo setup")
  check(body.perform(0,target.global_position) and body.model.weapon_combo_step==-1,"Native companion attacks without advancing the player's cycle")
 mirrors.dispose();await frames(2)
 game.save_equipment_loadouts({gear.character_key(37):{"1":"weapon:sword"}},{},{})
 game.select_shin_skin(37,100050);click_attack()
 check(model.weapon_combo_clips.is_empty() and model.weapon_combo_step==-1,"Original Shin remains unchanged")
 kit.cancel(true)
 game.select_shin_skin(37,900050);game.show_equipment_hub(true);await frames(2)
 var hub=game.equipment_hub
 check("weapon:three-weapon" in hub.available_items(),"Equipment offers the combo separately from Sword")
 hub.auto_equip(hub.available_items().find("weapon:three-weapon"));await frames(2)
 check(model.gear_weapon=="three-weapon" and hub.gear_buttons["1"].get_node("GearIcon").texture==gear.ITEMS["weapon:three-weapon"].icon,"Selecting the combo equips its combined three-weapon icon")
 await cycle_capture("three-weapon-equipment")
 game.back_from_equipment();game.set_physics_process(false);p.set_physics_process(false)
 game.settings.weapon_slot_unlocks={gear.character_key(37):2}
 check(game.save_equipment_loadouts({gear.character_key(37):{"1":"weapon:sword","2":"weapon:three-weapon","active_weapon":"1"}},{},{}),"Sword and combo can be carried as separate items")
 click_attack();check(model.weapon_combo_step==-1,"An inactive carried combo cannot change the active sword");kit.cancel(true)
 p.swap_weapon();click_attack()
 check(model.gear_weapon=="three-weapon" and model.weapon_combo_step==0,"Cycling selects the separately carried combo and starts its cycle");kit.cancel(true)
 p.swap_weapon();click_attack()
 check(model.gear_weapon=="sword" and model.weapon_combo_step==-1 and game.settings.gear_loadouts[gear.character_key(37)]["2"]=="weapon:three-weapon","Cycling restores ordinary sword while preserving the carried combo");kit.cancel(true)
 catalog_combo_cases()
 await other_combo_wearers()
 print("WATER_PRIMARY_CYCLE_RESULT checks=%d failures=%d"%[checks,failures])
 game.queue_free();current_scene=null;await frames(3)
 DirAccess.remove_absolute(ProjectSettings.globalize_path(cfg));quit(1 if failures else 0)

func catalog_combo_cases():
 var gear=preload("res://scripts/forest/equipment.gd")
 var compatible=0
 for character_ in gear.catalog():
  var character=int(character_)
  for skin_ in gear.catalog()[character_]:
   var skin=int(skin_)
   var routes:Dictionary=gear.catalog()[character_][skin_]
   var complete=["sword","polearm","axe"].all(func(weapon):return routes.has(weapon))
   check(routes.has("three-weapon")==complete,"Combo availability follows all three native weapon routes")
   if not complete:continue
   compatible+=1
   var native_root="res://assets/characters/crossgate/"+gear.Roster.CROSSGATE[character].get("root","")+"/"
   if gear.Roster.is_shin(character):native_root=gear.Roster.ShinSkins.root(skin)
   elif gear.Roster.has_variant_skins(character):native_root=gear.Roster.skin_root(character,skin)
   var valid=true
   for weapon in ["sword","polearm","axe"]:
    var route:Dictionary=routes[weapon]
    var root_:String=route.get("root",native_root)
    var data:Dictionary=game.player.model.profile(root_)
    var stance:Dictionary=data if route.has("root") or int(route.native)==0 else data.weapons[int(route.native)-1]
    for facing in 8:
     var clip_:Dictionary=stance.clips["5:%d"%facing]
     valid=valid and float(clip_.duration)>0 and not clip_.frames.is_empty() and clip_.has("audio_cues")
     if weapon!="sword":valid=valid and clip_.has("contact") and float(clip_.contact)>=0 and float(clip_.contact)<1
   check(valid,"Compatible look %d/%d has complete eight-facing weapon clips and audio"%[character,skin])
 print("THREE_WEAPON_COMPATIBLE_LOOKS ",compatible)

func other_combo_wearers():
 var gear=preload("res://scripts/forest/equipment.gd")
 for character in game.player.RogueRoster.CROSSGATE:
  var compatible:Array=gear.catalog()[str(character)].keys().filter(func(skin):return gear.catalog()[str(character)][skin].has("three-weapon"))
  if compatible.is_empty():
   check(not gear.sanitized({gear.character_key(character):{"1":"weapon:three-weapon"}}).has(gear.character_key(character)),"Missing weapon animations cannot enable the combo for %d"%character)
   continue
  game.settings.gear_loadouts={};await settle(character)
  var skin=int(compatible[0])
  if character==36:game.select_kaz_skin(preload("res://scripts/kaz_skins.gd").MAZE)
  elif gear.Roster.is_shin(character):game.select_shin_skin(character,skin)
  elif gear.Roster.has_variant_skins(character):game.select_crossgate_skin(character,skin)
  var p=game.player;var model=p.model;var kit=p.active_ability
  check(game.save_equipment_loadouts({gear.character_key(character):{"1":"weapon:sword"}},{},{}),"Equip normal sword for %d"%character)
  var baseline:Dictionary=model.normal_attack_pattern()
  var reach:float=kit.primary_reach()
  check(game.save_equipment_loadouts({gear.character_key(character):{"1":"weapon:three-weapon"}},{},{}),"Equip combo on its own compatible character %d"%character)
  check(model.current_weapon()=="sword" and model.gear_weapon=="three-weapon" and model.weapon_combo_clips.size()==3,"Combo retains sword mechanics and prepares wearer-specific motions for %d"%character)
  check(gear.carried_weapons(game.settings.gear_loadouts,character,game.settings)==["sword"],"Combo retains sword skill requirements for %d"%character)
  var target=place_target(kit.melee_visual_reach()*.55)
  for swing in 3:
   var cursor:int=game.voice_idx
   kit.start_selected_primary(Vector3.FORWARD,target)
   var pattern:Dictionary=model.normal_attack_pattern()
   var attack:Dictionary=pattern.attack
   var expected_swings=[];var expected_hits=[]
   var count_=1 if model.fighter.strike=="timed" and kit.cut_times.is_empty() else maxi(1,kit.sound_cues.size())
   for i in count_:expected_swings.append(model.attack_sound(false,i,attack))
   for i in baseline.contacts.size():expected_hits.append(model.attack_sound(true,i,attack))
   check(model.weapon_combo_step==swing and pattern.contacts==baseline.contacts and is_equal_approx(kit.primary_reach(),reach),"Wearer %d stage %d keeps its native sword contacts and reach"%[character,swing])
   for facing in 8:
    var clip_:Dictionary=model.weapon_combo_clips[swing]["5:%d"%facing]
    check(clip_.frames.all(func(frame):return int(frame[0])<model.atlases.size()),"Wearer-specific facing uses its cached atlas")
   var before:float=target.hp
   var sounded=[];var impacts=[]
   for tick in ceili(float(pattern.duration)/p.attack_speed_multiplier()/DT)+10:
    kit.tick(DT)
    sounded.append_array(cycle_heard(cursor,"swing"));impacts.append_array(cycle_heard(cursor,"hit"));cursor=game.voice_idx
   check(sounded.size()==expected_swings.size() and sounded.all(func(sample):return sample in expected_swings) and impacts.size()==expected_hits.size() and impacts.all(func(sample):return sample in expected_hits),"Wearer %d stage %d plays its own weapon sounds"%[character,swing])
   check(target.hp<before and not kit.is_attacking() and model.weapon_combo_step==-1,"Wearer %d stage %d hits and cleans up"%[character,swing])
  game.save_equipment_loadouts({gear.character_key(character):{"1":"weapon:sword"}},{},{})
  kit.start_selected_primary(Vector3.FORWARD,target)
  check(model.weapon_combo_step==-1,"Ordinary sword restored for wearer %d"%character);kit.cancel(true)
  if character==38:
   game.save_equipment_loadouts({gear.character_key(character):{"1":"weapon:three-weapon"}},{},{})
   game.select_shin_skin(character,118993)
   check(model.gear_weapon.is_empty() and model.weapon_combo_clips.is_empty() and gear.equipped(game.settings.gear_loadouts,character)=="weapon:three-weapon","A look missing weapon animations keeps its own art and preserves the saved combo choice")
   game.select_shin_skin(character,skin)
   check(model.gear_weapon=="three-weapon" and model.weapon_combo_clips.size()==3,"Returning to a compatible look restores the saved combo")
  if character in [35,36,37,48]:
   game.save_equipment_loadouts({gear.character_key(character):{"1":"weapon:three-weapon"}},{},{})
   kit.start_selected_primary(Vector3.FORWARD,target);kit.tick(kit.duration*.3)
   model.show_pose(5,kit.elapsed,false);await cycle_capture("wearer-%d"%character);kit.cancel(true)
