extends RefCounted
## Gate assignment consumes ordinary hero interception and its damage branch.
static func tick(enemy: Ninja,delta: float)->bool:
	var run=enemy.game.encounters
	if not run.gate_blocking(enemy):return false
	if not run.gate.handles(enemy):run._admit_gate_actor(enemy)
	var assignment: Dictionary=run.gate.assignment(enemy)
	enemy.attack_hit=true
	if assignment.is_empty():enemy.velocity=Vector3.ZERO;return true
	if enemy.game.tuning.freeze_ai:return true
	if enemy.impact_pause>0:
		enemy.impact_pause=maxf(0,enemy.impact_pause-delta);return true
	if enemy.stun>0:
		enemy.stun=maxf(0,enemy.stun-delta)
		enemy.velocity.x=move_toward(enemy.velocity.x,0,delta*16)
		enemy.velocity.z=move_toward(enemy.velocity.z,0,delta*16)
		if not enemy.grounded_cached and not enemy.is_on_floor():enemy.velocity.y-=28*delta
		enemy.walk_clock=0;enemy.walk_motion(delta);enemy.update_animation(false);return true
	enemy.pulse+=delta;enemy.animation_elapsed+=delta;enemy.recoil_age+=delta;enemy.cooldown-=delta
	var offset: Vector3=assignment.position-enemy.position;offset.y=0
	var close=offset.length_squared()<(1.1*1.1 if assignment.attacking else .6*.6)
	var pose: StringName=assignment.pose if close and assignment.attacking else &"march"
	if enemy.state!=pose:enemy.timer=.3 if pose==&"strike" else 0
	else:enemy.timer=maxf(0,enemy.timer-delta)
	enemy.state=pose
	# Invalidate a previously cached hero-facing segment when targets change.
	if enemy.get_meta("gate_motion_target",Vector3.INF)!=assignment.position:
		enemy.set_meta("gate_motion_target",assignment.position);enemy.walk_clock=0;enemy.walk_phase_pending=true
	var speed=0.0 if close else minf(run.defense_speed(enemy)*enemy.defense_slow_multiplier(),offset.length()/maxf(.15,delta))
	var direction=offset.normalized()
	enemy.velocity.x=direction.x*speed;enemy.velocity.z=direction.z*speed
	if not enemy.grounded_cached and not enemy.is_on_floor():enemy.velocity.y-=28*delta
	enemy.walk_motion(delta)
	var facing: Vector3=run.gate_position-enemy.position if close else direction
	facing.y=0;facing=facing.normalized();enemy.attack_dir=facing
	enemy.model.rotation.y=atan2(-facing.x,-facing.z);enemy.update_animation(false)
	return true
