extends RefCounted
const Roles=preload("res://scripts/forest/forest_enemy_roles.gd")
const Navigation=preload("res://scripts/forest/forest_enemy_navigation.gd")
const Arrows=preload("res://scripts/forest/forest_enemy_projectiles.gd")
const Pose=preload("res://scripts/forest/forest_enemy_crowd.gd")
const Routes=preload("res://scripts/forest/forest_routes.gd")
const COUNTS=[72,108,144,180,240]
const SPAWN_BATCH_SIZE=3
const ACTIVE_CAP=240
const SPAWN_ATTEMPTS=12
const SPAWN_DIRECTION=Vector2i.DOWN # South (+Z), facing the starter fort's gate.
var reference: WeakRef
var m:
	get:return reference.get_ref()
var pending=0
var spawn_clock=0.0
var rng=RandomNumberGenerator.new()
var giant_pending=false
var remaining_counts: Array=[0,0,0,0]
var spawned=0
var staging_revision=-1
var staging_candidates: Array=[]
var staging_validated: Dictionary={}
var staging_contacts: Array=[]
var projectiles: Dictionary={}
var navigation
var arrows
var routes
func _init(model):
	reference=weakref(model);navigation=Navigation.new(model);arrows=Arrows.new(model,navigation);routes=Routes.new(model)
func begin()->bool:
	if m.phase!="preparing" or m.wave>=m.balance.waves.size() or m.shrine().is_empty():return false
	m.wave+=1;m.phase="wave";remaining_counts=m.balance.waves[m.wave-1].duplicate();pending=0
	for count in remaining_counts:pending+=count
	spawn_clock=2.0;spawned=0;giant_pending=remaining_counts[2]>0;projectiles.clear()
	# Prepare the shared clearance grid at the wave transition. The giant's
	# first spawn should only validate entries against an already prepared grid.
	if giant_pending:navigation.refresh()
	rng.seed=m.seed_value+m.wave*7919
	routes.portal_cursor=0
	return true
func spawn_enemy(variant: int,point: Vector3)->Dictionary:
	var id: int=m.next_id;m.next_id+=1;var data=Roles.stats(variant)
	var e={"id":id,"pos":point,"hp":data.hp,"max_hp":data.hp,"variant":variant,"clock":0.0,"path":[],"nav":-1,"target":Vector2i.ZERO,"stun":0.0,"velocity":Vector3.ZERO,"attack":false,
		"action":"walk","action_left":0.0,"target_kind":"","target_id":-1,"facing":atan2(point.x,point.z),"walk_phase":0.0,"attack_progress":0.0,"attack_point":point,"strike_kind":"","strike_id":-1,"route_obstacle":-1,"frozen":0.0,"slow":1.0,"slow_left":0.0}
	m.enemies[id]=e;return e
func giant_staging()->Array:
	if staging_revision!=m.navigation_revision:
		staging_candidates.clear();staging_validated.clear();navigation.refresh()
		staging_contacts=navigation.approach_points(2,m.shrine())
		# Every entry stays on the gate side; scouting can push staging farther south.
		for radius in [14,15,16,20,24,28,32,36,37]:
			staging_candidates.append(m.point(SPAWN_DIRECTION*radius))
		# Perimeter towers can watch the center lane. The broad diagonal lanes
		# provide far southern entries without switching to another map edge.
		var side=Vector2i(SPAWN_DIRECTION.y,-SPAWN_DIRECTION.x)
		for radius in [20,24,28,32,36,37]:
			for sign_ in [-1,1]:staging_candidates.append(m.point(SPAWN_DIRECTION*radius+side*(radius-1)*sign_))
		staging_revision=m.navigation_revision
	var choices=[];var nearest=INF
	for p in staging_candidates:
		if p.length()>nearest+6:continue
		if not navigation.full_unseen(p,2):continue
		# Validate only unseen entries that can join the nearest staging ring.
		# Farther entries remain available when scouting covers the near ones.
		if not staging_validated.has(p):
			var probe={"pos":p,"variant":2,"facing":atan2(p.x,p.z)}
			staging_validated[p]=navigation.move_clear(p,8.5) and navigation.fitted_blocker(probe,p)<0 and navigation.has_approach(probe,staging_contacts)
		if not staging_validated[p]:continue
		if p.length()<nearest-6:choices.clear();nearest=p.length()
		choices.append(p)
	return choices
