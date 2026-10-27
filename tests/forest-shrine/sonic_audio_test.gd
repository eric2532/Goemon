extends "res://scripts/recovered_goemon_gameplay_tests.gd"
const SonicAudio=preload("res://scripts/sonic_audio.gd")
const EVIDENCE="res://build/Other Files/Asset Toolkit/Sonic/Audio Integration/"
var home:Vector3
var capture:AudioEffectCapture

func _initialize():
 create_timer(180).timeout.connect(func():printerr("FAIL: Sonic audio timeout");quit(1))
 run.call_deferred()

func stop_audio():
 for voice in game.voices:voice.stop()
 game.move_audio.stop();game.player.active_ability.charge_voice.stop()
 if capture!=null:capture.clear_buffer()

func save_audio(name_:String):
 if capture==null:return
 await create_timer(.8).timeout
 var data=capture.get_buffer(capture.get_frames_available())
 var pcm=PackedByteArray();pcm.resize(data.size()*4)
 var peak=0.0
 for i in data.size():
  peak=maxf(peak,maxf(absf(data[i].x),absf(data[i].y)))
  pcm.encode_s16(i*4,clampi(roundi(data[i].x*32767),-32768,32767))
  pcm.encode_s16(i*4+2,clampi(roundi(data[i].y*32767),-32768,32767))
 check(peak>.001,"Desktop SFX output contains the %s cue"%name_)
 var wav=AudioStreamWAV.new();wav.format=AudioStreamWAV.FORMAT_16_BITS;wav.stereo=true
 wav.mix_rate=roundi(AudioServer.get_mix_rate());wav.data=pcm
 check(wav.save_to_wav(EVIDENCE+name_+".wav")==OK,"Save %s output for audible review"%name_)
 capture.clear_buffer()

func planted():
 var p=game.player
 p.active_ability.cancel();p.position=home;p.velocity=Vector3.DOWN;p.facing=Vector3.FORWARD
 p.smoke_mode=true;p.smoke_move=Vector2.ZERO
 for i in 4:p._physics_process(1.0/60)

func wall_order()->int:
 var order=-1
 for voice in game.voices:
  if voice.get_meta("kind","")=="sonic_wall_hit":order=maxi(order,int(voice.get_meta("order",-1)))
 return order

