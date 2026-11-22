extends "res://tests/forest-shrine/timed_dodge_test.gd"
const PLAIN_OUT="res://build/Other Files/Asset Toolkit/Timed Dodge/Plain/"
const Gear=preload("res://scripts/forest/equipment.gd")
const BOOTS_OUT="res://build/Other Files/Asset Toolkit/Accessories/"

func backstep_boots():
 var p=game.player
 var ordinary_distance=0.0
 for id in p.RogueRoster.CROSSGATE:
  if id in [34,36]:game.settings.kaz_skin=preload("res://scripts/kaz_skins.gd").MAZE if id==36 else preload("res://scripts/kaz_skins.gd").DEFAULT
  await settle(id);p.select_character(id);p.timed_dodge.shadow_counter_enabled=false
  var owner=Gear.character_key(p.character_id)
  check(game.save_equipment_loadouts({},{},{}),"Clear boots before testing fighter %d"%id)
  key();key(false)
  check(not p.timed_dodge.reacting and p.invuln==0,"Bare Space still needs a warning without boots for %d"%id)
  check(game.save_equipment_loadouts({owner:{"accessory:1":"accessory:21884"}},{},{}),"Equip Backstep Boots for %d"%id)
  var start:Vector3=p.position;var facing:Vector3=p.facing;var health:float=p.hp
  game.update_character_tuning(id,"counter_chance",100)
  key();key(false)
  var travel:Vector3=p.model.kagerou_step*p.model.KAGEROU_BACK_TICKS
  if id==p.RogueRoster.KAZI_ID:ordinary_distance=travel.length()
  check(p.timed_dodge.reacting and travel.dot(facing)<0 and p.invuln>0,"Boots start a protected backward step without a warning for %d"%id)
  check(p.timed_dodge.counter_source==0 and p.active_ability.shin_counter.is_empty(),"Free backsteps cannot earn a counter at 100%% chance for %d"%id)
  key();key(false);key(true,true);key(false)
  check(p.timed_dodge.step_ticks==0 and p.timed_dodge.cooldown==p.timed_dodge.RECOVERY,"Repeated Space and echoes cannot restart the step")
  p.take_hit_from(1,Vector3.BACK,false,0)
  check(p.hp==health,"Backstep reuses ordinary dodge protection")
  await driver.advance(1,func(_dt):advance(50,false))
  check(Vector3(p.position.x-start.x,0,p.position.z-start.z).distance_to(travel)<.1 and not p.timed_dodge.reacting and p.facing.is_equal_approx(facing),"Backward dodge completes at its endpoint without turning fighter %d"%id)
  check(not p.model.stat_counter_shadow.visible and p.model.kagerou_shadows.all(func(s):return not s.visible),"Boots create no shadow or afterimages")
  if id==p.RogueRoster.KAZI_ID and DisplayServer.get_name()!="headless":
   RenderingServer.force_draw();check(root.get_texture().get_image().save_png(BOOTS_OUT+"backstep-boots-endpoint.png")==OK,"Captured backward dodge endpoint")
  check(game.save_equipment_loadouts({},{},{}),"Unequip Backstep Boots")
  key();key(false)
  check(not p.timed_dodge.reacting and p.invuln<=0,"Unequipping immediately removes the free step for %d"%id)
 game.settings.kaz_skin=preload("res://scripts/kaz_skins.gd").DEFAULT
 await settle(p.RogueRoster.KAZI_ID);p.select_character(p.RogueRoster.KAZI_ID)
 var owner=Gear.character_key(p.character_id)
 check(game.save_equipment_loadouts({owner:{"accessory:1":"accessory:21884","accessory:2":"accessory:21817"}},{},{}),"Boots coexist with Speed Shoes")
 game.load_settings();Gear.apply(p)
 check(p.accessory_bonuses.get("backstep")==1 and p.accessory_bonuses.get("movement_speed")==3,"Both footwear accessories survive reload")
 var texture:Texture2D=Gear.ITEMS["accessory:21884"].icon
 var original=Image.load_from_file(texture.resource_path);original.convert(Image.FORMAT_RGBA8)
 var imported=texture.get_image();imported.convert(Image.FORMAT_RGBA8)
 check(original.get_data()==imported.get_data(),"Imported Backstep Boots preserve original RGBA pixels")
 p.active_ability.start_attack();check(p.active_ability.is_attacking(),"Start an attack before the free dodge")
 key();key(false)
 check(p.timed_dodge.reacting and not p.active_ability.is_attacking(),"The equipped backstep cancels an unfinished attack")
 check(is_equal_approx((p.model.kagerou_step*p.model.KAGEROU_BACK_TICKS).length(),ordinary_distance),"Speed Shoes do not multiply backstep distance")
 await driver.advance(1,func(_dt):advance(50,false))
 for state in ["paused","transitioning"]:
  game.set(state,true);key();key(false);game.set(state,false)
  check(not p.timed_dodge.reacting and p.timed_dodge.cooldown==0,"%s blocks an equipped backstep"%state)
 var jump=InputEventKey.new();jump.physical_keycode=KEY_SPACE;jump.shift_pressed=true;jump.pressed=true;root.push_input(jump,true)
 jump.pressed=false;root.push_input(jump,true)
 check(p.jump_buffer>0 and not p.timed_dodge.reacting,"Shift + Space keeps its jump with boots equipped")
 await driver.advance(1,func(_dt):advance(6,false));key();key(false)
 check(not p.is_on_floor() and not p.timed_dodge.reacting,"Boots cannot backstep in midair")
 await settle(p.RogueRoster.KAZI_ID);p.timed_dodge.shadow_counter_enabled=false
 var wall=StaticBody3D.new();wall.collision_layer=1
 var shape=CollisionShape3D.new();var box=BoxShape3D.new();box.size=Vector3(5,4,.25);shape.shape=box;wall.add_child(shape);game.add_child(wall);wall.global_position=home+Vector3(0,1,.85)
 await physics_frame;await physics_frame;key();key(false)
 await driver.advance(1,func(_dt):advance(50,false))
 check(p.position.z>=home.z and p.position.z<home.z+.7 and not p.timed_dodge.reacting,"Backstep stops at a wall")
 wall.queue_free();await physics_frame;await physics_frame
 await settle(p.RogueRoster.KAZI_ID);p.timed_dodge.shadow_counter_enabled=false
 var nodes=0;var resources=0.0
 for cycle in 35:
  if cycle==5:nodes=get_node_count();resources=Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)
  p.position=home;p.velocity=Vector3.ZERO;key();key(false)
  await driver.advance(1,func(_dt):advance(50,false))
  check(not p.timed_dodge.reacting and p.active_ability.shin_counter.is_empty(),"Repeated backward step finishes without stale counter state")
 var node_delta=get_node_count()-nodes;var resource_delta=Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)-resources
 check(node_delta<=0 and resource_delta<=0,"Thirty backward dodges retain no warmed nodes or resources: nodes %+d, resources %+.0f"%[node_delta,resource_delta])
 game.show_equipment_hub(true);await frames(3)
 var hub=game.equipment_hub;hub.show_page("accessories");hub.selected_slot="accessory:1";hub.selected_item="accessory:21884";hub.equip_selected()
 check(hub.collection.has("accessory:21884") and hub.accessory_buttons["accessory:1"].get_node("GearIcon").texture==texture,"Equipment shows and equips the selected Backstep Boots")
 if DisplayServer.get_name()!="headless":
  RenderingServer.force_draw();check(root.get_texture().get_image().save_png(BOOTS_OUT+"backstep-boots-equipped.png")==OK,"Captured equipped Backstep Boots")
 hub.unequip();check(not p.accessory_bonuses.has("backstep"),"Equipment removal clears the cached backstep bonus")
 game.back_from_equipment();await frames(3)

