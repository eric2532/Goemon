extends RefCounted
const SoldierVisual=preload("res://scripts/forest/forest_thirstquencher_visual.gd")
const Profile=preload("res://scripts/forest/forest_structure_profile.gd")
const SPEED=36.0
const TARGET_CELL=8.0
var model_ref: WeakRef
var m:
	get:return model_ref.get_ref()
var navigation
var next_id=1
func _init(model,nav):model_ref=weakref(model);navigation=nav
func worker_point(w: Dictionary)->Vector3:return w.pos+Vector3.UP*(Profile.TOWER_DECK_HEIGHT+Profile.WORKER_CONTACT_HEIGHT if w.state=="garrison" else Profile.WORKER_CONTACT_HEIGHT+w.get("deck_height",0.0))
func launch(projectiles: Dictionary,e: Dictionary,kind: String,id: int,to: Vector3):
	var from: Vector3=e.pos+Vector3.UP*2.2
	var ignore=-1
	if kind=="worker" and m.workers.has(id) and m.workers[id].state=="garrison":ignore=m.workers[id].job
	var arrow={"id":next_id,"from":from,"to":to,"pos":from,"direction":from.direction_to(to),"left":from.distance_to(to)+1.0,"target_kind":kind,"target_id":id,"damage":m.waves.role_stats(e.variant).damage,"ignore_building":ignore}
	next_id+=1;projectiles[arrow.id]=arrow;m.events.append({"kind":"enemy_arrow","id":arrow.id,"from":from,"to":to})
func _target_grid(rows:Array)->Dictionary:
	var grid={}
	for index in rows.size():
		var point:Vector3=rows[index].pos
		var cell=Vector2i(floori(point.x/TARGET_CELL),floori(point.z/TARGET_CELL))
		if not grid.has(cell):grid[cell]=[]
		grid[cell].append(index)
	return grid
func _candidates(rows:Array,grid:Dictionary,from:Vector3,to:Vector3)->Array:
	# The original narrow tests use a .85m sphere around each target. Include
	# adjacent cells too: repeated float32 flight steps can cross the direct
	# endpoint's cell edge. Height and exact radius stay authoritative below.
	var minimum=from.min(to)-Vector3.ONE*.85
	var maximum=from.max(to)+Vector3.ONE*.85
	if not minimum.is_finite() or not maximum.is_finite():return rows
	var first=Vector2i(floori(minimum.x/TARGET_CELL),floori(minimum.z/TARGET_CELL))-Vector2i.ONE
	var last=Vector2i(floori(maximum.x/TARGET_CELL),floori(maximum.z/TARGET_CELL))+Vector2i.ONE
	if (last.x-first.x+1)*(last.y-first.y+1)>256:return rows
	var indices=[]
	for x in range(first.x,last.x+1):
		for z in range(first.y,last.y+1):indices.append_array(grid.get(Vector2i(x,z),[]))
	indices.sort() # Preserve the original dictionary insertion-order hit priority.
	var result=[]
	for index in indices:result.append(rows[index])
	return result
func tick(projectiles: Dictionary,delta: float,hero: Vector3):
	if projectiles.is_empty():return
	# This synchronous flight tick queues defender damage and never moves
	# targets. Keep live row references so wounded/retreating workers are still
	# revalidated after each prior hit, and rebuild positions on the next tick.
	var defenders=m.defenders.values();var workers=m.workers.values()
	var defender_grid=_target_grid(defenders);var worker_grid=_target_grid(workers)
	for id in projectiles.keys():
		var a: Dictionary=projectiles[id]
		if a.get("soldier_bullet",false):
			_tick_soldier(projectiles,a,delta,hero,defenders,defender_grid,workers,worker_grid);continue
		var distance=minf(a.left,SPEED*delta);var steps=maxi(1,ceili(distance/.35));var impacted=false
		var endpoint:Vector3=a.pos+a.direction*distance
		var nearby_defenders=_candidates(defenders,defender_grid,a.pos,endpoint)
		var nearby_workers=_candidates(workers,worker_grid,a.pos,endpoint)
		for step in range(steps):
			var before: Vector3=a.pos;a.pos+=a.direction*distance/steps;a.left-=distance/steps
			if not navigation.line_clear(before,a.pos,-1 if a.ignore_building<0 else a.ignore_building):impacted=true;break
			# Endpoint sampling complements line_clear's interior samples for short segments.
			if not navigation.line_clear(before,a.pos+a.direction*.5,a.ignore_building):impacted=true;break
			if a.target_kind=="hero" and m.hero_targetable and hero.y-m.surface_height(hero.x,hero.z)<5:
				var contact=Geometry3D.get_closest_point_to_segment(hero+Vector3.UP*1.3,before,a.pos)
				if contact.distance_to(hero+Vector3.UP*1.3)<.85:
					m.events.append({"kind":"hero_hit","amount":a.damage,"from":a.from,"projectile":true});impacted=true;break
			for d in nearby_defenders:
				if d.hp<=0 or not d.targetable:continue
				var contact=Geometry3D.get_closest_point_to_segment(d.pos+Vector3.UP*1.3,before,a.pos)
				if contact.distance_to(d.pos+Vector3.UP*1.3)<.85:
					m.events.append({"kind":"defender_hit","id":d.id,"amount":a.damage,"from":a.from,"projectile":true});impacted=true;break
			if impacted:break
			for w in nearby_workers:
				if m.worker_targetable(w.id) and a.pos.distance_to(worker_point(w))<.85:m.damage_worker(w.id,a.damage);impacted=true;break
			if impacted:break
			if a.target_kind=="building" and m.buildings.has(a.target_id):
				var b: Dictionary=m.buildings[a.target_id]
				if a.pos.distance_to(navigation.building_point(b,a.pos)+Vector3.UP*1.6)<.8:m.damage_building(b.id,a.damage);impacted=true;break
		if impacted or a.left<=0:
			m.events.append({"kind":"enemy_arrow_impact","id":id,"point":a.pos});projectiles.erase(id)