func run():
 await setup_fixture()
 game.set_process(false);game.army_runtime.set_physics_process(false)
 var p=game.player;var lib=game.sound_library
 game.training_dummy.position=Vector3(10000,0,10000);game.training_dummy.home=game.training_dummy.position
 p.select_character(19);p.set_physics_process(false);p.set_auto_attack(false)
 game.tuning.invincible=false;game.tuning.enemy_damage=1;game.settings.volume=1
 home=Vector3(0,game.world.height_at(0,60)+.1,60)
 planted()
 check(p.is_on_floor(),"Audio fixture uses real floor contacts")
 var hurt=SonicAudio.stream_for("hurt")
 check(hurt is AudioStreamSynchronized and hurt.stream_count==2,"Hurt owns one synchronized original effect/voice pair")
 check(hurt==SonicAudio.stream_for("hurt"),"Selection caches the hurt pair")
 check(hurt.get_sync_stream(0).mix_rate==22050 and hurt.get_sync_stream(1).mix_rate==16429,"Hurt layers retain the native playback rates")
 check(SonicAudio.stream_for("sonic_wall_hit").mix_rate==16429,"Wall reaction uses native note/fine tuning")
 var jumps=SonicAudio.stream_for("move_jump_voice")
 check(jumps is AudioStreamRandomizer and jumps.streams_count==2 and jumps.get_stream(0).mix_rate==16429 and jumps.get_stream(1).mix_rate==16429,"Both jump variants use corrected source pitch")
 check(SonicAudio.stream_for("sonic_charge").mix_rate==22050 and SonicAudio.stream_for("sonic_dash").mix_rate==22050,"Spin Dash retains the native driver's playback note")
 check(p.active_ability.charge_voice.stream.loop_begin==17827 and p.active_ability.charge_voice.stream.loop_end==27444,"Charge retains source PCM loop points at corrected speed")
 if DisplayServer.get_name()!="headless":
  capture=AudioEffectCapture.new();capture.buffer_length=2
  AudioServer.add_bus_effect(AudioServer.get_bus_index("SFX"),capture)
 stop_audio()
 var before=game.voice_idx
 p.invuln=0;p.hp=100;p.take_hit(10,Vector3.RIGHT)
 check(p.hp==90 and game.voice_idx==before+1,"An accepted hit starts exactly one hurt event on the damage frame")
 check(game.last_sound_voice.stream==hurt and game.last_sound_voice.pitch_scale==1,"Damage routes both source layers through the existing player without random pitch")
 before=game.voice_idx;p.take_hit(10,Vector3.RIGHT)
 check(p.hp==90 and game.voice_idx==before,"Invulnerability rejects repeated damage and audio together")
 await save_audio("hurt")
 stop_audio()
 var take=AudioStreamWAV.new();take.mix_rate=22050;take.format=AudioStreamWAV.FORMAT_16_BITS;take.data=PackedByteArray([0,0,0,1])
 lib.select_character(19);lib.custom.hurt=take;p.invuln=0;p.take_hit(1,Vector3.ZERO)
 check(game.last_sound_voice.stream==take,"A saved hurt recording replaces the whole original pair")
 lib.custom.erase("hurt");lib.mutes.hurt=true;before=game.voice_idx;p.invuln=0;p.take_hit(1,Vector3.ZERO)
 check(game.voice_idx==before,"Hurt mute suppresses both layers")
 lib.mutes.erase("hurt");lib.recording=true;before=game.voice_idx;p.invuln=0;p.take_hit(1,Vector3.ZERO)
 check(game.voice_idx==before,"Recording mode suppresses hurt playback")
 lib.recording=false
 var wall=StaticBody3D.new();wall.collision_layer=1
 var shape=CollisionShape3D.new();shape.shape=BoxShape3D.new();shape.shape.size=Vector3(12,12,.5)
 wall.add_child(shape);game.add_child(wall);wall.position=home+Vector3(0,4,-3)
 await physics_frame;await physics_frame
 planted();stop_audio();var order=wall_order()
 p.active_ability.start_spin()
 for i in 21:p._physics_process(1.0/60)
 p.active_ability.release_spin();stop_audio()
 for i in 6:
  p._physics_process(1.0/60)
  if wall_order()>order:break
 check(p.is_on_wall() and wall_order()>order,"A real Spin Dash collision starts the wall reaction on its contact frame")
 check(game.last_sound_voice.stream==SonicAudio.stream_for("sonic_wall_hit") and game.last_sound_voice.pitch_scale==1,"Wall hit reuses the corrected source sample at fixed pitch")
 order=wall_order();p.smoke_move=Vector2(0,-1)
 for i in 18:p._physics_process(1.0/60)
 check(wall_order()==order,"Holding into the wall does not repeat the reaction")
 await save_audio("wall-hit")
 planted();stop_audio();order=wall_order();p.velocity=Vector3.FORWARD*60
 for i in 6:
  p._physics_process(1.0/60)
  if wall_order()>order:break
 check(wall_order()>order,"A fast running crash also uses the original wall reaction")
 planted();p.active_ability.jump_requested=true;p.active_ability.jump_held=false;stop_audio()
 before=game.move_audio.cursor;p._physics_process(1.0/60)
 check(p.attack_ticket.move_audio.voiced and game.move_audio.cursor==before+1,"Jump voices release once on the launch frame")
 check(game.move_audio.voices[before%game.move_audio.voices.size()].stream==jumps and game.move_audio.voices[before%game.move_audio.voices.size()].pitch_scale==1,"Jump uses the cached corrected variants without random pitch")
 await save_audio("jump")
 planted();stop_audio();await create_timer(1).timeout;await frames(2)
 var nodes=get_node_count();var resources=Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)
 for i in 32:
  planted();p.active_ability.start_spin();p.active_ability.release_spin()
  for tick in 12:p._physics_process(1.0/60)
  p.invuln=0;p.hp=100;p.take_hit(1,Vector3.ZERO)
 stop_audio();await create_timer(1).timeout;await frames(2)
 print("SONIC_AUDIO_REUSE nodes=",get_node_count()-nodes," resources=",Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)-resources)
 check(get_node_count()==nodes and Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)==resources,"Repeated collisions and hurt reuse the same voices, effects and resources")
 wall.queue_free();await frames(2)
 p.select_character(1)
 check(lib.original_for(1,"hurt")!=hurt,"Other characters retain their own damage audio")
 stop_audio_for_exit()
 print("SONIC_AUDIO_RESULT checks=%d failures=%d"%[checks,failures])
 game.queue_free();game=null;paused=false;await frames(3)
 if FileAccess.file_exists(cfg):DirAccess.remove_absolute(ProjectSettings.globalize_path(cfg))
 quit(1 if failures else 0)

func stop_audio_for_exit():
 for voice in game.voices:voice.stop()
 game.move_audio.stop()
