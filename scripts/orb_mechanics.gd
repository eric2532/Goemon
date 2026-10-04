extends Node

const BURST_RADIUS=7.0
const FIRE_DAMAGE=100.0
const FREEZE_SECONDS=2.0
const MAGNET_INTERVAL=30.0
var game: Node
var rng=RandomNumberGenerator.new()
var active=false
var magnet_clock=0.0
var burst_clock=0.0
var pickup_clock=0.0
var pending: Array[String]=[]
var ice_bursts=0
var fire_bursts=0

func begin():
	reset();active=true;rng.seed=game.run_seed+9173;magnet_clock=1.0

func reset():
	active=false;pending.clear();burst_clock=0;pickup_clock=0;ice_bursts=0;fire_bursts=0
	for group in ["orb_magnets","elemental_vfx","energy_pickups"]:
		for node in get_tree().get_nodes_in_group(group):node.queue_free()

func drop(point: Vector3):
	for i in range(rng.randi_range(1,5)):
		var pickup=EnergyPickup.new();pickup.game=game
		pickup.kind=EnergyPickup.DROP_KINDS[rng.randi_range(0,2)]
		var angle=rng.randf()*TAU
		var offset=Vector3(cos(angle),0,sin(angle))*rng.randf_range(.15,1.1)
		var candidate=point+offset
		var ray=PhysicsRayQueryParameters3D.create(point+Vector3.UP,candidate+Vector3.UP,1)
		if not game.get_world_3d().direct_space_state.intersect_ray(ray).is_empty():candidate=point
		candidate.y=game.world.height_at(candidate.x,candidate.z)+.1
		if candidate.y<0:candidate=point
		pickup.position=candidate;game.add_child(pickup)

func pickup_feedback(kind: String):
	if pickup_clock>0:return
	pickup_clock=.08
	game.sound("spark",.25)
	game.burst(game.player.global_position+Vector3.UP,EnergyPickup.COLORS[kind],3,.4)

func queue_burst(kind: String):pending.append(kind)

func _physics_process(delta):
	if not active or not game.playing or game.paused or game.transitioning or game.player.hp<=0:return
	pickup_clock=maxf(0,pickup_clock-delta);burst_clock=maxf(0,burst_clock-delta)
	# Pace simultaneous magnet rewards, retaining every completed set of five.
	if not pending.is_empty() and burst_clock<=0 and not game.player.sky_strike.active:
		burst(pending.pop_front());burst_clock=.12
	if not game.descent_mode:
		magnet_clock-=delta
		if magnet_clock<=0:
			magnet_clock=MAGNET_INTERVAL if spawn_magnet() else 3.0

func burst(kind: String):
	var origin=game.player.global_position
	if kind=="fire":
		fire_bursts+=1
		var effect=EdoFireExplosion.new();effect.game=game;effect.sound_slot="orb_fire";effect.position=origin
		game.add_child(effect);effect.add_to_group("elemental_vfx");effect.scale=Vector3.ONE # Visual footprint only; BURST_RADIUS remains 7m.
	else:
		ice_bursts+=1
		var effect=preload("res://scripts/ice_burst.gd").new();effect.game=game;effect.position=origin;game.add_child(effect)
		game.sound("orb_ice",.55)
	for enemy in game.enemies:
		if not is_instance_valid(enemy) or enemy.dead:continue
		var offset=enemy.global_position-origin
		if Vector2(offset.x,offset.z).length()>BURST_RADIUS+enemy.body_radius or absf(offset.y)>4:continue
		if not game.pursuit.clear_segment(origin,enemy.global_position):continue
		if kind=="ice":enemy.freeze_for(FREEZE_SECONDS)
		else:enemy.take_hit(FIRE_DAMAGE*game.player.damage_multiplier(),offset.normalized(),true)

func magnet_collect()->int:
	var count=0
	for pickup in get_tree().get_nodes_in_group("energy_pickups"):
		if pickup.is_queued_for_deletion() or pickup.collected:continue
		pickup.attract_from_magnet();count+=1
	game.sound("orb_magnet",.7)
	game.toast("MAGNET · %d orbs drawn in" % count)
	return count

func spawn_magnet()->bool:
	if get_tree().get_nodes_in_group("orb_magnets").size()>=3:return true
	var focus=game.pursuit.destination()
	for attempt in range(36):
		var angle=rng.randf()*TAU
		var candidate=focus+Vector3(cos(angle),0,sin(angle))*rng.randf_range(16,100)
		var cell=game.pursuit.cell_of(candidate)
		var ground=game.pursuit.ground(cell)
		if ground==null or ground.distance_to(focus)<12:continue
		var crowded=false
		for existing in get_tree().get_nodes_in_group("orb_magnets"):
			if ground.distance_to(existing.position)<12:crowded=true;break
		if crowded:continue
		if not game.pursuit.clear_segment(ground,focus) and not game.pursuit.distances.has(cell):continue
		var magnet=preload("res://scripts/orb_magnet.gd").new();magnet.game=game;magnet.position=ground
		game.add_child(magnet);return true
	return false
