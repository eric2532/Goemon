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
	if attack_ticket.has("magic_result") and (pool_live or (projectile_pool==null and not is_queued_for_deletion())):
		attack_ticket.magic_result.pending-=1
	if is_instance_valid(projectile_pool):projectile_pool.release(self)
	else:queue_free()

func damage_spell_target(target:Ninja,amount:float,direction:Vector3):
	var result:Variant=attack_ticket.get("magic_result")
	var before=target.hp
	target.take_hit(amount,direction,false,attack_ticket)
	if result!=null and is_instance_valid(target) and target.hp<before:
		result.hit=true

func restart_visual():pass

func damage_spell_area(primary:Ninja,center:Vector3,radius:float,amount:float,direction:Vector3,exclude:Array[RID]=[]):
	damage_spell_target(primary,amount,direction)
	for enemy in AttackChain.enemy_candidates(game,center,radius):
		if not is_instance_valid(enemy) or enemy==primary or enemy.dead:continue
		if game.has_method("forest_enemy_visible") and not game.forest_enemy_visible(enemy):continue
		if AttackChain.segment_contact(enemy,center,center,radius).is_empty():continue
		if not AttackChain.clear_line(self,center,AttackChain.aim_point(enemy,center),exclude):continue
		damage_spell_target(enemy,amount,direction)

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
