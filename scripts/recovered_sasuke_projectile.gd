extends "res://scripts/character_projectile.gd"
## Native Sasuke bomb/ice visuals, with swept collision against the game's fitted targets.
## Speed/range follow source8 units/tick and source60/45-tick ice lifetime;
## damage and freeze duration are explicit adaptations to this game's balance.
var visual_source:Node3D
var kind="ice"
var velocity=Vector3.ZERO
var damage=28.0
var damage_scale=1.0
var visual_scale=1.0
var freeze_seconds=2.0
var hit_radius=.14
var blast_radius=2.3
var bomb_gravity=9.094854
var lifetime=2.0
var age=0.0
var resolved=false
var hit_targets: Dictionary={}
var ornament: Node3D

func _ready():
	add_to_group("sasuke_projectiles")
	if kind=="bomb":lifetime=3.0;damage=42.0;hit_radius=.25
	elif kind=="hail":lifetime=1.5;damage=24.0;freeze_seconds=2.5
	var model=visual_source if is_instance_valid(visual_source) else hero.model
	if is_instance_valid(model) and model.has_method("create_projectile_visual"):
		ornament=model.create_projectile_visual(kind)
		if ornament:add_child(ornament)
	_update_visual(0)

func restart_visual():
	if is_instance_valid(ornament):ornament.rotation=Vector3.ZERO;ornament.scale=Vector3.ONE*visual_scale
	_update_visual(0)

func _physics_process(delta: float):
	if resolved or is_queued_for_deletion():return
	if not is_instance_valid(game) or not is_instance_valid(hero) or not game.playing:
		retire();return
	if game.paused:return
	var step=minf(delta,maxf(lifetime,0))
	var from=global_position
	var gravity=Vector3.DOWN*bomb_gravity if kind=="bomb" else Vector3.ZERO
	var next=from+velocity*step+gravity*step*step*.5
	velocity+=gravity*step
	age+=step;lifetime-=step
	var wall=AttackChain.world_ray(self,from,next)
	var end: Vector3=next if wall.is_empty() else wall.position
	var contact=AttackChain.nearest_contact(game,self,from,end,hit_radius,hit_targets)
	if not contact.is_empty():
		var hit_point:Vector3=contact.center
		global_position=hit_point
		if kind=="bomb":explode(hit_point)
		else:_damage(contact.enemy,hit_point);_finish(hit_point)
		return
	if not wall.is_empty():
		global_position=wall.position+wall.normal*.025
		if kind=="bomb":explode(global_position)
		else:_finish(global_position)
		return
	global_position=next
	if lifetime<=0:
		if kind=="bomb":explode(global_position)
		else:retire()
		return
	_update_visual(step)

func _clear(from: Vector3,to: Vector3)->bool:
	return AttackChain.clear_line(self,from,to)

func _damage(enemy: Ninja,point: Vector3):
	if hit_targets.has(enemy.get_instance_id()):return
	hit_targets[enemy.get_instance_id()]=true
	var direction=velocity.normalized() if kind!="bomb" else (point-global_position).normalized()
	if direction.length_squared()<.001:direction=Vector3.UP
	enemy.take_hit(damage*damage_scale,direction,kind=="bomb",attack_ticket)
	if kind!="bomb" and not enemy.dead:enemy.freeze_for(freeze_seconds)
	if game.player==hero and not hero.ai_controlled:
		game.confirm_impact(enemy,point,direction,2 if kind=="bomb" else 0,true,16)
	else:game.confirm_ally_impact(enemy,point,direction,2 if kind=="bomb" else 0,true,16)
	game.sound("sasuke_bomb_impact" if kind=="bomb" else "sasuke_ice_impact",.55,false,attack_ticket,16)

func explode(point: Vector3):
	if resolved:return
	global_position=point
	for enemy in AttackChain.enemy_candidates(game,point,blast_radius):
		if not is_instance_valid(enemy) or enemy.dead or hit_targets.has(enemy.get_instance_id()):continue
		if AttackChain.segment_contact(enemy,point,point,blast_radius).is_empty():continue
		var contact=AttackChain.contact_point(enemy,point,enemy.global_position+Vector3.UP)
		if _clear(point,contact):_damage(enemy,contact)
	_finish(point)

func _finish(point: Vector3):
	if resolved:return
	resolved=true
	if kind=="bomb":
		game.burst(point,Color("ffd874"),22,1.3*visual_scale)
		game.sound("sasuke_bomb_explosion",.65,false,attack_ticket,16)
	else:game.burst(point,Color("c4f3ff"),8,.4*visual_scale)
	retire()

func _update_visual(delta: float):
	if not is_instance_valid(ornament):return
	if kind=="bomb":ornament.rotation.z+=delta*4.5
	elif velocity.length_squared()>.001:ornament.quaternion=Quaternion(Vector3.UP,velocity.normalized())
