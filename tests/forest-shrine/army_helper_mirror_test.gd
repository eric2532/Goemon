extends SceneTree
class Model extends RefCounted:
 var fighter_count=0
 var fighter_posts={}
 var defenders={}
class Arena extends Node3D:
 var model=Model.new()
 var army_runtime=Node.new()
class Unit extends Node3D:
 var state="acting"
 var hp=100.0
 var gate_id=-1000
 var guard_post=Vector3(10,0,20)
 var taunting=false
 func rogue_untargetable():return false
var checks=0
var failures=0
func check(ok,label_):
 checks+=1
 if not ok:failures+=1;printerr("FAIL: ",label_)
func _initialize():run.call_deferred()
func run():
 var arena=Arena.new();root.add_child(arena)
 var director=load("res://scripts/forest/explorer_helpers.gd").new();director.game=arena
 var unit=Unit.new();arena.add_child(unit);director.pool=[unit];director.actors[unit.gate_id]=unit
 director.sync_targets();var row=arena.model.defenders[unit.gate_id];unit.position=Vector3(3,4,5);unit.hp=73;unit.taunting=true;director.sync_targets()
 check(is_same(row,arena.model.defenders[unit.gate_id]),"Native compatibility reuses each owned ally row across physics ticks")
 check(row.pos==unit.position and row.hp==73 and row.taunting,"Reused rows expose exact current pose, HP and taunt")
 unit.state="sheltered";director.sync_targets()
 check(arena.model.defenders.is_empty() and arena.model.fighter_count==1 and arena.model.fighter_posts.size()==1,"Sheltered allies retain food/post ownership and leave exposed targeting")
 unit.state="idle";director.sync_targets()
 check(arena.model.fighter_count==0 and arena.model.fighter_posts.is_empty() and arena.model.defenders.is_empty(),"Retired allies leave every live mirror immediately")
 director.free();arena.army_runtime.free();arena.free()
 print("ARMY_HELPER_MIRROR_RESULT checks=",checks," failures=",failures);quit(1 if failures else 0)
