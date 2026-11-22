extends "res://tests/forest-shrine/weapon_equipment_test.gd"
const WATER_OUT="res://build/Other Files/Asset Toolkit/Shin Water Dragon/Recovery Turn/Gameplay/"
const WATER_SKIN=900050

func water_picture(stem:String):
 if DisplayServer.get_name()=="headless":return
 await frames(2);await RenderingServer.frame_post_draw
 check(root.get_texture().get_image().save_png(WATER_OUT+stem+".png")==OK,"Rendered "+stem)

func movement_review():
 var p=game.player;var start=p.position
 p.active_ability.cancel(true);p.set_auto_attack(false);p.set_physics_process(true)
 var move=InputEventAction.new();move.action="move_left";move.pressed=true;Input.parse_input_event(move)
 await create_timer(.6).timeout
 check(p.position.distance_to(start)>.2 and p.model.current_clip.begins_with("1:"),"Actual movement uses the stitched walking grip")
 await water_picture("controls-walk")
 var shift=InputEventKey.new();shift.physical_keycode=KEY_SHIFT;shift.pressed=true;shift.shift_pressed=true;Input.parse_input_event(shift)
 await create_timer(.6).timeout
 check(Input.is_action_pressed("sprint") and p.model.current_clip.begins_with("3:"),"Shift press uses the stitched running grip")
 await water_picture("controls-sprint")
 shift=InputEventKey.new();shift.physical_keycode=KEY_SHIFT;shift.pressed=false;Input.parse_input_event(shift)
 await create_timer(.4).timeout
 check(not Input.is_action_pressed("sprint") and p.model.current_clip.begins_with("1:"),"Shift release restores walking")
 move=InputEventAction.new();move.action="move_left";move.pressed=false;Input.parse_input_event(move)
 await create_timer(.4).timeout
 await water_picture("controls-resting");p.set_physics_process(false)

