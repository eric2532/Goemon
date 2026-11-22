extends "res://tests/forest-shrine/weapon_equipment_test.gd"

const UruHeads=preload("res://scripts/forest/painted_heads.gd")
const UruMirrors=preload("res://scripts/warcraft_mirrors.gd")
const URU_OUT="res://build/Other Files/Asset Toolkit/Uru Complete Inventory/Gameplay/"

func uru_picture(stem:String):
 if DisplayServer.get_name()=="headless":return
 game.camera_rig.camera.h_offset=0;game.camera_rig.camera.v_offset=0
 game.camera_rig.camera.global_position=home+Vector3(8,7,15);game.camera_rig.camera.look_at(home+Vector3.UP*1.4)
 await frames(2);await RenderingServer.frame_post_draw
 check(root.get_texture().get_image().save_png(URU_OUT+stem+".png")==OK,"Rendered "+stem)

func run():
 create_timer(900).timeout.connect(func():printerr("URU_INVENTORY_TIMEOUT");quit(1))
 DirAccess.make_dir_recursive_absolute(URU_OUT);root.size=Vector2i(1280,800);root.set_flag(Window.FLAG_NO_FOCUS,true)
 game=load("res://scenes/forest_title.tscn").instantiate();game.settings_path=cfg;root.add_child(game);current_scene=game;await frames(3)
 game.set_process(false);game.set_physics_process(false);game.player.set_physics_process(false)
 game.army_runtime.set_process(false);game.army_runtime.set_physics_process(false);game.camera_rig.set_process(false)
 game.settings.forest_pet_loadout=[];game.settings.disable_character_cooldowns=false;game.save_settings()
 var roster=Gear.Roster.selection_ids().duplicate()
 game.begin_arena();game.choose_rogue_character(35);await frames(3)
 game.equipment_hub.enter_button.pressed.emit();await frames(3)
 var p=game.player;var visual=p.model;var catalog=Gear.Roster.skin_catalog(35)
 check(catalog.size()==32 and catalog.has(0),"Uru has all 32 verified appearances including the preserved Original")
 check(Gear.Roster.loadout_key(35,game.settings)=="35" and UruHeads.portrait(35,game.settings).resource_path.ends_with("model/35.png"),"Original Uru keeps the existing painted head and saved loadout key")
 home=Vector3(40,0,60);home.y=game.model.surface_height(home.x,home.z)+.05
 game.model.team_progression.cards_enabled=false;game.model.waves.patrol_posts.clear();game.model.waves.crossgate_pet_test=true
 if is_instance_valid(game.training_dummy):game.training_dummy.position=home+Vector3.DOWN*1000
 var pool=Pool.service(game)
 pool.launched.connect(func(shot):weapon_shots.append(shot);shot.set_physics_process(false))
 game.impact_confirmed.connect(func(target,_strength,_time):weapon_hits.append(target))
 var skins=0;var combinations=0;var costs=[]
 for skin in catalog:
  choose_skin(35,skin);skins+=1
  check(p.character_id==35 and p.model==visual,"Every appearance stays under the same Uru model and character")
  var choices=Gear.allowed(35,game.settings)
  if skin!=0:check(choices.keys()==visual.appearance.source_weapons.keys(),"Skin %d exposes only its original source weapon set"%skin)
  check(UruHeads.portrait(35,game.settings)!=null,"Skin %d has its own prepared HUD head"%skin)
  for weapon in choices:
   equip_weapon(35,weapon);combinations+=1
   check(visual.current_weapon()==weapon,"Skin %d selects its original %s"%[skin,weapon])
   if skin!=0:check(visual.motions.key==visual.appearance.source_weapons[weapon],"Exact archive key survives sprite-ID collisions")
   for direction in 8:
    var key="5:%d"%direction;var clip_:Dictionary=visual.body_clip(5,key)
    for index in clip_.frames.size():
     visual.show_frame(5,key,index)
     check(Rect2(Vector2.ZERO,visual.sprite.texture.get_size()).encloses(visual.sprite.region_rect),"Source frame remains within the selected atlas")
   attack_case(35,weapon)
   game.army_runtime.clear();game.model.enemies.clear();game.army_runtime.flush_presentation();game.crowd.army.presentation.clear()
   if is_instance_valid(game.native_ink_feedback):game.native_ink_feedback.clear()
   var clip_:Dictionary=visual.body_clip(5,"5:4")
   visual.show_frame(5,"5:4",clip_.frames.size()/2)
   await uru_picture("weapon-%d-%s"%[skin,weapon])
  if skin!=0:
   var without_weapon=game.settings.gear_loadouts.duplicate(true);without_weapon.erase(Gear.character_key(35))
   check(game.save_equipment_loadouts(without_weapon,game.settings.skill_item_loadouts,game.settings.cosmetic_loadouts),"Skin starts safely without a carried weapon")
   for index in choices.size():
    p.swap_weapon()
    var expected:String=choices.keys()[(index+1)%choices.size()]
    check(p.model.current_weapon()==expected,"Cycling stays within the actual supplied weapon set")
    game.load_settings();check(p.model.current_weapon()==expected,"Cycled weapon survives selection reload")
   check(Gear.Roster.selected_skin(35,game.settings)==skin,"Uru appearance survives save/reload")
   p.position=home;p.velocity=Vector3.ZERO
   var mirrors=UruMirrors.new(p);mirrors.prepare_count()
   check(mirrors.cast(),"Appearance summons through the existing native army")
   check(mirrors.bodies.all(func(body):return body.character_id==35 and body.model.variant_skin==skin and body.model.current_weapon()==visual.current_weapon()),"Native copies retain Uru's exact appearance and weapon")
   for i in 12:game.army_runtime.integration_tick(DT);game.army_runtime.flush_presentation()
   mirrors.dispose();await frames(2)
   game.army_runtime.clear();game.model.enemies.clear();game.army_runtime.flush_presentation();game.crowd.army.presentation.clear()
   p.position=home
   var clip_:Dictionary=visual.body_clip(5,"5:4")
   for index in clip_.frames.size():
    visual.show_frame(5,"5:4",index)
    if DisplayServer.get_name()!="headless":await create_timer(float(clip_.duration)/clip_.frames.size()).timeout
    if index in [0,clip_.frames.size()/2,clip_.frames.size()-1]:await uru_picture("motion-%d-%d"%[skin,index])
   var started=Time.get_ticks_usec()
   for i in 300:visual.animate(DT,5,true,0,0,false,0,false)
   costs.append(float(Time.get_ticks_usec()-started)/300)
 check(skins==32 and combinations==182,"All 32 Uru appearances and 182 supplied weapon combinations were exercised")
 choose_skin(35,111691);check(Gear.allowed(35,game.settings).keys()==["unarmed"],"Pink pet appearance remains unarmed-only")
 check(Gear.Roster.skin_catalog(46).has(109912),"Existing saved red-rune appearance under Rei remains valid")
 for rei_skin in [100700,100798,120428,109912]:check(not catalog.has(rei_skin) and Gear.Roster.skin_catalog(46).has(rei_skin),"Rei artwork stays in Rei's gallery, outside Uru")
 check(catalog.has(100650) and not Gear.Roster.skin_catalog(46).has(100650),"Classic Ruby stays with Uru")
 choose_skin(35,0);equip_weapon(35,"staff")
 check(Gear.Roster.loadout_key(35,game.settings)=="35" and visual.normal_attack_pattern().contacts.size()==5,"Original Uru still has her prepared five-contact staff")
 for i in 20:attack_case(35,"staff")
 await frames(4)
 var nodes=get_node_count();var resources=Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT);var created=pool.created
 for i in 20:attack_case(35,"staff")
 await frames(4)
 print("URU_INVENTORY_REUSE before_nodes=",nodes," after_nodes=",get_node_count()," before_resources=",resources," after_resources=",Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)," before_pool=",created," after_pool=",pool.created)
 check(get_node_count()==nodes and Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)<=resources and pool.created==created,"Repeated warmed Uru attacks retain nodes/resources and the existing projectile pool")
 check(Gear.Roster.selection_ids()==roster,"Additional skins do not create new characters")
 game.show_equipment_hub(true);await frames(2)
 var picker=game.equipment_hub.portrait_button
 picker.open_gallery();check(picker.character==35 and picker.choices.item_count==32,"Uru's existing portrait opens the complete 32-skin gallery")
 await uru_picture("complete-uru-gallery")
 costs.sort();print("URU_INVENTORY_POSE_US median=",costs[costs.size()/2]," max=",costs.back()," (isolated callback; not frame times)")
 print("URU_INVENTORY_RESULT checks=%d failures=%d skins=%d weapons=%d"%[checks,failures,skins,combinations])
 game.sound_library.cancel();game.music.stop();game.queue_free();paused=false;await frames(4)
 DirAccess.remove_absolute(ProjectSettings.globalize_path(cfg));quit(1 if failures else 0)
