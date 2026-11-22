extends RefCounted
const Winter=preload("res://scripts/forest/forest_frostpass.gd")
const Prayer=preload("res://scripts/forest/forest_black_prayer.gd")
const Falken=preload("res://scripts/forest/crowd/falken_sprites.gd")
const Balance=preload("res://scripts/forest/core_balance.gd")
const Roles=preload("res://scripts/forest/forest_enemy_roles.gd")
const Navigation=preload("res://scripts/forest/forest_enemy_navigation.gd")
const Routes=preload("res://scripts/forest/forest_routes.gd")
const ZombieMaze=preload("res://scripts/forest/forest_zombie_maze.gd")
const Zombie=preload("res://scripts/forest/crowd/zombie_sprites.gd")
const Captain=preload("res://scripts/forest/crowd/captain_sprites.gd")
const Grave=preload("res://scripts/forest/crowd/grave_sprites.gd")
const Ruby=preload("res://scripts/forest/crowd/ruby_boss_sprites.gd")
const Habaru=preload("res://scripts/forest/crowd/habaru_sprites.gd")
const Undersea=preload("res://scripts/forest/crowd/undersea_sprites.gd")
const Patrols=preload("res://scripts/forest/crowd/falan_frontier_sprites.gd")
const Shalena=preload("res://scripts/forest/crowd/shalena_sprites.gd")
const PatrolData=preload("res://assets/maps/falan/freyja_patrol_data.gd")
const MapEncounters=preload("res://assets/maps/falan/map_encounter_data.gd")
const CaveProgression=preload("res://scripts/forest/cave_progression.gd")
const Pets=preload("res://scripts/forest/pet_catalog.gd")
const Formation=preload("res://scripts/forest/party_formation.gd")
const COUNTS=[360,540,716,896,1196]
const SPAWN_INTERVAL=.13 # Retry blocked entrances without releasing the next group early.
const WAVE_SECONDS=60.0
const SLIME_WAVE_SECONDS=30.0
const SLIME_SIDES=[Vector3.FORWARD,Vector3.RIGHT,Vector3.BACK,Vector3.LEFT]
const SLIME_SIDE_NAMES=["NORTH","EAST","SOUTH","WEST"]
const SLIMES_PER_WAVE=4*Roles.SLIME_COLORS
const SLIME_ACTIVE_CAP=8*SLIMES_PER_WAVE
const SLIME_LANES=13
const SLIME_ENTRY_SLOTS=SLIME_LANES*12
const SLIME_REBIRTH_GROWTH=1.1
const ACTIVE_CAP=240
const ADVENTURE_PACK_SIZE=3
const ROAD_SPAWN_INTERVAL=.2
const SPAWN_ATTEMPTS=12
const RANDOM_SPAWN_INTERVAL=1.0
const RANDOM_SPAWN_COUNT=3
const RANDOM_SPAWN_SOURCE=-2
const SPAWN_DIRECTION=Vector2i.DOWN # South (+Z), facing the starter fort's gate.
var reference: WeakRef
var m:
	get:return reference.get_ref()
var pending=0
var spawn_clock=0.0
var random_spawn_clock=RANDOM_SPAWN_INTERVAL
var kill_spawn_pending=0
var wave_clock=WAVE_SECONDS
var crossgate_pet_test=false
var slime_placement_cursors=[0,0,0,0]
var slime_arrivals=[0,0,0,0]
var slime_side_cursor=0
var slime_rebirths=[[],[],[],[]]
var slime_rebirth_pending=0
var slime_returned=0
var released_waves=0
var rng=RandomNumberGenerator.new()
var giant_pending=false
var remaining_counts: Array=[]
var boss_pending: Dictionary={}
var spawned=0
var dungeon_boss_id=0
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
var patrol_source=Patrols
var patrol_levels:Array=[]
var patrol_posts:Array
var patrol_frame:Transform2D
var patrol_owners:Dictionary={}
var patrol_cursor=0
var patrol_fits=PackedFloat32Array()
var habaru_cells:Array=[]
var elite_posts:Dictionary={}
func _init(model):
	reference=weakref(model);navigation=Navigation.new(model);routes=Routes.new(model)
	crossgate_pet_test=model.uses_slime_waves()
	var area:String=model.falan_road if not model.falan_road.is_empty() else model.falan_area
	patrol_posts=PatrolData.POSTS.get(area,[]).duplicate()
	if area=="east_gate":patrol_posts.append_array(PatrolData.POSTS.east_coast)
	for i in patrol_posts.size():
		var post:Vector4i=patrol_posts[i]
		if post.z==1 and post.w in [1004,1005,1007] and i%3==0:patrol_posts[i]=Vector4i(post.x,post.y,24,post.w)
	for i in patrol_posts.size():
		var post:Vector4i=patrol_posts[i]
		if post.z==Patrols.GOBLIN and i%4==0 and (MapEncounters.ZONES[post.w][1] & (1<<24))!=0:patrol_posts[i]=Vector4i(post.x,post.y,24,post.w)
	if area=="north_coast":patrol_posts.clear()
	for post:Vector4i in MapEncounters.POSTS.get("east_coast" if area=="east_gate" else area,[]):
		if not patrol_posts.any(func(old):return Vector2(old.x,old.y).distance_squared_to(Vector2(post.x,post.y))<16):patrol_posts.append(post)
	if model.falan_floor==13001:patrol_posts=MapEncounters.ROOM_POSTS[13001].duplicate()
	if area in ["east_gate","east_coast","north_coast"]:
		var occupied={}
		for post:Vector4i in patrol_posts:occupied[Vector2i(post.x,post.y)]=true
		for post:Vector4i in patrol_posts.duplicate():
			var gate_post=area=="east_gate" and post in PatrolData.POSTS.east_gate
			var offsets=[Vector2i(0,-2),Vector2i(0,2)] if gate_post else [Vector2i(-2,0),Vector2i(2,0)]
			for offset:Vector2i in offsets:
				var cell=Vector2i(post.x,post.y)+offset
				if occupied.has(cell):continue
				var zone:Array=MapEncounters.ZONES.get(post.w,[])
				if not zone.is_empty() and not zone[0].has_point(cell):continue
				occupied[cell]=true
				patrol_posts.append(Vector4i(cell.x,cell.y,post.z,post.w))
	if not patrol_posts.is_empty() and model.falan_floor!=13001:patrol_frame=model.FalanFrontier.Regions.frame(area).inverse()
	if patrol_posts.any(func(post):return post.z==Patrols.BANDIT) and model.falan_floor!=13001:
		var mask:Image=model.terrain.mask_texture().get_image()
		var origin:Vector2=model.terrain.mask_origin()
		var clear_posts=[]
		for post:Vector4i in patrol_posts:
			var clear=true
			if post.z==Patrols.BANDIT:
				var pixel=Vector2i(((patrol_frame*(Vector2(post.x,post.y)*3.0)-origin)/3.0).round())
				for y in range(-12,13):
					for x in range(-12,13):
						var at=pixel+Vector2i(x,y)
						if x*x+y*y<169 and Rect2i(Vector2i.ZERO,mask.get_size()).has_point(at) and mask.get_pixelv(at).g>=.56:clear=false
			if clear:clear_posts.append(post)
		patrol_posts=clear_posts
	if Shalena.owns(model.falan_floor):
		patrol_source=Shalena;patrol_posts.clear();patrol_frame=Transform2D.IDENTITY
		for row in Shalena.posts(model.falan_floor,model.seed_value):patrol_posts.append(row[0]);patrol_levels.append(row[1])
	if not patrol_posts.is_empty():patrol_fits=preload("res://scripts/forest/crowd/pet_dimensions.gd").scales(patrol_source.ROOT,patrol_source.motions())
	if model.falan_floor==0:
		var elite_rng=RandomNumberGenerator.new();elite_rng.seed=model.seed_value+area.hash()
		# One elite outcome per shuffled bag of twenty outdoor posts.
		for first in range(0,patrol_posts.size(),20):
			var slot=first+elite_rng.randi_range(0,19)
			if slot<patrol_posts.size():elite_posts[slot]=true
