extends "res://tests/forest-shrine/weapon_equipment_test.gd"

const CAST_OUT="res://build/Other Files/Asset Toolkit/Bau El Gen Sarah/Gameplay/"
const CAST={52:19,53:17,54:18,55:21}

func cast_picture(stem:String):
 if DisplayServer.get_name()=="headless":return
 game.forest_ui.sync();await frames(2);await RenderingServer.frame_post_draw
 check(root.get_texture().get_image().save_png(CAST_OUT+stem+".png")==OK,"Rendered "+stem)

func run():
 create_timer(900).timeout.connect(func():printerr("FOUR_CAST_TIMEOUT");quit(1))
 DirAccess.make_dir_recursive_absolute(CAST_OUT);root.size=Vector2i(1280,800);root.set_flag(Window.FLAG_NO_FOCUS,true)
 game=load("res://scenes/forest_title.tscn").instantiate();game.settings_path=cfg;root.add_child(game);current_scene=game;await frames(3)
 game.set_process(false);game.set_physics_process(false);game.player.set_physics_process(false)
 game.army_runtime.set_process(false);game.army_runtime.set_physics_process(false);game.camera_rig.set_process(false)
 game.settings.forest_pet_loadout=[];game.settings.disable_character_cooldowns=false;game.save_settings()
 var p=game.player
 game.begin_arena();game.choose_rogue_character(52);await frames(3)
 check(game.equipment_hub!=null,"Bau opens the existing Equipment flow")
 game.equipment_hub.enter_button.pressed.emit();await frames(3)
 home.y=game.model.world_height(home.x,home.z)+.15
 game.model.team_progression.cards_enabled=false;game.model.waves.crossgate_pet_test=true
 if is_instance_valid(game.training_dummy):game.training_dummy.home=home+Vector3.DOWN*1000;game.training_dummy.position=game.training_dummy.home
 game.camera_rig.camera.global_position=home+Vector3(8,7,15);game.camera_rig.camera.look_at(home+Vector3(0,2,-4))
 var pool=Pool.service(game)
 pool.launched.connect(func(shot):weapon_shots.append(shot);shot.set_physics_process(false))
 game.impact_confirmed.connect(func(target,_strength,_time):weapon_hits.append(target))
 check(not Gear.Roster.skin_catalog(52).has(115257) and not Gear.Roster.skin_catalog(52).has(124999),"Gen-family special skins stay out of Bau's gallery")
 check(Gear.Roster.skin_catalog(54).has(115257) and Gear.Roster.skin_catalog(54).has(124999),"Gen offers both original special skins")
 check(Gear.Roster.SARAH.skins.has(111676) and Gear.Roster.SARAH.skins.has(120447),"Sarah's special source effect skins are selectable")
 var combinations=0;var appearances=0;var pose_samples=[]
 for character in CAST:
  p.select_character(character)
  var visual=p.model
  check(Gear.Roster.selection_ids().has(character) and Gear.Roster.skin_catalog(character).size()==CAST[character],"Selectable %s has every inventoried appearance"%Gear.Roster.name_for(character))
  check(SoundLibrary.original_for(character,"step")==SoundLibrary.GOEMON_FOOTSTEP and SoundLibrary.original_for(character,"land")==SoundLibrary.HUMANOID_LANDING,"New character uses prepared Goemon step/landing defaults")
  check(visual.get_script()==preload("res://scripts/crossgate_model.gd") and p.active_ability.get_script()==preload("res://scripts/crossgate_combat.gd"),"Character reuses the shared Cross Gate owners")
  for skin in Gear.Roster.skin_catalog(character):
   choose_skin(character,skin);appearances+=1
   check(p.model==visual and visual.variant_skin==skin and visual.profile(visual.native_root).id==skin,"Skin %d changes the same prepared model"%skin)
   check(visual.body_materials.size()<=visual.atlases.size()+visual.qi_atlas.size()+1,"Skin materials remain bounded to current artwork")
   game.forest_ui.sync_character()
   check(game.forest_ui.hero_portrait.texture==game.forest_ui.PaintedHeads.portrait(character,game.settings),"Skin %d has its own matching HUD route"%skin)
   for weapon in Gear.allowed(character,game.settings):
    if weapon=="three-weapon":continue
    equip_weapon(character,weapon);combinations+=1
    check(visual.current_weapon()==weapon,"Skin %d equips its recovered %s"%[skin,weapon])
    for direction in 8:
     var key="5:%d"%direction;var motion:Dictionary=visual.body_clip(5,key)
     check(motion.has("audio_cues") and visual.attack_sound(false,0,motion)!=null and visual.attack_sound(true,0,motion)!=null,"Every weapon facing resolves its cached source swing and impact audio")
     for index in [0,motion.frames.size()/2,motion.frames.size()-1]:
      visual.show_frame(5,key,int(index))
      check(Rect2(Vector2.ZERO,visual.sprite.texture.get_size()).encloses(visual.sprite.region_rect),"Original weapon atlas bounds %d %s facing %d"%[skin,weapon,direction])
    game.update_character_tuning(character,"accuracy",100)
    attack_case(character,weapon)
   var started=Time.get_ticks_usec()
   for i in 300:visual.animate(DT,5,true,0,0,false,0,false)
   pose_samples.append(float(Time.get_ticks_usec()-started)/300.0)
   if skin==Gear.Roster.CROSSGATE[character].skin_default or skin in [115257,111676,120447,124999]:
    equip_weapon(character,str(visual.profile(visual.native_root).weapon))
    game.show_rogue_roster();await frames(2)
    var card=game.menu.find_child("RogueFighter_"+Gear.Roster.CROSSGATE[character].id,true,false)
    check(card!=null,"The selected character has a gallery card")
    await cast_picture("gallery-%d-%d"%[character,skin]);game.close_rogue_roster()
    p.position=home;p.velocity=Vector3.ZERO
    game.camera_rig.camera.global_position=home+Vector3(8,9,17)
    game.camera_rig.camera.look_at(home+Vector3.UP*1.8)
    game.army_runtime.clear();game.model.enemies.clear();game.army_runtime.flush_presentation()
    var attack:Dictionary=visual.body_clip(5,"5:4")
    for index in attack.frames.size():
     visual.show_frame(5,"5:4",index)
     if DisplayServer.get_name()!="headless":await create_timer(float(attack.duration)/attack.frames.size()).timeout
     await cast_picture("swing-%d-%d-%d"%[character,skin,index])
   await frames(1)
  var last_skin:int=Gear.Roster.selected_skin(character,game.settings)
  game.load_settings()
  check(Gear.Roster.selected_skin(character,game.settings)==last_skin,"Selected new-character skin survives reload")
  p.select_character(character);choose_skin(character,Gear.Roster.CROSSGATE[character].skin_default)
 check(appearances==75 and combinations>=400,"All 75 gallery appearances and their available source weapons were exercised")
 p.select_character(54);choose_skin(54,105100);equip_weapon(54,"unarmed");attack_case(54,"unarmed");await frames(3)
 var nodes=get_node_count();var resources=Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT);var created=pool.created
 for i in 20:attack_case(54,"unarmed")
 await frames(2)
 check(get_node_count()==nodes and Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)<=resources and pool.created==created,"Repeated warmed combat retains nodes/resources and projectile pool size")
 if DisplayServer.get_name()!="headless":
  var frame_ms=[]
  for i in 120:
   var started=Time.get_ticks_usec()
   p.model.animate(DT,5,true,0,0,false,0,false)
   await frames(1)
   frame_ms.append(float(Time.get_ticks_usec()-started)/1000.0)
  frame_ms.sort()
  print("FOUR_CAST_RENDERED_FRAME_MS median=",frame_ms[60]," p95=",frame_ms[113]," max=",frame_ms.back()," (isolated warmed scene, not full-army gameplay)")
 pose_samples.sort()
 print("FOUR_CAST_POSE_US median=",pose_samples[pose_samples.size()/2]," max=",pose_samples.back()," (isolated animation callback; not rendered frame times)")
 print("FOUR_CAST_RESULT checks=%d failures=%d appearances=%d weapons=%d"%[checks,failures,appearances,combinations])
 var old_path=game.settings_path;game.sound_library.cancel();game.music.stop();game.queue_free();paused=false;await frames(4)
 DirAccess.remove_absolute(ProjectSettings.globalize_path(old_path));quit(1 if failures else 0)
