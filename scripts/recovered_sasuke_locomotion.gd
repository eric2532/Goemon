extends RefCounted
## Movement and combat select native action rows; sampling remains in ROM time.
var model:Node3D
var original:RefCounted
var skeleton:Skeleton3D
var dirty=true
var grounded=true
var vertical=0.0
var previous_vertical=0.0
var actual_speed=0.0
var attack=0.0
var dodge=false
var free_feet=false
var reference_jump_flip=-1.0
var jump_compression=0.0
var step_events=0
var land_age=1.0
var idle_time=0.0
var run_time=0.0
var jump_age=0.0
var fall_age=0.0
var previous_step=0
var source_action=-1
var source_time=0.0
func _init(owner_model:Node3D):
 model=owner_model;original=model.sampler;skeleton=model.skeleton
func update(delta:float,velocity_world:Vector3,on_floor:bool,vy:float,attack_value:float,dodging:bool):
 if not on_floor and (grounded or vy>previous_vertical+3):jump_age=0
 else:jump_age+=delta
 if on_floor or (previous_vertical>0 and vy<=0):fall_age=0
 elif vy<=0:fall_age+=delta
 previous_vertical=vy
 if on_floor and not grounded:land_age=0
 else:land_age+=delta
 grounded=on_floor;vertical=vy;attack=attack_value;dodge=dodging
 actual_speed=Vector2(velocity_world.x,velocity_world.z).length()
 run_time+=delta;idle_time+=delta
 if on_floor and actual_speed>.25:
  var step=int(run_time*4)
  if step!=previous_step:step_events+=1;previous_step=step
 dirty=true
func evaluate():
 if not dirty:return
 dirty=false
 var combat=model.combat
 if combat!=null:
  var active=bool(combat.pose_active()) if combat.has_method('pose_active') else bool(combat.is_attacking())
  if active:
   source_action=combat.action_id;source_time=combat.elapsed;model.apply_native_pose(source_action,source_time);return
 if dodge:source_action=0x18;source_time=.08
 elif not grounded:
  source_action=0x18 if vertical>0 else 0x19;source_time=jump_age if vertical>0 else fall_age
 elif land_age<original.duration(0x1a):source_action=0x1a;source_time=land_age
 elif actual_speed>.25:
  source_action=0xf if actual_speed>2.2 else (0xe if actual_speed>1.6 else (0xd if actual_speed>1 else 0xc))
  source_time=fposmod(run_time,maxf(.001,original.duration(source_action)))
 else:
  source_action=0;source_time=fposmod(idle_time,maxf(.001,original.duration(0)))
 model.apply_native_pose(source_action,source_time)
func reset():
 run_time=0;idle_time=0;jump_age=0;fall_age=0;previous_vertical=0;source_action=-1;source_time=0
 grounded=true;vertical=0;actual_speed=0;attack=0;dodge=false;free_feet=false;reference_jump_flip=-1;jump_compression=0;land_age=1;dirty=true
func attach_weapons():pass
