extends "res://tests/forest-shrine/dark_lumina_3_completeness_test.gd"
const STEERING_OUT=OUT+"Wind Steering/"
var wind_releases=[]
var wind_pcm={}
func aim_at_yaw(yaw:float):
 var p=game.player
 game.camera_rig.yaw=yaw
 game.camera_rig.camera.position=p.position+Vector3(0,10,24).rotated(Vector3.UP,yaw)
 game.camera_rig.camera.look_at(p.position+Vector3(0,3,-30).rotated(Vector3.UP,yaw))
func wind_voices(owner:int)->Array:
 return game.crowd.army.presentation.voices.filter(func(v):return v.playing and v.get_meta("loop_owner",0)==owner and v.get_meta("finale_loop","")=="wind_loop")
func capture_wind_audio(label_:String)->Dictionary:
 var record=AudioEffectRecord.new();record.format=AudioStreamWAV.FORMAT_16_BITS
 var bus=AudioServer.get_bus_index("SFX");var effect=AudioServer.get_bus_effect_count(bus);AudioServer.add_bus_effect(bus,record)
 record.set_recording_active(true);await create_timer(.4).timeout;record.set_recording_active(false)
 var audio=record.get_recording();var peak=0;var clipped=0
 if audio:
  for offset in range(0,audio.data.size(),2):
   var value=absi(audio.data.decode_s16(offset));peak=maxi(peak,value)
   if value>=32767:clipped+=1
 check(peak>100 and clipped==0,"Wind reaches the desktop SFX mixer without clipping: "+label_)
 if audio:check(audio.save_to_wav(STEERING_OUT+label_+".wav")==OK,"Saved real mixer output: "+label_)
 AudioServer.remove_bus_effect(bus,effect)
 return {"peak":peak/32768.0,"clipped_samples":clipped}
