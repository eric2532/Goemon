extends "res://scripts/recovered_goemon_gameplay_tests.gd"
const RECOVERED=preload("res://assets/audio/recovered_yae/event_21d.wav")
const Bank=preload("res://scripts/character_audio_bank.gd")
const OUT="res://build/Other Files/Asset Toolkit/Shared Jump Audio/"
var jumps=[]

func advance(count:int):
 for i in count:
  var serial=game.voice_idx
  game.player._physics_process(1.0/60)
  for voice in game.voices:
   if voice.get_meta("order",-1)>serial and voice.get_meta("kind","")=="jump":
    jumps.append([voice.stream,voice.pitch_scale])
  await physics_frame

func run():
 create_timer(120).timeout.connect(func():printerr("SHARED_JUMP_AUDIO_TIMEOUT");quit(1))
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
 await setup_fixture()
 game.set_process(false);game.army_runtime.set_physics_process(false);game.music.stop()
 game.camera_rig.camera.position=ORIGIN+Vector3(25,20,45)
 game.camera_rig.camera.look_at(ORIGIN+Vector3(0,9.6,0))
 var p=game.player;var lib=game.sound_library
 check(game.sounds.jump==RECOVERED and not Bank.streams.has("res://audio/jump.wav"),"Startup replaces the prototype beep without loading it")
 for id in SoundLibrary.Roster.PLAYABLE_IDS:
  var own=lib.original_for(id,"jump")
  var expected=own if own!=null else RECOVERED
  var serial=game.voice_idx
  game.sound("jump",.5,false,{},id)
  if SoundLibrary.source_slot_is_silent(id,"jump"):
   check(game.voice_idx==serial and game.sound_preview(id,"jump")==null,"Fighter %d retains authored jump silence"%id)
  else:
   check(game.last_sound_voice.stream==expected and game.last_sound_voice.pitch_scale==1 and game.sound_preview(id,"jump")==expected and lib.stream_for(id,"jump",null)==expected,"Fighter %d uses its recovered jump or shared event 21D in gameplay and Studio"%id)
 for voice in game.voices:voice.stop()
 var recorder:AudioEffectRecord
 var bus=AudioServer.get_bus_index("SFX")
 if DisplayServer.get_name()!="headless":
  recorder=AudioEffectRecord.new();recorder.format=AudioStreamWAV.FORMAT_16_BITS
  AudioServer.add_bus_effect(bus,recorder);recorder.set_recording_active(true)
 for id in [31,32]:
  p.select_character(id);p.set_scarf_equipped(false)
  for repeat in 3:
   fresh();p.jumps_used=0;p.jump_windup=0;p.jump_buffer=0
   await advance(6);jumps.clear()
   check(p.is_on_floor(),"Fighter %d repeat %d starts grounded"%[id,repeat])
   tap("jump");await advance(8)
   check(p.jumps_used==1 and p.velocity.y>0 and jumps.size()==1,"Space launches fighter %d repeat %d with one cue"%[id,repeat])
   tap("jump");await advance(3)
   check(p.jumps_used==2 and jumps.size()==2 and jumps.all(func(cue):return cue==[RECOVERED,1.0]),"Fighter %d repeat %d ground/double jumps both use recovered event 21D"%[id,repeat])
  if recorder:
   RenderingServer.force_draw()
   check(root.get_texture().get_image().save_png(OUT+"jump-%d.png"%id)==OK,"Capture fighter %d jumping"%id)
 if recorder:
  await create_timer(.2).timeout;recorder.set_recording_active(false)
  var audio=recorder.get_recording()
  check(audio!=null and audio.data.count(0)<audio.data.size(),"Desktop mixer records non-silent jump output")
  if audio:check(audio.save_to_wav(OUT+"playback.wav")==OK,"Save real jump audio for listening")
  AudioServer.remove_bus_effect(bus,AudioServer.get_bus_effect_count(bus)-1)
 lib.select_character(32);lib.gains.jump=.4;p.play_sound("jump",.5)
 check(game.last_sound_voice.stream==RECOVERED and is_equal_approx(db_to_linear(game.last_sound_voice.volume_db),.5*.55*.4),"Shared jump respects character gain")
 lib.mutes.jump=true;var serial=game.voice_idx;p.play_sound("jump")
 check(game.voice_idx==serial,"Shared jump respects mute");lib.mutes.erase("jump")
 lib.custom.jump=game.sounds.hurt;p.play_sound("jump")
 check(game.last_sound_voice.stream==game.sounds.hurt,"User recording still overrides the shared jump");lib.custom.erase("jump")
 p.play_sound("jump")
 check(game.last_sound_voice.stream==RECOVERED,"Removing a take restores the recovered default")
 var nodes=get_node_count();var resources=Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT);var cached=Bank.streams.size()
 for i in 1000:
  for id in [31,32]:game.sound("jump",.5,false,{},id)
 check(get_node_count()==nodes and Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)==resources and Bank.streams.size()==cached,"2,000 overlapping jumps reuse existing voices and resources")
 game.sound_library.cancel();game.move_audio.stop();game.queue_free();current_scene=null;await frames(4)
 if FileAccess.file_exists(cfg):DirAccess.remove_absolute(ProjectSettings.globalize_path(cfg))
 print("SHARED_JUMP_AUDIO_RESULT checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)