func spawn_one(reserved: Array=[])->bool:
	if pending<=0 or m.enemies.size()>=ACTIVE_CAP:return false
	if not m.portals.is_empty():return spawn_from_portals(reserved)
	if giant_pending:
		var candidates=giant_staging().filter(func(p):
			for enemy in m.enemies.values():
				if enemy.variant==2 and enemy.pos.distance_to(p)<18:return false
			return true)
		if not candidates.is_empty():
			spawn_enemy(2,candidates[rng.randi_range(0,candidates.size()-1)]);remaining_counts[2]-=1;giant_pending=remaining_counts[2]>0
			pending-=1;spawned+=1;return true
		# Ordinary enemies can still arrive while scouting occupies a giant approach.
		if pending<=remaining_counts[2]:return false
	var angle=atan2(SPAWN_DIRECTION.x,SPAWN_DIRECTION.y)+rng.randf_range(-.09,.09)
	var direction=Vector2(sin(angle),cos(angle));direction*=39.0/maxf(absf(direction.x),absf(direction.y))
	var c=m.nearest_open(Vector2i(roundi(direction.x),roundi(direction.y)),true)
	var variant=-1
	for offset in range(3):
		var type=[0,1,3][(spawned+offset)%3]
		if remaining_counts[type]>0:variant=type;break
	if variant<0:return false
	var p: Vector3=m.point(c)
	if not m.REGION.has_point(c) or not navigation.move_clear(p,Roles.footprint_radius(variant)) or not navigation.full_unseen(p,variant):return false
	for previous in reserved:
		if p.distance_to(previous)<1.8:return false
	spawn_enemy(variant,p);remaining_counts[variant]-=1;pending-=1;spawned+=1;reserved.append(p);return true
func spawn_from_portals(reserved: Array)->bool:
	var variants=[]
	if giant_pending:variants.append(2)
	for offset in range(3):
		var variant=[0,1,3][(spawned+offset)%3]
		if remaining_counts[variant]>0:variants.append(variant)
	for variant in variants:
		if not routes.spawn(variant,reserved):continue
		remaining_counts[variant]-=1;pending-=1;spawned+=1;giant_pending=remaining_counts[2]>0;return true
	return false

func spawn_batch()->int:
	var released=0;var reserved: Array=[]
	# Failed fog/clearance/spacing candidates consume retries, never pending slots.
	for attempt in range(SPAWN_ATTEMPTS):
		if released>=SPAWN_BATCH_SIZE or pending<=0 or m.enemies.size()>=ACTIVE_CAP:break
		if spawn_one(reserved):released+=1
	return released
func valid_target(kind: String,id: int,hero: Vector3)->bool:
	match kind:
		"hero":return m.hero_targetable and hero.y-m.surface_height(hero.x,hero.z)<5
		"worker":return m.workers.has(id) and m.workers[id].state!="wounded" and m.workers[id].hp>0
		"building":return m.buildings.has(id) and m.buildings[id].hp>0
	return false
func target_point(kind: String,id: int,hero: Vector3,e: Dictionary)->Vector3:
	match kind:
		"hero":return hero+Vector3.UP*1.3
		"worker":return arrows.worker_point(m.workers[id])
		"building":return navigation.building_point(m.buildings[id],e.pos)+Vector3.UP*(3.0 if e.variant==2 else 1.6)
	return e.pos
func set_target(e: Dictionary,kind: String,id: int):
	if e.get("target_kind","")==kind and e.get("target_id",-1)==id:return
	e.target_kind=kind;e.target_id=id;e.path=[];e.nav=-1
