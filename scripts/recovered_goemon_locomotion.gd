extends RefCounted
## Native action selector; source rigid meshes consume their original matrices.
const Profile=preload("res://scripts/recovered_goemon_combat_profile.gd")
var model:Node3D
var original:RefCounted
var skeleton:Skeleton3D
var dirty=true
var grounded=true
var vertical=0.0
var actual_speed=0.0
var attack=0.0
var dodge=false
var free_feet=false
var reference_jump_flip=-1.0
var jump_compression=0.0
var step_events=0
var land_age=1.0
var idle_time=0.0
var previous_step=0
var source_action=-1
var source_time=0.0
var run_time=0.0
var previous_vertical=0.0
var jump_age=0.0
var fall_age=0.0

func _init(owner_model:Node3D):
	model=owner_model;skeleton=model.skeleton
	original=model.sampler

func update(delta:float,velocity_world:Vector3,on_floor:bool,vy:float,attack_value:float,dodging:bool):
	if not on_floor and (grounded or vy>previous_vertical+3.0):jump_age=0
	else:jump_age+=delta
	if on_floor or (previous_vertical>0 and vy<=0):fall_age=0
	elif vy<=0:fall_age+=delta
	previous_vertical=vy
	if on_floor and not grounded:land_age=0
	else:land_age+=delta
	run_time+=delta;idle_time+=delta
	grounded=on_floor;vertical=vy;attack=attack_value;dodge=dodging
	actual_speed=Vector2(velocity_world.x,velocity_world.z).length()
	if on_floor and actual_speed>.25:
		var step=int(run_time*4)
		if step!=previous_step:step_events+=1;previous_step=step
	dirty=true

func evaluate():
	if not dirty:return
	dirty=false
	source_action=-1;source_time=0
	if dodge:
		source_action=0x18;source_time=0.08
		model.apply_native_pose(source_action,source_time);return
	var actor=model.get_parent()
	var has_actor=is_instance_valid(actor) and actor.has_method("start_attack")
	if attack>0:
		var slot=int(actor.weapon_slot) if has_actor else (3 if model.chain_selected else 1)
		if has_actor and actor.attack_charged and slot==1:
			source_action=0x6A;source_time=(1.0-attack)*Profile.action_duration(0x6A)
			model.apply_native_pose(source_action,source_time);return
		var duration_:float=actor.attack_duration if has_actor else Profile.duration(model.pipe_combo_stage)
		var elapsed=(1.0-attack)*duration_
		if slot==1:
			var sample_:Dictionary=Profile.action_at(model.pipe_combo_stage,elapsed)
			source_action=sample_.action;source_time=sample_.time_seconds
		elif slot==2:
			source_action=actor.original_coin_action if has_actor else Profile.coin_action(grounded,actual_speed>.25);source_time=elapsed
		elif has_actor and actor.chain_pipe_combat.active:
			var chain_pose:Dictionary=Profile.chain_at(elapsed,actor.chain_pipe_combat.duration,not grounded)
			source_action=chain_pose.action;source_time=chain_pose.time_seconds
	elif model.transform_age>=0:
		var first:float=Profile.action_duration(0x82)
		if model.transform_age<first:
			source_action=0x82;source_time=model.transform_age
		elif model.transform_age<first+Profile.action_duration(0x83):
			source_action=0x83;source_time=model.transform_age-first
		else:model.transform_age=-1
	if source_action<0 and model.original_ranged_age>=0:
		source_action=model.original_ranged_action;source_time=model.original_ranged_age
	if source_action<0:
		if not grounded:
			source_action=0x18 if vertical>0 else 0x19;source_time=jump_age if vertical>0 else fall_age
		elif land_age<Profile.action_duration(0x1A):source_action=0x1A;source_time=land_age
		elif actual_speed>.25:
			source_action=0x0F if actual_speed>2.2 else (0x0E if actual_speed>1.6 else (0x0D if actual_speed>1.0 else 0x0C))
			source_time=fposmod(run_time,maxf(.001,Profile.action_duration(source_action)))
		else:
			source_action=0;source_time=fposmod(idle_time,maxf(.001,Profile.action_duration(0)))
	model.apply_native_pose(source_action,source_time)


func reset():
	run_time=0;idle_time=0;jump_age=0;fall_age=0;previous_vertical=0;source_action=-1;source_time=0
	grounded=true;vertical=0;actual_speed=0;attack=0;dodge=false
	free_feet=false;reference_jump_flip=-1;jump_compression=0;land_age=1;dirty=true

func attach_weapons():
	model.attach_native_weapons(original.sample_source(maxi(0,source_action),source_time))
