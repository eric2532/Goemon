extends SceneTree
const Music=preload("res://scripts/forest/crossgate_music.gd")
const Tour=preload("res://scripts/forest/forest_falan_tour.gd")
const Roles=preload("res://scripts/forest/forest_enemy_roles.gd")
const OUT="res://build/Other Files/Asset Toolkit/Cross Gate Music/"
var checks=0
var failures=0
var game
var settings_path="/tmp/crossgate-building-music-test-%s.cfg"%OS.get_process_id()
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
  var source_key=stream.resource_path.get_file().get_basename()
  check(FileAccess.get_sha256(stream.resource_path)==provenance.tracks[source_key].runtime_sha256,"Prepared audio hash "+key)
  check(absf(stream.get_length()-float(provenance.tracks[source_key].duration))<.15,"Complete original track "+key)
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
 var config=ConfigFile.new();config.set_value("settings","music_enabled",true)
 check(config.save(settings_path)==OK,"Write isolated music preferences")
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
 check(track("m1") and game.music.get_playback_position()>10,"Starting a wave without nearby enemies retains the area theme")
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
 await battle_music()
 await boss_music()
 await elsa_music()
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
func elsa_music():
 var points:Array=JSON.parse_string(FileAccess.get_file_as_string("res://build/Other Files/Asset Toolkit/Elsa Island/review-points.json"))
 game.set_physics_process(false)
 for sample in [[59510,"puk2_haikyo"],[59500,"puk2_field1"],[59501,"puk2_field1"],[59520,"puk2_mati"],[59530,"puk2_sinden"],[59602,"d2"],[59725,"d4"],[59716,"d1"],[59511,""]]:
  var point:Dictionary=points.filter(func(p):return int(p.map)==sample[0])[0]
  var at=Music.Original.source_point(sample[0],Vector2i(point.cell[0],point.cell[1]))
  Tour.travel(game,Music.Original.layout(sample[0]),{"arrival":at,"yaw":0.0});await frames()
  var key:String=sample[1]
  check(game.music.stream==Music.STREAMS.get(key),"Native Elsa map selects source sound "+str(sample[0]))
  check(game.music.playing if key!="" else not game.music.playing,"Elsa playback or silence "+str(sample[0]))
  if key.begins_with("puk2_") and sample[0]!=59501 and DisplayServer.get_name()!="headless":await capture_mix(key+"-mix")
 await visit(Tour.Regions.layout("east_gate"),"f1")
 game.set_physics_process(true)
func battle_music():
 game.set_physics_process(false)
 var army=game.army_runtime
 army.finish_integration();army.clear();game.model.enemies.clear()
 game.battle_music_left=0;game.battle_music_probe=0;game.sync_area_music()
 var player=game.music;var nodes=game.get_child_count()
 var center:Vector3=game.player.global_position
 var radius=Music.BATTLE_RADIUS*game.model.falan_scale
 var ally=army.spawn(-900001,1,0,center+Vector3.RIGHT*2,100,.5)
 var far=army.spawn(900001,0,0,center+Vector3.RIGHT*(radius+5),100,.5)
 game._tick_battle_music(.3)
 check(track("f1"),"Allies and distant enemies leave the area theme playing")
 army.despawn(ally);army.despawn(far)
 var corner=army.spawn(900003,0,0,center+Vector3(.85,0,.85)*radius,100,.5)
 game._tick_battle_music(.3)
 check(track("f1"),"Enemies inside the query box but outside the encounter radius stay distant")
 army.despawn(corner)
 var high=army.spawn(900002,0,0,center+Vector3.UP*(radius+5),100,.5)
 game._tick_battle_music(.3)
 check(track("f1"),"Enemies on a distant floor do not start battle music")
 army.despawn(high)
 for i in 4:
  game.music.seek(12)
  var enemy=army.spawn(900010+i,0,0,center+Vector3.RIGHT*2,100,.5)
  game._tick_battle_music(.3)
  check(track("b0") and game.music.playing and game.music.stream.loop,"Nearby native enemy starts original looping battle music")
  game.music.seek(10);game._tick_battle_music(.3);game.sync_area_music()
  check(game.music.get_playback_position()>9,"Continued encounter does not restart the battle track")
  game.settings.music_enabled=false;game.apply_music_setting()
  check(not game.music.playing,"Battle music respects the existing mute preference")
  game.settings.music_enabled=true;game.apply_music_setting()
  check(track("b0") and game.music.playing,"Re-enabling music retains the battle theme")
  game.sound_library.recording=true;game.apply_music_setting()
  check(game.music.stream_paused,"Recording pauses the battle theme")
  game.sound_library.recording=false;game.apply_music_setting()
  army.despawn(enemy)
  game._tick_battle_music(1)
  check(track("b0"),"Short gaps between enemies retain battle music")
  game._tick_battle_music(Music.BATTLE_HOLD)
  check(track("f1") and game.music.playing and game.music.get_playback_position()>10,"Quiet period resumes the area track at its saved position")
 check(game.music==player and game.get_child_count()==nodes,"Repeated encounters reuse the music player and prepared streams")
 var crossing=army.spawn(900050,0,0,center+Vector3.RIGHT*2,100,.5)
 game._tick_battle_music(.3)
 var village=Music.Regions.village_transform("il_village")*Music.Regions.village_bounds("il_village").get_center()
 game.player.position=game.model.world_point(village,.15);game.sync_area_music()
 check(track("b0"),"Crossing a joined village boundary preserves an active battle track")
 army.despawn(crossing);game._tick_battle_music(Music.BATTLE_HOLD+.3)
 check(track("m3") and game.music_resume_stream==null,"Encounter ends on the destination theme without retaining a stale resume position")
 game.player.position=center;game.sync_area_music()
 var row=game.model.waves.spawn_enemy(0,center+Vector3.RIGHT*2)
 army.import_arrivals();game.battle_music_probe=0
 game.set_physics_process(true)
 for i in 4:await physics_frame
 check(track("b0"),"Actual gameplay physics detects a nearby enemy")
 game.set_physics_process(false)
 if DisplayServer.get_name()!="headless":await capture_mix("battle-mix")
 army.apply_hit(army.handles[row.id],{"amount":1000000.0,"direction":Vector3.FORWARD})
 game._tick_battle_music(Music.BATTLE_HOLD+.3)
 check(track("f1"),"Defeated enemies no longer keep battle music active")
 var next=army.spawn(900100,0,0,center+Vector3.RIGHT*2,100,.5)
 game._tick_battle_music(.3)
 check(track("b0"),"A later encounter starts battle music again")
 game.model.phase="preparing";game.set_phase_view()
 check(track("f1") and game.battle_music_left==0,"Preparation clears the previous encounter")
 army.despawn(next)
 game.model.phase="wave";game.set_phase_view()
 game.set_physics_process(true)
