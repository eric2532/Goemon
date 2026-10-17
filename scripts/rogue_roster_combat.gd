extends Node
## Native Rogue combat running on Sonic's real player body and enemy population.
## The imported actions retain their kits; this facade supplies physical terrain,
## damage attribution, native feedback, and lifecycle handling for Tower Defense.
const Actions = preload("res://assets/rogue/scripts/class_actions.gd")
const MeleeResponse=preload("res://scripts/melee_responsiveness.gd")
const GroundResponse=preload("res://scripts/ground_movement_response.gd")
const COMBO = [
	{"duration": 0.29, "contact": 0.075, "damage": 25, "reach": 2.85, "arc": 1.08, "impulse": 2.7, "stop": 0.045},
	{"duration": 0.33, "contact": 0.095, "damage": 30, "reach": 3.05, "arc": 1.3, "impulse": 3.2, "stop": 0.055},
	{"duration": 0.49, "contact": 0.15, "damage": 48, "reach": 3.35, "arc": 1.55, "impulse": 6.5, "stop": 0.085}
]
const PRIMARY_RANGE_MULTIPLIER = 1.0
const RANGER_GLIDE_DIVISOR = 3.0
const ENERGY_PER_LIGHT = 20
const ENERGY_MAX = 100
const DIVE_DAMAGE = 260
const DIVE_RADIUS = 8.0
const DRAGOON_LEAP_MAX_DISTANCE = 30.0
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
var secondary_sources: Dictionary = {}
var attack_buffer: float = 0.0
var combo: int = 0
var combo_timer: float = 0.0
var hit_stop: float = 0.0
var time: float = 0.0
var evade_cooldown: float = 0.0
var fx: Node3D
var sound: Node
var visual_actor: Node3D
var _ticket: Dictionary = {}
var _resolution_ticket: Dictionary = {}
var _damage_origin: Vector3 = Vector3.ZERO
var _projectile_damage: bool = false
var _projectile_query_active: bool = false
var _projectile_targets: Array = []
var _projectile_centers: PackedVector3Array = PackedVector3Array()
var _projectile_radii: PackedFloat64Array = PackedFloat64Array()
var _projectile_minimum: Vector3
var _projectile_maximum: Vector3
var _hooks: Node3D
var _hook_markers: Array[Node3D] = []
var _hook_cache: Array[Vector3] = []
var _hook_cell: Vector2i = Vector2i(999999, 999999)
var _setup_done: bool = false
var animation_velocity: Vector3 = Vector3.ZERO
var locomotion_velocity: Vector3 = Vector3.ZERO
var utility_buffer: float = 0.0
var buffered_evade: bool = false
var flip_time: float = -1.0
var landing_pose: float = 0.0
var utility_trail: float = 0.0
var _leap_preview: Node3D
var _completed_brush_attack: Variant = null
var _completed_hit_drift=Vector3.ZERO
var _brush_blades: Array = []

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
	fx.apply_quality(int(game.settings.quality))
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
	sound.game = game
	_setup_done = true
	reset_run()

func sync_actor(actor: Node3D) -> void:
	visual_actor = actor
	_brush_blades.clear()
	if is_instance_valid(actor) and actor.WEAPON_AXES.has(class_id) and actor.joints.has("Weapon_Cutlass"):
		_brush_blades.append({"node":actor.joints.Weapon_Cutlass.node,"axis":actor.WEAPON_AXES[class_id]})
		if class_id=="explorer" and actor.joints.has("Weapon_Pistol"):_brush_blades.append({"node":actor.joints.Weapon_Pistol.node,"axis":actor.LEFT_BLADE})
	if not player.is_empty():
		player.actor = actor

func _fresh_player() -> Dictionary:
	return {"pos": hero.global_position, "vel": Vector3.ZERO, "angle": atan2(hero.facing.x, hero.facing.z),
		"hp": hero.hp, "maxHp": hero.max_hp, "cooldowns": {"cutlass": 0.0, "flintlock": 0.0, "roll": 0.0, "drink": 0.0},
		"sockets": {"cutlass": [], "flintlock": []}, "attack": null,
		"roll": 0.0, "rollDir": Vector3.ZERO, "rollDuration": 0.32, "rollSpeed": 12.5, "rollStyle": "roll", "rollTicket": {},
		"ultimatePulse": 0.0, "drink": 0.0, "invuln": 0.0, "shot": 0.0, "drinkGesture": 0.0,
		"buffName": "", "buffTime": 0.0, "buffDuration": 0.0, "blockMeter": 0.0, "blocking": false,
		"crouched": false, "riposte": 0.0, "travel": null, "dive": null, "energy": 0, "burst": null, "secondaryBuffer": null,
		"chargeTime": 0.0, "charging": false, "chargeAngle": 0.0, "chargeTicket": {}, "chargeOrb": null,
		"guardTime": 0.0, "guardStyle": "", "guardTicket": {}, "guardCounter": null, "dashAttack": null, "pulses": [], "bladeSide": 1,
		"untargetable": 0.0, "ninjaHits": 0, "rangerShots": 0, "rangerFlightSerial": 0, "rangerGliding": false, "dragoonHovering": false, "classId": class_id, "id": class_id, "isPlayer": true, "actor": visual_actor}

func reset_run() -> void:
	_completed_hit_drift=Vector3.ZERO
	if is_instance_valid(_leap_preview):_leap_preview.hide()
	if hero!=null:hero.melee_assist.reset()
	_restore_ranger_fall()
	locomotion_velocity = Vector3.ZERO
	animation_velocity = Vector3.ZERO
	utility_buffer = 0.0
	flip_time = -1.0
	landing_pose = 0.0
	_clear_projectiles()
	if is_instance_valid(fx):
		fx.clear()
	primary_held = false
	secondary_held = false
	secondary_sources.clear()
	attack_buffer = 0.0
	combo = 0
	evade_cooldown = 0
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
		if not player.is_empty(): Actions.cancel_charge(self)
		player = _fresh_player()
		hero.attack_left = 0
		hero.impact_pause = 0
		if is_instance_valid(visual_actor): visual_actor.reset_motion()
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
	elif event.is_action_pressed("heavy_attack") or event.is_action_pressed("weapon_chain"):
		var already_held: bool = secondary_held
		secondary_sources["mouse" if event.is_action_pressed("heavy_attack") else "key3"] = true
		secondary_held = true
		if not already_held or not uses_energy(): action("flintlock")
	elif event.is_action_pressed("dodge"):
		request_utility(game.camera_combat() and has_extra_utility())
	elif event.is_action_pressed("equip"):
		if not game.camera_combat() or has_extra_utility():request_utility(false)
	elif event.is_action_pressed("surge"):
		action("drink")
	elif event.is_action_pressed("jump") and player.get("dive") == null and not (player.travel != null and player.travel.kind == "lance-leap"):
		hero.jump_buffer = 0.15

# A short press just before recovery ends is consumed once, never held/repeated.
func request_utility(evade: bool) -> void:
	buffered_evade = evade
	utility_buffer = 0.16
	_try_utility()

func _try_utility() -> void:
	if utility_buffer <= 0 or player.is_empty():
		return
	var cooldown: float = evade_cooldown if buffered_evade else player.cooldowns.roll
	if cooldown > 0 or player.roll > 0 or player.travel != null:
		return
	utility_buffer = 0.0
	if buffered_evade: standard_evade()
	else: action("roll")

func has_extra_utility() -> bool:
	return class_id in ["samurai", "ninja", "explorer", "master-thief"]

func standard_evade() -> void:
	if evade_cooldown > 0 or player.roll > 0 or player.travel != null:
		return
	hero.melee_assist.reset()
	begin_cast("evade")
	player.angle = atan2(aim.x - player.pos.x, aim.z - player.pos.z)
	evade_cooldown = 0.75
	Actions.dash(self, movement_direction(), 0.28, 18.0, "roll")

func release_input(event: InputEvent) -> void:
	if event.is_action_released("light_attack"):
		primary_held = false
		if class_id == "mage": attack_buffer = 0.0
		if not player.is_empty() and player.get("charging", false):
			if active and game.playing and not game.paused and not game.transitioning and hero.hp > 0:
				Actions.release_charge(self)
			else:
				Actions.cancel_charge(self)
	if event.is_action_released("heavy_attack") or event.is_action_released("weapon_chain"):
		secondary_sources.erase("mouse" if event.is_action_released("heavy_attack") else "key3")
		secondary_held = not secondary_sources.is_empty()
		if not secondary_held and not player.is_empty() and class_id in ["master-thief","knight"]:
			player.blocking = false
			player.guardTime = 0.0
			player.secondaryBuffer = null

