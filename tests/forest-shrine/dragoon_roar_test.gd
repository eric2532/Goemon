extends "res://scripts/recovered_goemon_gameplay_tests.gd"
const ROAR=preload("res://assets/audio/recovered_frost_dragon/roar.wav")
const HUNT=preload("res://assets/audio/recovered_frost_dragon/ground_attack.wav")
const OUT="res://build/Other Files/Asset Toolkit/Dragoon Frost Dragon Audio/Selected Ground Attack/"
const Runtime=preload("res://scripts/forest/crowd/army_runtime.gd")

func leap(button:String="flintlock"):
 var p=game.player;var c=p.active_ability
 c.cancel();c.reset_run();game.move_audio.stop();c.sound.last_events.clear()
 p.position=ORIGIN+Vector3.UP*12;p.velocity=Vector3.DOWN
 await physics_frame;p.move_and_slide();c.player.pos=p.position
 c.action(button)
 check(c.player.travel!=null,"Airborne %s starts Dragon Leap"%button)
 if c.player.travel==null:return
 c.player.travel.target=ORIGIN
 var cursor=game.move_audio.cursor
 check(not c.current_ticket().move_audio.voiced,"Roar waits for actual landing")
 for i in 180:
  if DisplayServer.get_name()!="headless":await physics_frame
  c.step_travel(1.0/60);c._process(0);c.fx.tick(1.0/60)
  if c.player.travel==null:break
 check(c.player.travel==null and p.is_on_floor(),"Actual floor contact releases the dragon")
 check(game.move_audio.cursor==posmod(cursor+1,8) or game.sound_library.is_muted_for(8,"move_secondary_voice"),"Landing releases at most one voice")

