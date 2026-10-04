class_name GoemonDash
extends RefCounted

const DURATION=0.20
const SPEED=20.0
const IMMUNITY=0.34
const COOLDOWN=0.80
const DAMAGE=4.0
const PUSH_SPEED=22.0
var attack_ticket: Dictionary={}
var hero: Hero
var active=false
var remaining=0.0
var tempo=1.0
var immunity_left=0.0
var direction=Vector3.FORWARD
var struck: Dictionary={}

func _init(player):hero=player

func start()->bool:
	if hero.character_id!=1 or (hero.dodge_cooldown>0 and not hero.attack_chain.unleashed()):return false
	hero.cancel_charge(false,hero.game.rogue_battle_mode)
	hero.attack_left=0;hero.heavy_buffer=0;hero.combo=0;hero.queued=false;hero.impact_pause=0
	hero.reset_wall_jump()
	hero.jump_buffer=0;hero.jump_windup=0;hero.air_turn=0
	direction=hero.game.attack_direction()
	hero.facing=direction
	attack_ticket=hero.attack_chain.begin("dash");tempo=hero.attack_speed_multiplier()
	hero.dodge_time=DURATION/tempo;hero.dodge_cooldown=COOLDOWN/tempo
	active=true;remaining=DURATION/tempo;immunity_left=IMMUNITY;struck.clear()
	hero.game.sound("goemon_dash")
	hero.game.wind(hero.global_position+Vector3.UP*.8,-direction)
	if hero.attack_chain.unleashed():
		var from=hero.global_position
		var motion=direction*SPEED*DURATION*hero.growth_multiplier()
		for i in range(4):
			var collision=hero.move_and_collide(motion)
			if collision==null:break
			motion=collision.get_remainder().slide(collision.get_normal())
			if motion.length_squared()<.0001:break
		after_move(from,DURATION);hero.dodge_time=0;hero.dodge_cooldown=0
	return true

func after_move(origin: Vector3,delta: float):
	if not active:return
	# Sweep only the distance actually travelled by the collision-aware body.
	var end=hero.global_position
	BreakableBuilding.hit_area(hero.game,end+Vector3.UP*hero.growth_multiplier(),1.2*hero.growth_multiplier(),DAMAGE*hero.damage_multiplier(),attack_ticket,direction,-.2,struck)
	for enemy in hero.game.enemies:
		if not is_instance_valid(enemy) or enemy.dead or struck.has(enemy.get_instance_id()):continue
		var center=enemy.global_position
		var nearest=Geometry3D.get_closest_point_to_segment(center,origin,end)
		var offset=center-nearest
		if absf(offset.y)>2.0:continue
		offset.y=0
		if offset.length()>.85*hero.growth_multiplier()+enemy.body_radius:continue
		var ray=PhysicsRayQueryParameters3D.create(nearest+Vector3.UP,center+Vector3.UP,1)
		if not hero.get_world_3d().direct_space_state.intersect_ray(ray).is_empty():continue
		struck[enemy.get_instance_id()]=true
		var push=(offset.normalized()+direction*.75).normalized()
		if push.length_squared()<.1:push=direction
		enemy.take_hit(DAMAGE*hero.damage_multiplier(),push,false,attack_ticket)
		if not enemy.training_dummy:
			enemy.velocity=push*PUSH_SPEED*enemy.growth_knockback()/(3.0 if enemy.ground_giant else (1.7 if enemy.boss or enemy.island_elite else 1.0))+Vector3.UP*2.0
			enemy.stun=maxf(enemy.stun,.38)
			enemy.grounded_cached=false
		hero.game.burst(center+Vector3.UP,Color("ffe3a0"),5,.6)
		hero.game.sound("goemon_dash_hit",.5)
	remaining=maxf(0,remaining-delta)
	if remaining<=0.0001:
		active=false;hero.dodge_time=0
		hero.velocity.x=0;hero.velocity.z=0

func cancel():
	if active:
		hero.velocity.x=0;hero.velocity.z=0;hero.dodge_time=0
	active=false;remaining=0;immunity_left=0;struck.clear()
