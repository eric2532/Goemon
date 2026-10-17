extends RefCounted
const SPEED=36.0
var model_ref: WeakRef
var m:
	get:return model_ref.get_ref()
var navigation
var next_id=1
func _init(model,nav):model_ref=weakref(model);navigation=nav
func worker_point(w: Dictionary)->Vector3:return w.pos+Vector3.UP*(10.4 if w.state=="garrison" else 1.6+w.get("deck_height",0.0))
func launch(projectiles: Dictionary,e: Dictionary,kind: String,id: int,to: Vector3):
	var from: Vector3=e.pos+Vector3.UP*2.2
	var ignore=-1
	if kind=="worker" and m.workers.has(id) and m.workers[id].state=="garrison":ignore=m.workers[id].job
	var arrow={"id":next_id,"from":from,"to":to,"pos":from,"direction":from.direction_to(to),"left":from.distance_to(to)+1.0,"target_kind":kind,"target_id":id,"damage":20.0,"ignore_building":ignore}
	next_id+=1;projectiles[arrow.id]=arrow;m.events.append({"kind":"enemy_arrow","id":arrow.id,"from":from,"to":to})
func tick(projectiles: Dictionary,delta: float,hero: Vector3):
	for id in projectiles.keys():
		var a: Dictionary=projectiles[id];var distance=minf(a.left,SPEED*delta);var steps=maxi(1,ceili(distance/.35));var impacted=false
		for step in range(steps):
			var before: Vector3=a.pos;a.pos+=a.direction*distance/steps;a.left-=distance/steps
			if not navigation.line_clear(before,a.pos,-1 if a.ignore_building<0 else a.ignore_building):impacted=true;break
			# Endpoint sampling complements line_clear's interior samples for short segments.
			if not navigation.line_clear(before,a.pos+a.direction*.5,a.ignore_building):impacted=true;break
			if a.target_kind=="hero" and m.hero_targetable and hero.y-m.surface_height(hero.x,hero.z)<5:
				var contact=Geometry3D.get_closest_point_to_segment(hero+Vector3.UP*1.3,before,a.pos)
				if contact.distance_to(hero+Vector3.UP*1.3)<.85:
					m.events.append({"kind":"hero_hit","amount":a.damage,"from":a.from,"projectile":true});impacted=true;break
			for w in m.workers.values():
				if w.state!="wounded" and a.pos.distance_to(worker_point(w))<.85:m.damage_worker(w.id,a.damage);impacted=true;break
			if impacted:break
			if a.target_kind=="building" and m.buildings.has(a.target_id):
				var b: Dictionary=m.buildings[a.target_id]
				if a.pos.distance_to(navigation.building_point(b,a.pos)+Vector3.UP*1.6)<.8:m.damage_building(b.id,a.damage);impacted=true;break
		if impacted or a.left<=0:
			m.events.append({"kind":"enemy_arrow_impact","id":id,"point":a.pos});projectiles.erase(id)
