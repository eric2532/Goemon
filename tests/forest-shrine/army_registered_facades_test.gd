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
 if not army.native.has_method("register_facade"):
  check(false,"Spawn-time facade registration is available");finish(army);return
 var actors=[];var rows={};var enemies={};var allies={}
 for i in 4000:
  var team=0 if i<2000 else 1;var id=i+1 if team==0 else -i-1
  var handle:int=army.spawn(id,team,0 if team==0 else 11,Vector3(i%64,0,i/64),200,3.9 if team==0 else .4)
  var actor=load("res://scripts/forest/crowd/army_enemy_target.gd" if team==0 else "res://scripts/forest/crowd/army_ally_target.gd").new();actor.runtime=army;actor.handle=handle
  var row={"retained":true}
  if team==0:actor.forest_id=id;actor.variant=0;rows[id]=row;enemies[id]=actor
  else:actor.gate_id=id;actor.character_id=11;allies[id]=actor
  root.add_child(actor);actor.sync(army.unit_state(handle));actors.append(actor)
  check(army.native.register_facade(handle,row,actor),"Register independent actor with its generation handle")
 var data:Dictionary=army.render_snapshot();data.shared_facades=true;data.guard_poses=true
 for i in 4000:data.positions[i]+=Vector3(.125,.25,.5);data.yaw[i]=.37;data.hp[i]=73.25;data.velocities[i]=Vector3(.5,0,1)
 army.snapshot_epoch+=1;army.snapshot_view=Snapshot.new(data)
 check(army.native.sync_registered_facades(data)==4000,"All4000 actors synchronize without table lookup")
 for i in 4000:
  check(actors[i].position==data.positions[i] and is_equal_approx(actors[i].rotation.y,data.yaw[i]) and actors[i].hp==73.25 and actors[i].max_hp==200 and actors[i].velocity==data.velocities[i],"Registered transfer preserves exact pose/health/motion")
  if i<2000:check(rows[i+1].pos==data.positions[i] and rows[i+1].hp==73.25 and rows[i+1].retained,"Original model dictionary stays live")
 # Replacing a binding must stop writing the old model record, even if held.
 var old_row:Dictionary=rows[1];var replacement={"retained":true};army.native.register_facade(actors[0].handle,replacement,actors[0]);data.hp[0]=62
 army.native.sync_registered_facades(data)
 check(old_row.hp==73.25 and replacement.hp==62,"Explicit rebind releases the previous model row")
 # Dead objects are resolved by ID, never followed through cached raw pointers.
 actors[1].free();check(army.native.sync_registered_facades(data)==3999,"Freed actor is safely skipped")
 var previous_handle:int=actors[0].handle;army.despawn(previous_handle)
 var fresh:int=army.spawn(90001,0,0,Vector3.ZERO,200,3.9)
 check(fresh!=previous_handle and (fresh&0xffffffff)==(previous_handle&0xffffffff),"Fixture reuses native slot with a new generation")
 var fresh_data:Dictionary=army.render_snapshot();fresh_data.shared_facades=true
 check(army.native.sync_registered_facades(fresh_data)==-1,"Missing new-generation binding requests fallback before mutating actors")
 check(not army.native.register_facade(previous_handle,{},actors[0]),"Stale generation cannot bind a replacement")
 var unsupported=Node3D.new();root.add_child(unsupported)
 check(not army.native.register_facade(fresh,{},unsupported),"Unmarked actors retain the generic compatibility path")
 unsupported.free();army.native.clear()
 check(army.native.sync_registered_facades(army.render_snapshot())==0,"Clear releases all registered rows and actors")
 for actor in actors:
  if is_instance_valid(actor):actor.free()
 finish(army)
func finish(army):
 army.free();print("ARMY_REGISTERED_FACADES_RESULT checks=",checks," failures=",failures);quit(1 if failures else 0)
