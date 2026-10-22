extends Ninja
const Snapshot=preload("res://scripts/forest/crowd/army_snapshot.gd")
## Compatibility facade only: native state owns movement, HP, statuses and attacks.
const Contact=preload("res://scripts/forest/forest_enemy_contact.gd")
const Soldier=preload("res://scripts/forest/forest_thirstquencher_visual.gd")
var runtime:Node
var handle:int
var forest_id:int
var fitted_contact:Dictionary={}
var pose_data:Dictionary={}
func _ready():
 set_physics_process(false);set_process(false);collision_layer=4;collision_mask=0;body_radius=0
 # Native movement owns contacts; Godot retains the same moving query shape.
 if get_tree().get_meta("forest_army_query_static",true):PhysicsServer3D.body_set_mode(get_rid(),PhysicsServer3D.BODY_MODE_STATIC)
 var item=Contact.shapes(variant)[0];var collider=CollisionShape3D.new();collider.shape=item.shape;collider.position=item.center;add_child(collider)
var _packed_owned:Snapshot
var _seen_epoch=-1
var _direct_epoch=-1
var _packed:Snapshot:
 get:
  _refresh_shared()
  if _shared() and _seen_epoch==runtime.snapshot_epoch and _direct_epoch!=runtime.snapshot_epoch:return runtime.snapshot_view
  return _packed_owned
 set(value):
  if _shared() and value!=null and is_same(value,runtime.snapshot_view):
   _packed_owned=null;_seen_epoch=runtime.snapshot_epoch;_direct_epoch=-1
  else:
   _packed_owned=value
   if _shared():_direct_epoch=runtime.snapshot_epoch
var _index=-1
var _state:Dictionary={}
var _pose_dirty=true
var _fit_dirty=true
var _bounds_dirty=true
var _bounds:AABB
var _yaw_value=0.0
var _yaw:float:
 get:_refresh_shared();return _yaw_value
 set(value):_yaw_value=value
func _shared()->bool:return is_instance_valid(runtime) and runtime.get("shared_snapshot_enabled")==true
func uses_shared_snapshot():pass
# HP/max HP/motion are plain storage; native copies need no prior-value reads.
func uses_plain_snapshot_fields():pass
func _refresh_shared():
 if not _shared() or runtime.snapshot_view==null:return
 var epoch:int=runtime.snapshot_epoch
 if _direct_epoch==epoch or _seen_epoch==epoch:return
 var view:Snapshot=runtime.snapshot_view;var slot:int=handle&0xffffffff
 if slot<0 or slot>=view.rows_by_slot.size():return
 var row:int=view.rows_by_slot[slot]
 if row<0 or row>=view.handles.size() or view.handles[row]!=handle:return
 _packed_owned=null;_seen_epoch=epoch;_direct_epoch=-1;_index=row;_yaw_value=view.yaw[row]
 _pose_dirty=true;_fit_dirty=true;_bounds_dirty=true;_contact_dirty=true
var _contact_dirty=true
var _contact_pose=Transform3D.IDENTITY
var _contact_inverse=Transform3D.IDENTITY
func sync(data:Dictionary):
 if data.is_empty():return
 _packed=null;_index=-1;_state=data
 hp=data.hp;max_hp=data.max_hp;global_position=data.position;velocity=data.velocity;_yaw=data.yaw;rotation.y=_yaw
 _pose_dirty=true;_fit_dirty=true;_bounds_dirty=true;_contact_dirty=true
func sync_snapshot(data:Snapshot,index:int):
 _packed=data;_index=index
 hp=data.hp[index];max_hp=data.max_hp[index];global_position=data.positions[index];velocity=data.velocities[index];_yaw=data.yaw[index];rotation.y=_yaw
 _pose_dirty=true;_fit_dirty=true;_bounds_dirty=true;_contact_dirty=true
func sync_native_snapshot(data:Snapshot,index:int,new_hp:float,new_max_hp:float,point:Vector3,motion:Vector3,yaw_:float,_age:float,_status:int,_mode:int):
 _packed=data;_index=index
 hp=new_hp;max_hp=new_max_hp;global_position=point;velocity=motion;_yaw=yaw_;rotation.y=_yaw
 _pose_dirty=true;_fit_dirty=true;_bounds_dirty=true;_contact_dirty=true
func sync_native_metadata(data:Snapshot,index:int,new_hp:float,new_max_hp:float,motion:Vector3,yaw_:float,_age:float,_status:int,_mode:int):
 _packed=data;_index=index;hp=new_hp;max_hp=new_max_hp;velocity=motion;_yaw=yaw_
 _pose_dirty=true;_fit_dirty=true;_bounds_dirty=true;_contact_dirty=true
