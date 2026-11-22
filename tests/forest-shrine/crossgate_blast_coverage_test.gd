extends "res://scripts/recovered_goemon_gameplay_tests.gd"

const Roles=preload("res://scripts/forest/forest_enemy_roles.gd")
const Skills=preload("res://scripts/spells/skill_balance.gd")
const OUT="res://build/Other Files/Native Sure Strike/"
const DT=1.0/60
var home=Vector3(-120,0,125)
var driver
var victims:Array[int]=[]
var samples:Array[int]=[]

func advance(_dt:float):
 var started=Time.get_ticks_usec()
 game.player._physics_process(DT)
 game.army_runtime.flush_presentation()
 game.crowd.army.presentation.tick(DT)
 samples.append(Time.get_ticks_usec()-started)

func spawn(offset:Vector3)->Ninja:
 var at=home+offset;at.y=game.model.surface_height(at.x,at.z)
 var row=game.model.waves.spawn_enemy(Roles.SLIME,at);row.hp=1000000;row.max_hp=row.hp
 game.army_runtime.import_arrivals();game.army_runtime.sync_targets()
 return game.army_runtime.enemy_target(row.id)

func capture(name_:String):
 if DisplayServer.get_name()=="headless":return
 var fx=game.crowd.army.presentation
 for row in fx.effects:
  if row.kind=="shin_sure_strike":row.age=5*fx.SURE_STRIKE_FRAME_TIME
  elif row.kind=="shin_double_edge":row.age=5*fx.DOUBLE_EDGE_FRAME_TIME
 game.army_runtime.flush_presentation();fx.draw_effects();game.forest_ui.sync()
 await process_frame;await RenderingServer.frame_post_draw
 check(root.get_texture().get_image().save_png(OUT+name_+".png")==OK,"Captured "+name_)

