extends Node
## Native Rogue combat running on Sonic's real player body and enemy population.
## The imported actions retain their kits; this facade supplies physical terrain,
## damage attribution, native feedback, and lifecycle handling for Tower Defense.
const Actions = preload("res://assets/rogue/scripts/class_actions.gd")
const COMBO = [
	{"duration": 0.29, "contact": 0.075, "damage": 25, "reach": 2.85, "arc": 1.08, "impulse": 2.7, "stop": 0.045},
	{"duration": 0.33, "contact": 0.095, "damage": 30, "reach": 3.05, "arc": 1.3, "impulse": 3.2, "stop": 0.055},
	{"duration": 0.49, "contact": 0.15, "damage": 48, "reach": 3.35, "arc": 1.55, "impulse": 6.5, "stop": 0.085}
]
const MAX_PROJECTILES = 160
const ELEMENT_COLORS = {"fire": Color("ff9a5e"), "ice": Color("9de8ff"), "lightning": Color("c4a5ff")}
var hero: Hero
var game: Node
var class_id: String = "pirate"
var active: bool = false
var player: Dictionary = {}
var roster: Array = []
var projectiles: Array = []
var aim: Vector3 = Vector3.ZERO
var move_input: Vector3 = Vector3.ZERO
var primary_held: bool = false
var secondary_held: bool = false
var attack_buffer: float = 0.0
var combo: int = 0
var combo_timer: float = 0.0
var hit_stop: float = 0.0
var time: float = 0.0
var fx: Node3D
var sound: Node
var visual_actor: Node3D
var _ticket: Dictionary = {}
var _resolution_ticket: Dictionary = {}
var _damage_origin: Vector3 = Vector3.ZERO
var _projectile_damage: bool = false
var _hooks: Node3D
var _hook_markers: Array[Node3D] = []
var _hook_cache: Array[Vector3] = []
var _hook_cell: Vector2i = Vector2i(999999, 999999)
var _setup_done: bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE

func configure(owner: Hero, id: String) -> void:
	hero = owner
	game = hero.game
	class_id = id
	if roster.is_empty():
		var data = JSON.parse_string(FileAccess.get_file_as_string("res://assets/rogue/data/classes.json"))
		if data is Array:
			roster = data
	if not is_instance_valid(fx):
		fx = game.get_node_or_null("RogueSharedClassEffects")
	if not is_instance_valid(fx):
		fx = load("res://assets/rogue/scripts/effects.gd").new()
		fx.name = "RogueSharedClassEffects"
		fx.process_mode = Node.PROCESS_MODE_PAUSABLE
		game.add_child(fx)
	if not is_instance_valid(sound):
		sound = game.get_node_or_null("RogueSharedClassAudio")
	if not is_instance_valid(sound):
		sound = load("res://assets/rogue/scripts/audio.gd").new()
		sound.name = "RogueSharedClassAudio"
		sound.process_mode = Node.PROCESS_MODE_PAUSABLE
		game.add_child(sound)
		# Tower Defense retains its own ambient/music presentation.
		if is_instance_valid(sound.get("ambience")):
			sound.ambience.stop()
	_setup_done = true
	reset_run()

func sync_actor(actor: Node3D) -> void:
	visual_actor = actor
	if not player.is_empty():
		player.actor = actor

func _fresh_player() -> Dictionary:
	return {"pos": hero.global_position, "vel": Vector3.ZERO, "angle": atan2(hero.facing.x, hero.facing.z),
		"hp": hero.hp, "maxHp": hero.max_hp, "cooldowns": {"cutlass": 0.0, "flintlock": 0.0, "roll": 0.0, "drink": 0.0},
		"sockets": {"cutlass": [], "flintlock": []}, "attack": null,
		"roll": 0.0, "rollDir": Vector3.ZERO, "rollDuration": 0.32, "rollSpeed": 12.5, "rollStyle": "roll", "rollTicket": {},
		"drink": 0.0, "invuln": 0.0, "shot": 0.0, "drinkGesture": 0.0,
		"buffName": "", "buffTime": 0.0, "buffDuration": 0.0, "blockMeter": 0.0, "blocking": false,
		"crouched": false, "riposte": 0.0, "travel": null, "burst": null, "secondaryBuffer": null,
		"untargetable": 0.0, "classId": class_id, "id": class_id, "isPlayer": true, "actor": visual_actor}