func _combat_data()->Dictionary:
 _refresh_shared()
 if not _pose_dirty:return pose_data
 _pose_dirty=false
 var data:Dictionary=_state
 var packed:Snapshot=_packed
 if _index>=0 and packed!=null:
  var i=_index;data={"pose_velocity":packed.pose_velocities[i],"pose_time":packed.pose_time[i],"frozen":1.0 if packed.status[i]&1 else 0.0,"action_time":packed.action_time[i],"pose_row":packed.pose_rows[i],"action":packed.actions[i],"stun":packed.stun_left[i],"walk_phase":packed.walk_phase[i]}
 pose_data={"variant":variant,"pos":global_position,"facing":_yaw,"velocity":data.get("pose_velocity",velocity),"soldier_pose_tick":data.get("pose_time",0.0)*30,"frozen":data.get("frozen",0.0),"action":"walk","soldier_tick":data.get("action_time",0.0)*30}
 if int(data.get("pose_row",-1))>=0:pose_data.army_pose_row=data.pose_row
 var action=int(data.get("action",0))
 if action in [1,2,3,4,5]:
  var source=preload("res://scripts/forest/forest_thirstquencher_combat.gd")
  var phase=preload("res://scripts/forest/crowd/army_kit_data.gd").ACTION.keys()[action]
  source._enter(pose_data,phase);pose_data.soldier_tick=data.get("action_time",0.0)*30;pose_data.soldier_action="attack"
 elif action==6:pose_data.soldier_hurt_clip="Source__801b02a8";pose_data.soldier_hurt_tick=(16.0/30-float(data.get("stun",16.0/30)))*30;pose_data.soldier_hurt_left=.1
 else:pose_data.soldier_action="walk";pose_data.walk_phase=float(data.get("walk_phase",0.0))
 return pose_data
func _ensure_contact():
 _refresh_shared()
 if not _fit_dirty:return
 fitted_contact=Contact.prepare(_combat_data());_fit_dirty=false
func _sync_fitted_pose():sync(runtime.unit_state(handle))
func combat_bounds()->AABB:
 _refresh_shared()
 if _bounds_dirty:
  _bounds=Transform3D(Basis(Vector3.UP,_yaw),global_position)*Contact.shapes(variant)[0].bounds;_bounds_dirty=false
 return _bounds
func combat_contact_point(point:Vector3)->Vector3:
 _refresh_shared()
 if _contact_dirty:
  _contact_pose=Transform3D(Basis(Vector3.UP,_yaw),global_position);_contact_inverse=_contact_pose.affine_inverse();_contact_dirty=false
 var box:AABB=Contact.shapes(variant)[0].bounds
 return _contact_pose*(_contact_inverse*point).clamp(box.position,box.end)
func combat_aim_point(point:Vector3)->Vector3:return combat_contact_point(point)
func has_shared_combat_contacts()->bool:return false
func combat_contact_candidates(point:Vector3)->PackedVector3Array:return PackedVector3Array([combat_contact_point(point)])
func combat_physics_contact(_shape:int,point:Vector3)->Vector3:return combat_contact_point(point)
func combat_segment_contact(from:Vector3,to:Vector3,radius:float)->Dictionary:
 if dead or not runtime.valid(handle):return {}
 _ensure_contact();return Contact.segment_contact(_combat_data(),from,to,radius,fitted_contact)
func combat_segment_hit(from:Vector3,to:Vector3,radius:float)->bool:return not combat_segment_contact(from,to,radius).is_empty()
func take_hit(amount:float,direction:Vector3,heavy:bool,ticket:Dictionary={}):
 if dead or amount<=0 or not runtime.valid(handle):return
 var source_ref=ticket.get("source_hero");var source=source_ref.get_ref() if source_ref is WeakRef else game.player
 var critical=preload("res://scripts/critical_hits.gd").roll(ticket)
 if not ticket.get("tower",false):
  if is_instance_valid(source):amount*=source.attack_chain.damage_for(ticket);source.attack_chain.confirm(ticket)
  if critical:amount*=preload("res://scripts/critical_hits.gd").DAMAGE_MULTIPLIER
 if ticket.get("lethal_headshot",false):amount=maxf(amount,runtime.unit_state(handle).hp)
 var source_id=int(source.get("gate_id")) if ticket.get("allied",false) and is_instance_valid(source) and source.get("gate_id")!=null else 0
 var attribution=ticket.duplicate();attribution.critical=critical
 runtime.hit_target(handle,{"amount":amount,"source_id":source_id,"direction":direction,"heavy":heavy,"provoke":not ticket.get("tower",false),"projectile":ticket.get("projectile",false)},attribution)
func combat_knockback(direction:Vector3,strength:float,flinch:float):
 if not dead:runtime.apply_hit(handle,{"knockback":Vector3(direction.x,0,direction.z)*strength,"flinch":flinch})
func apply_rogue_bash(direction:Vector3):
 if not dead:runtime.apply_hit(handle,{"knockback":Vector3(direction.x,0,direction.z)*7,"flinch":.2,"add_impulse":true})
func freeze_for(seconds:float):
 if not dead:runtime.apply_hit(handle,{"element":"ice","status_seconds":seconds})
func apply_defense_slow(factor:float,seconds:float):
 if not dead:runtime.apply_hit(handle,{"element":"slow","slow_factor":clampf(factor,.1,1),"status_seconds":seconds})
func mark_dead():
 dead=true;hp=minf(0,hp);collision_layer=0;visible=false