func begin()->bool:
	if m.phase!="preparing":return false
	if not crossgate_pet_test and ((not m.survival_run and m.shrine().is_empty()) or (not m.has_enemy_camps() and m.wave>=m.balance.waves.size())):return false
	m.wave=1;m.phase="wave";released_waves=1;wave_clock=SLIME_WAVE_SECONDS if crossgate_pet_test else WAVE_SECONDS
	remaining_counts.clear();pending=0;boss_pending.clear()
	if not crossgate_pet_test:
		remaining_counts=m.balance.waves[m.wave-1].duplicate()
		for count in remaining_counts:pending+=count
		if remaining_counts[Balance.TYPES.find(Roles.BOSS)]>0:boss_pending[0]=true
	spawn_clock=0.0;random_spawn_clock=RANDOM_SPAWN_INTERVAL;kill_spawn_pending=0;spawned=0;dungeon_boss_id=0;spawn_groups.clear()
	if not patrol_posts.is_empty():spawn_clock=1.0
	patrol_owners.clear();patrol_cursor=-1 if patrol_source==Shalena else 0
	slime_placement_cursors.fill(0);slime_arrivals.fill(0);slime_side_cursor=0
	for queue in slime_rebirths:queue.clear()
	slime_rebirth_pending=0;slime_returned=0
	rng.seed=m.seed_value+m.wave*7919;routes.portal_cursor=0
	m.wave_started.emit()
	return true
func schedule_left()->float:
	return maxf(0,(m.balance.waves.size()-maxi(1,released_waves))*WAVE_SECONDS+wave_clock)
func clock_text(seconds:float)->String:
	var whole=ceili(maxf(0,seconds))
	return "%02d:%02d"%[whole/60,whole%60]
func slime_side_total(side:int)->int:
	return maxi(0,released_waves-2*side)*Roles.SLIME_COLORS
func slime_scheduled_total()->int:
	var total=0
	for side in SLIME_SIDES.size():total+=slime_side_total(side)
	return total
func slime_active_sides()->int:
	return mini(4,(released_waves+1)/2)
func countdown_text()->String:
	if crossgate_pet_test:
		if m.phase=="preparing":return "SLIME SURVIVAL · 1 → 4 SIDES\n29 PER SIDE EVERY 00:30"
		var sides=slime_active_sides()
		var entrances="/".join(SLIME_SIDE_NAMES.slice(0,sides).map(func(side):return side.left(1)))
		if sides<4 and released_waves%2==0 and wave_clock<=10.000001:
			entrances+=" · %s OPENS %s"%[SLIME_SIDE_NAMES[sides].left(1),clock_text(wave_clock)]
		return "WAVE %d · NEXT %s\n%s\n%d ACTIVE · %d QUEUED"%[m.wave,clock_text(wave_clock),entrances,m.enemies.size(),slime_scheduled_total()-spawned+slime_rebirth_pending]
	var total:int=m.balance.waves.size()
	if m.phase=="preparing":return "%d WAVES · %s\nONE WAVE EVERY 01:00"%[total,clock_text(total*WAVE_SECONDS)]
	if released_waves>=total:
		return "FINAL WAVE %d / %d\nTOTAL %s"%[total,total,clock_text(schedule_left())] if wave_clock>0 else "FINAL WAVE %d / %d\nCLEAR THE ENEMIES"%[total,total]
	return "WAVE %d / %d IN %s\nTOTAL %s"%[released_waves+1,total,clock_text(wave_clock),clock_text(schedule_left())]
func spawn_enemy(variant: int,point: Vector3,source:int=-1,skin:int=0)->Dictionary:
	var id: int=m.next_id;m.next_id+=1;var data=_simulation_stats(variant)
	var group:int=spawn_groups.get(source,{}).get("number",1)
	var health_scale=1.0+.2*(group-1)
	# Intern the mirror keys used by every native physics publication.
	var e={"id":id,&"pos":point,&"hp":data.hp,"max_hp":data.hp,"variant":variant,"enemy_size":Roles.size_multiplier(variant,m.balance.enemy_size_mult),"clock":0.0,"path":[],"nav":-1,"target":Vector2i.ZERO,"stun":0.0,&"velocity":Vector3.ZERO,"attack":false,
		"action":"walk","action_left":0.0,"target_kind":"","target_id":-1,&"facing":atan2(point.x,point.z),"walk_phase":0.0,"attack_progress":0.0,"attack_point":point,"strike_kind":"","strike_id":-1,"route_obstacle":-1,"frozen":0.0,"slow":1.0,"slow_left":0.0}
	if variant in [Roles.SLIME,Roles.CAVE_BEAR]:e.skin=skin
	if variant in [Roles.BOSS,Roles.DARK_LUMINA_2,Roles.DARK_LUMINA_3]:e.boss=true
	e.hp*=health_scale;e.max_hp=e.hp
	e.reinforcement_group=group;e.health_scale=health_scale;e.damage_scale=1.0+.1*(group-1);e.xp_reward_tenths=10+2*(group-1)
	m.enemies[id]=e
	var runtime=m.get("army_runtime")
	if is_instance_valid(runtime) and runtime.has_method("queue_enemy_arrival"):runtime.queue_enemy_arrival(e)
	return e