func action(slot: String) -> void:
	if not active or player.is_empty() or not player.cooldowns.has(slot) or hero.hp <= 0 or player.get("dive") != null:
		return
	player.pos = hero.global_position
	_update_aim()
	if slot=="cutlass" and class_id=="dragoon" and not hero.is_on_floor():
		attack()
		return
	if slot == "roll" and class_id != "ranger" and player.attack == null and player.roll <= 0 and player.travel == null:
		player.angle = atan2(aim.x - player.pos.x, aim.z - player.pos.z)
	if slot == "cutlass":
		attack_buffer = 0.17
		if _can_primary() and hit_stop <= 0:
			attack()
		return
	hero.melee_assist.reset()
	if class_id != "pirate":
		Actions.class_action(self, slot, null, true)
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
		Actions.fire_projectile(self, {"angle": p.angle, "damage": 82, "speed": 42.0, "kind": "bullet", "width": 0.55, "visualScale": 10.0, "pierce": true, "heavy": true, "range": 17.0, "height": 1.3, "color": Color("ffecc3")})
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

func refine_melee_primary(a: Dictionary):
	if a.get("primary",false) and a.get("weapon","cutlass")=="cutlass" and MeleeResponse.applies(game,class_id):MeleeResponse.tune(a)

func melee_contact_guarded()->bool:
	var a=player.get("attack")
	return a!=null and a.get("responsiveMelee",false) and MeleeResponse.contact_guard(a.time,a.contact)

func _can_primary() -> bool:
	return player.get("dive") == null and player.attack == null and player.roll <= 0 and player.travel == null and player.cooldowns.cutlass <= 0 and not player.blocking and not player.charging

func attack() -> void:
	if class_id not in ["mage","ranger"]:hero.combat_aim_left=0
	if class_id=="dragoon" and not hero.is_on_floor():
		hero.melee_assist.reset()
		Actions.class_action(self,"flintlock",null,true)
		_sync_hero()
		return
	begin_cast("primary")
	if class_id == "magic-swordsman" and hero.jumps_used >= 2 and not hero.is_on_floor():
		_begin_dive()
		return
	if class_id != "pirate":
		Actions.begin_primary(self)
		if class_id == "explorer" and player.attack != null and not game.has_method("forest_enemy_visible"):
			_begin_explorer_close_assist(player.attack)
		return
	var index: int = combo % 3 if combo_timer > 0 else 0
	combo = index + 1
	combo_timer = 1.1
	attack_buffer = 0
	player.angle = atan2(aim.x - player.pos.x, aim.z - player.pos.z)
	var a: Dictionary = COMBO[index].duplicate(true)
	a.rangeScale = primary_range_scale()
	a.reach *= a.rangeScale
	a.merge({"index": index, "time": 0.0, "hit": false, "angle": player.angle, "style": "sword", "weapon": "cutlass", "ticket": current_ticket(),"primary":true}, true)
	refine_melee_primary(a)
	fit_primary_reach(a)
	player.attack = a
	player.cooldowns.cutlass = a.duration
	player.vel += front(player.angle) * (3.1 if index == 2 else 2.1)

func _explorer_close_point(enemy: Ninja, aim_angle: float) -> Vector3:
	if not is_instance_valid(enemy) or enemy.dead or enemy.hp <= 0:
		return Vector3.INF
	if game.has_method("forest_enemy_visible") and not game.forest_enemy_visible(enemy):
		return Vector3.INF
	# Reject remote actors before fitting contact. Posed AABBs contain the full
	# giant feet/fists, so a far root never excludes a genuinely nearby limb.
	var reach: float = 2.75 + enemy.body_radius
	if enemy.has_method("combat_bounds"):
		var bounds: AABB = enemy.combat_bounds()
		if not bounds.position.is_finite() or not bounds.size.is_finite():
			return Vector3.INF
		var nearest: Vector2 = Vector2(clampf(player.pos.x, bounds.position.x, bounds.end.x), clampf(player.pos.z, bounds.position.z, bounds.end.z))
		if nearest.distance_squared_to(Vector2(player.pos.x, player.pos.z)) > reach * reach or bounds.position.y > player.pos.y + 2.5 or bounds.end.y < player.pos.y - 2.5:
			return Vector3.INF
	else:
		var root_offset: Vector3 = enemy.global_position - player.pos
		if not root_offset.is_finite() or Vector2(root_offset.x, root_offset.z).length_squared() > reach * reach:
			return Vector3.INF
	# Forest snapshots use the fitted hull: a giant's nearby foot can be close
	# even when its root is far away. This allowance never extends weapon reach.
	var point: Vector3 = AttackChain.contact_point(enemy, player.pos + Vector3.UP, enemy.global_position)
	if not point.is_finite():
		return Vector3.INF
	var offset: Vector3 = point - player.pos
	if absf(offset.y) > 2.5:
		return Vector3.INF
	offset.y = 0
	if maxf(0, offset.length() - enemy.body_radius) > 2.75 or offset.length_squared() < .0001:
		return Vector3.INF
	if absf(wrapf(atan2(offset.x, offset.z) - aim_angle, -PI, PI)) > PI * .5:
		return Vector3.INF
	if not clear_line(player.pos + Vector3.UP, point):
		return Vector3.INF
	return point

func _begin_explorer_close_assist(a: Dictionary) -> void:
	var best_score: float = INF
	for enemy in game.enemies:
		if not is_instance_valid(enemy):
			continue
		var point: Vector3 = _explorer_close_point(enemy, a.angle)
		if point == Vector3.INF:
			continue
		var offset: Vector3 = point - player.pos
		var correction: float = absf(wrapf(atan2(offset.x, offset.z) - a.angle, -PI, PI))
		# Cursor/crosshair alignment wins over a slightly closer side target.
		var score: float = correction + Vector2(offset.x, offset.z).length() * .12
		if score < best_score:
			best_score = score
			a.explorerTarget = enemy
	if a.has("explorerTarget"):
		a.explorerAim = a.angle
		a.explorerLunge = .8

func _steer_explorer_primary(a: Dictionary, delta: float, combat_delta: float) -> void:
	if class_id != "explorer" or not a.get("primary", false) or a.hit or not a.has("explorerTarget"):
		return
	# Validate before passing the cached object into the typed helper: a freed
	# Node fails argument validation before that helper's own guard can run.
	if not is_instance_valid(a.explorerTarget):
		a.erase("explorerTarget")
		return
	var point: Vector3 = _explorer_close_point(a.explorerTarget, a.explorerAim)
	if point == Vector3.INF:
		# Losing cover/vision or moving behind the original aim ends this stroke's
		# assist; do not jump to another target partway through a committed cut.
		a.erase("explorerTarget")
		return
	var offset: Vector3 = point - player.pos
	var previous: float = a.angle
	var weight: float = minf(1, combat_delta / maxf(.001, a.contact - a.time))
	a.angle = lerp_angle(previous, atan2(offset.x, offset.z), weight)
	player.angle = a.angle
	# Only redirect the existing tiny forward lunge. The authored lateral dodge
	# and ordinary movement still pass through the body's move_and_slide.
	a.explorerLunge *= exp(-12 * delta)
	player.vel += (front(a.angle) - front(previous)) * a.explorerLunge

func uses_energy() -> bool:
	return class_id in ["ninja", "explorer"]

func energy_ready() -> bool:
	return uses_energy() and int(player.get("energy", 0)) >= ENERGY_MAX

func _complete_primary(a: Dictionary) -> void:
	if not uses_energy() or not a.get("primary", false) or not a.get("hit", false):
		return
	var previous: int = int(player.energy)
	player.energy = mini(ENERGY_MAX, previous + ENERGY_PER_LIGHT)
	if previous < ENERGY_MAX and energy_ready():
		fx.ring(player.pos, tint(), 1.65, 0.35)
		fx.damage(player.pos, "FREE HEAVY", "crit")

