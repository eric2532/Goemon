extends RefCounted
## Shrine poses never execute Ninja's player-damage strike branch.
static func tick(enemy: Ninja,delta: float)->bool:
	var run=enemy.game.encounters
	if not run.shrine.handles(enemy) or enemy.stun>0 or enemy.impact_pause>0:return false
	var assignment: Dictionary=run.shrine.assignment(enemy)
	if not assignment.attacking and enemy.game.player.hp>0 and enemy.position.distance_squared_to(enemy.game.player.position)<225:return false
	if enemy.game.tuning.freeze_ai:return true
	enemy.pulse+=delta;enemy.animation_elapsed+=delta;enemy.recoil_age+=delta;enemy.cooldown-=delta
	var offset: Vector3=assignment.position-enemy.position;offset.y=0
	var close=offset.length_squared()<(1.1*1.1 if assignment.attacking else .6*.6)
	var pose: StringName=assignment.pose if close and assignment.attacking else &"march"
	if enemy.state!=pose:enemy.timer=.3 if pose==&"strike" else 0
	else:enemy.timer=maxf(0,enemy.timer-delta)
	enemy.state=pose;enemy.attack_hit=true
	var speed=0.0 if close else minf(run.defense_speed(enemy)*enemy.defense_slow_multiplier(),offset.length()/.15)
	var direction=offset.normalized()
	enemy.velocity.x=direction.x*speed;enemy.velocity.z=direction.z*speed
	if not enemy.grounded_cached and not enemy.is_on_floor():enemy.velocity.y-=28*delta
	enemy.walk_motion(delta)
	var facing: Vector3=enemy.game.world.base_position-enemy.position if close else direction
	facing.y=0;facing=facing.normalized();enemy.attack_dir=facing
	enemy.model.rotation.y=atan2(-facing.x,-facing.z);enemy.update_animation(false)
	return true
