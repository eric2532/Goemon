extends SceneTree
class Arena extends Node3D:
 var enemies=[]
class Target extends Ninja:
 var entry=0.0
 var calls=0
 var aim=Vector3.ZERO
 func _ready():set_physics_process(false)
 func combat_segment_contact(from:Vector3,to:Vector3,_radius:float)->Dictionary:
  calls+=1;return {"t":entry,"point":from.lerp(to,entry)}
 func combat_aim_point(_from:Vector3)->Vector3:return aim
var failures=0
var checks=0
func check(ok:bool,label_:String):
 checks+=1
 if not ok:failures+=1;printerr("FAIL: ",label_)
func _initialize():run.call_deferred()
func run():
 var arena=Arena.new();root.add_child(arena)
 var a=Target.new();var b=Target.new();arena.add_child(a);arena.add_child(b);arena.enemies=[a,b]
 var from=Vector3(0,2,0);var to=from+Vector3.FORWARD*10
 a.aim=from;b.aim=from
 var hit=AttackChain.nearest_contact(arena,arena,from,to,6)
 check(hit.enemy==a and hit.t==0,"Overlapping targets retain the first source-order hit")
 check(a.calls==1 and b.calls==0,"A valid start contact avoids fitting every remaining target")
 hit=AttackChain.nearest_contact(arena,arena,from,to,6,{a.get_instance_id():true})
 check(hit.enemy==b,"A previous hit is still excluded before the early exit")
 a.entry=.8;b.entry=.2
 hit=AttackChain.nearest_contact(arena,arena,from,to,6)
 check(hit.enemy==b and is_equal_approx(hit.t,.2),"Nonzero entry still searches for the nearest contact")
 a.entry=.2
 check(AttackChain.nearest_contact(arena,arena,from,to,6).enemy==a,"Equal nonzero entries keep source ordering")
 arena.enemies.reverse()
 check(AttackChain.nearest_contact(arena,arena,from,to,6).enemy==b,"Reordered candidates update the tie winner immediately")
 arena.enemies.reverse();a.entry=0;b.entry=0
 var wall=StaticBody3D.new();var shape=CollisionShape3D.new();var box=BoxShape3D.new();box.size=Vector3(1,4,4);shape.shape=box;wall.add_child(shape);arena.add_child(wall);wall.position=Vector3(5,2,0)
 a.aim=from+Vector3.RIGHT*10
 await physics_frame;await physics_frame
 check(AttackChain.nearest_contact(arena,arena,from,to,6).enemy==b,"A covered start contact cannot suppress a later visible target")
 check(AttackChain.nearest_contact(arena,arena,from,from,6).enemy==b,"Stationary overlap queries retain cover checks")
 arena.free();print("NEAREST_CONTACT_RESULT checks=",checks," failures=",failures);quit(1 if failures else 0)
