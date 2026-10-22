extends SceneTree
## Real Forest player updates: release must follow the rendered casting hand.
var game
var checks = 0
var failures = 0
var balls: Array[Node3D] = []

func _initialize():call_deferred("run")

func check(ok: bool, label: String):
	checks += 1
	if not ok:failures += 1
	print("PASS " if ok else "FAIL ", label)

func frames(count: int):
	for i in range(count):await physics_frame

func capture_projectile(node: Node):
	if node is MusashiFireball:
		# Keep the emitted projectile at its spawn point for the release-frame check.
		node.set_physics_process(false)
		balls.append(node)

func fresh():
	var p = game.player
	p.musashi.cancel()
	await process_frame
	balls.clear()
	p.attack_chain.reset()
	p.clear_powerups()
	p.buildings_broken = 0
	p.scale = Vector3.ONE
	p.position = Vector3(0, .1, 70)
	p.velocity = Vector3.ZERO
	p.smoke_move = Vector2.ZERO
	p.air_turn = 0
	p.jumps_used = 0
	p.model.rotation = Vector3.ZERO
	p.model.locomotion.reset()
	game.camera_rig.yaw = 0
	for i in range(30):p._physics_process(1.0 / 60)

func run():
	game = load("res://scenes/forest_shrine.tscn").instantiate()
	# A nonexistent isolated path keeps the user's settings out of this fixture.
	game.settings_path = "user://edo-primary-alignment-%s.cfg" % OS.get_process_id()
	root.add_child(game)
	current_scene = game
	game.smoke_test = true
	game.tuning.freeze_ai = true
	game.tuning.invincible = true
	game.settings.volume = 0.0
	game.player.smoke_mode = true
	game.player.select_character(2)
	game.start_wave()
	game.model.waves.spawn_clock = 10000
	game.set_physics_process(false)
	game.player.set_physics_process(false)
	game.child_entered_tree.connect(capture_projectile)
	await frames(2)
	for rate in [30, 60, 120]:
		for moving in [false, true]:
			await fireball_release(rate, moving)
	await fireball_release(60, true, true)
	await casting_joints()
	await secondary_and_cancel()
	await beam_alignment()
	game.player.musashi.cancel()
	Input.action_release("light_attack")
	game.queue_free()
	current_scene = null
	paused = false
	await frames(3)
	print("EDO_PRIMARY_ALIGNMENT_RESULT checks=", checks, " failures=", failures)
	quit(1 if failures else 0)

func fireball_release(rate: int, moving: bool, airborne: bool = false):
	await fresh()
	var p = game.player
	var c = p.musashi
	if moving:
		p.smoke_move = Vector2.RIGHT
		game.camera_rig.yaw = PI / 2
	if airborne:
		p.position.y = 8
		p.jumps_used = 2
		p.air_turn = .42
		p.velocity.y = 5
	c.cast_fireball(false)
	for step in range(rate):
		p._physics_process(1.0 / rate)
		if not balls.is_empty():break
	var label = "%d Hz %s" % [rate, "moving/turning" if moving else "stationary"]
	if airborne:label += " in a somersault"
	check(balls.size() == 3, "Edo retains its three fireballs at " + label)
	if balls.is_empty():return
	var mismatch = balls[0].global_position.distance_to(p.model.hand_position("R"))
	check(mismatch < .001, "Edo projectile starts at the visible release hand at %s (error %.4f)" % [label, mismatch])
	check(c.progress() >= .27 and c.progress() < .27 + 1.0 / rate / c.duration + .001, "Edo release keeps its existing cast timing at " + label)
	check(balls.all(func(ball):return ball.damage == 24 and not ball.heavy), "Edo retains basic fireball damage at " + label)
	check(balls[0].velocity.normalized().dot(balls[2].velocity.normalized()) < .99, "Edo retains volley spread at " + label)
	check(is_equal_approx(balls[1].velocity.length() * balls[1].lifetime, 192.0), "Edo retains actual basic projectile travel at " + label)

func joint_rotations() -> Array[Quaternion]:
	var result: Array[Quaternion] = []
	var skeleton: Skeleton3D = game.player.model.skeleton
	for name_ in ["Arm_R", "Forearm_R", "Hand_R"]:
		var index = skeleton.find_bone(name_)
		var parent = skeleton.get_bone_global_pose(skeleton.get_bone_parent(index)).basis
		result.append((parent.inverse() * skeleton.get_bone_global_pose(index).basis).get_rotation_quaternion())
	return result