func choose_target(e: Dictionary,hero: Vector3):
	if e.variant!=2 and e.get("retaliation",0.0)>0 and valid_target("hero",0,hero) and horizontal_distance(e.pos,hero)<=28.0:
		set_target(e,"hero",0);return
	match e.variant:
		0:set_target(e,"hero",0) if valid_target("hero",0,hero) else set_target(e,"building",1)
		1:
			if e.target_kind=="worker" and valid_target("worker",e.target_id,hero):return
			var best=-1;var distance=INF
			for w in m.workers.values():
				if w.state=="wounded" or w.hp<=0:continue
				var d: float=e.pos.distance_squared_to(arrows.worker_point(w))
				if d<distance:distance=d;best=w.id
			set_target(e,"worker",best) if best>=0 else set_target(e,"building",1)
		2:
			if e.target_kind=="building" and valid_target("building",e.target_id,hero) and m.buildings[e.target_id].kind in ["tower","wall"]:
				if e.nav==m.navigation_revision:return
				var current=navigation.approach(e,m.buildings[e.target_id])
				if not current.is_empty():return
			var best=-1;var cost=INF;var best_order=2147483647;var candidates=[];var order=0
			for b in m.buildings.values():
				if b.kind not in ["tower","wall"]:continue
				var lower_bound=navigation.horizontal_path_lower_bound(e.pos,navigation.building_point(b,e.pos))-Roles.DATA[2].range*sqrt(2.0)
				candidates.append({"building":b,"bound":lower_bound,"order":order});order+=1
			# Search promising structures first, then stop when no remaining route
			# can win. Equal-cost targets retain their original insertion priority.
			candidates.sort_custom(func(a,b):return a.bound<b.bound)
			for candidate in candidates:
				if candidate.bound>cost:break
				var route_=navigation.approach(e,candidate.building)
				if not route_.is_empty() and (route_.cost<cost or (route_.cost==cost and candidate.order<best_order)):
					cost=route_.cost;best=candidate.building.id;best_order=candidate.order
			set_target(e,"building",best if best>=0 else 1)
		3:set_target(e,"building",1)
func horizontal_distance(a: Vector3,b: Vector3)->float:return Vector2(a.x-b.x,a.z-b.z).length()
func turn(e: Dictionary,point: Vector3,delta: float)->bool:
	var direction=point-e.pos
	if Vector2(direction.x,direction.z).length_squared()<.001:return true
	var desired=atan2(-direction.x,-direction.z)
	var amount: float=minf(Roles.stats(e.variant).turn_speed*delta,e.get("turn_left",INF))
	var rotation=clampf(wrapf(desired-e.facing,-PI,PI),-amount,amount)
	if e.variant==2:
		var sweep=navigation.yaw_sweep(e,rotation)
		e.turn_left=maxf(0,e.get("turn_left",amount)-absf(sweep.facing-e.facing))
		e.facing=sweep.facing
		if sweep.blocker>=0:
			var cached: Dictionary=e.get("turn_escape_query",{})
			if cached.get("nav",-1)!=m.navigation_revision or cached.get("pos",Vector3.INF)!=e.pos or not is_equal_approx(cached.get("facing",INF),e.facing):
				cached={"nav":m.navigation_revision,"pos":e.pos,"facing":e.facing,"path":navigation.turning_retreat(e,sweep.blocker)}
				e.turn_escape_query=cached
			# Cache failed searches too; a static blocked pose must not repeat map search every tick.
			e.turn_escape=cached.path.duplicate()
			e.turn_escape_nav=m.navigation_revision
			return false
	else:
		e.facing+=rotation;e.turn_left=maxf(0,e.get("turn_left",amount)-absf(rotation))
	return absf(wrapf(desired-e.facing,-PI,PI))<(.20 if e.variant==2 else .35)
