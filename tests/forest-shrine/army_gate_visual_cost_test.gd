extends SceneTree
class Model extends "res://scripts/forest/forest_model.gd":
 var center_calls=0
 func center(b:Dictionary)->Vector3:
  center_calls+=1;return super.center(b)
var checks=0
var failures=0
func check(ok,label_):
 checks+=1
 if not ok:failures+=1;printerr("FAIL: ",label_)
func _initialize():run.call_deferred()
func run():
 var model=Model.new();model.reset(42,{})
 var world=load("res://scripts/forest/forest_world.gd").new();world.model=model;root.add_child(world);await process_frame
 var gates=model.buildings.values().filter(func(b):return b.kind=="gate")
 for i in 2000:model.defenders[-1000-i]={"id":-1000-i,"hp":100,"pos":Vector3(140,0,140)}
 model.center_calls=0;world.sync(1.0/60)
 check(model.center_calls<=gates.size(),"Gate visuals calculate each gate's terrain center once, independent of army size")
 var gate=gates[0];var door=world.structure_nodes[gate.id].get_node("GateDoor");var closed:float=door.position.y
 model.defenders[-1000].pos=model.center(gate);world.sync(.2)
 check(door.position.y>closed,"A nearby ally still opens the original gate")
 model.defenders[-1000].pos=Vector3(140,0,140);world.sync(.2)
 check(door.position.y<world.Profile.GATE_OPEN_Y,"The gate still closes after the ally leaves")
 world.queue_free();await process_frame
 print("ARMY_GATE_VISUAL_COST_RESULT checks=",checks," failures=",failures);quit(1 if failures else 0)