func _begin_dive() -> void:
	player.angle = atan2(aim.x - player.pos.x, aim.z - player.pos.z)
	var direction: Vector3 = front(player.angle)
	player.dive = {"time": 0.0, "direction": direction, "angle": player.angle, "ticket": current_ticket(), "rangeScale": range_scale(), "trail": 0.0}
	player.cooldowns.cutlass = 0.65
	player.attack = null
	player.vel = Vector3.ZERO
	player.secondaryBuffer = null
	attack_buffer = 0.0
	hero.jump_buffer = 0.0
	flip_time = -1.0
	locomotion_velocity = Vector3.ZERO
	hero.velocity = direction * 28.0 + Vector3.DOWN * 38.0
	fx.dive_slash(player.pos, player.angle, 5.5 * range_scale(), false)
	sound.play("claymore-sweep", {"pitch": 0.75, "volume": 0.85})

func _step_dive(delta: float) -> void:
	var dive: Dictionary = player.dive
	dive.time += delta
	dive.trail -= delta
	hero.velocity = dive.direction * 28.0 + Vector3.DOWN * 38.0
	hero.move_and_slide()
	player.pos = hero.global_position
	if dive.trail <= 0:
		dive.trail = 0.075
		fx.dive_slash(player.pos, dive.angle, 5.5 * dive.rangeScale, false)
	if hero.is_on_floor():
		# Clear before resolving hits: landing and subsequent body ticks cannot replay it.
		player.dive = null
		hero.velocity = Vector3.ZERO
		landing_pose = 1.6
		use_ticket(dive.ticket)
		_resolution_ticket = dive.ticket
		_projectile_damage = false
		_damage_origin = player.pos + Vector3.UP
		fx.dive_slash(player.pos, dive.angle, DIVE_RADIUS * dive.rangeScale, true)
		Actions.area(self, player.pos, DIVE_RADIUS, DIVE_DAMAGE, "cutlass", true, Color("c5a2ff"), "dive-slash", dive.rangeScale)
		hit_stop = maxf(hit_stop, 0.12)
		sound.play("claymore-impact", {"heavy": true, "pitch": 0.65, "volume": 0.85})
	elif dive.time >= 2.5:
		player.dive = null

func begin_cast(kind: String) -> void:
	_ticket = hero.attack_chain.begin("rogue_" + class_id + "_" + kind)
	_ticket["rogue_range_scale"] = hero.range_multiplier()
	_ticket["melee_reach_scale"] = hero.melee_reach_setting()
	hero.attack_ticket = _ticket

func current_ticket() -> Dictionary:
	if _ticket.is_empty():
		begin_cast("primary")
	return _ticket

func range_scale() -> float:
	return float(_ticket.get("rogue_range_scale", hero.range_multiplier()))

func melee_reach_scale() -> float:
	return float(_ticket.get("melee_reach_scale",hero.melee_reach_setting()))

func primary_range_scale() -> float:
	# Arrows/fireballs already show their full travel. Only melee had invisible reach.
	return range_scale() * (3.0 if class_id in ["mage","ranger"] else PRIMARY_RANGE_MULTIPLIER*hero.melee_contact_multiplier())

func fit_primary_reach(a: Dictionary) -> void:
	if a.get("style","")=="dragoon-sweep":
		# Preserve the authored sweep's three arcs; extend its lance and radius.
		a.meleeWeaponScale=melee_reach_scale()
		a.reach*=a.meleeWeaponScale
		return
	var physical: bool=a.get("primary",false) or a.get("style","") in ["claymore","cutlass","katana","ninja","heavy","twin","pipe","low-pipe","evasive-slash","thrust"]
	if not physical or class_id in ["mage","ranger"] or not is_instance_valid(visual_actor):return
	var saved_transform: Transform3D=visual_actor.model.transform
	var sample: Dictionary=player.duplicate()
	sample.attack=a.duplicate()
	sample.attack.time=a.contact
	sample.meleeVisualScale=range_scale()*melee_reach_scale()/maxf(.01,hero.growth_multiplier())
	if class_id=="master-thief" and player.buffTime>0:sample.meleeVisualScale*=1.8
	visual_actor.animate_pose(sample,0,time,0)
	var name_="Weapon_Pistol" if class_id=="explorer" and int(a.get("swingSide",1))<0 else "Weapon_Cutlass"
	var weapon: Node3D=visual_actor.joints[name_].node
	var axis: Vector3=visual_actor.LEFT_BLADE if name_=="Weapon_Pistol" else visual_actor.WEAPON_AXES[class_id]
	var tip: Vector3=weapon.to_global(axis)
	var origin: Vector3=hero.global_position
	a.reach=maxf(Vector2(tip.x-origin.x,tip.z-origin.z).length(),Vector2(weapon.global_position.x-origin.x,weapon.global_position.z-origin.z).length())+.12*hero.growth_multiplier()
	a.reach*=hero.melee_contact_multiplier()
	a.meleeVisualScale=sample.meleeVisualScale
	a.weaponContact=true
	if game.has_method("forest_enemy_visible") and a.get("weapon","cutlass")=="cutlass":
		hero.melee_assist.begin(hero,a.angle,a.reach)
	visual_actor.animate_pose(player,0,time,0)
	visual_actor.model.transform=saved_transform

func release_sword_wave(a: Dictionary) -> void:
	# Sample the same articulated attack used on screen either side of release.
	# Its projected tip velocity is the cutting edge, not a guessed world tilt.
	var sample: Dictionary=player.duplicate()
	sample.attack=a.duplicate();sample.grounded=hero.is_on_floor()
	var weapon: Node3D=visual_actor.joints.Weapon_Cutlass.node
	var tips: Array[Vector3]=[]
	for offset in [-.018,.018]:
		sample.attack.time=a.contact+offset
		visual_actor.animate_pose(sample,0,time,0)
		tips.append(weapon.to_global(visual_actor.WEAPON_AXES[class_id]))
	sample.attack.time=a.contact
	visual_actor.animate_pose(sample,0,time,0)
	var direction: Vector3=a.waveDirection.normalized()
	var cut: Vector3=tips[1]-tips[0]
	cut-=direction*cut.dot(direction)
	if cut.length_squared()<.00001:
		cut=direction.cross(Vector3.UP if absf(direction.y)<.95 else Vector3.RIGHT)
	cut=cut.normalized()
	var slash_basis=Basis(cut,direction.cross(cut).normalized(),direction)
	var tip: Vector3=weapon.to_global(visual_actor.WEAPON_AXES[class_id])
	var origin: Vector3=weapon.global_position.lerp(tip,.48)
	Actions.fire_projectile(self,{"origin":origin,"angle":a.angle,"damage":100,"speed":22,"kind":"wave","width":2.5,"pierce":true,"heavy":true,"range":40,"direction":direction,"slashBasis":slash_basis,"feedback":false})
	player.shot=0.0 # Recovery belongs to this attack, not the old firing pose.
	player.vel-=front(a.angle)*1.6
	fx.shake=maxf(fx.shake,.12)
	sound.play("claymore-wave",{"volume":.8,"pitch":.9})
	visual_actor.animate_pose(player,0,time,0)

func ranger_ground_target(angle: float) -> Vector3:
	var locked=hero.auto_aim_target()
	if locked:return AttackChain.aim_point(locked)
	if game.crosshair_aim_enabled():return game.crosshair_target()
	if not game.camera_combat():
		return aim
	var point: Vector3 = hero.global_position + front(angle) * 7.5 * hero.growth_multiplier()
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(point + Vector3.UP * 2.0, point + Vector3.DOWN * 128.0, 1)
	query.exclude = [hero.get_rid()]
	var floor_hit: Dictionary = hero.get_world_3d().direct_space_state.intersect_ray(query)
	if not floor_hit.is_empty():
		return floor_hit.position
	point.y -= 8.0 * hero.growth_multiplier()
	return point

func dragoon_landing_target() -> Vector3:
	return dragoon_landing_solution().point

func dragoon_landing_solution() -> Dictionary:
	var point: Vector3=game.crosshair_target() if game.camera_combat() else aim
	var horizontal=Vector2(point.x-hero.global_position.x,point.z-hero.global_position.z)
	var maximum=DRAGOON_LEAP_MAX_DISTANCE*hero.range_multiplier()
	if horizontal.length()>maximum:
		horizontal=horizontal.normalized()*maximum
		point.x=hero.global_position.x+horizontal.x;point.z=hero.global_position.z+horizontal.y
	point=clamp_arena(point)
	var top=maxf(hero.global_position.y,point.y)+2.0
	var query=PhysicsRayQueryParameters3D.create(Vector3(point.x,top,point.z),Vector3(point.x,top-256.0,point.z),1)
	query.exclude=[hero.get_rid()]
	var hit: Dictionary=hero.get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():return {"point":hit.position,"valid":true}
	point.y=minf(point.y,hero.global_position.y-8.0)
	return {"point":point,"valid":false}