func in_reach(e: Dictionary,kind: String,id: int,hero: Vector3)->bool:
	if not valid_target(kind,id,hero):return false
	var point=target_point(kind,id,hero,e)
	if not m.ramparts.is_empty() and e.variant!=1 and absf(e.pos.y-(point.y-(1.3 if kind=="hero" else 0)))>3.5:return false
	var range_: float=Roles.stats(e.variant).range
	if e.variant==1 and kind!="building":
		if e.pos.distance_to(point)>range_:return false
	elif horizontal_distance(e.pos,point)>range_:return false
	var ignore=id if kind=="building" else -1
	if kind=="worker" and m.workers[id].state=="garrison":ignore=m.workers[id].job
	return navigation.line_clear(e.pos+Vector3.UP*(3 if e.variant==2 else 2.2),point,ignore)
func start_attack(e: Dictionary,kind: String,id: int,hero: Vector3):
	e.action="windup";e.action_left=Roles.stats(e.variant).windup;e.strike_kind=kind;e.strike_id=id;e.attack_point=target_point(kind,id,hero,e);e.attack=true;e.attack_progress=0.0;e.velocity=Vector3.ZERO
func attack_tick(e: Dictionary,delta: float,hero: Vector3):
	var stats=Roles.stats(e.variant);e.velocity=Vector3.ZERO;e.attack=true
	if e.action=="windup" and not in_reach(e,e.strike_kind,e.strike_id,hero):
		e.action="walk";e.action_left=0.0;e.attack=false;e.attack_progress=0.0;e.path=[];e.nav=-1;return
	e.action_left=maxf(0,e.action_left-delta)
	if e.action=="windup":
		e.attack_progress=clampf(1-e.action_left/stats.windup,0,1)
		if e.action_left>0:return
		# Revalidate live target contact. No stale ids, teleported workers or damage through cover.
		e.attack_point=target_point(e.strike_kind,e.strike_id,hero,e)
		if e.variant==1 and (e.strike_kind!="building" or e.strike_id==1):
			arrows.launch(projectiles,e,e.strike_kind,e.strike_id,e.attack_point)
		else:
			match e.strike_kind:
				"hero":m.events.append({"kind":"hero_hit","amount":stats.damage,"from":e.pos})
				"worker":m.damage_worker(e.strike_id,stats.damage)
				"building":m.damage_building(e.strike_id,stats.damage)
		e.action="recover";e.action_left=stats.recovery;e.clock=stats.recovery;e.attack_progress=-1.0
	else:
		e.attack_progress=-e.action_left/stats.recovery;e.clock=e.action_left
		if e.action_left<=0:e.action="walk";e.attack=false;e.attack_progress=0.0
func rebuild_path(e: Dictionary,hero: Vector3,kind: String="",id: int=-1):
	if kind.is_empty():kind=e.target_kind;id=e.target_id
	var point=target_point(kind,id,hero,e);point.y=0
	var destination: Vector2i=m.cell_of(point)
	if e.nav==m.navigation_revision and e.target==destination and not e.path.is_empty():return
	e.nav=m.navigation_revision;e.target=destination
	if kind=="building":
		var approach=navigation.approach(e,m.buildings[id])
		e.path=approach.get("path",[])
	else:e.path=navigation.route(e,point)
	if not e.path.is_empty() and horizontal_distance(e.pos,m.point(e.path[0]))<.1:e.path.pop_front()
func swept_move(e: Dictionary,displacement: Vector3)->int:
	var radius: float=Roles.footprint_radius(e.variant);var steps=maxi(1,ceili(displacement.length()/.25))
	for i in range(steps):
		var next: Vector3=e.pos+displacement/steps
		if not m.terrain.step_clear(e.pos,next):return -2
		if not m.ramparts.is_empty():next.y=m.surface_height(next.x,next.z)
		if not navigation.terrain_clear(next,radius):return -2
		var obstacle: int=navigation.fitted_blocker(e,next)
		if obstacle>=0:return obstacle
		e.pos=next
	return -1
