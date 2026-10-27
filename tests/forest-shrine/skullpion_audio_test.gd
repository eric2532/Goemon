extends "res://scripts/recovered_goemon_gameplay_tests.gd"
const OUT="res://build/Other Files/Asset Toolkit/Skullpion/Playable Audio/"
var recorder:AudioEffectRecord
func advance(count:int):
 for i in count:
  game.player._physics_process(1.0/60)
  await physics_frame
func latest(slot:String,stream:AudioStream)->bool:
 return game.last_sound_voice.get_meta("kind","")==slot and game.last_sound_voice.stream==stream and game.last_sound_voice.pitch_scale==1.0
func run():
 create_timer(120).timeout.connect(func():printerr("SKULLPION_AUDIO_TIMEOUT");quit(1))
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
 await setup_fixture()
 game.set_process(false);game.army_runtime.set_physics_process(false);game.music.stop()
 var p=game.player;var lib=game.sound_library
 p.select_character(27);fresh();await advance(4)
 var expected={}
 for slot in SoundLibrary.SKULLPION_FILES:
  expected[slot]=load("res://assets/characters/recovered_skullpion/audio/"+SoundLibrary.SKULLPION_FILES[slot]+".wav")
  check(lib.original_for(27,slot)==expected[slot] and game.sound_preview(27,slot)==expected[slot],"Skullpion "+slot+" uses its existing recovered sample in gameplay and Studio")
 if DisplayServer.get_name()!="headless":
  recorder=AudioEffectRecord.new();recorder.format=AudioStreamWAV.FORMAT_16_BITS
  AudioServer.add_bus_effect(AudioServer.get_bus_index("SFX"),recorder);recorder.set_recording_active(true)
 tap("jump");await advance(4)
 check(p.velocity.y>0 and latest("jump",expected.jump),"Actual Space jump plays the recovered sweep at source pitch")
 await advance(90)
 p.progression.reset(true);var before=p.progression.level;p.award_kill()
 check(p.progression.level==before+1 and latest("spark",expected.spark),"Kill-earned level plays recovered core recovery instead of the prototype chime")
 game.tuning.invincible=false;p.invuln=0;p.hp=p.max_hp;p.take_hit(1,Vector3.ZERO)
 check(game.last_sound_voice.stream==game.sounds.hurt,"Skullpion damage retains its previous sound")
 var nodes=get_node_count();var cached=preload("res://scripts/character_audio_bank.gd").streams.size()
 for i in 100:
  p.play_sound("jump");p.play_sound("spark")
 check(get_node_count()==nodes and preload("res://scripts/character_audio_bank.gd").streams.size()==cached,"Repeated cues reuse prepared streams and the existing voices")
 lib.select_character(27);lib.gains.jump=.4;p.play_sound("jump")
 check(is_equal_approx(db_to_linear(game.last_sound_voice.volume_db),.55*.4),"Recovered jump honors Studio gain")
 lib.mutes.jump=true;var serial=game.voice_idx;p.play_sound("jump")
 check(game.voice_idx==serial,"Recovered jump honors Studio mute");lib.mutes.erase("jump")
 lib.custom.jump=expected.spark;p.play_sound("jump")
 check(game.last_sound_voice.stream==expected.spark,"User recordings retain priority");lib.custom.erase("jump")
 check(lib.original_for(3,"jump")==null and game.sounds.jump==load("res://audio/jump.wav"),"Other fighters retain their existing defaults")
 p.invuln=0;p.hp=1;p.take_hit(100000,Vector3.ZERO)
 check(p.hp==0 and game.last_sound_voice.stream==game.sounds.hurt,"Skullpion death retains its previous sound")
 if recorder:
  await create_timer(1).timeout;recorder.set_recording_active(false)
  var audio=recorder.get_recording()
  check(audio!=null and audio.data.count(0)<audio.data.size(),"Desktop SFX mixer contains the recovered cues")
  if audio:audio.save_to_wav(OUT+"playback.wav")
 game.sound_library.cancel();game.music.stop();game.move_audio.stop();game.queue_free();current_scene=null
 await frames(4)
 print("SKULLPION_AUDIO_RESULT checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)
