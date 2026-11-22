extends "res://scripts/recovered_goemon_gameplay_tests.gd"
const RECOVERED=preload("res://assets/characters/recovered_skullpion/audio/core_recover.wav")
const LEVEL_UP=preload("res://assets/audio/crossgate/cgsys12.wav")
const OUT="res://build/Other Files/Asset Toolkit/Cross Gate Level Up/"
func run():
 create_timer(180).timeout.connect(func():printerr("SHARED_KILL_AUDIO_TIMEOUT");quit(1))
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
 await setup_fixture()
 game.set_process(false);game.army_runtime.set_physics_process(false);game.music.stop()
 var p=game.player;var lib=game.sound_library
 var recorder:AudioEffectRecord
 if DisplayServer.get_name()!="headless":
  recorder=AudioEffectRecord.new();recorder.format=AudioStreamWAV.FORMAT_16_BITS
  AudioServer.add_bus_effect(AudioServer.get_bus_index("SFX"),recorder);recorder.set_recording_active(true)
 for id in SoundLibrary.Roster.PLAYABLE_IDS:
  var original=lib.original_for(id,"spark")
  var expected=original if original!=null else RECOVERED
  var before=game.voice_idx
  game.sound("spark",.5,false,{},id)
  if SoundLibrary.source_slot_is_silent(id,"spark"):
   check(game.voice_idx==before,"Character %d retains intentional source silence"%id)
  else:
   check(game.last_sound_voice.stream==expected and game.last_sound_voice.pitch_scale==1.0 and game.sound_preview(id,"spark")==expected,"Character %d uses recovered reward audio in playback and Studio"%id)
  game.sound("team_level_up",.8,false,{},id)
  check(game.last_sound_voice.stream==LEVEL_UP and game.last_sound_voice.pitch_scale==1.0,"Character %d receives the same Cross Gate team level cue"%id)
 for id in [5,8,13,27,29,30]:
  p.select_character(id);fresh();p.team_progression.reset();p.team_progression.award_kills(p.team_progression.kills_required()-1)
  var enemy_id=100000+id
  var point=ORIGIN+Vector3(0,0,-10)
  game.army_runtime.spawn(enemy_id,0,0,point,10,0)
  game.model.enemies[enemy_id]={"id":enemy_id,"hp":10,"max_hp":10,"pos":point,"variant":0,"ryo_dropped":true}
  var actor=game.army_runtime.enemy_target(enemy_id)
  var kills=game.kills
  actor.take_hit(1000,Vector3.FORWARD,true,{"action":"special","projectile":true,"source_hero":weakref(p)})
  game.army_runtime.dispatch_events()
  check(game.kills==kills+1 and p.team_progression.level==2 and p.progression.level==1 and game.last_sound_voice.stream==LEVEL_UP,"Character %d native special-projectile kill uses Cross Gate team level-up"%id)
 var nodes=get_node_count();var serial=game.voice_idx
 for i in 100:p.award_kill()
 check(get_node_count()==nodes and game.voice_idx>serial,"Repeated kill rewards reuse the existing voice pool")
 lib.select_character(30);lib.gains.spark=.4;p.play_sound("spark",.5)
 check(is_equal_approx(db_to_linear(game.last_sound_voice.volume_db),.5*.55*.4),"Shared reward respects per-character gain")
 lib.mutes.spark=true;serial=game.voice_idx;p.play_sound("spark")
 check(game.voice_idx==serial,"Shared reward respects mute");lib.mutes.erase("spark")
 lib.custom.spark=game.sounds.hurt;p.play_sound("spark")
 check(game.last_sound_voice.stream==game.sounds.hurt,"Shared reward preserves user recording priority");lib.custom.erase("spark")
 check(lib.original_for(1,"move_surge_weapon")==load("res://assets/audio/recovered_goemon/golden_weapon.wav"),"Goemon's recovered special-attack sound retains priority")
 for voice in game.voices:voice.stop()
 game.move_audio.stop()
 if recorder:
  recorder.set_recording_active(false);recorder.set_recording_active(true)
 check(LEVEL_UP.format==AudioStreamWAV.FORMAT_16_BITS and LEVEL_UP.mix_rate==22050 and not LEVEL_UP.stereo and LEVEL_UP.data.size()==79590,"The full original Cross Gate PCM sample imports losslessly")
 p.team_progression.reset();var before_level=game.voice_idx
 p.award_kill()
 check(game.voice_idx==before_level,"An ordinary kill does not play the level-up cue")
 p.team_progression.award_kills(p.team_progression.kills_required()-2);p.award_kill()
 var level_voice=game.last_sound_voice
 check(game.voice_idx==before_level+1 and level_voice.stream==LEVEL_UP,"Crossing the XP threshold plays exactly one Cross Gate cue")
 game.show_team_upgrade()
 check(paused and game.team_upgrade_picker!=null and level_voice.can_process(),"The level-up voice continues while the three-card choice pauses combat")
 if recorder:
  await create_timer(LEVEL_UP.get_length()+.15).timeout;recorder.set_recording_active(false)
  var audio=recorder.get_recording()
  check(audio!=null and audio.data.count(0)<audio.data.size(),"Desktop mixer contains the Cross Gate level-up cue")
  if audio:audio.save_to_wav(OUT+"cgsys12-playback.wav")
  AudioServer.remove_bus_effect(AudioServer.get_bus_index("SFX"),AudioServer.get_bus_effect_count(AudioServer.get_bus_index("SFX"))-1)
 game.sound_library.cancel();game.move_audio.stop();game.queue_free();current_scene=null;paused=false;await frames(4)
 print("SHARED_KILL_AUDIO_RESULT checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)
