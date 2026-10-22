extends RefCounted
const SoldierCombat=preload("res://scripts/forest/forest_thirstquencher_combat.gd")
const SoldierVisual=preload("res://scripts/forest/forest_thirstquencher_visual.gd")
const Profile=preload("res://scripts/forest/forest_structure_profile.gd")
const Roles=preload("res://scripts/forest/forest_enemy_roles.gd")
const Navigation=preload("res://scripts/forest/forest_enemy_navigation.gd")
const Arrows=preload("res://scripts/forest/forest_enemy_projectiles.gd")
const Pose=preload("res://scripts/forest/forest_enemy_crowd.gd")
const Routes=preload("res://scripts/forest/forest_routes.gd")
const Flow=preload("res://scripts/forest/forest_enemy_flow.gd")
const COUNTS=[360,540,716,896,1196]
const SPAWN_BATCH_SIZE=3
const SPAWN_INTERVAL=.13 # Five independent ordinary arrivals per old group.
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
var boss_pending: Dictionary={}
var spawned=0
var staging_revision=-1
var staging_candidates: Array=[]
var staging_validated: Dictionary={}
var staging_contacts: Array=[]
var projectiles: Dictionary={}
var navigation
var arrows
var routes
var flow
const SPAWN_QUERY_CELL=16.0
var spawn_query_active=false
var spawn_query_buckets:Dictionary={}
var spawn_query_max_radius=0.0
const DEFENDER_CELL=24.0
var defender_snapshot_active=false
var defender_rows:Array=[]
var defender_buckets:Dictionary={}
var first_taunting_defender:Variant=null
var step_active=false
var step_ids:Array=[]
var step_cursor=0
var step_delta=0.0
var step_sliced=false
var stats_cache:Dictionary={}
var stats_speed=NAN
var stats_health=NAN
var stats_damage=NAN
var stats_boss_health=NAN
var stats_boss_speed=NAN
func _init(model):
	reference=weakref(model);navigation=Navigation.new(model);arrows=Arrows.new(model,navigation);routes=Routes.new(model);flow=Flow.new(model)
func begin()->bool:
	if m.phase!="preparing" or m.wave>=m.balance.waves.size() or m.shrine().is_empty():return false
	cancel_step()
	m.wave+=1;m.phase="wave";remaining_counts=m.balance.waves[m.wave-1].duplicate();pending=0
	# Suppress large special enemies in the effective queue only. Saved/editor
	# composition stays intact so it can be restored without migrating maps.
	remaining_counts[2]=0
	for type in [0,1,3]:pending+=remaining_counts[type]
	boss_pending.clear()
	spawn_clock=2.0;spawned=0;giant_pending=remaining_counts[2]>0;projectiles.clear()
	# Prepare the shared clearance grid at the wave transition. The giant's
	# first spawn should only validate entries against an already prepared grid.
	if giant_pending:navigation.refresh()
	rng.seed=m.seed_value+m.wave*7919
	routes.portal_cursor=0
	return true
func spawn_enemy(variant: int,point: Vector3)->Dictionary:
	var id: int=m.next_id;m.next_id+=1;var data=_simulation_stats(variant)
	var e={"id":id,"pos":point,"hp":data.hp,"max_hp":data.hp,"variant":variant,"clock":0.0,"path":[],"nav":-1,"target":Vector2i.ZERO,"stun":0.0,"velocity":Vector3.ZERO,"attack":false,
		"action":"walk","action_left":0.0,"target_kind":"","target_id":-1,"facing":atan2(point.x,point.z),"walk_phase":0.0,"attack_progress":0.0,"attack_point":point,"strike_kind":"","strike_id":-1,"route_obstacle":-1,"frozen":0.0,"slow":1.0,"slow_left":0.0}
	m.enemies[id]=e
	var runtime=m.get("army_runtime")
	if is_instance_valid(runtime) and runtime.has_method("queue_enemy_arrival"):runtime.queue_enemy_arrival(e)
	return e
func role_stats(variant:int)->Dictionary:
	# Public callers may mutate their copy. Simulation only borrows frozen rows.
	return _simulation_stats(variant).duplicate()
