extends "res://scripts/swarm_survival.gd"
# Discrete island encounters replace the clock/wave spawner in the main mode.
var current_island=0
var completed=false
var visited: Dictionary={}
var cleared: Dictionary={}
var recoveries=0
const GROUND_COUNT=50
const GROUND_RAIDERS=24
var pending_giants: Array=[]
var ground_refill_clock=0.0
var ground_raiders_pending=0
const REINFORCEMENT_INTERVAL=8.0
const ISLAND_LIMIT=12
var rosters: Dictionary={}
var serials: Dictionary={}
var next_reinforcement=REINFORCEMENT_INTERVAL
var spawned: Dictionary={}
var defeated: Dictionary={}
var ground_spawned=false
var ground_cleared=false
var stream_layer=-1
var stream_timer=0.0
const SPAWNS_PER_FRAME=4
var pending_spawns: Array=[]

func reset():
	super.reset()
	current_island=0;completed=false;visited.clear();cleared.clear();recoveries=0
	spawned.clear();defeated.clear();ground_spawned=false;ground_cleared=false
	stream_layer=-1;stream_timer=0;pending_spawns.clear()
	rosters.clear();serials.clear();next_reinforcement=REINFORCEMENT_INTERVAL
	pending_giants.clear();ground_refill_clock=0;ground_raiders_pending=0

func begin():
	reset();enabled=true;active=true
	spawn_rng.seed=game.run_seed
	var capsule=CapsuleShape3D.new();capsule.radius=.72;capsule.height=1.85
	spawn_probe=PhysicsShapeQueryParameters3D.new();spawn_probe.shape=capsule;spawn_probe.collision_mask=5
	var sky=game.world.sky_islands
	for index in range(sky.COUNT):
		rosters[index]=[];serials[index]=0
		for j in range(sky.enemy_count(index)):add_roster_enemy(index)
	game.player.progression.reset(true)
	game.player.refresh_max_health()
	game.checkpoint=sky.islands[0]+Vector3(0,.12,3.8)
	game.player.position=game.checkpoint;game.player.velocity=Vector3.ZERO
	game.camera_rig.pitch=.65
	var direction=sky.next_point(0)-sky.islands[0]
	game.camera_rig.yaw=atan2(-direction.x,-direction.z)
	game.camera_rig.reset_follow()
	refresh_encounters()
	visited[0]=true;sky.highlight(0)
	game.hud.banner="DAWN CROWN · BEGIN THE DESCENT";game.hud.banner_time=4

func add_roster_enemy(index: int):
	var serial=int(serials[index]);serials[index]=serial+1
	rosters[index].append("sky_%02d_%05d" % [index,serial])

func record_defeat(enemy: Ninja):
	if defeated.has(enemy.encounter_id):return
	defeated[enemy.encounter_id]=enemy.island_index
	game.adventure.record_defeat(enemy)
	rosters[enemy.island_index].erase(enemy.encounter_id)
	if rosters[enemy.island_index].is_empty() and game.adventure.is_complete(enemy.island_index):
		cleared[enemy.island_index]=true
		game.toast("ISLAND %02d CLEARED · Reinforcements stopped" % [enemy.island_index+1])

func remaining_on(index: int)->int:
	return rosters[index].size() if rosters.has(index) else game.world.sky_islands.enemy_count(index)

func reinforce():
	for index in rosters:
		if cleared.has(index) or game.adventure.is_complete(index):continue
		for j in range(mini(2,ISLAND_LIMIT-rosters[index].size())):add_roster_enemy(index)
	refresh_encounters()

func refresh_encounters():
	# Only nearby arenas need actors; every island retains its own roster.
	# Unloading retains kills, including when the hero returns to an earlier island.
	var sky=game.world.sky_islands
	stream_layer=sky.layer_at_height(game.player.position.y)
	var wanted={}
	if not completed:
		for index in sky.nearby_islands(game.player.position):wanted[index]=true
	for i in range(game.enemies.size()-1,-1,-1):
		var enemy=game.enemies[i]
		if not is_instance_valid(enemy):game.enemies.remove_at(i);continue
		if enemy.island_index>=0 and not wanted.has(enemy.island_index):
			game.enemies.remove_at(i);enemy.queue_free()
	for index in spawned.keys():
		if not wanted.has(index):spawned.erase(index)
	var live_ids={}
	for enemy in game.enemies:
		if is_instance_valid(enemy) and not enemy.dead:live_ids[enemy.encounter_id]=true
	pending_spawns.clear()
	for index in wanted:
		spawned[index]=true
		for id in rosters[index]:
			if not live_ids.has(id):pending_spawns.append({"index":index,"id":id})