func reset_run() -> void:
	_clear_projectiles()
	if is_instance_valid(fx):
		fx.clear()
	primary_held = false
	secondary_held = false
	attack_buffer = 0.0
	combo = 0
	combo_timer = 0.0
	hit_stop = 0.0
	time = 0.0
	_ticket = {}
	_resolution_ticket = {}
	_hook_cell = Vector2i(999999, 999999)
	_hook_cache.clear()
	if is_instance_valid(_hooks):
		_hooks.hide()
	if hero != null:
		player = _fresh_player()
		hero.attack_left = 0
		hero.impact_pause = 0
		_animate(0, 0)

func class_data() -> Dictionary:
	for entry in roster:
		if entry.id == class_id:
			return entry
	return {"id": class_id, "hero": false, "speed": 5.15, "maxHealth": 100, "color": "#e4b86b",
		"cooldowns": {"cutlass": 0.3, "flintlock": 1.65, "roll": 1.05, "drink": 15}, "abilities": {}}

func tint() -> Color:
	return Color(class_data().color)

func input(event: InputEvent) -> void:
	release_input(event)
	if not active or event.is_echo() or not game.playing or game.paused or game.transitioning:
		return
	_update_aim()
	if event.is_action_pressed("light_attack"):
		primary_held = true
		action("cutlass")
	elif event.is_action_pressed("heavy_attack"):
		secondary_held = true
		action("flintlock")
	elif event.is_action_pressed("dodge") or event.is_action_pressed("equip"):
		action("roll")
	elif event.is_action_pressed("surge"):
		action("drink")
	elif event.is_action_pressed("jump"):
		hero.jump_buffer = 0.15

func release_input(event: InputEvent) -> void:
	if event.is_action_released("light_attack"):
		primary_held = false
	if event.is_action_released("heavy_attack"):
		secondary_held = false
		if not player.is_empty():
			player.blocking = false

func action(slot: String) -> void:
	if not active or player.is_empty() or not player.cooldowns.has(slot):
		return
	player.pos = hero.global_position
	_update_aim()
	if slot == "roll" and player.attack == null and player.roll <= 0 and player.travel == null:
		player.angle = atan2(aim.x - player.pos.x, aim.z - player.pos.z)
	if slot == "cutlass":
		attack_buffer = 0.17
		if _can_primary() and hit_stop <= 0:
			attack()
		return
	if class_id != "pirate":
		Actions.class_action(self, slot)
		_sync_hero()
		return
	var p: Dictionary = player
	if slot == "flintlock":
		if p.cooldowns.flintlock > 0 or p.roll > 0 or p.travel != null:
			p.secondaryBuffer = {"remaining": 0.24}
			return
		begin_cast("secondary")
		p.secondaryBuffer = null
		p.cooldowns.flintlock = class_data().cooldowns.flintlock
		p.shot = 0.28
		p.angle = atan2(aim.x - p.pos.x, aim.z - p.pos.z)
		var start: Vector3 = p.pos + Vector3.UP * 1.3 * hero.growth_multiplier()
		var dir: Vector3 = projectile_direction(p.angle, start)
		var end: Vector3 = start + dir * 17 * range_scale()
		var wall: Dictionary = _terrain_hit(start, end, 0.055)
		if not wall.is_empty():
			end = wall.position
		var targets: Array = _segment_targets(start, end, 0.24 * range_scale())
		if not targets.is_empty():
			var enemy: Dictionary = targets[0].e
			_resolution_ticket = _ticket
			_damage_origin = start
			_projectile_damage = true
			hit(enemy, 82, "flintlock", true, dir, "", "gun")
			_projectile_damage = false
			end = enemy.pos + Vector3.UP * 1.2
		fx.streak(start + dir * 0.75, end, Color("ffecc3"), 0.055, 0.16)
		fx.muzzle(p.pos, p.angle, Color("ffdba1"), "gun")
		fx.smoke(start, 12, Color("a7a092"))
		fx.ring(p.pos, Color("ffc282"), 1.6, 0.22)
		fx.shake = maxf(fx.shake, 0.23)
		p.vel -= dir * 3.2
		sound.play("shot")
	elif slot == "roll" and p.cooldowns.roll <= 0 and p.roll <= 0 and p.travel == null:
		begin_cast("utility")
		p.rollDir = movement_direction()
		p.roll = 0.32
		p.rollDuration = 0.32
		p.rollSpeed = 12.5
		p.invuln = 0.36
		p.cooldowns.roll = class_data().cooldowns.roll
		p.attack = null
		attack_buffer = 0
		sound.play("roll")
		fx.smoke(p.pos, 5, Color("718d91"))
	elif slot == "drink" and p.cooldowns.drink <= 0:
		begin_cast("skill")
		p.drink = 5.0
		p.drinkGesture = 0.8
		p.cooldowns.drink = class_data().cooldowns.drink
		sound.play("drink")
		fx.ring(p.pos, Color("68e5cf"), 3, 0.6)
		fx.damage(p.pos, "UNTOUCHABLE", "ice")
		toast("Drink · Untargetable for 5 seconds")
	_sync_hero()

