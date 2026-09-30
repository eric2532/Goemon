class_name GoemonDash
extends RefCounted

const DURATION=0.20
const SPEED=20.0
const IMMUNITY=0.34
const COOLDOWN=0.80
const DAMAGE=4.0
const PUSH_SPEED=22.0
var hero: Hero
var active=false
var remaining=0.0
var immunity_left=0.0
var direction=Vector3.FORWARD
var struck: Dictionary={}

func _init(player):hero=player

func start()->bool:
	if hero.character_id!=1 or hero.dodge_cooldown>0:return false
	hero.cancel_charge()
	hero.attack_left=0;hero.heavy_buffer=0;hero.combo=0;hero.queued=false;hero.impact_pause=0
	hero.jump_buffer=0;hero.jump_windup=0;hero.air_turn=0
	direction=Vector3.FORWARD.rotated(Vector3.UP,hero.game.camera_rig.yaw)
	hero.facing=direction
	hero.dodge_time=DURATION;hero.dodge_cooldown=COOLDOWN
	active=true;remaining=DURATION;immunity_left=IMMUNITY;struck.clear()
	hero.game.sound("goemon_dash")
	hero.game.wind(hero.global_position+Vector3.UP*.8,-direction)
	return true

func after_move(origin: Vector3,delta: float):
	if not active:return
	# Sweep only the distance actually travelled by the collision-aware body.
	var end=hero.global_position
	for enemy in hero.game.enemies:
		if not is_instance_valid(enemy) or enemy.dead or struck.has(enemy.get_instance_id()):continue
		var center=enemy.global_position
		var nearest=Geometry3D.get_closest_point_to_segment(center,origin,end)
		var offset=center-nearest
		if absf(offset.y)>2.0:continue
		offset.y=0
		if offset.length()>0.85+enemy.body_radius:continue
		var ray=PhysicsRayQueryParameters3D.create(nearest+Vector3.UP,center+Vector3.UP,1)
		if not hero.get_world_3d().direct_space_state.intersect_ray(ray).is_empty():continue
		struck[enemy.get_instance_id()]=true
		var push=(offset.normalized()+direction*.75).normalized()
		if push.length_squared()<.1:push=direction
		enemy.take_hit(DAMAGE*hero.damage_multiplier(),push,false)
		if not enemy.training_dummy:
			enemy.velocity=push*PUSH_SPEED/(1.7 if enemy.boss else 1.0)+Vector3.UP*2.0
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
