extends RefCounted
## Hidden, grounded melee assistance. Camera and ordinary input remain manual.
const ACQUIRE_ANGLE=PI/4.0
const RETAIN_ANGLE=PI/3.0
const MAX_CORRECTION=PI*25.0/180.0
const BREAK_AIM=PI*22.0/180.0
const TURN_SPEED=4.5
const MEMORY=1.1
const STEP_DISTANCE=.30
const STEP_SPEED=2.0
var reference: WeakRef
var remaining=0.0
var active=false
var reach=0.0
var camera_aim=0.0
var camera_pitch=0.0
var step_left=0.0
var released_to_manual=false

func target():return reference.get_ref() if reference!=null else null
func reset():
	reference=null;remaining=0.0;active=false;step_left=0.0
	released_to_manual=false
func manual_angle(hero)->float:return atan2(-sin(hero.game.camera_rig.yaw),-cos(hero.game.camera_rig.yaw))
func _available(hero)->bool:
	if hero.auto_attack_enabled:return false
	if not hero.game.has_method("forest_enemy_visible") or not hero.is_on_floor() or hero.velocity.y>0 or hero.jump_buffer>0 or hero.jump_windup>0:return false
	if hero.dodge_time>0 or hero.forward_dash.active or hero.sky_strike.active or hero.chain_pipe_combat.active:return false
	if hero.is_rogue_character():
		var p: Dictionary=hero.active_ability.player
		if p.roll>0 or p.travel!=null or p.get("dive")!=null or p.blocking:return false
	return true
func _aimed_away(hero)->bool:
	return absf(wrapf(manual_angle(hero)-camera_aim,-PI,PI))>BREAK_AIM or absf(hero.game.camera_rig.pitch-camera_pitch)>BREAK_AIM
func point(hero,enemy,angle: float,max_distance: float,max_angle: float=ACQUIRE_ANGLE)->Vector3:
	if not is_instance_valid(enemy) or not enemy is Ninja or enemy.dead or enemy.hp<=0:return Vector3.INF
	if not hero.game.forest_enemy_visible(enemy):return Vector3.INF
	var origin: Vector3=hero.global_position
	var limit=max_distance+enemy.body_radius
	if enemy.has_method("combat_bounds"):
		var box: AABB=enemy.combat_bounds()
		if not box.position.is_finite() or not box.size.is_finite():return Vector3.INF
		var nearest=Vector2(clampf(origin.x,box.position.x,box.end.x),clampf(origin.z,box.position.z,box.end.z))
		if nearest.distance_squared_to(Vector2(origin.x,origin.z))>limit*limit or box.position.y>origin.y+2.5 or box.end.y<origin.y-2.5:return Vector3.INF
	else:
		var delta: Vector3=enemy.global_position-origin
		if not delta.is_finite() or Vector2(delta.x,delta.z).length_squared()>limit*limit:return Vector3.INF
	var contact: Vector3=AttackChain.contact_point(enemy,origin+Vector3.UP,enemy.global_position)
	if not contact.is_finite():return Vector3.INF
	var offset=contact-origin
	if absf(offset.y)>2.5:return Vector3.INF
	offset.y=0
	if offset.length_squared()<.0001 or offset.length()>limit:return Vector3.INF
	if absf(wrapf(atan2(offset.x,offset.z)-angle,-PI,PI))>max_angle:return Vector3.INF
	var ray=PhysicsRayQueryParameters3D.create(origin+Vector3.UP,contact,1)
	ray.exclude=[hero.get_rid()]
	if not hero.get_world_3d().direct_space_state.intersect_ray(ray).is_empty():return Vector3.INF
	return contact
func _breaking(hero,contact: Vector3)->bool:
	if not _available(hero) or _aimed_away(hero):return true
	var raw: Vector2=hero.smoke_move if hero.smoke_mode else Input.get_vector("move_left","move_right","move_forward","move_back")
	var move=Vector3(raw.x,0,raw.y).rotated(Vector3.UP,hero.game.camera_rig.yaw)
	var toward=contact-hero.global_position;toward.y=0
	return move.length_squared()>.01 and move.normalized().dot(toward.normalized())<-.2
func begin(hero,angle: float,weapon_reach: float):
	released_to_manual=false
	if not _available(hero):reset();return
	reach=minf(weapon_reach,5.5)
	var candidate=target()
	# A known enemy may drift slightly farther than a new acquisition.
	var contact=point(hero,candidate,angle,reach+.75,RETAIN_ANGLE)
	if remaining<=0 or contact==Vector3.INF:
		candidate=null;var best=INF
		for enemy in hero.game.enemies:
			var p=point(hero,enemy,angle,reach+.35)
			if p==Vector3.INF:continue
			var offset=p-hero.global_position
			var score=absf(wrapf(atan2(offset.x,offset.z)-angle,-PI,PI))+Vector2(offset.x,offset.z).length()*.12
			if score<best:best=score;candidate=enemy;contact=p
	if candidate==null:reset();return
	camera_aim=manual_angle(hero)
	camera_pitch=hero.game.camera_rig.pitch
	if _breaking(hero,contact):reset();return
	reference=weakref(candidate);remaining=MEMORY;active=true;step_left=STEP_DISTANCE
func tick(hero,delta: float):
	if reference==null:return
	if not active:remaining=maxf(0,remaining-delta)
	var p=point(hero,target(),manual_angle(hero),reach+.75,RETAIN_ANGLE)
	if remaining<=0 or p==Vector3.INF or _breaking(hero,p):
		var aimed_away=active and _aimed_away(hero)
		reset();released_to_manual=aimed_away
func steer(hero,angle: float,delta: float)->float:
	if not active:
		if released_to_manual:
			released_to_manual=false;return manual_angle(hero)
		return angle
	var manual=manual_angle(hero)
	var p=point(hero,target(),manual,reach+.75,RETAIN_ANGLE)
	if p==Vector3.INF or _breaking(hero,p):
		var aimed_away=_aimed_away(hero)
		reset();return manual if aimed_away else angle
	var offset=p-hero.global_position
	var correction=clampf(wrapf(atan2(offset.x,offset.z)-manual,-PI,PI),-MAX_CORRECTION,MAX_CORRECTION)
	return rotate_toward(angle,manual+correction,TURN_SPEED*delta)
func motion(hero,delta: float)->Vector3:
	if not active or step_left<=0 or delta<=0:return Vector3.ZERO
	var p=point(hero,target(),manual_angle(hero),reach+.75,RETAIN_ANGLE)
	if p==Vector3.INF or _breaking(hero,p):reset();return Vector3.ZERO
	var offset=p-hero.global_position;offset.y=0
	# Extra memory distance does not grant a farther approach or damage reach.
	if offset.length()>reach+.35+target().body_radius:return Vector3.ZERO
	var gap=maxf(0,offset.length()-reach+.05)
	var distance=minf(step_left,minf(gap,STEP_SPEED*delta))
	step_left-=distance
	return offset.normalized()*distance/delta
func contact():
	active=false;step_left=0.0;remaining=MEMORY if target()!=null else 0.0