func _simulation_stats(variant:int)->Dictionary:
	var balance=m.balance
	if stats_speed!=balance.enemy_speed_mult or stats_health!=balance.enemy_health_mult or stats_damage!=balance.enemy_damage_mult or stats_boss_health!=balance.boss_health or stats_boss_speed!=balance.boss_speed:
		stats_cache.clear()
		stats_speed=balance.enemy_speed_mult;stats_health=balance.enemy_health_mult;stats_damage=balance.enemy_damage_mult
		stats_boss_health=balance.boss_health;stats_boss_speed=balance.boss_speed
	if stats_cache.has(variant):return stats_cache[variant]
	var stats=Roles.stats(variant)
	if variant==Roles.BOSS:stats.hp=stats_boss_health;stats.speed=stats_boss_speed
	stats.speed*=stats_speed
	stats.hp*=stats_health
	stats.damage*=stats_damage
	stats.make_read_only();stats_cache[variant]=stats
	return stats
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
	var variant=-1
	for offset in range(3):
		var type=[0,1,3][(spawned+offset)%3]
		if remaining_counts[type]>0:variant=type;break
	if variant<0:return false
	var radius=Roles.footprint_radius(variant)
	var edge=mini(m.navigation_region.end.x-1,floori((m.world_bounds().end.x-radius)/m.CELL))
	var angle=atan2(SPAWN_DIRECTION.x,SPAWN_DIRECTION.y)+rng.randf_range(-.09,.09)
	var direction=Vector2(sin(angle),cos(angle));direction*=float(edge)/maxf(absf(direction.x),absf(direction.y))
	var c=m.nearest_open(Vector2i(roundi(direction.x),roundi(direction.y)),true)
	var p: Vector3=m.point(c)
	if not m.navigation_region.has_point(c) or not navigation.move_clear(p,Roles.footprint_radius(variant)) or not navigation.full_unseen(p,variant):return false
	for previous in reserved:
		if p.distance_to(previous)<maxf(1.8,2*radius+.35):return false
	spawn_enemy(variant,p);remaining_counts[variant]-=1;pending-=1;spawned+=1;reserved.append(p);return true
func spawn_from_portals(reserved: Array)->bool:
	for index in boss_pending.keys():
		if routes.spawn(Roles.BOSS,reserved,index):
			boss_pending.erase(index);pending-=1;spawned+=1;return true
	var variants=[]
	if giant_pending:variants.append(2)
	for offset in range(3):
		var variant=[0,1,3][(spawned+offset)%3]
		if remaining_counts[variant]>0:variants.append(variant)
	for variant in variants:
		if not routes.spawn(variant,reserved):continue
		remaining_counts[variant]-=1;pending-=1;spawned+=1;giant_pending=remaining_counts[2]>0;return true
	return false

func begin_spawn_query():
	spawn_query_buckets.clear();spawn_query_max_radius=0.0;spawn_query_active=true
	for enemy in m.enemies.values():register_spawn(enemy)

func register_spawn(enemy:Dictionary):
	if not spawn_query_active:return
	var radius=Roles.visibility_radius(int(enemy.variant))
	spawn_query_max_radius=maxf(spawn_query_max_radius,radius)
	var point:Vector3=enemy.pos
	var cell=Vector2i(floori(point.x/SPAWN_QUERY_CELL),floori(point.z/SPAWN_QUERY_CELL))
	if not spawn_query_buckets.has(cell):spawn_query_buckets[cell]=[]
	spawn_query_buckets[cell].append({"pos":point,"radius":radius})

func spawn_space_clear(point:Vector3,radius:float)->bool:
	if not spawn_query_active:
		for enemy in m.enemies.values():
			if point.distance_to(enemy.pos)<radius+Roles.visibility_radius(int(enemy.variant))+.35:return false
		return true
	var reach=radius+spawn_query_max_radius+.35
	var first=Vector2i(floori((point.x-reach)/SPAWN_QUERY_CELL),floori((point.z-reach)/SPAWN_QUERY_CELL))
	var last=Vector2i(floori((point.x+reach)/SPAWN_QUERY_CELL),floori((point.z+reach)/SPAWN_QUERY_CELL))
	for x in range(first.x,last.x+1):
		for z in range(first.y,last.y+1):
			for row in spawn_query_buckets.get(Vector2i(x,z),[]):
				if point.distance_to(row.pos)<radius+float(row.radius)+.35:return false
	return true

func end_spawn_query():
	spawn_query_active=false;spawn_query_buckets.clear();spawn_query_max_radius=0.0

