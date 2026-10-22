extends RefCounted
## Shadow Cut has one swept travel hit and a separate endpoint cut per victim.
const DURATION=.42/3.0
const SPEED=27.0*3.0
const FINISH_REACH=3.6
const FINISH_WIDTH=1.35
static func resolve(g,from: Vector3,to: Vector3):
	var a: Dictionary=g.player.dashAttack
	var scale_: float=a.effectScale
	var height=Vector3.UP*1.4*g.hero.growth_multiplier()
	var prior_ticket: Dictionary=g._ticket;var prior_resolution: Dictionary=g._resolution_ticket
	var prior_projectile: bool=g._projectile_damage;var prior_origin: Vector3=g._damage_origin
	g.use_ticket(a.ticket);g._resolution_ticket=a.ticket;g._projectile_damage=true
	damage_segment(g,a,from+height,to+height,a.width,a.hits)
	if from.distance_squared_to(to)>.0001:
		g.fx.streak(from+height,to+height,Color("bb9dff"),.16,.25)
	if g.player.roll<=0:
		# A fresh hit list lets a victim touching the route and final cut take both.
		damage_segment(g,a,to+height,to+height+g.front(a.angle)*FINISH_REACH*scale_,FINISH_WIDTH*scale_,[])
		g.fx.ninja_finisher(to,a.angle,FINISH_REACH,FINISH_WIDTH,scale_,height.y)
		g.player.dashAttack=null
	g._ticket=prior_ticket;g._resolution_ticket=prior_resolution
	g._projectile_damage=prior_projectile;g._damage_origin=prior_origin
static func damage_segment(g,a: Dictionary,from: Vector3,to: Vector3,width: float,hits: Array):
	for candidate in g._segment_targets(from,to,width,hits):
		var e: Dictionary=candidate.e
		# Attribute contact from the nearest point of this travelled segment, rather
		# than rejecting tall fitted bodies using their root or a distant endpoint.
		g._damage_origin=Geometry3D.get_closest_point_to_segment(e.pos,from,to)
		g.hit(e,a.damage,"flintlock",true,g.front(a.angle),"","dash-cut")
		hits.append(e.uid)
