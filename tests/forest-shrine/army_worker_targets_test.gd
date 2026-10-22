extends SceneTree
const Coordinator=preload("res://scripts/forest/crowd/army_coordinator.gd")
const Model=preload("res://scripts/forest/forest_model.gd")
const Profile=preload("res://scripts/forest/forest_structure_profile.gd")
class Player extends Node3D:
 var hp=200
 func rogue_untargetable():return false
class Defenders extends RefCounted:
 var units={}
class Arena extends Node:
 var model=Model.new()
 var player=Player.new()
 var respawn_left=0
 var gate_defenders=Defenders.new()
var checks=0
var failures=0
func check(ok:bool,label_:String):
 checks+=1
 if not ok:failures+=1;printerr("FAIL: ",label_)
func _initialize():run.call_deferred()
func run():
 var arena=Arena.new();root.add_child(arena);arena.add_child(arena.player)
 arena.model.reset(42,{}, {"buildings":[],"trees":[],"deposits":[]},false)
 arena.model.workers={
  1:{"id":1,"state":"idle","hp":100,"pos":Vector3(3,4,5)},
  2:{"id":2,"state":"wounded","hp":10,"pos":Vector3(3,4,5)},
  3:{"id":3,"state":"idle","hp":100,"pos":Vector3(3,4,5),"sheltered_building":20},
  4:{"id":4,"state":"garrison","hp":100,"pos":Vector3(3,4,5)},
  5:{"id":5,"state":"exit_tower","hp":100,"pos":Vector3(3,4,5),"deck_height":7.5},
  6:{"id":6,"state":"idle","hp":0,"pos":Vector3(3,4,5)}}
 var army=Coordinator.new();army.game=arena;var data=army.external_targets()
 check(data.ids.has(1),"Exposed living workers remain valid targets")
 check(not data.ids.has(2) and not data.ids.has(3) and not data.ids.has(6),"Wounded, sheltered and dead workers are excluded using source targetability")
 for id in [1,4,5]:
  var index:int=data.ids.find(id);var worker:Dictionary=arena.model.workers[id]
  var expected:Vector3=preload("res://scripts/forest/forest_enemy_projectiles.gd").new(arena.model,null).worker_point(worker)-Vector3.UP*Profile.WORKER_CONTACT_HEIGHT
  check(index>=0 and data.positions[index].is_equal_approx(expected),"Native target foot retains actual visible worker deck height")
 army.free();arena.free()
 print("ARMY_WORKER_TARGETS_RESULT checks=",checks," failures=",failures);quit(1 if failures else 0)
