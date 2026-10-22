extends SceneTree
const Runtime=preload("res://scripts/forest/crowd/army_runtime.gd")
class Probe extends Node3D:
 var calls=0
 var seen:Object
 var seen_index=-1
 func sync_snapshot(data:Object,index:int):
  calls+=1;seen=data;seen_index=index
  position=data.positions[index]
class ScalarProbe extends Probe:
 var scalar_calls=0
 var scalar_values=[]
 func sync_native_snapshot(data:Object,index:int,new_hp:float,new_max_hp:float,point:Vector3,motion:Vector3,yaw:float,age:float,status:int,mode:int):
  scalar_calls+=1;scalar_values=[new_hp,new_max_hp,point,motion,yaw,age,status,mode];sync_snapshot(data,index)
class MetadataProbe extends ScalarProbe:
 var metadata_calls=0
 func sync_native_metadata(data:Object,index:int,new_hp:float,new_max_hp:float,motion:Vector3,yaw:float,age:float,status:int,mode:int):
  metadata_calls+=1;scalar_calls+=1;scalar_values=[new_hp,new_max_hp,position,motion,yaw,age,status,mode]
  calls+=1;seen=data;seen_index=index
var checks=0
var failures=0
func check(ok:bool,label_:String):
 checks+=1
 if not ok:failures+=1;printerr("FAIL: ",label_)
func _initialize():run.call_deferred()
func run():
 var runtime=Runtime.new();runtime.configure(null)
 if not runtime.native.has_method("sync_facades"):
  check(false,"Native compatibility batch is available");finish(runtime);return
 var rows={};var enemies={};var allies={};var probes=[]
 for i in 4000:
  var team=0 if i<2000 else 1;var id=i+1 if team==0 else -i-1
  var handle=runtime.spawn(id,team,0 if team==0 else 11,Vector3(i,2,3),192 if team==0 else 200,3.9 if team==0 else .4)
  runtime.set_pose(handle,Vector3(i,2+i%7,3),i*.01)
  if team==0:rows[id]={"hp":0,"pos":Vector3.ZERO,"velocity":Vector3.ONE,"facing":0,"army_pose_row":-99,"retained":true}
  var actor=Probe.new() if team==0 else (ScalarProbe.new() if i%2==0 else MetadataProbe.new());root.add_child(actor);probes.append(actor)
  if team==0:enemies[id]=actor
  else:allies[id]=actor
 var data=runtime.render_snapshot();var held=data.duplicate(true);var view=preload("res://scripts/forest/crowd/army_snapshot.gd").new(data)
 runtime.native.simulation_profile(true)
 check(runtime.native.sync_facades(data,rows,enemies,allies,view)==4000,"Every independent facade receives exactly one shared snapshot")
 check(runtime.native.simulation_profile(false).get("facade_object_lookups",-1)==4000,"Each facade resolves its live scene object exactly once")
 check(probes[2001].metadata_calls==1,"Metadata-capable facades receive engine pose transfer before their state callback")
 check(probes[2000].scalar_calls==1,"Scalar-capable facades receive the direct typed state path")
 var at=2000
 check(probes[at].scalar_values==[data.hp[at],data.max_hp[at],data.positions[at],data.velocities[at],data.yaw[at],data.ages[at],data.status[at],data.shelter_modes[at]],"Direct values retain exact double HP, pose, motion and lifecycle fields")
 for i in 4000:
  var id:int=data.logical_ids[i];var actor=probes[i]
  check(actor.calls==1 and actor.seen_index==i and is_same(actor.seen,view) and actor.position==data.positions[i],"Exact snapshot ownership, index, callback order and pose")
  if data.teams[i]==0:
   var row:Dictionary=rows[id]
   check(row.hp==data.hp[i] and row.pos==data.positions[i] and row.velocity==data.velocities[i] and row.facing==data.yaw[i] and row.army_pose_row==data.pose_rows[i] and row.retained,"Original enemy mirror fields and unrelated metadata retained")
 check(data==held,"Batch never mutates captured packed arrays")
 # Missing and freed facade instances, and a model row removed by a synchronous
 # death callback, must not recreate stale state or call a retired instance.
 enemies[1].free();enemies.erase(2);rows.erase(3)
 check(runtime.native.sync_facades(data,rows,enemies,allies,view)==3998 and not rows.has(3),"Missing/freed nodes are skipped and removed rows stay removed")
 runtime.clear()
 check(runtime.native.sync_facades(runtime.render_snapshot(),rows,enemies,allies,view)==0,"Clear produces no stale callbacks")
 for actor in probes:
  if is_instance_valid(actor):actor.free()
 finish(runtime)
func finish(runtime):
 runtime.free();print("ARMY_FACADE_BATCH_RESULT checks=",checks," failures=",failures);quit(1 if failures else 0)