func casting_joints():
	await fresh()
	var p = game.player
	p.musashi.cast_fireball(false)
	p.musashi.elapsed = .12 * p.musashi.duration
	for step in range(30):p.model.animate(1.0 / 60, 0, true, 0, 0, false, 0, false)
	var windup = joint_rotations()
	var windup_hand: Vector3 = p.model.hand_position("R")
	p.musashi.elapsed = .27 * p.musashi.duration
	for step in range(30):p.model.animate(1.0 / 60, 0, true, 0, 0, false, 0, false)
	var release = joint_rotations()
	for index in range(3):
		check(windup[index].angle_to(release[index]) > .1, "Edo casting articulates the actual Goemon " + ["shoulder", "elbow", "wrist"][index])
	check(windup_hand.distance_to(p.model.hand_position("R")) > .65, "Edo wind-up drives the visible hand through a full casting arc")

func secondary_and_cancel():
	await fresh()
	var p = game.player
	var c = p.musashi
	c.cast_fireball(true)
	for step in range(60):
		p._physics_process(1.0 / 60)
		if not balls.is_empty():break
	check(balls.size() == 1 and balls[0].heavy and balls[0].damage == 96, "Edo giant secondary remains one heavy 96-damage fireball")
	if not balls.is_empty():
		check(balls[0].global_position.distance_to(p.model.hand_position("R")) < .001, "Edo giant secondary also releases from its visible hand")
		check(is_equal_approx(balls[0].velocity.length() * balls[0].lifetime, 76.0), "Edo giant secondary keeps its original travel range")
	await fresh()
	c.cast_fireball(false)
	c.tick(.12)
	c.cancel()
	p._physics_process(1.0 / 60)
	check(balls.is_empty(), "Cancel between contact and pose update cannot emit a stale fireball")
	p.attack_chain.count = 100
	var visible_hand: Vector3 = p.model.hand_position("R")
	c.cast_fireball(false)
	check(balls.size() == 3 and c.available() and p.attack_left == 0, "Unleashed keeps its immediate fireball release")
	if not balls.is_empty():check(balls[0].global_position.distance_to(visible_hand) < .001, "Unleashed emits from the hand visible at its instant release")

func target_at(center: Vector3) -> Ninja:
	var target = Ninja.new()
	target.game = game
	target.training_dummy = true
	target.practice = true
	target.position = center - Vector3.UP * 1.1
	game.add_child(target)
	target.set_physics_process(false)
	target.hp = 10000
	target.max_hp = 10000
	game.enemies.append(target)
	return target

func beam_alignment():
	await fresh()
	var p = game.player
	var c = p.musashi
	c.shield_left = 10
	Input.action_press("light_attack")
	c.start_beam("light_attack")
	var beam = c.beam
	beam.set_physics_process(false)
	for step in range(8):
		p._physics_process(1.0 / 60)
		beam.update_path()
	var hand = p.model.hand_position("R")
	check(beam.global_position.distance_to(hand) < .001, "Edo beam damage begins at the visible casting hand")
	check(beam.source.global_position.distance_to(hand) < .001, "Edo beam flare follows the same hand")
	var shell_start: Vector3 = beam.shells[0].to_global(Vector3(0, .5, 0))
	check(shell_start.distance_to(hand) < .001, "Edo beam shell begins at the visible casting hand")
	var visible_end: Vector3 = beam.tip.global_position
	check(visible_end.distance_to(hand + beam.direction * beam.length_now) < .001, "Edo visible beam end matches its damage-range endpoint")
	check(is_equal_approx(beam.length_now, game.hero_tuning("beam_length") * 3), "Edo empowered basic preserves its configured extended range")
	var inside = target_at(hand + beam.direction * (beam.length_now - .2))
	var outside = target_at(hand + beam.direction * (beam.length_now + .2))
	beam.damage_tick()
	check(inside.hp < 10000, "Edo beam damages an enemy just inside its visible endpoint")
	check(outside.hp == 10000, "Edo beam cannot damage an enemy beyond its visible endpoint")
