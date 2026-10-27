extends Node3D
## Shared lease lifecycle. Trajectory and authored presentation remain kit data.
var game:Node
var hero:Hero
var attack_ticket:Dictionary={}
var projectile_pool:Node
var pool_key=""
var pool_live=false
var pool_defaults:Dictionary={}
var pool_metadata:Dictionary={}
var pool_groups:Array[StringName]=[]

func retire():
	if is_instance_valid(projectile_pool):projectile_pool.release(self)
	else:queue_free()

func restart_visual():pass

const SkillBalance=preload("res://scripts/spells/skill_balance.gd")
var pool_skill_visual_defaults:Dictionary={}

func skill_factor(key:String)->float:return SkillBalance.factor(attack_ticket,key)

func tune_launch():
	var speed=skill_factor("travel_speed")
	for field in ["velocity","speed","native_acceleration"]:
		if get(field)!=null:set(field,get(field)*speed)
	for field in ["hit_radius","blast_radius"]:
		if get(field)!=null:set(field,get(field)*skill_factor("hit_area"))

func reset_visual_tuning():
	for child in pool_skill_visual_defaults:
		if is_instance_valid(child):child.scale=pool_skill_visual_defaults[child]

func tune_visual():
	for child in get_children():
		if child is Node3D:
			pool_skill_visual_defaults[child]=child.scale
			child.scale*=skill_factor("size")