func spawn_batch()->int:
	var released=0;var reserved: Array=[]
	var portal_mode=not m.portals.is_empty()
	if portal_mode:begin_spawn_query()
	# Portal searches exhaust every type/portal/slot. Repeating a failed search
	# cannot find a new opening before the world advances. Random edge entries
	# retain their independent retries.
	for attempt in range(SPAWN_ATTEMPTS):
		if released>=SPAWN_BATCH_SIZE or pending<=0 or m.enemies.size()>=ACTIVE_CAP:break
		if spawn_one(reserved):released+=1
		elif portal_mode:break
	if portal_mode:end_spawn_query()
	return released
func valid_target(kind: String,id: int,hero: Vector3)->bool:
	match kind:
		"hero":return m.hero_targetable and hero.y-m.surface_height(hero.x,hero.z)<5
		"defender":return m.defenders.has(id) and m.defenders[id].hp>0 and m.defenders[id].targetable
		"worker":return m.worker_targetable(id)
		"building":return m.buildings.has(id) and m.buildings[id].hp>0 and m.buildings[id].kind!="wall" and not m.buildings[id].get("breached",false)
		"breach":return m.buildings.has(id) and m.buildings[id].get("breached",false)
	return false
func target_point(kind: String,id: int,hero: Vector3,e: Dictionary)->Vector3:
	match kind:
		"hero":return hero+Vector3.UP*1.3
		"defender":return m.defenders[id].pos+Vector3.UP*1.3
		"worker":return arrows.worker_point(m.workers[id])
		"breach":return m.center(m.buildings[id])
		"building":return navigation.building_point(m.buildings[id],e.pos)+Vector3.UP*(3.0 if e.variant==2 else 1.6)
	return e.pos
func set_target(e: Dictionary,kind: String,id: int):
	if e.get("target_kind","")==kind and e.get("target_id",-1)==id:return
	e.target_kind=kind;e.target_id=id;e.path=[];e.nav=-1
func begin_defender_snapshot(hero:Vector3):
	defender_rows.clear();defender_buckets.clear();first_taunting_defender=null
	# Helpers replace these rows between physics frames. Enemy hits queue events
	# until this slice returns, so its live rows can be shared only within a slice.
	for d in m.defenders.values():
		if not valid_target("defender",d.id,hero):continue
		if first_taunting_defender==null and d.get("taunting",false):first_taunting_defender=d.id
		var cell=Vector2i(floori(d.pos.x/DEFENDER_CELL),floori(d.pos.z/DEFENDER_CELL))
		if not defender_buckets.has(cell):defender_buckets[cell]=[]
		defender_buckets[cell].append(defender_rows.size());defender_rows.append(d)
	defender_snapshot_active=true
func nearby_defenders(pos:Vector3,distance:float)->Array:
	if not defender_snapshot_active:return m.defenders.values()
	var indices=[]
	for x in range(floori((pos.x-distance)/DEFENDER_CELL),floori((pos.x+distance)/DEFENDER_CELL)+1):
		for z in range(floori((pos.z-distance)/DEFENDER_CELL),floori((pos.z+distance)/DEFENDER_CELL)+1):
			indices.append_array(defender_buckets.get(Vector2i(x,z),[]))
	indices.sort() # Preserve insertion priority when exact distances tie.
	var result=[]
	for index in indices:result.append(defender_rows[index])
	return result
func choose_target(e: Dictionary,hero: Vector3):
	var crossing:Dictionary=m.buildings.get(e.get("crossing_gate",-1),{})
	if crossing.get("breached",false) and not navigation.gate_crossing_complete(e,crossing):
		set_target(e,"breach",crossing.id);return
	e.erase("crossing_gate");e.erase("crossing_aligned");e.erase("crossing_direction")
	if defender_snapshot_active:
		if first_taunting_defender!=null:set_target(e,"defender",first_taunting_defender);return
	else:
		for defender in m.defenders.values():
			if defender.get("taunting",false) and valid_target("defender",defender.id,hero):
				set_target(e,"defender",defender.id);return
	var retaliate=int(e.get("retaliation_defender",-1))
	if e.get("retaliation",0.0)>0 and valid_target("defender",retaliate,hero) and horizontal_distance(e.pos,m.defenders[retaliate].pos)<28:
		set_target(e,"defender",retaliate);return
	if e.get("retaliation",0.0)>0 and valid_target("hero",0,hero) and horizontal_distance(e.pos,hero)<=28.0:
		set_target(e,"hero",0);return
	# Ordinary objectives compete by horizontal distance to the actual building
	# edge or exposed unit. Roles still own their original attacks and movement.
	var kind="";var id=-1;var distance=INF
	for b in m.buildings.values():
		if not valid_target("building",b.id,hero):continue
		var point=navigation.building_point(b,e.pos)
		var gap=Vector2(e.pos.x-point.x,e.pos.z-point.z).length_squared()
		if gap<distance:distance=gap;kind="building";id=b.id
	for w in m.workers.values():
		if not valid_target("worker",w.id,hero):continue
		var gap=Vector2(e.pos.x-w.pos.x,e.pos.z-w.pos.z).length_squared()
		if gap<distance:distance=gap;kind="worker";id=w.id
	var defenders=nearby_defenders(e.pos,sqrt(distance)) if is_finite(distance) and distance<DEFENDER_CELL*DEFENDER_CELL*64 else (defender_rows if defender_snapshot_active else m.defenders.values())
	for d in defenders:
		if not defender_snapshot_active and not valid_target("defender",d.id,hero):continue
		var gap=Vector2(e.pos.x-d.pos.x,e.pos.z-d.pos.z).length_squared()
		if gap<distance:distance=gap;kind="defender";id=d.id
	if not kind.is_empty():set_target(e,kind,id)
	elif valid_target("hero",0,hero):set_target(e,"hero",0)
	else:set_target(e,"",-1)
