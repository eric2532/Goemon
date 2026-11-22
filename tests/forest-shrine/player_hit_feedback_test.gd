extends "res://scripts/recovered_goemon_gameplay_tests.gd"
const OUT="res://build/Other Files/Asset Toolkit/Player Hit Feedback/"
var driver
var timings=[]
var hidden_frames=0
var home=ORIGIN
func fresh(surge:bool=false):
 super.fresh(surge)
 game.player.position=home
func advance(count:int):
 await driver.advance(count,func(dt):
  var started=Time.get_ticks_usec()
  game.player._physics_process(dt)
  game.crowd.army.presentation.tick(dt)
  timings.append((Time.get_ticks_usec()-started)/1000.0)
  if not game.player.model.visible:hidden_frames+=1)
func capture(name_:String):
 if DisplayServer.get_name()=="headless":return
 await RenderingServer.frame_post_draw
 check(root.get_texture().get_image().save_png(OUT+name_+".png")==OK,"Capture player contact: "+name_)
func run():
 create_timer(180).timeout.connect(func():printerr("PLAYER_HIT_FEEDBACK_TIMEOUT");quit(1))
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
 var document=load("res://scripts/forest/forest_map_document.gd").new()
 check(document.load_wind_meadow()=="","Use the bundled Falan Arena")
 await setup_fixture(document.data)
 home.y=game.model.surface_height(home.x,home.z)+.1
 game.training_dummy.hide();game.training_dummy.collision_layer=0
 game.camera_rig.camera.position=home+Vector3(4,4,8)
 game.camera_rig.camera.look_at(home+Vector3.UP*1.2)
 game.set_process(false);game.army_runtime.set_physics_process(false);game.army_runtime.set_process(false)
 game.explorer_helpers.set_process(false);game.camera_focused=false;game._sync_camera_mouse();game.music.stop()
 for node in [game,game.player,game.camera_rig]:
  node.set_process_input(false);node.set_process_unhandled_input(false)
 game.ui.hide();game.tuning.invincible=false
 driver=load("res://tests/forest-shrine/physics_step_driver.gd").new();root.add_child(driver)
 var p=game.player
 var fx=game.crowd.army.presentation
 for id in p.RogueRoster.CROSSGATE:
  p.select_character(id);fresh();p.hp=p.max_hp
  game.camera_rig.first_person_mode=false
  if p.RogueRoster.has_kagerou(id):p.active_ability.kagerou_enabled=false
  await advance(6);fx.clear();hidden_frames=0
  var hp_before:float=p.hp
  p.take_hit(2,Vector3.BACK)
  check(game.last_sound_voice.get_meta("kind","")=="hurt" and is_equal_approx(db_to_linear(game.last_sound_voice.volume_db),1.8*.55),"Incoming damage uses the louder hurt cue for %d"%id)
  var gold=fx.effects.filter(func(row):return row.kind in fx.GOLD_SPARKS)
  check(p.hp<hp_before and is_equal_approx(p.invuln,.85),"Real damage retains the invulnerability window for %d"%id)
  check(gold.size()==1 and is_equal_approx(gold[0].scale,p.hit_effect_scale()),"Damage emits one existing gold impact at the fighter's size for %d"%id)
  check(gold.size()==1 and gold[0].anchor.get_ref()==p,"The impact follows the knocked-back fighter for %d"%id)
  var hp_after:float=p.hp
  var count_before=fx.effects.size()
  var sound_before=game.voice_idx
  p.take_hit(2,Vector3.LEFT,true)
  check(p.hp==hp_after and fx.effects.size()==count_before,"An immune projectile adds no damage or impact for %d"%id)
  check(game.voice_idx==sound_before,"An immune projectile adds no hurt sound for %d"%id)
  await advance(4)
  await capture("fighter-%d"%id)
  if not gold.is_empty():
   var batch=fx.batches[gold[0].kind].multimesh
   var alpha=batch.get_instance_custom_data(0).g
   game.settings.reduced_flashes=true;fx.draw_effects()
   check(is_equal_approx(batch.get_instance_custom_data(0).g,alpha*.35),"Player impacts respect Reduced Flashes for %d"%id)
   game.settings.reduced_flashes=false;fx.draw_effects()
  await advance(55)
  check(hidden_frames==0 and p.invuln==0,"The fighter stays visible through the whole recovery for %d"%id)
  check(fx.effects.is_empty(),"The player impact expires for %d"%id)
 p.select_character(34);fresh();await advance(60);fx.clear()
 var lib=game.sound_library
 lib.select_character(34);lib.gains.hurt=.4;lib.custom.hurt=SoundLibrary.BLADE_IMPACTS.hit
 p.hp=p.max_hp;p.invuln=0;p.take_hit(1,Vector3.BACK)
 check(game.last_sound_voice.stream==SoundLibrary.BLADE_IMPACTS.hit and is_equal_approx(db_to_linear(game.last_sound_voice.volume_db),1.8*.55*.4),"Incoming hit keeps the saved recording and gain")
 lib.mutes.hurt=true;var serial=game.voice_idx
 p.invuln=0;p.take_hit(1,Vector3.BACK)
 check(game.voice_idx==serial,"Incoming hit keeps the saved mute")
 lib.mutes.erase("hurt");lib.gains.erase("hurt");lib.custom.erase("hurt")
 p.invuln=0;p.dodge_time=.1;serial=game.voice_idx
 var dodge_hp:float=p.hp
 p.take_hit(1,Vector3.BACK)
 check(p.hp==dodge_hp and game.voice_idx==serial,"A dodged enemy strike stays silent")
 p.dodge_time=0
 await advance(60);fx.clear()
 if DisplayServer.get_name()!="headless":
  for voice in game.voices:voice.stop()
  var recorder=AudioEffectRecord.new();recorder.format=AudioStreamWAV.FORMAT_16_BITS
  var bus=AudioServer.get_bus_index("SFX");AudioServer.add_bus_effect(bus,recorder)
  recorder.set_recording_active(true)
  p.hp=p.max_hp;p.invuln=0;p.take_hit(1,Vector3.BACK)
  await advance(60);recorder.set_recording_active(false)
  var wav=recorder.get_recording()
  check(wav!=null and wav.data.count(0)<wav.data.size(),"Desktop mixer records the louder incoming hit")
  if wav!=null:check(wav.save_to_wav(OUT+"louder-incoming-hit.wav")==OK,"Save incoming hit for listening")
  AudioServer.remove_bus_effect(bus,AudioServer.get_bus_effect_count(bus)-1)
  fx.clear()
 var nodes=get_node_count();var resources=Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)
 for repeat in 12:
  p.hp=p.max_hp;p.invuln=0;p.take_hit(1,Vector3.BACK)
  await advance(60)
 check(get_node_count()<=nodes and Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)<=resources,"Repeated incoming hits reuse the prepared nodes and resources")
 timings.sort()
 var report={"checks":checks,"failures":failures,"samples":timings.size(),"step_p95_ms":timings[int(timings.size()*.95)],"step_max_ms":timings[-1],"node_delta":get_node_count()-nodes,"resource_delta":Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)-resources}
 FileAccess.open(OUT+DisplayServer.get_name()+".json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
 print("PLAYER_HIT_FEEDBACK_RESULT ",JSON.stringify(report))
 game.queue_free();current_scene=null;await frames(4)
 if FileAccess.file_exists(cfg):DirAccess.remove_absolute(ProjectSettings.globalize_path(cfg))
 quit(1 if failures else 0)