func _can_primary() -> bool:
	return player.attack == null and player.roll <= 0 and player.travel == null and player.cooldowns.cutlass <= 0 and not player.blocking

func attack() -> void:
	begin_cast("primary")
	if class_id != "pirate":
		Actions.begin_primary(self)
		return
	var index: int = combo % 3 if combo_timer > 0 else 0
	combo = index + 1
	combo_timer = 1.1
	attack_buffer = 0
	player.angle = atan2(aim.x - player.pos.x, aim.z - player.pos.z)
	var a: Dictionary = COMBO[index].duplicate(true)
	a.rangeScale = range_scale()
	a.reach *= a.rangeScale
	a.merge({"index": index, "time": 0.0, "hit": false, "angle": player.angle, "style": "sword", "weapon": "cutlass", "ticket": current_ticket()}, true)
	player.attack = a
	player.cooldowns.cutlass = a.duration
	player.vel += front(player.angle) * (3.1 if index == 2 else 2.1)

func begin_cast(kind: String) -> void:
	_ticket = hero.attack_chain.begin("rogue_" + class_id + "_" + kind)
	_ticket["rogue_range_scale"] = hero.range_multiplier()
	hero.attack_ticket = _ticket

func current_ticket() -> Dictionary:
	if _ticket.is_empty():
		begin_cast("primary")
	return _ticket

func range_scale() -> float:
	return float(_ticket.get("rogue_range_scale", hero.range_multiplier()))

func projectile_direction(angle: float, origin: Vector3) -> Vector3:
	var direction: Vector3 = front(angle)
	var offset: Vector3 = aim + Vector3.UP * 1.1 - origin
	var horizontal: float = Vector2(offset.x, offset.z).length()
	direction.y = offset.y / maxf(0.5, horizontal)
	return direction.normalized()

func use_ticket(ticket: Dictionary) -> void:
	_ticket = ticket

func tick_timers(delta: float) -> void:
	if player.is_empty():
		return
	var tempo: float = hero.attack_speed_multiplier()
	for key in player.cooldowns:
		player.cooldowns[key] = maxf(0, player.cooldowns[key] - delta * (tempo if key in ["cutlass", "flintlock"] else 1.0))
	for key in ["invuln", "drink", "shot", "drinkGesture"]:
		player[key] = maxf(0, player[key] - delta)
	hero.invuln = maxf(0, hero.invuln - delta)
	hero.jump_buffer = maxf(0, hero.jump_buffer - delta)
	hero.coyote = maxf(0, hero.coyote - delta)
	combo_timer = maxf(0, combo_timer - delta)
	attack_buffer = maxf(0, attack_buffer - delta)
	if class_id != "pirate":
		Actions.update_class(self, delta)
	elif player.secondaryBuffer != null:
		player.secondaryBuffer.remaining -= delta
		if player.secondaryBuffer.remaining <= 0:
			player.secondaryBuffer = null
		elif player.cooldowns.flintlock <= 0 and player.roll <= 0:
			action("flintlock")

func tick(delta: float, update_timers: bool = true) -> void:
	if not active or player.is_empty():
		return
	if update_timers:
		if hit_stop > 0:
			hit_stop = maxf(0, hit_stop - delta)
			return
		tick_timers(delta)
	time += delta
	var combat_delta: float = delta * hero.attack_speed_multiplier()
	if player.attack != null:
		var a: Dictionary = player.attack
		a.time += combat_delta
		if a.time >= a.contact and not a.hit:
			a.hit = true
			_resolution_ticket = a.ticket
			_damage_origin = player.pos + Vector3.UP
			_projectile_damage = false
			use_ticket(a.ticket)
			if class_id == "pirate":
				fx.slash(player.pos, a.angle, a.index, tint(), a.reach, {"style": "sword", "arc": a.arc * 2, "height": 1.05})
				sound.play("blade", {"style": "pirate", "combo": a.index})
				var hits: int = 0
				for e in living():
					if in_arc(player.pos, e.pos, a.angle, a.reach + e.radius, a.arc):
						hit(e, a.damage, "cutlass", a.index == 2, front(a.angle), "", "cutlass")
						hits += 1
				if hits > 0:
					hit_stop = maxf(hit_stop, a.stop)
			else:
				Actions.resolve_attack(self, a)
		if a.time >= a.duration:
			player.attack = null
	if (primary_held or attack_buffer > 0) and _can_primary():
		attack()
	for i in range(projectiles.size() - 1, -1, -1):
		var projectile: Dictionary = projectiles[i]
		if not is_instance_valid(projectile.mesh):
			projectiles.remove_at(i)
			continue
		Actions.update_projectile(self, projectile, delta)
		if projectile.life <= 0:
			projectile.mesh.queue_free()
			projectiles.remove_at(i)
	_sync_hero()

