extends SceneTree
const Coordinator=preload("res://scripts/forest/crowd/army_coordinator.gd")
const Model=preload("res://scripts/forest/forest_model.gd")
class Arena extends Node3D:
 var model=Model.new()
 var army_runtime:Node
 var actors={}
 var enemies:Array[Ninja]=[]
var checks=0
var failures=0
func check(ok:bool,label_:String):
 checks+=1
 if not ok:failures+=1;printerr("FAIL: ",label_)
func _initialize():run.call_deferred()
func run():
 var game=Arena.new();root.add_child(game);game.model.reset(42,{}, {"buildings":[],"trees":[],"deposits":[]},false)
 var army=Coordinator.new();army.set_process(false);game.add_child(army);army.game=game;army.configure(null);army.game_ref=weakref(game);game.army_runtime=army;game.model.army_runtime=army
 for i in 2000:game.model.waves.spawn_enemy(0,Vector3(i%50,0,60+i/50.0))
 army.import_arrivals()
 check(army.snapshot().handles.size()==2000 and game.actors.size()==2000 and game.enemies.size()==2000,"Every source arrival imports once at full capacity")
 var visited=army.get("import_rows_visited")
 if visited!=null:army.import_rows_visited=0
 for i in 10:army.import_arrivals()
 visited=army.get("import_rows_visited");print("ARRIVAL_ROW_VISITS ",visited)
 check(visited!=null and visited==0,"Physics ticks without arrivals do not rescan2000 living model rows")
 var id:int=game.model.enemies.keys()[0];army.despawn(army.handles[id]);army.sync_compatibility()
 check(not game.model.enemies.has(id) and not game.actors.has(id),"Explicit native retirement removes the exact model/proxy without stale entries")
 var row=game.model.waves.spawn_enemy(1,Vector3(20,0,60));army.import_arrivals()
 check(army.handles.has(row.id) and game.actors.has(row.id) and army.snapshot().handles.size()==2000,"A later queued arrival fills a recycled slot once")
 var skipped=game.model.waves.spawn_enemy(0,Vector3(30,0,60));skipped.hp=0;army.import_arrivals()
 check(not army.handles.has(skipped.id),"An arrival killed before import never creates a live proxy")
 var waiting=game.model.waves.spawn_enemy(0,Vector3(40,0,60));army.import_arrivals()
 check(not army.handles.has(waiting.id) and army.snapshot().handles.size()==2000,"A live capacity-limited arrival waits without dropping or over-allocating")
 var retiring:int=army.handles.keys()[0];army.despawn(army.handles[retiring]);army.sync_compatibility();army.import_arrivals()
 check(army.handles.has(waiting.id) and game.actors.has(waiting.id) and army.snapshot().handles.size()==2000,"A queued capacity retry imports exactly once when a real slot frees")
 var removed=game.model.waves.spawn_enemy(0,Vector3(50,0,60));game.model.enemies.erase(removed.id);army.import_arrivals()
 check(not army.handles.has(removed.id),"A removed queued model row cannot reappear as a stale actor")
 army.clear();game.free();print("ARMY_ARRIVAL_QUEUE_RESULT checks=",checks," failures=",failures);quit(1 if failures else 0)
