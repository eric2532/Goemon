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
func run():
 var map=load("res://scripts/forest/forest_map_document.gd").new();map.load_original();set_meta("forest_custom_layout",map.data)
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
 for i in 2:
  game.tower_arrows.audio.last_events.clear()
  game.tower_arrows.launch({"id":900+i,"from":game.player.position+Vector3.UP*8,"to":game.player.position+Vector3.FORWARD*10})
  check(latest(game.tower_arrows.audio)=="bow-tower-%d.wav"%i,"Tower arrows alternate the two selected source effects")
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
