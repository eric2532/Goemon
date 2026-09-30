class_name SwarmSurvival
extends EndlessEncounters

const DURATION=600.0
const INTERVAL=10.0
const FIRST_WAVE=100
const GROWTH_PER_MINUTE=10
const TOTAL_WAVES=60
const SPAWN_BUDGET=12
const SPAWN_TIME_USEC=3000
var elapsed=0.0
var wave=0
var pending=0
var total_spawned=0
var total_scheduled=0
var total_skipped=0
var alive_count=0
var active=false
var spawn_rng=RandomNumberGenerator.new()
var spawn_probe: PhysicsShapeQueryParameters3D

func reset():
	active=false;elapsed=0;wave=0;pending=0;total_spawned=0;alive_count=0
	slots.clear();respawn_count=0;total_scheduled=0;total_skipped=0

func begin():
	reset();enabled=true;active=true
	spawn_rng.seed=game.run_seed
	var capsule=CapsuleShape3D.new();capsule.radius=.72;capsule.height=1.85
	spawn_probe=PhysicsShapeQueryParameters3D.new();spawn_probe.shape=capsule;spawn_probe.collision_mask=1
	queue_wave()

func remaining()->float:return maxf(0,DURATION-elapsed)
func next_wave_in()->float:return maxf(0,wave*INTERVAL-elapsed) if wave<TOTAL_WAVES else 0.0
func wave_size(number: int)->int:return FIRST_WAVE+floori(float(number-1)/6.0)*GROWTH_PER_MINUTE
func clock_text(seconds: float)->String:
	var rounded=ceili(maxf(0,seconds))
	return "%02d:%02d" % [rounded/60,rounded%60]

func queue_wave():
	wave+=1
	# Each wave replaces its unplaced request. Demand beyond available room is
	# skipped, never banked for a burst after a kill or a long paused frame.
	total_skipped+=pending
	var requested=wave_size(wave)
	total_scheduled+=requested
	pending=mini(requested,game.enemy_spawn_capacity())
	total_skipped+=requested-pending
	game.hud.banner="WAVE %02d · %d INCOMING · LIMIT %d" % [wave,pending,game.active_enemy_limit]
	game.hud.banner_time=2.5

func tick(delta: float):
	if not enabled or not active or not game.playing or game.paused or game.transitioning or game.player.hp<=0:return
	elapsed=minf(DURATION,elapsed+maxf(0,delta))
	# Win at zero; never spawn an extra wave after the survival period.
	if elapsed>=DURATION:
		active=false;pending=0
		game.survival_victory()
		return
	while wave<TOTAL_WAVES and elapsed+0.000001>=wave*INTERVAL:queue_wave()
	alive_count=game.active_enemy_count()
	spawn_pending()

func spawn_pending():
	if not enabled or not active or not game.playing or game.paused or game.transitioning or game.player.hp<=0:return
	var room=game.enemy_spawn_capacity()
	if pending>room:
		total_skipped+=pending-room
		pending=room
	var deadline=Time.get_ticks_usec()+SPAWN_TIME_USEC
	for i in range(mini(SPAWN_BUDGET,pending)):
		var point=wave_spawn_point()
		if point==null:break # Retry only until the next wave; requests never accumulate.
		var enemy=Ninja.new();enemy.game=game;enemy.swarm=true
		enemy.encounter_id="swarm_%d" % total_spawned
		enemy.formation_index=total_spawned
		enemy.variant=total_spawned%3 # All swarm enemies close to melee range.
		enemy.position=point;enemy.alerted=true;enemy.state="chase"
		enemy.process_mode=Node.PROCESS_MODE_PAUSABLE
		game.add_child(enemy);game.enemies.append(enemy)
		pending-=1;total_spawned+=1;alive_count+=1
		if Time.get_ticks_usec()>=deadline:break

func wave_spawn_point():
	var focus: Vector3=game.pursuit.destination()
	var space=game.get_world_3d().direct_space_state
	for attempt in range(64):
		# Visit opposite sides in turn. If terrain blocks a sector, try the next
		# one rather than dropping the enemy or forcing a spawn through a wall.
		var sector=(total_spawned*7+floori(attempt/4.0)*7)%16
		var angle=TAU*(sector+spawn_rng.randf_range(.1,.9))/16.0+wave*.37
		var radius=spawn_rng.randf_range(22,38)
		var point=focus+Vector3(cos(angle),0,sin(angle))*radius
		if not game.world.playable_bounds.grow(-3).has_point(Vector2(point.x,point.z)):continue
		point.y=game.world.height_at(point.x,point.z)
		if point.y<0:continue
		var floor_hit=space.intersect_ray(PhysicsRayQueryParameters3D.create(point+Vector3.UP*1.8,point-Vector3.UP,1))
		if floor_hit.is_empty() or floor_hit.normal.y<.72:continue
		point.y=floor_hit.position.y+.12
		spawn_probe.transform=Transform3D(Basis.IDENTITY,point+Vector3.UP*.96)
		if not space.intersect_shape(spawn_probe,1).is_empty():continue
		# Reject isolated courtyards and the wrong side of solid walls unless the
		# shared navigation field provides a connected route to the hero.
		if not game.pursuit.clear_segment(point,focus):
			var cell=game.pursuit.cell_of(point)
			if not game.pursuit.distances.has(cell):continue
			if not game.pursuit.clear_segment(point,game.pursuit.ground(cell)):continue
		return point
	return null
