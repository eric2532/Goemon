extends RefCounted
const Roles=preload("res://scripts/forest/forest_enemy_roles.gd")
const Profile=preload("res://scripts/forest/forest_structure_profile.gd")
const Contact=preload("res://scripts/forest/forest_enemy_contact.gd")
const Repairs=preload("res://scripts/forest/forest_repairs.gd")
var reference: WeakRef
var repairs
var m:
	get:return reference.get_ref()
var held=false
var release_point=Vector3.ZERO
var assignment_clock=0.0
const ARROW_SPEED=70.0
# Native 50/100/125 splash rings at 0.06 metres per Warcraft unit.
const CANNON_RADII=[3.0,6.0,7.5]
const CANNON_SPEED=42.0
const CANNON_DAMAGE=100.5/18.0
const CANNON_INTERVAL=2.5/1.4
var arrows: Dictionary={}
var tower_candidate_work=0
var _tower_capture_active=false
var _tower_capture_ready=false
var _tower_rows:Array=[]
var _tower_handles:Dictionary={}
var _tower_fallback:Array=[]
func _init(model):
	reference=weakref(model);repairs=Repairs.new(model)
func recruit(free: bool=false)->bool:
	if m.phase!="preparing" and not (free and m.phase=="wave"):return false
	if not free and (m.gold<50 or not m.can_recruit(1)):return false
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
func capacity(b: Dictionary)->int:
	match b.kind:
		"mine":return 3 if m.deposits.get(b.cell,0)>0 else 0
		"shrine","gate","barracks":return 2 if (b.hp>0 or b.get("breached",false)) and b.hp<b.max_hp and m.gold>=1 else 0
	return 0
func jobs_near(p: Vector3)->Array:
	var jobs=[]
	for b in m.buildings.values():
		if m.center(b).distance_to(p)>30:continue
		if count_job(b.id)<capacity(b):jobs.append(b)
	return jobs
func _assign(w: Dictionary,b: Dictionary,temporary_repair: bool=false)->bool:
	if w.state=="wounded" or capacity(b)<=0:return false
	if w.job!=b.id and count_job(b.id)>=capacity(b):return false
	var start=navigation_origin(w)
	var destination=m.entry(b)
	if Repairs.repairable(b):
		var target=repairs.destination(w,b)
		if target.is_empty():return false
		destination=target.cell
	if m.route(start,destination).is_empty():return false
	leave_shelter(w);leave_tower(w)
	if temporary_repair:repairs.remember(w,b)
	elif w.get("repair_job",-1)!=b.id:repairs.forget(w)
	if Repairs.repairable(b):w.repair_cell=destination
	w.job=b.id;w.follow=false;w.path=[];w.destination=Vector2i(-999,-999)
	w.state="deliver" if w.cargo>0 else "travel";w.timer=0.0;w.job_nav=m.navigation_revision
	return true
func release_job(w: Dictionary):
	leave_shelter(w);leave_tower(w)
	w.job=-1;w.state="deliver" if w.cargo>0 else "idle"
	w.path=[];w.destination=Vector2i(-999,-999);w.timer=0.0
	repairs.restore(w)
func job_is_safe(b: Dictionary)->bool:
	if Repairs.repairable(b):return repairs.job_is_safe(b)
	if m.phase!="wave":return true
	if b.kind in ["tower","cannon_tower"] and b.hp<b.max_hp*.2:return false
	return not threatened(m.point(m.entry(b))) and not threatened(m.center(b))
func automatic_job(w: Dictionary)->Dictionary:
	var best={};var best_priority=99;var distance=INF
	for b in m.buildings.values():
		if count_job(b.id)>=capacity(b):continue
		if not job_is_safe(b):continue
		var priority=0 if b.kind in ["shrine","wall","gate","barracks"] else (1 if b.kind=="mine" else 2)
		if priority>best_priority:continue
		var length=INF
		if Repairs.repairable(b):
			var target=repairs.destination(w,b)
			if not target.is_empty():length=target.distance
		else:
			var path=m.route(navigation_origin(w),m.entry(b))
			if not path.is_empty():length=path.size()
		if length<INF and (priority<best_priority or length<distance):
			best=b;best_priority=priority;distance=length
	return best
