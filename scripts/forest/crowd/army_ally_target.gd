extends Node3D
const Snapshot=preload("res://scripts/forest/crowd/army_snapshot.gd")
## Autonomous summon compatibility target, never a playable Hero controller.
var runtime:Node
var handle:int
var gate_id:int
var character_id:int
var hp=0.0
var max_hp=0.0
var _state_value="active"
var state:String:
 get:_refresh_shared();return _state_value
 set(value):_state_value=value;_block_shared()
var dead=false
var velocity=Vector3.ZERO
var _targetable_value=true
var _taunting_value=false
var _seen_epoch=-1
var _direct_epoch=-1
var targetable:bool:
 get:_refresh_shared();return _targetable_value
 set(value):_targetable_value=value;_block_shared()
var taunting:bool:
 get:_refresh_shared();return _taunting_value
 set(value):_taunting_value=value;_block_shared()
func uses_shared_snapshot():pass
# HP/max HP/motion are plain storage; native copies need no prior-value reads.
func uses_plain_snapshot_fields():pass
func _block_shared():
 if is_instance_valid(runtime) and runtime.get("shared_snapshot_enabled")==true:_direct_epoch=runtime.snapshot_epoch
func _refresh_shared():
 if dead or handle==0 or not is_instance_valid(runtime) or runtime.get("shared_snapshot_enabled")!=true or runtime.snapshot_view==null:return
 var epoch:int=runtime.snapshot_epoch
 if _direct_epoch==epoch or _seen_epoch==epoch:return
 var view:Snapshot=runtime.snapshot_view;var slot:int=handle&0xffffffff
 if slot<0 or slot>=view.rows_by_slot.size():return
 var row:int=view.rows_by_slot[slot]
 if row<0 or row>=view.handles.size() or view.handles[row]!=handle:return
 _seen_epoch=epoch
 _targetable_value=(view.status[row]&64)==0;_taunting_value=(view.status[row]&32)!=0
 _sync_shared_lifecycle(view,row)
func _sync_shared_lifecycle(_data:Snapshot,_index:int):pass
func sync(data:Dictionary):
 if data.is_empty():return
 _block_shared()
 hp=data.hp;max_hp=data.max_hp;position=data.position;rotation.y=data.yaw;velocity=data.velocity
 targetable=(int(data.get("status",0))&64)==0;taunting=(int(data.get("status",0))&32)!=0
func sync_snapshot(data:Snapshot,index:int):
 _block_shared()
 hp=data.hp[index];max_hp=data.max_hp[index];position=data.positions[index];rotation.y=data.yaw[index];velocity=data.velocities[index]
 targetable=(int(data.status[index])&64)==0;taunting=(int(data.status[index])&32)!=0
func sync_native_snapshot(_data:Snapshot,_index:int,new_hp:float,new_max_hp:float,point:Vector3,motion:Vector3,yaw_:float,_age:float,status_:int,_mode:int):
 _block_shared()
 hp=new_hp;max_hp=new_max_hp;position=point;rotation.y=yaw_;velocity=motion
 targetable=(status_&64)==0;taunting=(status_&32)!=0
func sync_native_metadata(_data:Snapshot,_index:int,new_hp:float,new_max_hp:float,motion:Vector3,_yaw:float,_age:float,status_:int,_mode:int):
 _block_shared()
 hp=new_hp;max_hp=new_max_hp;velocity=motion
 targetable=(status_&64)==0;taunting=(status_&32)!=0
func take_hit(amount:float,direction:Vector3,projectile:bool=false):
 if not dead:runtime.apply_hit(handle,{"amount":amount,"direction":direction,"projectile":projectile})
func mark_dead():dead=true;hp=0;state="dead";targetable=false