func horizontal_distance(a: Vector3,b: Vector3)->float:return Vector2(a.x-b.x,a.z-b.z).length()
func turn(e: Dictionary,point: Vector3,delta: float)->bool:
	var direction=point-e.pos
	if Vector2(direction.x,direction.z).length_squared()<.001:return true
	var desired=atan2(-direction.x,-direction.z)
	# Commit the source charge heading only on a straight, clear native route.
	# Native corners, separation and cliffs retain their existing safe steering.
	if e.variant in [0,3] and float(e.get("soldier_charge_tick",0))>=9:
		var forward=Vector3(-sin(e.facing),0,-cos(e.facing))
		var flat=Vector3(direction.x,0,direction.z).normalized()
		if forward.dot(flat)>.995:return true
		e.soldier_charge_tick=0.0
	var amount: float=minf(_simulation_stats(e.variant).turn_speed*delta,e.get("turn_left",INF))
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
	if kind=="breach" or not valid_target(kind,id,hero):return false
	var point=target_point(kind,id,hero,e)
	if m.has_elevation() and e.variant!=1 and absf(e.pos.y-(point.y-(1.3 if kind in ["hero","defender"] else 0)))>3.5:return false
	var range_: float=_simulation_stats(e.variant).range
	if e.variant==1 and kind!="building":
		if e.pos.distance_to(point)>range_:return false
	elif horizontal_distance(e.pos,point)>range_:return false
	if e.variant==1:return soldier_gun_target(e,kind,id,hero)
	if e.variant in [0,3] and not soldier_melee_proximity(e,kind,id,hero):return false
	var ignore=id if kind=="building" else -1
	if kind=="worker" and m.workers[id].state=="garrison":ignore=m.workers[id].job
	return navigation.line_clear(e.pos+Vector3.UP*(3 if e.variant==2 else 2.2),point,ignore)
func start_attack(e: Dictionary,kind: String,id: int,hero: Vector3):
	if SoldierVisual.supports(int(e.variant)):
		e.strike_kind=kind;e.strike_id=id;e.attack_point=target_point(kind,id,hero,e)
		e.action="source_attack";e.action_left=0.0;e.attack=true;e.attack_progress=0.0;e.velocity=Vector3.ZERO
		SoldierCombat.begin(e);return
	e.action="windup";e.action_left=_simulation_stats(e.variant).windup;e.strike_kind=kind;e.strike_id=id;e.attack_point=target_point(kind,id,hero,e);e.attack=true;e.attack_progress=0.0;e.velocity=Vector3.ZERO
