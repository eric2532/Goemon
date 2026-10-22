extends SceneTree
class Counter extends "res://scripts/forest/crowd/army_renderer.gd":
 var uploads=0
 func present(snapshot:Dictionary,events:Array):
  uploads+=1;super.present(snapshot,events)
var checks=0
var failures=0
func check(ok:bool,label_:String):
 checks+=1
 if not ok:failures+=1;printerr("FAIL: ",label_)
func _initialize():run.call_deferred()
func run():
 set_meta("forest_army_backend","native")
 var doc=load("res://scripts/forest/forest_map_document.gd").new();doc.load_original();set_meta("forest_custom_layout",doc.data)
 var game=load("res://scenes/forest_shrine.tscn").instantiate();game.settings_path="user://army-presentation-cadence-%d.cfg"%OS.get_process_id();root.add_child(game)
 for i in 3:await process_frame
 game.set_process(false);game.set_physics_process(false);game.player.set_physics_process(false);game.explorer_helpers.set_process(false)
 var army=game.army_runtime;army.set_process(false)
 var renderer=Counter.new();game.crowd.add_child(renderer);renderer.configure(game);game.crowd.army.free();game.crowd.army=renderer
 game.model.phase="wave";game.paused=false;paused=false;game.model.waves.pending=1000000;game.model.waves.spawn_clock=1000000
 var row=game.model.waves.spawn_enemy(0,Vector3(80,0,80))
 var before:float=army.simulation_seconds
 army.integration_tick(1.0/60);army.integration_tick(1.0/60);army.integration_tick(1.0/60)
 check(renderer.uploads==0,"Catch-up physics does not upload overwritten GPU frames")
 check(absf(army.simulation_seconds-before-.05)<.00001,"All three combat ticks still execute at the original cadence")
 if not army.has_method("flush_presentation"):
  check(false,"Presentation needs an explicit once-per-render flush")
 else:
  army.flush_presentation()
  check(renderer.uploads==1 and renderer.submitted==1,"One render presents the complete latest authoritative snapshot")
  army.flush_presentation()
  check(renderer.uploads==1,"Repeated rendering without new simulation reuses its buffers")
  game.paused=true;army.integration_tick(.5);army._process(.5)
  check(absf(army.simulation_seconds-before-.05)<.00001 and renderer.uploads==1,"Paused presentation cannot advance native combat or create uploads")
 game.sound_library.cancel();game.music.stop();game.queue_free();paused=false
 for i in 3:await process_frame
 print("ARMY_PRESENTATION_CADENCE_RESULT checks=",checks," failures=",failures);quit(1 if failures else 0)