func mark_dungeon_boss(enemy:Dictionary):
	enemy.boss=true;dungeon_boss_id=enemy.id
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
	if variant!=Roles.SLIME:
		stats.speed*=stats_speed
		if variant!=Roles.BOSS:stats.hp*=stats_health
		stats.damage*=stats_damage
	elif not patrol_posts.is_empty():stats.merge(patrol_source.STATS,true)
	stats.make_read_only();stats_cache[variant]=stats
	return stats
func active_cap()->int:
	if crossgate_pet_test:return SLIME_ACTIVE_CAP
	return 1000 if m.enemy_camps_prototype else ACTIVE_CAP
func spawn_one(reserved: Array=[],portal_index:int=-1)->bool:
	m.sync_enemy_records()
	if m.enemies.size()>=active_cap():return false
	if pending<=0 or m.phase!="wave" or (m.has_enemy_camps() and m.active_enemy_camps()==0):return false
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
	pending-=1
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

func enemy_defeated(enemy:Dictionary={}):
	if m.phase!="wave":return
	if not crossgate_pet_test:kill_spawn_pending+=2
	elif enemy.get("variant",-1)==Roles.SLIME and enemy.has("slime_side"):
		slime_rebirths[enemy.slime_side].append({"skin":enemy.skin,"level":int(enemy.get("level",1))+1,"health_scale":enemy.health_scale*SLIME_REBIRTH_GROWTH,"damage_scale":enemy.damage_scale*SLIME_REBIRTH_GROWTH,"wave":released_waves+1})
		slime_rebirth_pending+=1

func spawn_random_batch(from_kills:bool=false)->int:
	if m.phase!="wave" or (kill_spawn_pending if from_kills else pending)<=0 or m.enemies.size()>=active_cap() or (m.has_enemy_camps() and m.active_enemy_camps()==0):return 0
	var bounds:Rect2=m.world_bounds().grow(-24)
	var runtime=m.get("army_runtime")
	if is_instance_valid(runtime) and runtime.navigation_revision!=m.navigation_revision:return 0
	var destinations=[m.point(m.shrine_entry())]
	var center:Vector3=m.fort_center()
	for gate in m.buildings.values():
		if gate.kind=="gate" and not gate.get("breached",false):
			var exterior:Vector3=m.center(gate)+navigation.gate_outward(gate)*12
			exterior.y=m.surface_height(exterior.x,exterior.z);destinations.append(exterior)
	var anchor=Vector2.ZERO
	var released=0
	begin_spawn_query()
	for member in (mini(2,kill_spawn_pending) if from_kills else RANDOM_SPAWN_COUNT):
		if (kill_spawn_pending if from_kills else pending)<=0 or m.enemies.size()>=active_cap():break
		var slot=-1
		if not from_kills:
			for offset in Balance.TYPES.size():
				var candidate=(spawned+offset)%Balance.TYPES.size()
				if remaining_counts[candidate]>0 and Balance.TYPES[candidate] in Roles.WAVE_TYPES:slot=candidate;break
			if slot<0:break
		var variant:int=Roles.WAVE_TYPES[rng.randi_range(0,Roles.WAVE_TYPES.size()-1)] if from_kills else Balance.TYPES[slot]
		var radius=Roles.footprint_radius(variant,m.balance.enemy_size_mult)
		var visible_radius=Roles.visibility_radius(variant,m.balance.enemy_size_mult)
		var placed=false
		for attempt in SPAWN_ATTEMPTS*4:
			# Retry a different clearing if this group cannot enter the first one.
			if (member==0 or attempt>0) and attempt%SPAWN_ATTEMPTS==0:
				anchor=Vector2(rng.randf_range(bounds.position.x,bounds.end.x),rng.randf_range(bounds.position.y,bounds.end.y))
			var point:Vector3=m.point(m.cell_of(Vector3(anchor.x+rng.randf_range(-24,24),0,anchor.y+rng.randf_range(-24,24))))
			if horizontal_distance(point,center)<90 or horizontal_distance(point,m.hero_position)<maxf(20,visible_radius+2):continue
			if not navigation.move_clear(point,radius) or not spawn_space_clear(point,visible_radius):continue
			var clear=true
			for worker in m.workers.values():
				if worker.state!="wounded" and horizontal_distance(point,worker.pos)<visible_radius+1:clear=false;break
			if not clear:continue
			var direction:Vector3=center-point
			var facing=atan2(-direction.x,-direction.z)
			var probe={"pos":point,"variant":variant,"facing":facing}
			if navigation.fitted_blocker(probe,point)>=0:continue
			# Use the army's supported terrain connectivity, including off-road hills.
			if is_instance_valid(runtime):
				var reachable=false
				for destination:Vector3 in destinations:
					if runtime.native.can_reach(point,destination,radius):reachable=true;break
				if not reachable:continue
			elif not navigation.has_approach(probe,destinations):continue
			var enemy=spawn_enemy(variant,point,RANDOM_SPAWN_SOURCE)
			enemy.facing=facing;enemy.portal_index=RANDOM_SPAWN_SOURCE;enemy.road_path=[]
			register_spawn(enemy)
			if from_kills:kill_spawn_pending-=1
			else:consume_slot(slot)
			released+=1;placed=true;break
		if not placed:break
	end_spawn_query()
	return released

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
			if group.members.size()>=group.target_size or pending<=0 or m.enemies.size()>=active_cap():break
			if spawn_one(reserved,source):
				released+=1;group.members[m.next_id-1]=true
			elif portal_mode:break
	if portal_mode:end_spawn_query()
	return released
func horizontal_distance(a: Vector3,b: Vector3)->float:return Vector2(a.x-b.x,a.z-b.z).length()
func slime_entry(outward:Vector3,center:Vector3)->Vector3:
	var best=0.0
	var extent:Vector2=m.world_bounds().size
	var entry=center+outward*minf(140.0,minf(extent.x,extent.y)*.35)
	for portal:Dictionary in m.portals:
		var relative=Vector3(portal.x*m.CELL,0,portal.z*m.CELL)-center
		var along=relative.dot(outward)
		if along<=best or (absf(relative.x)>absf(relative.z))!=(outward.x!=0):continue
		best=along;entry=Routes.exit_point(portal,Roles.SLIME)
	return entry