func auto_assign():
	# Keep useful reservations stable; only reconsider idle or obsolete work.
	for w in m.workers.values():
		if w.state in ["wounded","retreat","follow","move"]:continue
		if w.has("repair_job") and w.job!=w.repair_job:release_job(w)
		if w.job!=-1:
			var b: Dictionary=m.buildings.get(w.job,{})
			if b.is_empty() or capacity(b)<=0:release_job(w)
			elif Repairs.repairable(b) and not w.has("sheltered_building"):
				var destination: Vector2i=w.get("repair_cell",Vector2i(-999,-999))
				if w.get("job_nav",-1)!=m.navigation_revision or not repairs.safe_face(destination):
					var target=repairs.destination(w,b)
					if target.is_empty():release_job(w)
					else:
						w.repair_cell=target.cell;w.job_nav=m.navigation_revision
						w.state="deliver" if w.cargo>0 else "travel";w.timer=0.0
			elif w.get("job_nav",-1)!=m.navigation_revision:
				if m.route(navigation_origin(w),m.entry(b)).is_empty():release_job(w)
				else:w.job_nav=m.navigation_revision
		if w.job==-1:
			if w.cargo>0:w.state="deliver"
			elif w.state!="idle":w.state="idle"
	repairs.dispatch()
	for w in m.workers.values():
		if w.state!="idle" or w.job!=-1:continue
		var b=automatic_job(w)
		if not b.is_empty():_assign(w,b)
func prepare_tick(delta: float):
	# Repairs and deliveries continue; mining and tower attacks are wave-only.
	tick(delta,m.hero_position)
func nearest_job(w: Dictionary,p: Vector3,reservations: Dictionary={})->Dictionary:
	var best={};var distance=INF
	for b in jobs_near(p):
		if count_job(b.id)+reservations.get(b.id,0)>=capacity(b):continue
		var path=m.route(navigation_origin(w),m.entry(b))
		if not path.is_empty() and path.size()<distance:best=b;distance=path.size()
	return best
func preview_jobs(p: Vector3)->Dictionary:
	var result={"mine":0,"tower":0,"repair":0,"idle":0};var reservations={}
	for w in m.workers.values():
		if not w.follow:continue
		var b=nearest_job(w,p,reservations)
		if b.is_empty():result.idle+=1
		else:
			reservations[b.id]=reservations.get(b.id,0)+1
			result["repair" if Repairs.repairable(b) else "tower" if b.kind=="cannon_tower" else b.kind]+=1
	return result
func assign_nearest(w: Dictionary,p: Vector3):
	var best=nearest_job(w,p)
	repairs.forget(w)
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
func assign_workers(id: int)->int:
	if m.phase!="preparing" or not m.buildings.has(id):return 0
	var b: Dictionary=m.buildings[id];var candidates=[];var assigned=0
	if count_job(id)>=capacity(b):return 0
	for w in m.workers.values():
		if w.job==id or w.follow or w.state in ["wounded","retreat","follow","move"]:continue
		var path=m.route(navigation_origin(w),m.entry(b))
		if not path.is_empty():candidates.append({"worker":w,"priority":0 if w.state=="idle" else 1,"distance":path.size()})
	candidates.sort_custom(func(a,b_):
		if a.priority!=b_.priority:return a.priority<b_.priority
		if a.distance!=b_.distance:return a.distance<b_.distance
		return a.worker.id<b_.worker.id)
	for candidate in candidates:
		if count_job(id)>=capacity(b):break
		if _assign(candidate.worker,b):assigned+=1
	return assigned
func rally(value: bool,p: Vector3):
	if m.phase!="wave":held=false;return
	if value:
		held=true
		for w in m.workers.values():
			if w.state in ["wounded","retreat"] or w.follow:continue
			if Vector2(w.pos.x-p.x,w.pos.z-p.z).length()<=30:
				leave_shelter(w);leave_tower(w)
				repairs.forget(w)
				w.follow=true;w.job=-1;w.state="follow";w.path=[];w.destination=Vector2i(-999,-999)
	else:
		held=false;release_point=p
		for w in m.workers.values():
			if w.follow:assign_nearest(w,p)
func cancel_rally():
	held=false
	for w in m.workers.values():
		if w.follow:w.follow=false;w.state="idle";w.path=[]
func navigation_origin(w: Dictionary)->Vector2i:
	if w.has("sheltered_building") and m.buildings.has(w.sheltered_building):return m.entry(m.buildings[w.sheltered_building])
	if w.has("exit_point"):return m.cell_of(w.exit_point)
	if w.state=="garrison" and m.buildings.has(w.job):return m.entry(m.buildings[w.job])
	return m.nearest_open(m.cell_of(w.pos))
