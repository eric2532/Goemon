extends SceneTree
const Runtime=preload("res://scripts/forest/crowd/army_runtime.gd")
const Snapshot=preload("res://scripts/forest/crowd/army_snapshot.gd")
class Enemy extends "res://scripts/forest/crowd/army_enemy_target.gd":
 var writes=0
 func _notification(what):
  if what==Node3D.NOTIFICATION_LOCAL_TRANSFORM_CHANGED:writes+=1
class Ally extends "res://scripts/forest/crowd/army_ally_target.gd":
 var writes=0
 func _notification(what):
  if what==Node3D.NOTIFICATION_LOCAL_TRANSFORM_CHANGED:writes+=1
var checks=0
var failures=0
func check(ok:bool,label_:String):
 checks+=1
 if not ok:failures+=1;printerr("FAIL: ",label_)
func _initialize():run.call_deferred()
func run():
 var army=Runtime.new();army.configure(null)
 army.spawn(1,0,0,Vector3(7,3,11),192.125,3.9);army.spawn(-1,1,11,Vector3(17,2,21),200.125,.4)
 var data=army.render_snapshot();var view=Snapshot.new(data);var actors=[Enemy.new(),Ally.new()]
 for i in 2:
  var actor=actors[i];actor.runtime=army
  if i==0:actor.variant=0
  root.add_child(actor);actor.set_notify_local_transform(true);actor.sync_snapshot(view,i)
 var enemies={1:actors[0]};var allies={-1:actors[1]}
 for i in 2:
  var actor=actors[i];var expected=actor.global_transform;actor.writes=0
  army.native.sync_facades(data,{},enemies,allies,view)
  check(actor.writes==0,"Unchanged authoritative pose performs no engine transform writes")
  check(actor.global_transform==expected and actor.hp==data.hp[i],"Idle transfer retains exact world pose and fractional health")
  actor.position+=Vector3(3,2,1);actor.rotation.y+=.5
  army.native.sync_facades(data,{},enemies,allies,view)
  check(actor.global_transform.is_equal_approx(expected),"A directly displaced scene facade is restored to authoritative simulation pose")
 var later=data.duplicate(true);later.pose_time[0]+=.2;var fresh=Snapshot.new(later);var enemy=actors[0]
 enemy._combat_data();enemy.writes=0
 army.native.sync_facades(later,{},enemies,allies,fresh)
 check(is_same(enemy._packed,fresh) and enemy._combat_data().soldier_pose_tick==later.pose_time[0]*30,"Stationary fitted contacts retain the new animation/status snapshot")
 check(enemy.writes==0,"Animation-only state does not dirty the static collision transform")
 for actor in actors:actor.free()
 army.free();print("ARMY_ENGINE_IDLE_RESULT checks=",checks," failures=",failures);quit(1 if failures else 0)