func attack_tick(e: Dictionary,delta: float,hero: Vector3):
	if SoldierVisual.supports(int(e.variant)):
		soldier_attack_tick(e,delta,hero);return
	var stats=_simulation_stats(e.variant);e.velocity=Vector3.ZERO;e.attack=true
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
				"defender":m.events.append({"kind":"defender_hit","id":e.strike_id,"amount":stats.damage,"from":e.pos})
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
	if e.variant in [0,3] and kind!="building" and destination==m.cell_of(e.pos) and horizontal_distance(e.pos,point)<=6.0:
		e.path=[];e.nav=m.navigation_revision;e.target=destination;return
	if e.nav==m.navigation_revision and e.target==destination and (not e.path.is_empty() or (SoldierVisual.supports(int(e.variant)) and float(e.get("path_retry",0))>0)):return
	e.nav=m.navigation_revision;e.target=destination;e.path_retry=.35
	if kind in ["building","breach"]:
		var approach=navigation.approach(e,m.buildings[id])
		e.path=approach.get("path",[])
	else:e.path=navigation.route(e,point)
	if not e.path.is_empty() and horizontal_distance(e.pos,m.point(e.path[0]))<.1:e.path.pop_front()
	elif Flow.ordinary(e) and e.path.size()>1 and e.path.front()==m.cell_of(e.pos) and flow.corridor_clear(e,e.pos,m.point(e.path[1]),false):
		# Chasing from a lateral lane should depart toward the next route cell,
		# rather than first walking sideways back to the current cell center.
		e.path.pop_front()
func swept_move(e: Dictionary,displacement: Vector3)->int:
	var radius: float=Roles.footprint_radius(e.variant);var steps=maxi(1,ceili(displacement.length()/.25))
	for i in range(steps):
		var next: Vector3=e.pos+displacement/steps
		if not m.terrain.step_clear(e.pos,next):return -2
		if m.has_elevation():next.y=m.surface_height(next.x,next.z)
		if not navigation.terrain_clear(next,radius):return -2
		var obstacle: int=navigation.fitted_blocker(e,next)
		if obstacle>=0:return obstacle
		e.pos=next
	return -1
func breach_step(e:Dictionary,delta:float,gate_id:int=-1,direction:int=-1)->bool:
	var gate:Dictionary=m.buildings[e.target_id if gate_id<0 else gate_id]
	var next=navigation.gate_breach_waypoint(e,gate,direction)
	if next.is_empty():return false
	e.route_obstacle=-1;e.path=[];e.nav=-1
	var before:Vector3=e.pos;var point:Vector3=next.point
	turn(e,point,delta)
	var distance:float=e.pos.distance_to(point)
	var amount=minf(distance,_simulation_stats(e.variant).speed*e.get("slow",1.0)*delta)
	var obstacle=swept_move(e,e.pos.direction_to(point)*amount)
	if obstacle==-1 and distance<=amount+.001:
		if not next.aligned:e.crossing_aligned=true
		else:e.erase("crossing_gate");e.erase("crossing_aligned");e.erase("crossing_direction");e.entry_gate=-1
	e.velocity=(e.pos-before)/maxf(.001,delta)
	e.walk_phase=fmod(e.walk_phase+TAU*e.pos.distance_to(before)/_simulation_stats(e.variant).stride,TAU)
	return true
