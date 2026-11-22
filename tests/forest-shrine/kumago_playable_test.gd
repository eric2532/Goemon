extends "res://tests/forest-shrine/weapon_equipment_test.gd"

const KUMAGO_OUT="res://build/Other Files/Asset Toolkit/Kumago/Gameplay/"
const Copies=preload("res://scripts/warcraft_mirrors.gd")
const ID=Gear.Roster.KUMAGO_ID

func check(ok:bool,message:String):
 checks+=1
 if not ok:failures+=1;printerr("FAIL: "+message)

func capture(stem:String):
 if DisplayServer.get_name()=="headless":return
 if game.playing:
  game.camera_rig.camera.h_offset=0;game.camera_rig.camera.v_offset=0
  game.camera_rig.camera.global_position=home+Vector3(7,6,13);game.camera_rig.camera.look_at(home+Vector3.UP*1.5)
 game.forest_ui.sync();await frames(2);await RenderingServer.frame_post_draw
 check(root.get_texture().get_image().save_png(KUMAGO_OUT+stem+".png")==OK,"Rendered "+stem)

func clear_arena():
 game.army_runtime.clear();game.model.enemies.clear();game.army_runtime.flush_presentation()
 game.crowd.army.presentation.clear()
 game.player.position=home;game.player.velocity=Vector3.ZERO

func simultaneous_attacks(skin:int):
 clear_arena();choose_skin(ID,skin);equip_weapon(ID,"unarmed")
 var target=spawn(Vector3.FORWARD*1.6)
 var copies=Copies.new(game.player,0);weapon_hits.clear()
 for index in 5:
  check(copies.reinforce(ID,home+Vector3((index-2)*.2,0,0)),"Native army accepts 熊哥's stable identity")
  var body=copies.bodies[index];body.ai_target=target
  check(body.model.variant_skin==skin and body.perform(0,target.position),"Copy uses selected original skin and starts its punch")
 for tick in 100:
  for body in copies.bodies:body.step(DT,{"position":body.position,"hp":body.max_hp,"yaw":0.0,"pose_velocity":Vector3.ZERO})
  if tick==25:await capture("five-punches-%d"%skin)
 check(weapon_hits.count(target)==5 and copies.bodies.all(func(body):return not body.has_offensive_action()),"Five simultaneous punches each hit once and finish")
 copies.dispose();await frames(3);clear_arena()

func movement_case():
 var p=game.player;p.active_ability.cancel(true);p.attack_chain.reset();p.position=home;p.velocity=Vector3.ZERO
 check(InputMap.action_get_events("sprint").any(func(event):return event is InputEventKey and event.physical_keycode==KEY_SHIFT),"Shift keeps the normal sprint binding")
 p.set_physics_process(true)
 Input.action_press("move_forward");await create_timer(.25).timeout
 var walk=Vector2(p.velocity.x,p.velocity.z).length()
 check(p.model.current_clip.begins_with("1:"),"Movement without Shift plays the source walk")
 Input.action_press("sprint");await create_timer(.25).timeout
 var sprint=Vector2(p.velocity.x,p.velocity.z).length()
 check(p.model.current_clip.begins_with("3:"),"Shift selects the source run")
 await capture("sprinting")
 Input.action_release("sprint");await create_timer(.25).timeout
 var released=Vector2(p.velocity.x,p.velocity.z).length()
 check(p.model.current_clip.begins_with("1:"),"Shift release returns to the source walk")
 Input.action_release("move_forward");await frames(3);p.set_physics_process(false)
 check(walk>0 and sprint>walk and released<sprint,"Walking, sprint press and release use existing player controls")
 p.position=home;p.velocity=Vector3.ZERO

