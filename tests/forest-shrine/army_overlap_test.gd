extends SceneTree
class Battle extends "res://scripts/forest/forest_game.gd":
 var ryo_pending=[]
 var ryo_navigation=[]
 func _tick_ryo(delta:float):
  if is_instance_valid(army_runtime) and army_runtime.has_method("begin_integration"):
   ryo_pending.append(army_runtime.worker_pending);ryo_navigation.append(army_runtime.navigation_revision)
  super._tick_ryo(delta)
var checks=0
var failures=0
func check(ok:bool,label_:String):
 checks+=1
 if not ok:failures+=1;printerr("FAIL: ",label_)
func _initialize():run.call_deferred()
func run():
 set_meta("forest_army_backend","native");set_meta("forest_fighter",11)
 var doc=preload("res://scripts/forest/forest_map_document.gd").new();doc.load_original();set_meta("forest_custom_layout",doc.data)
 var game=Battle.new();game.settings_path="user://army-overlap-%d.cfg"%OS.get_process_id();root.add_child(game)
 for i in 3:await process_frame
 game.set_process(false);game.set_physics_process(false);game.player.set_physics_process(false)
 for unit in game.gate_defenders.units.values():unit.set_physics_process(false)
 var army=game.army_runtime;army.collect_stats=true
 if not army.has_method("begin_integration"):
  check(false,"The scene owner offers a bounded begin/finish integration pair");await finish(game);return
 game.start_wave();game.paused=false;paused=false
 game.model.waves.pending=100000;game.model.waves.spawn_clock=100000
 for i in 16:game.model.waves.spawn_enemy([0,1,3][i%3],Vector3(i*4,0,70))
 for i in 16:
  var h:int=army.spawn(-1000-i,1,[11,5,8,10,7][i%5],Vector3(i*4,0,40),200,.4)
  army.native.set_guard(h,Vector3(i*4,0,40),18);army.ally_target(-1000-i)
 game.ryo_pending.clear();game.ryo_navigation.clear()
 var initial=army.simulation_steps
 game._physics_process(1.0/60)
 check(game.ryo_pending==[false] and army.simulation_steps==initial+1,"Cold navigation retains the original Ryo-before-world-refresh order")
 check(not army.integration_pending and not army.worker_pending,"The first physics callback leaves no outstanding integration")
 game._physics_process(1.0/60)
 check(army.get("helper_overlap_calls")==1,"Paid helper mirrors use the captured pre-step state while simulation is pending")
 check(game.ryo_pending[-1] and army.simulation_steps==initial+2,"A stable castle overlaps one simulation step with HUD/helper processing even without loot")
 check(not army.integration_pending and not army.worker_pending,"Events and fitted facade updates finish before returning to player physics")
 var old_revision=army.navigation_revision;game.model.navigation_revision+=1
 game._physics_process(1.0/60)
 check(not game.ryo_pending[-1] and game.ryo_navigation[-1]==old_revision and army.navigation_revision==game.model.navigation_revision,"Topology changes preserve existing pre-refresh timing, then refresh before attacks")
 game.paused=true;var before=army.simulation_steps;game._physics_process(1.0/60)
 check(army.simulation_steps==before and not army.integration_pending,"Pause never submits background simulation")
 game.paused=false
 check(army.begin_integration(1.0/60),"A stable owner can explicitly submit one pending step")
 var handle:int=army.handles[game.model.enemies.keys()[0]]
 var serial_before=army.simulation_steps;army.apply_hit(handle,{"amount":.125,"element":"ice","status_seconds":.1})
 check(not army.integration_pending and army.simulation_steps==serial_before+1,"An external synchronous hit completes earlier scene callbacks before applying its own damage")
 check(army.event_gaps==0,"No ordered damage event is dropped while joining")
 check(army.begin_integration(1.0/60),"A later frame can reuse the same bounded worker")
 army.clear();check(not army.integration_pending and army.render_snapshot().handles.is_empty(),"Scene reset joins before releasing facades and native slots")
 await finish(game)
func finish(game):
 game.sound_library.cancel();game.music.stop();game.queue_free();paused=false
 for i in 3:await process_frame
 print("ARMY_OVERLAP_RESULT checks=",checks," failures=",failures);quit(1 if failures else 0)
