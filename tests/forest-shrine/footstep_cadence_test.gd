extends "res://scripts/recovered_goemon_gameplay_tests.gd"
const OUT="res://build/Other Files/Asset Toolkit/Footstep Speed Limit/"
const CharacterBalance=preload("res://scripts/character_balance.gd")
var driver:Node

func run():
 create_timer(180).timeout.connect(func():printerr("FOOTSTEP_CADENCE_TIMEOUT");quit(1))
 var document=load("res://scripts/forest/forest_map_document.gd").new();document.load_wind_meadow()
 await setup_fixture(document.data)
 game.set_process(false);game.army_runtime.set_physics_process(false);game.music.stop()
 for node in [game,game.player,game.camera_rig]:
  node.set_process_input(false);node.set_process_unhandled_input(false)
 game.camera_focused=false;game._sync_camera_mouse()
 driver=load("res://tests/forest-shrine/physics_step_driver.gd").new();root.add_child(driver)
 DirAccess.make_dir_recursive_absolute(OUT)
 var p=game.player
 # The same physical floor keeps extreme movement on level ground.
 var floor_=StaticBody3D.new();var shape=CollisionShape3D.new();shape.shape=BoxShape3D.new()
 shape.shape.size=Vector3(160,1,160);floor_.add_child(shape);game.add_child(floor_);floor_.position=Vector3(0,99.5,60)
 var recorder:AudioEffectRecord
 var bus=AudioServer.get_bus_index("SFX")
 if DisplayServer.get_name()!="headless":
  recorder=AudioEffectRecord.new();recorder.format=AudioStreamWAV.FORMAT_16_BITS;AudioServer.add_bus_effect(bus,recorder)
 for id in [1,5,13,18,19,28,29,31,32]:
  p.select_character(id);fresh();game.sound_library.select_character(id)
  for fast in [false,true]:
   if p.active_ability!=null:p.active_ability.cancel()
   var key=CharacterBalance.key_for(id)
   game.character_tuning[key]={"walk_speed":40.0 if fast else 6.0,"sprint_speed":40.0 if fast else 6.0}
   p.set_scarf_equipped(fast);p.position=Vector3(0,100.05,60);p.velocity=Vector3.ZERO;p.smoke_move=Vector2.RIGHT;p.foot_time=0
   var sounds=[];var speeds=[];var elapsed=[0.0]
   if recorder:recorder.set_recording_active(true)
   await driver.advance(120,func(dt):
    if absf(p.position.x)>40:p.position.x=0
    var serial=game.voice_idx
    p._physics_process(dt);elapsed[0]+=dt
    speeds.append(Vector2(p.velocity.x,p.velocity.z).length())
    for voice in game.voices:
     var kind=voice.get_meta("kind","")
     if voice.get_meta("order",-1)>serial and (kind=="step" or kind.begins_with("musashi_step_") or kind=="dark_lumina_2_step"):
      sounds.append([elapsed[0],voice.stream,voice.pitch_scale]))
   var spaced=true
   for i in range(1,sounds.size()):
    if sounds[i][0]-sounds[i-1][0]<Hero.FOOTSTEP_INTERVAL-.000001:spaced=false
   check(sounds.size()>=2 and spaced,"Fighter %d %s movement: %d footsteps, min interval %.2fs, peak speed %.2f"%[id,"fast" if fast else "normal",sounds.size(),Hero.FOOTSTEP_INTERVAL,speeds.max()])
   var slot="musashi_step_0" if id==13 else "dark_lumina_2_step" if id==29 else "step"
   var playback=game.sound_library.playback_for(id,slot,game.sounds.get(slot))
   check(sounds.all(func(cue):return cue[1]==playback.stream and (cue[2]==1.0 if playback.recorded or playback.get("original",false) else cue[2]>=.92 and cue[2]<=1.08)),"Fighter %d preserves its sample and pitch policy"%id)
   if fast and id in [1,5,18,28,31,32]:check(speeds.max()>30,"Fighter %d still travels fast"%id)
   if recorder:
    recorder.set_recording_active(false)
    var audio=recorder.get_recording()
    check(audio!=null and audio.data.count(0)<audio.data.size(),"Fighter %d has audible desktop output"%id)
    if audio:audio.save_to_wav(OUT+"%d-%s.wav"%[id,"fast" if fast else "normal"])
  p.smoke_move=Vector2.ZERO
  await driver.advance(60,func(dt):p._physics_process(dt))
  var serial=game.voice_idx
  await driver.advance(30,func(dt):p._physics_process(dt))
  check(game.voice_idx==serial,"Fighter %d has no queued footsteps after stopping"%id)
 # The limiter follows simulation time at each supported physics rate.
 p.select_character(1);fresh();p.position=Vector3(0,100.05,60)
 for hz in [30,60,120]:
  p.foot_time=0;var sounded=[0]
  await driver.advance(1,func(_dt):
   for frame in hz*3:
    p._physics_process(1.0/hz)
    var order=game.voice_idx;p.play_sound("step")
    if game.voice_idx>order:sounded[0]+=1)
  check(sounded[0]==10,"%d Hz permits exactly ten cues in three seconds despite a request every tick"%hz)
 # One hero cannot suppress another hero's footsteps or unrelated effects.
 p.select_character(1);p.foot_time=0;p.play_sound("step");var serial=game.voice_idx
 p.play_sound("step");check(game.voice_idx==serial,"Same-frame repeated footsteps are suppressed")
 p.play_sound("land");check(game.voice_idx==serial+1,"Footstep cooldown leaves landing sounds alone")
 var other=Hero.new();other.game=game;other.play_sound("step");other.free()
 check(game.voice_idx==serial+2,"Another hero owns an independent footstep interval")
 p.select_character(28);p.play_sound("step")
 check(game.voice_idx==serial+3,"Selection clears the old hero's footstep interval")
 game.paused=true;var remaining=p.foot_time;p._physics_process(1)
 check(p.foot_time==remaining,"Pause freezes the footstep interval");game.paused=false
 var nodes=get_node_count();var resources=Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)
 for repeat in 10000:p.play_sound("step")
 check(get_node_count()==nodes and Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)==resources,"Repeated blocked steps allocate no nodes or resources")
 if recorder:AudioServer.remove_bus_effect(bus,AudioServer.get_bus_effect_count(bus)-1)
 var audio_cfg=game.sound_library.config_path
 game.queue_free();current_scene=null;await frames(4)
 if FileAccess.file_exists(cfg):DirAccess.remove_absolute(ProjectSettings.globalize_path(cfg))
 if FileAccess.file_exists(audio_cfg):DirAccess.remove_absolute(ProjectSettings.globalize_path(audio_cfg))
 DirAccess.remove_absolute(ProjectSettings.globalize_path(audio_cfg.get_base_dir()))
 print("FOOTSTEP_CADENCE_RESULT checks=%d failures=%d desktop=%s"%[checks,failures,DisplayServer.get_name()!="headless"]);quit(1 if failures else 0)