func leave_shelter(w:Dictionary):
	if not w.has("sheltered_building"):return
	var destination:Vector3=w.get("shelter_exit",w.pos)
	var cell=m.nearest_open(m.cell_of(destination))
	if cell.x!=-999:w.pos=m.point(cell)
	w.erase("sheltered_building");w.erase("shelter_exit")
	w.path=[];w.destination=Vector2i(-999,-999)
func leave_tower(w: Dictionary):
	if w.state!="garrison" or not m.buildings.has(w.job):return
	w.exit_point=m.point(m.entry(m.buildings[w.job]));w.exit_start=w.pos;w.deck_height=Profile.TOWER_DECK_HEIGHT
	w.path=[];w.destination=Vector2i(-999,-999)
func tick_exit(w: Dictionary,delta: float):
	w.pos=w.pos.move_toward(w.exit_point,delta*8.0)
	var remaining=w.pos.distance_to(w.exit_point)
	w.deck_height=Profile.TOWER_DECK_HEIGHT*remaining/maxf(.01,w.exit_start.distance_to(w.exit_point))
	if remaining<.01:
		w.pos=w.exit_point;w.erase("exit_point");w.deck_height=0.0;w.destination=Vector2i(-999,-999)
func move(w: Dictionary,destination: Vector2i,delta: float,speed: float=8.0)->bool:
	if not m.navigation_region.has_point(destination):return false
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
	if not m.worker_targetable(id):return
	w.hp=maxf(0,w.hp-amount)
	if w.hp<=0:
		repairs.forget(w)
		w.state="wounded";w.job=-1;w.follow=false;w.cargo=0;w.path=[];w.timer=0.0
		m.events.append({"kind":"wounded"});m.update_vision(m.hero_position)
	else:retreat(w)
func retreat(w: Dictionary):
	leave_shelter(w);leave_tower(w)
	if w.state!="retreat":w.saved_job=w.job
	w.state="retreat";w.job=-1;w.follow=false;w.path=[];w.destination=Vector2i(-999,-999);w.safe=0.0
func recover():
	arrows.clear()
	cancel_rally()
	for w in m.workers.values():
		if w.state=="wounded":revive(w)
func revive(w:Dictionary):
	w.hp=w.max_hp;w.pos=m.point(m.nearest_open(m.shrine_entry()+Vector2i(w.id%5-2,2)))
	w.state="idle";w.job=-1;w.saved_job=-1;w.timer=0.0;w.safe=0.0;w.follow=false;w.cargo=0
	w.path=[];w.destination=Vector2i(-999,-999);w.nav=-1
	w.erase("exit_point");w.erase("sheltered_building");w.erase("shelter_exit");w.deck_height=0.0
	repairs.forget(w)
func threatened(p: Vector3)->bool:
	if is_instance_valid(m.army_runtime):
		for handle in m.army_runtime.query_aabb(AABB(p-Vector3.ONE*12,Vector3.ONE*24),0):
			var state:Dictionary=m.army_runtime.unit_state(handle)
			if state.is_empty():continue
			var enemy:Dictionary=m.enemies.get(state.logical_id,{})
			if not enemy.is_empty() and enemy.hp>0 and p.distance_squared_to(state.position)<144 and not repairs.wall_between(p,state.position):return true
		return false
	for e in m.enemies.values():
		if e.hp>0 and p.distance_squared_to(e.pos)<144 and not repairs.wall_between(p,e.pos):return true
	return false
func _capture_tower_candidates(runtime):
	_tower_capture_ready=true;_tower_rows=m.enemies.values()
	var index:Dictionary=runtime.index_enemy_rows(_tower_rows)
	assert(index.valid,"Invalid tower model snapshot")
	_tower_handles=index.handles;_tower_fallback=Array(index.fallback)
	tower_candidate_work+=_tower_rows.size()
func tower_candidates(point:Vector3)->Array:
	var model=m;var runtime=model.army_runtime
	if not is_instance_valid(runtime):return model.enemies.values()
	if not _tower_capture_active or not _tower_capture_ready:_capture_tower_candidates(runtime)
	# Share source order and pending/articulated fallback rows across this tick.
	# Each tower queries only its own conservative original hurt-surface range.
	var soldier=preload("res://scripts/forest/forest_thirstquencher_visual.gd")
	var reach=Vector3.ONE*(48.0+soldier.hurt_bounds().size.length()*model.balance.enemy_size_mult)
	var indices:Array=_tower_fallback.duplicate()
	var nearby:PackedInt64Array=runtime.query_aabb(AABB(point-reach,reach*2),0)
	var refresh=nearby.duplicate()
	for index in _tower_fallback:
		var handle:int=runtime.handles.get(_tower_rows[index].id,0)
		if handle!=0:refresh.append(handle)
	if not refresh.is_empty():model.sync_enemy_records(refresh)
	for handle in nearby:
		if _tower_handles.has(handle):indices.append(_tower_handles[handle])
	indices.sort()
	var result:Array=[]
	for index in indices:result.append(_tower_rows[index])
	return result
