extends RefCounted
## Three independent swept shield faces, emitted by one confirmed frontal block.
const COUNT=3
const INTERVAL=.22
const TRAVEL=.18
const TAIL=.04
const DAMAGE=80.0
const WIDTH=6.0
const HEIGHT=6.6
const START=1.0
const DISTANCE=6.0
const THICKNESS=.8
const FACE=[Vector2(-6,2.3),Vector2(0,3.3),Vector2(6,2.3),Vector2(5.8,-1.4),Vector2(0,-3.3),Vector2(-5.8,-1.4)]
static func trigger(g)->bool:
	if g.player.get("guardCounter")!=null:return false
	var ticket=g.hero.attack_chain.make_ticket("rogue_knight_shield_counter")
	g.player.guardCounter={"time":0.0,"pos":g.player.pos,"angle":g.player.angle,"scale":g.hero.range_multiplier(),"ticket":ticket,"faces":[]}
	for i in COUNT:g.player.guardCounter.faces.append({"started":false,"last":START-THICKNESS,"hits":{}})
	return true
static func tick(g,delta: float):
	var counter=g.player.get("guardCounter")
	if counter==null:return
	counter.time+=maxf(0,delta)
	for i in COUNT:
		var age=float(counter.time)-i*INTERVAL
		if age<0:continue
		var face: Dictionary=counter.faces[i]
		if not face.started:
			face.started=true
			g.fx.knight_shield_pulse(counter.pos,counter.angle,counter.scale,i)
		var distance=START+DISTANCE*clampf(age/TRAVEL,0,1)
		var finish=distance+THICKNESS
		if finish>float(face.last)+.00001:
			sweep(g,counter,face,float(face.last),finish)
			face.last=finish
	if counter.time>=(COUNT-1)*INTERVAL+TRAVEL+TAIL:g.player.guardCounter=null
static func sweep(g,counter: Dictionary,face: Dictionary,from: float,to: float):
	var direction: Vector3=g.front(counter.angle);var side=Vector3(direction.z,0,-direction.x)
	var scale_: float=counter.scale
	var center: Vector3=counter.pos+Vector3.UP*3.3*scale_+direction*(from+to)*.5*scale_
	var prior_ticket: Dictionary=g._ticket;var prior_resolution: Dictionary=g._resolution_ticket
	var prior_projectile: bool=g._projectile_damage;var prior_origin: Vector3=g._damage_origin
	g.use_ticket(counter.ticket);g._resolution_ticket=counter.ticket
	g._projectile_damage=true;g._damage_origin=counter.pos+Vector3.UP*3.3*scale_
	var box=Transform3D(Basis(Vector3.UP,counter.angle).scaled(Vector3.ONE*scale_),counter.pos)*AABB(Vector3(-WIDTH,-.1,from),Vector3(WIDTH*2,HEIGHT+.1,to-from))
	for enemy in g.game.enemies:
		if not is_instance_valid(enemy) or enemy.dead or enemy.hp<=0:continue
		var uid=enemy.get_instance_id()
		if face.hits.has(uid):continue
		if g.game.has_method("forest_enemy_visible") and not g.game.forest_enemy_visible(enemy):continue
		# Reject remote bodies using cheap bounds before fitting any contact hull.
		if enemy.has_method("combat_bounds") and not box.intersects(enemy.combat_bounds()):continue
		var point=AttackChain.contact_point(enemy,center,enemy.global_position)
		var offset: Vector3=(point-counter.pos)/scale_
		var forward=offset.dot(direction)
		if forward<from or forward>to or absf(offset.dot(side))>WIDTH or offset.y<-.1 or offset.y>HEIGHT:continue
		if not Geometry2D.is_point_in_polygon(Vector2(offset.dot(side),offset.y-HEIGHT*.5),PackedVector2Array(FACE)):continue
		if not g.clear_line(g._damage_origin,point):continue
		var target: Dictionary=g._target_snapshot(enemy,center);target.pos=point
		g.hit(target,DAMAGE,"flintlock",true,direction,"","shield-counter")
		face.hits[uid]=true
	g._ticket=prior_ticket;g._resolution_ticket=prior_resolution
	g._projectile_damage=prior_projectile;g._damage_origin=prior_origin
