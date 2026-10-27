extends SceneTree
const Runtime=preload("res://scripts/forest/crowd/army_runtime.gd")
const Snapshot=preload("res://scripts/forest/crowd/army_snapshot.gd")
const Ally=preload("res://scripts/forest/crowd/army_ally_target.gd")
var checks=0
var failures=0
func check(ok:bool,label_:String):
 checks+=1
 if not ok:failures+=1;printerr("FAIL: ",label_)
func _initialize():run.call_deferred()
func publish(army:Node,data:Dictionary,lazy:bool=true):
 army.snapshot_epoch+=1;army.snapshot_view=Snapshot.new(data);army.ally_fields_epoch=army.snapshot_epoch if lazy else -1
 data.shared_facades=true;data.lazy_ally_fields=lazy
 check(army.native.sync_registered_facades(data)==2000,"Every independent ally pose is published")
func run():
 var army=Runtime.new();root.add_child(army);army.configure(null);army.shared_snapshot_enabled=true
 var actors=[]
 for i in 2000:
  var h:int=army.spawn(-i-1,1,11,Vector3(i%50,0,i/50),200,.4)
  var actor=Ally.new();actor.runtime=army;actor.handle=h;actor.gate_id=-i-1;root.add_child(actor);actor.sync(army.unit_state(h));actors.append(actor)
  check(army.native.register_facade(h,{},actor),"Owned ally registers once")
 var data:Dictionary=army.render_snapshot()
 for i in 2000:data.hp[i]=73.25;data.max_hp[i]=201.125;data.positions[i]+=Vector3(.5,2,.25);data.velocities[i]=Vector3(.25,0,.75)
 publish(army,data)
 check(actors.all(func(a):return a._hp_value==200 and a._velocity_value==Vector3.ZERO),"Publishing avoids all2000 health/motion assignments")
 for i in 2000:
  check(actors[i].position==data.positions[i] and actors[i].hp==73.25 and actors[i].max_hp==201.125 and actors[i].velocity==Vector3(.25,0,.75),"First read gets the current independent health/motion and physical pose")
 army.native.simulation_profile(true);army.native.sync_registered_facades(data)
 check(army.native.simulation_profile(false).facade_total_ms==0,"Normal publication avoids opt-in per-unit clocks")
 data.profile_registered=true;army.native.sync_registered_facades(data)
 var measured:Dictionary=army.native.simulation_profile(false)
 check(measured.facade_total_ms>0 and measured.facade_pose_ms>0 and measured.facade_total_ms>=measured.facade_unpack_ms+measured.facade_rows_ms+measured.facade_lookup_ms+measured.facade_pose_ms+measured.facade_fields_ms-.001,"Opt-in diagnostics measure the actual registered publisher")
 data.erase("profile_registered")
 var actor=actors[0];var retained:Snapshot=army.snapshot_view
 data=data.duplicate(true);data.hp[0]=48.125;data.max_hp[0]=250.25;data.velocities[0]=Vector3(2,3,4);data.status[0]=32
 publish(army,data);actor.targetable=false
 check(actor.hp==48.125 and actor.max_hp==250.25 and actor.velocity==Vector3(2,3,4) and actor.taunting and not actor.targetable,"A local status write retains the newly published health and other flags")
 publish(army,data);actor.hp=19.75
 check(actor.hp==19.75 and actor.max_hp==250.25 and actor.velocity==Vector3(2,3,4) and actor.taunting,"A same-frame health override keeps all other published fields current")
 publish(army,data);actor.velocity=Vector3.UP
 check(actor.hp==48.125 and actor.max_hp==250.25 and actor.velocity==Vector3.UP,"A same-frame motion override cannot expose stale health")
 actor.sync({"hp":9.5,"max_hp":300.25,"position":Vector3(7,2,9),"velocity":Vector3.LEFT,"yaw":.8,"status":64})
 check(actor.hp==9.5 and actor.max_hp==300.25 and actor.velocity==Vector3.LEFT and not actor.targetable,"Direct damage/state callbacks take precedence over the older published view")
 publish(army,data)
 check(actor.hp==48.125 and actor.max_hp==250.25 and actor.velocity==Vector3(2,3,4),"A later publication replaces the previous direct override")
 check(retained.hp[0]==73.25 and retained.velocities[0]==Vector3(.25,0,.75),"Retained snapshots remain immutable")
 data.hp[0]=66.5;publish(army,data,false)
 check(actor.hp==66.5 and actor.velocity==Vector3(2,3,4),"Explicit transfers remain compatible without shared field publication")
 publish(army,data);actor.mark_dead()
 check(actor.hp==0 and actor.dead and not actor.targetable,"Death cannot be reversed by a lazy read")
 var old=actor.handle;army.despawn(old);var fresh:int=army.spawn(-9000,1,11,Vector3.ZERO,190,.4)
 check(fresh!=old and (fresh&0xffffffff)==(old&0xffffffff),"Fixture reuses the retired slot with a new generation")
 army.snapshot_epoch+=1;army.snapshot_view=Snapshot.new(army.render_snapshot());army.ally_fields_epoch=army.snapshot_epoch
 check(actor.hp==0 and actor.velocity==Vector3(2,3,4),"A retired facade never reads a recycled unit's state")
 for a in actors:a.free()
 army.clear();check(army.ally_fields_epoch==-1 and army.snapshot_view==null,"Reset releases the shared field publication")
 army.free();print("ARMY_LAZY_ALLY_FIELDS_RESULT checks=",checks," failures=",failures);quit(1 if failures else 0)
