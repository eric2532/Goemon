extends SceneTree
const Runtime=preload("res://scripts/forest/crowd/army_runtime.gd")
const Snapshot=preload("res://scripts/forest/crowd/army_snapshot.gd")
var checks=0
var failures=0
func check(ok:bool,label_:String):
 checks+=1
 if not ok:failures+=1;printerr("FAIL: ",label_)
func _initialize():run.call_deferred()
func run():
 var army=Runtime.new();root.add_child(army);army.configure(null);army.shared_snapshot_enabled=true
 var rows={};var enemies={};var allies={}
 for i in 4000:
  var team=0 if i<2000 else 1;var id=i+1 if team==0 else -i-1;var kind=[0,1,3][i%3] if team==0 else [11,5,7,8,10][i%5]
  var handle:int=army.spawn(id,team,kind,Vector3(i%64,0,i/64),200,3.9 if team==0 else .4)
  var actor=load("res://scripts/forest/crowd/army_enemy_target.gd" if team==0 else "res://scripts/forest/crowd/army_ally_target.gd").new();actor.runtime=army;actor.handle=handle
  if team==0:actor.forest_id=id;actor.variant=kind;rows[id]={};enemies[id]=actor
  else:actor.gate_id=id;actor.character_id=kind;allies[id]=actor
  root.add_child(actor);actor.sync(army.unit_state(handle))
 var a:Dictionary=army.render_snapshot();a.shared_facades=true;a.guard_poses=true
 var b:Dictionary=a.duplicate(true)
 for i in 4000:b.positions[i]+=Vector3(.125,0,.25);b.yaw[i]+=.13;b.hp[i]-=.25;b.velocities[i]=Vector3(.5,0,1)
 var fields=["facade_total_ms","facade_unpack_ms","facade_rows_ms","facade_lookup_ms","facade_pose_ms","facade_fields_ms","facade_callbacks_ms"]
 var initial:Dictionary=army.native.simulation_profile(false)
 if not initial.has("facade_total_ms"):
  check(false,"Facade transfer exposes opt-in subphase measurements")
  for actor in enemies.values()+allies.values():actor.free()
  army.free();print("ARMY_FACADE_PROFILE_RESULT checks=",checks," failures=",failures);quit(1);return
 army.snapshot_view=Snapshot.new(a)
 army.native.sync_facades(a,rows,enemies,allies,army.snapshot_view)
 check(army.native.simulation_profile(false).facade_total_ms==0,"Normal unprofiled transfer does not collect timers")
 var elapsed=0;var transfers=0
 army.native.simulation_profile(true)
 army.native.sync_facades(a,rows,enemies,allies,army.snapshot_view)
 check(army.native.simulation_profile(false).facade_total_ms==0,"Ordinary battle profiling avoids per-object timer overhead")
 a.profile_facades=true;b.profile_facades=true
 for frame in 80:
  var data:Dictionary=a if frame%2==0 else b
  army.snapshot_epoch+=1;army.snapshot_view=Snapshot.new(data)
  var started=Time.get_ticks_usec();transfers+=army.native.sync_facades(data,rows,enemies,allies,army.snapshot_view);var used=Time.get_ticks_usec()-started
  if frame>=20:elapsed+=used
  await process_frame
 print("ARMY_FACADE_COST ms=",elapsed/60000.0," transfers=",transfers," binary=",FileAccess.get_sha256("res://native/terrain_math/bin/libgoemon_terrain_math.macos.universal.dylib"))
 var measured:Dictionary=army.native.simulation_profile(false)
 var sum_parts=0.0
 for key in fields:
  check(measured[key]>0,"Real 4000-unit transfer records "+key)
  if key!="facade_total_ms":sum_parts+=measured[key]
 check(measured.facade_total_ms>=sum_parts-.001,"Subphase measurements fit inside full transfer time")
 check(measured.get("facade_field_reads",-1)==0,"Plain snapshot fields are copied without reading the previous value first")
 check(transfers==320000,"Every transfer still synchronizes all4000 independent facades")
 print("ARMY_FACADE_PHASES ",JSON.stringify(measured))
 army.native.simulation_profile(true)
 check(army.native.simulation_profile(false).facade_total_ms==0,"Profiling reset clears transfer totals")
 for actor in enemies.values()+allies.values():actor.free()
 army.free();print("ARMY_FACADE_PROFILE_RESULT checks=",checks," failures=",failures);quit.call_deferred(1 if failures else 0)
