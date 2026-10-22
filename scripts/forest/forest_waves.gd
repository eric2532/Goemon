extends RefCounted
const Roles=preload("res://scripts/forest/forest_enemy_roles.gd")
const Navigation=preload("res://scripts/forest/forest_enemy_navigation.gd")
const Routes=preload("res://scripts/forest/forest_routes.gd")
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
var navigation
var routes
const SPAWN_QUERY_CELL=16.0
var spawn_query_active=false
var spawn_query_buckets:Dictionary={}
var spawn_query_max_radius=0.0
var stats_cache:Dictionary={}
var stats_speed=NAN
var stats_health=NAN
var stats_damage=NAN
var stats_boss_health=NAN
var stats_boss_speed=NAN
func _init(model):
	reference=weakref(model);navigation=Navigation.new(model);routes=Routes.new(model)
func begin()->bool:
	if m.phase!="preparing" or m.wave>=m.balance.waves.size() or m.shrine().is_empty():return false
	m.wave+=1;m.phase="wave";remaining_counts=m.balance.waves[m.wave-1].duplicate();pending=0
	# Suppress large special enemies in the effective queue only. Saved/editor
	# composition stays intact so it can be restored without migrating maps.
	remaining_counts[2]=0
	for type in [0,1,3]:pending+=remaining_counts[type]
	boss_pending.clear()
	spawn_clock=2.0;spawned=0;giant_pending=remaining_counts[2]>0
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
func horizontal_distance(a: Vector3,b: Vector3)->float:return Vector2(a.x-b.x,a.z-b.z).length()
func tick(delta:float,hero:Vector3):
	if m.phase!="wave":return
	spawn_clock-=delta
	if pending>0 and spawn_clock<=0 and m.enemies.size()<ACTIVE_CAP:spawn_batch();spawn_clock=SPAWN_INTERVAL
	if pending==0 and m.enemies.is_empty():
		m.gold+=100;m.phase="victory" if m.wave>=m.balance.waves.size() else "preparing"
		m.workforce.recover();m.update_vision(hero);m.events.append({"kind":m.phase});m.revision+=1
