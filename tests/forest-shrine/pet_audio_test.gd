extends "res://scripts/recovered_goemon_gameplay_tests.gd"
const Pets=preload("res://scripts/forest/pet_catalog.gd")
const Kit=preload("res://scripts/forest/crowd/army_kit_data.gd")
const OUT="res://build/Other Files/Asset Toolkit/Pet Audio/"
var played:Array=[]

func native_attacks():
 var model=load("res://scripts/forest/forest_model.gd").new();model.reset(42)
 var runtime=load("res://scripts/forest/crowd/army_runtime.gd").new();runtime.configure(null);runtime.configure_kits(Kit.from_model(model))
 for skin in Pets.COUNT:
  for direction in 8:
   runtime.clear();runtime.set_navigation(skin*8+direction+1,{"width":0})
   var handle=runtime.spawn(10001,0,19,Vector3.ZERO,100000,.5);runtime.native.set_pet_skin(handle,skin)
   runtime.native.set_targets({"ids":PackedInt64Array([0]),"kinds":PackedInt32Array([0]),"positions":PackedVector3Array([Vector3(0,0,-1.5)]),"hp":PackedFloat32Array([100000]),"hound_camera_yaw":(direction-1)*PI/4.0})
   var got=[];var finished=false
   for tick in 400:
    runtime.step([.011,.031,.017,.026][tick%4],{})
    for event in runtime.take_events():
     if event.kind=="status" and event.action_index>=500:got.append([int(event.action_index)-500,float(event.source_tick)])
     if event.kind=="done":finished=true;break
    if finished:break
   var expected=[]
   for cue in Pets.motions().variants[skin].attack_directions[direction]:
    if int(cue.id)>0:expected.append([int(cue.id),float(cue.atMs)*.03])
   var matches=finished and got.size()==expected.size()
   if matches:
    for j in got.size():matches=matches and got[j][0]==expected[j][0] and absf(got[j][1]-expected[j][1])<.0001
   if not matches and failures<3:print("PET_AUDIO_TRACE skin=",skin," direction=",direction," got=",got," expected=",expected," finished=",finished)
   check(matches,"Original native attack cues: skin %d direction %d"%[skin,direction])
 runtime.clear();runtime.free()

func silence(fx):
 fx.suspend_audio();fx.pet_audio.clear();fx.effects.clear();played.clear()
func streams(fx)->Array:
 return fx.voices.filter(func(v):return v.playing).map(func(v):return v.stream)

func sample(skin:int,action:int,direction:int,time:float)->Dictionary:
 var velocity=Vector3.FORWARD*(3.0 if action==3 else .5 if action==1 else 0)
 return {"handles":PackedInt64Array([999]),"pose_rows":PackedInt32Array([skin]),"positions":PackedVector3Array([game.player.position]),"yaw":PackedFloat32Array([-(direction-1)*PI/4.0]),"kinds":PackedInt32Array([19]),"render_actions":PackedInt32Array([0]),"render_time":PackedFloat32Array([0]),"pose_velocities":PackedVector3Array([velocity]),"flash_left":PackedFloat32Array([0]),"status":PackedInt32Array([0]),"action_indices":PackedInt32Array([0]),"pose_time":PackedFloat32Array([time])}

func check_original_clips(fx):
 for skin in Pets.COUNT:
  for key in Pets.audio_clips[skin]:
   var clip:Dictionary=Pets.audio_clips[skin][key]
   var expected=clip.sounds.filter(func(c):return Pets.sounds.has(int(c.id))).map(func(c):return Pets.sounds[int(c.id)])
   silence(fx)
   if int(clip.action) in [8,10]:
    var record={"position":game.player.position,"sound_clip":clip}
    fx.pet_reaction_cues(record,-.000001,float(clip.duration_ms)/1000.0)
    played=streams(fx)
   else:
    fx.pet_audio[999]={}
    # Probe each marker separately so a long playing sample cannot mask the next marker.
    for cue in clip.sounds:
     fx.suspend_audio()
     var at=float(cue.atMs)/1000.0
     fx.pet_motion_cues(clip,game.player.position,at-.000001,at,999)
     played.append_array(streams(fx))
   check(played==expected,"Prepared original cues reach pooled playback: skin %d action %d direction %d"%[skin,clip.action,clip.direction])

