extends SceneTree
class State extends RefCounted:
 var next_id=1
 var fighter_count=0
 var fighter_posts={}
class Arena extends Node3D:
 var model=State.new()
 var forest_ui:Node
 var enemies=[]
 func forest_enemy_visible(_enemy)->bool:return true
class Target extends Ninja:
 func _ready():set_physics_process(false)
class Owner extends Hero:
 var director:Node
 func _ready():ai_controlled=true;set_physics_process(false)
class Combat extends "res://scripts/forest/summoned_ally_combat.gd":
 func clear_line(_from:Vector3,_to:Vector3)->bool:return true
var checks=0
var failures=0
func check(ok:bool,label_:String):
 checks+=1
 if not ok:failures+=1;printerr("FAIL: ",label_)
func _initialize():run.call_deferred()
func run():
 var arena=Arena.new();root.add_child(arena)
 var director=preload("res://scripts/forest/explorer_helpers.gd").new();director.game=arena
 var owner=Owner.new();owner.director=director;arena.add_child(owner)
 var combat=Combat.new();combat.game=arena;combat.hero=owner
 for i in 2:
  var target=Target.new();arena.add_child(target);target.position=Vector3(0,0,1+i*2);arena.enemies.append(target)
 combat._begin_projectile_queries()
 var minimum=Vector3(-3,-3,-3);var maximum=Vector3(3,5,8)
 check(combat._projectile_candidate_indices(minimum,maximum)==[0,1],"Initial spatial indices refer to this projectile owner's captured geometry")
 var extra=Target.new();arena.add_child(extra);extra.position=Vector3(0,0,5);arena.enemies.append(extra);arena.model.next_id+=1;director.refresh_targets()
 var candidates=combat._projectile_candidate_indices(minimum,maximum)
 check(candidates==[0,1],"An ally retains its own target indices when a nested combat query refreshes the shared army snapshot")
 if candidates==[0,1]:
  var hits=combat._segment_candidates(Vector3(0,1,0),Vector3(0,1,6),.25,[])
  check(hits.size()==2,"The in-flight query safely resolves its original victims without silently dropping targets")
 combat._end_projectile_queries();combat._begin_projectile_queries()
 check(combat._projectile_targets.size()==3,"The next projectile update immediately captures new enemy geometry")
 arena.enemies[0].dead=true
 var hits=combat._segment_candidates(Vector3(0,1,0),Vector3(0,1,6),.25,[])
 check(not hits.any(func(h):return h.e.node==arena.enemies[0]),"Snapshot reuse still filters a victim killed during the same update")
 director.clear()
 check(combat._projectile_candidate_indices(minimum,maximum)==[0,1,2],"Clearing the shared grid cannot discard an owner's captured projectile candidates")
 hits=combat._segment_candidates(Vector3(0,1,0),Vector3(0,1,6),.25,[])
 check(hits.size()==2,"A cleared shared grid still resolves surviving captured victims safely")
 combat._end_projectile_queries();combat._begin_projectile_queries()
 var other=Combat.new();other.game=arena;other.hero=owner;other._begin_projectile_queries()
 other._clear_projectiles()
 check(combat._projectile_centers.size()==2 and director.projectile_centers.size()==2,"Retiring one ally's projectiles preserves shared geometry for other owners and the director")
 other.free();combat._end_projectile_queries();combat.free();director.free();arena.queue_free();await process_frame
 print("ARMY_SNAPSHOT_CONSISTENCY_RESULT checks=",checks," failures=",failures);quit(1 if failures else 0)
