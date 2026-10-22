extends "res://scripts/forest/crowd/army_ally_target.gd"
## Preparation/UI facade only; no player input, Hero, ability graph or skeleton.
var game:Node
var director:Node
var kit_id=11
var slot=0
var guard_post=Vector3.INF
var _age_value=0.0
var age:float:
 get:_refresh_shared();return _age_value
 set(value):_age_value=value;_block_shared()
func _ready():state="idle";set_process(false);set_physics_process(false)
func summon(_target,point:Vector3,_wait:float):
 if runtime.valid(handle):runtime.despawn(handle)
 character_id=kit_id;dead=false;targetable=true;taunting=false;max_hp=director.HEALTH[slot];hp=max_hp
 handle=runtime.spawn(gate_id,1,kit_id,point,hp,.4)
 if handle==0:state="idle";hp=0;return false
 runtime.allies[gate_id]=self;runtime.register_actor_facade(self)
 guard_post=point;position=point;age=0;state="prepared" if game.model.phase=="preparing" else "acting"
 runtime.set_guard(handle,point,director.GUARD_RADIUS);director.smoke_at(point)
func park():
 if runtime.valid(handle):runtime.despawn(handle)
 handle=0;state="idle";dead=false;guard_post=Vector3.INF;hp=0;director.remove_taunt(self)
func assign_guard_post(point:Vector3):
 guard_post=point;position=point
 if runtime.valid(handle):runtime.set_pose(handle,point,rotation.y);runtime.set_guard(handle,point,director.GUARD_RADIUS)
func rest_between_waves():
 if dead or not runtime.valid(handle):return
 state="prepared";age=0
 if guard_post.is_finite():assign_guard_post(guard_post)
func update_health_display():pass # Shared health MultiMesh owns the display.
func rogue_untargetable()->bool:return not targetable
func mark_dead():
 if state!="idle":
  director.living_count=maxi(0,director.living_count-1);game.model.fighter_count=director.living_count
 super.mark_dead();state="idle";director.remove_taunt(self)

func sync(data:Dictionary):
 super.sync(data)
 if data.is_empty():return
 age=data.get("age",age);_sync_mode(int(data.get("shelter_mode",0)))
func sync_snapshot(data:Snapshot,index:int):
 super.sync_snapshot(data,index);age=data.ages[index];_sync_mode(data.shelter_modes[index])
func sync_native_snapshot(data:Snapshot,index:int,new_hp:float,new_max_hp:float,point:Vector3,motion:Vector3,yaw_:float,age_:float,status_:int,mode:int):
 super.sync_native_snapshot(data,index,new_hp,new_max_hp,point,motion,yaw_,age_,status_,mode);age=age_;_sync_mode(mode)
func sync_native_metadata(data:Snapshot,index:int,new_hp:float,new_max_hp:float,motion:Vector3,yaw_:float,age_:float,status_:int,mode:int):
 super.sync_native_metadata(data,index,new_hp,new_max_hp,motion,yaw_,age_,status_,mode);age=age_;_sync_mode(mode)
func _sync_shared_lifecycle(data:Snapshot,index:int):
 _age_value=data.ages[index];_sync_mode(data.shelter_modes[index])
func _sync_mode(mode:int):
 if mode>0:state={1:"retreating",2:"sheltered",3:"returning",4:"bunker_leaping"}[mode]
 elif state not in ["idle","prepared"]:state="acting"
 visible=mode!=2 or kit_id==8
 if game.model.phase=="preparing" and mode!=2 and state!="idle":
  state="prepared"
  if mode==3:assign_guard_post(guard_post)