func run():
 create_timer(300).timeout.connect(func():printerr("WATER_DRAGON_TIMEOUT");quit(1))
 DirAccess.make_dir_recursive_absolute(WATER_OUT);root.size=Vector2i(1280,800);root.set_flag(Window.FLAG_NO_FOCUS,true)
 game=load("res://scenes/forest_title.tscn").instantiate();game.settings_path=cfg;root.add_child(game);current_scene=game;await frames(3)
 game.set_process(false);game.set_physics_process(false);game.player.set_physics_process(false)
 game.army_runtime.set_process(false);game.army_runtime.set_physics_process(false);game.camera_rig.set_process(false)
 game.settings.forest_pet_loadout=[];game.settings.disable_character_cooldowns=false;game.save_settings()
 var p=game.player
 game.begin_arena();game.choose_rogue_character(37);await frames(3)
 check(Gear.Roster.skin_catalog(37).has(100050) and Gear.Roster.skin_catalog(37).has(WATER_SKIN),"Original and stitched basic Shin are separate selectable appearances")
 game.select_shin_skin(37,WATER_SKIN);await frames(2)
 var hub=game.equipment_hub
 hub.select_skin(WATER_SKIN)
 check(hub.available_items().size()==7 and "weapon:boomerang" in hub.available_items(),"Water Dragon Shin supplies all seven recovered weapons")
 await water_picture("equipment-resting")
 hub.portrait_button.open_gallery();await frames(3)
 var choices=hub.portrait_button.choices
 var selected=choices.get_selected_items()[0]
 check(choices.get_item_metadata(selected)==WATER_SKIN,"Selection gallery displays the equipped blue Shin")
 choices.ensure_current_is_visible();await water_picture("selection-resting")
 hub.portrait_button.gallery.hide();await frames(3)
 hub.enter_button.pressed.emit();await frames(3)
 home.y=game.model.world_height(home.x,home.z)+.15;p.position=home;p.velocity=Vector3.ZERO
 game.model.team_progression.cards_enabled=false;game.model.waves.crossgate_pet_test=true
 if is_instance_valid(game.training_dummy):game.training_dummy.home=home+Vector3.DOWN*1000;game.training_dummy.position=game.training_dummy.home
 var model=p.model
 check(model.shin_skin==WATER_SKIN and model.current_weapon()=="sword" and model.atlases.size()==int(model.appearance.pages),"Existing Cross Gate model loads the prepared sword/wave atlases")
 check(model.get_script()==preload("res://scripts/crossgate_model.gd") and p.active_ability.get_script()==preload("res://scripts/crossgate_combat.gd"),"No new model, weapon attachment or combat owner")
 game.forest_ui.sync_character()
 var heads=preload("res://scripts/forest/painted_heads.gd")
 var head=heads.portrait(37,game.settings)
 check(head==game.forest_ui.hero_portrait.texture and head==heads.portrait(37,game.settings),"Selected model head uses the existing portrait cache")
 check(heads.routes["37:900050"]!=heads.routes["37:100050"],"Blue appearance has its matching original-model head crop")
 var native=model.profile("res://assets/characters/crossgate/shin/100050/").weapons[0]
 for direction in [5,6,7]:
  check((model.motions.clips["5:%d"%direction].frames[-1]==model.motions.clips["0:%d"%direction].frames[0])==(direction==5),"Recovery keeps the selected source body %d"%direction)
 for pose in native.clips:
  var original:Dictionary=native.clips[pose];var actual:Dictionary=model.motions.clips[pose]
  check(original.duration==actual.duration and original.frames.size()==actual.frames.size(),"Source frame count and clock "+pose)
  if pose.begins_with("5:"):check(original.contact==actual.contact and original.swing==actual.swing and original.audio_cues==actual.audio_cues,"Source contact and audio "+pose)
  for i in actual.frames.size():
   model.show_frame(int(pose.split(":")[0]),pose,i)
   check(Rect2(Vector2.ZERO,model.sprite.texture.get_size()).encloses(model.sprite.region_rect),"Prepared atlas bounds "+pose)
 var review_directions={}
 for direction in 8:
  p.facing=Vector3.FORWARD;p.combat_aim_left=0
  game.camera_rig.camera.global_position=home+Vector3.BACK.rotated(Vector3.UP,direction*TAU/8)*15+Vector3.UP*7
  game.camera_rig.camera.look_at(home+Vector3.UP*1.8)
  attack_case(37,"sword")
  p.facing=Vector3.FORWARD;p.combat_aim_left=0
  var review_direction:int=model.direction()
  review_directions[review_direction]=true
  check(model.body_clip(9,"9:%d"%direction).frames.size()==1,"Original guard facing %d"%direction)
  check(model.body_clip(5,"5:%d"%direction).frames.any(func(frame):return frame[3]>200 or frame[4]>200),"Recovered blue strike wave facing %d"%direction)
  var key="5:%d"%review_direction;var motion:Dictionary=model.body_clip(5,key)
  for i in motion.frames.size():
   model.show_frame(5,key,i)
   if DisplayServer.get_name()!="headless":
    await create_timer(float(motion.duration)/motion.frames.size()).timeout
    await water_picture("attack-%d-%02d"%[direction,i])
  for action in [0,1,3,6,8,9,10]:
   model.show_frame(action,"%d:%d"%[action,review_direction],0)
   await water_picture("pose-%d-%d"%[direction,action])
   if action in [1,3]:
    var moving="%d:%d"%[action,review_direction]
    for i in model.body_clip(action,moving).frames.size():
     model.show_frame(action,moving,i)
     await water_picture("motion-%d-%d-%d"%[review_direction,action,i])
  var resting="0:%d"%review_direction
  for i in model.body_clip(0,resting).frames.size():
   model.show_frame(0,resting,i)
   await water_picture("resting-%d-%d"%[direction,i])
 check(review_directions.size()==8,"Rendered review covers eight distinct sprite directions after combat aiming")
 equip_weapon(37,"sword");await frames(2)
 var pool=Pool.service(game);var created=pool.created
 game.impact_confirmed.connect(func(target,_strength,_time):weapon_hits.append(target))
 attack_case(37,"sword");await frames(3)
 var nodes=get_node_count();var resources=Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)
 for i in 12:attack_case(37,"sword")
 await frames(3)
 check(get_node_count()==nodes and Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)<=resources and pool.created==created,"Repeated warmed sword use keeps existing node/resource/pool counts")
 var mirrors=preload("res://scripts/warcraft_mirrors.gd").new(p,0)
 for i in 5:
  check(mirrors.reinforce(37,home+Vector3((i-2)*2,0,0)),"Native companion allocation")
  var body=mirrors.bodies[i]
  check(body.model.shin_skin==WATER_SKIN and body.model.atlases[0]==model.atlases[0],"Native companions reuse selected stitched atlas")
  check(body.perform(0,home+Vector3.FORWARD*2),"Native companion starts the shared sword/wave attack")
 for i in 90:
  game.army_runtime.integration_tick(DT);game.army_runtime.flush_presentation()
  if i==42:await water_picture("five-native-blue-waves")
 await water_picture("five-native-copies");mirrors.dispose();await frames(3)
 game.army_runtime.clear();await movement_review()
 game.save_settings();game.load_settings()
 check(p.model.shin_skin==WATER_SKIN and Gear.Roster.valid_loadout_key("37:900050"),"Separate appearance/loadout survives save and reload")
 game.select_shin_skin(37,100050)
 check(p.model.shin_skin==100050 and p.model.appearance.id==100050,"Original basic Shin still loads normally")
 print("WATER_DRAGON_RESULT checks=%d failures=%d"%[checks,failures])
 var old_path=game.settings_path;game.sound_library.cancel();game.music.stop();game.queue_free();paused=false;await frames(4)
 DirAccess.remove_absolute(ProjectSettings.globalize_path(old_path));quit(1 if failures else 0)
