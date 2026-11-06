extends "res://scripts/recovered_goemon_gameplay_tests.gd"
const OUT="res://build/Other Files/Asset Toolkit/Shared Goemon Footsteps/"
const Bank=preload("res://scripts/character_audio_bank.gd")
const SHARED=preload("res://assets/audio/recovered_yae/event_217.wav")
const MUSASHI=preload("res://assets/audio/recovered_musashi/foot_contact.wav")
const SHARED_IDS=[1,2,3,4,5,6,7,8,9,10,11,12,14,15,16,17,31,32,33,34]
const MOVEMENT_IDS=[1,5,7,8,14,15,16,17,28,31,32,34]

func run():
 create_timer(180).timeout.connect(func():printerr("SHARED_FOOTSTEPS_TIMEOUT");quit(1))
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
 var document=load("res://scripts/forest/forest_map_document.gd").new()
 check(document.load_wind_meadow()=="","Load the bundled Wind Meadow map")
 await setup_fixture(document.data)
 game.set_process(false);game.army_runtime.set_physics_process(false);game.music.stop()
 for node in [game,game.player,game.camera_rig]:
  node.set_process_input(false);node.set_process_unhandled_input(false)
 game.camera_focused=false;game._sync_camera_mouse()
 var p=game.player;var lib=game.sound_library
 DirAccess.make_dir_recursive_absolute(lib.config_path.get_base_dir())
 check(SoundLibrary.GOEMON_FOOTSTEP_IDS==SHARED_IDS,"Shared footstep policy covers exactly the requested roster")
 check(lib.shared_default_for(35,"step")==SHARED and lib.shared_default_for(1000,"step")==SHARED,"Future character IDs inherit Goemon's prepared footstep without registration")
 check(game.sounds.step==SHARED,"The engine's last footstep fallback is Goemon, never the early prototype")
 for id in SHARED_IDS:
  game.sound("step",.22,false,{},id)
  check(lib.original_for(id,"step")==SHARED and lib.shared_default_for(id,"step")==SHARED and game.sound_preview(id,"step")==SHARED and game.last_sound_voice.stream==SHARED and game.last_sound_voice.pitch_scale==1.0,"Fighter %d shares Goemon's default in gameplay, direct lookup and Studio"%id)
 for id in [13,18,19,20,21,22,23,24,25,26,27,28,29,30]:
  var original=lib.original_for(id,"step")
  var expected=null if lib.source_slot_is_silent(id,"step") else original if original!=null else SHARED
  check(lib.shared_default_for(id,"step")==SHARED and game.sound_preview(id,"step")==expected,"Fighter %d preserves distinct native footsteps/silence and defaults to Goemon"%id)
 for id in SoundLibrary.Roster.PLAYABLE_IDS:
  var preview=game.sound_preview(id,"step")
  check(preview==null or preview.resource_path!="res://audio/step.wav","Fighter %d cannot preview the retired prototype footstep"%id)
 check(preload("res://scripts/recovered_sasuke_audio.gd").stream_for("step")==preload("res://assets/audio/recovered_sasuke/event_218.wav"),"Sasuke's authentic source sample remains available separately from the requested shared gameplay default")
 check(preload("res://scripts/kojiro_audio.gd").stream_for("step")==preload("res://scripts/recovered_musashi_audio.gd").stream_for("musashi_step_0"),"Kojiro reuses Musashi's prepared footstep")
 var desktop=DisplayServer.get_name()!="headless"
 var recorder:AudioEffectRecord
 var bus=AudioServer.get_bus_index("SFX")
 if desktop:
  recorder=AudioEffectRecord.new();recorder.format=AudioStreamWAV.FORMAT_16_BITS
  AudioServer.add_bus_effect(bus,recorder)
 for id in MOVEMENT_IDS:
  p.select_character(id);fresh();p.set_scarf_equipped(false);lib.select_character(id)
  var expected=MUSASHI if id==28 else SHARED
  var level=.22 if id==28 else .65
  check(lib.original_for(id,"step")==expected and game.sound_preview(id,"step")==expected,"Fighter %d previews its requested walking default"%id)
  check(not lib.source_slot_is_silent(id,"step"),"Fighter %d has an audible source footstep"%id)
  if recorder:recorder.set_recording_active(true)
  for speed in [.2,.8]:
   p.position=Vector3(0,maxf(0,game.world.height_at(0,60))-.01,60)
   p.velocity=Vector3.DOWN;p.move_and_slide();p.velocity=Vector3.ZERO
   p.model.locomotion.reset();p.last_foot_events=0;p.foot_time=0;p.smoke_move=Vector2(speed,0)
   var first_step=p.model.locomotion.step_events
   var heard={}
   for frame in 100:
    var serial=game.voice_idx
    p._physics_process(1.0/60)
    for voice in game.voices:
     if voice.get_meta("order",-1)>serial and voice.get_meta("kind","")=="step":
      heard[voice.get_meta("order")]=[voice.stream,voice.pitch_scale,db_to_linear(voice.volume_db),frame]
    if desktop:await physics_frame
   check(heard.size()>=(1 if speed<.5 else 2),"Fighter %d emits real movement footsteps at input %.1f (events=%d last=%d floor=%s velocity=%s)"%[id,speed,p.model.locomotion.step_events,p.last_foot_events,p.is_on_floor(),p.velocity])
   if id in [31,32]:
    var final_step=p.model.locomotion.step_events
    check(heard.size()<=ceili(final_step/2.0)-ceili(first_step/2.0),"Fighter %d retains its alternate-step filter within the shared audio limit"%id)
   var cues=heard.values();var spaced=true
   for i in range(1,cues.size()):
    if (cues[i][3]-cues[i-1][3])/60.0<Hero.FOOTSTEP_INTERVAL-.000001:spaced=false
   check(spaced,"Fighter %d leaves at least %.2f seconds between footsteps at input %.1f"%[id,Hero.FOOTSTEP_INTERVAL,speed])
   check(not heard.is_empty() and heard.values().all(func(cue):return cue[0]==expected and cue[1]==1.0 and is_equal_approx(cue[2],level*.55)),"Fighter %d movement uses its requested sample, source pitch and gameplay level"%id)
  p.smoke_move=Vector2.ZERO
  for frame in 30:p._physics_process(1.0/60)
  var stopped_order=game.voice_idx
  for frame in 30:p._physics_process(1.0/60)
  check(game.voices.all(func(voice):return voice.get_meta("kind","")!="step" or voice.get_meta("order",-1)<=stopped_order),"Fighter %d stops emitting footsteps while standing still"%id)
  if recorder:
   await create_timer(.15).timeout;recorder.set_recording_active(false)
   var audio=recorder.get_recording()
   check(audio!=null and audio.data.count(0)<audio.data.size(),"Fighter %d produces audible desktop mixer output"%id)
   if audio:check(audio.save_to_wav(OUT+"walking-%d.wav"%id)==OK,"Save fighter %d walking output"%id)
   var scale_=maxf(1.0,p.model.scale.y)
   game.camera_rig.camera.global_position=p.global_position+Vector3(4,3,8)*scale_
   game.camera_rig.camera.look_at(p.global_position+Vector3.UP*scale_)
   await frames(2)
   RenderingServer.force_draw()
   check(root.get_texture().get_image().save_png(OUT+"walking-%d.png"%id)==OK,"Capture fighter %d on Wind Meadow"%id)
  lib.gains.step=.4;p.foot_time=0;p.play_sound("step",.5)
  check(game.last_sound_voice.stream==expected and is_equal_approx(db_to_linear(game.last_sound_voice.volume_db),.5*.55*.4),"Fighter %d retains its footstep volume control"%id)
  lib.mutes.step=true;var serial=game.voice_idx;p.foot_time=0;p.play_sound("step")
  check(game.voice_idx==serial,"Fighter %d footstep mute works"%id);lib.mutes.erase("step")
  lib.custom.step=game.sounds.hurt;p.foot_time=0;p.play_sound("step")
  check(game.last_sound_voice.stream==game.sounds.hurt and game.sound_preview(id,"step")==game.sounds.hurt,"Fighter %d saved take overrides the recovered default"%id)
  lib.reset_slot("step");p.foot_time=0;p.play_sound("step")
  check(game.last_sound_voice.stream==expected and lib.gain_for(id,"step")==1.0,"Restore default returns fighter %d to its requested sample and volume"%id)
 lib.recording=true;var serial=game.voice_idx;p.foot_time=0;p.play_sound("step")
 check(game.voice_idx==serial,"Recording suppresses walking playback");lib.recording=false
 var nodes=get_node_count();var resources=Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT);var cached=Bank.streams.size()
 for repeat in 1000:
  for id in SHARED_IDS+[28]:game.sound("step",.65,false,{},id)
 check(get_node_count()==nodes and Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)==resources and Bank.streams.size()==cached,"Overlapping footsteps reuse existing voices and prepared resources")
 if recorder:AudioServer.remove_bus_effect(bus,AudioServer.get_bus_effect_count(bus)-1)
 var audio_cfg=lib.config_path
 game.queue_free();current_scene=null;await frames(4)
 if FileAccess.file_exists(cfg):DirAccess.remove_absolute(ProjectSettings.globalize_path(cfg))
 if FileAccess.file_exists(audio_cfg):DirAccess.remove_absolute(ProjectSettings.globalize_path(audio_cfg))
 DirAccess.remove_absolute(ProjectSettings.globalize_path(audio_cfg.get_base_dir()))
 print("SHARED_FOOTSTEPS_RESULT checks=%d failures=%d desktop=%s"%[checks,failures,desktop]);quit(1 if failures else 0)
