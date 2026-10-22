extends SceneTree
const Runtime=preload("res://scripts/forest/crowd/army_runtime.gd")
var checks=0
var failures=0
func check(ok:bool,label_:String):
 checks+=1
 if not ok:failures+=1;printerr("FAIL: ",label_)
func _initialize():run.call_deferred()
func run():
 var army=Runtime.new();army.configure(null)
 if not army.native.has_method("collector_snapshot"):
  check(false,"Native collector capture removes per-unit intermediate dictionaries");finish(army);return
 var allies={-2:{"id":-2,"pos":Vector3(1,2,3),"hp":100},-5:{"id":-5,"pos":Vector3(-1,4,6),"hp":0}}
 var workers={8:{"id":8,"pos":Vector3(0,1,4),"hp":100,"state":"garrison"},9:{"id":9,"pos":Vector3(8,1,4),"hp":100,"state":"exit_tower","deck_height":7.5},10:{"id":10,"pos":Vector3.ZERO,"hp":100,"state":"idle","sheltered_building":20},11:{"id":11,"pos":Vector3.ZERO,"hp":100,"state":"wounded"},12:{"id":12,"pos":Vector3(NAN,0,0),"hp":100,"state":"idle"}}
 var player={"pos":Vector3(-3,2,4),"hp":200,"active":true}
 var data=army.native.collector_snapshot(player,allies,workers,20.0,1.0,10.0)
 check(data.ids==["player","ally_-2","worker_8","worker_9"],"Original player/defender/worker order and collector IDs retained")
 check(data.positions==PackedVector3Array([Vector3(-3,3,4),Vector3(1,3,3),Vector3(0,22,4),Vector3(8,9.5,4)]),"Collector pickup height, tower deck and partial descent match source")
 check(data.cells.keys()==[Vector2i(-1,0),Vector2i(0,0)],"Shared wake cells retain first insertion order")
 player.active=false;check(not army.native.collector_snapshot(player,allies,workers,20.0,1.0,10.0).ids.has("player"),"Respawning player does not attract coins")
 # Run identical normal-stat loot through the original normalization path and
 # the packed game capture, including loss/reappearance and covered collectors.
 var a=preload("res://scripts/forest/forest_model.gd").new();a.reset(42,{}, {"buildings":[],"trees":[],"deposits":[]},false);a.phase="wave";a.army_runtime=army
 var b=preload("res://scripts/forest/forest_model.gd").new();b.reset(42,{}, {"buildings":[],"trees":[],"deposits":[]},false);b.phase="wave";b.army_runtime=army
 for i in 20:
  var enemy={"id":100+i,"variant":i%2,"hp":0,"pos":Vector3(i*.5-5,0,60)};a.ryo.spawn_enemy_drop(enemy);b.ryo.spawn_enemy_drop(enemy)
 allies.clear();workers.clear();player.active=true;player.pos=Vector3(-3,0,60)
 for i in 200:allies[-1000-i]={"id":-1000-i,"pos":Vector3((i%20)*.5-5,0,58+i/20.0),"hp":100}
 var clear=func(_from,to):return to.x<0
 for frame in 180:
  player.active=frame<40 or frame>80
  var rows=[{"id":"player","pos":player.pos,"hp":player.hp,"active":player.active}]
  for row in allies.values():rows.append({"id":"ally_%s"%row.id,"pos":row.pos,"hp":row.hp})
  a.ryo.tick(1.0/60,rows,false,clear)
  b.ryo.tick(1.0/60,[],false,clear,army.native.collector_snapshot(player,allies,workers,20.0,1.0,10.0))
  check(a.gold==b.gold and a.ryo.drops==b.ryo.drops and a.ryo.collected_events==b.ryo.collected_events,"Packed capture retains exact loot trajectories, covered recipient and collection events")
 finish(army)
func finish(army):
 army.free();print("ARMY_LOOT_COLLECTORS_RESULT checks=",checks," failures=",failures);quit(1 if failures else 0)