func retreat_tick(e: Dictionary,delta: float):
	var old: Vector3=e.pos
	var remaining: float=_simulation_stats(2).speed*e.get("slow",1.0)*delta
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
	# Sliced actors retain local revisions even when a public caller advances
	# them between world cycles. Ordinary direct callers keep global fallback.
	if e.has("simulation_revision"):e.simulation_revision=int(e.simulation_revision)+1
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
	e.entry_gate_retry=maxf(0,float(e.get("entry_gate_retry",0))-delta)
	# Control timers consume only the frozen overlap; attacks/movement consume the remaining interval.
	e.frozen=maxf(0,frozen_before-delta)
	if frozen_before>0:
		delta=maxf(0,delta-frozen_before)
		if e.frozen<=0:e.erase("frozen_pose")
		if delta<=0:return
	if SoldierVisual.supports(int(e.variant)):
		e.soldier_pose_tick=float(e.get("soldier_pose_tick",0))+delta*30.0
		e.path_retry=maxf(0,float(e.get("path_retry",0))-delta)
	if float(e.get("soldier_hurt_left",0))>0:
		e.soldier_hurt_tick=float(e.get("soldier_hurt_tick",0))+delta*30.0
		e.soldier_hurt_left=maxf(0,float(e.soldier_hurt_left)-delta)
	e.stun=maxf(0,e.stun-delta);e.slow_left=maxf(0,e.get("slow_left",0.0)-delta)
	e.retaliation=maxf(0,e.get("retaliation",0.0)-delta)
	e.hit_recoil=maxf(0,e.get("hit_recoil",0.0)-delta)
	if e.slow_left<=0:e.slow=1.0
	var impulse: Vector3=e.get("knockback",Vector3.ZERO)
	if impulse.length_squared()>.01:
		var old: Vector3=e.pos;swept_move(e,impulse*delta);e.velocity=(e.pos-old)/maxf(.001,delta);e.knockback=impulse*exp(-8*delta);e.path=[];e.erase("road_join");return
	if e.stun>0:return
	if e.action!="walk":attack_tick(e,delta,hero);return
	if e.variant in [0,3]:e.soldier_charge_tick=fposmod(float(e.get("soldier_charge_tick",0))+delta*30.0,30.0)
	e.turn_left=_simulation_stats(e.variant).turn_speed*delta
	if e.variant==2 and not e.get("turn_escape",[]).is_empty():
		if e.get("turn_escape_nav",-1)!=m.navigation_revision:e.turn_escape=[];e.path=[];e.nav=-1
		else:retreat_tick(e,delta);return
	e.attack=false;choose_target(e,hero)
	if not valid_target(e.target_kind,e.target_id,hero):return
	if e.target_kind=="breach" and breach_step(e,delta):return
	# Combat targets can be on either side of a breached door. Use the same
	# bounded alignment and physical sweep for inward and outward pursuit.
	if e.target_kind!="breach":
		var destination:Vector3=target_point(e.target_kind,e.target_id,hero,e)
		for gate in m.buildings.values():
			if gate.kind!="gate" or not gate.get("breached",false):continue
			var normal:Vector3=navigation.gate_outward(gate);var center:Vector3=m.center(gate)
			var actor_side:float=normal.dot(e.pos-center);var target_side:float=normal.dot(destination-center)
			if actor_side*target_side>=0:continue
			if breach_step(e,delta,gate.id,1 if actor_side<0 else -1):return
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
			var old: Vector3=e.pos;var step: float=_simulation_stats(2).speed*e.get("slow",1.0)*delta
			var obstacle=swept_move(e,e.pos.direction_to(ground)*minf(step,e.pos.distance_to(ground)))
			if obstacle>=0 and obstacle!=movement_id:e.route_obstacle=obstacle;e.path=[];e.nav=-1
			e.velocity=(e.pos-old)/maxf(.001,delta)
			var traveled: float=e.pos.distance_to(old)
			if traveled>0:e.walk_phase=fmod(e.walk_phase+TAU*traveled/Roles.stats(2).stride,TAU)
			return
	if in_reach(e,movement_kind,movement_id,hero):
		if turn(e,target_point(movement_kind,movement_id,hero,e),delta):start_attack(e,movement_kind,movement_id,hero)
		return
	if on_road and e.get("route_obstacle",-1)<0:
		# A safe outer lane is farther from the next cell center than the old
		# center-line rejoin threshold; keep advancing its existing shared road.
		var lane_progress=Flow.ordinary(e) and e.get("flow_road",false) and e.get("road_join",[]).is_empty() and m.roads.has(m.cell_of(e.pos)) and e.pos.distance_to(m.point(e.road_path.front()))<12
		e.path=e.road_path if lane_progress else routes.movement_path(e);e.nav=-1
	else:rebuild_path(e,hero,movement_kind,movement_id)
	if e.path.is_empty():
		# A grid cell is wider than the original weapon. Close the final metres
		# in world space, keeping the same wall/cliff sweep as normal travel.
		if e.variant in [0,3]:soldier_close_step(e,delta,hero,movement_kind,movement_id)
		return
	var remaining: float=_simulation_stats(e.variant).speed*e.get("slow",1.0)*delta;var old: Vector3=e.pos
	while remaining>0 and not e.path.is_empty():
		e.flow_road=on_road
		var point: Vector3=flow.route_point(e,on_road)
		if not turn(e,point,delta) and e.variant==2:break
		var distance: float=e.pos.distance_to(point);var move_amount=minf(distance,remaining)
		var obstacle=swept_move(e,flow.direction(e,point)*move_amount)
		if obstacle>=0:
			if not valid_target("building",obstacle,hero):
				e.route_obstacle=-1;e.path=[];e.nav=-1;break
			# Keep facing the actual blocker on the next step. Re-turning toward
			# the waypoint first can consume every tick's entire yaw budget.
			if e.route_obstacle!=obstacle:
				e.route_obstacle=obstacle;e.path=[];e.nav=-1
			if in_reach(e,"building",obstacle,hero) and turn(e,target_point("building",obstacle,hero,e),delta):start_attack(e,"building",obstacle,hero)
			break
		if obstacle==-2:e.path=[];e.erase("road_join");e.erase("flow_key");e.nav=-1;break
		remaining-=move_amount
		if distance<=move_amount+.001:e.path.pop_front()
		else:break
	e.velocity=(e.pos-old)/maxf(.001,delta)
	var traveled: float=e.pos.distance_to(old)
	if traveled>0:e.walk_phase=fmod(e.walk_phase+TAU*traveled/_simulation_stats(e.variant).stride,TAU)
