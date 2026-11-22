extends SceneTree
const Music=preload("res://scripts/forest/crossgate_music.gd")
const Tour=preload("res://scripts/forest/forest_falan_tour.gd")
const OUT="res://build/Other Files/Asset Toolkit/Cross Gate Music/"
var checks=0
var failures=0
var game
var settings_path="user://building-music-test-%s.cfg"%OS.get_process_id()
func _initialize():
 create_timer(240).timeout.connect(func():printerr("MUSIC_TIMEOUT");quit(1))
 run.call_deferred()
func check(ok:bool,message:String):
 checks+=1
 if not ok:failures+=1;printerr("FAIL: "+message)
func track(key:String)->bool:return game.music.stream==Music.STREAMS[key]
func frames():
 for i in 4:await process_frame
func visit(layout:Dictionary,key:String):
 Tour.travel(game,layout,{"arrival":Vector2.ZERO,"yaw":0.0})
 await frames()
 check(track(key) and game.music.playing,"Travel selects "+key+" for "+Tour.area(game.model))
 if DisplayServer.get_name()!="headless":
  await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png(OUT+Tour.area(game.model)+".png")
func run():
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
 root.size=Vector2i(1280,800)
 var provenance=JSON.parse_string(FileAccess.get_file_as_string("res://assets/audio/crossgate/music/provenance.json"))
 for key in Music.STREAMS:
  var stream:AudioStreamMP3=Music.STREAMS[key]
  check(FileAccess.get_sha256(stream.resource_path)==provenance.tracks["cgbgm_"+key].runtime_sha256,"Prepared audio hash "+key)
  check(absf(stream.get_length()-float(provenance.tracks["cgbgm_"+key].duration))<.15,"Complete original track "+key)
 for row in [
  [["city",""],"m1"],[["castle"],"m0"],
  [["freyja","east_gate","south_gate","north_coast","west_lakes","south_lakes","tomato_road","tomato_farm"],"f1"],
  [["sokia_coast","sokia_desert","ghana_road","ghana_north_road"],"f2"],
  [["il_village","alyut","laruka","venoa"],"m3"],[["kili","ghana"],"m4"]]:
  for area in row[0]:check(Music.key(area,0,Vector2(-9999,-9999))==row[1],"Original regional theme "+area)
 for row in [[1011,"m1"],[1522,"m0"],[1530,"d2"],[2001,"m3"],[3201,"m4"],[3807,"m4"],[5007,"m3"],[11004,"d1"],[30101,"d2"],[30106,"d2"],[30201,"d2"],[30216,"d2"],[51201,"d2"],[51212,"d2"],[47040,"d1"],[51001,"d1"],[51004,"m2"],[51005,"m2"],[51008,"f0"],[51009,"d3"],[51010,"d4"],[51021,"m2"],[51024,"f0"],[51025,"d0"],[51101,"d0"]]:
  check(Music.key("interior",row[0])==row[1],"Interior and source alias "+str(row[0]))
 for area in Music.Regions.CONNECTED_VILLAGES:
  var village:String=Music.Regions.CONNECTED_VILLAGES[area]
  var center=Music.Regions.village_transform(village)*Music.Regions.village_bounds(village).get_center()
  check(Music.key(area,0,center)=="m3","Joined village keeps its own theme "+village)
 var config=ConfigFile.new();config.set_value("settings","music_enabled",true);config.save(settings_path)
 game=load("res://scenes/forest_title.tscn").instantiate();game.settings_path=settings_path
 root.add_child(game);current_scene=game;await frames()
 game.settings.forest_level_up_cards=false;game.settings.forest_pet_loadout=[]
 check(not game.music.playing and game.settings.music_enabled,"Title stays silent with music enabled")
 game.show_settings(false)
 var toggle=game.menu.find_child("BackgroundMusicToggle",true,false)
 toggle.button_pressed=false;toggle.button_pressed=true
 check(not game.music.playing,"Enabling music in title settings preserves silence")
 game.show_title();game.begin_arena();game.choose_rogue_character(34)
 check(not game.music.playing,"Cross Gate selection and Equipment stay silent before entering")
 game.enter_equipped_map();await frames()
 game.tuning.invincible=true
 check(track("m1") and game.music.playing and game.music.stream.loop,"Arena uses the original looping Falan theme")
 game.model.phase="preparing";game.set_phase_view()
 check(paused and game.music.can_process() and not game.music.stream_paused,"Preparation's paused tree keeps music playing")
 game.music.seek(12);game.start_wave()
 check(track("m1") and game.music.get_playback_position()>10,"Combat retains the area's theme without restarting")
 game.show_settings(true);toggle=game.menu.find_child("BackgroundMusicToggle",true,false);toggle.button_pressed=false
 check(not game.music.playing,"Settings mutes music")
 game.resume()
 var venture:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/maps/falan/web_adventure.json"))
 await muted_visit(venture.falan_areas.city)
 check(not game.music.playing,"Travel respects mute")
 game.show_settings(true);toggle=game.menu.find_child("BackgroundMusicToggle",true,false);toggle.button_pressed=true
 check(track("m1") and game.music.playing,"Settings enables the current area's music")
 game.resume()
 await visit(venture.falan_areas.castle,"m0")
 await visit(Tour.Regions.layout("east_gate"),"f1")
 var player=game.music;var node_count=game.get_child_count()
 for i in 4:
  var village="il_village"
  var at=Music.Regions.village_transform(village)*Music.Regions.village_bounds(village).get_center()
  game.player.position=game.model.world_point(at,.15)
  await physics_frame;await physics_frame
  check(track("m3") and game.music.playing,"Walking into joined Il selects its village theme")
  game.player.position=game.model.world_point(Vector2.ZERO,.15)
  await physics_frame;await physics_frame
  check(track("f1") and game.music.playing,"Walking back outdoors restores Freyja")
 check(game.music==player and game.get_child_count()==node_count,"Repeated crossings reuse one player and prepared streams")
 game.music.seek(12);game.sync_area_music()
 check(game.music.get_playback_position()>10,"Same-area updates do not restart playback")
 game.sound_library.recording=true;game.apply_music_setting()
 check(game.music.stream_paused,"Sound Studio recording still pauses music")
 game.sound_library.recording=false;game.apply_music_setting()
 check(not game.music.stream_paused,"Music resumes after recording")
 if DisplayServer.get_name()!="headless":await capture_mix()
 game.show_title();check(not game.music.playing and game.settings.music_enabled,"Returning to title stops music and preserves preference")
 game.sound_library.cancel();game.music.stop();game.queue_free();current_scene=null;paused=false;await frames()
 DirAccess.remove_absolute(ProjectSettings.globalize_path(settings_path))
 print("BUILDING_MUSIC_RESULT checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)
func muted_visit(layout:Dictionary):
 Tour.travel(game,layout,{"arrival":Vector2.ZERO,"yaw":0.0})
 await frames()
 check(track("m1") and not game.music.playing,"Muted travel still selects the destination track")
func capture_mix():
 var bus=AudioServer.get_bus_index("SFX");var was_muted=AudioServer.is_bus_mute(bus);AudioServer.set_bus_mute(bus,true)
 var capture=AudioEffectRecord.new();capture.format=AudioStreamWAV.FORMAT_16_BITS
 var slot=AudioServer.get_bus_effect_count(0);AudioServer.add_bus_effect(0,capture)
 capture.set_recording_active(true);game.music.seek(10)
 await create_timer(1.5).timeout
 capture.set_recording_active(false)
 var wav=capture.get_recording();var peak=0
 for i in range(0,wav.data.size(),2):peak=maxi(peak,absi(wav.data.decode_s16(i)))
 check(peak>100,"Rendered gameplay emits non-silent original music on Master")
 check(wav.save_to_wav(OUT+"freyja-mix.wav")==OK,"Capture the real music mix")
 AudioServer.remove_bus_effect(0,slot);AudioServer.set_bus_mute(bus,was_muted)