func tick(delta: float,hero: Vector3):
	_tower_capture_active=true;_tower_capture_ready=false
	repairs.finish_breaches()
	if m.phase=="wave":tick_arrows(delta)
	assignment_clock-=delta
	if assignment_clock<=0:auto_assign();assignment_clock=.5
	if held:rally(true,hero)
	for w in m.workers.values():
		if w.state=="wounded":continue
		var threat=false
		if m.phase=="wave" and w.state!="garrison" and not w.has("sheltered_building"):
			threat=threatened(w.pos)
		if m.phase=="wave" and w.state=="garrison" and m.buildings.has(w.job) and m.buildings[w.job].hp<m.buildings[w.job].max_hp*.2:threat=true
		if threat and w.state!="retreat":retreat(w)
		if w.has("exit_point"):
			tick_exit(w,delta);continue
		if w.state=="retreat":
			move(w,m.shrine_entry()+Vector2i(0,2),delta,10)
			w.safe=0.0 if threat else w.safe+delta
			if w.safe>3:
				var saved: Dictionary=m.buildings.get(w.saved_job,{})
				if saved.is_empty():w.state="idle"
				elif job_is_safe(saved):
					if not _assign(w,saved):w.state="idle"
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
			w.job=-1;w.state="deliver" if w.cargo>0 else "idle";continue
		var b: Dictionary=m.buildings[w.job]
		if w.state=="travel":
			var destination: Vector2i=w.get("repair_cell",m.entry(b)) if Repairs.repairable(b) else m.entry(b)
			if not move(w,destination,delta):continue
			w.state={"mine":"mine","tower":"garrison","cannon_tower":"garrison","shrine":"repair","wall":"repair","gate":"repair","barracks":"repair"}.get(b.kind,"idle")
			if b.kind=="barracks":
				w.sheltered_building=b.id;w.shelter_exit=m.point(m.entry(b));w.pos=m.center(b)
			if w.state=="garrison":w.pos=m.center(b)+Vector3((w.id%3-1)*1.4,0,0)
		if w.state=="repair":
			repairs.tick(w,b,delta);continue
		if m.phase!="wave":continue
		if w.state=="mine":
			w.timer+=delta
			if w.timer>=5:
				w.timer=0;var load_=mini(10,m.deposits.get(b.cell,0))
				if load_<=0:w.state="idle";w.job=-1
				else:m.deposits[b.cell]-=load_;w.cargo=load_;w.state="deliver"

	if m.phase=="wave":tick_towers(delta)

	_tower_capture_active=false;_tower_capture_ready=false;_tower_rows.clear();_tower_handles.clear();_tower_fallback.clear()

func tick_towers(delta:float):
	# Share fitted contacts and the native snapshot across all automatic towers.
	var target_bounds:Dictionary={}
	for b in m.buildings.values():
		if b.kind not in ["tower","cannon_tower"] or b.hp<=0:continue
		b.clock=maxf(0,b.clock-delta)
		if b.clock>0:continue
		var point:Vector3=m.center(b)
		var target={};var nearest=48.0*48.0
		for e in tower_candidates(point):
			if e.hp<=0:continue
			if b.kind=="cannon_tower" and e.pos.y>m.surface_height(e.pos.x,e.pos.z)+3.0:continue
			if not target_bounds.has(e.id):target_bounds[e.id]=Contact.bounds(e)
			var box:AABB=target_bounds[e.id]
			if point.distance_squared_to(point.clamp(box.position,box.end))>=nearest:continue
			var aim:Vector3=e.pos-point
			var muzzle:Vector3=point+Vector3.UP*Profile.TOWER_DECK_HEIGHT+Basis(Vector3.UP,atan2(aim.x,aim.z))*Profile.TOWER_MUZZLE_OFFSET
			var hurt=Roles.hurt_point(e,muzzle)
			var distance=point.distance_squared_to(hurt)
			if distance<nearest and (m.visible_at(e.pos) or m.visible_at(hurt)):target=e;nearest=distance
		if target.is_empty():continue
		b.clock=attack_interval(b)
		var aim:Vector3=target.pos-point
		var facing=atan2(aim.x,aim.z)
		for slot in m.balance.tower_workers:
			var from:Vector3=point+Vector3((slot%3-1)*1.4,0,0)+Vector3.UP*Profile.TOWER_DECK_HEIGHT+Basis(Vector3.UP,facing)*Profile.TOWER_MUZZLE_OFFSET
			var id=m.next_id;m.next_id+=1
			var shot={"id":id,"from":from,"pos":from,"target":target.id,"age":0.0}
			var to=Roles.hurt_point(target,from)
			if b.kind=="cannon_tower":
				from=point+Vector3.UP*18.0+Basis(Vector3.UP,facing)*Vector3(0,0,6.5)
				to=Roles.hurt_point(target,from)
				shot.merge({"cannon":true,"from":from,"pos":from,"to":to,"duration":maxf(.1,from.distance_to(to)/CANNON_SPEED),"damage":m.balance.tower_damage*CANNON_DAMAGE},true)
			arrows[id]=shot
			m.events.append({"kind":"arrow","id":id,"from":from,"to":to,"cannon":b.kind=="cannon_tower"})