func tick_native(delta:float,hero:Vector3):
	if m.phase!="wave":return
	spawn_clock-=delta
	if pending>0 and spawn_clock<=0 and m.enemies.size()<ACTIVE_CAP:spawn_batch();spawn_clock=SPAWN_INTERVAL
	if pending==0 and m.enemies.is_empty():
		m.gold+=100;m.phase="victory" if m.wave>=m.balance.waves.size() else "preparing"
		m.workforce.recover();m.update_vision(hero);m.events.append({"kind":m.phase});m.revision+=1

func tick(delta: float,hero: Vector3):
	# Direct callers stay synchronous. Complete any captured old interval before
	# consuming the newly requested one; neither interval loses its actors.
	if step_active:advance_step(step_ids.size(),hero)
	if not begin_step(delta,hero,false):return
	advance_step(step_ids.size(),hero)

func begin_step(delta:float,hero:Vector3,sliced:bool=true)->bool:
	if step_active or m.phase!="wave" or delta<=0:return false
	arrows.tick(projectiles,delta,hero)
	if m.phase!="wave":projectiles.clear();return false
	spawn_clock-=delta
	if pending>0 and spawn_clock<=0 and m.enemies.size()<ACTIVE_CAP:spawn_batch();spawn_clock=SPAWN_INTERVAL
	flow.begin_tick()
	# Capture IDs after the cycle's spawn batch. Later arrivals join the next
	# cycle; deaths/removals are revalidated when their captured slot is reached.
	step_ids=m.enemies.keys();step_cursor=0;step_delta=delta;step_sliced=sliced;step_active=true
	return true

func cancel_step():
	step_active=false;step_ids.clear();step_cursor=0;step_delta=0.0;step_sliced=false
	defender_snapshot_active=false

func advance_step(limit:int,hero:Vector3)->bool:
	if not step_active:return true
	if m.phase!="wave":cancel_step();projectiles.clear();return true
	begin_defender_snapshot(hero)
	var stop=mini(step_ids.size(),step_cursor+maxi(0,limit))
	while step_cursor<stop:
		var id:int=step_ids[step_cursor];step_cursor+=1
		if not m.enemies.has(id):continue
		var e: Dictionary=m.enemies[id]
		if e.hp<=0:
			m.ryo.award_enemy_bounty(e);m.enemies.erase(id);continue
		if step_sliced:
			if not e.has("simulation_revision"):e.simulation_revision=0
		else:e.erase("simulation_revision")
		tick_enemy(e,step_delta,hero)
		if m.phase!="wave":cancel_step();projectiles.clear();return true
	defender_snapshot_active=false
	if step_cursor<step_ids.size():return false
	cancel_step()
	if pending==0 and m.enemies.is_empty() and m.phase=="wave":
		projectiles.clear();m.gold+=100;m.phase="victory" if m.wave>=m.balance.waves.size() else "preparing"
		m.workforce.recover();m.update_vision(hero);m.events.append({"kind":m.phase});m.revision+=1
	return true

func soldier_gun_target(e:Dictionary,kind:String,id:int,hero:Vector3)->bool:
	if not valid_target(kind,id,hero):return false
	var point=target_point(kind,id,hero,e)
	if e.pos.distance_squared_to(point)>pow(_simulation_stats(1).range,2):return false
	var from:Vector3=e.pos+Basis(Vector3.UP,float(e.facing))*SoldierVisual.source_point(SoldierCombat.MUZZLE)
	var ignore=id if kind=="building" else -1
	if kind=="worker" and m.workers[id].state=="garrison":ignore=m.workers[id].job
	# Enlarged soldiers aim at the live target in 3D; cover still blocks shots.
	return navigation.line_clear(from,point,ignore)

func soldier_melee_proximity(e:Dictionary,kind:String,id:int,hero:Vector3)->bool:
	if not valid_target(kind,id,hero):return false
	# Acquire close targets independently of the current weapon direction. The
	# caller still turns through native yaw limits before beginning the attack.
	var direction=target_point(kind,id,hero,e)-Vector3(e.pos)
	var yaw=float(e.facing)
	if Vector2(direction.x,direction.z).length_squared()>.001:yaw=atan2(-direction.x,-direction.z)
	return _soldier_segment_contact(e,kind,id,hero,yaw)

