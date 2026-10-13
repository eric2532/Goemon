extends Node
## Goemon's existing pipe and damage, with Magic Swordsman's contact rhythm.
## This profile is opt-in for ordinary pipe LMB attacks in Rogue Siege only.
const DURATIONS = [0.48, 0.48, 0.576]
const CONTACT_TIME = 0.15
const COMBO_WINDOW = 1.05
const HIT_PAUSES = [0.045, 0.045, 0.075]
const TINT = Color("b9a0ff")
# Keep the pose profile independent of Hero/HeroModel's preload graph.
var hero: Node3D
var fx: Node3D
var sound: Node

static func duration(stage: int) -> float:
	return DURATIONS[clampi(stage - 1, 0, 2)]

static func contact_phase(stage: int) -> float:
	return CONTACT_TIME / duration(stage)

static func sample(stage: int, elapsed: float) -> Dictionary:
	var index: int = clampi(stage - 1, 0, 2)
	var wind: Dictionary = [PipeCombo.HIGH, PipeCombo.DIAGONAL_END, PipeCombo.FINISH_LOAD][index]
	# Each contact is an authored Goemon pose with the actual pipe crossing the
	# forward hit region; recovery and windup use the native Rogue clock.
	var contact: Dictionary = PipeCombo.raw(index + 1, [0.48, 0.38, 0.48][index])
	var follow: Dictionary = [PipeCombo.DIAGONAL_END, PipeCombo.LEFT_END, PipeCombo.RIGHT_END][index]
	var windup: float = CONTACT_TIME * 0.52
	var follow_end: float = minf(duration(stage) * 0.78, CONTACT_TIME + minf(0.09, (duration(stage) - CONTACT_TIME) * 0.24))
	if elapsed < windup:
		return _blend(PipeCombo.IDLE, wind, smoothstep(0, windup, elapsed))
	if elapsed < CONTACT_TIME:
		var amount: float = clampf((elapsed - windup) / (CONTACT_TIME - windup), 0, 1)
		return _blend(wind, contact, amount * amount)
	if elapsed < follow_end:
		var amount: float = clampf((elapsed - CONTACT_TIME) / (follow_end - CONTACT_TIME), 0, 1)
		return _blend(contact, follow, 1.0 - (1.0 - amount) * (1.0 - amount))
	return _blend(follow, PipeCombo.IDLE, smoothstep(follow_end, duration(stage), elapsed))

static func _blend(from: Dictionary, to: Dictionary, amount: float) -> Dictionary:
	var pose: Dictionary = {}
	for key in from:
		pose[key] = lerp(from[key], to[key], amount)
	return pose

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE

func prepare() -> void:
	var game: Node = hero.game
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
		sound.ambience_enabled = false
		game.add_child(sound)
	sound.set_volume(float(game.settings.volume))

func release(stage: int) -> void:
	prepare()
	sound.play("blade", {"style": "magic-swordsman", "combo": clampi(stage - 1, 0, 2)})

func slash(stage: int) -> void:
	prepare()
	var index: int = clampi(stage - 1, 0, 2)
	var angle: float = atan2(hero.facing.x, hero.facing.z)
	fx.slash(hero.global_position, angle, index, TINT, hero.game.tuning.pipe_range * hero.attack_reach_multiplier(),
		{"style": "magic", "arc": 2.5, "height": 1.05 * hero.growth_multiplier(), "direction": -1 if index % 2 else 1})

func impact(victim: Node3D, point: Vector3, direction: Vector3, stage: int) -> void:
	prepare()
	var index: int = clampi(stage - 1, 0, 2)
	var duration_: float = HIT_PAUSES[index]
	var heavy: bool = index == 2
	var game: Node = hero.game
	game.impact_confirmed.emit(victim, 2 if heavy else 0, duration_)
	victim.impact_pause = maxf(victim.impact_pause, duration_)
	hero.impact_pause = maxf(hero.impact_pause, duration_)
	game.hit_stop = maxf(game.hit_stop, duration_)
	game.camera_rig.kick(direction, 0.065 if heavy else 0.035)
	# weapon_impact takes a feet position and supplies its own contact height.
	fx.weapon_impact(point - Vector3.UP, atan2(direction.x, direction.z), "claymore", TINT, heavy)
	sound.play("heavy" if heavy else "hit", {"pitch": 0.77 if victim.boss else 1.0})
	game.sound("enemy_reaction", 0.38 if heavy else 0.22)

func clear() -> void:
	# A native adapter owns the same pool when another fighter is selected.
	if hero.character_id == 1 and is_instance_valid(fx):
		fx.clear()

func _process(delta: float) -> void:
	if not is_instance_valid(hero) or hero.character_id != 1 or not hero.game.rogue_roster_mode:
		return
	var game: Node = hero.game
	if not game.playing or game.paused or game.transitioning or not is_instance_valid(fx):
		return
	fx.tick(delta)
	sound.set_volume(float(game.settings.volume))
	game.camera_rig.impulse = maxf(game.camera_rig.impulse, minf(0.23, fx.shake))