func physics_step(delta: float) -> void:
	if not active or player.is_empty() or not game.playing or game.paused or game.transitioning or hero.hp <= 0:
		return
	_update_aim()
	player.pos = hero.global_position
	player.hp = hero.hp
	if hit_stop > 0:
		hit_stop = maxf(0, hit_stop - delta)
		hero.impact_pause = hit_stop
		return
	hero.impact_pause = 0
	tick_timers(delta)
	var raw: Vector2 = hero.smoke_move if hero.smoke_mode else Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	move_input = Vector3(raw.x, 0, raw.y).rotated(Vector3.UP, game.camera_rig.yaw).limit_length()
	var previous: Vector3 = hero.global_position
	if player.travel != null:
		step_travel(delta)
	else:
		_move_body(delta)
	player.pos = hero.global_position
	if player.attack == null and player.roll <= 0 and player.travel == null:
		player.angle = lerp_angle(player.angle, atan2(aim.x - player.pos.x, aim.z - player.pos.z), minf(1, delta * 20))
	tick(delta, false)
	_enforce_bounds()
	_sync_hero()
	_animate(delta * hero.attack_speed_multiplier(), Vector2(hero.global_position.x - previous.x, hero.global_position.z - previous.z).length() / maxf(delta, 0.001) / maxf(0.1, class_data().speed))
	_update_hooks()

func _move_body(delta: float) -> void:
	var p: Dictionary = player
	if hero.is_on_floor():
		hero.coyote = 0.13
		hero.jumps_used = 0
	if p.roll > 0:
		var portion: float = minf(delta, p.roll)
		p.roll = maxf(0, p.roll - delta)
		hero.velocity.x = p.rollDir.x * p.rollSpeed * portion / maxf(delta, 0.0001)
		hero.velocity.z = p.rollDir.z * p.rollSpeed * portion / maxf(delta, 0.0001)
		if p.roll <= 0:
			use_ticket(p.rollTicket)
			Actions.finish_dash(self)
	else:
		var multiplier: float = 0.72 if p.crouched else (0.58 if p.blocking else 1.0)
		if p.attack != null and p.attack.time < 0.15:
			multiplier *= 0.5
		var base_speed: float = game.tuning.sprint_speed if Input.is_action_pressed("sprint") else game.tuning.walk_speed
		if Input.is_action_pressed("walk_modifier"):
			multiplier *= 0.5
		var motion: Vector3 = move_input * base_speed * (class_data().speed / 5.15) * hero.progression.movement_multiplier() * multiplier + p.vel
		hero.velocity.x = motion.x
		hero.velocity.z = motion.z
		p.vel *= exp(-12 * delta)
	if hero.jump_buffer > 0 and p.roll <= 0:
		if hero.coyote > 0 or hero.jumps_used < 2:
			var grounded: bool = hero.coyote > 0
			hero.velocity.y = (game.tuning.jump_speed if grounded else game.tuning.second_jump_speed) * hero.progression.jump_velocity_multiplier()
			hero.jumps_used = 1 if grounded else 2
			hero.jump_buffer = 0
			hero.coyote = 0
	if not hero.is_on_floor():
		hero.velocity.y = maxf(-55, hero.velocity.y - 30 * delta)
	elif hero.velocity.y < 0:
		hero.velocity.y = 0
	# Match the existing body step-up allowance; this never bypasses tall cover.
	var horizontal: Vector3 = Vector3(hero.velocity.x, 0, hero.velocity.z) * delta
	if hero.is_on_floor() and hero.test_move(hero.global_transform, horizontal):
		var raised: Transform3D = hero.global_transform
		raised.origin.y += 0.32
		if not hero.test_move(raised, horizontal):
			hero.global_position.y += 0.32
	hero.move_and_slide()

