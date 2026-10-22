extends SceneTree
const Runtime=preload("res://scripts/forest/crowd/army_runtime.gd")
var checks=0
var failures=0
func check(ok:bool,label_:String):
 checks+=1
 if not ok:failures+=1;printerr("FAIL: ",label_)
func _initialize():run.call_deferred()
func run():
 var model=preload("res://scripts/forest/forest_model.gd").new();model.reset(42,{}, {"buildings":[],"trees":[],"deposits":[]},false);model.phase="wave"
 var army=Runtime.new();army.configure(null);model.army_runtime=army
 for i in 2000:
  var row=model.waves.spawn_enemy(0,Vector3(100+i%20,0,60+i/20.0));army.spawn(row.id,0,0,row.pos,row.hp,3.9)
 for i in 12:
  var tower=model._make_building("tower",Vector2i(i,8),0)
  model.workers[3000+i]={"id":3000+i,"pos":Vector3(0,0,60+i*.1),"hp":100,"state":"garrison","job":tower.id,"timer":0.0}
 model.workforce.assignment_clock=1000;model.workforce.tick(.01,Vector3.ZERO)
 check(model.workforce.arrows.is_empty(),"Twelve empty-range towers do not fire at distant soldiers")
 var work=model.workforce.get("tower_candidate_work");print("TOWER_CANDIDATE_ROW_VISITS ",work)
 check(work!=null and int(work)<=2000,"One workforce tick captures enemy order once rather than rescanning2000 rows for each tower")
 army.clear();army.free();print("ARMY_TOWER_SNAPSHOT_COST_RESULT checks=",checks," failures=",failures);quit(1 if failures else 0)
