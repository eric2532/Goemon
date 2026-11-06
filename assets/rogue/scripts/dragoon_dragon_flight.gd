extends RefCounted
## A released dragon uses the ordinary Rogue projectile lease and native queries.
const DURATION=3.0
const SPEED=42.0
const DAMAGE=192.0
const WIDTH=2.2
const SEEK=24.0
const DASH_TIME=.35
const VISUAL_SCALE=1.15

static func launch(g,t:Dictionary):
	var mesh=g.fx.create_projectile("dragon",Color.WHITE)
	g.add_projectile_mesh(mesh)
	mesh.position=g.player.pos+Vector3.UP*1.8
	mesh.rotation.y=g.player.angle;mesh.scale=Vector3.ONE*VISUAL_SCALE*t.rangeScale*g.skill_factor("size",t.ticket)
	mesh.get_child(0).material_override.set_shader_parameter("flow_time",0.0)
	g.projectiles.append({"mesh":mesh,"kind":"dragon","life":DURATION,"age":0.0,"dashLeft":0.0,"lastTarget":0,"origin":mesh.position,"vel":g.front(g.player.angle)*SPEED*g.skill_factor("travel_speed",t.ticket),"rangeScale":t.rangeScale,"width":WIDTH*t.rangeScale*g.skill_factor("hit_area",t.ticket),"damage":DAMAGE,"weapon":"flintlock","heavy":true,"pierce":true,"hits":[],"ticket":t.ticket,"visual_lease":mesh.get_meta("army_projectile_generation",-1)})
	g.fx.shake=maxf(g.fx.shake,.22)

static func advance(g,pr:Dictionary,delta:float):
	# Substeps keep long frames from skipping a dash's hit-list reset or cover.
	var remaining=minf(delta,pr.life)
	while remaining>.000001:
		var dt=minf(remaining,1.0/60)
		remaining-=dt;pr.age+=dt;pr.life=maxf(0,pr.life-dt);pr.dashLeft-=dt
		var before:Vector3=pr.mesh.position
		if pr.dashLeft<=.000001:
			pr.dashLeft=DASH_TIME;pr.hits.clear()
			var selected:Dictionary={};var best=INF
			for e in g._nearby_targets(before,SEEK*pr.rangeScale):
				if not g.clear_line(before,e.pos):continue
				var score=before.distance_squared_to(e.pos)+(SEEK*SEEK*pr.rangeScale*pr.rangeScale if e.uid==pr.lastTarget else 0.0)
				if score<best:best=score;selected=e
			var aim:Vector3=pr.origin+Vector3(sin(pr.age*5),0,cos(pr.age*5))*6*pr.rangeScale
			if not selected.is_empty():aim=selected.pos;pr.lastTarget=selected.uid
			var direction=(aim-before).normalized()
			if direction.length_squared()>.001:pr.vel=direction*SPEED*g.skill_factor("travel_speed",pr.ticket)
		var end:Vector3=before+pr.vel*dt
		var wall:Dictionary=g._terrain_hit(before,end,pr.width,false)
		if not wall.is_empty():end=wall.position
		var prior_ticket:Dictionary=g._resolution_ticket
		var prior_origin:Vector3=g._damage_origin
		var prior_projectile:bool=g._projectile_damage
		g._resolution_ticket=pr.ticket;g._damage_origin=before;g._projectile_damage=true
		for enemy in AttackChain.segment_enemy_candidates(g.game,before,end,pr.width):
			if not is_instance_valid(enemy) or enemy.dead or pr.hits.has(enemy.get_instance_id()):continue
			var contact=AttackChain.segment_contact(enemy,before,end,pr.width)
			if contact.is_empty() or not g.clear_line(before,contact.point):continue
			pr.hits.append(enemy.get_instance_id())
			var target=g._target_snapshot(enemy,contact.point)
			target.pos=contact.point;target.shared_contact_validated=true
			g.hit(target,pr.damage,pr.weapon,true,pr.vel.normalized(),"","dragon")
		g._resolution_ticket=prior_ticket;g._damage_origin=prior_origin;g._projectile_damage=prior_projectile
		pr.mesh.position=end
		if pr.vel.length_squared()>.001:pr.mesh.quaternion=Quaternion(Vector3.BACK,pr.vel.normalized())
		if not wall.is_empty():pr.vel=Vector3.ZERO
	if pr.life<.000001:pr.life=0.0
	pr.mesh.get_child(0).material_override.set_shader_parameter("flow_time",pr.age)
