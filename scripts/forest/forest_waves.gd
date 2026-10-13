extends RefCounted
const COUNTS=[24,36,48,60,80]
var reference: WeakRef
var m:
	get:return reference.get_ref()
var pending=0
var spawn_clock=0.0
var sectors: Array=[]
var rng=RandomNumberGenerator.new()
func _init(model):reference=weakref(model)
func begin()->bool:
	if m.phase!="preparing" or m.wave>=5 or m.shrine().is_empty():return false
	m.wave+=1;m.phase="wave";pending=COUNTS[m.wave-1];spawn_clock=2.0
	rng.seed=m.seed_value+m.wave*7919;sectors.clear()
	var count=[1,1,2,2,3][m.wave-1]
	while sectors.size()<count:
		var sector=rng.randi_range(0,7)
		if not sectors.has(sector):sectors.append(sector)
	return true
func spawn_one():
	var angle=sectors[rng.randi_range(0,sectors.size()-1)]*TAU/8.0+rng.randf_range(-.09,.09)
	var direction=Vector2(sin(angle),cos(angle))
	direction*=39.0/maxf(absf(direction.x),absf(direction.y))
	var c=Vector2i(roundi(direction.x),roundi(direction.y))
	c=m.nearest_open(c,true)
	if not m.REGION.has_point(c) or m.visible_at(m.point(c)):return
	var id=m.next_id;m.next_id+=1
	m.enemies[id]={"id":id,"pos":m.point(c),"hp":75.0+m.wave*12,"max_hp":75.0+m.wave*12,"variant":id%4,"clock":0.0,"path":[],"nav":-1,"target":Vector2i.ZERO,"stun":0.0,"velocity":Vector3.ZERO,"attack":false}
	pending-=1
func tick(delta: float,hero: Vector3):
	spawn_clock-=delta
	if pending>0 and spawn_clock<=0 and m.enemies.size()<80:spawn_one();spawn_clock=.65
	for id in m.enemies.keys():
		var e: Dictionary=m.enemies[id]
		if e.hp<=0:m.enemies.erase(id);continue
		e.clock=maxf(0,e.clock-delta);e.stun=maxf(0,e.stun-delta);e.attack=false
		if e.stun>0:e.velocity=Vector3.ZERO;continue
		var target_worker=-1;var hero_close=hero.distance_squared_to(e.pos)<64 and hero.y<5
		var target_point=hero if hero_close else m.point(m.shrine_entry())
		for w in m.workers.values():
			if w.state not in ["wounded","garrison"] and e.pos.distance_squared_to(w.pos)<49:
				target_worker=w.id;target_point=w.pos;hero_close=false;break
		var destination=m.nearest_open(m.cell_of(target_point),true)
		if e.nav!=m.navigation_revision or e.target!=destination or e.path.is_empty():
			e.path=m.route(m.cell_of(e.pos),destination,true);e.nav=m.navigation_revision;e.target=destination
			if not e.path.is_empty():e.path.pop_front()
		var obstacle=-1
		if not e.path.is_empty() and m.occupancy.has(e.path[0]):obstacle=m.occupancy[e.path[0]]
		if obstacle>=0 and m.buildings.has(obstacle):
			var b: Dictionary=m.buildings[obstacle]
			if e.pos.distance_to(m.point(e.path[0]))<7:
				e.velocity=Vector3.ZERO;e.attack=true
				if e.clock<=0:m.damage_building(obstacle,18+m.wave*2);e.clock=1.2
				continue
		if e.pos.distance_to(target_point)<3.5:
			e.velocity=Vector3.ZERO;e.attack=true
			if e.clock<=0:
				e.clock=1.2
				if target_worker>=0:m.damage_worker(target_worker,25)
				elif hero_close:m.events.append({"kind":"hero_hit","amount":12.0,"from":e.pos})
				else:m.damage_building(1,15)
			continue
		if not e.path.is_empty():
			var old: Vector3=e.pos;e.pos=e.pos.move_toward(m.point(e.path[0]),delta*(7.0+m.wave*.3))
			e.velocity=(e.pos-old)/maxf(.001,delta)
			if e.pos.distance_to(m.point(e.path[0]))<.05:e.path.pop_front()
	if pending==0 and m.enemies.is_empty() and m.phase=="wave":
		m.gold+=100;m.phase="victory" if m.wave==5 else "preparing"
		m.workforce.recover();m.update_vision(hero);m.events.append({"kind":m.phase});m.revision+=1
