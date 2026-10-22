extends SceneTree
var checks=0
var failures=0
func check(ok:bool,label_:String):
 checks+=1
 if not ok:failures+=1;printerr("FAIL: ",label_)
func _initialize():run.call_deferred()
func run():
 if not ResourceLoader.exists("res://scripts/forest/forest_soldier_audio.gd"):
  check(false,"The confirmed soldier scream needs a bounded positional death voice pool");finish();return
 var audio=load("res://scripts/forest/forest_soldier_audio.gd")
 var f=load("res://tests/forest-shrine/large_army_fixture.gd").new();root.add_child(f);var game=await f.make_game("original");f.clear_targets()
 var target=f.add_target(Vector3(0,0,52));var pool=audio.ensure(game)
 check(pool.get_child_count()==6,"The whole game owns exactly six soldier death voices")
 target.take_hit(100000,Vector3.FORWARD,false,{"tower":true})
 check(pool.plays_started==1,"A real legacy soldier death plays the user-confirmed scream")
 game.model.phase="preparing";pool._process(.02)
 check(pool.voices.any(func(v):return v.playing),"The final soldier's scream can finish when the wave ends")
 game.model.phase="wave"
 pool._process(.1);target.take_hit(100000,Vector3.FORWARD,false,{"tower":true})
 check(pool.plays_started==1,"Repeated damage to a dead soldier cannot replay its death voice")
 var runtime=load("res://scripts/forest/crowd/army_runtime.gd").new();game.add_child(runtime);runtime.configure(game);runtime.configure_kits(load("res://scripts/forest/crowd/army_kit_data.gd").from_model(game.model))
 var soldier:int=runtime.spawn(90001,0,1,Vector3(0,0,52),100,.4)
 runtime.apply_hit(soldier,{"amount":1000.0,"source_id":0})
 check(pool.plays_started==2,"A native soldier death plays once even when no target facade was constructed")
 pool._process(.1);runtime.apply_hit(soldier,{"amount":1000.0,"source_id":0})
 check(pool.plays_started==2,"A stale native death handle cannot replay audio")
 var before:int=pool.plays_started
 for i in 2000:pool.death(Vector3(0,0,52),0)
 check(pool.plays_started<=before+1 and pool.get_child_count()==6,"Two thousand simultaneous deaths keep a fixed voice count and a bounded start rate")
 pool._process(.1);before=pool.plays_started
 check(not pool.death(Vector3(1000,0,1000),0) and pool.plays_started==before,"Distant deaths do not consume voices")
 check(not pool.death(Vector3(0,0,52),2),"Non-soldier actors do not borrow the soldier scream")
 game.paused=true;check(not pool.death(Vector3(0,0,52),0),"Pause suppresses death voice starts");game.paused=false
 game.settings.volume=0;check(not pool.death(Vector3(0,0,52),0),"The user's mute setting suppresses death voices");game.settings.volume=.65
 pool.reset();check(pool.voices.all(func(v):return not v.playing),"Reset releases all voices without growing a queue")
 check(is_equal_approx(pool.voices[0].stream.get_length(),.3697) or absf(pool.voices[0].stream.get_length()-.37)<.002,"Playback uses the confirmed pitch-bend scream, not the rejected raw0.49-second sample")
 runtime.clear();runtime.queue_free();await f.close();f.queue_free();await process_frame;finish()
func finish():print("SOLDIER_DEATH_AUDIO_RESULT checks=",checks," failures=",failures);quit(1 if failures else 0)
