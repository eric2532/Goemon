extends RefCounted
var reference: WeakRef
var m:
	get:return reference.get_ref()
var held=false
var release_point=Vector3.ZERO
func _init(model):reference=weakref(model)
func recruit(free: bool=false)->bool:
	if m.phase!="preparing" or m.workers.size()>=24 or (not free and m.gold<50):return false
	if not free:m.gold-=50
	var id=m.next_id;m.next_id+=1
	var index=m.workers.size()
	var c=m.nearest_open(Vector2i(-3+index%6,4+index/6))
	m.workers[id]={"id":id,"pos":m.point(c),"hp":100.0,"max_hp":100.0,"state":"idle","job":-1,"saved_job":-1,"follow":false,"cargo":0,"timer":0.0,"safe":0.0,"path":[],"destination":Vector2i(-999,-999),"nav":-1}
	m.revision+=1;return true
func count_job(id: int)->int:
	var count=0
	for w in m.workers.values():
		if w.job==id and w.state!="wounded":count+=1
	return count
func jobs_near(p: Vector3)->Array:
	var jobs=[]
	for b in m.buildings.values():
		if m.center(b).distance_to(p)>30:continue
		var cap=0
		match b.kind:
			"mine":cap=3 if m.deposits.get(b.cell,0)>0 else 0
			"tower":cap=3
			"wall","gate":cap=2 if b.hp<b.max_hp and m.gold>0 else 0
		if count_job(b.id)<cap:jobs.append(b)
	return jobs
func _assign(w: Dictionary,b: Dictionary)->bool:
	var start=m.nearest_open(m.cell_of(w.pos))
	var destination=m.entry(b)
	if m.route(start,destination).is_empty():return false
	w.job=b.id;w.follow=false;w.path=[];w.destination=Vector2i(-999,-999)
	w.state="deliver" if w.cargo>0 else "travel";w.timer=0.0
	return true
func assign_nearest(w: Dictionary,p: Vector3):
	var best={};var distance=INF
	for b in jobs_near(p):
		var path=m.route(m.nearest_open(m.cell_of(w.pos)),m.entry(b))
		if not path.is_empty() and path.size()<distance:best=b;distance=path.size()
	w.follow=false;w.job=-1
	if best.is_empty():
		w.state="move";w.target=m.nearest_open(m.cell_of(p));w.path=[];w.destination=Vector2i(-999,-999)
	else:_assign(w,best)
func assign_idle(id: int)->int:
	if m.phase!="preparing" or not m.buildings.has(id):return 0
	var b: Dictionary=m.buildings[id];var assigned=0
	for w in m.workers.values():
		if w.state=="idle" and jobs_near(m.center(b)).has(b) and _assign(w,b):assigned+=1
	return assigned
func rally(value: bool,p: Vector3):
	if m.phase!="wave":held=false;return
	if value:
		held=true
		for w in m.workers.values():
			if w.state in ["wounded","retreat"] or w.follow:continue
			if Vector2(w.pos.x-p.x,w.pos.z-p.z).length()<=30:
				w.follow=true;w.job=-1;w.state="follow";w.path=[];w.destination=Vector2i(-999,-999)
	else:
		held=false;release_point=p
		for w in m.workers.values():
			if w.follow:assign_nearest(w,p)
func cancel_rally():
	held=false
	for w in m.workers.values():
		if w.follow:w.follow=false;w.state="idle";w.path=[]
func move(w: Dictionary,destination: Vector2i,delta: float,speed: float=8.0)->bool:
	if not m.REGION.has_point(destination):return false
	if w.destination!=destination or w.nav!=m.navigation_revision:
		w.destination=destination;w.nav=m.navigation_revision
		w.path=m.route(m.nearest_open(m.cell_of(w.pos)),destination)
		if not w.path.is_empty():w.path.pop_front()
	if w.path.is_empty():return w.pos.distance_to(m.point(destination))<4.5
	var remaining=delta*speed
	while remaining>0 and not w.path.is_empty():
		var target=m.point(w.path[0]);var distance=w.pos.distance_to(target)
		if distance<=remaining:w.pos=target;remaining-=distance;w.path.pop_front()
		else:w.pos=w.pos.move_toward(target,remaining);remaining=0
	return w.path.is_empty() and w.pos.distance_to(m.point(destination))<4.5
