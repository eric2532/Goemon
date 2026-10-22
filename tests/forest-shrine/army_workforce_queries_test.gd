extends SceneTree
class Runtime extends "res://scripts/forest/crowd/army_runtime.gd":
 var queries=0
 var reads=0
 func query_aabb(bounds:AABB,team:int)->PackedInt64Array:
  queries+=1;return super.query_aabb(bounds,team)
 func unit_state(handle:int)->Dictionary:
  reads+=1;return super.unit_state(handle)
var checks=0
var failures=0
func check(ok,label_):
 checks+=1
 if not ok:failures+=1;printerr("FAIL: ",label_)
func _initialize():run.call_deferred()
func run():
 var model=load("res://scripts/forest/forest_model.gd").new();model.reset(42,{}, {"buildings":[],"trees":[],"deposits":[]},false);model.phase="wave"
 var army=Runtime.new();army.configure(null);model.army_runtime=army
 for i in 2000:
  var point=Vector3(0,0,68) if i==0 else Vector3(80+(i%30),0,60+floori(i/30.0))
  var row=model.waves.spawn_enemy(0,point);army.spawn(row.id,0,0,row.pos,row.hp,3.9)
 var point=Vector3(0,0,60)
 check(model.workforce.threatened(point),"An exposed nearby soldier still threatens a worker")
 check(army.queries==1 and army.reads<=4,"Worker safety uses the shared crowd index rather than scanning2000 enemies")
 model._make_building("wall",Vector2i(0,11),0)
 check(not model.workforce.threatened(point),"Intact castle masonry still protects a worker from a nearby enemy")
 model.buildings.clear();model.occupancy.clear()
 var row:Dictionary=model.enemies.values()[0];row.pos=Vector3(0,13,60);army.set_pose(army.handles[row.id],row.pos,0)
 check(not model.workforce.threatened(point),"Threat detection retains the source's exact three-dimensional twelve-metre limit")
 row.pos=Vector3(0,0,68);row.hp=0;army.set_pose(army.handles[row.id],row.pos,0)
 check(not model.workforce.threatened(point),"A dead model row never threatens a worker while a proxy retires")
 # Towers use fitted soldier surfaces, including a rotated body whose root
 # is outside48m while its actual near face remains within shooting range.
 row.hp=192;row.pos=Vector3(51,0,60);row.facing=PI/2;army.set_pose(army.handles[row.id],row.pos,PI/2)
 model.visible_cells[model.cell_of(row.pos)]=true
 var tower=model._make_building("tower",Vector2i(0,8),0);model.workers.clear()
 model.workers[3000]={"id":3000,"pos":point,"hp":100,"state":"garrison","job":tower.id,"timer":0.0}
 army.queries=0;army.reads=0;model.workforce.assignment_clock=1000;model.workforce.tick(.01,Vector3.ZERO)
 check(model.workforce.arrows.size()==1 and model.workforce.arrows.values()[0].target==row.id,"Tower range still reaches the exact rotated soldier face beyond its root distance")
 check(army.queries>=1 and army.reads<=4,"Towers fit nearby candidates instead of all2000 enemy bodies")
 army.clear();army.free()
 print("ARMY_WORKFORCE_QUERIES_RESULT checks=",checks," failures=",failures);quit(1 if failures else 0)
