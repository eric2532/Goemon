extends SceneTree
const Coordinator=preload("res://scripts/forest/crowd/army_coordinator.gd")
const Model=preload("res://scripts/forest/forest_model.gd")
const Profile=preload("res://scripts/forest/forest_structure_profile.gd")
class Player extends Node3D:
 const RogueRoster=preload("res://scripts/rogue_roster.gd")
 var character_id=1
 var hp=200
 func rogue_untargetable():return false
class Arena extends Node:
 var model=Model.new()
 var player=Player.new()
 var respawn_left=0
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
  var expected:Vector3=preload("res://tests/forest-shrine/reference/forest_enemy_projectiles.gd").new(arena.model,null).worker_point(worker)-Vector3.UP*Profile.WORKER_CONTACT_HEIGHT
  check(index>=0 and data.positions[index].is_equal_approx(expected),"Native target foot retains actual visible worker deck height")
 arena.model.workers.clear()
 arena.model.buildings.clear()
 arena.player.position=Vector3(200,0,200)
 var shrine=arena.model._make_building("shrine",Vector2i(0,4),0)
 var tower=arena.model._make_building("tower",Vector2i(4,6),0)
 var barracks=arena.model._make_building("barracks",Vector2i(10,0),0)
 var gate=arena.model._make_building("gate",Vector2i(0,2),0)
 data=army.external_targets()
 for b in [tower,barracks]:
  check(data.assault_priority[data.ids.find(b.id)]==4,"Barracks and towers publish the local military aggro priority")
 check(data.assault_priority[data.ids.find(shrine.id)]==2 and data.assault_priority[data.ids.find(gate.id)]==1,"Castle and breach priorities remain the main assault objectives")
 var runtime=preload("res://scripts/forest/crowd/army_runtime.gd").new();runtime.configure(null)
 runtime.configure_kits(preload("res://scripts/forest/crowd/army_kit_data.gd").from_model(arena.model))
 for kind in [0,1,3,6,9,14,16,17,18]:
  for phase in ["castle","tower","barracks","destroyed"]:
   runtime.clear();runtime.navigation_revision=-1;runtime.set_navigation(1,{"width":0})
   tower.hp=0 if phase=="destroyed" else tower.max_hp
   barracks.hp=0 if phase=="destroyed" else barracks.max_hp
   var point:Vector3=Vector3(18,0,36) if phase=="tower" else Vector3(54,0,0) if phase in ["barracks","destroyed"] else Vector3.ZERO
   var enemy:int=runtime.spawn(100,0,kind,point,10000,1.3)
   runtime.step(.01,{"targets":army.external_targets()})
   var expected:int=tower.id if phase=="tower" else barracks.id if phase=="barracks" else shrine.id
   check(runtime.unit_state(enemy).external_target==expected and runtime.unit_state(enemy).external_kind==2,"Enemy %d selects %s using castle-first targeting and local defense aggro"%[kind,phase])
 runtime.clear();runtime.free()
 army.free();arena.free()
 print("ARMY_WORKER_TARGETS_RESULT checks=",checks," failures=",failures);quit(1 if failures else 0)