func damage(id: int,amount: float):
	if not m.workers.has(id) or m.phase!="wave":return
	var w: Dictionary=m.workers[id]
	if w.state=="wounded":return
	w.hp=maxf(0,w.hp-amount)
	if w.hp<=0:
		w.state="wounded";w.job=-1;w.follow=false;w.cargo=0;w.path=[]
		m.events.append({"kind":"wounded"});m.update_vision(m.hero_position)
	else:retreat(w)
func retreat(w: Dictionary):
	if w.state!="retreat":w.saved_job=w.job
	w.state="retreat";w.job=-1;w.follow=false;w.path=[];w.destination=Vector2i(-999,-999);w.safe=0.0
func recover():
	cancel_rally()
	for w in m.workers.values():
		if w.state=="wounded":
			w.hp=w.max_hp;w.pos=m.point(m.nearest_open(m.shrine_entry()+Vector2i(w.id%5-2,2)))
			w.state="idle";w.job=-1;w.saved_job=-1
func tick(delta: float,hero: Vector3):
	if held:rally(true,hero)
	for w in m.workers.values():
		if w.state=="wounded":continue
		var threat=false
		if w.state!="garrison":
			for e in m.enemies.values():
				if e.hp>0 and w.pos.distance_squared_to(e.pos)<144:threat=true;break
		if w.state=="garrison" and m.buildings.has(w.job) and m.buildings[w.job].hp<m.buildings[w.job].max_hp*.2:threat=true
		if threat and w.state!="retreat":retreat(w)
		if w.state=="retreat":
			move(w,m.shrine_entry()+Vector2i(0,2),delta,10)
			w.safe=0.0 if threat else w.safe+delta
			if w.safe>3:
				var saved: Dictionary=m.buildings.get(w.saved_job,{})
				if not saved.is_empty() and jobs_near(m.center(saved)).has(saved):_assign(w,saved)
				else:w.state="idle"
			continue
		if w.state=="follow":
			var offset=Vector2i(w.id%3-1,1+w.id%2)
			move(w,m.nearest_open(m.cell_of(hero)+offset),delta,13);continue
		if w.state=="move":
			if move(w,w.target,delta):w.state="idle"
			continue
		if w.state=="deliver":
			if move(w,m.shrine_entry(),delta):
				m.gold+=w.cargo;w.cargo=0;w.state="travel" if m.buildings.has(w.job) else "idle"
			continue
		if not m.buildings.has(w.job):
			w.job=-1;w.state="idle";continue
		var b: Dictionary=m.buildings[w.job]
		if w.state=="travel":
			if not move(w,m.entry(b),delta):continue
			w.state={"mine":"mine","tower":"garrison","wall":"repair","gate":"repair"}.get(b.kind,"idle")
			if w.state=="garrison":w.pos=m.center(b)+Vector3((w.id%3-1)*1.4,0,0)
		if w.state=="mine":
			w.timer+=delta
			if w.timer>=5:
				w.timer=0;var load_=mini(10,m.deposits.get(b.cell,0))
				if load_<=0:w.state="idle";w.job=-1
				else:m.deposits[b.cell]-=load_;w.cargo=load_;w.state="deliver"
		elif w.state=="repair":
			w.timer+=delta
			if w.timer>=1:
				w.timer=0
				if b.hp<b.max_hp and m.gold>0:m.gold-=1;b.hp=minf(b.max_hp,b.hp+10)
		elif w.state=="garrison":
			w.timer=maxf(0,w.timer-delta)
			if w.timer<=0:
				var target={};var nearest=48.0*48.0
				for e in m.enemies.values():
					var distance=w.pos.distance_squared_to(e.pos)
					if e.hp>0 and distance<nearest and m.visible_at(e.pos):target=e;nearest=distance
				if not target.is_empty():
					w.timer=1.4;m.damage_enemy(target.id,18)
					m.events.append({"kind":"arrow","from":w.pos+Vector3.UP*10,"to":target.pos+Vector3.UP})
