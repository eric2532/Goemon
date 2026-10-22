extends SceneTree
var failures=0
var checks=0
func check(ok: bool,message: String):
	checks+=1
	if not ok:failures+=1;printerr("FAIL: "+message)
func _initialize():call_deferred("run")
func fresh():
	var m=load("res://scripts/forest/forest_model.gd").new();m.reset(42);m.trees.clear();m.workers.clear()
	for b in m.buildings.values():
		if b.id!=1:m._remove_building(b.id)
	m.rebuild_navigation();m.update_vision(Vector3.ZERO);m.start_wave();m.waves.spawn_clock=10000
	return m
func run():
	var m=fresh()
	check(m.waves.has_method("spawn_enemy"),"Director supports deterministic role spawns")
	if not m.waves.has_method("spawn_enemy"):finish();return
	var wall=m._make_building("wall",Vector2i(5,0),1)
	var committed_tower=m._make_building("tower",Vector2i(5,7),0);m.rebuild_navigation()

	var worker={"id":90,"pos":Vector3(54,0,60),"hp":100.0,"max_hp":100.0,"state":"idle","job":-1,"follow":false,"cargo":0,"timer":0.0,"safe":0.0,"path":[],"destination":Vector2i(-999,-999),"nav":-1};m.workers[90]=worker
	for variant in range(4):m.waves.spawn_enemy(variant,Vector3(60,0,60))
	m.waves.tick(.1,Vector3(60,0,54))
	var es=m.enemies.values()
	check(es[0].target_kind=="hero","Raider pursues targetable hero over nearby workers")
	check(es[1].target_kind=="worker" and es[1].target_id==90,"Archer prefers healthy workers")
	check(es[2].target_kind=="building" and es[2].target_id==committed_tower.id and wall.hp==wall.max_hp,"Daruma prefers a vulnerable tower and leaves permanent walls intact beside hero and workers")
	check(es[3].target_kind=="building" and es[3].target_id==1,"Lantern commits to shrine")
	m.hero_targetable=false;m.waves.tick(.1,Vector3(60,0,54))
	check(es[0].target_kind=="building" and es[0].target_id==1,"Untargetable hero gives Raider shrine fallback")
	var tower=m._make_building("tower",Vector2i(9,7),0);m.rebuild_navigation();m.waves.tick(.1,Vector3.ZERO)
	check(es[2].target_id==committed_tower.id,"New equally suitable structures do not steal a valid committed giant tower target")
	m=fresh();var giant=m.waves.spawn_enemy(2,Vector3(0,0,84));giant.facing=0.0
	for i in range(160):m.waves.tick(.1,Vector3(120,0,120))
	check(absf(giant.pos.z-69.6)<.08,"Daruma covers14.4m in16 seconds on a clear approach")
	check(giant.hp==9000 and giant.max_hp==9000,"Giant durability is actual9000HP")
	m.wave=5;var late=m.waves.spawn_enemy(2,Vector3(0,0,120));late.facing=0.0
	var before: Vector3=late.pos
	for i in range(10):m.waves.tick(.1,Vector3.ZERO)
	check(absf(before.distance_to(late.pos)-.9)<.08 and late.hp==9000,"Later waves preserve giant speed andHP")
	m=fresh();var door=m._make_building("gate",Vector2i(-1,5),0);m.rebuild_navigation();giant=m.waves.spawn_enemy(2,Vector3(0,0,42));giant.facing=0.0
	m.waves.tick(.1,Vector3.ZERO)
	check(giant.action=="windup" and door.hp==door.max_hp,"Giant stops and starts readable door windup before damage")
	var left: float=giant.action_left;giant.frozen=2.0;before=giant.pos
	m.waves.tick(1.0,Vector3.ZERO)
	check(giant.action_left==left and giant.pos==before,"Freeze pauses giant attack timers and movement")
	m.waves.tick(1.0,Vector3.ZERO)
	check(giant.action_left==left,"Entire final frozen interval stays paused")
	m.waves.tick(1.39,Vector3.ZERO)
	check(door.hp==door.max_hp,"No early giant contact damage")
	m.waves.tick(.12,Vector3.ZERO)
	check(door.hp==door.max_hp-240 and giant.action=="recover","Completed giant door windup damages once then recovers")
	m.waves.tick(2.0,Vector3.ZERO);check(door.hp==door.max_hp-240,"Door attack recovery prevents repeated damage")
	m=fresh();door=m._make_building("gate",Vector2i(-1,5),0);m.rebuild_navigation();giant=m.waves.spawn_enemy(2,Vector3(0,0,42));giant.facing=0.0;m.waves.tick(.1,Vector3.ZERO)
	m._remove_building(door.id);m.rebuild_navigation();var shrine_hp: float=m.shrine().hp;m.waves.tick(2.0,Vector3.ZERO)
	check(m.shrine().hp==shrine_hp,"Destroyed windup target cannot transfer delayed strike to shrine")
	m=fresh();var infantry=m.waves.spawn_enemy(0,Vector3(0,0,60));infantry.facing=0.0;m.waves.tick(.1,Vector3(0,0,58));m.events.clear()
	m.waves.tick(.6,Vector3(0,0,40))
	check(not m.events.any(func(event):return event.kind=="hero_hit"),"Hero leaving visible melee contact cancels windup damage")
	m=fresh();giant=m.waves.spawn_enemy(2,Vector3(0,0,84));before=giant.pos;giant.frozen=2.0;m.phase="preparing";m.waves.tick(2.0,Vector3.ZERO)
	check(giant.pos==before and giant.frozen==2.0,"Paused/inactive director stops locomotion and control timers")
	m=fresh();giant=m.waves.spawn_enemy(2,Vector3(0,0,84));giant.facing=0.0;m.waves.tick(.1,Vector3.ZERO)
	var posed_velocity: Vector3=giant.velocity;var posed_phase: float=giant.walk_phase;giant.frozen=2.0;m.waves.tick(.5,Vector3.ZERO)
	check(giant.has("frozen_pose"),"Frozen director exposes one immutable simulation pose for all contact and visual consumers")
	if giant.has("frozen_pose"):
		check(giant.frozen_pose.velocity==posed_velocity and giant.frozen_pose.walk_phase==posed_phase,"Freeze snapshot preserves planted-foot motion and walk phase before velocity clears")
		check(not giant.frozen_pose.has("frozen_pose"),"Repeated freeze snapshots cannot recursively retain previous poses")
		m.waves.tick(.5,Vector3.ZERO)
		check(giant.frozen_pose.velocity==posed_velocity,"Director retains the same frozen pose throughout freeze")
	m.waves.tick(1.1,Vector3.ZERO)
	check(not giant.has("frozen_pose"),"Expired freeze returns to authoritative active simulation pose")
	# ReviewP2: clear initial facing must never rotate a fist through a nearby tower.
	for tight in [false,true]:
		m=fresh();tower=m._make_building("tower",Vector2i(-1,12),0)
		if tight:m._make_building("tower",Vector2i(-5,7),0);m._make_building("tower",Vector2i(2,7),0)
		m.rebuild_navigation();giant=m.waves.spawn_enemy(2,Vector3(0,0,60));giant.facing=0.0
		check(m.waves.navigation.fitted_blocker(giant,giant.pos)==-1,"Turning fixture begins in a fitted clear pose")
		var overlap=false;var too_fast=false;var moved=false;var snapped=false
		for i in range(650):
			var old_pos: Vector3=giant.pos;var old_facing: float=giant.facing
			m.waves.tick(.1,Vector3.ZERO)
			if giant.action=="walk":
				if m.waves.navigation.fitted_blocker(giant,giant.pos)>=0:overlap=true
				var yaw_probe=giant.duplicate()
				for part in range(1,9):
					yaw_probe.facing=old_facing+wrapf(giant.facing-old_facing,-PI,PI)*part/8.0
					yaw_probe.pos=old_pos.lerp(giant.pos,part/8.0)
					if m.waves.navigation.fitted_blocker(yaw_probe,yaw_probe.pos)>=0:overlap=true
			if giant.pos.distance_to(old_pos)>.0901:too_fast=true
			if absf(wrapf(giant.facing-old_facing,-PI,PI))>.0451:snapped=true
			if giant.pos.distance_to(Vector3(0,0,60))>.2:moved=true
			if tower.hp<tower.max_hp:break
		check(not overlap,"Giant yaw and retreat never overlap fitted neighboring structures before windup (tight=%s)"%tight)
		check(not too_fast and not snapped,"Blocked-turn response preserves0.9m/s and0.45rad/s without teleporting")
		check(moved and tower.hp<tower.max_hp,"Blocked yaw repositions and completes a deliberate strike instead of stalling")
		check(giant.target_id==tower.id,"Turning clearance keeps the committed primary structure")
	m=fresh();var corridor_wall=-1
	for z in range(-5,26,6):
		corridor_wall=m._make_building("wall",Vector2i(-2,z),1).id
		m._make_building("wall",Vector2i(2,z),1)
	m.rebuild_navigation();giant=m.waves.spawn_enemy(2,Vector3(0,0,60));giant.facing=PI*.5
	check(m.waves.navigation.fitted_blocker(giant,giant.pos)==-1,"Long turning corridor starts in a clear fixed-facing pose")
	var distant_clearance: Array=m.waves.navigation.turning_retreat(giant,corridor_wall)
	check(not distant_clearance.is_empty() and giant.pos.distance_to(distant_clearance.back())>48,"A long valid corridor finds distant turning clearance beyond the local recovery neighborhood")
	m=fresh();m.trees[Vector2i(0,8)]=1.0;m.rebuild_navigation();giant=m.waves.spawn_enemy(2,Vector3(0,0,72));giant.knockback=Vector3(0,0,-100)
	m.waves.tick(.5,Vector3.ZERO)
	check(giant.pos.z>=57.7,"Swept impulse respects giant core clearance against trees")
	m=fresh();m.trees[Vector2i(2,12)]=1.0;m.rebuild_navigation();giant=m.waves.spawn_enemy(2,Vector3(0,0,84));giant.facing=0.0
	var collided_fist=false
	for i in range(240):
		m.waves.tick(.1,Vector3.ZERO)
		var fist: Vector3=giant.pos+Basis(Vector3.UP,giant.facing)*Vector3(10.637,0,-1.3)
		var offset=Vector2(maxf(0,absf(fist.x-12)-1.25),maxf(0,absf(fist.z-72)-1.25))
		if offset.length()<3.2:collided_fist=true
	check(not collided_fist,"Broad stone fist cannot walk through a tree outside core body clearance")
	m=fresh();wall=m._make_building("wall",Vector2i(2,8),0);m.rebuild_navigation();giant=m.waves.spawn_enemy(2,Vector3(0,0,84));giant.facing=0.0
	var side_blocker: int=m.waves.swept_move(giant,Vector3(0,0,-42))
	check(side_blocker==wall.id and giant.pos.z>=55.2,"Fitted low stone fist blocks side wall before the core passes beside it")
	m=fresh();tower=m._make_building("tower",Vector2i(0,-5),0);m.rebuild_navigation();giant=m.waves.spawn_enemy(2,Vector3(0,0,84));giant.facing=0.0;m.waves.tick(.1,Vector3.ZERO)
	wall=m._make_building("wall",Vector2i(2,8),0);m.rebuild_navigation();giant.pos=Vector3(0,0,55.5);giant.path=[];giant.nav=-1
	for i in range(900):m.waves.tick(.1,Vector3.ZERO)
	check(wall.hp==wall.max_hp and not m.waves.valid_target("building",wall.id,Vector3.ZERO) and m.waves.navigation.fitted_blocker(giant,giant.pos)!=wall.id,"Side-fist obstruction stays solid and undamaged without becoming an attack target")
	check(giant.target_id==tower.id,"Temporary side obstruction preserves primary structure commitment")
	m=fresh();m.trees[Vector2i(-2,5)]=1.0;m.trees[Vector2i(2,5)]=1.0;m.rebuild_navigation();giant=m.waves.spawn_enemy(2,Vector3(0,0,60));giant.facing=0.0
	for i in range(200):m.waves.tick(.1,Vector3.ZERO)
	check(absf(giant.pos.x)>8.0 or giant.pos.z>39.0,"Giant cannot squeeze through24m tree gap with fitted clearance")
	m=fresh();worker={"id":90,"pos":Vector3(0,0,64),"hp":100.0,"max_hp":100.0,"state":"idle","job":-1};m.workers[90]=worker
	var archer=m.waves.spawn_enemy(1,Vector3(0,0,84));archer.facing=0.0
	m.waves.tick(.1,Vector3.ZERO);m.waves.tick(.8,Vector3.ZERO)
	check(worker.hp==100 and m.waves.projectiles.size()==1,"Archer launches traveling arrow without instant worker damage")
	for i in range(15):m.waves.tick(.05,Vector3.ZERO)
	check(worker.hp<100 and m.waves.projectiles.is_empty(),"Traveling arrow hits worker at physical contact")
	m=fresh();worker={"id":90,"pos":Vector3(0,0,64),"hp":100.0,"max_hp":100.0,"state":"idle","job":-1};m.workers[90]=worker;archer=m.waves.spawn_enemy(1,Vector3(0,0,84));archer.facing=0.0
	m.waves.tick(.1,Vector3.ZERO);m.waves.tick(.8,Vector3.ZERO);m.trees[Vector2i(0,12)]=1.0;m.rebuild_navigation()
	for i in range(15):m.waves.tick(.05,Vector3.ZERO)
	check(worker.hp==100,"Tree intercepts already traveling arrow")
	m=fresh();m.wave=2;m.phase="preparing";m.start_wave()
	# Permanent shared vision over the short staging ring must not stall a late wave.
	for x in range(-18,19):
		for z in range(-18,19):m.visible_cells[Vector2i(x,z)]=true
	m.waves.spawn_one()
	check(m.enemies.size()==1 and m.enemies.values()[0].variant==2,"Fully visible staging ring finds a farther unseen reachable giant approach")
	if not m.enemies.is_empty():check(m.enemies.values()[0].pos.length()>110,"Fallback staging stays outside full shared vision")
	m=fresh();worker={"id":90,"pos":Vector3(0,0,64),"hp":100.0,"max_hp":100.0,"state":"idle","job":-1};m.workers[90]=worker;archer=m.waves.spawn_enemy(1,Vector3(0,0,84));archer.facing=0.0
	m.waves.tick(.1,Vector3.ZERO);worker.pos=Vector3(60,0,64);m.waves.tick(1.0,Vector3.ZERO)
	check(worker.hp==100 and m.waves.projectiles.is_empty(),"Worker leaving range during windup cancels shot")
	m=fresh();archer=m.waves.spawn_enemy(1,Vector3(0,0,24));archer.facing=0.0;shrine_hp=m.shrine().hp
	m.waves.tick(.1,Vector3.ZERO);m.waves.tick(.8,Vector3.ZERO)
	for i in range(15):m.waves.tick(.05,Vector3.ZERO)
	check(m.shrine().hp<shrine_hp,"Archer with no workers physically hits shrine fallback")
	m=fresh();tower=m._make_building("tower",Vector2i(-1,10),0);m.rebuild_navigation();worker={"id":90,"pos":m.center(tower),"hp":100.0,"max_hp":100.0,"state":"garrison","job":tower.id};m.workers[90]=worker
	archer=m.waves.spawn_enemy(1,m.center(tower)+Vector3(0,0,10));archer.facing=0.0;m.waves.tick(.1,Vector3.ZERO);m.waves.tick(.8,Vector3.ZERO)
	for i in range(15):m.waves.tick(.05,Vector3.ZERO)
	check(worker.hp<100,"Exposed tower crew within the archer physical range is a valid ranged worker target")
	var real=load("res://scripts/forest/forest_model.gd").new();real.reset(42);real.wave=2;real.start_wave();real.waves.spawn_clock=10000
	var spawn_started=Time.get_ticks_usec();real.waves.spawn_one();var spawn_ms=(Time.get_ticks_usec()-spawn_started)/1000.0
	check(real.enemies.size()==1 and real.enemies.values()[0].variant==2,"Production forest admits a reachable giant staging approach")
	if not real.enemies.is_empty():
		var staged: Dictionary=real.enemies.values()[0]
		check(staged.pos.z>absf(staged.pos.x) and staged.pos.z>=80,"Production giant stages south of the gate beyond shared sight")
		check(real.waves.navigation.full_unseen(staged.pos,2),"Production giant staging respects complete shared footprint vision")
		var approach=real.waves.navigation.approach(staged,real.shrine())
		check(not approach.is_empty(),"Production giant staging has valid clearance route to shrine")
	print("GIANT_STAGING_FIRST_SEARCH_MS=%.2f"%spawn_ms)
	check(spawn_ms<500,"Bounded first staging search completes within half-second headless budget")
	var cached_started=Time.get_ticks_usec()
	for i in range(20):real.waves.giant_staging()
	print("GIANT_STAGING_20_CACHED_SEARCH_MS=%.2f"%((Time.get_ticks_usec()-cached_started)/1000.0))
	m=fresh();tower=m._make_building("tower",Vector2i(2,14),0);m.rebuild_navigation();m.visible_cells.clear()
	var fitted_stages: Array=m.waves.giant_staging()
	check(not fitted_stages.has(Vector3(0,0,84)),"Giant staging validates full fitted side fists against neighboring structures")
	# Watching the middle of the southern approach leaves far southern entries.
	var expanded=load("res://scripts/forest/forest_model.gd").new();expanded.reset(42);expanded.wave=2;expanded.start_wave();expanded.waves.spawn_clock=10000
	for x in range(-40,40):
		for z in range(-40,40):
			if absi(x)<30 or z<34:expanded.visible_cells[Vector2i(x,z)]=true
	expanded.waves.spawn_one()
	check(expanded.enemies.size()==1 and expanded.enemies.values()[0].variant==2,"Persistent central vision admits a validated far southern giant entry")
	if not expanded.enemies.is_empty():
		var corner: Vector3=expanded.enemies.values()[0].pos
		check(corner.z>absf(corner.x) and corner.z>210,"Far giant fallback remains on the southern map edge")
	# No route admits a giant while map obstacles cover every approach; smaller units can still enter.
	m=fresh()
	for x in range(-10,11):
		for z in range(-10,11):
			if Vector2(x,z).length()>=7 and Vector2(x,z).length()<=10 and x!=0:m.trees[Vector2i(x,z)]=1.0
	m.rebuild_navigation();m.wave=2;m.phase="preparing";m.start_wave();m.waves.spawn_one()
	check(m.enemies.size()==1 and m.enemies.values()[0].variant!=2 and m.waves.giant_pending,"Unavailable giant entry does not block the rest of the finite wave")
	m=fresh();m.wave=0;m.phase="preparing";m.workers.clear();m.waves.pending=0;m.enemies.clear()
	for wave_index in range(1,6):
		m.start_wave();var spawned=0;var giants=0
		while m.waves.pending>0 and spawned<300:
			m.waves.spawn_one()
			for e in m.enemies.values():
				spawned+=1
				if e.variant==2:
					giants+=1
					check(e.pos.length()>=80 and e.pos.length()<=102,"Giant stages80–100m from shrine")
					check(e.pos.length()-14>48,"Full giant spawn footprint is beyond shrine vision")
			m.enemies.clear()
		check(spawned==[0,72,108,144,180,240][wave_index],"Wave%d preserves finite count"%wave_index)
		check(giants==(1 if wave_index>=3 else 0),"Wave%d spawns the intended giant count"%wave_index)
		m.waves.tick(.1,Vector3.ZERO)
	check(m.phase=="victory" and not m.start_wave(),"All five waves resolve to victory without a sixth wave")
	m.reset(42)
	check(m.phase=="preparing" and m.wave==0 and m.enemies.is_empty() and m.waves.projectiles.is_empty(),"Retry resets enemies, projectile ownership and wave count")
	finish()
func finish():print("FOREST_ENEMY_ROLES_RESULT checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)
