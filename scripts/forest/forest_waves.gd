extends RefCounted
const Balance=preload("res://scripts/forest/core_balance.gd")
const Roles=preload("res://scripts/forest/forest_enemy_roles.gd")
const Navigation=preload("res://scripts/forest/forest_enemy_navigation.gd")
const Routes=preload("res://scripts/forest/forest_routes.gd")
const COUNTS=[360,540,716,896,1196]
const SPAWN_INTERVAL=.13 # Retry blocked entrances without releasing the next group early.
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
var remaining_counts: Array=[]
var boss_pending: Dictionary={}
var spawned=0
var spawn_groups:Dictionary={}
var navigation
var routes
const SPAWN_QUERY_CELL=16.0
var spawn_query_active=false
var spawn_query_buckets:Dictionary={}
var spawn_query_max_radius=0.0
var stats_cache:Dictionary={}
var stats_size=NAN
var stats_speed=NAN
var stats_health=NAN
var stats_damage=NAN
var stats_boss_health=NAN
var stats_boss_speed=NAN
func _init(model):
	reference=weakref(model);navigation=Navigation.new(model);routes=Routes.new(model)
func begin()->bool:
	if m.phase!="preparing" or m.shrine().is_empty() or (not m.has_enemy_camps() and m.wave>=m.balance.waves.size()):return false
	m.wave=1 if m.has_enemy_camps() else m.wave+1;m.phase="wave"
	remaining_counts=m.balance.waves[m.wave-1].duplicate();pending=0
	if not m.has_enemy_camps():
		for count in remaining_counts:pending+=count
	boss_pending.clear()
	if remaining_counts[Balance.TYPES.find(Roles.BOSS)]>0:boss_pending[0]=true
	spawn_clock=2.0;spawned=0;spawn_groups.clear()
	rng.seed=m.seed_value+m.wave*7919;routes.portal_cursor=0
	return true
func spawn_enemy(variant: int,point: Vector3,source:int=-1)->Dictionary:
	var id: int=m.next_id;m.next_id+=1;var data=_simulation_stats(variant)
	var group:int=spawn_groups.get(source,{}).get("number",1)
	var health_scale=1.0+.2*(group-1)
	# Intern the mirror keys used by every native physics publication.
	var e={"id":id,&"pos":point,&"hp":data.hp,"max_hp":data.hp,"variant":variant,"enemy_size":m.balance.enemy_size_mult if variant in Roles.RIGID_TYPES else 1.0,"clock":0.0,"path":[],"nav":-1,"target":Vector2i.ZERO,"stun":0.0,&"velocity":Vector3.ZERO,"attack":false,
		"action":"walk","action_left":0.0,"target_kind":"","target_id":-1,&"facing":atan2(point.x,point.z),"walk_phase":0.0,"attack_progress":0.0,"attack_point":point,"strike_kind":"","strike_id":-1,"route_obstacle":-1,"frozen":0.0,"slow":1.0,"slow_left":0.0}
	e.hp*=health_scale;e.max_hp=e.hp
	e.reinforcement_group=group;e.health_scale=health_scale;e.damage_scale=1.0+.1*(group-1);e.xp_reward_tenths=10+2*(group-1)
	m.enemies[id]=e
	var runtime=m.get("army_runtime")
	if is_instance_valid(runtime) and runtime.has_method("queue_enemy_arrival"):runtime.queue_enemy_arrival(e)
	return e
func role_stats(variant:int)->Dictionary:
	# Public callers may mutate their copy. Simulation only borrows frozen rows.
	return _simulation_stats(variant).duplicate()
func _simulation_stats(variant:int)->Dictionary:
	var balance=m.balance
	if stats_size!=balance.enemy_size_mult or stats_speed!=balance.enemy_speed_mult or stats_health!=balance.enemy_health_mult or stats_damage!=balance.enemy_damage_mult or stats_boss_health!=balance.boss_health or stats_boss_speed!=balance.boss_speed:
		stats_cache.clear();stats_size=balance.enemy_size_mult
		stats_speed=balance.enemy_speed_mult;stats_health=balance.enemy_health_mult;stats_damage=balance.enemy_damage_mult
		stats_boss_health=balance.boss_health;stats_boss_speed=balance.boss_speed
	if stats_cache.has(variant):return stats_cache[variant]
	var stats=Balance.EnemyBalance.base_stats(balance,variant)
	if variant in Roles.RIGID_TYPES:
		stats.stride*=stats_size
		if variant!=1:stats.range*=stats_size
	stats.speed*=stats_speed
	if variant!=Roles.BOSS:stats.hp*=stats_health
	stats.damage*=stats_damage
	stats.make_read_only();stats_cache[variant]=stats
	return stats
