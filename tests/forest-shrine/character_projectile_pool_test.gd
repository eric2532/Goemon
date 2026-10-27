extends SceneTree
const Pool=preload("res://scripts/character_projectile_pool.gd")
class Caster extends Hero:
 func _ready():set_physics_process(false)
class Lease extends "res://scripts/character_projectile.gd":
 var damage=0.0
 var target:Node
 var hit_targets={}
 var visual:Node3D
 func _ready():
  visual=Node3D.new();add_child(visual);add_to_group("pool-regression");set_meta("source",7)
 func restart_visual():visual.position=Vector3.ONE*damage
var checks=0
var failures=0
func check(ok:bool,label_:String):
 checks+=1
 if not ok:failures+=1;printerr("FAIL: ",label_)
func _initialize():run.call_deferred()
func run():
 var game=Node3D.new();root.add_child(game);var hero=Caster.new();hero.game=game;game.add_child(hero)
 var pool=Pool.service(game);pool.warm(hero,Lease,"burst",{},5);var key=pool.key_for(hero,Lease,"burst")
 pool.idle[key][0].free();pool.idle[key][-1].free()
 var live=[];var victim=Node.new();game.add_child(victim)
 for i in 3:
  var shot=pool.launch(hero,Lease,"burst",{"damage":3.0,"target":victim,"attack_ticket":{"id":i}})
  live.append(shot)
  check(shot.pool_live and shot.hero==hero and shot.target==victim and shot.visible and shot.is_in_group("pool-regression"),"A burst reuses a valid prepared lease despite freed idle entries")
 check(pool.misses==0 and pool.created==5,"Valid leases are consumed before growing the pool")
 var extra=pool.launch(hero,Lease,"burst",{"damage":2.0})
 check(pool.misses==1 and pool.created==6 and pool.all[key].size()==4,"Exhaustion replaces only one required lease, without counting freed nodes")
 live.append(extra)
 var shot=live[0];var visual=shot.visual;shot.hit_targets[1]=true;shot.set_meta("stale",99)
 shot.retire()
 check(not shot.pool_live and shot.target==null and shot.hero==null and shot.attack_ticket.is_empty() and shot.hit_targets.is_empty() and not shot.visible,"Retirement clears combat ownership and stale hit state")
 var reused=pool.launch(hero,Lease,"burst",{"damage":1.0})
 check(reused==shot and reused.visual==visual and reused.visual.position==Vector3.ONE,"Reuse preserves prepared visuals and applies the new state")
 check(not reused.has_meta("stale") and reused.get_meta("source")==7 and reused.attack_ticket.is_empty(),"Reuse restores authored metadata without carrying a prior attack")
 for node in live:node.retire()
 var created=pool.created
 for i in 200:
  var node=pool.launch(hero,Lease,"burst",{"damage":float(i%4)});node.retire()
 check(pool.created==created and pool.misses==1,"Repeated bursts do not grow prepared resources")
 hero.free();await process_frame
 check(pool.all.is_empty() and pool.idle.is_empty(),"Owner removal discards every lease and callback")
 game.free();print("CHARACTER_PROJECTILE_POOL_RESULT checks=",checks," failures=",failures);quit(1 if failures else 0)