func run():
 create_timer(120).timeout.connect(func():printerr("DRAGOON_ROAR_TIMEOUT");quit(1))
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
 var doc=load("res://scripts/forest/forest_map_document.gd").new()
 check(doc.load_wind_meadow()=="","Load bundled Wind Meadow")
 await setup_fixture(doc.data)
 game.set_process(false);game.army_runtime.set_physics_process(false);game.music.stop()
 for node in [game,game.player,game.camera_rig]:
  node.set_process_input(false);node.set_process_unhandled_input(false)
 game.camera_focused=false;game._sync_camera_mouse()
 var lib=game.sound_library;var p=game.player
 p.select_character(8);lib.select_character(8)
 check(game.sound_preview(8,"move_secondary_voice")==ROAR and ROAR.get_length()>3,"Studio previews the recovered full Frost Dragon opening roar")
 check(game.sound_preview(8,"dragoon_hunt")==HUNT and is_equal_approx(HUNT.get_length(),3.109297052154195),"Studio previews selected sound 08 as a separate ground-attack cue")
 check(game.sound_preview(7,"move_secondary_voice")!=ROAR and game.sound_preview(13,"move_heavy_voice")!=ROAR,"Other characters retain their voice defaults")
 var desktop=DisplayServer.get_name()!="headless"
 var recorder:AudioEffectRecord
 var bus=AudioServer.get_bus_index("SFX")
 if desktop:
  recorder=AudioEffectRecord.new();recorder.format=AudioStreamWAV.FORMAT_16_BITS
  AudioServer.add_bus_effect(bus,recorder);recorder.set_recording_active(true)
 await leap()
 var voice=game.move_audio.voices[posmod(game.move_audio.cursor-1,8)]
 check(voice.stream==ROAR and voice.pitch_scale==1 and is_equal_approx(db_to_linear(voice.volume_db),.55*.8),"Real landing plays the original roar 20 percent quieter at source pitch")
 var impact=p.active_ability.sound.voices[posmod(p.active_ability.sound.cursor-1,28)]
 check(impact.stream.resource_path.ends_with("landing-strike-dragoon.wav") and is_equal_approx(db_to_linear(impact.volume_db),game.settings.volume*.85*.8),"The accompanying landing impact is also 20 percent quieter")
 check(is_equal_approx(lib.playback_for(7,"move_secondary_voice",null).gain,1.0) and is_equal_approx(lib.playback_for(8,"move_sweep_weapon",null).gain,1.0),"Other characters and the grounded lance sweep retain their sound level")
 var c=p.active_ability;var cursor=game.move_audio.cursor
 check(not game.move_audio.voices.any(func(v):return v.stream==HUNT and v.playing),"Landing preserves its own sound before the first hunting pass")
 if desktop:
  c.tick(.12,false);c._process(0);game.ui.hide()
  var camera=game.camera_rig.camera
  camera.global_position=p.position+Vector3(20,18,27);camera.look_at(p.position+Vector3(0,4,-2));camera.current=true
  await RenderingServer.frame_post_draw;await RenderingServer.frame_post_draw
  check(root.get_texture().get_image().save_png(OUT+"landing.png")==OK,"Capture Dragon Leap on Wind Meadow")
 for i in 120:
  if desktop:await physics_frame
  c.tick(1.0/60)
 check(game.move_audio.cursor==posmod(cursor+1,8),"The first hunting pass plays one new cue; later passes and shockwaves cannot repeat it")
 var hunt_voice=game.move_audio.voices[posmod(game.move_audio.cursor-1,8)]
 check(hunt_voice.stream==HUNT and hunt_voice.pitch_scale==1 and is_equal_approx(db_to_linear(hunt_voice.volume_db),.55),"Actual ground hunting plays selected 08 at the approved pitch through the existing pool")
 if desktop:
  await create_timer(1.6).timeout;recorder.set_recording_active(false)
  var audio=recorder.get_recording()
  check(audio!=null and audio.data.count(0)<audio.data.size(),"Actual desktop mixer produces non-silent landing audio")
  if audio:check(audio.save_to_wav(OUT+"landing-and-hunt.wav")==OK,"Save unchanged landing followed by selected ground-attack playback")
 lib.set_gain("dragoon_hunt",.4);await leap()
 for i in 30:c.tick(1.0/60)
 hunt_voice=game.move_audio.voices[posmod(game.move_audio.cursor-1,8)]
 check(hunt_voice.stream==HUNT and is_equal_approx(db_to_linear(hunt_voice.volume_db),.55*.4),"Ground-attack gain adjusts its own cue")
 lib.set_muted("dragoon_hunt",true);await leap();cursor=game.move_audio.cursor
 for i in 30:c.tick(1.0/60)
 check(game.move_audio.cursor==cursor,"Ground-attack mute leaves landing audible and suppresses only the hunting cue")
 lib.set_muted("dragoon_hunt",false)
 lib.take=AudioStreamWAV.load_from_file(ProjectSettings.globalize_path("res://assets/audio/recovered_frost_dragon/roar.wav"));lib.take_slot="dragoon_hunt"
 check(lib.save_take(),"Save an independent custom ground-attack take in the isolated profile")
 await leap()
 for i in 30:c.tick(1.0/60)
 check(game.move_audio.voices[posmod(game.move_audio.cursor-1,8)].stream==lib.custom_for(8,"dragoon_hunt"),"A saved ground-attack take replaces selected 08")
 lib.reset_slot("dragoon_hunt")
 check(game.sound_preview(8,"dragoon_hunt")==HUNT and game.sound_preview(8,"move_secondary_voice")==ROAR,"Restore ground attack returns 08 while preserving the landing sound")
 lib.set_gain("move_secondary_voice",.4);await leap("cutlass")
 voice=game.move_audio.voices[posmod(game.move_audio.cursor-1,8)]
 check(voice.stream==ROAR and is_equal_approx(db_to_linear(voice.volume_db),.55*.8*.4),"Airborne left-click combines the quieter roar with saved voice gain")
 lib.set_muted("move_secondary_voice",true);cursor=game.move_audio.cursor
 await leap()
 check(game.move_audio.cursor==cursor,"Voice mute silences the roar while the landing still completes")
 lib.set_muted("move_secondary_voice",false)
 lib.take=AudioStreamWAV.load_from_file(ProjectSettings.globalize_path("res://assets/audio/recovered_frost_dragon/roar.wav"));lib.take_slot="move_secondary_voice"
 check(lib.save_take(),"Save a custom roar in the isolated test profile")
 await leap()
 check(game.move_audio.voices[posmod(game.move_audio.cursor-1,8)].stream==lib.custom_for(8,"move_secondary_voice"),"A custom voice replaces the complete default roar")
 lib.reset_slot("move_secondary_voice")
 check(game.sound_preview(8,"move_secondary_voice")==ROAR and lib.gain_for(8,"move_secondary_voice")==1,"Restore default returns the Frost Dragon roar")
 c.cancel();c.reset_run();p.position=ORIGIN;p.velocity=Vector3.DOWN
 await physics_frame;p.move_and_slide();c.player.pos=p.position
 game.move_audio.stop();cursor=game.move_audio.cursor;c.action("flintlock");c.tick(.25,false)
 check(game.move_audio.cursor==cursor,"Grounded lance sweep does not play a dragon roar")
 var fx=game.crowd.army.presentation
 var r=Runtime.new();r.configure(null);r.configure_kits(load("res://scripts/forest/crowd/army_kit_data.gd").from_model(game.model));r.set_navigation(1,{"width":0})
 var target=r.spawn(1,0,0,ORIGIN,100000,3.9);r.apply_hit(target,{"element":"ice","status_seconds":100})
 for i in 8:r.spawn(-i-1,1,8,ORIGIN+Vector3((i-4)*2,12,0),200,.4)
 for channel in fx.voices:channel.stop()
 fx.next_sound=0;fx.last_serial=0
 var pulses=0
 for i in 60:
  r.step(1.0/60,{});var events=r.take_events()
  pulses+=events.filter(func(e):return e.kind=="landing_pulse" and e.action_index==0).size()
  fx.present(events);fx.tick(1.0/60)
 check(pulses==8 and fx.voices.any(func(v):return v.stream==ROAR and v.playing and v.pitch_scale==1 and is_equal_approx(db_to_linear(v.volume_db),.55*.8)),"Eight simultaneous native Dragoon landings use the quieter shared spatial roar pool")
 check(fx.voices.any(func(v):return v.stream==HUNT and v.playing and v.pitch_scale==1 and is_equal_approx(db_to_linear(v.volume_db),.55)),"Native allies play selected 08 on their first hunting pass through the same spatial pool")
 var nodes=get_node_count();var resources=Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)
 for i in 1000:
  game.move_audio.play_voice(game,8,"move_secondary_voice");game.move_audio.play_voice(game,8,"dragoon_hunt")
 check(get_node_count()==nodes and Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)==resources,"Two thousand repeated landing and hunting cues reuse the same nodes and resources")
 r.clear();r.free();c.cancel();game.move_audio.stop()
 if recorder:AudioServer.remove_bus_effect(bus,AudioServer.get_bus_effect_count(bus)-1)
 var audio_cfg=lib.config_path
 current_scene=null;game.free();await frames(4)
 for path in [cfg,audio_cfg]:
  if FileAccess.file_exists(path):DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
 print("DRAGOON_ROAR_RESULT checks=%d failures=%d desktop=%s"%[checks,failures,desktop]);quit(1 if failures else 0)
