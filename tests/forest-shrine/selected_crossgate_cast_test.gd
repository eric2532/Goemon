extends "res://tests/forest-shrine/weapon_equipment_test.gd"

const CAST_OUT="res://build/Other Files/Asset Toolkit/Pete Grace Rei Cedi/Gameplay/"
const CAST={44:17,45:11,46:17,47:14}
const Mirrors=preload("res://scripts/warcraft_mirrors.gd")

func cast_picture(stem:String):
 if DisplayServer.get_name()=="headless":return
 game.forest_ui.sync();await frames(2);await RenderingServer.frame_post_draw
 check(root.get_texture().get_image().save_png(CAST_OUT+stem+".png")==OK,"Rendered "+stem)

func run():
 create_timer(900).timeout.connect(func():printerr("SELECTED_CAST_TIMEOUT");quit(1))
 DirAccess.make_dir_recursive_absolute(CAST_OUT);root.size=Vector2i(1280,800);root.set_flag(Window.FLAG_NO_FOCUS,true)
 game=load("res://scenes/forest_title.tscn").instantiate();game.settings_path=cfg;root.add_child(game);current_scene=game;await frames(3)
 game.set_process(false);game.set_physics_process(false);game.player.set_physics_process(false)
 game.army_runtime.set_process(false);game.army_runtime.set_physics_process(false);game.camera_rig.set_process(false)
 game.settings.forest_pet_loadout=[];game.settings.disable_character_cooldowns=false;game.save_settings()
 var p=game.player
 game.begin_arena();game.choose_rogue_character(44);await frames(3)
 check(game.equipment_hub!=null,"Pete opens the existing Equipment flow")
 game.equipment_hub.enter_button.pressed.emit();await frames(3)
 home.y=game.model.world_height(home.x,home.z)+.15
 game.model.team_progression.cards_enabled=false;game.model.waves.crossgate_pet_test=true
 if is_instance_valid(game.training_dummy):game.training_dummy.home=home+Vector3.DOWN*1000;game.training_dummy.position=game.training_dummy.home
 game.camera_rig.camera.global_position=home+Vector3(8,7,15);game.camera_rig.camera.look_at(home+Vector3(0,2,-4))
 var pool=Pool.service(game)
 pool.launched.connect(func(shot):weapon_shots.append(shot);shot.set_physics_process(false))
 game.impact_confirmed.connect(func(target,_strength,_time):weapon_hits.append(target))
 check(Gear.Roster.GRACE.skins.has(106234),"Grace includes the requested 106234 appearance")
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
    equip_weapon(character,weapon);combinations+=1
    check(visual.current_weapon()==weapon,"Skin %d equips its recovered %s"%[skin,weapon])
    for direction in 8:
     var key="5:%d"%direction;var motion:Dictionary=visual.body_clip(5,key)
     for index in [0,motion.frames.size()/2,motion.frames.size()-1]:
      visual.show_frame(5,key,int(index))
      check(Rect2(Vector2.ZERO,visual.sprite.texture.get_size()).encloses(visual.sprite.region_rect),"Original weapon atlas bounds %d %s facing %d"%[skin,weapon,direction])
    attack_case(character,weapon)
   var started=Time.get_ticks_usec()
   for i in 300:visual.animate(DT,5,true,0,0,false,0,false)
   pose_samples.append(float(Time.get_ticks_usec()-started)/300.0)
   if skin==Gear.Roster.CROSSGATE[character].skin_default or skin==106234:
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
     if index in [0,attack.frames.size()/2,attack.frames.size()-1]:await cast_picture("swing-%d-%d-%d"%[character,skin,index])
   await frames(1)
  var last_skin:int=Gear.Roster.selected_skin(character,game.settings)
  game.load_settings()
  check(Gear.Roster.selected_skin(character,game.settings)==last_skin,"Selected new-character skin survives reload")
  p.select_character(character);choose_skin(character,Gear.Roster.CROSSGATE[character].skin_default)
  equip_weapon(character,"unarmed")
  var mirrors=Mirrors.new(p)
  mirrors.prepare_count()
  p.position=home;p.velocity=Vector3.DOWN;p.move_and_slide()
  print("CAST_SUMMON_FIXTURE character=",character," bodies=",mirrors.bodies.size()," required=",mirrors.required_count()," home=",home," surface=",game.model.surface_height(home.x,home.z)," clear=",mirrors.clear_point(home+Vector3(4,0,0),[],1.5))
  check(mirrors.cast(),"New character summons through the native army")
  check(mirrors.bodies.all(func(body):return body.character_id==character and body.model.variant_skin==p.model.variant_skin),"Simultaneous native copies retain the selected identity and skin")
  for i in 30:game.army_runtime.integration_tick(DT);game.army_runtime.flush_presentation()
  mirrors.dispose()
  await frames(3)
 check(appearances==59 and combinations>=300,"All 59 appearances and their available source weapons were exercised")
 attack_case(47,"unarmed");await frames(3)
 var nodes=get_node_count();var resources=Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT);var created=pool.created
 for i in 20:attack_case(47,"unarmed")
 await frames(2)
 check(get_node_count()==nodes and Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)<=resources and pool.created==created,"Repeated warmed combat retains nodes/resources and projectile pool size")
 pose_samples.sort()
 print("SELECTED_CAST_POSE_US median=",pose_samples[pose_samples.size()/2]," max=",pose_samples.back()," (isolated animation callback; not rendered frame times)")
 print("SELECTED_CAST_RESULT checks=%d failures=%d appearances=%d weapons=%d"%[checks,failures,appearances,combinations])
 var old_path=game.settings_path;game.sound_library.cancel();game.music.stop();game.queue_free();paused=false;await frames(4)
 DirAccess.remove_absolute(ProjectSettings.globalize_path(old_path));quit(1 if failures else 0)