func _update_leap_preview() -> void:
	var enabled=active and class_id=="dragoon" and _setup_done and game.playing and not game.paused and not get_tree().paused and not game.transitioning and hero.hp>0 and not hero.is_on_floor()
	if not enabled:
		if is_instance_valid(_leap_preview):_leap_preview.hide()
		return
	var solution: Dictionary
	var scale: float=hero.range_multiplier()
	var travel=player.get("travel")
	if travel is Dictionary and travel.get("kind","")=="lance-leap":
		scale=float(travel.rangeScale)
		if travel.get("phase","")=="drop":
			# A blocked launch falls vertically; its marker follows the new landing.
			var query=PhysicsRayQueryParameters3D.create(hero.global_position+Vector3.UP*.05,hero.global_position+Vector3.DOWN*256,1)
			query.exclude=[hero.get_rid()]
			var hit: Dictionary=hero.get_world_3d().direct_space_state.intersect_ray(query)
			solution={"point":hit.get("position",Vector3.ZERO),"valid":not hit.is_empty()}
		else:solution={"point":travel.target,"valid":true}
	else:solution=dragoon_landing_solution()
	if not solution.valid:
		if is_instance_valid(_leap_preview):_leap_preview.hide()
		return
	if not is_instance_valid(_leap_preview):
		_leap_preview=preload("res://scripts/dragoon_leap_preview.gd").new()
		game.add_child(_leap_preview)
	_leap_preview.set_area(solution.point,Vector3(Actions.dragoon_impact_radius(0),Actions.dragoon_impact_radius(1),Actions.dragoon_impact_radius(2))*scale)

func projectile_direction(angle: float, origin: Vector3) -> Vector3:
	var direction: Vector3 = front(angle)
	if game.crosshair_aim_enabled() or hero.auto_aim_target()!=null:
		return game.projectile_direction(origin).rotated(Vector3.UP,wrapf(angle-float(player.angle),-PI,PI))
	if game.camera_combat():return direction
	var offset: Vector3 = aim + Vector3.UP * 1.1 - origin
	var horizontal: float = Vector2(offset.x, offset.z).length()
	direction.y = offset.y / maxf(0.5, horizontal)
	return direction.normalized()

func use_ticket(ticket: Dictionary) -> void:
	_ticket = ticket

func tick_timers(delta: float) -> void:
	if player.is_empty():
		return
	evade_cooldown = maxf(0, evade_cooldown - delta)
	var tempo: float = hero.attack_speed_multiplier()
	for key in player.cooldowns:
		var timed_guard: bool = key == "flintlock" and class_id in ["knight", "master-thief"]
		player.cooldowns[key] = maxf(0, player.cooldowns[key] - delta * (tempo if key in ["cutlass", "flintlock"] and not timed_guard else 1.0))
	for key in ["invuln", "drink", "shot", "drinkGesture", "ultimatePulse"]:
		player[key] = maxf(0, player[key] - delta)
	hero.invuln = maxf(0, hero.invuln - delta)
	hero.jump_buffer = maxf(0, hero.jump_buffer - delta)
	hero.coyote = maxf(0, hero.coyote - delta)
	_try_utility()
	utility_buffer = maxf(0, utility_buffer - delta)
	combo_timer = maxf(0, combo_timer - delta)
	# A tapped follow-up belongs to this swing and survives its full recovery.
	# Start/cancel consumes the single slot; ranged inputs retain their old expiry.
	if player.attack==null or not player.attack.get("responsiveMelee",false):
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
	_completed_brush_attack=null
	time += delta
	var combat_delta: float = delta * hero.attack_speed_multiplier()
	if player.attack!=null and player.attack.get("style","")=="dragoon-sweep" and (player.roll>0 or not hero.is_on_floor()):player.attack=null
	if player.attack != null:
		var a: Dictionary = player.attack
		if game.has_method("forest_enemy_visible") and a.get("weaponContact",false) and not a.hit:
			a.angle=hero.melee_assist.steer(hero,a.angle,delta)
			player.angle=a.angle
		else:_steer_explorer_primary(a, delta, combat_delta)
		a.time += combat_delta
		if a.style=="dragoon-sweep":
			while int(a.sweep_hits)<3 and a.time>=a.contact+float(a.sweep_hits)*.12:
				_resolution_ticket=a.ticket;_damage_origin=player.pos+Vector3.UP;_projectile_damage=false
				use_ticket(a.ticket)
				Actions.resolve_dragoon_sweep(self,a,int(a.sweep_hits))
				a.sweep_hits+=1;a.hit=true
		var sweep_pitch: float = clampf(sqrt(hero.attack_speed_multiplier()), 0.8, 1.5)
		var sweep_lead: float = 0.075 * hero.attack_speed_multiplier() / sweep_pitch
		if class_id == "magic-swordsman" and a.get("style", "") == "claymore" and not a.get("sweepSound", false) and a.time >= maxf(0, a.contact - sweep_lead):
			a.sweepSound = true
			sound.play("claymore-sweep", {"combo": a.index, "pitch": sweep_pitch, "volume": 0.68,"ticket":a.ticket})
		if a.time >= a.contact and not a.hit and a.style!="dragoon-sweep":
			a.hit = true
			if a.get("weaponContact",false):hero.melee_assist.contact()
			_resolution_ticket = a.ticket
			_damage_origin = player.pos + Vector3.UP
			_projectile_damage = false
			use_ticket(a.ticket)
			if class_id == "pirate":
				# Authored blade sampling owns the primary stroke.
				sound.play("blade", {"style": "pirate", "combo": a.index,"ticket":a.ticket})
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
			# Preserve one authored follow-through pose when a boosted combat step
			# skips the whole stroke. This changes presentation only; damage,
			# cooldowns and combo retirement still run on their original clock.
			if _uses_blade_brush(a) and a.get("magicBrush",{}).is_empty():
				var follow: float = minf(a.duration*.78,a.contact+minf(.09,(a.duration-a.contact)*.24))
				if a.time-combat_delta<follow:
					_completed_brush_attack=a.duplicate()
					_completed_brush_attack.time=follow
			_complete_primary(a)
			if a.get("hitDriftPending",false):
				# Fast swings may retire before their contact plant releases.
				_completed_hit_drift=front(a.angle)*a.hitDriftImpulse
			player.attack = null
	if (primary_held or attack_buffer > 0 or hero.auto_attack_running()) and _can_primary():
		attack()
		# Automatic Mage primary is a normal tap. A real held click still charges.
		if class_id == "mage" and hero.auto_attack_running() and not primary_held and player.charging:
			Actions.release_charge(self)
	if not projectiles.is_empty(): _begin_projectile_queries()
	for i in range(projectiles.size() - 1, -1, -1):
		var projectile: Dictionary = projectiles[i]
		if not is_instance_valid(projectile.mesh):
			projectiles.remove_at(i)
			continue
		Actions.update_projectile(self, projectile, delta)
		if projectile.life <= 0:
			projectile.mesh.queue_free()
			projectiles.remove_at(i)
	_end_projectile_queries()
	_sync_hero()

