extends "res://scripts/character_sound_tests.gd"
## Real WAV/config and mixer capture; never records private microphone input.
const OUT="res://build/Other Files/Asset Toolkit/Sound Studio Defaults/"
func reload_library():
 lib.game=null;lib.free();lib=new_library();lib.game=game;game.sound_library=lib
func run():
 DirAccess.make_dir_recursive_absolute(sandbox)
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
 lib=new_library();game=AudioGame.new();root.add_child(game);game.setup_audio()
 game.player=Hero.new();game.sound_library=lib;lib.game=game;game.settings.volume=.65
 var wav=fixture()
 # Previously ignored files must not suddenly replace the current defaults.
 for id in [1,16,17]:
  var directory=lib._profile_folder(id);DirAccess.make_dir_recursive_absolute(directory)
  wav.save_to_wav(directory+"/jump.wav")
 reload_library()
 for id in [1,16,17]:
  check(lib.custom_for(id,"jump")==null and FileAccess.file_exists(lib._profile_folder(id)+"/jump.wav") and game.sound_preview(id,"jump")==game.sound_default(id,"jump"),"Old inactive take is preserved while the current default remains selected: %d"%id)
 for entry in [[1,"move_primary_1_weapon"],[16,"move_primary_1_weapon"],[17,"move_primary_1_weapon"],[30,"finale_wind_loop"]]:
  var id:int=entry[0];var slot:String=entry[1]
  lib.select_character(id);game.player.character_id=id
  var built_in=game.sound_preview(id,slot)
  check(built_in!=null,"Current built-in default exists: %d/%s"%[id,slot])
  check(save(slot,wav),"Save a take: %d/%s"%[id,slot])
  check(lib.stream_for(id,slot,null)==wav and lib.playback_for(id,slot,null).recorded,"Direct and pooled audio select the saved take: %d"%id)
  check(game.sound_preview(id,slot)==wav,"Studio preview selects the same saved take: %d"%id)
  var order=game.voice_idx;game.sound(slot,1,false,{},id)
  check(game.voice_idx==order+1 and game.last_sound_voice.stream==wav and game.last_sound_voice.pitch_scale==1,"Actual game dispatcher plays the recorded sound: %d"%id)
  lib.set_gain(slot,.4);lib.set_muted(slot,true);lib.reset_slot(slot)
  var restored=lib.playback_for(id,slot,null)
  check(game.sound_preview(id,slot)==built_in and restored.gain==1 and not restored.muted,"Restore returns the current default and clears its volume/mute: %d"%id)
  reload_library();lib.select_character(id)
  check(lib.custom_for(id,slot)==null and game.sound_preview(id,slot)==built_in,"Default survives restart: %d"%id)
  check(save(slot,wav),"A new recording can replace a restored default: %d"%id)
  reload_library();lib.select_character(id)
  check(lib.custom_for(id,slot)!=null and lib.playback_for(id,slot,null).recorded,"New take survives restart after Restore: %d"%id)
  lib.reset_slot(slot)
 # Sustained recordings are prepared once; one-shot previews remain finite.
 lib.select_character(30);save("finale_wind_loop",wav)
 var loop=lib.recorded_loop_for(30,"finale_wind_loop",null)
 check(loop!=wav and loop.loop_mode==AudioStreamWAV.LOOP_FORWARD and loop.loop_end>0 and wav.loop_mode==AudioStreamWAV.LOOP_DISABLED,"Wind uses an owned prepared loop without changing its one-shot recording")
 var resources=Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)
 var reused=true
 for repeat in 100:reused=reused and lib.recorded_loop_for(30,"finale_wind_loop",null)==loop
 check(reused,"Repeated sustain lookup reuses the prepared recording")
 check(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)==resources,"Repeated recorded sustain lookup creates no resources")
 lib.reset_slot("finale_wind_loop")
 check(lib.recorded_loop_for(30,"finale_wind_loop",null)==null,"Restore releases the prepared custom loop")
 # Source-silent defaults may still be customized deliberately.
 for entry in [[16,"move_primary_2_voice"],[17,"move_utility_voice"],[30,"step"]]:
  var id:int=entry[0];var slot:String=entry[1]
  lib.select_character(id);game.player.character_id=id
  check(game.sound_preview(id,slot)==null,"Silent default remains silent: %d/%s"%[id,slot])
  save(slot,wav);var order=game.voice_idx;game.sound(slot,1,false,{},id)
  check(game.voice_idx==order+1 and game.sound_preview(id,slot)==wav and game.last_sound_voice.stream==wav,"Recording overrides a silent default: %d/%s"%[id,slot])
  lib.reset_slot(slot)
  check(game.sound_preview(id,slot)==null,"Restore returns to silence: %d/%s"%[id,slot])
 # Restoring one move must not fall back to an old shared recording or mute.
 lib.select_character(5);game.player.character_id=5
 var built_in=game.sound_preview(5,"move_primary_1_weapon")
 save("native_blade",wav);lib.set_gain("native_blade",.25);lib.set_muted("native_blade",true)
 save("move_primary_1_weapon",fixture(22050));lib.reset_slot("move_primary_1_weapon")
 var restored=lib.playback_for(5,"move_primary_1_weapon",built_in)
 check(not restored.recorded and restored.stream==built_in and restored.gain==1 and not restored.muted,"Restore bypasses inherited recordings, gain and mute for this move")
 check(lib.custom_for(5,"native_blade")==wav and lib.is_muted_for(5,"native_blade"),"Restoring one move preserves the shared recording and other moves")
 reload_library();lib.select_character(5)
 restored=lib.playback_for(5,"move_primary_1_weapon",built_in)
 check(not restored.recorded and restored.stream==built_in and restored.gain==1 and not restored.muted,"Exact default selection survives profile reload")
 var before=FileAccess.get_file_as_bytes(lib._profile_folder(5)+"/native_blade.wav")
 lib.take=wav;lib.take_slot="../invalid"
 check(not lib.save_take() and FileAccess.get_file_as_bytes(lib._profile_folder(5)+"/native_blade.wav")==before,"Invalid slot cannot alter an existing recording")
 lib.discard()
 check(lib.has_method("studio_slots_for"),"Studio has a current editable catalog while retaining legacy profile compatibility")
 if lib.has_method("studio_slots_for"):
  for id in lib.Roster.selection_ids():
   var visible=lib.studio_slots_for(id)
   check(not visible.has("enemy_reaction") and not visible.has("kojiro_unused_a83") and not visible.has("kojiro_unused_a84"),"Studio excludes retired/unused cues: %d"%id)
   for key in lib.moves_for(id):
    var move=lib.moves_for(id)[key]
    var obsolete=(id==14 and key in ["primary_2","primary_3"]) or (id==15 and key=="primary_3")
    check((not visible.has(move.weapon) and not visible.has(move.voice)) if obsolete else (visible.has(move.weapon) and visible.has(move.voice) and not visible.has(move.legacy)),"Catalog matches current move: %d/%s"%[id,key])
 if DisplayServer.get_name()!="headless":
  lib.select_character(30);game.player.character_id=30
  lib.configure_capture();lib.mic.stream=wav
  var sfx=AudioServer.get_bus_index("SFX");var prior_mute=AudioServer.is_bus_mute(sfx)
  check(lib.begin("finale_wind_loop") and AudioServer.is_bus_mute(sfx),"Recording captures the selected slot while game SFX are muted")
  await create_timer(.4).timeout;lib.finish()
  check(lib.take!=null and not lib.recording and not lib.mic.playing and AudioServer.is_bus_mute(sfx)==prior_mute,"Stop produces real captured PCM, closes input and restores SFX")
  if lib.take:
   lib.take.save_to_wav(OUT+"captured-synthetic-take.wav")
   check(lib.save_take(),"Captured take saves through the normal recording path")
   game.sound("finale_wind_loop",1,false,{},30)
   check(game.last_sound_voice.stream==lib.custom_for(30,"finale_wind_loop"),"Captured take reaches actual gameplay")
   lib.reset_slot("finale_wind_loop")
   check(game.sound_preview(30,"finale_wind_loop")==lib.original_for(30,"finale_wind_loop"),"Captured take can always return to current Wind default")
 for voice in game.voices:voice.stop()
 lib.game=null;lib.free();game.sound_library=null;game.player.free();game.player=null;game.free()
 var report={"checks":checks,"failures":failures,"desktop":DisplayServer.get_name()!="headless","private_microphone_sampled":false}
 FileAccess.open(OUT+("desktop" if report.desktop else "headless")+".json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
 print("RECORDING_DEFAULTS_RESULT ",report)
 finish()