func run():
 create_timer(360).timeout.connect(func():printerr("KUMAGO_TIMEOUT");quit(1))
 DirAccess.make_dir_recursive_absolute(KUMAGO_OUT);root.size=Vector2i(1280,800)
 game=load("res://scenes/forest_title.tscn").instantiate();game.settings_path=cfg;root.add_child(game);current_scene=game;await frames(3)
 game.set_process(false);game.set_physics_process(false);game.player.set_physics_process(false)
 game.army_runtime.set_process(false);game.army_runtime.set_physics_process(false);game.camera_rig.set_process(false)
 game.settings.forest_pet_loadout=[];game.settings.disable_character_cooldowns=false;game.save_settings()
 check(Gear.Roster.selection_ids().has(ID) and Gear.Roster.sound_ids().has(ID),"熊哥 appears in selection and Sound Studio")
 check(Gear.Roster.valid_loadout_key("51:100800") and Gear.Roster.valid_loadout_key("51:120443") and not Gear.Roster.valid_loadout_key("51:999999"),"Save boundary validates both new appearances")
 game.begin_arena()
 check(game.menu.find_child("RogueFighter_kumago",true,false)!=null,"Real character menu contains 熊哥")
 game.choose_rogue_character(ID);await frames(3)
 check(game.equipment_hub!=null and game.equipment_hub.available_items().size()==6,"Original outfit exposes its six supplied weapons in Equipment")
 await capture("equipment-original")
 game.equipment_hub.portrait_button.open_gallery();await frames(2)
 check(game.equipment_hub.portrait_button.choices.item_count==2,"Equipment gallery exposes original and dark outfits")
 await capture("skin-gallery");game.equipment_hub.portrait_button.gallery.hide()
 game.equipment_hub.enter_button.pressed.emit();await frames(3)
 var p=game.player;var visual=p.model
 home=Vector3(40,0,60);home.y=game.model.surface_height(home.x,home.z)+.05
 game.model.team_progression.cards_enabled=false;game.model.waves.patrol_posts.clear();game.model.waves.crossgate_pet_test=true
 if is_instance_valid(game.training_dummy):game.training_dummy.position=home+Vector3.DOWN*1000
 game.camera_rig.camera.h_offset=0;game.camera_rig.camera.v_offset=0
 game.camera_rig.camera.global_position=home+Vector3(7,6,13);game.camera_rig.camera.look_at(home+Vector3.UP*1.5)
 check(visual.get_script()==preload("res://scripts/crossgate_model.gd") and p.active_ability.get_script()==preload("res://scripts/crossgate_combat.gd"),"熊哥 reuses shared model and combat")
 check(SoundLibrary.original_for(ID,"step")==SoundLibrary.GOEMON_FOOTSTEP and SoundLibrary.original_for(ID,"land")==SoundLibrary.HUMANOID_LANDING,"Goemon's prepared footstep and landing remain defaults")
 var pool=Pool.service(game)
 pool.launched.connect(func(shot):weapon_shots.append(shot);shot.set_physics_process(false))
 game.impact_confirmed.connect(func(target,_strength,_time):weapon_hits.append(target))
 var combinations=0
 for skin in Gear.Roster.skin_catalog(ID):
  choose_skin(ID,skin);var choices=Gear.allowed(ID,game.settings)
  check(p.model==visual and visual.appearance.id==skin,"Skin changes reuse the same model")
  check(choices.keys()==visual.appearance.source_weapons.keys(),"Only actual source weapon siblings are offered")
  game.forest_ui.sync_character()
  check(game.forest_ui.hero_portrait.texture==game.forest_ui.PaintedHeads.portrait(ID,game.settings) and game.forest_ui.hero_portrait.texture!=null,"HUD head matches selected original skin")
  for weapon in choices:
   equip_weapon(ID,weapon);combinations+=1
   check(visual.current_weapon()==weapon and visual.motions.key==visual.appearance.source_weapons[weapon],"Equipped weapon uses its pack-qualified source")
   check(game.sound_preview(ID,"swing")==visual.attack_sound(false) and game.sound_preview(ID,"hit")==visual.attack_sound(true),"Sound Studio uses the equipped weapon's original audio")
   for direction in 8:
    for action in [0,1,3,5,6,8,9,10]:
     var key="%d:%d"%[action,direction];var motion:Dictionary=visual.body_clip(action,key)
     for index in motion.frames.size():
      visual.show_frame(action,key,index)
      check(Rect2(Vector2.ZERO,visual.sprite.texture.get_size()).encloses(visual.sprite.region_rect),"Every original animation frame fits its atlas")
    var attack:Dictionary=visual.body_clip(5,"5:%d"%direction)
    check(not attack.contacts.is_empty() and attack.contacts.all(func(at):return at>=0 and at<attack.duration),"Source contact timings stay bounded")
    check(weapon in ["unarmed","bow"] or not attack.wind_motions.is_empty(),"Weapon wind has a reviewed original swing direction")
   attack_case(ID,weapon)
   clear_arena();var attack:Dictionary=visual.body_clip(5,"5:4")
   for index in attack.frames.size():
    visual.show_frame(5,"5:4",index)
    if DisplayServer.get_name()!="headless":await create_timer(float(attack.duration)/attack.frames.size()).timeout
    if index==attack.frames.size()/2:await capture("attack-%d-%s"%[skin,weapon])
  var empty=game.settings.gear_loadouts.duplicate(true);empty.erase(Gear.character_key(ID))
  check(game.save_equipment_loadouts(empty,game.settings.skill_item_loadouts,game.settings.cosmetic_loadouts),"Unequip returns to native source stances")
  for index in choices.size():
   var expected:String=choices.keys()[(choices.keys().find(visual.current_weapon())+1)%choices.size()]
   p.swap_weapon();game.load_settings()
   check(Gear.Roster.selected_skin(ID,game.settings)==skin and visual.current_weapon()==expected and (choices.size()==1 or Gear.equipped(game.settings.gear_loadouts,ID)=="weapon:"+expected),"Cycling saves and reloads every supplied equipped weapon and skin")
  var copies=Copies.new(p);copies.prepare_count();p.position=home;p.velocity=Vector3.DOWN;p.move_and_slide()
  check(copies.cast(),"Native copies summon for each outfit")
  check(copies.bodies.all(func(body):return body.character_id==ID and body.model.variant_skin==skin and body.model.current_weapon()==visual.current_weapon() and body.model.atlases[0]==visual.atlases[0]),"Copies retain outfit, weapon and shared atlas")
  copies.dispose();await frames(3);clear_arena()
 check(combinations==7,"Both outfits and all seven supplied combinations were exercised")
 choose_skin(ID,100800);equip_weapon(ID,"sword");choose_skin(ID,120443);game.load_settings()
 check(visual.current_weapon()=="unarmed" and Gear.equipped(game.settings.gear_loadouts,ID)=="weapon:sword","Dark outfit keeps its actual fists while preserving the original outfit's saved sword")
 choose_skin(ID,100800)
 check(visual.current_weapon()=="sword","Returning to the original outfit restores its compatible saved weapon")
 for skin in [100800,120443]:await simultaneous_attacks(skin)
 choose_skin(ID,100800);equip_weapon(ID,"unarmed");await movement_case()
 for repeat in 3:attack_case(ID,"unarmed")
 await frames(3)
 var nodes=get_node_count();var resources=Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT);var created=pool.created
 for repeat in 20:attack_case(ID,"unarmed")
 await frames(3)
 check(get_node_count()<=nodes and Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)<=resources and pool.created==created,"Warmed repeated attacks do not grow nodes/resources/projectile capacity")
 print("KUMAGO_REUSE nodes=",nodes,"/",get_node_count()," resources=",resources,"/",Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)," projectile_nodes=",created,"/",pool.created)
 print("KUMAGO_RESULT checks=%d failures=%d appearances=2 combinations=%d"%[checks,failures,combinations])
 game.sound_library.cancel();game.music.stop();game.queue_free();paused=false;await frames(4)
 DirAccess.remove_absolute(ProjectSettings.globalize_path(cfg));quit(1 if failures else 0)