func physics_step(delta: float) -> void:
	if not active or player.is_empty() or not game.playing or game.paused or game.transitioning or hero.hp <= 0:
		return
	hero.tick_combat_aim(delta)
	_update_aim()
	player.pos = hero.global_position
	player.hp = hero.hp
	if hero.combat_aiming() and (player.charging or (class_id in ["mage","ranger"] and player.attack!=null)):
		var direction: Vector3=aim-player.pos;player.angle=atan2(direction.x,direction.z)
		if player.charging:player.chargeAngle=player.angle
		if player.attack!=null:player.attack.angle=player.angle
	if hit_stop > 0:
		hit_stop = maxf(0, hit_stop - delta)
		hero.impact_pause = hit_stop
		Actions.update_guard(self, delta)
		return
	hero.impact_pause = 0
	tick_timers(delta)
	var raw: Vector2 = hero.smoke_move if hero.smoke_mode else Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	move_input = Vector3(raw.x, 0, raw.y).rotated(Vector3.UP, game.camera_rig.yaw).limit_length()
	if player.roll>0 or player.travel!=null or player.get("dive")!=null or player.blocking:_completed_hit_drift=Vector3.ZERO
	var previous: Vector3 = hero.global_position
	landing_pose = maxf(0, landing_pose - delta * 5.5)
	if player.roll > 0 or player.travel != null:
		flip_time = -1.0
	if flip_time >= 0:
		flip_time += delta
		if flip_time >= 0.48: flip_time = -1.0
	if player.get("dive") != null:
		_step_dive(delta)
	elif player.travel != null:
		step_travel(delta)
	else:
		_move_body(delta)
	player.pos = hero.global_position
	if player.dashAttack != null:
		Actions.resolve_dash_segment(self, previous, player.pos)
	if player.get("dive") == null and player.attack == null and not player.charging and player.roll <= 0 and player.travel == null:
		if game.camera_combat():
			# Like Goemon, idle camera orbit leaves the feet/body facing in place.
			# Moving in any direction turns the whole body into the path.
			if player.blocking or hero.combat_aiming():
				player.angle = atan2(aim.x - player.pos.x, aim.z - player.pos.z)
			elif move_input.length() > 0.1:
				var direction = move_input.normalized()
				player.angle = atan2(direction.x, direction.z)
		else:
			player.angle = lerp_angle(player.angle, atan2(aim.x - player.pos.x, aim.z - player.pos.z), minf(1, delta * 20))
	tick(delta, false)
	_enforce_bounds()
	_sync_hero()
	animation_velocity = (hero.global_position - previous) / maxf(delta, 0.001)
	_animate(delta * hero.attack_speed_multiplier(), Vector2(hero.global_position.x - previous.x, hero.global_position.z - previous.z).length() / maxf(delta, 0.001) / maxf(0.1, class_data().speed))
	_update_hooks()

func _move_body(delta: float) -> void:
	var p: Dictionary = player
	var forest_melee: bool = game.has_method("forest_enemy_visible") and p.attack!=null and p.attack.weapon=="cutlass" and class_id not in ["mage","ranger"]
	var planted: bool = false
	if forest_melee and hero.is_on_floor() and hero.velocity.y<=0 and hero.jump_buffer<=0:
		planted=GroundResponse.strike_planted(p.attack.time,p.attack.contact,p.attack.duration,delta*hero.attack_speed_multiplier())
	if hero.is_on_floor():
		p.dragoonHovering=false
		_restore_ranger_fall()
		hero.coyote = 0.13
		hero.jumps_used = 0
		flip_time = -1.0
	if p.blocking and class_id == "master-thief":
		locomotion_velocity = Vector3.ZERO
		p.vel = Vector3.ZERO
		hero.velocity.x = 0
		hero.velocity.z = 0
	elif p.roll > 0:
		locomotion_velocity = Vector3.ZERO
		var portion: float = minf(delta, p.roll)
		var duration: float = maxf(0.01, p.rollDuration)
		var start: float = 1.0-p.roll/duration
		var finish: float = start+portion/duration
		# Integrate a fast-start/eased-finish curve; total dash distance is unchanged.
		var travel_time: float = portion+0.28*duration/PI*(sin(finish*PI)-sin(start*PI))
		p.roll = maxf(0, p.roll - delta)
		hero.velocity.x = p.rollDir.x * p.rollSpeed * travel_time / maxf(delta, 0.0001)
		hero.velocity.z = p.rollDir.z * p.rollSpeed * travel_time / maxf(delta, 0.0001)
		if p.roll <= 0:
			use_ticket(p.rollTicket)
			Actions.finish_dash(self)
	elif planted:
		# Windup retains the authored step; contact plants both input motion and
		# the remaining attack impulse, then recovery returns normal steering.
		locomotion_velocity=Vector3.ZERO;p.vel=Vector3.ZERO
		hero.velocity.x=0;hero.velocity.z=0
	else:
		if p.attack!=null and p.attack.get("hitDriftPending",false):
			# Keep the contact plant, then release one small follow-through step.
			p.vel+=front(p.attack.angle)*p.attack.hitDriftImpulse
			p.attack.hitDriftImpulse=0.0;p.attack.hitDriftPending=false
		var multiplier: float = 0.72 if p.crouched else (0.58 if p.blocking else 1.0)
		if p.attack != null and p.attack.time < 0.15 and not forest_melee:
			multiplier *= 0.5
		var base_speed: float = game.hero_tuning("sprint_speed") if Input.is_action_pressed("sprint") else game.hero_tuning("walk_speed")
		if Input.is_action_pressed("walk_modifier"):
			multiplier *= 0.5
		var motion: Vector3 = move_input * base_speed * hero.progression.movement_multiplier() * multiplier + p.vel
		var target_motion: Vector3 = motion - p.vel
		var acceleration: float = 95.0 if move_input.length_squared() < 0.01 else 65.0
		if hero.is_on_floor():
			acceleration=GroundResponse.acceleration(locomotion_velocity,move_input,base_speed*hero.progression.movement_multiplier())
		else: acceleration *= 0.8
		locomotion_velocity = locomotion_velocity.move_toward(target_motion, acceleration * delta)
		hero.velocity.x = locomotion_velocity.x + p.vel.x
		hero.velocity.z = locomotion_velocity.z + p.vel.z
		if forest_melee and not p.attack.hit and not p.attack.has("hitDriftImpulse"):
			var assist_motion: Vector3=hero.melee_assist.motion(hero,delta)
			hero.velocity.x+=assist_motion.x;hero.velocity.z+=assist_motion.z
		p.vel *= exp(-12 * delta)
	if _completed_hit_drift!=Vector3.ZERO:
		# Preserve one accepted hit through normal retirement, even if a queued
		# boosted swing is already planting. All travel still uses native collision.
		p.vel+=_completed_hit_drift
		hero.velocity.x+=_completed_hit_drift.x;hero.velocity.z+=_completed_hit_drift.z
		_completed_hit_drift=Vector3.ZERO
	if hero.jump_buffer > 0 and p.roll <= 0 and not (p.blocking and class_id == "master-thief"):
		if hero.coyote > 0 or hero.jumps_used < hero.maximum_jumps():
			var grounded: bool = hero.coyote > 0
			p.rangerGliding = false
			hero.velocity.y = (game.hero_tuning("jump_speed") if grounded else game.hero_tuning("second_jump_speed")) * hero.progression.jump_velocity_multiplier()
			hero.jumps_used = 1 if grounded else 2
			if not grounded: flip_time = 0.0
			hero.jump_buffer = 0
			hero.coyote = 0
		elif class_id=="dragoon":hero.jump_buffer=0
	if not hero.is_on_floor():
		# Keep ordinary fall momentum behind the glide, then apply the held
		# speed divisor once. Releasing Space restores that ordinary momentum.
		var fall_speed: float = hero.velocity.y
		if p.rangerGliding and fall_speed < 0: fall_speed *= RANGER_GLIDE_DIVISOR
		fall_speed = maxf(-55, fall_speed - 30 * delta)
		p.rangerGliding = class_id == "ranger" and fall_speed < 0 and Input.is_action_pressed("jump") and hero.hp > 0
		hero.velocity.y = fall_speed / RANGER_GLIDE_DIVISOR if p.rangerGliding else fall_speed
		if p.rangerGliding and hero.jumps_used >= 2: hero.jump_buffer = 0
		p.dragoonHovering=class_id=="dragoon" and fall_speed<=0 and Input.is_action_pressed("jump") and hero.hp>0
		if p.dragoonHovering:hero.velocity.y=0
	elif hero.velocity.y < 0:
		hero.velocity.y = 0
	# Match the existing body step-up allowance; this never bypasses tall cover.
	var horizontal: Vector3 = Vector3(hero.velocity.x, 0, hero.velocity.z) * delta
	if hero.is_on_floor() and hero.test_move(hero.global_transform, horizontal):
		var raised: Transform3D = hero.global_transform
		raised.origin.y += 0.32
		if not hero.test_move(raised, horizontal):
			hero.global_position.y += 0.32
	var was_airborne: bool = not hero.is_on_floor()
	hero.move_and_slide()
	if was_airborne and hero.is_on_floor():
		p.rangerGliding = false
		p.dragoonHovering = false
		landing_pose = 1.0
		flip_time = -1.0