func active_cap()->int:return 1000 if m.enemy_camps_prototype else ACTIVE_CAP
func spawn_one(reserved: Array=[],portal_index:int=-1)->bool:
	m.sync_enemy_records()
	if m.enemies.size()>=active_cap():return false
	if m.has_enemy_camps():
		if m.phase!="wave" or m.active_enemy_camps()==0:return false
		if remaining_counts.all(func(count):return count==0):remaining_counts=m.balance.waves[0].duplicate()
	elif pending<=0:return false
	if not m.portals.is_empty():return spawn_from_portals(reserved,portal_index)
	if remaining_counts[Balance.TYPES.find(Roles.BOSS)]>0 and spawn_skullpion(reserved):
		consume_slot(Balance.TYPES.find(Roles.BOSS));return true
	for offset in Balance.TYPES.size():
		var slot=(spawned+offset)%Balance.TYPES.size()
		if Balance.TYPES[slot]==Roles.BOSS or remaining_counts[slot]<=0:continue
		var variant=Balance.TYPES[slot]
		var radius=Roles.footprint_radius(variant,m.balance.enemy_size_mult)
		var edge=mini(m.navigation_region.end.x-1,floori((m.world_bounds().end.x-radius)/m.CELL))
		var angle=atan2(SPAWN_DIRECTION.x,SPAWN_DIRECTION.y)+rng.randf_range(-.09,.09)
		var direction=Vector2(sin(angle),cos(angle));direction*=float(edge)/maxf(absf(direction.x),absf(direction.y))
		var c=m.nearest_open(Vector2i(roundi(direction.x),roundi(direction.y)),true)
		var p: Vector3=m.point(c)
		if not m.navigation_region.has_point(c) or not navigation.move_clear(p,radius) or not navigation.full_unseen(p,variant):continue
		var clear=true
		for previous in reserved:
			if p.distance_to(previous)<maxf(1.8,2*radius+.35):clear=false;break
		if not clear:continue
		spawn_enemy(variant,p);consume_slot(slot);reserved.append(p);return true
	return false
func consume_slot(slot:int):
	remaining_counts[slot]-=1;spawned+=1
	if not m.has_enemy_camps():pending-=1
	if remaining_counts[Balance.TYPES.find(Roles.BOSS)]==0:boss_pending.clear()
func spawn_from_portals(reserved: Array,portal_index:int=-1)->bool:
	if remaining_counts[Balance.TYPES.find(Roles.BOSS)]>0 and spawn_skullpion(reserved,portal_index):
		consume_slot(Balance.TYPES.find(Roles.BOSS));return true
	for offset in Balance.TYPES.size():
		var slot=(spawned+offset)%Balance.TYPES.size()
		if Balance.TYPES[slot]==Roles.BOSS or remaining_counts[slot]<=0 or not routes.spawn(Balance.TYPES[slot],reserved,portal_index):continue
		consume_slot(slot);return true
	return false

func spawn_skullpion(reserved:Array,portal_index:int=-1)->bool:
	if not m.portals.is_empty() and routes.spawn(Roles.BOSS,reserved,portal_index):return true
	# A broad boss can enter beyond a cramped portal mouth without blocking a wave.
	var anchors=[]
	for index in m.portals.size():
		if portal_index>=0 and index!=portal_index:continue
		var portal:Dictionary=m.portals[index]
		if float(portal.get("hp",1.0))>0:anchors.append({"point":routes.exit_point(portal,Roles.BOSS),"forward":routes.direction(portal),"portal_index":index})
	if m.portals.is_empty():anchors.append({"point":m.point(SPAWN_DIRECTION*20),"forward":Vector3.BACK})
	for anchor in anchors:
		var side=Vector3(-anchor.forward.z,0,anchor.forward.x)
		for distance in [6,12,18,24,30]:
			for lateral in [0,6,-6,12,-12]:
				var point:Vector3=anchor.point+anchor.forward*distance+side*lateral
				point.y=m.surface_height(point.x,point.z)
				if not navigation.move_clear(point,Roles.footprint_radius(Roles.BOSS)) or not spawn_space_clear(point,Roles.footprint_radius(Roles.BOSS)):continue
				if horizontal_distance(point,m.hero_position)<20:continue
				var probe={"pos":point,"variant":Roles.BOSS,"facing":0.0}
				if navigation.fitted_blocker(probe,point)>=0:continue
				var enemy=spawn_enemy(Roles.BOSS,point,int(anchor.get("portal_index",-1)));enemy.facing=atan2(-anchor.forward.x,-anchor.forward.z)
				if anchor.has("portal_index"):enemy.portal_index=anchor.portal_index;routes.portal_cursor=(int(anchor.portal_index)+1)%m.portals.size()
				reserved.append(point);register_spawn(enemy);return true
	return false