func boss_music():
 game.set_physics_process(false)
 var army=game.army_runtime
 var center:Vector3=game.player.global_position
 var scale_:float=game.model.falan_scale
 game.music.seek(12)
 var guard=game.model.waves.spawn_enemy(0,center+Vector3.RIGHT*2*scale_)
 var boss=game.model.waves.spawn_enemy(Roles.BOSS,center+Vector3.RIGHT*(Music.BOSS_RADIUS+5)*scale_)
 army.import_arrivals()
 game._tick_battle_music(.3)
 check(track("b0"),"Distant bosses leave the nearby patrol on the ordinary theme")
 army.set_pose(army.handles[boss.id],center+Vector3.RIGHT*24*scale_,0.)
 game._tick_battle_music(.3)
 check(track("b1") and game.music.playing and game.music.stream.loop,"Nearby native boss overrides the ordinary theme with the looping boss track")
 game.music.seek(10);game._tick_battle_music(.3);game.sync_area_music()
 check(game.music.get_playback_position()>9,"A living boss keeps the same playback position across probes")
 game.settings.music_enabled=false;game.apply_music_setting()
 check(track("b1") and not game.music.playing,"Boss music respects Background Music mute")
 game.settings.music_enabled=true;game.apply_music_setting()
 if DisplayServer.get_name()!="headless":await capture_mix("boss-mix")
 army.apply_hit(army.handles[boss.id],{"amount":1000000.0,"direction":Vector3.FORWARD})
 check(not army.boss_handles.has(boss.id),"Native boss death retires its music entry")
 game._tick_battle_music(1.)
 check(track("b1"),"Short boss phase gaps retain the boss theme")
 game._tick_battle_music(Music.BATTLE_HOLD)
 check(track("b0"),"A nearby retinue returns to ordinary battle music after the boss hold")
 army.despawn(army.handles[guard.id]);game._tick_battle_music(Music.BATTLE_HOLD)
 check(track("f1") and game.music.get_playback_position()>10,"Area playback resumes at its saved position across both combat tracks")

 var floor_=11004
 var at:Vector2=Tour.Regions.Sites.HABARU_FORMATION[0]+Vector2(0,5)
 Tour.travel(game,Tour.Indoor.layout(floor_),{"arrival":at,"yaw":0.0});await frames()
 check(track("d1") and is_instance_valid(game.habaru_waiting),"Habaru's waiting host keeps the cave theme")
 game.show_habaru_dialogue()
 check(track("d1") and is_instance_valid(game.dialogue),"Habaru's conversation keeps the cave theme")
 game.finish_habaru_dialogue()
 game.set_physics_process(true)
 for i in 30:await physics_frame
 check(track("b1") and game.music.playing,"Habaru's actual native encounter starts the boss theme after dialogue")
 game.set_physics_process(false)
 await visit(Tour.Regions.layout("east_gate"),"f1")
 check(game.boss_music_left==0. and army.boss_handles.is_empty(),"Travel clears the boss timer and native boss handles")
 game.set_physics_process(true)
func capture_mix(stem:String="freyja-mix"):
 var bus=AudioServer.get_bus_index("SFX");var was_muted=AudioServer.is_bus_mute(bus);AudioServer.set_bus_mute(bus,true)
 var capture=AudioEffectRecord.new();capture.format=AudioStreamWAV.FORMAT_16_BITS
 var slot=AudioServer.get_bus_effect_count(0);AudioServer.add_bus_effect(0,capture)
 capture.set_recording_active(true);game.music.seek(10)
 await create_timer(1.5).timeout
 capture.set_recording_active(false)
 var wav=capture.get_recording();var peak=0
 for i in range(0,wav.data.size(),2):peak=maxi(peak,absi(wav.data.decode_s16(i)))
 check(peak>100,"Rendered gameplay emits non-silent original music on Master")
 check(wav.save_to_wav(OUT+stem+".wav")==OK,"Capture the real music mix")
 AudioServer.remove_bus_effect(0,slot);AudioServer.set_bus_mute(bus,was_muted)
