extends "res://tests/forest-shrine/weapon_equipment_test.gd"

const Special=preload("res://scripts/crossgate_special_skins.gd")
const Mirrors=preload("res://scripts/warcraft_mirrors.gd")
const SPECIAL_OUT="res://build/Other Files/Asset Toolkit/Character Pet Variants/Gameplay/"

func special_picture(stem:String):
 if DisplayServer.get_name()=="headless":return
 game.camera_rig.camera.h_offset=0;game.camera_rig.camera.v_offset=0
 game.camera_rig.camera.global_position=home+Vector3(8,7,15);game.camera_rig.camera.look_at(home+Vector3.UP*1.4)
 await frames(2);await RenderingServer.frame_post_draw
 check(root.get_texture().get_image().save_png(SPECIAL_OUT+stem+".png")==OK,"Rendered "+stem)

func run():
 create_timer(600).timeout.connect(func():printerr("SPECIAL_SKINS_TIMEOUT");quit(1))
 DirAccess.make_dir_recursive_absolute(SPECIAL_OUT);root.size=Vector2i(1280,800);root.set_flag(Window.FLAG_NO_FOCUS,true)
 game=load("res://scenes/forest_title.tscn").instantiate();game.settings_path=cfg;root.add_child(game);current_scene=game;await frames(3)
 game.set_process(false);game.set_physics_process(false);game.player.set_physics_process(false)
 game.army_runtime.set_process(false);game.army_runtime.set_physics_process(false);game.camera_rig.set_process(false)
 var p=game.player
 var roster=Gear.Roster.selection_ids().duplicate()
 game.settings.forest_pet_loadout=[];game.settings.disable_character_cooldowns=false;game.save_settings()
 game.begin_arena();game.choose_rogue_character(47);await frames(3)
 game.equipment_hub.enter_button.pressed.emit();await frames(3)
 home=Vector3(40,0,60);home.y=game.model.surface_height(home.x,home.z)+.05
 game.model.team_progression.cards_enabled=false;game.model.waves.patrol_posts.clear();game.model.waves.crossgate_pet_test=true
 if is_instance_valid(game.training_dummy):game.training_dummy.position=home+Vector3.DOWN*1000
 game.camera_rig.camera.global_position=home+Vector3(8,7,15);game.camera_rig.camera.look_at(home+Vector3.UP*1.4)
 var pool=Pool.service(game)
 pool.launched.connect(func(shot):weapon_shots.append(shot);shot.set_physics_process(false))
 game.impact_confirmed.connect(func(target,_strength,_time):weapon_hits.append(target))
 check(Gear.Roster.loadout_key(35,game.settings)=="35","Original Uru retains the existing saved loadout and painted head key")
 var skins=0;var combinations=0;var warm_costs=[]
 for character in Special.CATALOG:
  p.select_character(character)
  var original=Gear.Roster.selected_skin(character,game.settings)
  for skin in Special.CATALOG[character]:
   choose_skin(character,skin);skins+=1
   var visual=p.model
   var manifest:Dictionary=visual.appearance
   check(Gear.Roster.skin_catalog(character).has(skin) and str(Gear.Roster.skin_catalog(character)[skin][0]).begins_with("Special · "),"Special skin remains in its original character gallery")
   check(manifest.id==skin and visual.character==character,"Special skin changes appearance without creating a character")
   var choices=Gear.allowed(character,game.settings)
   check(choices.keys()==manifest.source_weapons.keys(),"Only the exact supplied source weapons are available")
   check(game.forest_ui.PaintedHeads.portrait(character,game.settings)!=null,"Special skin has a prepared HUD head")
   check(Gear.Roster.selected_skin(character,game.settings)==skin,"Special selection uses the existing validated saved setting")
   for weapon in choices:
    equip_weapon(character,weapon);combinations+=1
    check(visual.current_weapon()==weapon and visual.motions.key==manifest.source_weapons[weapon],"Equipped weapon uses the matching original sprite record")
    check(visual.fighter.strike==("bow" if weapon=="bow" else "staff" if character==35 and weapon=="staff" else "timed"),"The shared combat owner follows the selected source weapon")
    if visual.fighter.strike=="timed":check(visual.motions.clips["5:4"].sounds.all(func(cue):return cue.flag<10000 or cue.flag>=20000),"Contact sounds are delivered once by the timed hit owner")
    if weapon=="bow":check(p.active_ability.shin_sound(true)==visual.gear_sounds[int(visual.motions.clips["5:4"].contact_cues[0])],"Bow release uses its prepared original source sample")
    for direction in 8:
     var key="5:%d"%direction;var motion:Dictionary=visual.body_clip(5,key)
     for index in motion.frames.size():
      visual.show_frame(5,key,index)
      check(Rect2(Vector2.ZERO,visual.sprite.texture.get_size()).encloses(visual.sprite.region_rect),"Every original attack frame remains inside its atlas")
    attack_case(character,weapon)
    game.army_runtime.clear();game.model.enemies.clear();game.army_runtime.flush_presentation()
    game.crowd.army.presentation.clear()
    if is_instance_valid(game.native_ink_feedback):game.native_ink_feedback.tick(10.0)
    var attack:Dictionary=visual.body_clip(5,"5:4")
    visual.show_frame(5,"5:4",attack.frames.size()/2)
    await special_picture("weapon-%d-%d-%s"%[character,skin,weapon])
   if choices.size()==1:
    var other="bow" if not choices.has("bow") else "sword"
    check(not Gear.can_equip(Gear.character_key(character),"weapon:"+other,game.settings),"Fixed-weapon skin rejects an invented weapon")
    var saved_gear=game.settings.gear_loadouts.duplicate(true)
    var incompatible=saved_gear.duplicate(true);incompatible[Gear.character_key(character)]={"1":"weapon:"+other}
    check(game.save_equipment_loadouts(incompatible,game.settings.skill_item_loadouts,game.settings.cosmetic_loadouts) and p.model.gear_weapon.is_empty() and p.model.current_weapon()==choices.keys()[0],"A saved weapon from another outfit cannot replace the fixed source weapon")
    check(game.save_equipment_loadouts(saved_gear,game.settings.skill_item_loadouts,game.settings.cosmetic_loadouts),"Restores the previous equipment without deleting other outfit choices")
    p.swap_weapon();check(choices.has(p.model.current_weapon()),"Cycling cannot escape the source weapon restriction")
   else:
    var without_weapon=game.settings.gear_loadouts.duplicate(true);without_weapon.erase(Gear.character_key(character))
    check(game.save_equipment_loadouts(without_weapon,game.settings.skill_item_loadouts,game.settings.cosmetic_loadouts),"Special skin supports its original weapon before equipment is assigned")
    for index in choices.size():
     p.swap_weapon()
     var expected:String=choices.keys()[(index+1)%choices.size()]
     check(p.model.current_weapon()==expected and Gear.equipped(game.settings.gear_loadouts,character)=="weapon:"+expected,"Cycling selects and saves every supplied native weapon")
     game.load_settings();check(p.model.current_weapon()==expected,"A cycled source weapon survives reload")
   var saved=Gear.Roster.selected_skin(character,game.settings)
   game.load_settings();check(Gear.Roster.selected_skin(character,game.settings)==saved,"Special skin survives settings reload")
   p.position=home;p.velocity=Vector3.ZERO
   var mirrors=Mirrors.new(p);mirrors.prepare_count()
   check(mirrors.cast(),"Special skin can summon through the existing native army")
   check(mirrors.bodies.all(func(body):return body.character_id==character and body.model.appearance.id==skin and body.model.current_weapon()==p.model.current_weapon()),"Simultaneous native copies preserve the skin and its actual weapon")
   for i in 12:game.army_runtime.integration_tick(DT);game.army_runtime.flush_presentation()
   mirrors.dispose();await frames(2)
   game.army_runtime.clear();game.model.enemies.clear();game.army_runtime.flush_presentation();p.position=home
   game.crowd.army.presentation.clear()
   if is_instance_valid(game.native_ink_feedback):game.native_ink_feedback.tick(10.0)
   var motion:Dictionary=visual.body_clip(5,"5:4")
   for index in motion.frames.size():
    visual.show_frame(5,"5:4",index)
    if DisplayServer.get_name()!="headless":await create_timer(float(motion.duration)/motion.frames.size()).timeout
    if index in [0,motion.frames.size()/2,motion.frames.size()-1]:await special_picture("%d-%d-%d"%[character,skin,index])
   var start=Time.get_ticks_usec()
   for i in 300:visual.animate(DT,5,true,0,0,false,0,false)
   warm_costs.append(float(Time.get_ticks_usec()-start)/300)
  choose_skin(character,original)
  check(not p.model.appearance.has("source_weapons") and p.model.fighter.strike==Gear.Roster.CROSSGATE[character].strike,"Returning to the original skin restores its original combat style")
 check(skins==15 and combinations==44,"All reviewed special skins and original weapon records were exercised")
 check(Gear.Roster.selection_ids()==roster,"The character roster is unchanged")
 p.select_character(35);choose_skin(35,0);equip_weapon(35,"staff")
 check(not p.model.gear_external and p.model.normal_attack_pattern().contacts.size()==5 and Gear.Roster.loadout_key(35,game.settings)=="35","Original Uru retains her prepared five-contact staff and saved loadout key")
 attack_case(35,"staff")
 p.select_character(47);choose_skin(47,111618);equip_weapon(47,"polearm")
 for i in 20:attack_case(47,"polearm")
 await frames(4)
 var nodes=get_node_count();var resources=Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT);var created=pool.created
 for i in 20:attack_case(47,"polearm")
 await frames(2)
 print("SPECIAL_SKIN_REUSE before_nodes=",nodes," after_nodes=",get_node_count()," before_resources=",resources," after_resources=",Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)," before_pool=",created," after_pool=",pool.created)
 check(get_node_count()==nodes and Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)<=resources and pool.created==created,"Repeated warmed attacks retain nodes/resources and projectile pool size")
 game.show_equipment_hub(true);await frames(2)
 var picker=game.equipment_hub.portrait_button
 check(picker.character==47 and picker.catalog.has(111618),"Cedi's existing character portrait offers the Special 紫夜 skin")
 picker.open_gallery();await special_picture("cedi-special-gallery")
 warm_costs.sort();print("SPECIAL_SKIN_POSE_US median=",warm_costs[warm_costs.size()/2]," max=",warm_costs.back()," (isolated callback; not frame times)")
 print("SPECIAL_SKINS_RESULT checks=%d failures=%d skins=%d weapons=%d"%[checks,failures,skins,combinations])
 game.sound_library.cancel();game.music.stop();game.queue_free();paused=false;await frames(4)
 DirAccess.remove_absolute(ProjectSettings.globalize_path(cfg));quit(1 if failures else 0)