func spawn_slimes(hero:Vector3):
	if spawned>=slime_scheduled_total() and slime_rebirth_pending==0:return
	if m.enemies.size()>=active_cap():return
	var runtime=m.army_runtime
	if not is_instance_valid(runtime) or runtime.navigation_revision!=m.navigation_revision:return
	var radius=Roles.SLIME_RADIUS*Roles.MAP_ENEMY_SCALE
	var spacing=2*radius+.55
	var padding=Vector3(radius+.4,Roles.height(Roles.SLIME),radius+.4)
	var center:Vector3=m.fort_center()
	var destinations=[Vector3.ZERO,Vector3.ZERO]
	for gate in m.buildings.values():
		if gate.kind=="gate" and not gate.get("breached",false):
			var point:Vector3=m.center(gate)+navigation.gate_outward(gate)*12
			point.y=m.surface_height(point.x,point.z);destinations.append(point)
	var reserved:Array[Vector3]=[]
	var start=slime_side_cursor
	for offset in SLIME_SIDES.size():
		var side=(start+offset)%SLIME_SIDES.size()
		var side_total=slime_side_total(side)
		var rebirths:Array=slime_rebirths[side]
		if slime_arrivals[side]>=side_total and (rebirths.is_empty() or rebirths[0].wave>released_waves):continue
		var outward:Vector3=SLIME_SIDES[side]
		var across=Vector3.UP.cross(outward)
		var entry=slime_entry(outward,center)
		# Check two approach distances to accommodate walls and uneven terrain.
		for approach in 2:
			var target=center+outward*(24.0+24.0*approach)
			target.y=m.surface_height(target.x,target.z)
			destinations[approach]=target
		var placed=0
		for attempt in 18:
			var slot:int=slime_placement_cursors[side]%SLIME_ENTRY_SLOTS
			slime_placement_cursors[side]+=1
			var lane=slot%SLIME_LANES
			var lateral=((lane+1)/2)*(1 if lane%2==1 else -1)
			var point=entry-outward*(slot/SLIME_LANES)*spacing+across*lateral*spacing
			point.y=m.surface_height(point.x,point.z)
			if horizontal_distance(point,hero)<radius+4 or not navigation.move_clear(point,radius):continue
			var bounds=AABB(point-padding,padding*2)
			if not runtime.query_aabb(bounds,0).is_empty() or not runtime.query_aabb(bounds,1).is_empty():continue
			if reserved.any(func(other):return horizontal_distance(point,other)<spacing):continue
			if not destinations.any(func(destination):return runtime.native.can_reach(point,destination,radius)):continue
			var returning=slime_arrivals[side]>=side_total
			var rebirth:Dictionary=rebirths.pop_front() if returning else {}
			var slime=spawn_enemy(Roles.SLIME,point,-1,rebirth.skin if returning else slime_arrivals[side]%Roles.SLIME_COLORS)
			slime.slime_side=side
			slime.enemy_name="史萊姆"
			slime.level=rebirth.level if returning else 1
			slime.xp_reward_tenths=Roles.level_xp_tenths(slime.level)
			if returning:
				slime.health_scale=rebirth.health_scale;slime.damage_scale=rebirth.damage_scale
				slime.hp*=slime.health_scale;slime.max_hp=slime.hp;slime_returned+=1;slime_rebirth_pending-=1
			else:
				spawned+=1;slime_arrivals[side]+=1
			slime.facing=atan2(outward.x,outward.z)
			reserved.append(point);placed+=1
			if m.enemies.size()>=active_cap():
				slime_side_cursor=(side+1)%SLIME_SIDES.size()
				return
			if placed==3 or (slime_arrivals[side]==side_total and (rebirths.is_empty() or rebirths[0].wave>released_waves)):break

func tick_outer_road(delta:float,hero:Vector3):
	var city_side:bool=not m.falan_road.is_empty()
	if city_side and hero.z<m.FalanFrontier.ENEMY_EDGE:return
	spawn_clock-=delta
	if spawn_clock>0:return
	spawn_clock=ROAD_SPAWN_INTERVAL if m.falan_area in ["east_gate","east_coast","north_coast"] else .5
	var released=0
	if patrol_cursor<0:
		var nearest=INF;patrol_cursor=0
		for slot in patrol_posts.size():
			var post:Vector4i=patrol_posts[slot]
			var distance=Vector2(post.x,post.y).distance_squared_to(Vector2(hero.x,hero.z))
			if distance>=64 and distance<nearest:nearest=distance;patrol_cursor=slot
	var start=patrol_cursor
	for offset in patrol_posts.size():
		if m.enemies.size()>=ACTIVE_CAP:return
		var slot=(start+offset)%patrol_posts.size()
		var owner:int=patrol_owners.get(slot,0)
		if owner<0 or m.enemies.has(owner):continue
		var post:Vector4i=patrol_posts[slot]
		var at:Vector2=Vector2(post.x,post.y) if m.falan_floor==13001 or patrol_source==Shalena else patrol_frame*(Vector2(post.x,post.y)*3.0)
		if m.FalanFrontier.Regions.village_contains(m.falan_area,at):
			patrol_owners[slot]=-1
			continue
		if m.falan_floor==13001 and is_instance_valid(m.army_runtime) and m.army_runtime.get_tree().get_meta("map_patrol_slain",{}).has(m.falan_floor*1000+slot):
			patrol_owners[slot]=-1
			continue
		var point=Vector3(at.x,m.surface_height(at.x,at.y),at.y)
		if point.distance_squared_to(hero)<64.0:continue
		var footprint=patrol_source.TREE_FOOTPRINT if patrol_source.tree(post.z) else patrol_source.FOOTPRINT
		var fit:float=patrol_fits[post.z]*Roles.MAP_ENEMY_SCALE
		if not navigation.move_clear(point,footprint*fit):
			patrol_owners[slot]=-1
			continue
		var elite=elite_posts.has(slot) and navigation.move_clear(point,footprint*fit*2.0)
		var escorts:Array[Vector3]=[]
		if elite:
			var yaw=atan2(point.x,point.z)
			var forward=Vector3(-sin(yaw),0,-cos(yaw));var right=Vector3(-forward.z,0,forward.x)
			var spacing=maxf(1.0,(footprint*fit*3.0+1.0)/7.0)
			for post_offset:Vector3 in Formation.POSTS:
				var at_=point+(right*post_offset.x+forward*post_offset.z)*spacing/m.falan_scale
				at_.y=m.surface_height(at_.x,at_.z)
				if at_.distance_squared_to(hero)<64.0 or not navigation.move_clear(at_,footprint*fit):break
				escorts.append(at_)
			elite=escorts.size()==5
			if elite and m.enemies.size()+6>ACTIVE_CAP:continue
		var enemy=spawn_patrol(post,point,elite,patrol_levels[slot] if patrol_source==Shalena else 0)
		if m.falan_floor==13001:enemy.map_patrol_slot=m.falan_floor*1000+slot
		elif patrol_source==Shalena:enemy.source_patrol_slot=slot
		if elite:
			for member in 5:
				var escort=spawn_patrol(post,escorts[member],false)
				escort.elite_leader=enemy.id;escort.escort_slot=member;escort.facing=enemy.facing
		patrol_owners[slot]=enemy.id
		patrol_cursor=(slot+1)%patrol_posts.size()
		released+=6 if elite else 1
		if released>=(ADVENTURE_PACK_SIZE if m.falan_area in ["east_gate","east_coast","north_coast"] else 1):return