func _restore_ranger_fall() -> void:
	if player.is_empty(): return
	if player.get("rangerGliding", false) and is_instance_valid(hero) and hero.velocity.y < 0:
		hero.velocity.y = maxf(-55, hero.velocity.y * RANGER_GLIDE_DIVISOR)
	player.rangerGliding = false

func step_travel(delta: float) -> void:
	locomotion_velocity = Vector3.ZERO
	var t = player.travel
	if t == null:
		return
	if t.kind == "lance-leap":
		_step_lance_leap(t, delta)
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
			Actions.lance_impact(self, t)
		player.travel = null
		if t.kind != "lance-leap": fx.ring(player.pos, tint(), 1.25, 0.3)

func _step_lance_leap(t: Dictionary, delta: float) -> void:
	t.time += delta
	if t.phase in ["drop","aimed-drop"]:
		var before_drop: Vector3=hero.global_position
		# Continue below the activation height until the real body meets a floor.
		# move_and_slide lets descent proceed along walls instead of sticking to them.
		if t.phase=="aimed-drop":
			# Aim stays fixed at activation; collision stops the body at the floor.
			# Aim slightly below the surface so floor snapping cannot leave it hovering.
			var offset: Vector3=t.target+Vector3.DOWN*.5-hero.global_position
			var motion: Vector3=offset.limit_length(45.0*delta)
			hero.velocity=motion/maxf(delta,.0001)
		else:
			hero.velocity = Vector3.DOWN * minf(55.0, maxf(38.0, -hero.velocity.y) + 30.0 * delta)
		hero.move_and_slide()
		player.pos = hero.global_position
		if hero.is_on_floor() and hero.get_floor_normal().dot(Vector3.UP) >= cos(hero.floor_max_angle):
			_finish_lance_landing(t)
		elif t.phase=="aimed-drop":
			var goal: Vector3=t.target+Vector3.DOWN*.5
			var progress: float=before_drop.distance_to(goal)-hero.global_position.distance_to(goal)
			t.stalled=float(t.get("stalled",0))+delta if progress<delta*.25 else 0.0
			# A roof side or an aim point over empty space must not trap the move.
			if hero.global_position.distance_to(goal)<.15 or t.stalled>.2:
				t.phase="drop"
				hero.velocity=Vector3.DOWN*38.0
		return
	var amount: float = minf(1.0, t.time / t.duration)
	var destination: Vector3 = t.start.lerp(t.target, amount)
	destination.y += sin(amount * PI) * t.height
	var motion: Vector3 = destination - hero.global_position
	hero.velocity = motion / maxf(delta, 0.0001)
	var collision: KinematicCollision3D = hero.move_and_collide(motion)
	player.pos = hero.global_position
	if collision != null:
		# A wall or ceiling ends the arc, but only downward floor contact lands it.
		if motion.y < 0.0 and collision.get_normal().dot(Vector3.UP) >= cos(hero.floor_max_angle):
			_finish_lance_landing(t)
			return
	if amount >= 1.0 or collision != null:
		t.phase = "drop"
		hero.velocity = Vector3.DOWN * 38.0

func _finish_lance_landing(t: Dictionary) -> void:
	# Consume before creating pulses, so later body ticks cannot replay an impact.
	player.travel = null
	hero.velocity = Vector3.ZERO
	hero.jump_buffer = 0.0
	hero.jumps_used = 0
	hero.coyote = 0.13
	landing_pose = 1.25
	use_ticket(t.ticket)
	_resolution_ticket = t.ticket
	_damage_origin = player.pos + Vector3.UP
	Actions.lance_impact(self, t)

func blink_to(destination: Vector3) -> void:
	destination = clamp_arena(destination)
	hero.move_and_collide(destination - hero.global_position)
	player.pos = hero.global_position
	hero.velocity = Vector3.ZERO
	locomotion_velocity = Vector3.ZERO

func _enforce_bounds() -> void:
	var fell=hero.global_position.y< -5
	if hero.constrain_forest_bounds():
		if fell:
			player.travel=null;player.dive=null;player.roll=0;locomotion_velocity=Vector3.ZERO
		player.pos=hero.global_position
		return
	var bounds: Rect2 = game.world.playable_bounds.grow(-1)
	if hero.global_position.y < -5 or not bounds.grow(4).has_point(Vector2(hero.global_position.x, hero.global_position.z)):
		hero.hp = maxf(1, hero.hp - 10)
		hero.global_position = game.checkpoint
		hero.velocity = Vector3.ZERO
		player.travel = null
		player.dive = null
		player.roll = 0
		game.camera_rig.reset_follow()
	player.pos = hero.global_position

func _sync_hero() -> void:
	if player.is_empty():
		return
	hero.facing = front(player.angle)
	hero.invuln = maxf(hero.invuln, player.invuln)
	hero.dodge_time = player.roll
	hero.dodge_cooldown = evade_cooldown if game.camera_combat() and has_extra_utility() else player.cooldowns.roll
	hero.attack_left = maxf(0, player.attack.duration - player.attack.time) if player.attack != null else 0.0
	hero.attack_duration = player.attack.duration if player.attack != null else 0.4
	hero.combo = int(player.attack.index) + 1 if player.attack != null else 0
	hero.attack_heavy = player.attack != null and int(player.attack.index) == 2
	player.hp = hero.hp
	player.maxHp = hero.max_hp

func _uses_blade_brush(attack_: Variant) -> bool:
	return attack_!=null and class_id in ["pirate","samurai","ninja","knight","magic-swordsman","explorer","master-thief"] and attack_.style not in ["shield-bash","bash","spin","fireburst","thrust"]

func _animate(delta: float, movement: float) -> void:
	if not is_instance_valid(visual_actor) or player.is_empty():
		return
	if active:
		var target_yaw = atan2(-hero.facing.x, -hero.facing.z)
		if game.camera_combat():
			var turn_delta = delta / maxf(0.01, hero.attack_speed_multiplier())
			hero.model.rotation.y = lerp_angle(hero.model.rotation.y, target_yaw, 1 - exp(-turn_delta * (24 if hero.attack_left > 0 or player.shot > 0 else (GroundResponse.TURN_RESPONSE if hero.is_on_floor() else 14))))
		else:
			hero.model.rotation.y = target_yaw
	var pose: Dictionary = player.duplicate()
	if player.travel != null:
		pose = player.duplicate()
		pose.travel = player.travel.duplicate()
		pose.travel.height = 0.0 # The real collision body already follows the arc.
	var real_delta: float = delta / maxf(0.01, hero.attack_speed_multiplier())
	if _completed_brush_attack!=null:
		pose.attack=_completed_brush_attack
	pose.graphicsQuality = game.settings.quality
	pose.meleeVisualScale=pose.attack.get("meleeVisualScale",1.0) if pose.attack is Dictionary else 1.0
	pose.grounded = hero.is_on_floor()
	pose.vertical = hero.velocity.y
	pose.landing = landing_pose
	pose.flip = flip_time / 0.48 if flip_time >= 0 and player.get("dive") == null else -1.0
	var world_motion := Vector3(animation_velocity.x, 0, animation_velocity.z)
	pose.localMotion = visual_actor.global_basis.orthonormalized().inverse() * world_motion
	pose.motionSpeed = world_motion.length()
	var brush_attack: Variant=pose.attack if _uses_blade_brush(pose.attack) else null
	if brush_attack==null and class_id=="ninja" and pose.dashAttack is Dictionary and float(pose.roll)>0:
		# The authored RMB endpoints own the blade path; use the real posed tip.
		brush_attack=pose.dashAttack
		brush_attack.duration=pose.rollDuration
		brush_attack.contact=pose.rollDuration*.5
		brush_attack.time=pose.rollDuration-pose.roll
		brush_attack.index=0
		brush_attack.brushStart=.025
		brush_attack.brushEnd=pose.rollDuration
	if brush_attack!=null and class_id=="samurai" and not _brush_blades.is_empty():
		var contact: float=brush_attack.contact
		var follow: float=minf(brush_attack.duration*.78,contact+minf(.09,(brush_attack.duration-contact)*.24))
		var skipped=_completed_brush_attack!=null or (float(brush_attack.time)>follow and float(brush_attack.get("brushObservedTime",0))<contact*.52)
		if skipped:seed_samurai_brush(pose,contact,follow,movement)
	visual_actor.animate_pose(pose, real_delta, time, minf(1, movement))
	if not _brush_blades.is_empty():
		if class_id in ["magic-swordsman","samurai"]:
			fx.sword_brush_sample(brush_attack,_brush_blades[0].node,_brush_blades[0].axis,class_id=="samurai",class_id=="samurai" and player.buffTime>0,hero.attack_speed_multiplier())
		else:
			fx.weapon_brush_sample(brush_attack,_brush_blades,tint(),hero.attack_speed_multiplier()>2,hero.attack_speed_multiplier())
	_completed_brush_attack=null
	utility_trail -= real_delta
	if (player.roll > 0 or player.travel != null) and utility_trail <= 0:
		utility_trail = 0.075
		fx.streak(hero.global_position + Vector3.UP * 0.65 - animation_velocity.normalized() * 0.8, hero.global_position + Vector3.UP * 0.65, tint(), 0.035, 0.16)