func step_travel(delta: float) -> void:
	var t = player.travel
	if t == null:
		return
	t.time += delta
	var amount: float = minf(1, t.time / t.duration)
	var destination: Vector3 = t.start.lerp(t.target, amount)
	destination.y += sin(amount * PI) * t.height
	var collision: KinematicCollision3D = hero.move_and_collide(destination - hero.global_position)
	player.pos = hero.global_position
	hero.velocity = Vector3.ZERO
	if amount >= 1 or collision != null:
		if t.impact:
			use_ticket(t.ticket)
			_resolution_ticket = t.ticket
			_damage_origin = player.pos + Vector3.UP
			fx.spell_burst(player.pos, player.angle, tint(), 2.65 * t.rangeScale)
			Actions.area(self, player.pos, 2.65, 85, "flintlock", true, tint(), "slam", t.rangeScale)
		player.travel = null
		fx.ring(player.pos, tint(), 3 if t.kind == "lance-leap" else 1.25, 0.3)

func blink_to(destination: Vector3) -> void:
	destination = clamp_arena(destination)
	hero.move_and_collide(destination - hero.global_position)
	player.pos = hero.global_position
	hero.velocity = Vector3.ZERO

func _enforce_bounds() -> void:
	var bounds: Rect2 = game.world.playable_bounds.grow(-1)
	if hero.global_position.y < -5 or not bounds.grow(4).has_point(Vector2(hero.global_position.x, hero.global_position.z)):
		hero.hp = maxf(1, hero.hp - 10)
		hero.global_position = game.checkpoint
		hero.velocity = Vector3.ZERO
		player.travel = null
		player.roll = 0
		game.camera_rig.reset_follow()
	player.pos = hero.global_position

func _sync_hero() -> void:
	if player.is_empty():
		return
	hero.facing = front(player.angle)
	hero.invuln = maxf(hero.invuln, player.invuln)
	hero.dodge_time = player.roll
	hero.dodge_cooldown = player.cooldowns.roll
	hero.attack_left = maxf(0, player.attack.duration - player.attack.time) if player.attack != null else 0.0
	hero.attack_duration = player.attack.duration if player.attack != null else 0.4
	hero.combo = int(player.attack.index) + 1 if player.attack != null else 0
	hero.attack_heavy = player.attack != null and int(player.attack.index) == 2
	player.hp = hero.hp
	player.maxHp = hero.max_hp

func _animate(delta: float, movement: float) -> void:
	if not is_instance_valid(visual_actor) or player.is_empty():
		return
	if active:
		hero.model.rotation.y = atan2(-hero.facing.x, -hero.facing.z)
	var pose: Dictionary = player
	if player.travel != null:
		pose = player.duplicate()
		pose.travel = player.travel.duplicate()
		pose.travel.height = 0.0 # The real collision body already follows the arc.
	visual_actor.animate_pose(pose, delta, time, minf(1, movement))

func _process(delta: float) -> void:
	if not active or not _setup_done or not game.playing or game.paused or game.transitioning:
		return
	fx.tick(delta)
	sound.set_volume(float(game.settings.volume))
	game.camera_rig.impulse = maxf(game.camera_rig.impulse, minf(0.23, fx.shake))

func _update_aim() -> void:
	if not is_instance_valid(game) or not is_instance_valid(hero):
		return
	if is_instance_valid(game.get("rogue_view")):
		game.rogue_view.update_aim()
		aim = game.rogue_view.aim
	else:
		aim = hero.global_position + hero.facing * 8
	var raw: Vector2 = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	move_input = Vector3(raw.x, 0, raw.y).rotated(Vector3.UP, game.camera_rig.yaw)

static func front(angle: float) -> Vector3:
	return Vector3(sin(angle), 0, cos(angle))

func movement_direction() -> Vector3:
	return move_input.normalized() if move_input.length_squared() > 0.1 else front(player.angle)

func clamp_arena(pos: Vector3) -> Vector3:
	var bounds: Rect2 = game.world.playable_bounds.grow(-1)
	pos.x = clampf(pos.x, bounds.position.x, bounds.end.x)
	pos.z = clampf(pos.z, bounds.position.y, bounds.end.y)
	return pos

func clear_line(from: Vector3, to: Vector3) -> bool:
	return _terrain_hit(from, to).is_empty()

func in_arc(origin: Vector3, target: Vector3, angle: float, reach: float, half_angle: float) -> bool:
	var offset: Vector3 = target - origin
	if absf(offset.y) > 3.0:
		return false
	offset.y = 0
	return offset.length() <= reach and absf(wrapf(atan2(offset.x, offset.z) - angle, -PI, PI)) <= half_angle and clear_line(origin + Vector3.UP, target + Vector3.UP)

static func segment_distance(point: Vector3, a: Vector3, b: Vector3) -> Dictionary:
	var line: Vector3 = b - a
	var t: float = clampf((point - a).dot(line) / line.length_squared(), 0, 1) if line.length_squared() > 0.0001 else 0.0
	return {"distance": point.distance_to(a + line * t), "t": t}

