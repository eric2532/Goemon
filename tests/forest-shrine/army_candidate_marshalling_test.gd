extends SceneTree
const Runtime=preload("res://scripts/forest/crowd/army_runtime.gd")
const Target=preload("res://scripts/forest/crowd/army_enemy_target.gd")
class State extends RefCounted:
 var enemies={}
class Arena extends Node3D:
 var enemies=[]
 var training_dummy
 var enemy_objectives=[]
 var enemy_objective_targets=[]
 var model=State.new()
class Extra extends Ninja:
 func _ready():set_physics_process(false)
var checks=0
var failures=0
func check(ok:bool,label_:String):
 checks+=1
 if not ok:failures+=1;printerr("FAIL: ",label_)
func _initialize():run.call_deferred()
func run():
 var runtime=Runtime.new();runtime.configure(null)
 var arena=Arena.new();root.add_child(arena);runtime.game_ref=weakref(arena);seed(71026)
 for i in 96:
  var handle=runtime.spawn(i+1,0,0,Vector3(i%12*4,0,i/12*4),100,.4)
  var actor=Target.new();actor.runtime=runtime;actor.handle=handle;actor.variant=0;actor.forest_id=i+1;arena.add_child(actor);actor.sync(runtime.unit_state(handle))
  runtime.enemies[i+1]=actor;runtime.register_actor_facade(actor);arena.enemies.append(actor)
 var dummy=Extra.new();arena.add_child(dummy);arena.training_dummy=dummy;arena.enemies.append(dummy)
 for i in 200:
  if i%10==0:arena.enemies.shuffle()
  var point=Vector3(randf_range(-10,60),0,randf_range(-10,40));var radius=[0.0,3.0,12.0,100.0][i%4]
  var reach=radius+runtime.query_padding+.001
  var handles=runtime.query_aabb(AABB(Vector3(point.x-reach,-1e8,point.z-reach),Vector3(reach*2,2e8,reach*2)),0)
  var expected=arena.enemies.filter(func(actor):return actor==dummy or (not actor.is_queued_for_deletion() and handles.has(actor.handle)))
  check(runtime.enemy_candidates(point,radius)==expected,"Native projection preserves the current small/wide query set and arbitrary order")
 var actor=arena.enemies.filter(func(a):return a!=dummy)[0]
 actor.queue_free()
 check(not runtime.enemy_candidates(Vector3.ZERO,100).has(actor),"Queued native proxies are excluded immediately")
 var stale=Extra.new();arena.add_child(stale);stale.free()
 var malformed=[null,7,stale,dummy]
 check(runtime.native.ordered_enemy_candidates(AABB(Vector3.ZERO,Vector3.ONE),{},malformed,[dummy])==[dummy],"Malformed source values and freed objects are safe")
 var old=arena.enemies.filter(func(a):return a!=dummy and a!=actor)[0];var old_handle=old.handle
 runtime.set_pose(old_handle,Vector3(500,0,500),.7);old.sync(runtime.unit_state(old_handle))
 check(not runtime.enemy_candidates(Vector3.ZERO,100).has(old),"Same-frame native movement changes query membership")
 runtime.despawn(old_handle)
 arena.enemies.erase(old);runtime.enemies.erase(old.forest_id)
 check(not runtime.enemy_candidates(Vector3(500,0,500),1).has(old),"Retirement cannot retain an old generation in query results")
 var replacement_handle=runtime.spawn(10001,0,0,Vector3(500,0,500),100,.4)
 var replacement=Target.new();replacement.runtime=runtime;replacement.handle=replacement_handle;replacement.variant=0;arena.add_child(replacement);replacement.sync(runtime.unit_state(replacement_handle))
 runtime.enemies[10001]=replacement;runtime.register_actor_facade(replacement);arena.enemies.append(replacement)
 check(replacement_handle!=old_handle and (replacement_handle&0xffffffff)==(old_handle&0xffffffff),"The regression exercises an actually reused native slot")
 var reused=runtime.enemy_candidates(Vector3(500,0,500),1)
 check(reused.has(replacement) and not reused.has(old),"Reused slots expose only their current proxy generation")
 check(runtime.enemy_candidates(Vector3(NAN,0,0),1)==arena.enemies,"Invalid requests retain the existing conservative fallback")
 runtime.free();arena.free();print("ARMY_CANDIDATE_MARSHALLING_RESULT checks=",checks," failures=",failures);quit(1 if failures else 0)
