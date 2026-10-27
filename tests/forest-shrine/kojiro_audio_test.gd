extends "res://scripts/recovered_goemon_gameplay_tests.gd"
const Audio=preload("res://scripts/kojiro_audio.gd")
const Pool=preload("res://scripts/character_projectile_pool.gd")
const Shot=preload("res://scripts/kojiro_projectile.gd")
const OUT="res://build/Other Files/Asset Toolkit/Kojiro/Audio Correction/"
var heard=[]
var order=0
var recorder:AudioEffectRecord
var intervals=[]

func advance(count:int):
 for i in count:
  var start=Time.get_ticks_usec()
  game.player._physics_process(1.0/60)
  for nodes in Pool.service(game).all.values():
   for shot in nodes:
    if shot.pool_live and shot.get_script()==Shot:shot._physics_process(1.0/60)
  for voice in game.voices:
   if int(voice.get_meta("order",0))>order:
    heard.append(str(voice.get_meta("kind")))
    check(voice.pitch_scale==1,"Emitted %s retains prepared pitch"%voice.get_meta("kind"))
  order=game.voice_idx
  intervals.append((Time.get_ticks_usec()-start)/1000.0)
  if DisplayServer.get_name()!="headless":await physics_frame
  elif i%30==0:await process_frame

func begin_capture():
 for voice in game.voices:voice.stop()
 heard.clear();order=game.voice_idx
 if recorder:recorder.set_recording_active(true)

func end_capture(label_:String):
 if recorder==null:return
 await create_timer(.65).timeout
 recorder.set_recording_active(false)
 var recording=recorder.get_recording()
 check(recording!=null and recording.data.count(0)<recording.data.size(),"Desktop mixer emits %s audio"%label_)
 if recording:check(recording.save_to_wav(OUT+label_+".wav")==OK,"Save %s for listening"%label_)

func run():
 create_timer(180).timeout.connect(func():printerr("KOJIRO_AUDIO_TIMEOUT");quit(1))
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
 await setup_fixture()
 game.set_process(false);game.army_runtime.set_physics_process(false)
 game.settings.volume=1;game.settings.music_enabled=false;game.apply_music_setting()
 var p=game.player;var lib=game.sound_library
 p.select_character(28);fresh();game.tuning.invincible=true
 Pool.service(game).launched.connect(func(shot):shot.set_physics_process(false))
 await advance(12)
 if DisplayServer.get_name()!="headless":
  recorder=AudioEffectRecord.new();recorder.format=AudioStreamWAV.FORMAT_16_BITS
  AudioServer.add_bus_effect(AudioServer.get_bus_index("SFX"),recorder)
 var combat=p.active_ability
 for slot in ["kojiro_homing_voice","kojiro_air_cut_voice","kojiro_wave_voice","kojiro_wind_voice"]:
  var stream=Audio.stream_for(slot)
  check(stream.get_length()<.33 and stream==Audio.stream_for(slot),"%s is the short cached duel voice"%slot)
  check(game.sound_preview(28,slot)==stream,"Studio previews the same %s"%slot)
 for cut in 3:
  combat.combo_timer=1 # Keep the chain while the capture tail plays.
  begin_capture();tap("light_attack");await advance(45)
  check(combat.combo==cut,"Click advances grounded cut %d"%(cut+1))
  check(heard.count("kojiro_sword_cut")==1,"Grounded cut %d has exactly one sword cue"%(cut+1))
  check(heard.count("hit")==1,"Grounded cut %d has a separate confirmed contact"%(cut+1))
  if cut>0:check(heard.count("kojiro_air_cut_voice" if cut==1 else "kojiro_air_spin_voice")==1,"Prepared grounded motion retains its matching duel voice")
  await end_capture("ground-cut-%d"%(cut+1))
 for action in ["air_cut","air_spin","homing","wave","wind"]:
  combat.cancel();p.position=ORIGIN;p.impact_pause=0
  begin_capture();combat.start_skill(action);await advance(90)
  check(heard.count("kojiro_"+action+"_voice")==1,"%s emits one matching voice"%action)
  check(heard.count("kojiro_sword_cut" if action.begins_with("air_") else "kojiro_"+action+"_release")==1,"%s emits one matching cut/release"%action)
  await end_capture(action)
 await advance(200)
 lib.select_character(28)
 var take=Audio.stream_for("kojiro_wave_voice")
 for slot in ["kojiro_sword_cut","kojiro_homing_release","hit"]:
  lib.custom[slot]=take;lib.gains[slot]=.5;game.sound(slot,.8,false,{},28)
  check(game.last_sound_voice.stream==take,"Saved %s recording retains priority"%slot)
  check(is_equal_approx(db_to_linear(game.last_sound_voice.volume_db),.8*.55*.5*(.45 if slot=="hit" else 1)),"%s respects saved gain"%slot)
  lib.mutes[slot]=true;var before=game.voice_idx;game.sound(slot,.8,false,{},28)
  check(game.voice_idx==before,"%s mute suppresses playback"%slot)
  lib.custom.erase(slot);lib.gains.erase(slot);lib.mutes.erase(slot)
 # Borrowed spells retain Kojiro's audio owner after fighter selection changes.
 p.select_character(1);fresh();await advance(12)
 for action in ["homing","wave","wind"]:
  check(p.spell_loadout.equip(1,"equip","kojiro/"+action),"Equip borrowed "+action)
  begin_capture();tap("equip");await advance(100)
  check(heard.count("kojiro_"+action+"_voice")==1 and heard.count("kojiro_"+action+"_release")==1,"Borrowed %s keeps both corrected sounds"%action)
  p.spell_loadout.cancel();await advance(200)
  if recorder:recorder.set_recording_active(false)
 p.spell_loadout.equip(1,"equip","");p.select_character(28);fresh();await advance(12)
 combat=p.active_ability;combat.cancel()
 begin_capture();combat.start_skill("slash");combat.cancel();await advance(45)
 check(not heard.has("kojiro_sword_cut"),"Cancelling before contact emits no delayed cut")
 if recorder:recorder.set_recording_active(false)
 for voice in game.voices:voice.stop()
 await create_timer(1).timeout;await frames(2)
 var nodes=get_node_count();var resources=Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)
 var cache_size=preload("res://scripts/character_audio_bank.gd").streams.size()
 for repeat in 100:
  game.sound("kojiro_sword_cut",.8,false,{},28);game.sound("hit",.8,false,{},28)
  for action in ["homing","wave","wind"]:combat.sound(action+"_voice");combat.sound(action+"_release")
 for voice in game.voices:voice.stop()
 await frames(2)
 check(get_node_count()==nodes and Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)==resources,"800 overlapping audio events reuse the same voices and resources")
 check(preload("res://scripts/character_audio_bank.gd").streams.size()==cache_size,"Repeated attacks do not load more audio assets")
 if recorder:AudioServer.remove_bus_effect(AudioServer.get_bus_index("SFX"),AudioServer.get_bus_effect_count(AudioServer.get_bus_index("SFX"))-1)
 intervals.sort()
 FileAccess.open(OUT+"checks.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"renderer":RenderingServer.get_video_adapter_name(),"manual_step_p95_ms":intervals[int(intervals.size()*.95)],"scope":"Audio routing/capture and bounded reuse; not a full-wave FPS benchmark."},"  "))
 game.queue_free();game=null;paused=false;await frames(3)
 if FileAccess.file_exists(cfg):DirAccess.remove_absolute(ProjectSettings.globalize_path(cfg))
 print("KOJIRO_AUDIO_RESULT checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)