func run():
 visual=DisplayServer.get_name()!="headless"
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(STEERING_OUT))
 create_timer(120).timeout.connect(func():printerr("WIND_STEERING_TIMEOUT");quit(1))
 await setup_fixture()
 root.title="Goemon · Steerable Lumina wind"
 root.set_flag(Window.FLAG_NO_FOCUS,true);Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
 game.set_process(false)
 game.camera_rig.set_process_unhandled_input(false);game.ui.hide();game.model.phase="wave";game.tuning.invincible=true
 game.settings.volume=.65;game.settings.music_enabled=false;game.apply_music_setting()
 var sfx_bus=AudioServer.get_bus_index("SFX")
 check(AudioServer.get_bus_effect_count(sfx_bus)>0 and AudioServer.get_bus_effect(sfx_bus,0) is AudioEffectHardLimiter and AudioServer.get_bus_effect(sfx_bus,0).ceiling_db+AudioServer.get_bus_volume_db(sfx_bus)<0,"Shared SFX limiter leaves headroom after the bus gain")
 var p=game.player;p.select_character(30);fresh();p.position=ORIGIN
 var c=p.active_ability;var fx=game.crowd.army.presentation;var pool=Pool.service(game)
 game.training_dummy.position=ORIGIN+Vector3(100,0,0);game.training_dummy.home=game.training_dummy.position;game.training_dummy.hide()
 pool.launched.connect(func(shot):
  shot.set_physics_process(false)
  if shot.get_script()==Shot and shot.kind==1:wind_releases.append({"direction":shot.velocity.normalized(),"damage":shot.damage}))
 var prepared=pool.created;var misses=pool.misses
 aim_at_yaw(0);key(1)
 check(c.is_attacking() and c.move==1,"Number 1 starts Wind through the real input route")
 check(fx.voices.any(func(v):return v.playing and v.get_meta("loop_owner",0)==c.get_instance_id() and v.stream==Finale.sounds.wind_start),"Wind starts its recovered opening gust")
 await advance(42)
 var voices=wind_voices(c.get_instance_id())
 check(voices.size()==1 and voices[0].stream==Finale.loops.wind_loop,"Blowing owns exactly one prepared Wind sustain")
 if visual:wind_pcm.player=await capture_wind_audio("wind-only")
 var source:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(Finale.SOUND_DIR+"wind_sustain_sources.json"))
 check(source.bank_slot==94 and source.sample_index==9 and source.sha256==FileAccess.get_sha256(Finale.SOUND_DIR+"wind_sustain.wav"),"The recovered Wind sample remains preserved")
 check(Finale.loops.wind_loop.loop_begin==source.loop_begin and Finale.loops.wind_loop.loop_end==source.loop_end,"Prepared sustain retains the ROM sample loop region")
 for yaw in [PI/2,PI,PI*1.5,PI/4]:
  aim_at_yaw(yaw);var direction=p.combat_attack_direction();var before=wind_releases.size()
  await advance(10)
  check(c.is_attacking() and p.facing.dot(direction)>.999,"Wind follows current camera aim at yaw %.2f"%yaw)
  check((-c.cast_model().basis.z).dot(direction)>.999,"Caster turns with the blowing wings")
  check(wind_releases.size()>=before+Finale.WIND_FAN and wind_releases.slice(before,before+Finale.WIND_FAN).all(func(s):return s.direction.dot(direction)>.97),"Next gust fan travels in the new direction")
  check(wind_voices(c.get_instance_id())==voices,"Turning reuses the same Wind voice")
  if visual:
   fx.draw_effects()
   var wing=fx.batches["finale-wind"].multimesh.get_instance_transform(1)
   check((-wing.basis.z).normalized().dot(direction)>.999,"Attached wing geometry turns with the attack")
   RenderingServer.force_draw();root.get_texture().get_image().save_png(STEERING_OUT+"turn-%d.png"%roundi(rad_to_deg(yaw)))
 await advance(180)
 check(wind_releases.size()==22*Finale.WIND_FAN,"Turning preserves all 22 four-gust pulses")
 check(wind_releases.all(func(s):return is_equal_approx(s.damage,65*Finale.DAMAGE[1]*.5)),"Turning preserves gust damage")
 check(not c.is_attacking() and wind_voices(c.get_instance_id()).is_empty(),"Completion stops the blowing loop")
 await advance(90)
 var resources=Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)
 var nodes=Performance.get_monitor(Performance.OBJECT_NODE_COUNT)
 for repeat in 3:
  fresh();p.position=ORIGIN;aim_at_yaw(repeat*PI/2);c.start_move(1);await advance(42)
  aim_at_yaw(repeat*PI/2+PI/4);await advance(10)
  c.interrupt_for_dodge()
  check(wind_voices(c.get_instance_id()).is_empty() and not fx.effects.any(func(e):return e.get("owner_id",0)==c.get_instance_id()),"Interruption clears wind wings and audio on repeat %d"%repeat)
  await advance(90)
 check(pool.created==prepared and pool.misses==misses,"Repeated turns and cancellations reuse prepared projectiles")
 var resource_growth=Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)-resources
 var node_growth=Performance.get_monitor(Performance.OBJECT_NODE_COUNT)-nodes
 check(resource_growth==0 and node_growth==0,"Repeated turns retain no additional nodes or resources")
 fresh();c.start_move(1);await advance(42)
 var rising_voice=wind_voices(c.get_instance_id())
 p.position.y+=120
 await advance(10)
 check(wind_voices(c.get_instance_id())==rising_voice and rising_voice.size()==1 and rising_voice[0].position.distance_to(p.position+p.facing*5*Finale.SCALE)<1.0,"Ascending Wind moves its existing sound to each release point")
 c.cancel();p.velocity=Vector3.ZERO
 fresh();c.start_move(1);c.interrupt_for_dodge()
 check(not fx.voices.any(func(v):return v.playing and v.get_meta("loop_owner",0)==c.get_instance_id()),"Immediate interruption stops the opening gust as well as the sustain")
 var lib=game.sound_library;lib.select_character(30)
 for slot in ["step"]:
  check(lib.stream_for(30,slot,null)==null and lib.playback_for(30,slot,null).muted and game.sound_preview(30,slot)==null,"Shared audio and preview silence "+slot)
 for slot in ["finale_wind_start","finale_wind_loop","finale_earth_impact","swing","hurt"]:check(not lib.playback_for(30,slot,game.sounds.get(slot)).muted,"Other Dark Lumina audio is unchanged: "+slot)
 var before_steps=game.voice_idx
 for repeat in 8:p.play_sound("step",.22)
 check(game.voice_idx==before_steps,"Repeated Lumina footsteps do not start a voice")
 game.sound("step",.22,false,{},1)
 check(game.voice_idx==before_steps+1,"Goemon footsteps remain audible")
 p.position=ORIGIN
 for slot in ["finale_wind_start","finale_wind_loop"]:
  check(lib.stream_for(30,slot,null)==Finale.stream_for(slot) and game.sound_preview(30,slot)==Finale.stream_for(slot),"Shared audio and preview resolve "+slot)
 lib.custom.finale_wind_start=Finale.sounds.cast;lib.gains.finale_wind_start=.5;c.start_move(1)
 check(fx.voices.any(func(v):return v.playing and v.get_meta("loop_owner",0)==c.get_instance_id() and v.stream==Finale.sounds.cast and is_equal_approx(db_to_linear(v.volume_db),.55*Finale.SOUND_GAIN.wind_start*.5)),"Wind opening honors the saved recording and gain through the Master volume bus")
 c.cancel();lib.custom.erase("finale_wind_start");lib.gains.erase("finale_wind_start")
 var samples=PackedVector2Array()
 for i in 1600:samples.append(Vector2.ONE*sin(i*TAU*440/16000)*.15)
 var recorded=lib.make_take(samples,16000)
 lib.take=recorded;lib.take_slot="finale_wind_loop";check(lib.save_take(),"Wind test saves a real PCM recording");lib.gains.finale_wind_loop=.4
 fx.finale_loop(p.position,"wind_loop",2,c.get_instance_id());var custom_voice=wind_voices(c.get_instance_id())
 check(custom_voice.size()==1 and custom_voice[0].stream==lib.recorded_loop_for(30,"finale_wind_loop",null) and custom_voice[0].stream.loop_mode==AudioStreamWAV.LOOP_FORWARD and is_equal_approx(db_to_linear(custom_voice[0].volume_db),.55*.4),"Wind sustain honors the saved recording and gain")
 if visual:
  await create_timer(recorded.get_length()+.15).timeout
  check(wind_voices(c.get_instance_id())==custom_voice,"A saved Wind recording sustains beyond its one-shot length without restarting")
 c.cancel();lib.reset_slot("finale_wind_loop")
 lib.mutes.finale_wind_start=true;lib.mutes.finale_wind_loop=true
 c.start_move(1);await advance(42)
 check(not fx.voices.any(func(v):return v.playing and v.get_meta("loop_owner",0)==c.get_instance_id()),"Explicit user mutes still suppress both Wind phases")
 c.cancel();lib.mutes.erase("finale_wind_start");lib.mutes.erase("finale_wind_loop")
 for voice in fx.voices:voice.stop()
 for owner in [-1,-2,-3]:
  fx.next_sound=0
  fx.present([{"kind":"status","unit_kind":Finale.ROLE,"action_index":301,"source_id":-owner,"position":p.position},{"kind":"status","unit_kind":Finale.ROLE,"action_index":312,"source_id":-owner,"source_tick":60,"position":p.position}])
  fx.next_sound=0
  fx.present([{"kind":"status","unit_kind":Finale.ROLE,"action_index":312,"source_id":-owner,"source_tick":72,"position":p.position}])
  check(wind_voices(owner).size()==1,"Native boss Wind owns one sustain for owner %d"%owner)
 check([-1,-2,-3].all(func(owner):return wind_voices(owner).size()==1),"Three native bosses can blow simultaneously")
 if visual:wind_pcm.native_three=await capture_wind_audio("wind-native-three")
 fx.cancel_finale(-2)
 check(wind_voices(-2).is_empty() and wind_voices(-1).size()==1 and wind_voices(-3).size()==1,"Cancelling one native owner preserves the others")
 for owner in [-1,-2,-3]:fx.cancel_finale(owner)
 for voice in fx.voices:voice.stop()
 for i in fx.voices.size():
  fx.next_sound=0;fx.finale_loop(p.position,"wind_loop",2,-100-i)
 check(fx.voices.all(func(v):return v.playing and v.get_meta("loop_owner",0)<0),"Native sustains fill the existing bounded sound pool")
 fx.finale_cue(p.position,1,Vector3.FORWARD,c.get_instance_id())
 check(fx.voices.any(func(v):return v.playing and v.get_meta("loop_owner",0)==c.get_instance_id() and v.stream==Finale.sounds.wind_start),"Player Wind opening reclaims a native voice under saturation")
 fx.finale_loop(p.position,"wind_loop",2,c.get_instance_id())
 check(wind_voices(c.get_instance_id()).size()==1 and fx.voices.filter(func(v):return v.playing).size()==8,"Player Wind remains audible when native sustains fill the pool")
 fx.next_sound=0;fx.gunshot(p.position)
 check(wind_voices(c.get_instance_id()).size()==1,"Ordinary army sounds cannot steal the player's held Wind")
 for i in fx.voices.size():fx.cancel_finale(-100-i)
 check(wind_voices(c.get_instance_id()).size()==1,"Cancelling a preempted owner cannot stop its reused player voice")
 c.cancel()
 fx.next_sound=0
 var next_before=fx.next_sound
 check(fx.play_sound(p.position,null)==null and fx.next_sound==next_before,"An empty stream consumes neither a pooled voice nor the audio throttle")
 game.settings.volume=.2
 var quiet=fx.play_sound(p.position,Finale.sounds.cast)
 check(quiet!=null and is_equal_approx(db_to_linear(quiet.volume_db),.55),"Army sounds apply Master volume once, matching other SFX")
 if quiet:quiet.stop()
 game.settings.volume=0;fx.next_sound=0
 check(fx.play_sound(p.position,Finale.sounds.cast)==null,"Master mute suppresses new army voices")
 game.settings.volume=.65;lib.recording=true
 check(fx.play_sound(p.position,Finale.sounds.cast,1,65,true)==null,"Recording suppresses new army voices")
 lib.recording=false;fx.next_sound=0;fx.finale_loop(p.position,"wind_loop",2,c.get_instance_id())
 game.paused=true;fx.tick(0)
 check(wind_voices(c.get_instance_id()).is_empty(),"Pause stops held army audio")
 game.paused=false
 # Other spells retain their committed facing.
 fresh();p.position=ORIGIN;aim_at_yaw(0);c.start_move(2);var committed=p.facing
 aim_at_yaw(PI/2);await advance(5)
 check(p.facing.is_equal_approx(committed),"Water keeps its existing aim lock")
 c.cancel();p.select_character(1);fresh();p.position=ORIGIN;aim_at_yaw(0)
 check(p.spell_loadout.equip(1,"equip","dark-lumina-3/wind"),"Another fighter can equip the same Wind controller")
 tap("equip");await advance(42);var borrowed=p.spell_loadout.current
 check(fx.voices.any(func(v):return v.playing and v.stream==Finale.loops.wind_loop),"Borrowed Wind uses the same prepared sustain")
 aim_at_yaw(-PI/2);var borrowed_direction=p.combat_attack_direction();await advance(10)
 check(borrowed!=null and borrowed.busy() and p.facing.dot(borrowed_direction)>.999,"Borrowed Wind follows aim through the shared skill path")
 p.spell_loadout.interrupt();await advance(90)
 check(not fx.voices.any(func(v):return v.playing and v.get_meta("finale_loop","")=="wind_loop"),"Borrowed Wind interruption releases its sound")
 step_times.sort();frame_times.sort()
 var report={"checks":checks,"failures":failures,"prepared":prepared,"pool_misses":pool.misses-misses,"resource_growth":resource_growth,"node_growth":node_growth,"step_p95_ms":step_times[floori(step_times.size()*.95)],"step_max_ms":step_times[-1],"wind_pcm":wind_pcm}
 if visual:report.frame_p95_ms=frame_times[floori(frame_times.size()*.95)];report.frame_max_ms=frame_times[-1]
 FileAccess.open(STEERING_OUT+("rendered" if visual else "headless")+".json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
 print("WIND_STEERING_RESULT ",JSON.stringify(report))
 game.queue_free();await frames(4)
 if FileAccess.file_exists(cfg):DirAccess.remove_absolute(ProjectSettings.globalize_path(cfg))
 quit(1 if failures else 0)