func native_reactions(fx):
 var army=game.army_runtime
 army.clear();game.settings.forest_pet_loadout=[Pets.key(87),Pets.key(82)];army.refresh_kits();army.queue_hounds()
 for tick in 100:army.integration_tick(1.0/60);army.flush_presentation()
 silence(fx)
 var hurt:int=army.handles[army.HOUND_ID-87];var dying:int=army.handles[army.HOUND_ID-82]
 for handle in [hurt,dying]:army.set_pose(handle,game.player.position+Vector3.RIGHT*2,0)
 army.apply_hit(hurt,{"amount":1.0});army.flush_presentation()
 check(streams(fx).has(Pets.sounds[151]),"An actual native hit plays the original pet hurt cue")
 silence(fx)
 army.apply_hit(dying,{"amount":1000000.0});army.flush_presentation()
 check(not streams(fx).has(Pets.sounds[152]) and fx.effects.any(func(e):return e.kind=="pet-audio"),"An actual native death schedules its source cue without playing early")
 fx.tick(.149)
 check(not streams(fx).has(Pets.sounds[152]),"Death audio waits for original frame-one timing")
 fx.tick(.002)
 check(streams(fx).has(Pets.sounds[152]),"Death audio plays at its original 150 ms marker")
 fx.suspend_audio();army.clear();game.crowd.present_army(army.render_snapshot(),[])