func soldier_melee_contact(e:Dictionary,kind:String,id:int,hero:Vector3)->bool:
	return _soldier_segment_contact(e,kind,id,hero,float(e.facing))

func _soldier_segment_contact(e:Dictionary,kind:String,id:int,hero:Vector3,yaw:float)->bool:
	if not valid_target(kind,id,hero):return false
	var basis=Basis(Vector3.UP,yaw)
	var from:Vector3=e.pos+basis*SoldierVisual.source_point(SoldierCombat.MELEE_FROM)
	var to:Vector3=e.pos+basis*SoldierVisual.source_point(SoldierCombat.MELEE_TO)
	var ignore=id if kind=="building" else -1
	if not navigation.line_clear(from,to,ignore):return false
	if kind=="building":
		var b:Dictionary=m.buildings[id]
		var point:Vector3=navigation.building_point(b,to)
		point.y=clampf(to.y,m.center(b).y,m.center(b).y+Profile.height(b.kind))
		return Geometry3D.get_closest_point_to_segment(point,from,to).distance_to(point)<.18
	var foot:Vector3=hero
	if kind=="worker":
		foot=arrows.worker_point(m.workers[id])-Vector3.UP*1.6
	elif kind=="defender":foot=m.defenders[id].pos
	# Native target body capsule; the original outgoing attack is a segment,
	# not a sphere around a stale target and not permanent body-touch damage.
	var pair=Geometry3D.get_closest_points_between_segments(from,to,foot+Vector3.UP*.4,foot+Vector3.UP*1.8)
	return pair[0].distance_to(pair[1])<.576

func soldier_attack_tick(e:Dictionary,delta:float,hero:Vector3):
	e.velocity=Vector3.ZERO;e.attack=true
	if not SoldierCombat.active(e):
		e.action="walk";e.attack=false;return
	var can_combo=true
	if e.variant==0 and e.get("soldier_phase","")=="melee_a" and float(e.get("soldier_tick",0))+delta*30>=20:
		can_combo=soldier_melee_contact(e,e.strike_kind,e.strike_id,hero)
	var events=SoldierCombat.advance(e,delta,{"continue_combo":can_combo})
	for event in events:
		match event.kind:
			"muzzle":
				var point:Vector3=e.pos+Basis(Vector3.UP,float(e.facing))*SoldierVisual.source_point(event.local_origin)
				m.events.append({"kind":"enemy_arrow_impact","id":-1,"point":point,"muzzle":true,"facing":e.facing})
			"bullet":
				if soldier_gun_target(e,e.strike_kind,e.strike_id,hero):
					arrows.launch_soldier(projectiles,e,e.strike_kind,e.strike_id,target_point(e.strike_kind,e.strike_id,hero,e),float(event.damage)*m.balance.enemy_damage_mult)
			"melee":
				if not soldier_melee_contact(e,e.strike_kind,e.strike_id,hero):continue
				var damage=float(event.damage)*m.balance.enemy_damage_mult
				match e.strike_kind:
					"hero":m.events.append({"kind":"hero_hit","amount":damage,"from":e.pos})
					"defender":m.events.append({"kind":"defender_hit","id":e.strike_id,"amount":damage,"from":e.pos})
					"worker":m.damage_worker(e.strike_id,damage)
					"building":m.damage_building(e.strike_id,damage)
			"done":
				e.action="walk";e.attack=false;e.attack_progress=0.0;e.clock=0.0

func soldier_close_step(e:Dictionary,delta:float,hero:Vector3,kind:String,id:int):
	if not valid_target(kind,id,hero):return
	var point=target_point(kind,id,hero,e);point.y=e.pos.y
	if horizontal_distance(e.pos,point)>6.0:return
	if not turn(e,point,delta):return
	var before:Vector3=e.pos
	var step:float=minf(_simulation_stats(e.variant).speed*e.get("slow",1.0)*delta,before.distance_to(point))
	var obstacle=swept_move(e,before.direction_to(point)*step)
	if obstacle>=0:e.route_obstacle=obstacle
	e.velocity=(e.pos-before)/maxf(.001,delta)
	e.walk_phase=fmod(e.walk_phase+TAU*e.pos.distance_to(before)/_simulation_stats(e.variant).stride,TAU)