func living() -> Array:
	var result: Array = []
	for enemy in game.enemies:
		if not is_instance_valid(enemy) or enemy.dead or enemy.hp <= 0:
			continue
		if game.has_method("forest_enemy_visible") and not game.forest_enemy_visible(enemy):continue
		result.append({"node": enemy, "uid": enemy.get_instance_id(), "pos": enemy.global_position,
			"hp": enemy.hp, "maxHp": enemy.max_hp, "type": "warden" if enemy.boss or (enemy.defense_traits != null and enemy.defense_traits.is_boss()) else "revenant",
			"radius": enemy.body_radius, "vel": enemy.velocity, "attackCD": enemy.cooldown, "slow": 0.0, "slowAmount": 0.0})
	return result

# The default empty argument is the active_ability incoming-hit interface. The
# native action module uses the same method with a target dictionary for damage.
func hit(e: Dictionary = {}, amount: float = 0, weapon: String = "cutlass", heavy: bool = false, direction: Vector3 = Vector3.ZERO, element: String = "", presentation: String = "") -> void:
	if e.is_empty():
		if is_instance_valid(visual_actor):
			visual_actor.flash_hit(Color("ff573e"), 1.1)
		hit_stop = maxf(hit_stop, 0.045)
		hero.impact_pause = hit_stop
		_animate(0, 0)
		return
	var enemy = e.get("node")
	if not is_instance_valid(enemy) or enemy.dead or amount <= 0:
		return
	if game.has_method("forest_enemy_visible") and not game.forest_enemy_visible(enemy):return
	var target: Vector3 = AttackChain.aim_point(enemy)
	var origin: Vector3 = _damage_origin if _projectile_damage else player.pos + Vector3.UP
	if not _projectile_damage and absf(e.pos.y - player.pos.y) > 3.5:
		return
	if not clear_line(origin, target):
		return
	var supercritical: bool = class_id == "explorer" and player.buffTime > 0 and element.is_empty()
	var damage: float = roundf(amount * (2.0 if supercritical else 1.0)) * hero.damage_multiplier()
	var dir: Vector3 = direction.normalized() if direction.length_squared() > 0.001 else (e.pos - player.pos).normalized()
	var ticket: Dictionary = _resolution_ticket if not _resolution_ticket.is_empty() else current_ticket()
	enemy.take_hit(damage, dir, heavy, ticket)
	e.hp = enemy.hp
	if not element.is_empty():
		return
	fx.weapon_impact(e.pos, atan2(dir.x, dir.z), presentation if not presentation.is_empty() else "sword", tint(), heavy)
	sound.play("pierce" if presentation in ["thrust", "arrow"] else ("heavy" if heavy else "hit"), {"pitch": 0.77 if e.type == "warden" else 1.0})
	var stop: float = 0.075 if heavy else 0.04
	enemy.impact_pause = maxf(enemy.impact_pause, stop)
	hit_stop = maxf(hit_stop, stop)
	hero.impact_pause = hit_stop
	game.hit_stop = maxf(game.hit_stop, stop)
	game.impact_confirmed.emit(enemy, 2 if heavy else 0, stop)
	game.camera_rig.kick(dir, 0.065 if heavy else 0.035)
	game.chain += 1
	game.chain_timer = 3
	_apply_elements(e, amount, weapon)

func _apply_elements(first: Dictionary, amount: float, weapon: String) -> void:
	var slots: Array = player.sockets.get("cutlass" if class_data().hero else weapon, [])
	var tiers: Dictionary = {"fire": 0, "ice": 0, "lightning": 0}
	for item in slots:
		if tiers.has(item):
			tiers[item] = mini(3, tiers[item] + 1)
	if class_id == "master-thief" and player.buffTime > 0:
		tiers.fire = maxi(1, tiers.fire)
	if tiers.ice > 0 and is_instance_valid(first.node) and not first.node.dead:
		first.node.apply_defense_slow(1.0 - [0, 0.2, 0.37, 0.55][tiers.ice], 2.5)
		fx.particles(first.pos, ELEMENT_COLORS.ice, 6, 0.6)
	if tiers.fire > 0:
		var radius: float = [0, 1.8, 2.6, 3.4][tiers.fire]
		fx.ring(first.pos, ELEMENT_COLORS.fire, radius, 0.3)
		sound.play("fire", {"volume": 0.45})
		for other in living():
			if other.uid != first.uid and other.pos.distance_to(first.pos) < radius and clear_line(first.pos + Vector3.UP, other.pos + Vector3.UP):
				hit(other, roundf(amount * 0.25 * tiers.fire), weapon, false, Vector3.ZERO, "fire")
	if tiers.lightning > 0:
		var visited: Array = [first.uid]
		var current: Dictionary = first
		var limit: int = [0, 3, 5, 6][tiers.lightning]
		while visited.size() < limit:
			var nearest: Dictionary = {}
			var distance: float = 4.4
			for other in living():
				var gap: float = other.pos.distance_to(current.pos)
				if not visited.has(other.uid) and gap < distance and clear_line(current.pos + Vector3.UP, other.pos + Vector3.UP):
					nearest = other
					distance = gap
			if nearest.is_empty():
				break
			fx.lightning(current.pos, nearest.pos)
			hit(nearest, roundf(amount * 0.45), weapon, false, Vector3.ZERO, "lightning")
			visited.append(nearest.uid)
			current = nearest

