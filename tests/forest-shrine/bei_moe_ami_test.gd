extends "res://tests/forest-shrine/weapon_equipment_test.gd"

const NEW_CAST={48:23,49:28,50:21,38:14}
const CAST_MIRRORS=preload("res://scripts/warcraft_mirrors.gd")
const CAST_OUT="res://build/Other Files/Asset Toolkit/Bei Moe Ami/Gameplay/"

func check(ok:bool,message:String):
 checks+=1
 if not ok:failures+=1;printerr("FAIL: "+message)

func cast_picture(stem:String):
 if DisplayServer.get_name()=="headless":return
 if game.playing:
  game.camera_rig.camera.h_offset=0;game.camera_rig.camera.v_offset=0
  game.camera_rig.camera.global_position=home+Vector3(8,7,15);game.camera_rig.camera.look_at(home+Vector3.UP*1.4)
 game.forest_ui.sync();await frames(2);await RenderingServer.frame_post_draw
 check(root.get_texture().get_image().save_png(CAST_OUT+stem+".png")==OK,"Rendered "+stem)

func clear_cast_scene():
 game.army_runtime.clear();game.model.enemies.clear();game.army_runtime.flush_presentation()
 game.crowd.army.presentation.clear()
 if is_instance_valid(game.native_ink_feedback):game.native_ink_feedback.clear()
 game.player.position=home;game.player.velocity=Vector3.ZERO

func simultaneous_cast_attacks():
 for spec in [[48,105125,"unarmed"],[49,105275,"unarmed"],[50,105300,"unarmed"],[48,120386,"sword"],[38,120352,"axe"],[38,120382,"unarmed"],[38,120445,"sword"]]:
  clear_cast_scene();game.player.select_character(spec[0]);choose_skin(spec[0],spec[1]);equip_weapon(spec[0],spec[2])
  var at=home+Vector3.FORWARD*1.6;at.y=game.model.surface_height(at.x,at.z)
  var row=game.model.waves.spawn_enemy(Roles.SLIME,at);row.hp=1000000;row.max_hp=row.hp
  game.army_runtime.import_arrivals();game.army_runtime.sync_targets();game.model.update_vision(home)
  var target=game.army_runtime.enemy_target(row.id)
  var mirrors=CAST_MIRRORS.new(game.player,0)
  weapon_hits.clear()
  for index in 5:
   check(mirrors.reinforce(spec[0],home+Vector3((index-2)*.2,0,0)),"Focused simultaneous copy uses native lifecycle")
   var body=mirrors.bodies[index]
   body.ai_target=target
   check(body.model.current_weapon()==spec[2] and body.perform(0,at),"Native copy starts the selected source attack")
  for tick in 100:
   for body in mirrors.bodies:body.step(DT,{"position":body.position,"hp":body.max_hp,"yaw":0.0,"pose_velocity":Vector3.ZERO})
   if tick==40:await cast_picture("five-attacking-%d-%d"%[spec[0],spec[1]])
  check(weapon_hits.count(target)==5 and mirrors.bodies.all(func(body):return not body.has_offensive_action()),"Five simultaneous recovered attacks each hit once and finish")
  print("CAST_SIMULTANEOUS character=",spec[0]," skin=",spec[1]," hits=",weapon_hits.count(target))
  mirrors.dispose();await frames(3)
 clear_cast_scene()