func run():
 create_timer(240).timeout.connect(func():printerr("PLAIN_DODGE_TIMEOUT");quit(1))
 DirAccess.make_dir_recursive_absolute(PLAIN_OUT);DirAccess.make_dir_recursive_absolute(BOOTS_OUT);root.size=Vector2i(1280,800)
 var doc=load("res://scripts/forest/forest_map_document.gd").new();doc.load_wind_meadow();await setup_fixture(doc.data)
 game.set_process(false);game.army_runtime.set_process(false);game.army_runtime.set_physics_process(false)
 game.music.stop();game.settings.forest_pet_loadout=[];game.model.waves.crossgate_pet_test=true;game.model.waves.patrol_posts.clear()
 game.training_dummy.position=home+Vector3.DOWN*1000
 driver=load("res://tests/forest-shrine/physics_step_driver.gd").new();root.add_child(driver)
 home.y=game.model.surface_height(home.x,home.z)+.05;game.model.update_vision(home)
 var p=game.player
 var warning=preload("res://assets/audio/crossgate/cgefc01.wav")
 var pcm=HashingContext.new();pcm.start(HashingContext.HASH_SHA256);pcm.update(warning.data)
 check(pcm.finish().hex_encode()=="cf04272b562b1b78e695d21c0bdd63bba148f1c21c21e5dba7034a5e3ee8dfdd","The imported 護衛 cue preserves the original PCM")
 check(not p.timed_dodge.shadow_counter_enabled,"A fresh player starts without the dormant shadow feature")
 game.camera_rig.camera.global_position=home+Vector3(8,4,0);game.camera_rig.camera.look_at(home+Vector3.UP*1.2)
 for id in p.RogueRoster.CROSSGATE:
  await settle(id);p.select_character(id)
  check(not p.timed_dodge.shadow_counter_enabled,"Shadow counter is dormant by default for %d"%id)
  var evade=InputEventKey.new();evade.physical_keycode=KEY_C;evade.pressed=true;root.push_input(evade,true)
  evade.pressed=false;root.push_input(evade,true)
  check(p.dodge_time==0 and p.invuln==0 and not p.timed_dodge.reacting,"C grants no evade or protection for %d"%id)
  var sound_before:int=game.voice_idx
  p.timed_dodge._process(0)
  check(game.voice_idx==sound_before,"No warning sound without a threat for %d"%id)
  var attacker=spawn()
  check(await wait_warning(),"Real warning opens the plain dodge for %d"%id)
  var enemy:Ninja=game.army_runtime.enemy_target(attacker.id)
  p.timed_dodge._process(0)
  var cue:AudioStreamPlayer=game.last_sound_voice
  check(p.timed_dodge.visible and is_instance_valid(cue) and cue.get_meta("order",-1)>sound_before
    and cue.get_meta("kind","")=="cg_dodge_warning" and cue.stream==warning and cue.pitch_scale==1,
    "The native warning plays the original 護衛 cue for %d"%id)
  sound_before=game.voice_idx;p.timed_dodge._process(0)
  check(game.voice_idx==sound_before,"An already visible warning plays no extra cue for %d"%id)
  var jump=InputEventKey.new();jump.physical_keycode=KEY_SPACE;jump.shift_pressed=true;jump.pressed=true;root.push_input(jump,true)
  jump.pressed=false;root.push_input(jump,true)
  check(p.jump_buffer>0 and not p.timed_dodge.reacting and p.invuln<=0,"Shift + Space queues a jump instead of the available dodge for %d"%id)
  p.jump_buffer=0
  if id==p.RogueRoster.SHIN_ID:
   p.active_ability.start_basic_attack(p.facing,enemy)
   check(p.active_ability.is_attacking(),"Shin starts a sword attack while a real warning is active")
  var start:Vector3=p.position;key();key(false)
  check(game.last_sound_voice.get_meta("kind","")=="cg_kagerou_dodge","The accepted dodge plays its existing retreat cue for %d"%id)
  if id==p.RogueRoster.SHIN_ID:
   check(p.timed_dodge.reacting and not p.active_ability.is_attacking() and p.dodge_time==0,"Timed Space cancels Shin's attack and uses the timed step")
  var travel:Vector3=p.model.kagerou_step*p.model.KAGEROU_BACK_TICKS
  check(p.timed_dodge.reacting and p.timed_dodge.counter_source==0 and not p.timed_dodge.counter_origin.is_finite(),"Space moves without banking a counter for %d"%id)
  check(not p.model.stat_counter_shadow.visible and p.model.kagerou_shadows.all(func(s):return not s.visible),"Space leaves no shadow for %d"%id)
  await driver.advance(1,func(_dt):advance(50,false))
  check(Vector3(p.position.x-start.x,0,p.position.z-start.z).distance_to(travel)<.1 and not p.timed_dodge.reacting,"The plain dodge stays at its outward endpoint for %d"%id)
  check(not p.model.stat_counter_shadow.visible and p.model.sprite.position.is_zero_approx(),"No delayed shadow or visual return for %d"%id)
  if id==p.RogueRoster.KAZI_ID and DisplayServer.get_name()!="headless":
   await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png(PLAIN_OUT+"plain-dodge.png")
  p.active_ability.primary_tab_target=weakref(enemy)
  var click=InputEventMouseButton.new()
  click.button_index=MOUSE_BUTTON_LEFT;click.pressed=true
  p._unhandled_input(click);click.pressed=false;p._input(click)
  check(p.active_ability.is_attacking() and p.active_ability.shin_counter.is_empty(),"The next left click remains an ordinary attack for %d"%id)
  await settle(id);p.select_character(id)
  game.update_character_tuning(id,"counter_chance",100)
  key();key(false)
  check(p.active_ability.shin_counter.is_empty(),"Unprompted Space cannot roll a counter even at 100%% for %d"%id)
  spawn();check(await wait_warning(),"A native warning opens the counter-chance dodge for %d"%id)
  jump.pressed=true;root.push_input(jump,true);jump.pressed=false;root.push_input(jump,true)
  check(p.jump_buffer>0 and p.active_ability.shin_counter.is_empty(),"Shift + Space cannot roll a counter even at 100%% for %d"%id)
  p.jump_buffer=0
  var source:int=game.army_runtime.native.hero_dodge_threat().source_id
  var origin:Vector3=p.position;var health:float=p.hp
  key();key(false)
  var counter:Dictionary=p.active_ability.shin_counter
  check(not counter.is_empty(),"Successful Space rolls the existing 100%% Counter Chance for %d"%id)
  if not counter.is_empty():
   check(counter.source==source and counter.basic and not counter.after_dodge and counter.origin.is_equal_approx(origin) and counter.ticket.action=="stat_counter","Space uses the original attacker and ordinary counter rules for %d"%id)
  key();key(false);key(true,true);key(false)
  for projectile in [false,true]:p.take_hit_from(2,Vector3.BACK,projectile,source)
  check(p.hp==health and p.active_ability.shin_counter==counter and p.active_ability.shin_counter_pending.is_empty(),"Repeat presses and protected contacts cannot reroll or queue counters for %d"%id)
  if id==p.RogueRoster.KAZI_ID and DisplayServer.get_name()!="headless":
   await driver.advance(1,func(_dt):advance(8,false))
   game.army_runtime.flush_presentation();game.forest_ui.sync()
   await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png(PLAIN_OUT+"chance-counter.png")
  await driver.advance(1,func(_dt):advance(50,false))
  finish_counter()
  check(p.hp==health and not p.timed_dodge.reacting and p.active_ability.shin_counter.is_empty(),"Chance counter finishes while the Space dodge keeps its protection and movement for %d"%id)
 await backstep_boots()
 print("PLAIN_DODGE_RESULT ",JSON.stringify({"checks":checks,"failures":failures}))
 game.queue_free();current_scene=null;await frames(3)
 DirAccess.remove_absolute(ProjectSettings.globalize_path(cfg));quit(1 if failures else 0)
