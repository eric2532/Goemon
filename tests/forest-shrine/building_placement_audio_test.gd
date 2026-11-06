extends SceneTree
var game
var checks=0
var failures=0
var cfg="user://placement-audio-%d.cfg"%OS.get_process_id()
func _initialize():run.call_deferred()
func check(ok:bool,label_:String):
 checks+=1
 if not ok:failures+=1;printerr("FAIL: ",label_)
func frames():
 for i in 3:await process_frame
func place(kind:String)->bool:
 game.select_build(kind)
 for z in range(-22,23):
  for x in range(-22,23):
   var cell=Vector2i(x,z)
   if game.model.placement_error(kind,cell,0).is_empty():return game.place_cell(cell)
 return false
func drag_wall()->bool:
 game.select_build("wall")
 for z in range(-22,23):
  for x in range(-22,22):
   var start=Vector2i(x,z);var end=start+Vector2i.RIGHT*game.model.SIZES.wall.x
   if not game.model.placement_error("wall",start,0).is_empty() or not game.model.placement_error("wall",end,0).is_empty():continue
   var before=game.model.buildings.size()
   game.wall_start=start
   var event=InputEventMouseButton.new();event.button_index=MOUSE_BUTTON_LEFT;event.pressed=false
   event.position=game.camera_rig.camera.unproject_position(game.model.point(end))
   game._unhandled_input(event)
   if game.model.buildings.size()>before:return game.model.buildings.size()==before+2
 return false
