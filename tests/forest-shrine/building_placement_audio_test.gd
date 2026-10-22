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
func run():
 var doc=load("res://scripts/forest/forest_map_document.gd").new();doc.load_original()
 set_meta("forest_custom_layout",doc.data);set_meta("forest_army_backend","legacy")
 game=load("res://scenes/forest_shrine.tscn").instantiate();game.settings_path=cfg;root.add_child(game);current_scene=game
 await frames();AudioServer.set_bus_mute(0,true)
 var sound=game.get_node_or_null("PlacementAudio")
 check(sound!=null,"The preparation game owns its building placement audio")
 if sound==null:await finish();return
 game.model.gold=10000;game.settings.volume=.65
 check(paused and game.paused and sound.can_process(),"Placement audio runs during the normal paused preparation phase")
 check(not sound.is_processing() and not sound.is_physics_processing(),"Placement audio adds no frame or physics tick")
 var streams=[]
 for i in 3:
  var before:int=sound.voice_cursor
  check(place("tower"),"Tower%d is purchased through the real placement path"%i)
  check(sound.voice_cursor==before+1,"A successful tower purchase plays exactly one sound")
  var voice:AudioStreamPlayer=sound.voices[before%sound.voices.size()]
  check(voice.playing and voice.can_process() and voice.stream.resource_path.get_file()=="tower-%d.wav"%(i+1),"Tower%d plays the approved variation at preparation time"%i)
  streams.append(voice.stream)
 var before:int=sound.voice_cursor
 check(place("barracks"),"The bunker is purchased through the real placement path")
 var bunker:AudioStreamPlayer=sound.voices[before%sound.voices.size()]
 check(sound.voice_cursor==before+1 and bunker.playing and bunker.stream.resource_path.get_file()=="bunker-1.wav","The barracks uses its deeper approved placement sound")
 check(bunker.stream.get_length()>streams[0].get_length() and bunker.pitch_scale==1,"The bunker retains its original tail and pitch")
 check(bunker.bus==&"Master" or bunker.bus==&"SFX","Placement playback follows the game's volume bus")
 for i in range(2,4):
  before=sound.voice_cursor
  var played:bool=sound.play_placement("barracks")
  var voice:AudioStreamPlayer=sound.voices[before%sound.voices.size()]
  check(played and sound.voice_cursor==before+1 and voice.playing and voice.stream.resource_path.get_file()=="bunker-%d.wav"%i,"The bunker cycles through approved variation %d"%i)
 for kind in sound.CLIPS:
  for clip in sound.CLIPS[kind]:
   check(clip is AudioStreamWAV and clip.format==AudioStreamWAV.FORMAT_16_BITS and clip.mix_rate==48000 and not clip.stereo,"Approved %s stays lossless mono 48 kHz PCM16"%clip.resource_path.get_file())
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
 check(not sound.play_placement("wall"),"Unconfigured building types do not borrow the approved sounds")
 var nodes=sound.get_child_count()
 for i in 24:sound.play_placement("tower" if i%2==0 else "barracks")
 check(sound.get_child_count()==nodes and sound.voices.size()<=4,"Rapid placements reuse a small fixed voice pool")
 for voice in sound.voices:check(voice.stream!=null and voice.pitch_scale==1,"Reused voices keep valid original-pitch audio")
 await finish()
func finish():
 game.sound_library.recording=false;game.sound_library.cancel();game.music.stop();game.queue_free();paused=false;await frames()
 if FileAccess.file_exists(cfg):DirAccess.remove_absolute(ProjectSettings.globalize_path(cfg))
 print("BUILDING_PLACEMENT_AUDIO_RESULT checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)