func spawn_patrol(post:Vector4i,point:Vector3,elite:bool,level_:int=0)->Dictionary:
	var enemy=spawn_enemy(Roles.SLIME,point*m.falan_scale,-1,post.z)
	if patrol_source==Shalena:
		CaveProgression.apply(enemy,[Shalena.Data.SPECIES[post.z].name,level_,300,false],Shalena.STATS)
	else:
		var area:String=m.falan_road if not m.falan_road.is_empty() else m.falan_area
		var progression=Patrols.progression(post.z,Patrols.area_levels(area,post))
		var multiplier=3 if elite else 1
		enemy.level=progression.level;enemy.enemy_name=("Elite · " if elite else "")+Patrols.NAMES[post.z]
		enemy.hp=progression.hp*multiplier;enemy.max_hp=enemy.hp
		enemy.health_scale=enemy.hp/Patrols.STATS.hp
		enemy.damage_scale=progression.damage*multiplier/Patrols.STATS.damage
		enemy.xp_reward_tenths=progression.xp_reward_tenths*multiplier
	if elite:enemy.elite=true;enemy.body_scale=2.0
	enemy.frontier_patrol=true
	enemy.footprint=patrol_source.TREE_FOOTPRINT if patrol_source.tree(post.z) else patrol_source.FOOTPRINT
	enemy.patrol_radius=patrol_source.LEASH
	return enemy

func tick_habaru(hero:Vector3):
	if spawned!=0:return
	var runtime=m.army_runtime
	if not is_instance_valid(runtime):return
	var formation:Array=m.FalanFrontier.Regions.Sites.HABARU_FORMATION
	var tree:SceneTree=runtime.get_tree()
	var slain:Dictionary=tree.get_meta("habaru_slain",{})
	if not runtime.game.habaru_dialogue_seen and not slain.has(0):return
	for slot in formation.size():
		if slain.has(slot):continue
		var at:Vector2=formation[slot]
		var enemy=spawn_enemy(Roles.SLIME,m.world_point(at),-1,int(slot!=0))
		enemy.habaru_slot=slot
		if slot!=0:runtime.presentation_events.append({"kind":"hound_summon","position":enemy.pos})
		enemy.patrol_radius=14.0*m.falan_scale
		if slot==0:mark_dungeon_boss(enemy)
		enemy.footprint=1.10 if slot==0 else 1.20
		CaveProgression.apply(enemy,CaveProgression.HABARU[enemy.skin],Habaru.STATS)
		enemy.facing=atan2(hero.x-at.x,hero.z-at.y)
	spawned=1
	if not slain.has(0):runtime.game.toast(Habaru.BOSS_NAME)

func tick_habaru_slimes():
	if spawned!=0 or not is_instance_valid(m.army_runtime):return
	var slain:Dictionary=m.army_runtime.get_tree().get_meta(Habaru.SLIME_SLAIN,{})
	var cells:Array=habaru_patrol_cells()
	for i in cells.size():
		var slot:int=m.falan_floor*100+i
		if slain.has(slot):continue
		var at=(Vector2(cells[i])-Vector2(25,25))*3.0
		var enemy=spawn_enemy(Roles.SLIME,m.world_point(at),-1,Habaru.GREEN_SLIME)
		enemy.habaru_slime_slot=slot
		CaveProgression.apply(enemy,CaveProgression.HABARU[Habaru.GREEN_SLIME],_simulation_stats(Roles.SLIME),12 if m.falan_floor==11003 else 16)
		enemy.footprint=.68
		enemy.patrol_radius=8.0
	spawned=1

func habaru_patrol_cells()->Array:
	if not habaru_cells.is_empty():return habaru_cells
	habaru_cells=Habaru.SLIME_CELLS[m.falan_floor].duplicate()
	var occupied={}
	for cell:Vector2i in habaru_cells:occupied[cell]=true
	for cell:Vector2i in Habaru.SLIME_CELLS[m.falan_floor]:
		var added=0
		for offset:Vector2i in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN,Vector2i(-1,-1),Vector2i(1,1),Vector2i(-2,0),Vector2i(2,0)]:
			var candidate=cell+offset
			if occupied.has(candidate):continue
			var at=(Vector2(candidate)-Vector2(25,25))*3.0
			if not navigation.move_clear(Vector3(at.x,m.surface_height(at.x,at.y),at.y),.68):continue
			occupied[candidate]=true
			habaru_cells.append(candidate)
			added+=1
			if added==ADVENTURE_PACK_SIZE-1:break
	return habaru_cells

func tick_venoa_bears(formation:Array):
	if spawned!=0 or not is_instance_valid(m.army_runtime):return
	var slain:Dictionary=m.army_runtime.get_tree().get_meta(Habaru.VENOA_SLAIN,{})
	for i in formation.size():
		var slot:int=m.falan_floor*100+i
		if slain.has(slot):continue
		var at:Vector2=formation[i]
		var enemy=spawn_enemy(Roles.SLIME,m.world_point(at),-1,Habaru.VENOA_BEAR_SKIN)
		enemy.venoa_bear_slot=slot
		enemy.patrol_radius=11.0
		enemy.footprint=1.2
		CaveProgression.apply(enemy,CaveProgression.HABARU[Habaru.VENOA_BEAR_SKIN],Habaru.STATS,18 if m.falan_floor==11000 else 20 if m.falan_floor==11001 else 22)
	var sites=m.FalanFrontier.Regions.Sites
	var boss_slot:int=sites.VENOA_BOSS_FLOOR*100+99
	if m.falan_floor==sites.VENOA_BOSS_FLOOR and not slain.has(boss_slot):
		var at:Vector2=sites.VENOA_BOSS_AT
		var boss=spawn_enemy(Roles.SLIME,m.world_point(at),-1,Habaru.VENOA_BOSS_SKIN)
		boss.venoa_bear_slot=boss_slot
		mark_dungeon_boss(boss)
		boss.patrol_radius=17.0
		boss.footprint=1.3
		CaveProgression.apply(boss,CaveProgression.HABARU[Habaru.VENOA_BOSS_SKIN],Habaru.STATS)
	spawned=1