func bash_enemy(e: Dictionary, direction: Vector3) -> void:
	if is_instance_valid(e.node) and not e.node.dead:
		if e.node.has_method("apply_rogue_bash"):
			e.node.apply_rogue_bash(direction);return
		e.node.velocity += direction * 7
		e.node.cooldown = maxf(e.node.cooldown, 1.2)

func add_projectile_mesh(mesh: Node3D) -> void:
	while projectiles.size() >= MAX_PROJECTILES:
		var oldest: Dictionary = projectiles.pop_front()
		if is_instance_valid(oldest.mesh):
			oldest.mesh.queue_free()
	game.add_child(mesh)
	mesh.add_to_group("rogue_projectiles")

func place_projectile(mesh: Node3D, width: float, start: Vector3) -> bool:
	var wall: Dictionary = _terrain_hit(start, mesh.position, width)
	if wall.is_empty():
		return false
	mesh.position = wall.position
	fx.particles(wall.position, tint(), 4, 0.3)
	return true

func resolve_projectile_segment(pr: Dictionary, from: Vector3, to: Vector3) -> void:
	var wall: Dictionary = _terrain_hit(from, to, pr.width)
	var end: Vector3 = wall.position if not wall.is_empty() else to
	var candidates: Array = _segment_targets(from, end, pr.width)
	for candidate in candidates:
		var e: Dictionary = candidate.e
		if pr.hits.has(e.uid):
			continue
		pr.hits.append(e.uid)
		_resolution_ticket = pr.ticket
		_damage_origin = from
		_projectile_damage = true
		hit(e, pr.damage, pr.weapon, pr.heavy, pr.vel.normalized(), "", pr.kind)
		_projectile_damage = false
		if pr.kind == "bolt":
			fx.ring(e.pos, tint(), 1.1, 0.2)
		if not pr.pierce:
			pr.life = 0
			pr.mesh.position = from.lerp(end, candidate.t)
			return
	if not wall.is_empty():
		pr.life = 0
		pr.mesh.position = end
		fx.particles(end, tint(), 4, 0.3)

func _segment_targets(from: Vector3, to: Vector3, width: float) -> Array:
	var candidates: Array = []
	for e in living():
		var center: Vector3 = AttackChain.aim_point(e.node)
		var result: Dictionary = segment_distance(center, from, to)
		if result.distance <= width + e.radius and clear_line(from, center):
			candidates.append({"e": e, "t": result.t})
	candidates.sort_custom(func(a, b): return a.t < b.t)
	return candidates

func _terrain_hit(from: Vector3, to: Vector3, radius: float = 0.0) -> Dictionary:
	if from.distance_squared_to(to) < 0.000001 or not is_instance_valid(hero) or not hero.is_inside_tree():
		return {}
	var space: PhysicsDirectSpaceState3D = hero.get_world_3d().direct_space_state
	if radius > 0.01:
		var shape: BoxShape3D = BoxShape3D.new()
		# Broad energy waves are wide but thin; a spherical cast would hit the
		# ground instead of modelling their authored horizontal silhouette.
		shape.size = Vector3(radius * 2, minf(radius, 0.22) * 2, 0.08)
		var query: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
		query.shape = shape
		query.collision_mask = 1
		query.exclude = [hero.get_rid()]
		var direction: Vector3 = (to - from).normalized()
		var up: Vector3 = Vector3.RIGHT if absf(direction.dot(Vector3.UP)) > 0.99 else Vector3.UP
		query.transform = Transform3D(Basis.looking_at(direction, up), from)
		if not space.intersect_shape(query, 1).is_empty():
			return {"position": from}
		query.motion = to - from
		var fractions: PackedFloat32Array = space.cast_motion(query)
		if fractions.size() >= 1 and fractions[0] < 0.99999:
			return {"position": from.lerp(to, fractions[0])}
		return {}
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, to, 1)
	query.exclude = [hero.get_rid()]
	return space.intersect_ray(query)