func spawn_pending():
	# Bound scene creation during flight and reinforcements; rosters stay immediate.
	var sky=game.world.sky_islands
	for count in range(SPAWNS_PER_FRAME):
		if pending_spawns.is_empty() or game.enemy_spawn_capacity()<=0:return
		var entry=pending_spawns.pop_front()
		var index=int(entry.index);var id=String(entry.id)
		if not spawned.has(index) or not rosters[index].has(id):continue
		var serial=int(id.get_slice("_",2))
		var enemy=Ninja.new();enemy.game=game;enemy.swarm=true;enemy.island_index=index
		enemy.island_elite=game.adventure.kind(index)==0 and serial==0
		enemy.encounter_id=id;enemy.formation_index=index*100+serial;enemy.variant=3 if not enemy.island_elite and serial%4==1 else (index+serial)%3
		# Rotate through clear points on the rim, away from the hero and actors.
		var point=sky.islands[index]+Vector3(7,.12,0)
		for attempt in range(24):
			var angle=serial*2.399963+attempt*TAU/24
			point=sky.interior_point(index,angle,.66)+Vector3.UP*.12
			if point.distance_to(game.player.position)<4:continue
			var clear=true
			for other in game.enemies:
				if is_instance_valid(other) and not other.dead and other.position.distance_squared_to(point)<2:clear=false;break
			if clear:break
		enemy.position=point;enemy.cooldown=.8;enemy.alerted=true;enemy.state="chase"
		enemy.process_mode=Node.PROCESS_MODE_PAUSABLE
		game.add_child(enemy);game.enemies.append(enemy)
		enemy.max_hp*=1.0+sky.layer_of(index)*.09;enemy.hp=enemy.max_hp
		total_spawned+=1

func ground_remaining()->int:
	var count=0
	for enemy in game.enemies:
		if is_instance_valid(enemy) and enemy.ground_giant and not enemy.dead:count+=1
	return count

func ground_raiders()->Array:
	return game.enemies.filter(func(enemy):return is_instance_valid(enemy) and not enemy.dead and enemy.encounter_id.begins_with("ground_raider_"))

func spawn_ground_giants():
	if ground_spawned:return
	ground_spawned=true
	var courts=game.world.outposts+game.world.furnished_districts
	for i in courts.size():
		for slot in range(2):pending_giants.append({"court":courts[i],"index":i,"slot":slot})
	ground_raiders_pending=GROUND_RAIDERS;ground_refill_clock=REINFORCEMENT_INTERVAL

func spawn_one_giant(entry: Dictionary):
	var shape=CapsuleShape3D.new();shape.radius=3.1;shape.height=9.0
	var query=PhysicsShapeQueryParameters3D.new();query.shape=shape;query.collision_mask=5
	var space=game.get_world_3d().direct_space_state
	for attempt in range(64):
		var angle=entry.slot*PI+attempt*2.399963
		var point=entry.court+Vector3(cos(angle),0,sin(angle))*(16+attempt%4*2)
		point.y=game.world.height_at(point.x,point.z)
		if point.distance_to(game.player.position)<14:continue
		var hit=space.intersect_ray(PhysicsRayQueryParameters3D.create(point+Vector3.UP*2,point-Vector3.UP,1))
		if hit.is_empty() or hit.normal.y<.85:continue
		point.y=hit.position.y+.15
		query.transform=Transform3D(Basis.IDENTITY,point+Vector3.UP*4.5)
		if not space.intersect_shape(query,1).is_empty():continue
		var enemy=Ninja.new();enemy.game=game;enemy.ground_giant=true;enemy.swarm=true
		enemy.variant=(entry.index*2+entry.slot)%3;enemy.formation_index=entry.index*2+entry.slot
		enemy.encounter_id="ground_giant_%d_%d" % [entry.index,entry.slot];enemy.position=point
		enemy.cooldown=2.5;enemy.process_mode=Node.PROCESS_MODE_PAUSABLE
		game.add_child(enemy);game.enemies.append(enemy);total_spawned+=1
		return