func tick_undersea(hero:Vector3):
	if spawned>=2 or not is_instance_valid(m.army_runtime):return
	var tree:SceneTree=m.army_runtime.get_tree()
	var slain:Dictionary=tree.get_meta(Undersea.SLAIN,{})
	if spawned==0:
		var patrols:Array=Undersea.PATROLS[m.falan_floor]
		for i in patrols.size():
			var slot:int=m.falan_floor*100+i
			if not slain.has(slot):spawn_undersea(slot,patrols[i][0],patrols[i][1],true)
		spawned=1
	if m.falan_floor!=Undersea.SOKIA or Vector2(hero.x,hero.z).distance_squared_to(Undersea.BOSS_AT)>17.0*17.0:return
	if not slain.has(0):
		var boss=spawn_undersea(0,Undersea.BOSS_AT,0,false)
		mark_dungeon_boss(boss)
		m.army_runtime.game.toast(Undersea.BOSS_NAME)
	for i in Undersea.ESCORTS.size():
		if not slain.has(i+1):spawn_undersea(i+1,Undersea.ESCORTS[i][0],Undersea.ESCORTS[i][1],false)
	spawned=2

func spawn_undersea(slot:int,at:Vector2,skin:int,patrol:bool)->Dictionary:
	var enemy=spawn_enemy(Roles.SLIME,m.world_point(at),-1,skin)
	enemy.undersea_slot=slot
	if patrol:enemy.patrol_radius=8.0
	enemy.footprint=1.12 if skin==0 else .82
	CaveProgression.apply(enemy,CaveProgression.UNDERSEA[skin],Undersea.STATS,0 if skin==0 else 26 if m.falan_floor==15593 else 20)
	return enemy

func tick_zombie_cave(hero:Vector3,formation:Array):
	if spawned!=0 or not is_instance_valid(m.army_runtime):return
	var tree:SceneTree=m.army_runtime.get_tree()
	var slain:Dictionary=tree.get_meta("zombie_slain",{})
	var lab_count=m.FalanFrontier.Regions.Sites.ZOMBIE_FORMATIONS[Zombie.FINAL].size()
	for i in formation.size():
		var skin:int=formation[i][1]
		var boss=skin==0
		var hellhound=skin==Zombie.HELLHOUND
		var slot=0 if boss else m.falan_floor*10+i
		if slain.has(slot):continue
		var at:Vector2=formation[i][0]
		if m.falan_floor==ZombieMaze.ROOM and i>=lab_count:at=ZombieMaze.patrol_point(i-lab_count,m.seed_value)
		var enemy=spawn_enemy(Roles.SLIME,m.world_point(at),-1,skin)
		enemy.zombie_slot=slot
		if boss:mark_dungeon_boss(enemy)
		enemy.patrol_radius=15.0 if boss else 12.0
		enemy.footprint=.95 if boss else .84 if hellhound else .72
		CaveProgression.apply(enemy,CaveProgression.ZOMBIE[skin],Zombie.STATS,0 if boss or m.falan_floor==Zombie.FINAL else 18 if hellhound else 20)
		enemy.facing=atan2(at.x-hero.x,at.y-hero.z)
	spawned=1
	if m.falan_floor==Zombie.FINAL and not slain.has(0):m.army_runtime.game.toast(Zombie.BOSS_NAME)

func tick_captain(hero:Vector3):
	if spawned!=0 or not is_instance_valid(m.army_runtime):return
	var formation:Array=m.FalanFrontier.Regions.Sites.CAPTAIN_FORMATION
	if Vector2(hero.x,hero.z).distance_squared_to(formation[0][0])>22.0*22.0:return
	var slain:Dictionary=m.army_runtime.get_tree().get_meta(Captain.SLAIN,{})
	for slot in formation.size():
		if slain.has(slot):continue
		var at:Vector2=formation[slot][0]
		var skin:int=formation[slot][1]
		var enemy=spawn_enemy(Roles.SLIME,m.world_point(at),-1,skin)
		enemy.captain_slot=slot
		if skin==0:mark_dungeon_boss(enemy)
		enemy.footprint=.95 if skin==0 else .75
		CaveProgression.apply(enemy,CaveProgression.CAPTAIN[skin],Captain.STATS)
		enemy.facing=atan2(at.x-hero.x,at.y-hero.z)
	spawned=1
	if not slain.has(0):m.army_runtime.game.toast("Wolf Captain")

func spawn_grave(slot:int,skin:int,hero:Vector3):
	var at:Vector2=m.FalanFrontier.Regions.Sites.GRAVE_FORMATION[slot]
	var enemy=spawn_enemy(Roles.SLIME,m.world_point(at),-1,skin)
	enemy.grave_slot=3 if skin==2 else slot if skin!=3 else -1
	if skin in [0,2]:mark_dungeon_boss(enemy)
	enemy.footprint=1.05 if skin==2 else .78
	CaveProgression.apply(enemy,CaveProgression.GRAVE[skin],Grave.STATS)
	enemy.facing=atan2(at.x-hero.x,at.y-hero.z)

func tick_grave(delta:float,hero:Vector3):
	if not is_instance_valid(m.army_runtime):return
	var slain:Dictionary=m.army_runtime.get_tree().get_meta(Grave.SLAIN,{})
	if slain.has(3):return
	var boss_at:Vector2=m.FalanFrontier.Regions.Sites.GRAVE_FORMATION[0]
	if spawned==0 and Vector2(hero.x,hero.z).distance_to(boss_at)<27.0:
		for slot in 3:
			if not slain.has(slot):spawn_grave(slot,0 if slot==0 else 1,hero)
		spawned=1
		if slain.size()<3:m.army_runtime.game.toast("Parukes's Ghost")
	if spawned==1 and slain.has(0) and slain.has(1) and slain.has(2):
		spawn_grave(0,2,hero)
		spawn_grave(3,3,hero)
		spawn_grave(4,3,hero)
		spawned=2
		spawn_clock=7.0
		m.army_runtime.game.toast("Parukes · Second Round")
	if spawned!=2:return
	spawn_clock=maxf(0.0,spawn_clock-delta)
	if spawn_clock>0.0:return
	spawn_clock=7.0
	var rebels=0
	for enemy in m.enemies.values():
		if enemy.skin==3 and enemy.hp>0:rebels+=1
	if rebels<2:
		spawn_grave(3+(m.next_id%2),3,hero)