func begin_spawn_query():
	m.sync_enemy_records()
	spawn_query_buckets.clear();spawn_query_max_radius=0.0;spawn_query_active=true
	for enemy in m.enemies.values():register_spawn(enemy)

func register_spawn(enemy:Dictionary):
	if not spawn_query_active:return
	var radius=Roles.visibility_radius(int(enemy.variant),m.balance.enemy_size_mult)
	spawn_query_max_radius=maxf(spawn_query_max_radius,radius)
	var point:Vector3=enemy.pos
	var cell=Vector2i(floori(point.x/SPAWN_QUERY_CELL),floori(point.z/SPAWN_QUERY_CELL))
	if not spawn_query_buckets.has(cell):spawn_query_buckets[cell]=[]
	spawn_query_buckets[cell].append({"pos":point,"radius":radius})

func spawn_space_clear(point:Vector3,radius:float)->bool:
	if not spawn_query_active:m.sync_enemy_records()
	if not spawn_query_active:
		for enemy in m.enemies.values():
			if point.distance_to(enemy.pos)<radius+Roles.visibility_radius(int(enemy.variant),m.balance.enemy_size_mult)+.35:return false
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

func enemy_started_attack(id:int):
	var source:int=m.enemies.get(id,{}).get("portal_index",-1)
	var group:Dictionary=spawn_groups.get(source,{})
	if not group.is_empty() and group.members.has(id):group.engaged=true

func group_ready(source:int)->bool:
	if not spawn_groups.has(source):spawn_groups[source]={"members":{},"engaged":false,"target_size":m.balance.spawn_group_start,"number":1}
	var group:Dictionary=spawn_groups[source]
	if group.members.size()>=group.target_size:
		if not group.engaged:
			# A wiped-out group must not strand the remaining wave.
			for id in group.members:
				if float(m.enemies.get(id,{}).get("hp",0))>0:return false
		group.members.clear();group.engaged=false;group.target_size+=m.balance.spawn_group_growth;group.number+=1
	return true

func spawn_batch()->int:
	var released=0;var reserved: Array=[]
	var portal_mode=not m.portals.is_empty()
	var sources:Array=[];var cursor:int=routes.portal_cursor
	for offset in range(m.portals.size() if portal_mode else 1):
		var source:int=(cursor+offset)%m.portals.size() if portal_mode else -1
		if portal_mode and float(m.portals[source].get("hp",1.0))<=0:continue
		if group_ready(source):sources.append(source)
	if sources.is_empty():return 0
	if portal_mode:begin_spawn_query()
	# Portal searches exhaust every type/portal/slot. Repeating a failed search
	# cannot find a new opening before the world advances. Random edge entries
	# retain their independent retries.
	for source in sources:
		var group:Dictionary=spawn_groups[source]
		for attempt in range(SPAWN_ATTEMPTS):
			if group.members.size()>=group.target_size or (pending<=0 and not m.has_enemy_camps()) or m.enemies.size()>=active_cap():break
			if spawn_one(reserved,source):
				released+=1;group.members[m.next_id-1]=true
			elif portal_mode:break
	if portal_mode:end_spawn_query()
	return released
func horizontal_distance(a: Vector3,b: Vector3)->float:return Vector2(a.x-b.x,a.z-b.z).length()
func tick(delta:float,hero:Vector3):
	if m.phase!="wave":return
	if m.has_enemy_camps():
		spawn_clock-=delta
		if spawn_clock<=0 and m.enemies.size()<active_cap() and m.active_enemy_camps()>0:spawn_batch();spawn_clock=SPAWN_INTERVAL
		return
	spawn_clock-=delta
	if pending>0 and spawn_clock<=0 and m.enemies.size()<active_cap():spawn_batch();spawn_clock=SPAWN_INTERVAL
	if pending==0 and m.enemies.is_empty():
		m.gold+=100;m.phase="victory" if m.wave>=m.balance.waves.size() else "preparing"
		m.workforce.recover();m.update_vision(hero);m.events.append({"kind":m.phase});m.revision+=1