func run():
 create_timer(300).timeout.connect(func():printerr("PET_AUDIO_TIMEOUT");quit(1))
 DirAccess.make_dir_recursive_absolute(OUT)
 native_attacks()
 var doc=load("res://scripts/forest/forest_map_document.gd").new();doc.load_wind_meadow();await setup_fixture(doc.data)
 game.player.select_character(34);game.set_process(false);game.army_runtime.set_process(false);game.army_runtime.set_physics_process(false);game.camera_rig.set_process(false);game.music.stop()
 game.settings.forest_pet_loadout=[];game.army_runtime.clear();game.model.enemies.clear()
 var fx=game.crowd.army.presentation
 check(Pets.audio_clips.size()==Pets.COUNT,"Every pet has prepared audio metadata")
 check_original_clips(fx)
 # The Yellow bee has frame-zero run buzzing in all eight directions.
 var skin=64;var buzz=Pets.sounds[161]
 for direction in 8:
  silence(fx)
  var s=sample(skin,3,direction,0)
  fx.present_pet_motion(s,0,0)
  check(streams(fx)==[buzz] and fx.pet_audio[999].voice.playing,"Bee movement starts original buzzing in direction %d"%direction)
  var voice=fx.pet_audio[999].voice
  s.pose_time[0]=.1;s.positions[0]+=Vector3.RIGHT
  fx.present_pet_motion(s,0,0)
  check(streams(fx)==[buzz] and voice.position==s.positions[0],"Movement updates the voice position without restarting it")
  s.pose_velocities[0]=Vector3.ZERO;fx.present_pet_motion(s,0,0)
  check(not voice.playing and fx.pet_audio.is_empty(),"Stopping the bee stops its movement voice")
 silence(fx)
 var move_clip:Dictionary=Pets.audio_clips[skin][3*8+4]
 fx.pet_audio[999]={};fx.clock=1;fx.pet_motion_cues(move_clip,game.player.position,-.000001,0,999)
 var loop_voice=fx.pet_audio[999].voice;var cycle=float(move_clip.duration_ms)/1000.0
 fx.clock=2;fx.pet_motion_cues(move_clip,game.player.position,cycle-.000001,cycle,999)
 check(fx.pet_audio[999].voice==loop_voice and loop_voice.get_meta("started")==2,"A source loop marker restarts the existing motion voice without layering or dropping its cue")
 silence(fx)
 var s=sample(skin,3,4,0);fx.present_pet_motion(s,0,0)
 var voice=fx.pet_audio[999].voice
 s.render_actions[0]=1;fx.present_pet_motion(s,0,0)
 check(not voice.playing and fx.pet_audio.is_empty(),"Attacking releases the movement voice for native attack audio")
 s.render_actions[0]=0;fx.present_pet_motion(s,0,0);voice=fx.pet_audio[999].voice
 s.positions[0]+=Vector3.RIGHT*100;fx.present_pet_motion(s,0,0)
 check(not voice.playing and fx.pet_audio.is_empty(),"Out-of-range pets release motion voices")
 silence(fx);s=sample(skin,3,4,0)
 game.paused=true;fx.present_pet_motion(s,0,0);check(streams(fx).is_empty(),"Paused gameplay cannot start pet sounds");game.paused=false
 silence(fx);game.sound_library.recording=true;fx.present_pet_motion(s,0,0);check(streams(fx).is_empty(),"Microphone recording suppresses pet playback");game.sound_library.recording=false
 # Verify actual native movement, recall and a hardware mixer capture through Play Goemon.
 silence(fx)
 game.settings.forest_pet_loadout=[Pets.key(skin)];game.army_runtime.refresh_kits();game.army_runtime.queue_hounds()
 var driver=load("res://tests/forest-shrine/physics_step_driver.gd").new();root.add_child(driver)
 for tick in 100:game.army_runtime.integration_tick(1.0/60);game.army_runtime.flush_presentation()
 var handle:int=game.army_runtime.handles.get(game.army_runtime.HOUND_ID-skin,0)
 check(handle!=0,"Bee arrives through the native lifecycle")
 var home=Vector3(-100,0,100);home.y=game.model.surface_height(home.x,home.z)
 game.player.position=home
 game.camera_rig.camera.global_position=home+Vector3(0,6,16);game.camera_rig.camera.look_at(home+Vector3.UP)
 game.army_runtime.set_pose(handle,home+Vector3.RIGHT*12,0)
 var bus=AudioServer.get_bus_index("SFX");var capture=AudioEffectCapture.new();capture.buffer_length=4;AudioServer.add_bus_effect(bus,capture)
 var heard=false
 for tick in 100:
  game.army_runtime.integration_tick(1.0/60);game.army_runtime.flush_presentation()
  heard=heard or fx.voices.any(func(v):return v.playing and v.stream==buzz)
  await driver.advance(1,func(_dt):pass)
 check(heard,"Real native moving bee plays its original movement buzz")
 var pcm=capture.get_buffer(capture.get_frames_available());var bytes=PackedByteArray();bytes.resize(pcm.size()*4);var peak=0.0
 for i in pcm.size():
  peak=maxf(peak,maxf(absf(pcm[i].x),absf(pcm[i].y)))
  bytes.encode_s16(i*4,clampi(roundi(pcm[i].x*32767),-32768,32767));bytes.encode_s16(i*4+2,clampi(roundi(pcm[i].y*32767),-32768,32767))
 if DisplayServer.get_name()!="headless":
  check(peak>.001 and peak<1,"Desktop mixer contains audible, unclipped pet movement audio")
  var wav=AudioStreamWAV.new();wav.format=AudioStreamWAV.FORMAT_16_BITS;wav.mix_rate=int(AudioServer.get_mix_rate());wav.stereo=true;wav.data=bytes;wav.save_to_wav(OUT+"bee-native-movement.wav")
 AudioServer.remove_bus_effect(bus,AudioServer.get_bus_effect_count(bus)-1)
 game.army_runtime.clear();game.crowd.present_army(game.army_runtime.render_snapshot(),[])
 check(fx.pet_audio.is_empty() and not fx.voices.any(func(v):return v.playing and v.get_meta("pet_motion_owner",0)!=0),"Recall clears movement ownership and playback")
 native_reactions(fx)
 silence(fx)
 var nodes=int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT));var resources=int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT));var times=[]
 for tick in 1200:
  var started=Time.get_ticks_usec()
  for pet in 5:
   s=sample(skin,3,pet,tick/60.0);s.handles[0]=1000+pet;fx.present_pet_motion(s,0,0)
  times.append(Time.get_ticks_usec()-started)
 check(int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))==nodes and int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT))==resources,"Repeated five-pet motion audio retains no nodes or resources")
 times.sort();print("PET_AUDIO_TIMING five_pet_callback_p95_us=",times[1140]," max_us=",times[-1]," mixer_peak=",peak)
 fx.clear()
 if DisplayServer.get_name()!="headless":
  await process_frame;await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png(OUT+"desktop-audio-check.png")
 game.queue_free();current_scene=null;await frames(4);driver.queue_free();await frames(2);DirAccess.remove_absolute(ProjectSettings.globalize_path(cfg))
 print("PET_AUDIO_RESULT checks=",checks," failures=",failures);quit(1 if failures else 0)