func tick_ground(delta: float):
	ground_refill_clock-=delta
	if ground_refill_clock<=0 and not ground_cleared:
		ground_refill_clock=REINFORCEMENT_INTERVAL
		if ground_remaining()>0 or not pending_giants.is_empty():
			# Recycle only while reinforcements are active. The final survivors
			# must be defeated, not despawned by walking out of range.
			for enemy in ground_raiders():
				if enemy.position.distance_squared_to(game.player.position)>110*110:
					game.enemies.erase(enemy);enemy.queue_free()
			ground_raiders_pending=maxi(0,GROUND_RAIDERS-ground_raiders().size())
	var deadline=Time.get_ticks_usec()+SPAWN_TIME_USEC
	for i in range(SPAWNS_PER_FRAME):
		if game.enemy_spawn_capacity()<=0:break
		# Alternate giant and regular arrivals so the landing area is active first.
		if not pending_giants.is_empty() and (i%2==0 or ground_raiders_pending<=0):
			spawn_one_giant(pending_giants.pop_front())
		elif ground_raiders_pending>0:
			var point=wave_spawn_point()
			if point==null:break
			var enemy=Ninja.new();enemy.game=game;enemy.swarm=true
			enemy.encounter_id="ground_raider_%d" % total_spawned;enemy.formation_index=total_spawned
			enemy.variant=3 if ground_raiders_pending%4==0 else total_spawned%3;enemy.position=point;enemy.alerted=true;enemy.state="chase";enemy.cooldown=1.2
			enemy.process_mode=Node.PROCESS_MODE_PAUSABLE
			game.add_child(enemy);game.enemies.append(enemy)
			total_spawned+=1;ground_raiders_pending-=1
		else:break
		if Time.get_ticks_usec()>=deadline:break

func tick(delta: float):
	if not enabled or not active or not game.playing or game.paused or game.transitioning or game.player.hp<=0:return
	elapsed+=delta
	if not completed and elapsed>=next_reinforcement:
		next_reinforcement=elapsed+REINFORCEMENT_INTERVAL
		reinforce()
	for i in range(game.enemies.size()-1,-1,-1):
		if not is_instance_valid(game.enemies[i]):game.enemies.remove_at(i)
	alive_count=game.active_enemy_count()
	var sky=game.world.sky_islands
	var player=game.player
	for i in visited:
		if not cleared.has(i) and remaining_on(i)==0 and game.adventure.is_complete(i):
			cleared[i]=true
			game.toast("ISLAND %02d CLEAR · Choose any island or cloud below" % [i+1])
	if completed and player.position.y>sky.ground_point.y+sky.DROP-8:
		completed=false;stream_timer=0
	if completed:
		tick_ground(delta)
		if ground_spawned and not ground_cleared and pending_giants.is_empty() and ground_raiders_pending==0 and ground_remaining()==0 and ground_raiders().is_empty():
			ground_cleared=true
			game.hud.banner="TIDEFALL LIBERATED · ALL GROUND ENEMIES DEFEATED";game.hud.banner_time=7
			game.toast("The ground is yours · Explore Tidefall or start a new descent")
		return
	spawn_pending()
	if player.sky_strike.active or (player.active_ability!=null and player.active_ability.blocks_movement()):return
	stream_timer-=delta
	if stream_timer<=0:
		stream_timer=.5
		var layer=sky.layer_at_height(player.position.y)
		refresh_encounters();sky.highlight(layer*sky.PER_LAYER)
	if player.is_on_floor():
		var landed=sky.island_at(player.global_position)
		if landed>=0:
			if current_island!=landed or not visited.has(landed):
				visited[landed]=true;current_island=landed
				game.checkpoint=sky.islands[landed]+Vector3.UP*.12
				sky.highlight(landed);refresh_encounters()
				game.hud.banner="LAYER %02d · %s" % [sky.layer_of(landed)+1,sky.island_name(landed)];game.hud.banner_time=2.5
				game.toast("Choose your route · Fight, cross the clouds, or drop freely")
		elif sky.cloud_at(player.position)>=0:
			game.checkpoint=player.position+Vector3.UP*.12
		elif player.position.y<sky.ground_point.y+sky.DROP-12:
			completed=true;game.checkpoint=player.position+Vector3.UP*.15
			refresh_encounters()
			game.hud.banner="TIDEFALL REACHED · GROUND RAIDERS & GIANTS";game.hud.banner_time=7
			game.toast("%d / %d islands cleared · Level %d · Defeat the ground raiders and giants" % [cleared.size(),sky.COUNT,player.progression.level])
			spawn_ground_giants();game.sound("spark")
	# Falling past an island is intentional. No route checkpoint teleport.