func retreat_tick(e: Dictionary,delta: float):
	var old: Vector3=e.pos
	var remaining: float=Roles.stats(2).speed*e.get("slow",1.0)*delta
	while remaining>0 and not e.turn_escape.is_empty():
		var point: Vector3=e.turn_escape.front()
		var distance: float=e.pos.distance_to(point)
		var amount=minf(remaining,distance)
		if swept_move(e,e.pos.direction_to(point)*amount)!=-1:
			e.turn_escape=[];e.path=[];e.nav=-1;break
		remaining-=amount
		if distance<=amount+.001:e.turn_escape.pop_front()
		else:break
	e.velocity=(e.pos-old)/maxf(.001,delta)
	var traveled: float=e.pos.distance_to(old)
	if traveled>0:e.walk_phase=fmod(e.walk_phase+TAU*traveled/Roles.stats(2).stride,TAU)
	if e.turn_escape.is_empty():e.path=[];e.nav=-1

func tick_enemy(e: Dictionary,delta: float,hero: Vector3):
	if e.variant!=2:
		_tick_enemy(e,delta,hero);return
	var track=e.has("walk_feet") or not e.get("turn_escape",[]).is_empty()
	var old_root=Transform3D(Basis(Vector3.UP,float(e.facing)),e.pos)
	var old_phase=float(e.walk_phase)
	var old_parts: Dictionary={}
	# Capture before clearing velocity, including a retreat first requested this
	# tick. Its initial anchors must retain the last physical walking pose.
	for group in ["foot_l","foot_r"]:old_parts[group]=Pose.part_pose(group,e)
	var frozen_before=float(e.get("frozen",0.0))
	_tick_enemy(e,delta,hero)
	if frozen_before>=delta:return
	if track or not e.get("turn_escape",[]).is_empty():
		Pose.advance_walk_feet(e,old_root,old_phase,old_parts,maxf(0,delta-frozen_before))