func launch_soldier(projectiles:Dictionary,e:Dictionary,kind:String,id:int,to:Vector3,damage:float=25.0):
	var from:Vector3=e.pos+Basis(Vector3.UP,float(e.facing))*SoldierVisual.source_point(Vector3(0,-80,-48))
	var direction=from.direction_to(to)
	var ignore=-1
	if kind=="worker" and m.workers.has(id) and m.workers[id].state=="garrison":ignore=m.workers[id].job
	var shot={"id":next_id,"from":from,"to":to,"pos":from,"direction":direction,"left":28.8,"age":0.0,"life":100.0/30.0,"speed":8.64,"soldier_bullet":true,"target_kind":kind,"target_id":id,"damage":damage,"ignore_building":ignore,"facing":e.facing}
	next_id+=1;projectiles[shot.id]=shot
	m.events.append({"kind":"enemy_arrow","id":shot.id,"from":from,"to":from+direction*28.8,"soldier_bullet":true,"direction":direction,"facing":e.facing})

func _tick_soldier(projectiles:Dictionary,a:Dictionary,delta:float,hero:Vector3,defenders:Array,defender_grid:Dictionary,workers:Array,worker_grid:Dictionary):
	var elapsed=minf(delta,maxf(0,float(a.life)-float(a.age)))
	var distance=8.64*elapsed
	var endpoint:Vector3=a.pos+a.direction*distance
	var tail_length=SoldierVisual.source_point(Vector3(0,0,32)).length()
	var nearby_defenders=_candidates(defenders,defender_grid,a.pos-a.direction*tail_length,endpoint)
	var nearby_workers=_candidates(workers,worker_grid,a.pos-a.direction*tail_length,endpoint)
	var steps=maxi(1,ceili(distance/.3));var impacted=false
	for step in steps:
		var before:Vector3=a.pos;a.pos+=a.direction*distance/steps;a.left=maxf(0,float(a.left)-distance/steps)
		# Native map sweeps stay authoritative, including cliff/floor and solid wall contact.
		if not navigation.line_clear(before,a.pos+a.direction*.5,int(a.get("ignore_building",-1))):
			if a.target_kind=="building" and m.buildings.has(a.target_id) and navigation.line_clear(before,a.pos+a.direction*.5,a.target_id):m.damage_building(a.target_id,a.damage)
			impacted=true;break
		var tail:Vector3=a.pos-a.direction*tail_length
		if m.hero_targetable and hero.y-m.surface_height(hero.x,hero.z)<5:
			if _soldier_body_contact(tail,a.pos,hero):
				m.events.append({"kind":"hero_hit","amount":a.damage,"from":a.from,"projectile":true});impacted=true;break
		for d in nearby_defenders:
			if d.hp<=0 or not d.targetable:continue
			if _soldier_body_contact(tail,a.pos,d.pos):
				m.events.append({"kind":"defender_hit","id":d.id,"amount":a.damage,"from":a.from,"projectile":true});impacted=true;break
		if impacted:break
		for w in nearby_workers:
			if not m.worker_targetable(w.id):continue
			if _soldier_body_contact(tail,a.pos,worker_point(w)-Vector3.UP*Profile.WORKER_CONTACT_HEIGHT):
				m.damage_worker(w.id,a.damage);impacted=true;break
		if impacted:break
		if a.target_kind=="building" and m.buildings.has(a.target_id):
			var b:Dictionary=m.buildings[a.target_id]
			var point:Vector3=navigation.building_point(b,a.pos)
			point.y=clampf(a.pos.y,m.center(b).y,m.center(b).y+Profile.height(b.kind))
			if point.distance_to(a.pos)<.35:m.damage_building(b.id,a.damage);impacted=true;break
	a.age=float(a.age)+elapsed
	if impacted or float(a.age)>=float(a.life):
		m.events.append({"kind":"enemy_arrow_impact","id":a.id,"point":a.pos,"soldier_bullet":true});projectiles.erase(a.id)

func _soldier_body_contact(from:Vector3,to:Vector3,foot:Vector3)->bool:
	var pair=Geometry3D.get_closest_points_between_segments(from,to,foot+Vector3.UP*.4,foot+Vector3.UP*1.8)
	return pair[0].distance_to(pair[1])<.576