func tick_arrows(delta: float):
	m.sync_enemy_targets(arrows.values().map(func(arrow):return arrow.target))
	for id in arrows.keys():
		var arrow: Dictionary=arrows[id]
		arrow.age+=delta
		if arrow.get("cannon",false):
			tick_cannon(arrow);continue
		var target: Dictionary=m.enemies.get(arrow.target,{})
		if target.is_empty() or target.hp<=0 or arrow.age>1.5:
			arrows.erase(id);continue
		var to: Vector3=Roles.hurt_point(target,arrow.pos)
		var direction: Vector3=(to-arrow.pos).normalized()
		if arrow.pos.distance_to(to)<=ARROW_SPEED*delta:
			m.damage_enemy(target.id,m.balance.tower_damage)
			target.tower_direction=direction
			m.events.append({"kind":"arrow_impact","id":id,"to":to,"direction":direction})
			arrows.erase(id)
		else:arrow.pos=arrow.pos.move_toward(to,ARROW_SPEED*delta)

func attack_interval(building:Dictionary)->float:
	return (CANNON_INTERVAL if building.kind=="cannon_tower" else 1.0)/m.balance.tower_attack_speed

func tick_cannon(shot:Dictionary):
	var t=clampf(shot.age/shot.duration,0,1)
	var next:Vector3=shot.from.lerp(shot.to,t)+Vector3.UP*(4.0*t*(1.0-t)*shot.from.distance_to(shot.to)*.35)
	var game=m.army_runtime.game_ref.get_ref() if is_instance_valid(m.army_runtime) and m.army_runtime.game_ref!=null else null
	var wall:Dictionary=AttackChain.world_ray(game.world,shot.pos,next) if is_instance_valid(game) else {}
	var direction:Vector3=(next-shot.pos).normalized()
	shot.pos=next if wall.is_empty() else wall.position+wall.normal*.05
	if t<1 and wall.is_empty():return
	cannon_splash(shot.pos,shot.damage,direction)
	m.events.append({"kind":"arrow_impact","id":shot.id,"to":shot.pos,"direction":direction,"cannon":true})
	arrows.erase(shot.id)

func cannon_splash(point:Vector3,damage:float,direction:Vector3):
	var runtime=m.army_runtime
	if not is_instance_valid(runtime) or runtime.game_ref==null:return
	var game=runtime.game_ref.get_ref()
	if not is_instance_valid(game):return
	# Reuse the native local index, fitted contacts and ordinary tower hit delivery.
	for enemy in runtime.enemy_candidates(point,CANNON_RADII[2]):
		if not is_instance_valid(enemy) or enemy.dead:continue
		if enemy.global_position.y>m.surface_height(enemy.global_position.x,enemy.global_position.z)+3.0:continue
		var contact=AttackChain.segment_contact(enemy,point,point,CANNON_RADII[2])
		if contact.is_empty() or not AttackChain.clear_line(game.world,point,contact.point):continue
		var distance=point.distance_to(contact.point)
		if distance>CANNON_RADII[2]:continue
		var factor=1.0 if distance<=CANNON_RADII[0] else .5 if distance<=CANNON_RADII[1] else .1
		enemy.take_hit(damage*factor,direction,false,{"tower":true,"projectile":true})