func run():
 var doc=load("res://scripts/forest/forest_map_document.gd").new();doc.load_wind_meadow()
 set_meta("forest_custom_layout",doc.data);
 game=load("res://scenes/forest_shrine.tscn").instantiate();game.settings_path=cfg;root.add_child(game);current_scene=game
 await frames();AudioServer.set_bus_mute(0,true)
 var sound=game.get_node_or_null("PlacementAudio")
 check(sound!=null,"The preparation game owns its building placement audio")
 if sound==null:await finish();return
 game.model.gold=10000;game.settings.volume=.65
 check(paused and game.paused and sound.can_process(),"Placement audio runs during the normal paused preparation phase")
 check(not sound.is_physics_processing(),"Work audio adds no physics tick")
 var streams=[]
 for i in 3:
  var before:int=sound.voice_cursor
  check(place("tower"),"Tower%d is purchased through the real placement path"%i)
  check(sound.voice_cursor==before+2 and sound.voices[(before+1)%4].stream==sound.CANNON.complete,"A successful tower purchase plays placement and Job's done once each")
  var voice:AudioStreamPlayer=sound.voices[before%sound.voices.size()]
  check(voice.playing and voice.can_process() and voice.stream==sound.PLACEMENT,"Tower%d plays the original Warcraft placement cue at preparation time"%i)
  streams.append(voice.stream)
 var before:int=sound.voice_cursor
 check(place("barracks"),"The bunker is purchased through the real placement path")
 var bunker:AudioStreamPlayer=sound.voices[before%sound.voices.size()]
 check(sound.voice_cursor==before+2 and bunker.playing and bunker.stream==sound.PLACEMENT and sound.voices[(before+1)%4].stream==sound.CANNON.complete,"The farm uses the same placement and completion cues")
 check(bunker.stream==streams[0] and bunker.pitch_scale==1,"The original sample and pitch are preserved")
 check(bunker.bus==&"Master" or bunker.bus==&"SFX","Placement playback follows the game's volume bus")
 for i in 3:
  before=sound.voice_cursor;sound.play_hammer()
  var voice:AudioStreamPlayer=sound.voices[before%sound.voices.size()]
  check(voice.playing and voice.stream==sound.CLIPS[i],"Worker hammer variation %d is preserved independently of placements"%(i+1))
 for kind in ["mine","wall","gate","shrine","enemy_castle","cannon_tower"]:
  before=sound.voice_cursor
  check(sound.play_placement(kind) and sound.voice_cursor==before+2 and sound.voices[before%4].stream==sound.PLACEMENT and sound.voices[(before+1)%4].stream==sound.CANNON.complete,"Every building plays placement and Job's done once each: "+kind)
 var placement:AudioStreamWAV=sound.PLACEMENT
 check(placement.format==AudioStreamWAV.FORMAT_16_BITS and placement.mix_rate==22050 and not placement.stereo,"Placement preserves original mono 22,050 Hz PCM16")
 var provenance=JSON.parse_string(FileAccess.get_file_as_string("res://assets/audio/warcraft_building/source.json"))
 var hash_=HashingContext.new();hash_.start(HashingContext.HASH_SHA256);hash_.update(placement.data)
 check(hash_.finish().hex_encode()==provenance.pcm_sha256,"Imported placement PCM matches the Warcraft archive byte for byte")
 before=sound.voice_cursor
 check(drag_wall() and sound.voice_cursor==before+2,"A real two-piece wall drag plays placement and Job's done once for the whole purchase")
 game.select_build("");game.forest_ui.selected_id=game.model.buildings.values().filter(func(b):return b.kind=="tower")[0].id
 game.forest_ui.sync();await frames()
 var actions=game.forest_ui.inspection.find_children("*","Button",true,false).map(func(b):return b.text)
 check(game.forest_ui.inspection.visible and actions==["REPAIR BUILDING","REMOVE · 50% REFUND"],"Preparation inspection omits manual worker assignment and retains repair/removal")
 check(not game.forest_ui.build_buttons.cannon_tower.tooltip_text.contains("Assign workers"),"Cannon tooltip no longer asks for the removed action")
 if DisplayServer.get_name()!="headless":
  var out="res://build/Other Files/Asset Toolkit/Construction and Level Audio/"
  DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out))
  await RenderingServer.frame_post_draw
  check(root.get_texture().get_image().save_png(out+"automatic-workers.png")==OK,"Capture simplified preparation inspection")
 for clip in sound.CLIPS:
  check(clip is AudioStreamWAV and clip.format==AudioStreamWAV.FORMAT_16_BITS and clip.mix_rate==22050 and not clip.stereo,"Recovered %s stays lossless mono 22,050 Hz PCM16"%clip.resource_path.get_file())
 before=sound.voice_cursor
 game.select_build("tower");game.world.show_preview("tower",Vector2i(3,-3),0,true)
 check(sound.voice_cursor==before,"Selecting and previewing a building stays silent")
 check(not game.place_cell(Vector2i(500,500)) and sound.voice_cursor==before,"Rejected placement never plays success audio")
 game.model.gold=0;game.select_build("tower")
 check(not game.place_cell(Vector2i(3,-3)) and sound.voice_cursor==before,"Unaffordable placement stays silent")
 game.model.gold=10000;game.settings.volume=0
 check(place("tower") and sound.voice_cursor==before,"Muted placement still builds without playing a voice")
 game.settings.volume=.65;game.sound_library.recording=true
 check(place("barracks") and sound.voice_cursor==before,"Sound recording suppresses placement audio without blocking the building")
 game.sound_library.recording=false;game.ordinary_pause=true
 check(not sound.play_placement("tower"),"An explicit pause prevents new placement feedback")
 game.ordinary_pause=false;game.model.phase="wave"
 check(not sound.play_placement("tower"),"Combat cannot trigger building placement audio")
 game.model.phase="preparing"
 check(sound.play_placement("wall"),"Construction uses the requested Warcraft placement sound")
 var nodes=sound.get_child_count()
 for i in 24:sound.play_placement("tower" if i%2==0 else "barracks")
 check(sound.get_child_count()==nodes and sound.voices.size()<=4,"Rapid placements reuse a small fixed voice pool")
 for voice in sound.voices:check(voice.stream!=null and voice.pitch_scale==1,"Reused voices keep valid original-pitch audio")
 if DisplayServer.get_name()!="headless":
  var recorder=AudioEffectRecord.new();recorder.format=AudioStreamWAV.FORMAT_16_BITS
  var bus=AudioServer.get_bus_index("SFX");AudioServer.add_bus_effect(bus,recorder)
  for voice in sound.voices:voice.stop()
  recorder.set_recording_active(true);sound.play_placement("tower")
  await create_timer(1.4).timeout;recorder.set_recording_active(false)
  var audio=recorder.get_recording()
  check(audio!=null and audio.data.count(0)<audio.data.size(),"Desktop mixer plays placement while preparation is paused")
  var out="res://build/Other Files/Asset Toolkit/Construction and Level Audio/"
  DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out))
  if audio:audio.save_to_wav(out+"placement-playback.wav")
  AudioServer.remove_bus_effect(bus,AudioServer.get_bus_effect_count(bus)-1)
 await finish()
func finish():
 game.sound_library.recording=false;game.sound_library.cancel();game.music.stop();game.queue_free();paused=false;await frames()
 if FileAccess.file_exists(cfg):DirAccess.remove_absolute(ProjectSettings.globalize_path(cfg))
 print("BUILDING_PLACEMENT_AUDIO_RESULT checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)
