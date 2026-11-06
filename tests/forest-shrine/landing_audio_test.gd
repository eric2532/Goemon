extends "res://scripts/recovered_goemon_gameplay_tests.gd"
const OUT="res://build/Other Files/Asset Toolkit/Humanoid Landing Audio/"
const HUMANOIDS=[1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,20,21,22,23,25,26,28,34]
const HUMAN_LAND=preload("res://assets/audio/recovered_yae/event_21e.wav")
var landing_orders={}

func advance(count:int):
 for i in count:
  game.player._physics_process(1.0/60)
  for voice in game.voices:
   if voice.get_meta("kind","")=="land":landing_orders[voice.get_meta("order")]=voice.stream
  await physics_frame

func stop_audio(node:Node):
 if node is AudioStreamPlayer or node is AudioStreamPlayer3D:node.stop()
 for child in node.get_children():stop_audio(child)

func run():
 create_timer(120).timeout.connect(func():printerr("FAIL: landing audio timeout");quit(1))
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
 await setup_fixture()
 game.set_process(false);game.army_runtime.set_physics_process(false)
 game.music.stop()
 var p=game.player;var lib=game.sound_library
 var original=load(SoundLibrary.LANDING_FILE)
 var backup=load("res://assets/characters/recovered_monsters/audio/dark_lumina_2/slam.wav")
 check(game.sounds.land==HUMAN_LAND,"Every shared landing fallback uses Goemon's prepared sample")
 for id in [35,1000]:check(SoundLibrary.shared_default_for(id,"land")==HUMAN_LAND and lib.playback_for(id,"land",original).stream==HUMAN_LAND,"Unregistered fighter %d inherits Goemon's landing"%id)
 for id in p.RogueRoster.selection_ids():
  var own=SoundLibrary.original_for(id,"land")
  var expected=own if own!=null else HUMAN_LAND
  if SoundLibrary.source_slot_is_silent(id,"land"):expected=null
  if id in HUMANOIDS:expected=HUMAN_LAND
  check(game.sound_preview(id,"land")==expected,"Fighter %d previews Goemon's default or its distinct recovered landing"%id)
 game.sound("land",.7,false,{},27)
 check(game.last_sound_voice.stream==original and game.last_sound_voice.pitch_scale==1,"Gameplay uses the prepared Skullpion sample at source pitch")
 SoundLibrary.landing_sound=null
 check(game.sound_preview(27,"land")==backup,"Missing primary falls back to Dark Lumina 2 in preview")
 game.sound("land",.7,false,{},27)
 check(game.last_sound_voice.stream==backup and game.last_sound_voice.pitch_scale==1,"Gameplay fallback uses Dark Lumina 2 at source pitch")
 p.select_character(27);fresh();p.set_scarf_equipped(false)
 check(p.model.skull.sounds[0x560]==backup,"Existing boss presentation resolves the same backup during setup")
 SoundLibrary.landing_sound=original;p.model.skull.sounds[0x560]=original
 game.settings.jump_styles={};p.jump_style.prepare()
 lib.select_character(27)
 var take=AudioStreamWAV.new();take.format=AudioStreamWAV.FORMAT_16_BITS;take.mix_rate=22050;take.data=PackedByteArray([0,32,0,0])
 lib.custom.land=take;lib.gains.land=.5
 p.play_sound("land",.8)
 check(game.last_sound_voice.stream==take and is_equal_approx(db_to_linear(game.last_sound_voice.volume_db),.8*.55*.5),"Existing saved landing recordings and gain retain priority")
 lib.mutes.land=true
 var serial=game.voice_idx;p.play_sound("land")
 check(game.voice_idx==serial,"Landing respects the existing character mute")
 lib.mutes.erase("land");lib.recording=true;p.play_sound("land")
 check(game.voice_idx==serial,"Recording suppresses landing playback")
 lib.recording=false;lib.custom.erase("land");lib.gains.erase("land")
 for repeat in 3:
  p.cancel_charge();p.position=ORIGIN+Vector3.UP*60;p.velocity=Vector3.DOWN*30;p.was_floor=false
  landing_orders.clear()
  var before=game.voice_idx
  await advance(90)
  var emitted=landing_orders.keys().filter(func(order):return order>before)
  check(p.is_on_floor() and emitted.size()==1,"Physical fall %d emits one landing event"%repeat)
  check(emitted.all(func(order):return landing_orders[order]==original),"Physical landing selects Skullpion's prepared sample")
 p.cancel_charge();p.was_floor=true;landing_orders.clear()
 var before=game.voice_idx;var boss_before=p.model.skull.audio_started
 p.active_ability.start_skull_attack(104)
 await advance(120)
 var emitted=landing_orders.keys().filter(func(order):return order>before)
 check(p.is_on_floor() and emitted.size()==1,"Jump stomp emits one physical landing sound")
 check(p.model.skull.audio_started==boss_before,"The stomp's timed presentation cannot add a duplicate impact")
 check(not p.active_ability.is_attacking(),"Jump stomp retains its existing recovery")
 # Exercise every humanoid's real floor transition, including Rogue's movement owner.
 for id in HUMANOIDS:
  p.select_character(id);fresh();p.set_scarf_equipped(false);p.jump_style.prepare()
  p.position=ORIGIN+Vector3.UP*3;p.velocity=Vector3.DOWN*10;p.was_floor=false
  landing_orders.clear();var humanoid_start=game.voice_idx
  await advance(70)
  var orders=landing_orders.keys().filter(func(order):return order>humanoid_start)
  check(p.is_on_floor() and orders.size()==1,"Humanoid %d emits exactly one physical landing"%id)
  check(orders.size()==1 and landing_orders[orders[0]]==HUMAN_LAND,"Humanoid %d lands with shared ROM event 21E"%id)
  if "--visual" in OS.get_cmdline_user_args() and id in [1,7]:
   check(root.get_texture().get_image().save_png(OUT+"landed-%d.png"%id)==OK,"Capture humanoid %d after real landing"%id)
 p.select_character(1);fresh()
 for id in HUMANOIDS:
  game.sound("land",.7,false,{},id)
  check(game.last_sound_voice.stream==HUMAN_LAND and game.last_sound_voice.pitch_scale==1,"Explicit humanoid owner %d shares the prepared landing at source pitch"%id)
 lib.select_character(7);lib.custom.land=take;lib.gains.land=.5
 game.sound("land",.8,false,{},7)
 check(game.last_sound_voice.stream==take and is_equal_approx(db_to_linear(game.last_sound_voice.volume_db),.8*.55*.5),"Humanoid saved landing and gain still override the shared default")
 lib.mutes.land=true;var muted_order=game.voice_idx;game.sound("land",1,false,{},7)
 check(game.voice_idx==muted_order,"Humanoid landing mute suppresses playback")
 lib.custom.erase("land");lib.gains.erase("land");lib.mutes.erase("land")
 stop_audio(game);await create_timer(.2).timeout
 var nodes=get_node_count();var resources=Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)
 for i in 100:
  for id in HUMANOIDS:game.sound("land",.5,false,{},id)
 check(get_node_count()==nodes and Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)==resources,"2,500 overlapping humanoid landings reuse existing voices and prepared resources")
 if "--visual" in OS.get_cmdline_user_args():
  stop_audio(game)
  var capture=AudioEffectRecord.new();capture.format=AudioStreamWAV.FORMAT_16_BITS
  var bus=AudioServer.get_bus_index("SFX");AudioServer.add_bus_effect(bus,capture)
  capture.set_recording_active(true);p.play_sound("land")
  await create_timer(1.2).timeout;capture.set_recording_active(false)
  var recording=capture.get_recording()
  check(recording!=null and recording.data.count(0)<recording.data.size(),"Desktop SFX mixer produces audible landing output")
  if recording!=null:check(recording.save_to_wav(OUT+"humanoid-landing.wav")==OK,"Save desktop landing output for listening")
  AudioServer.remove_bus_effect(bus,AudioServer.get_bus_effect_count(bus)-1)
 game.queue_free();game=null;paused=false;await frames(3)
 if FileAccess.file_exists(cfg):DirAccess.remove_absolute(ProjectSettings.globalize_path(cfg))
 print("LANDING_AUDIO_RESULT checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)