func tick_black_prayer():
	if spawned!=0 or not is_instance_valid(m.army_runtime):return
	var rows=Prayer.patrols(m.falan_floor,m.seed_value)
	var slain:Dictionary=m.army_runtime.get_tree().get_meta(Prayer.SLAIN,{})
	for slot in rows.size():
		var key=Vector2i(m.falan_floor,slot)
		if slain.has(key):continue
		var row:Array=rows[slot]
		var enemy=spawn_enemy(Roles.SLIME,m.world_point(row[0]),-1,row[1])
		enemy.black_prayer_slot=key
		enemy.footprint=.63
		CaveProgression.apply(enemy,["血腥之刃" if row[1]==1 else "鬼靈",row[2],400 if row[1]==1 else 300,false],Ruby.STATS)
	spawned=1

func tick_ruby(hero:Vector3):
	if spawned!=0 or not is_instance_valid(m.army_runtime):return
	var formation:Array=m.FalanFrontier.Regions.Sites.RUBY_FORMATION
	if Vector2(hero.x,hero.z).distance_to(formation[0][0])>39.0:return
	var slain:Dictionary=m.army_runtime.get_tree().get_meta(Ruby.SLAIN,{})
	for slot in formation.size():
		if slain.has(slot):continue
		var at:Vector2=formation[slot][0]
		var skin:int=formation[slot][1]
		var enemy=spawn_enemy(Roles.SLIME,m.world_point(at),-1,skin)
		enemy.ruby_slot=slot
		if slot==0:mark_dungeon_boss(enemy)
		enemy.footprint=.78 if slot==0 else .63
		CaveProgression.apply(enemy,CaveProgression.RUBY[skin],Ruby.STATS)
		enemy.facing=atan2(at.x-hero.x,at.y-hero.z)
	spawned=1
	if not slain.has(0):m.army_runtime.game.toast("Ruby · Black Prayer")

func tick_frostpass():
	if spawned!=0 or not is_instance_valid(m.army_runtime):return
	var id:int=m.falan_floor
	var level_range:Vector2i=Winter.LEVELS[id]
	var slain:Dictionary=m.army_runtime.get_tree().get_meta(Winter.SLAIN,{})
	var posts=Winter.patrols(id,m.seed_value)
	var creature_keys=Winter.creature_keys(id)
	var skins:Array=creature_keys.map(func(key):return Pets.skin(key))
	for i in posts.size():
		var slot=Vector2i(id,i)
		if slain.has(slot):continue
		var at=m.world_point(Winter.point(posts[i],id))
		if not skins.is_empty():
			var hound=i%2==1
			var enemy=spawn_enemy(Roles.GATEKEEPER_HOUND,at)
			enemy.skin=skins[i%2]
			enemy.frostpass_slot=slot
			enemy.patrol_radius=10.0
			enemy.footprint=.84 if hound else .72
			var level=level_range.x+(i/2)%(level_range.y-level_range.x+1)
			CaveProgression.apply(enemy,["地獄妖犬" if hound else "喪屍",level,330 if hound else 440,false],Roles.stats(Roles.GATEKEEPER_HOUND))
			continue
		var bear=i%3==2
		var kind=Roles.CAVE_BEAR if bear else Roles.GATEKEEPER_HOUND
		var skin=Habaru.VENOA_BEAR_SKIN if bear else 0
		var enemy=spawn_enemy(kind,at,-1,skin)
		enemy.frostpass_slot=slot
		enemy.patrol_radius=10.0
		var level=level_range.x+(i/3)%3
		CaveProgression.apply(enemy,["Frost Bear" if bear else "Ridge Hound",level,440 if bear else 330,false],Roles.stats(kind))
	spawned=1

func tick_falken():
	if spawned!=0 or not is_instance_valid(m.army_runtime):return
	var floor_id:int=m.falan_floor
	var slain:Dictionary=m.army_runtime.get_tree().get_meta(Falken.SLAIN,{})
	var rows=[]
	if floor_id==Falken.ROOM:
		if not m.army_runtime.game.falken_dialogue_seen and not slain.has(Vector2i(floor_id,0)):return
		rows.append([Falken.Route.point(floor_id,Falken.Route.BOSS_CELL),0])
		for x in range(19,28,2):rows.append([Falken.Route.point(floor_id,Vector2i(x,22)),1 if x%4==3 else 2])
	rows.append_array(Falken.Route.patrols(floor_id,m.seed_value))
	for slot in rows.size():
		var key=Vector2i(floor_id,slot)
		if slain.has(key):continue
		var enemy=spawn_enemy(Roles.SLIME,m.world_point(rows[slot][0]),-1,rows[slot][1])
		enemy.falken_slot=key
		enemy.footprint=.9 if rows[slot][1]==0 else .7
		enemy.patrol_radius=12.0
		CaveProgression.apply(enemy,Falken.PROFILES[rows[slot][1]],Falken.STATS)
		if floor_id in Falken.Route.FLOORS:CaveProgression.apply(enemy,[Falken.PROFILES[rows[slot][1]][0],rows[slot][2],400,false],Falken.STATS)
		if rows[slot][1]==0:mark_dungeon_boss(enemy)
	spawned=1

func tick_holy_decree():
	if spawned!=0 or not is_instance_valid(m.army_runtime):return
	var id:int=m.falan_floor
	var slain:Dictionary=m.army_runtime.get_tree().get_meta(Winter.SLAIN,{})
	var rows=Winter.Recovered.Beast.encounters(id,m.seed_value) if id==Winter.Recovered.Beast.BOSS_ROOM or Winter.Recovered.Beast.owns(id) else Winter.Decree.encounters(id,m.seed_value)
	for i in rows.size():
		var row:Array=rows[i]
		var slot=Vector2i(id,row[5])
		if slain.has(slot):continue
		spawn_decree_row(row,id)
	spawned=1