func run():
 create_timer(1200).timeout.connect(func():printerr("BEI_MOE_AMI_TIMEOUT");quit(1))
 DirAccess.make_dir_recursive_absolute(CAST_OUT);root.size=Vector2i(1280,800);root.set_flag(Window.FLAG_NO_FOCUS,true)
 game=load("res://scenes/forest_title.tscn").instantiate();game.settings_path=cfg;root.add_child(game);current_scene=game;await frames(3)
 game.set_process(false);game.set_physics_process(false);game.player.set_physics_process(false)
 game.army_runtime.set_process(false);game.army_runtime.set_physics_process(false);game.camera_rig.set_process(false)
 game.settings.forest_pet_loadout=[];game.settings.disable_character_cooldowns=false;game.save_settings()
 game.begin_arena()
 for character in NEW_CAST:
  check(Gear.Roster.selection_ids().has(character) and Gear.Roster.sound_ids().has(character),"New identity is selectable and appears in Sound Studio")
  var card=game.menu.find_child("RogueFighter_"+Gear.Roster.CROSSGATE[character].id,true,false)
  check(card!=null,"The real roster has a new-character card")
 game.choose_rogue_character(48);await frames(3)
 check(game.equipment_hub!=null,"New character opens the existing Equipment flow")
 await cast_picture("bei-equipment")
 game.equipment_hub.enter_button.pressed.emit();await frames(3)
 var p=game.player
 home=Vector3(40,0,60);home.y=game.model.surface_height(home.x,home.z)+.05
 game.model.team_progression.cards_enabled=false;game.model.waves.patrol_posts.clear();game.model.waves.crossgate_pet_test=true
 if is_instance_valid(game.training_dummy):game.training_dummy.position=home+Vector3.DOWN*1000
 game.camera_rig.camera.h_offset=0;game.camera_rig.camera.v_offset=0
 game.camera_rig.camera.global_position=home+Vector3(8,7,15);game.camera_rig.camera.look_at(home+Vector3.UP*1.4)
 var pool=Pool.service(game)
 pool.launched.connect(func(shot):weapon_shots.append(shot);shot.set_physics_process(false))
 game.impact_confirmed.connect(func(target,_strength,_time):weapon_hits.append(target))
 var appearances=0;var combinations=0;var samples=[]
 for character in NEW_CAST:
  p.select_character(character)
  var visual=p.model;var catalog=preload("res://scripts/crossgate_special_skins.gd").CAST_CATALOG[character]
  check(catalog.size()==NEW_CAST[character],"All inventoried colors, remodels and specials are present")
  check(visual.get_script()==preload("res://scripts/crossgate_model.gd") and p.active_ability.get_script()==preload("res://scripts/crossgate_combat.gd"),"New hero reuses shared model and combat")
  if character!=38:check(SoundLibrary.original_for(character,"step")==SoundLibrary.GOEMON_FOOTSTEP and SoundLibrary.original_for(character,"land")==SoundLibrary.HUMANOID_LANDING,"Prepared Goemon footstep and landing remain the defaults")
  for skin in catalog:
   choose_skin(character,skin);appearances+=1
   var choices=Gear.allowed(character,game.settings)
   var source_weapons:Dictionary=visual.profile(visual.native_root).source_weapons
   check(p.model==visual and visual.appearance.id==skin,"Skin changes the same existing model")
   if character==38:check(visual.body_height_pixels==80,"Shin 2.0 body scale excludes its weapon and aura")
   check(choices.has("beast-master") and source_weapons.keys().all(func(weapon):return choices.has(weapon)),"The supplied weapons and Beast Master are offered")
   game.forest_ui.sync_character()
   check(game.forest_ui.hero_portrait.texture==game.forest_ui.PaintedHeads.portrait(character,game.settings) and game.forest_ui.hero_portrait.texture!=null,"Original model head follows the selected skin")
   for weapon in source_weapons:
    equip_weapon(character,weapon);combinations+=1
    check(visual.current_weapon()==weapon and visual.motions.key==source_weapons[weapon],"Weapon keeps its exact source record despite numeric ID collisions")
    for direction in 8:
     var motion:Dictionary=visual.body_clip(5,"5:%d"%direction)
     check(motion.duration>0 and motion.contacts.all(func(at):return at>=0 and at<motion.duration),"Original contact clock is bounded")
     for index in motion.frames.size():
      visual.show_frame(5,"5:%d"%direction,index)
      check(Rect2(Vector2.ZERO,visual.sprite.texture.get_size()).encloses(visual.sprite.region_rect),"Every attack frame fits its original atlas")
    attack_case(character,weapon)
   clear_cast_scene()
   var no_gear=game.settings.gear_loadouts.duplicate(true);no_gear.erase(Gear.character_key(character))
   check(game.save_equipment_loadouts(no_gear,game.settings.skill_item_loadouts,game.settings.cosmetic_loadouts),"Skin can use its native weapon without carried equipment")
   for index in choices.size():
    p.swap_weapon()
    check(visual.gear_weapon==choices.keys()[(index+1)%choices.size()],"Cycling visits each available weapon")
   game.load_settings()
   check(Gear.Roster.selected_skin(character,game.settings)==skin and choices.has(visual.current_weapon()),"Skin and weapon survive reload")
   p.position=home;p.velocity=Vector3.ZERO
   var mirrors=CAST_MIRRORS.new(p);mirrors.prepare_count()
   check(mirrors.cast(),"Appearance summons through the native army")
   check(mirrors.bodies.all(func(body):return body.character_id==character and (body.model.shin_skin if character==38 else body.model.variant_skin)==skin and body.model.current_weapon()==visual.current_weapon() and body.model.atlases[0]==visual.atlases[0]),"All native copies retain the selected skin and weapon and share its atlas")
   for i in 12:game.army_runtime.integration_tick(DT);game.army_runtime.flush_presentation()
   mirrors.dispose();await frames(2);clear_cast_scene()
   var start=Time.get_ticks_usec()
   for i in 300:visual.animate(DT,5,true,0,0,false,0,false)
   samples.append(float(Time.get_ticks_usec()-start)/300)
   if skin==(Gear.Roster.ShinSkins.SPECIAL_DEFAULT if character==38 else Gear.Roster.CROSSGATE[character].skin_default) or skin in [109876,106708,120110,115258,120386,120352,120382,120445,108312]:
    var weapon:String=choices.keys()[0];equip_weapon(character,weapon)
    var clip_:Dictionary=visual.body_clip(5,"5:4")
    for index in clip_.frames.size():
     visual.show_frame(5,"5:4",index)
     if DisplayServer.get_name()!="headless":
      await create_timer(float(clip_.duration)/clip_.frames.size()).timeout
     if index in [0,clip_.frames.size()/2,clip_.frames.size()-1]:await cast_picture("motion-%d-%d-%d"%[character,skin,index])
  check(visual.body_materials.size()<=visual.atlases.size()+visual.qi_atlas.size()+1,"Current skin retains bounded owned materials")
  choose_skin(character,(Gear.Roster.ShinSkins.SPECIAL_DEFAULT if character==38 else Gear.Roster.CROSSGATE[character].skin_default))
  game.show_equipment_hub(true);await frames(2)
  var picker=game.equipment_hub.portrait_button
  picker.open_gallery();check(picker.character==character and picker.choices.item_count==Gear.Roster.skin_catalog(character).size(),"Real Equipment gallery exposes every new skin")
  await cast_picture("gallery-%d"%character);picker.gallery.hide();game.equipment_hub.enter_button.pressed.emit();await frames(2)
 check(appearances==86 and combinations==465,"All 86 added appearances and 465 supplied weapon combinations exercised")
 for spec in [[48,109876,"unarmed"],[49,106708,"sword"],[49,120110,"staff"],[50,115258,"sword"],[48,120386,"sword"],[38,108312,"polearm"],[38,120382,"unarmed"],[38,120383,"unarmed"],[38,120445,"sword"]]:
  p.select_character(spec[0]);choose_skin(spec[0],spec[1])
  var supported:Array=[spec[2]]
  if spec[1] in [120382,120383]:supported.append("boomerang")
  supported.append("beast-master")
  check(Gear.allowed(spec[0],game.settings).keys()==supported,"Fixed pet/effect appearance offers its prepared weapons and Beast Master")
 await simultaneous_cast_attacks()
 p.select_character(38)
 for skin in Gear.Roster.ShinSkins.HIDDEN_CLASSIC:
  choose_skin(38,skin);game.load_settings()
  check(p.model.shin_skin==skin and Gear.Roster.selected_skin(38,game.settings)==skin and not Gear.Roster.skin_catalog(38).has(skin),"Hidden classic Shin saves remain readable after gallery expansion")
 p.select_character(50);choose_skin(50,105300);equip_weapon(50,"unarmed")
 for i in 20:attack_case(50,"unarmed")
 await frames(3)
 var nodes=get_node_count();var resources=Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT);var created=pool.created
 for i in 20:attack_case(50,"unarmed")
 await frames(3)
 print("BEI_MOE_AMI_REUSE nodes=",nodes,"/",get_node_count()," resources=",resources,"/",Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)," projectiles=",created,"/",pool.created)
 check(get_node_count()<=nodes and Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)<=resources and pool.created==created,"Warmed repeated attacks add no retained nodes, resources or projectile capacity")
 if DisplayServer.get_name()!="headless":
  var timings=[]
  for spec in [[44,106025,"unarmed"],[48,105125,"unarmed"],[49,105275,"unarmed"],[50,105300,"unarmed"],[48,120386,"sword"],[38,120352,"axe"],[38,120445,"sword"]]:
   var character:int=spec[0]
   p.select_character(character);choose_skin(character,spec[1]);equip_weapon(character,spec[2])
   attack_case(character,spec[2]);p.position=home
   game.camera_rig.camera.h_offset=0;game.camera_rig.camera.v_offset=0
   game.camera_rig.camera.global_position=home+Vector3(8,7,15);game.camera_rig.camera.look_at(home+Vector3.UP*1.4)
   var mirrors=CAST_MIRRORS.new(p);mirrors.prepare_count();check(mirrors.cast(),"Frame sample has five native copies")
   var intervals=[];var previous=Time.get_ticks_usec()
   for tick in 150:
    p.active_ability.tick(DT);p.model.animate(DT,5,true,0,0,false,0,false)
    game.army_runtime.integration_tick(DT);game.army_runtime.flush_presentation()
    await process_frame
    var now=Time.get_ticks_usec()
    if tick>=30:intervals.append(float(now-previous)/1000)
    previous=now
   intervals.sort()
   timings.append({"character":character,"skin":spec[1],"median_ms":intervals[60],"p95_ms":intervals[114],"max_ms":intervals.back()})
   mirrors.dispose();await frames(2);clear_cast_scene()
  var timing_file=FileAccess.open(CAST_OUT+"frame-samples.json",FileAccess.WRITE);timing_file.store_string(JSON.stringify(timings,"  "));timing_file.close()
  print("BEI_MOE_AMI_FRAMES ",JSON.stringify(timings)," (focused hero + five native copies + one enemy; not a full-army benchmark)")
 samples.sort();print("BEI_MOE_AMI_POSE_US median=",samples[samples.size()/2]," max=",samples.back()," (isolated pose callback, not rendered frame times)")
 print("BEI_MOE_AMI_RESULT checks=%d failures=%d appearances=%d weapons=%d"%[checks,failures,appearances,combinations])
 game.sound_library.cancel();game.music.stop();game.queue_free();paused=false;await frames(4)
 DirAccess.remove_absolute(ProjectSettings.globalize_path(cfg));quit(1 if failures else 0)
