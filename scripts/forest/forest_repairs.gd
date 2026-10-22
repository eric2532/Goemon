extends RefCounted
## Repairs use the accessible edge of a structure, not its decorative entrance.
const INTERVAL=.25
const HEALTH_PER_RYO=10.0
var reference: WeakRef
var m:
	get:return reference.get_ref()
func _init(model):reference=weakref(model)
static func repairable(b: Dictionary)->bool:
	return b.get("kind","") in ["shrine","gate","barracks"]
func finish_breaches():
	for b in m.buildings.values():
		if b.get("breached",false) and b.hp>=b.max_hp:m.close_repaired_gate(b.id)
func faces(b: Dictionary)->Array:
	if b.kind=="barracks":return [m.entry(b)]
	var result=[]
	var size_: Vector2i=m.dimensions(b.kind,b.rotation,b.get("span",0))
	for x in range(size_.x):
		result.append(b.cell+Vector2i(x,-1))
		result.append(b.cell+Vector2i(x,size_.y))
	for y in range(size_.y):
		result.append(b.cell+Vector2i(-1,y))
		result.append(b.cell+Vector2i(size_.x,y))
	return result
func safe_face(cell_: Vector2i)->bool:
	return m.navigation_region.has_point(cell_) and not m.allied_grid.is_point_solid(cell_) and (m.phase!="wave" or not m.workforce.threatened(m.point(cell_)))
func destination(w: Dictionary,b: Dictionary)->Dictionary:
	var origin: Vector2i=m.workforce.navigation_origin(w)
	var candidates=faces(b)
	# Short routes keep workers on their current wall face; ties favor home.
	candidates.sort_custom(func(a,b_):
		var da=absi(a.x-origin.x)+absi(a.y-origin.y)
		var db=absi(b_.x-origin.x)+absi(b_.y-origin.y)
		if da!=db:return da<db
		return a.distance_squared_to(m.shrine_entry())<b_.distance_squared_to(m.shrine_entry()))
	var best={};var distance=INF
	for cell_ in candidates:
		if absi(cell_.x-origin.x)+absi(cell_.y-origin.y)+1>distance:break
		if not safe_face(cell_):continue
		var path: Array=m.route(origin,cell_)
		if not path.is_empty() and path.size()<distance:
			distance=path.size();best={"cell":cell_,"distance":distance}
	return best
func job_is_safe(b: Dictionary)->bool:
	for cell_ in faces(b):
		if safe_face(cell_):return true
	return false
func remember(w: Dictionary,b: Dictionary):
	w.repair_previous_job=w.job
	w.repair_job=b.id
func forget(w: Dictionary):
	w.erase("repair_previous_job");w.erase("repair_job");w.erase("repair_cell")
func restore(w: Dictionary):
	var previous=int(w.get("repair_previous_job",-1))
	forget(w)
	var b: Dictionary=m.buildings.get(previous,{})
	if not b.is_empty() and m.workforce.job_is_safe(b):m.workforce._assign(w,b)
func dispatch():
	if m.gold<1:return
	for b in m.buildings.values():
		if not repairable(b) or m.workforce.capacity(b)<=0:continue
		var slots=m.workforce.capacity(b)-m.workforce.count_job(b.id)
		if slots<=0:continue
		var candidates=[]
		for w in m.workers.values():
			if w.follow or w.state in ["wounded","retreat","follow","move"] or w.job==b.id:continue
			var current: Dictionary=m.buildings.get(w.job,{})
			# Keep one defender on each occupied tower when every worker is busy.
			var kind: String=current.get("kind","")
			if w.job!=-1 and kind not in ["mine","tower"]:continue
			if kind=="tower" and m.workforce.count_job(w.job)<=1:continue
			var target=destination(w,b)
			if target.is_empty():continue
			candidates.append({"worker":w,"priority":0 if w.job==-1 else (2 if kind=="tower" else 1),"distance":target.distance})
		candidates.sort_custom(func(a,b_):
			if a.priority!=b_.priority:return a.priority<b_.priority
			if a.distance!=b_.distance:return a.distance<b_.distance
			return a.worker.id<b_.worker.id)
		for candidate in candidates:
			if slots<=0:break
			if candidate.priority==2 and m.workforce.count_job(candidate.worker.job)<=1:continue
			if m.workforce._assign(candidate.worker,b,true):slots-=1
func tick(w: Dictionary,b: Dictionary,delta: float):
	if not repairable(b) or (b.hp<=0 and not b.get("breached",false)) or b.hp>=b.max_hp or m.gold<1:
		m.workforce.release_job(w);return
	w.timer+=delta
	var pulses=mini(int(floor((w.timer+.000001)/INTERVAL)),mini(int(m.gold),ceili((b.max_hp-b.hp)/HEALTH_PER_RYO)))
	if pulses>0:
		var restored=minf(pulses*HEALTH_PER_RYO,b.max_hp-b.hp)
		m.gold-=pulses;b.hp+=restored;w.timer=maxf(0,w.timer-pulses*INTERVAL)
		if b.get("breached",false) and b.hp>=b.max_hp:m.close_repaired_gate(b.id)
	if b.hp>=b.max_hp or m.gold<1:m.workforce.release_job(w)

func wall_between(a: Vector3,b: Vector3)->bool:
	# Threats are local (12 m), so only a few occupancy samples are needed.
	var steps=maxi(1,ceili(a.distance_to(b)/(m.CELL*.2)))
	for i in range(1,steps+1):
		var sample=a.lerp(b,float(i)/steps)
		var structure: Dictionary=m.buildings.get(m.occupancy.get(m.cell_of(sample),-1),{})
		if structure.get("kind","") in ["wall","gate"] and structure.hp>0 and not structure.get("breached",false):return true
	return false