func seed_samurai_brush(pose: Dictionary,contact: float,follow: float,movement: float):
	# A complete draw/slash/return can fit between two rendered frames.
	# Seed its ribbon from this cut's actual wind-up and contact, rather
	# than two nearly identical sheathed poses from adjacent cuts.
	var final_time: float=pose.attack.time
	for sample_time in [contact*.52,contact,follow]:
		pose.attack.time=sample_time
		visual_actor.animate_pose(pose,0,time,minf(1,movement))
		fx.sword_brush_sample(pose.attack,_brush_blades[0].node,_brush_blades[0].axis,true,player.buffTime>0,hero.attack_speed_multiplier())
	pose.attack.time=final_time

func _process(delta: float) -> void:
	_update_leap_preview()
	if not active or not _setup_done or not game.playing or game.paused or game.transitioning:
		return
	fx.tick(delta)
	sound.set_volume(float(game.settings.volume))
	game.camera_rig.impulse = maxf(game.camera_rig.impulse, minf(0.23, fx.shake))

func _update_aim() -> void:
	if not is_instance_valid(game) or not is_instance_valid(hero):
		return
	var locked=hero.auto_aim_target()
	if locked:
		aim = AttackChain.aim_point(locked)
	elif game.crosshair_aim_enabled():
		aim = game.attack_aim_point() if game.has_method("attack_aim_point") else game.crosshair_target()
	elif game.camera_combat():
		aim = hero.global_position + game.attack_direction() * 7.5
	elif game.rogue_battle_mode and is_instance_valid(game.get("rogue_view")):
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

func ranger_roll_direction() -> Vector3:
	var raw: Vector2 = hero.smoke_move if hero.smoke_mode else Input.get_vector("move_left","move_right","move_forward","move_back")
	if raw.length_squared()>.01:
		return Vector3(raw.x,0,raw.y).normalized().rotated(Vector3.UP,game.camera_rig.yaw)
	return front(player.angle)

func ranger_fire_rate_multiplier() -> float:
	return minf(3.0,1.0+.12*hero.attack_chain.count)

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
		result.append(_target_snapshot(enemy))
	return result

func _target_snapshot(enemy: Ninja,from: Vector3=Vector3.INF) -> Dictionary:
	if from==Vector3.INF:from=hero.global_position+Vector3.UP
	var contact=AttackChain.contact_point(enemy,from,enemy.global_position)
	return {"node": enemy, "uid": enemy.get_instance_id(), "pos": contact,
		"hp": enemy.hp, "maxHp": enemy.max_hp, "type": "warden" if enemy.boss or (enemy.defense_traits != null and enemy.defense_traits.is_boss()) else "revenant",
		"radius": enemy.body_radius, "vel": enemy.velocity, "attackCD": enemy.cooldown, "slow": 0.0, "slowAmount": 0.0}

func _nearby_targets(center: Vector3, radius: float, excluded_uid: int = -1) -> Array:
	var result: Array = []
	for enemy in game.enemies:
		if not is_instance_valid(enemy) or enemy.dead or enemy.hp <= 0 or enemy.get_instance_id() == excluded_uid:
			continue
		if game.has_method("forest_enemy_visible") and not game.forest_enemy_visible(enemy):continue
		if AttackChain.contact_point(enemy,center,enemy.global_position).distance_to(center) < radius:
			result.append(_target_snapshot(enemy,center))
	return result

# The default empty argument is the active_ability incoming-hit interface. The
# native action module uses the same method with a target dictionary for damage.
func hit(e: Dictionary = {}, amount: float = 0, weapon: String = "cutlass", heavy: bool = false, direction: Vector3 = Vector3.ZERO, element: String = "", presentation: String = "") -> void:
	if e.is_empty():
		# Hero applies incoming knockback after this hook. Restore ordinary
		# momentum first so the glide divisor cannot multiply that impulse.
		_restore_ranger_fall()
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
	var origin: Vector3 = _damage_origin if _projectile_damage else player.pos + Vector3.UP
	var target: Vector3 = AttackChain.aim_point(enemy,origin)
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
	var attack=player.attack
	# One confirmed basic swing earns one hit, regardless of target count.
	if class_id=="ninja" and weapon=="cutlass" and not _projectile_damage and element.is_empty() and attack!=null and attack.get("primary",false) and attack.ticket==ticket and not attack.get("ninjaRefreshCounted",false):
		attack.ninjaRefreshCounted=true
		player.ninjaHits=(int(player.ninjaHits)+1)%3
		if player.ninjaHits==0:
			var refreshed=float(player.cooldowns.flintlock)>0
			player.cooldowns.flintlock=0.0
			if refreshed:toast("Shadow Cut refreshed · 3 hits")
	if not _projectile_damage and element.is_empty() and attack!=null and attack.get("hitDriftImpulse",0.0)>0 and attack.ticket==ticket:
		attack.hitDriftPending=true
	if not element.is_empty():
		return
	fx.weapon_impact(e.pos, atan2(dir.x, dir.z), presentation if not presentation.is_empty() else "sword", tint(), heavy)
	if class_id == "magic-swordsman" and presentation in ["claymore", "wave"]:
		sound.play("claymore-impact", {"heavy": heavy, "volume": 0.52, "pitch": 0.92 if e.type == "warden" else 1.0})
	else:
		sound.play("pierce" if presentation in ["thrust", "arrow", "crimson-arrow"] else ("heavy" if heavy else "hit"), {"pitch": 0.77 if e.type == "warden" else 1.0})
	var stop: float = 0.075 if heavy else 0.04
	if class_id == "samurai" and player.buffTime > 0 and not _projectile_damage: stop /= 5.0
	enemy.impact_pause = maxf(enemy.impact_pause, stop)
	# A released projectile keeps travelling independently of the caster.
	# Piercing a crowd must not repeatedly freeze movement and projectile ticks.
	if not _projectile_damage:
		var self_stop: float=player.attack.stop if player.attack!=null and player.attack.get("responsiveMelee",false) else stop
		hit_stop = maxf(hit_stop, self_stop)
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
		for other in _nearby_targets(first.pos, radius, first.uid):
			if clear_line(first.pos + Vector3.UP, other.pos + Vector3.UP):
				hit(other, roundf(amount * 0.25 * tiers.fire), weapon, false, Vector3.ZERO, "fire")
	if tiers.lightning > 0:
		var visited: Array = [first.uid]
		var current: Dictionary = first
		var limit: int = [0, 3, 5, 6][tiers.lightning]
		while visited.size() < limit:
			var nearest: Dictionary = {}
			var distance: float = 4.4
			for other in _nearby_targets(current.pos, distance):
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

func place_projectile(mesh: Node3D, width: float, start: Vector3, sphere_collision: bool = false) -> bool:
	var wall: Dictionary = _terrain_hit(start, mesh.position, width, sphere_collision)
	if wall.is_empty():
		return false
	mesh.position = wall.position
	fx.particles(wall.position, tint(), 4, 0.3)
	return true

func resolve_projectile_segment(pr: Dictionary, from: Vector3, to: Vector3) -> void:
	var wall: Dictionary = _terrain_hit(from, to, pr.width, pr.get("sphereCollision", false))
	var end: Vector3 = wall.position if not wall.is_empty() else to
	var candidates: Array = _segment_targets(from, end, pr.width, pr.hits)
	for candidate in candidates:
		var e: Dictionary = candidate.e
		if pr.hits.has(e.uid):
			continue
		pr.hits.append(e.uid)
		_resolution_ticket = pr.ticket
		_damage_origin = from
		_projectile_damage = true
		hit(e, pr.damage, pr.weapon, pr.heavy, pr.get("flightDirection", pr.vel.normalized()), "", pr.kind)
		_projectile_damage = false
		if pr.kind in ["bolt", "fireball"]:
			fx.ring(e.pos, pr.get("color", tint()), 1.1 * pr.get("visualScale", 1.0), 0.3)
			if pr.kind == "fireball": fx.particles(e.pos, Color("ff7135"), 18, pr.get("visualScale", 1.0))
		if not pr.pierce:
			pr.life = 0
			pr.mesh.position = from.lerp(end, candidate.t)
			return
	if not wall.is_empty():
		pr.life = 0
		pr.mesh.position = end
		fx.particles(end, tint(), 4, 0.3)

