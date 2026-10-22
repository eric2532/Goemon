extends SceneTree
class FX extends Node3D:
 func streak(_a,_b,_c,_d,_e):pass
class Enemy extends Ninja:
 var contacts=0
 func _ready():set_process(false);set_physics_process(false);body_radius=0
 func combat_contact_point(_point:Vector3)->Vector3:
  contacts+=1;return global_position
class Director extends RefCounted:
 var rows=[]
 var requested_center=Vector3.INF
 var requested_radius=INF
 func melee_candidates(center:Vector3,radius:float)->Array:
  requested_center=center;requested_radius=radius
  return rows.filter(func(row):return not center.is_finite() or Vector2(row.enemy.position.x-center.x,row.enemy.position.z-center.z).length()<=radius)
class Fighter extends Hero:
 var director=Director.new()
 func _ready():set_process(false);set_physics_process(false)
class Arena extends Node:
 func forest_enemy_visible(_enemy):return true
class Combat extends "res://scripts/forest/summoned_ally_combat.gd":
 var hits=[]
 func use_ticket(_ticket:Dictionary):pass
 func clear_line(_from:Vector3,_to:Vector3)->bool:return true
 func hit(e:Dictionary={},_amount:float=0,_weapon:String="cutlass",_heavy:bool=false,_direction:Vector3=Vector3.ZERO,_element:String="",_presentation:String="")->void:hits.append(e.uid)
var checks=0
var failures=0
func check(ok,label_):
 checks+=1
 if not ok:failures+=1;printerr("FAIL: ",label_)
func _initialize():run.call_deferred()
func run():
 var reference=JSON.parse_string(FileAccess.get_file_as_string("res://tests/forest-shrine/fixtures/large_army_reference.json"))
 check(FileAccess.get_sha256("res://assets/rogue/scripts/class_actions.gd")==reference.protected_hashes["assets/rogue/scripts/class_actions.gd"],"Playable action implementation remains byte-for-byte at its protected baseline")
 var g=Combat.new()
 if not g.get_property_list().any(func(p):return p.name=="_npc_physics_from"):
  check(false,"The NPC adapter must own swept-query context without changing playable actions");g.free();finish();return
 var arena=Arena.new();root.add_child(arena);var fighter=Fighter.new();arena.add_child(fighter);g.hero=fighter;g.game=arena;g.class_id="explorer";g.fx=FX.new()
 var enemies=[]
 for point in [Vector3.ZERO,Vector3(0,0,10),Vector3(1.4,0,5),Vector3(1.6,0,5),Vector3(100,0,100)]:
  var e=Enemy.new();arena.add_child(e);e.position=point;enemies.append(e);fighter.director.rows.append({"enemy":e,"bounds":AABB(point-Vector3.ONE*.1,Vector3.ONE*.2)})
 g.player={"pos":Vector3(0,0,10),"dashAttack":{"ticket":{"serial":1},"hits":[],"width":1.45,"damage":78,"angle":0.0,"style":"cross-slash","fxTime":-1000.0},"roll":1.0};g._npc_physics_from=Vector3.ZERO
 var actions=load("res://assets/rogue/scripts/class_actions.gd");actions.resolve_dash_segment(g,Vector3.ZERO,Vector3(0,0,10))
 check(fighter.director.requested_center.is_finite() and fighter.director.requested_radius<INF and enemies.back().contacts==0,"Only the NPC adapter bounds a dash before fitting distant contacts")
 var expected=enemies.slice(0,3).map(func(e):return e.get_instance_id())
 check(g.hits==expected,"The unchanged dash retains both endpoints, near-edge hits and hit order")
 actions.resolve_dash_segment(g,Vector3.ZERO,Vector3(0,0,10));check(g.hits==expected,"The same source cast cannot hit victims twice")
 g._npc_physics_from=Vector3.INF;g.living()
 check(enemies.back().contacts>0,"Other unbounded NPC requests retain their complete original snapshot")
 g.fx.free();g.free();arena.free();finish()
func finish():
 print("ARMY_DASH_QUERY_RESULT checks=",checks," failures=",failures);quit(1 if failures else 0)