func protects_player() -> bool:
	return active and not player.is_empty() and (player.invuln > 0 or player.drink > 0 or player.untargetable > 0 or player.travel != null)

func untargetable() -> bool:
	return active and not player.is_empty() and (player.drink > 0 or player.untargetable > 0 or player.travel != null)

func filter_damage(amount: float, direction: Vector3, projectile: bool = false) -> float:
	if not active or player.is_empty():
		return amount
	if protects_player():
		return 0
	player.angle = atan2(hero.facing.x, hero.facing.z)
	if Actions.block_attack(self, direction, projectile):
		return 0
	return roundf(amount * 0.5) if class_id == "knight" and player.buffTime > 0 else amount

func receive_knockback(direction: Vector3) -> void:
	if active and not player.is_empty():
		player.vel += Vector3(direction.x, 0, direction.z) * 7.0

func blocks_movement() -> bool:
	return active and not player.is_empty() and player.travel != null

func interrupt_for_dodge() -> void:
	action("roll")

func cancel(preserve_power: bool = false) -> void:
	primary_held = false
	secondary_held = false
	attack_buffer = 0
	hit_stop = 0
	if player.is_empty():
		return
	player.attack = null
	player.roll = 0
	player.travel = null
	player.burst = null
	player.secondaryBuffer = null
	player.blocking = false
	player.vel = Vector3.ZERO
	_clear_projectiles()
	if is_instance_valid(fx):
		fx.clear()
	if not preserve_power:
		for key in ["drink", "invuln", "untargetable", "buffTime", "buffDuration", "blockMeter", "riposte", "shot", "drinkGesture"]:
			player[key] = 0.0
		player.buffName = ""
		player.crouched = false
	if is_instance_valid(_hooks):
		_hooks.hide()
	_sync_hero()
	_animate(0, 0)

func _clear_projectiles() -> void:
	for projectile in projectiles:
		if is_instance_valid(projectile.get("mesh")):
			projectile.mesh.queue_free()
	projectiles.clear()

func toast(text: String) -> void:
	game.toast(text)

func state() -> Dictionary:
	var result: Dictionary = player.duplicate()
	result["classId"] = class_id
	result["health"] = hero.hp
	result["maxHealth"] = hero.max_hp
	result["buffName"] = "Drink" if player.get("drink", 0) > 0 else player.get("buffName", "")
	result["buffTime"] = player.get("drink", 0) if player.get("drink", 0) > 0 else player.get("buffTime", 0)
	return result

func hook_points() -> Array[Vector3]:
	var cell: Vector2i = Vector2i(floori(hero.global_position.x / 12), floori(hero.global_position.z / 12))
	if cell == _hook_cell:
		return _hook_cache
	_hook_cell = cell
	_hook_cache.clear()
	for x in range(cell.x - 1, cell.x + 3):
		for z in range(cell.y - 1, cell.y + 3):
			var point: Vector3 = Vector3(x * 12, 0, z * 12)
			point.y = game.world.height_at(point.x, point.z) + 0.05
			if not game.world.playable_bounds.grow(-2).has_point(Vector2(point.x, point.z)):
				continue
			_hook_cache.append(point)
	return _hook_cache

func _update_hooks() -> void:
	if class_id != "explorer":
		if is_instance_valid(_hooks):
			_hooks.hide()
		return
	if not is_instance_valid(_hooks):
		_hooks = Node3D.new()
		_hooks.name = "RogueHookAnchors"
		game.add_child(_hooks)
		var material: StandardMaterial3D = Geo.mat("ffcf85", 0.2, 0.5)
		for i in range(16):
			var marker: Node3D = Node3D.new()
			_hooks.add_child(marker)
			var gem: PrismMesh = PrismMesh.new()
			gem.size = Vector3(0.22, 0.36, 0.22)
			Geo.mesh(marker, gem, Vector3.UP * 0.65, material)
			_hook_markers.append(marker)
	_hooks.show()
	var points: Array[Vector3] = hook_points()
	for i in range(_hook_markers.size()):
		var marker: Node3D = _hook_markers[i]
		marker.visible = i < points.size() and points[i].distance_to(hero.global_position) <= 15
		if marker.visible:
			marker.global_position = points[i]
			marker.rotation.y = time

func _exit_tree() -> void:
	_clear_projectiles()
	if is_instance_valid(_hooks):
		_hooks.queue_free()
