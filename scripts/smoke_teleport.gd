class_name SmokeTeleport
extends RefCounted
const MAX_DISTANCE=75.0 # Approximately one hundred 0.75m footsteps.
const DURATION=.52
const DAMAGE=36.0
const RADIUS=4.0
var hero: Hero
var combat: Node
var active=false
var elapsed=0.0
var origin=Vector3.ZERO
var destination=Vector3.ZERO
var arrived=false
var hit_count=0
var struck={}
func _init(player,ability):hero=player;combat=ability
func choose_destination():
	var shape=CapsuleShape3D.new();shape.radius=.48;shape.height=1.85
	var query=PhysicsShapeQueryParameters3D.new();query.shape=shape;query.collision_mask=5
	var space=hero.get_world_3d().direct_space_state
	for attempt in range(100):
		var angle=randf()*TAU;var distance=sqrt(randf_range(64,MAX_DISTANCE*MAX_DISTANCE))
		var point=hero.global_position+Vector3(cos(angle),0,sin(angle))*distance
		if not hero.game.world.playable_bounds.grow(-2).has_point(Vector2(point.x,point.z)):continue
		point.y=hero.game.world.height_at(point.x,point.z)
		if point.y<0:continue
		var floor_hit=space.intersect_ray(PhysicsRayQueryParameters3D.create(point+Vector3.UP*3,point-Vector3.UP*2,1))
		if floor_hit.is_empty() or floor_hit.normal.y<.8:continue
		point.y=floor_hit.position.y+.08
		if point.distance_to(hero.global_position)>MAX_DISTANCE:continue
		query.transform=Transform3D(Basis.IDENTITY,point+Vector3.UP*.95)
		if not space.intersect_shape(query,1).is_empty():continue
		var safe=true
		for gate in hero.game.gates:
			if point.distance_to(gate.global_position)<7:safe=false;break
		if safe:return point
	return null
func start()->bool:
	if active or hero.dodge_cooldown>0:return false
	var point=choose_destination()
	if point==null:hero.game.toast("E · No safe landing nearby");return false
	combat.interrupt_for_dodge()
	origin=hero.global_position;destination=point;elapsed=0;arrived=false;struck.clear();hit_count=0;active=true
	hero.attack_left=0;hero.dodge_time=0;hero.dodge_cooldown=.75/hero.attack_speed_multiplier();hero.velocity=Vector3.ZERO
	hero.jump_buffer=0;hero.jump_windup=0;hero.air_turn=0;hero.impact_pause=0
	EdoFireExplosion.emit(hero.game,origin,false,"edo_dodge_impact");smoke_damage(origin)
	hero.game.sound("edo_dodge",.75)
	return true
func smoke_damage(point: Vector3):
	for enemy in hero.game.enemies:
		if not is_instance_valid(enemy) or enemy.dead or struck.has(enemy.get_instance_id()):continue
		var offset=enemy.global_position-point
		if Vector2(offset.x,offset.z).length()>RADIUS+enemy.body_radius or absf(offset.y)>2.5:continue
		var ray=PhysicsRayQueryParameters3D.create(point+Vector3.UP,enemy.global_position+Vector3.UP,1)
		if not hero.get_world_3d().direct_space_state.intersect_ray(ray).is_empty():continue
		struck[enemy.get_instance_id()]=true;hit_count+=1
		enemy.take_hit(DAMAGE*hero.damage_multiplier(),offset.normalized(),false)
		hero.game.burst(enemy.global_position+Vector3.UP,Color("ffb044"),4,.5)
		hero.game.chain+=1;hero.game.chain_timer=3
func tick(delta: float):
	elapsed+=delta*hero.attack_speed_multiplier();hero.dodge_cooldown=maxf(0,hero.dodge_cooldown-delta)
	if not arrived and elapsed>=.20:
		arrived=true;hero.global_position=destination;hero.velocity=Vector3.ZERO
		EdoFireExplosion.emit(hero.game,destination,true,"edo_dodge_impact");smoke_damage(destination)
		hero.game.camera_rig.reset_follow()
	hero.model.visible=elapsed<.12 or elapsed>=.24
	var phase=clampf((elapsed-.24)/.28,0,1) if arrived else clampf(elapsed/.12,0,1)
	var height=(.65 if hit_count>0 else .3)*sin(phase*PI)
	hero.model.locomotion_velocity=Vector3.ZERO
	hero.model.animate(delta,0,false,cos(phase*PI)*4,0,false,0,false)
	hero.model.body.position.y=height
	if elapsed>=DURATION:cancel()
func cancel():
	active=false
	if is_instance_valid(hero.model):hero.model.show();hero.model.body.position=Vector3.ZERO