func _begin_projectile_queries() -> void:
	# Enemy positions/radii cannot advance inside this synchronous projectile
	# loop. Share geometry only until its end; health/death are checked per hit.
	_projectile_targets.clear()
	_projectile_centers.clear()
	_projectile_radii.clear()
	_projectile_minimum = Vector3.INF
	_projectile_maximum = -Vector3.INF
	for actor in game.enemies:
		if not is_instance_valid(actor): continue
		var enemy: Ninja = actor
		if enemy.dead or enemy.hp <= 0: continue
		if game.has_method("forest_enemy_visible") and not game.forest_enemy_visible(enemy):continue
		var center: Vector3 = AttackChain.aim_point(enemy)
		var radius: float = enemy.body_radius
		if enemy.has_method("combat_bounds"):
			var box: AABB=enemy.combat_bounds()
			center=box.get_center();radius=box.size.length()*.5
		_projectile_targets.append(enemy)
		_projectile_centers.append(center)
		_projectile_radii.append(radius)
		_projectile_minimum = _projectile_minimum.min(center - Vector3.ONE * radius)
		_projectile_maximum = _projectile_maximum.max(center + Vector3.ONE * radius)
	_projectile_query_active = true

func _end_projectile_queries() -> void:
	_projectile_query_active = false

func _segment_targets(from: Vector3, to: Vector3, width: float, hit_ids: Array = []) -> Array:
	var standalone: bool = not _projectile_query_active
	if standalone: _begin_projectile_queries()
	var candidates: Array = _segment_candidates(from, to, width, hit_ids)
	if standalone: _end_projectile_queries()
	return candidates

func _segment_candidates(from: Vector3, to: Vector3, width: float, hit_ids: Array) -> Array:
	var candidates: Array = []
	# Piercing shots retain their hit history. Do not rebuild snapshots or cast
	# victim rays for those contacts on every following physics step.
	var minimum: Vector3 = from.min(to) - Vector3.ONE * width
	var maximum: Vector3 = from.max(to) + Vector3.ONE * width
	if _projectile_targets.is_empty() or maximum.x < _projectile_minimum.x or minimum.x > _projectile_maximum.x or maximum.y < _projectile_minimum.y or minimum.y > _projectile_maximum.y or maximum.z < _projectile_minimum.z or minimum.z > _projectile_maximum.z:
		return candidates
	var excluded: Dictionary = {}
	for uid in hit_ids:excluded[uid]=true
	var segment: Vector3 = to - from
	var length_squared: float = segment.length_squared()
	for index in range(_projectile_targets.size()):
		var center: Vector3 = _projectile_centers[index]
		var radius: float = _projectile_radii[index]
		# Most airborne/far-travelling segments cannot touch the crowd. Reject
		# them without allocating a distance Dictionary per actor per projectile.
		if center.x + radius < minimum.x or center.x - radius > maximum.x or center.y + radius < minimum.y or center.y - radius > maximum.y or center.z + radius < minimum.z or center.z - radius > maximum.z:
			continue
		var actor = _projectile_targets[index]
		if not is_instance_valid(actor): continue
		var enemy: Ninja = actor
		if enemy.dead or enemy.hp <= 0 or excluded.has(enemy.get_instance_id()): continue
		var t: float = clampf((center - from).dot(segment) / length_squared, 0, 1) if length_squared > 0.0001 else 0.0
		if enemy.has_method("combat_segment_contact"):
			var contact: Dictionary=enemy.combat_segment_contact(from,to,width)
			if not contact.is_empty() and clear_line(from,contact.point):
				candidates.append({"e":_target_snapshot(enemy,contact.point),"t":contact.t})
		elif center.distance_to(from + segment * t) <= width + radius and clear_line(from, center):
			candidates.append({"e": _target_snapshot(enemy), "t": t})
	candidates.sort_custom(func(a, b): return a.t < b.t)
	return candidates

func _terrain_hit(from: Vector3, to: Vector3, radius: float = 0.0, sphere_collision: bool = false) -> Dictionary:
	if from.distance_squared_to(to) < 0.000001 or not is_instance_valid(hero) or not hero.is_inside_tree():
		return {}
	var space: PhysicsDirectSpaceState3D = hero.get_world_3d().direct_space_state
	if radius > 0.01:
		var shape: Shape3D
		if sphere_collision:
			var sphere := SphereShape3D.new()
			sphere.radius = radius
			shape = sphere
		else:
			# Existing energy waves use a wide, thin silhouette. The new round
			# bullet uses its full sphere so low/grazing cover stops it too.
			var box := BoxShape3D.new()
			box.size = Vector3(radius * 2, minf(radius, 0.22) * 2, 0.08)
			shape = box
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
	return active and not player.is_empty() and (player.invuln > 0 or player.drink > 0 or player.untargetable > 0 or player.travel != null or melee_contact_guarded())

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
	_completed_hit_drift=Vector3.ZERO
	if is_instance_valid(_leap_preview):_leap_preview.hide()
	_completed_brush_attack=null
	_restore_ranger_fall()
	primary_held = false
	secondary_held = false
	secondary_sources.clear()
	attack_buffer = 0
	hit_stop = 0
	if player.is_empty():
		return
	utility_buffer = 0.0
	animation_velocity = Vector3.ZERO
	locomotion_velocity = Vector3.ZERO
	flip_time = -1.0
	landing_pose = 0.0
	player.attack = null
	player.roll = 0
	player.travel = null
	player.dive = null
	player.burst = null
	player.secondaryBuffer = null
	player.blocking = false
	player.guardTime = 0.0
	player.guardCounter = null
	player.guardStyle = ""
	player.dashAttack = null
	player.pulses.clear()
	Actions.cancel_charge(self)
	player.vel = Vector3.ZERO
	_clear_projectiles()
	if is_instance_valid(fx):
		fx.clear()
	if not preserve_power:
		player.energy = 0
		player.ninjaHits = 0
		player.rangerShots = 0
		player.rangerFlightSerial = 0
		for key in ["ultimatePulse", "drink", "invuln", "untargetable", "buffTime", "buffDuration", "blockMeter", "riposte", "shot", "drinkGesture"]:
			player[key] = 0.0
		player.buffName = ""
		player.crouched = false
	if is_instance_valid(_hooks):
		_hooks.hide()
	if is_instance_valid(visual_actor): visual_actor.reset_motion(not preserve_power)
	_sync_hero()
	_animate(0, 0)

func _clear_projectiles() -> void:
	_end_projectile_queries()
	_projectile_targets.clear()
	_projectile_centers.clear()
	_projectile_radii.clear()
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

func hook_ahead(point: Vector3) -> bool:
	if not game.camera_combat():return true
	var offset = point - hero.global_position
	offset.y = 0
	return offset.length_squared() > 0.01 and offset.normalized().dot(game.attack_direction()) >= 0.75

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
	if is_instance_valid(_leap_preview):_leap_preview.queue_free()
	_clear_projectiles()
	if is_instance_valid(_hooks):
		_hooks.queue_free()

# Pulse origin and ticket survive independently of player movement or later attacks.
func resolve_area_pulse(pulse: Dictionary) -> void:
	var prior_ticket: Dictionary = _ticket
	var prior_resolution: Dictionary = _resolution_ticket
	use_ticket(pulse.ticket)
	_resolution_ticket = pulse.ticket
	_damage_origin = pulse.pos + Vector3.UP
	_projectile_damage = true
	Actions.area(self, pulse.pos, pulse.radius, pulse.damage, "flintlock", false, Color("529cff"), "lance-wave", pulse.rangeScale)
	_projectile_damage = false
	_ticket = prior_ticket
	_resolution_ticket = prior_resolution
	fx.lance_wave(pulse.pos, pulse.radius * pulse.rangeScale, pulse.index)
