extends SceneTree
class Model extends "res://scripts/forest/forest_model.gd":
 var center_calls=0
 func center(b:Dictionary)->Vector3:
  center_calls+=1;return super.center(b)
class Defender extends RefCounted:
 static var hp_reads=0
 static var position_reads=0
 var health=100.0
 var point=Vector3(140,0,140)
 var hp:float:
  get:hp_reads+=1;return health
 var pos:Vector3:
  get:position_reads+=1;return point
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
 # Isolate one gate to count exactly which residents it inspects.
 model.workforce.recruit(true)
 var worker:Dictionary=model.workers.values()[0].duplicate(true)
 model.buildings={gate.id:gate};model.revision+=1;model.workers.clear();model.defenders.clear();model.hero_position=Vector3(100,0,100)
 for i in 2000:model.defenders[-1000-i]=Defender.new()
 var first:Defender=model.defenders[-1000];first.point=model.center(gate)
 Defender.hp_reads=0;Defender.position_reads=0;world.sync(.2)
 check(Defender.hp_reads==1 and Defender.position_reads==1,"Finding the first nearby ally skips the remaining1999 residents")
 model.hero_position=first.point;Defender.hp_reads=0;world.sync(.2)
 check(Defender.hp_reads==0,"A nearby player opens the gate without any ally polling")
 model.hero_position=Vector3(100,0,100);worker.pos=first.point;worker.state="idle";model.workers[worker.id]=worker;model.revision+=1
 Defender.hp_reads=0;world.sync(.2)
 check(Defender.hp_reads==0,"A nearby worker opens the gate without any ally polling")
 worker.state="repair";first.health=0;Defender.hp_reads=0;Defender.position_reads=0;world.sync(.2)
 check(Defender.hp_reads==2000 and Defender.position_reads==1999,"A dead nearby ally never opens the gate; later residents remain eligible")
 first.health=100;first.point=model.center(gate)+Vector3.RIGHT*10;world.sync(1)
 check(is_equal_approx(door.position.y,world.Profile.GATE_CLOSED_Y-float(door.get_meta("foundation_depth",0))*.5),"The original strict10m gate boundary remains closed")
 first.point=model.center(gate)+Vector3.RIGHT*9.999;world.sync(1)
 check(is_equal_approx(door.position.y,world.Profile.GATE_OPEN_Y+float(door.get_meta("foundation_depth",0))*.5),"The gate still opens immediately inside its original boundary")
 world.queue_free();await process_frame
 print("ARMY_GATE_VISUAL_COST_RESULT checks=",checks," failures=",failures);quit(1 if failures else 0)