func run():
 create_timer(360).timeout.connect(func():printerr("BLAST_COVERAGE_TIMEOUT");quit(1))
 DirAccess.make_dir_recursive_absolute(OUT);root.size=Vector2i(1280,800);root.set_flag(Window.FLAG_NO_FOCUS,true)
 var doc=load("res://scripts/forest/forest_map_document.gd").new();doc.load_wind_meadow()
 await setup_fixture(doc.data)
 var p=game.player;var army=game.army_runtime;var fx=game.crowd.army.presentation;var rewards=game.model.team_progression
 game.set_process(false);army.set_process(false);army.set_physics_process(false);game.camera_rig.set_process(false)
 game.model.falan_floor=0;game.model.waves.patrol_posts.clear();game.model.waves.crossgate_pet_test=true;army.refresh_kits()
 for node in [game,p,game.camera_rig,game.forest_ui]:
  node.set_process_input(false);node.set_process_unhandled_input(false)
 root.gui_disable_input=true
 driver=load("res://tests/forest-shrine/physics_step_driver.gd").new();root.add_child(driver)
 home.y=game.model.surface_height(home.x,home.z)+.05;game.model.update_vision(home)
 game.training_dummy.position=home+Vector3.DOWN*100
 game.impact_confirmed.connect(func(enemy,_strength,_time):victims.append(enemy.forest_id))
 for id in p.RogueRoster.CROSSGATE:
  p.select_character(id);fresh();game.reset_character_tuning(id);game.update_character_tuning(id,"critical_chance",0)
  if id==37:p.model.select_stance(1)
  p.position=home;p.velocity=Vector3.ZERO;await driver.advance(20,advance)
  army.clear();game.model.enemies.clear();army.refresh_kits();fx.effects.clear();victims.clear()
  var primary=spawn(Vector3(0,0,-3.5));var flank=spawn(Vector3(15,0,-3.5))
  var anchor=primary.combat_bounds().get_center()
  var kit=p.active_ability
  var pool=preload("res://scripts/character_projectile_pool.gd").service(game)
  var shots:Array=[]
  var launched=func(shot):shots.append(shot);shot.set_physics_process(false)
  pool.launched.connect(launched)
  var basic_before=primary.hp
  kit.start_attack()
  for i in 200:
   await driver.advance(1,advance)
   for shot in shots:
    if shot.pool_live:shot._physics_process(DT)
  var native_contacts=victims.count(primary.forest_id)
  check(native_contacts>0 and primary.hp<basic_before,"Fighter %d normal attack has a real contact"%id)
  var before=primary.hp;var flank_before=flank.hp
  kit.cancel(true);kit.clear_cooldowns();p.attack_chain.reset();victims.clear();fx.effects.clear();shots.clear()
  var count_=0;var damages=[];var last_hp=before
  check(p.spell_loadout.equip(id,"special_4",Skills.Catalog.SURE_STRIKE),"Fighter %d equips shared 乾坤 without replacing the default attack"%id)
  check(not p.spell_loadout.instances.has("%d:%s"%[id,Skills.Catalog.SURE_STRIKE]),"Fighter %d uses its own controller rather than a donor animation"%id)
  p.spell_loadout._cast(Skills.Catalog.SURE_STRIKE,"special_4")
  check(kit.clip=="6" and p.model.combo_glow.visible,"Fighter %d starts the body-centred charge"%id)
  check(p.spell_loadout.cooldown_for("special_4")>0,"Shared 乾坤 exposes the current caster's cooldown")
  for i in 200:
   fx.effects.clear()
   await driver.advance(1,advance)
   for shot in shots:
    if shot.pool_live:shot._physics_process(DT)
   army.flush_presentation()
   var bursts=fx.effects.filter(func(row):return row.kind in ["shin_sure_strike","shin_double_edge"])
   count_+=bursts.size()
   for burst in bursts:
    check(burst.position.is_equal_approx(anchor),"Fighter %d explosion comes from the struck body's centre"%id)
   if primary.hp<last_hp:damages.append(last_hp-primary.hp);last_hp=primary.hp
  print("SURE_PATTERN id=",id," native=",native_contacts," powered=",victims.count(primary.forest_id)," explosions=",count_," damage=",damages)
  check(victims.count(primary.forest_id)==native_contacts and count_==native_contacts,"Fighter %d keeps every native contact and emits one explosion per connected hit"%id)
  check(is_equal_approx(before-primary.hp,5000) and damages.all(func(amount):return is_equal_approx(amount,5000.0/native_contacts)),"Fighter %d native contacts share exactly 5,000 base damage"%id)
  check(flank.hp==flank_before,"Fighter %d explosion cannot damage a nearby enemy outside the attack"%id)
  if id in [34,40]:check(native_contacts==2,"Kaz and Bog keep both native strikes")
  pool.launched.disconnect(launched)
 # A visual-only size override cannot widen the sword; misses produce no explosion.
 p.select_character(37);fresh();p.model.select_stance(1);p.position=home;p.velocity=Vector3.ZERO
 rewards.reset();game.reset_character_tuning(37);await driver.advance(20,advance)
 army.clear();game.model.enemies.clear();army.refresh_kits();fx.effects.clear();victims.clear()
 var near=spawn(Vector3(0,0,-3.5));var flank=spawn(Vector3(15,0,-3.5));var kit=p.active_ability
 game.update_skill_balance(Skills.Catalog.SURE_STRIKE,"size",3)
 kit.clear_cooldowns();kit.start_shin_area_cast()
 for i in 120:
  await driver.advance(1,advance)
  if not victims.is_empty():break
 var burst=fx.effects.filter(func(row):return row.kind=="shin_sure_strike")
 check(victims==[near.forest_id] and flank.hp==flank.max_hp,"A triple-size explosion adds no damaging circle")
 check(burst.size()==1 and is_equal_approx(burst[0].scale*232*fx.CONTACT_PIXEL_SIZE,Skills.BASE_DIAMETER*3),"The confirmed-hit explosion keeps the cast's size snapshot")
 kit.cancel(true);army.clear();game.model.enemies.clear();army.refresh_kits();fx.effects.clear();victims.clear()
 kit.clear_cooldowns();kit.start_shin_area_cast();await driver.advance(160,advance)
 check(victims.is_empty() and not fx.effects.any(func(row):return row.kind=="shin_sure_strike"),"An empty attack produces no body explosion")
 # Retirement cannot erase the impact position, and repeated hit events have no fixed burst quota.
 near=spawn(Vector3(0,0,-3.5));var centre=near.combat_bounds().get_center()
 for i in 5:
  var event_ticket=p.attack_chain.make_ticket("shin_sure_strike");event_ticket.sure_strike_size=Skills.BASE_DIAMETER
  near.take_hit(1000,Vector3.FORWARD,false,event_ticket)
  army.flush_presentation()
 check(fx.effects.filter(func(row):return row.kind=="shin_sure_strike").size()==5,"Five real damage events produce five explosions without a fixed one/two limit")
 fx.effects.clear();near.take_hit(2000000,Vector3.FORWARD,false,{"sure_strike_size":Skills.BASE_DIAMETER,"tower":true});army.flush_presentation()
 burst=fx.effects.filter(func(row):return row.kind=="shin_sure_strike")
 check(near.dead and burst.size()==1 and burst[0].position.is_equal_approx(centre),"A lethal hit preserves the victim's body-centre explosion")
 game.reset_skill_balance(Skills.Catalog.SURE_STRIKE)
 spawn(Vector3(0,0,-4))
 rewards.reset();p.select_character(37);fresh();p.position=home;p.velocity=Vector3.ZERO
 p.model.select_stance(1);await driver.advance(20,advance)
 # The charge cue must still obey the existing per-character Sound Studio controls.
 rewards.reset();p.select_character(37);fresh();p.position=home;p.velocity=Vector3.ZERO
 p.model.select_stance(1);await driver.advance(20,advance)
 kit=p.active_ability;var library:SoundLibrary=game.sound_library;library.select_character(37)
 for id in p.RogueRoster.CROSSGATE:
  check(SoundLibrary.slots_for(id).has("cg_combo_charge"),"Cross Gate fighter %d exposes the shared combo charge control"%id)
 kit.cancel(true);kit.clear_cooldowns()
 library.mutes.cg_combo_charge=true
 var order:int=game.voice_idx;kit.start_combo()
 check(kit.is_attacking() and game.voice_idx==order,"Muting the starting shine silences only its audio")
 kit.cancel(true);kit.clear_cooldowns();library.mutes.erase("cg_combo_charge")
 var custom=SoundLibrary.KAZ_SWORD_IMPACTS.hit
 library.custom.cg_combo_charge=custom;library.gains.cg_combo_charge=.5
 kit.start_combo()
 check(game.last_sound_voice.stream==custom and is_equal_approx(db_to_linear(game.last_sound_voice.volume_db),.8*.55*.5),"A recorded charge and its gain still override the recovered shine")
 kit.cancel(true);kit.clear_cooldowns();library.custom.erase("cg_combo_charge");library.gains.erase("cg_combo_charge")
 for voice in game.voices:voice.stop()
 var recorder:AudioEffectRecord;var bus=AudioServer.get_bus_index("SFX");var slot=AudioServer.get_bus_effect_count(bus)
 if DisplayServer.get_name()!="headless":
  recorder=AudioEffectRecord.new();AudioServer.add_bus_effect(bus,recorder);recorder.set_recording_active(true)
 order=game.voice_idx;kit.start_combo()
 check(game.voice_idx==order+1 and game.last_sound_voice.stream==SoundLibrary.CROSSGATE_FLASH,"Restoring defaults plays the original starting shine once")
 if recorder!=null:
  await create_timer(.4).timeout;recorder.set_recording_active(false)
  var recording=recorder.get_recording()
  check(recording!=null and recording.data.count(0)<recording.data.size() and recording.save_to_wav(ProjectSettings.globalize_path(OUT+"combo-starting-shine.wav"))==OK,"The desktop SFX bus records an audible starting shine")
  AudioServer.remove_bus_effect(bus,slot)
 kit.cancel(true);samples.sort()
 print("BLAST_CONTACT_US p95=",samples[floori(samples.size()*.95)]," max=",samples.back())
 game.queue_free();paused=false;await frames(3)
 if FileAccess.file_exists(cfg):DirAccess.remove_absolute(ProjectSettings.globalize_path(cfg))
 print("CROSSGATE_BLAST_COVERAGE_RESULT checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)
