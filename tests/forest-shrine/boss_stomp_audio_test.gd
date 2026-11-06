extends "res://scripts/recovered_goemon_gameplay_tests.gd"
const Dark=preload("res://scripts/forest/dark_lumina_kit.gd")
const OUT="res://build/Other Files/Asset Toolkit/Boss Stomp Audio/"
var home=Vector3(0,.1,140)
var heard=[]
var serial=0
var spatial_stomps=[]
var spatial_seen={}
var recorder:AudioEffectRecord
var focused=0
var stepped=0
func advance(count:int):
 for i in count:
  game.player._physics_process(1.0/60);game.crowd.army.presentation.tick(1.0/60)
  for voice in game.voices:
   var order=int(voice.get_meta("order",0))
   if order<=serial:continue
   if voice.get_meta("kind","") in ["land","dark_lumina_2_slam"]:heard.append({"order":order,"stream":voice.stream,"floor":game.player.is_on_floor(),"frame":stepped})
  for voice in game.crowd.army.presentation.voices:
   if not voice.playing or voice.stream!=Dark.sounds.get("slam"):continue
   var stamp="%d:%s"%[voice.get_instance_id(),voice.get_meta("started",-1)]
   if spatial_seen.has(stamp):continue
   spatial_seen[stamp]=true;spatial_stomps.append({"floor":game.player.is_on_floor(),"frame":stepped})
  serial=game.voice_idx;stepped+=1
  if DisplayServer.get_name()!="headless" and root.has_focus():focused+=1
  await physics_frame
func reset_audio():
 for voice in game.voices:voice.stop()
 for voice in game.crowd.army.presentation.voices:voice.stop()
 if game.player.character_id==27:
  for voice in game.player.model.skull.voices:voice.stop()
 heard.clear();spatial_stomps.clear();spatial_seen.clear();serial=game.voice_idx
 if recorder:recorder.set_recording_active(true)
func record(label_:String):
 if recorder==null:return
 await create_timer(.8).timeout;recorder.set_recording_active(false)
 var audio=recorder.get_recording()
 check(audio!=null and audio.data.count(0)<audio.data.size(),"Desktop mixer contains "+label_)
 if audio:audio.save_to_wav(OUT+label_+".wav")
func fresh(surge:bool=false):
 if game.player.active_ability!=null:game.player.active_ability.cancel()
 game.player.spell_loadout.cancel();super.fresh(surge)
 game.player.position=home;game.player.was_floor=true
 game.training_dummy.home=home+Vector3(0,0,-80);game.training_dummy.position=game.training_dummy.home
 game.model.update_vision(home)
func run():
 create_timer(180).timeout.connect(func():printerr("BOSS_STOMP_AUDIO_TIMEOUT");quit(1))
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
 var map=preload("res://scripts/forest/forest_map_document.gd").new();map.load_wind_meadow();await setup_fixture(map.data)
 home.y=game.model.surface_height(home.x,home.z)+.1
 game.set_process(false);game.army_runtime.set_physics_process(false);game.music.stop()
 game.set_process_input(false);game.set_process_unhandled_input(false)
 game.player.set_process_input(false);game.player.set_process_unhandled_input(false)
 game.tuning.invincible=true
 if DisplayServer.get_name()!="headless":
  DisplayServer.window_set_title("Goemon · boss stomp landing audio (DEBUG)")
  DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_ALWAYS_ON_TOP,true);DisplayServer.window_move_to_foreground()
  recorder=AudioEffectRecord.new();recorder.format=AudioStreamWAV.FORMAT_16_BITS;AudioServer.add_bus_effect(AudioServer.get_bus_index("SFX"),recorder)
 var p=game.player;var presentation=game.crowd.army.presentation
 for id in [27,29]:
  p.select_character(id);fresh();await advance(4);reset_audio()
  var expected=SoundLibrary.original_for(27,"land") if id==27 else Dark.sounds.slam
  var skull_before=p.model.skull.audio_started if id==27 else 0
  tap("heavy_attack");await advance(12)
  check(heard.is_empty(),"Boss %d emits no landing sound during windup"%id)
  for i in 200:
   await advance(1)
   if not p.active_ability.is_attacking():break
  check(heard.size()==1 and heard[0].stream==expected and heard[0].floor,"Boss %d plays its own original impact once on physical landing"%id)
  if id==27:check(p.model.skull.audio_started==skull_before,"Skullpion timed presentation does not duplicate the physical impact")
  else:
   check(spatial_stomps.is_empty(),"DL2 wave presentation does not replay the physical impact")
  await record("stomp-%d"%id)
 p.select_character(29);fresh();await advance(4);tap("jump");await advance(18);reset_audio();tap("surge");await advance(120)
 check(heard.size()==1 and heard[0].stream==Dark.sounds.slam and heard[0].floor and spatial_stomps.is_empty(),"DL2 mid-jump stomp also plays exactly one original landing sound")
 await record("aerial-stomp-29")
 fresh();await advance(4);reset_audio();p.position.y+=12;p.was_floor=false;p.velocity=Vector3.DOWN*30;await advance(90)
 check(heard.size()==1 and heard[0].stream==Dark.sounds.slam,"DL2 ordinary falls use the same stomp landing impact")
 p.select_character(1);fresh();await advance(4);p.spell_loadout.equip(1,"equip","dark-lumina-2/shockwave")
 p.position.y+=12;p.velocity=Vector3.DOWN*20;p.move_and_slide();reset_audio();tap("equip");await advance(150)
 check(spatial_stomps.size()==1 and spatial_stomps[0].floor,"Borrowed DL2 stomp retains one original donor impact on landing (heard=%s)"%str(spatial_stomps))
 await record("borrowed-stomp-29");p.spell_loadout.equip(1,"equip","")
 var lib=game.sound_library
 for id in [27,29]:
  p.select_character(id);fresh();await advance(4);lib.select_character(id);reset_audio()
  var slot="land" if id==27 else Dark.slot_for("slam")
  lib.custom[slot]=Dark.sounds.claw;lib.gains[slot]=.5;p.play_sound("land",.8)
  check(game.last_sound_voice.stream==Dark.sounds.claw and is_equal_approx(db_to_linear(game.last_sound_voice.volume_db),.8*.55*.5),"Boss %d landing honors its saved recording and gain"%id)
  lib.mutes[slot]=true;var before=game.voice_idx;p.play_sound("land")
  check(game.voice_idx==before,"Boss %d landing respects mute"%id)
  lib.custom.erase(slot);lib.gains.erase(slot);lib.mutes.erase(slot)
 p.select_character(29);fresh();await advance(4)
 for voice in presentation.voices:voice.stream=Dark.sounds.breath;voice.play();voice.set_meta("loop_until",0)
 presentation.next_sound=presentation.clock+10
 presentation.dark_cue(p.position,8,0,-99)
 check(presentation.voices.any(func(v):return v.playing and v.stream==Dark.sounds.slam and v.max_distance==Dark.SOUND_RANGE),"Native DL2 stomp preempts ordinary crowded sounds through the existing priority pool")
 if recorder:recorder.set_recording_active(false)
 var result={"checks":checks,"failures":failures,"stepped_frames":stepped,"focused_frames":focused,"note":"Rendered physical landing and desktop mixer verification for both bosses; no long-session benchmark"}
 FileAccess.open(OUT+"results.json",FileAccess.WRITE).store_string(JSON.stringify(result,"  "));print("BOSS_STOMP_AUDIO_RESULT ",result)
 game.queue_free();await frames(3);DirAccess.remove_absolute(cfg);quit(1 if failures else 0)