func spawn_decree_row(row:Array,id:int):
	var recovered=preload("res://scripts/forest/crowd/cursed_maze_sprites.gd")
	if Winter.Recovered.Beast.owns(id):recovered=preload("res://scripts/forest/crowd/beast_maze_sprites.gd")
	var skin:int=recovered.KEYS.find(row[1])
	var role=Roles.SLIME if skin>=0 else Roles.GATEKEEPER_HOUND
	var stats=recovered.STATS if skin>=0 else Roles.stats(role)
	var at=Winter.Recovered.point(id,row[0],m.seed_value) if Winter.Recovered.Beast.owns(id) else Winter.Decree.point(row[0],id)
	var enemy=spawn_enemy(role,m.world_point(at),-1,maxi(0,skin))
	if skin<0:enemy.skin=Pets.skin(row[1])
	enemy.frostpass_slot=Vector2i(id,row[5])
	enemy.footprint=.92 if row[4] else .84
	enemy.patrol_radius=8.0 if row[4] else 11.0
	CaveProgression.apply(enemy,[row[2],row[3],660 if row[4] else 280,row[4]],stats)
	if row[4]:mark_dungeon_boss(enemy)
	return enemy

func reinforce_decree(source_id:int):
	if m.falan_floor!=Winter.Decree.GUARDIAN_FLOORS[0]:return
	var boss:Dictionary=m.enemies.get(source_id,{})
	if boss.is_empty() or not boss.get("boss",false) or boss.hp<=0:return
	var slain:Dictionary=m.army_runtime.get_tree().get_meta(Winter.SLAIN,{})
	var count_=0
	for row in Winter.Decree.encounters(m.falan_floor,m.seed_value):
		var slot=Vector2i(m.falan_floor,row[5])
		if row[4] or not slain.has(slot):continue
		slain.erase(slot)
		var attendant:Dictionary=spawn_decree_row(row,m.falan_floor)
		attendant.cursed_arrival=true;count_+=1
		if count_==2:break
	m.army_runtime.get_tree().set_meta(Winter.SLAIN,slain)

func reinforce_falken(source_id:int,skin:int):
	if m.falan_floor!=Falken.ROOM or skin not in [1,2]:return
	var boss:Dictionary=m.enemies.get(source_id,{})
	if boss.is_empty() or boss.skin!=0 or boss.hp<=0:return
	if m.enemies.values().any(func(row):return row.id!=source_id and row.hp>0 and row.skin in [1,2] and row.pos.distance_to(boss.pos)<40*m.falan_scale):return
	for x in range(19,28,2):
		var enemy=spawn_enemy(Roles.SLIME,m.world_point(Falken.Route.point(Falken.ROOM,Vector2i(x,22))),-1,skin)
		enemy.falken_slot=Vector2i(Falken.ROOM,100+enemy.id);enemy.footprint=.7;enemy.patrol_radius=12.0
		CaveProgression.apply(enemy,Falken.PROFILES[skin],Falken.STATS)
		m.army_runtime.presentation_events.append({"kind":"hound_summon","position":enemy.pos})

func tick(delta:float,hero:Vector3):
	if m.phase!="wave":return
	if not patrol_posts.is_empty():
		tick_outer_road(delta,hero/m.falan_scale)
		return
	if not m.falan_area.is_empty():
		hero/=m.falan_scale
		if Winter.LEVELS.has(m.falan_floor):tick_frostpass()
		elif Winter.Decree.floor_number(m.falan_floor)>0 or m.falan_floor==Winter.Recovered.Beast.BOSS_ROOM or Winter.Recovered.Beast.owns(m.falan_floor):tick_holy_decree()
		elif Falken.Route.owns(m.falan_floor):tick_falken()
		elif m.falan_floor==11004:tick_habaru(hero)
		elif Habaru.SLIME_CELLS.has(m.falan_floor):tick_habaru_slimes()
		elif m.falan_floor==Captain.ROOM:tick_captain(hero)
		elif m.falan_floor==Grave.ROOM:tick_grave(delta,hero)
		elif m.falan_floor in Prayer.FLOORS:tick_black_prayer()
		elif m.falan_floor==Ruby.ROOM:tick_ruby(hero)
		elif Undersea.PATROLS.has(m.falan_floor):tick_undersea(hero)
		else:
			var sites=m.FalanFrontier.Regions.Sites
			if sites.VENOA_BEARS.has(m.falan_floor):tick_venoa_bears(sites.VENOA_BEARS[m.falan_floor])
			elif sites.ZOMBIE_FORMATIONS.has(m.falan_floor):tick_zombie_cave(hero,sites.ZOMBIE_FORMATIONS[m.falan_floor]+(m.Dungeons.ZOMBIE_PATROLS if m.falan_floor==Zombie.FINAL else []))
		return
	if crossgate_pet_test:
		wave_clock-=delta
		while wave_clock<=.000001:
			m.wave+=1;released_waves+=1;wave_clock+=SLIME_WAVE_SECONDS
			m.wave_started.emit()
		spawn_slimes(hero)
		return
	wave_clock-=delta
	while wave_clock<=.000001 and released_waves<m.balance.waves.size():
		m.wave+=1
		# Carry blocked arrivals forward without dropping any configured enemies.
		for slot in remaining_counts.size():
			remaining_counts[slot]+=m.balance.waves[m.wave-1][slot];pending+=m.balance.waves[m.wave-1][slot]
		spawn_groups.clear();rng.seed=m.seed_value+m.wave*7919;routes.portal_cursor=0
		if remaining_counts[Balance.TYPES.find(Roles.BOSS)]>0:boss_pending[0]=true
		released_waves+=1;wave_clock=minf(WAVE_SECONDS,wave_clock+WAVE_SECONDS);spawn_clock=0.0
		m.wave_started.emit()
	if released_waves==m.balance.waves.size() and wave_clock<=.000001:wave_clock=0.0
	if kill_spawn_pending>0:spawn_random_batch(true)
	random_spawn_clock=maxf(0,random_spawn_clock-delta)
	if random_spawn_clock<=.000001:
		spawn_random_batch();random_spawn_clock=RANDOM_SPAWN_INTERVAL
	spawn_clock-=delta
	if pending>0 and spawn_clock<=0 and m.enemies.size()<active_cap():spawn_batch();spawn_clock=SPAWN_INTERVAL
	if not m.survival_run and released_waves==m.balance.waves.size() and wave_clock==0 and pending==0 and kill_spawn_pending==0 and m.enemies.is_empty():
		m.gold+=100;m.phase="victory"
		m.workforce.recover();m.update_vision(hero);m.events.append({"kind":m.phase});m.revision+=1