func _tick_enemy(e: Dictionary,delta: float,hero: Vector3):
	var frozen_before: float=e.get("frozen",0.0)
	if frozen_before>0 and not e.has("frozen_pose"):
		var snapshot: Dictionary=e.duplicate();snapshot.erase("frozen_pose");e.frozen_pose=snapshot
	if frozen_before<=0:e.erase("frozen_pose")
	e.velocity=Vector3.ZERO
	# Control timers consume only the frozen overlap; attacks/movement consume the remaining interval.
	e.frozen=maxf(0,frozen_before-delta)
	if frozen_before>0:
		delta=maxf(0,delta-frozen_before)
		if e.frozen<=0:e.erase("frozen_pose")
		if delta<=0:return
	e.stun=maxf(0,e.stun-delta);e.slow_left=maxf(0,e.get("slow_left",0.0)-delta)
	e.retaliation=maxf(0,e.get("retaliation",0.0)-delta)
	e.hit_recoil=maxf(0,e.get("hit_recoil",0.0)-delta)
	if e.slow_left<=0:e.slow=1.0
	var impulse: Vector3=e.get("knockback",Vector3.ZERO)
	if impulse.length_squared()>.01:
		var old: Vector3=e.pos;swept_move(e,impulse*delta);e.velocity=(e.pos-old)/maxf(.001,delta);e.knockback=impulse*exp(-8*delta);e.path=[];e.erase("road_join");return
	if e.stun>0:return
	if e.action!="walk":attack_tick(e,delta,hero);return
	e.turn_left=Roles.stats(e.variant).turn_speed*delta
	if e.variant==2 and not e.get("turn_escape",[]).is_empty():
		if e.get("turn_escape_nav",-1)!=m.navigation_revision:e.turn_escape=[];e.path=[];e.nav=-1
		else:retreat_tick(e,delta);return
	e.attack=false;choose_target(e,hero)
	if not valid_target(e.target_kind,e.target_id,hero):return
	var on_road=routes.following(e,hero)
	var movement_kind: String=e.target_kind;var movement_id: int=e.target_id
	if e.get("route_obstacle",-1)>=0:
		if valid_target("building",e.route_obstacle,hero):movement_kind="building";movement_id=e.route_obstacle
		else:e.route_obstacle=-1;e.path=[];e.nav=-1
	# A side fist may encounter a building before the forward strike can reach it.
	# Turn fully, then close the short visible approach facing that obstruction.
	if e.variant==2 and e.get("route_obstacle",-1)>=0 and not in_reach(e,movement_kind,movement_id,hero):
		var contact=target_point(movement_kind,movement_id,hero,e);var ground=Vector3(contact.x,0,contact.z)
		if horizontal_distance(e.pos,ground)<=20 and navigation.line_clear(e.pos+Vector3.UP*3,contact,movement_id):
			if not turn(e,ground,delta):return
			var old: Vector3=e.pos;var step: float=Roles.stats(2).speed*e.get("slow",1.0)*delta
			var obstacle=swept_move(e,e.pos.direction_to(ground)*minf(step,e.pos.distance_to(ground)))
			if obstacle>=0 and obstacle!=movement_id:e.route_obstacle=obstacle;e.path=[];e.nav=-1
			e.velocity=(e.pos-old)/maxf(.001,delta)
			var traveled: float=e.pos.distance_to(old)
			if traveled>0:e.walk_phase=fmod(e.walk_phase+TAU*traveled/Roles.stats(2).stride,TAU)
			return
	if in_reach(e,movement_kind,movement_id,hero):
		if turn(e,target_point(movement_kind,movement_id,hero,e),delta):start_attack(e,movement_kind,movement_id,hero)
		return
	if on_road and e.get("route_obstacle",-1)<0:e.path=routes.movement_path(e);e.nav=-1
	else:rebuild_path(e,hero,movement_kind,movement_id)
	if e.path.is_empty():return
	var remaining: float=Roles.stats(e.variant).speed*e.get("slow",1.0)*delta;var old: Vector3=e.pos
	while remaining>0 and not e.path.is_empty():
		var point: Vector3=m.point(e.path.front())
		if not turn(e,point,delta) and e.variant==2:break
		var distance: float=e.pos.distance_to(point);var move_amount=minf(distance,remaining)
		var obstacle=swept_move(e,e.pos.direction_to(point)*move_amount)
		if obstacle>=0:
			if e.variant==2 and e.route_obstacle!=obstacle:
				e.route_obstacle=obstacle;e.path=[];e.nav=-1
			if in_reach(e,"building",obstacle,hero) and turn(e,target_point("building",obstacle,hero,e),delta):start_attack(e,"building",obstacle,hero)
			break
		if obstacle==-2:e.path=[];e.erase("road_join");e.nav=-1;break
		remaining-=move_amount
		if distance<=move_amount+.001:e.path.pop_front()
		else:break
	e.velocity=(e.pos-old)/maxf(.001,delta)
	var traveled: float=e.pos.distance_to(old)
	if traveled>0:e.walk_phase=fmod(e.walk_phase+TAU*traveled/Roles.stats(e.variant).stride,TAU)
func tick(delta: float,hero: Vector3):
	if m.phase!="wave" or delta<=0:return
	arrows.tick(projectiles,delta,hero)
	spawn_clock-=delta
	if pending>0 and spawn_clock<=0 and m.enemies.size()<ACTIVE_CAP:spawn_batch();spawn_clock=.65
	for id in m.enemies.keys():
		var e: Dictionary=m.enemies[id]
		if e.hp<=0:m.enemies.erase(id);continue
		tick_enemy(e,delta,hero)
		if m.phase!="wave":projectiles.clear();return
	if pending==0 and m.enemies.is_empty() and m.phase=="wave":
		projectiles.clear();m.gold+=100;m.phase="victory" if m.wave>=m.balance.waves.size() else "preparing"
		m.workforce.recover();m.update_vision(hero);m.events.append({"kind":m.phase});m.revision+=1
