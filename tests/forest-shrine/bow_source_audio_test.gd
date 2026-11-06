extends SceneTree
var checks=0
var failures=0
var game
var cfg="user://bow-source-%d.cfg"%OS.get_process_id()
var studio="user://bow-source-studio-%d.cfg"%OS.get_process_id()
func _initialize():run.call_deferred()
func check(ok: bool,note: String):
 checks+=1;print("PASS: " if ok else "FAIL: ",note)
 if not ok:failures+=1
func frames(n=3):
 for i in n:await process_frame
func latest(pool)->String:
 var voice=pool.voices[posmod(pool.cursor-1,pool.voices.size())]
 return voice.stream.resource_path.get_file() if voice.stream!=null else ""
func pcm_hash(data:PackedByteArray)->String:
 var hash=HashingContext.new();hash.start(HashingContext.HASH_SHA256);hash.update(data);return hash.finish().hex_encode()
func run():
 var map=load("res://tests/forest-shrine/reference/map_document.gd").new();map.load_original();set_meta("forest_custom_layout",map.data)
 game=load("res://scenes/forest_shrine.tscn").instantiate();game.settings_path=cfg;root.add_child(game);current_scene=game;await frames()
 game.sound_library.free();var lib=load("res://scripts/sound_library.gd").new();lib.folder="user://bow-source-takes-%d"%OS.get_process_id();lib.config_path=studio;root.add_child(lib);lib.game=game;game.sound_library=lib
 game.start_wave();game.set_physics_process(false);game.player.set_physics_process(false);game.camera_rig.set_process(false)
 game.model.waves.pending=0;game.player.select_character(10);game.player.position=Vector3(0,.1,70)
 var c=game.player.active_ability;c.reset_run();c.player.pos=game.player.position
 for i in 3:
  c.player.attack=null;c.player.cooldowns.cutlass=0;c.sound.last_events.clear();c.attack();c.tick(.05,false)
  var file=latest(c.sound)
  check(file==["bow-ranger-rapid-0.wav","bow-ranger-rapid-1.wav","bow-ranger-power.wav"][i],"Ranger shot %d selects the intended extracted bow effect (%s)"%[i+1,file])
 game.model.update_vision(game.player.position)
 var tower=game.tower_arrows;var pool=tower.audio
 var launch:AudioStreamRandomizer=pool.cache["tower-launch"]
 check(launch.streams_count==3,"Tower prepares all three original Warcraft Guard Tower firing variations")
 var source=JSON.parse_string(FileAccess.get_file_as_string("res://assets/audio/warcraft_tower/source.json"))
 for item in source.samples:
  var stream=load("res://assets/audio/warcraft_tower/"+item.file) as AudioStreamWAV
  check(stream.mix_rate==item.sample_rate and pcm_hash(stream.data)==item.pcm_sha256,"Imported %s preserves original Warcraft PCM and sample rate"%item.file)
 for i in 3:
  check(launch.get_stream(i).resource_path.ends_with("GuardTowerMissileLaunch%d.wav"%(i+1)),"Tower variation %d uses the recovered launch cue"%(i+1))
 var shot={"id":900,"from":game.player.position+Vector3.UP*8,"to":game.player.position+Vector3.FORWARD*10}
 var hit={"to":game.player.position,"direction":Vector3.FORWARD}
 pool.last_events.clear();tower.launch(shot)
 var voice=pool.voices[posmod(pool.cursor-1,pool.voices.size())]
 check(voice.playing and voice.stream==launch and voice.bus==&"SFX","Actual tower launch plays prepared Warcraft variations through the SFX pool independently of Ranger overrides")
 check(not pool.last_events.has("tower-impact"),"Launch never plays impact audio early")
 tower.impact(hit)
 check(latest(pool)=="ArrowImpact.wav","Arrival uses ArrowHit from the original Guard Tower missile's MARR event")
 var before:int=pool.cursor
 tower.impact(hit)
 check(pool.cursor==before,"Simultaneous impacts preserve the previous 35 ms overlap limit")
 game.sound_library.recording=true;shot.id+=1;tower.launch(shot);tower.impact(hit)
 check(pool.cursor==before,"Recording suppresses tower launch and impact audio")
 game.sound_library.recording=false;pool.last_events.clear()
 tower.launch({"id":999,"from":Vector3(10000,8,10000),"to":Vector3(10000,0,10010)})
 tower.impact({"to":Vector3(10000,0,10000),"direction":Vector3.FORWARD})
 check(pool.cursor==before,"Hidden launches and impacts stay silent")
 pool.set_volume(0);shot.id+=1;tower.launch(shot);tower.impact(hit)
 check(pool.cursor==before,"Muted tower audio consumes no voices")
 pool.set_volume(.55);pool.last_events.clear();shot.id+=1;tower.launch(shot)
 before=pool.cursor;shot.id+=1;tower.launch(shot)
 check(pool.cursor==before,"Simultaneous releases retain the shared overlap limit")
 game.show_pause();await frames()
 check(pool.voices.all(func(v):return not v.can_process()),"Tower audio pauses with gameplay")
 game.resume();tower.clear();await frames(12)
 var voice_ids=pool.voices.map(func(v):return v.get_instance_id())
 var resources=Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)
 var bank_size=load("res://scripts/character_audio_bank.gd").streams.size()
 for cycle in 5:
  for i in 12:
   pool.last_events.clear();shot.id=1000+cycle*12+i;tower.launch(shot);tower.impact(hit)
  await frames();tower.clear();await frames(12)
 check(pool.voices.map(func(v):return v.get_instance_id())==voice_ids and pool.cache.size()==4,"Sixty repeated tower shots reuse the same bounded voices and prepared events")
 check(load("res://scripts/character_audio_bank.gd").streams.size()==bank_size,"Repeated tower attacks load no new audio resources")
 check(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)==resources,"Repeated tower volleys retain no resources after cleanup")
 check(tower.visuals.is_empty() and tower.get_child_count()==2 and pool.voices.all(func(v):return not v.playing),"Tower reset clears arrows and stops every voice")
 check(game.sound_preview(10,"native_bow").resource_path.ends_with("bow-ranger-rapid-0.wav"),"Ranger shared Sound Studio preview uses the new bow source")
 check(game.sound_preview(10,"move_primary_3_weapon").resource_path.ends_with("bow-ranger-power.wav"),"Power-shot Sound Studio preview matches gameplay")
 # Real custom recordings must still replace the newly supplied fallback.
 var take=AudioStreamWAV.new();take.format=AudioStreamWAV.FORMAT_16_BITS;take.mix_rate=48000;take.data=PackedByteArray([0,0,0,0,0,0])
 lib.select_character(10);lib.take=take;lib.take_slot="native_bow";check(lib.save_take(),"Ranger custom sound can still be saved")
 c.sound.last_events.clear();c.sound.play("bow",{"ranger":true})
 check(c.sound.voices[posmod(c.sound.cursor-1,c.sound.voices.size())].stream==lib.custom_for(10,"native_bow"),"Custom bow recording overrides the new default")
 lib.reset_slot("native_bow");lib.cancel();game.music.stop();c.cancel();game.queue_free();lib.game=null;lib.queue_free();paused=false;await frames()
 DirAccess.remove_absolute(ProjectSettings.globalize_path(cfg));DirAccess.remove_absolute(ProjectSettings.globalize_path(studio))
 print("BOW_SOURCE_AUDIO_RESULT checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)
