extends Node
## Goemon's existing pipe and damage, with Magic Swordsman's contact rhythm.
## This profile is opt-in for ordinary pipe LMB attacks in Rogue Siege only.
const DURATIONS = [0.48, 0.48, 0.576]
const CONTACT_TIME = 0.15
const COMBO_WINDOW = 1.05
const HIT_PAUSES = [0.045, 0.045, 0.075]
const TINT = Color("ffc52f")
const GoldEnergy = preload("res://scripts/goemon_gold_energy.gdshader")
const Strike = preload("res://scripts/goemon_reference_strike.gd")
# Keep the pose profile independent of Hero/HeroModel's preload graph.
var hero: Node3D
var fx: Node3D
var sound: Node
var gold_material: ShaderMaterial
var pipe_meshes: Array[MeshInstance3D] = []
var old_overlays: Array[Material] = []
var pipe_tip = Vector3.ZERO
var brush: Dictionary = {}
var gold_clock = 0.0
var glow_active = false

static func duration(stage: int) -> float:
	return DURATIONS[clampi(stage - 1, 0, 2)]

static func contact_phase(stage: int) -> float:
	return CONTACT_TIME / duration(stage)

static func sample(stage: int, elapsed: float) -> Dictionary:
	return Strike.sample(stage,elapsed/duration(stage),contact_phase(stage))

static func _blend(from: Dictionary, to: Dictionary, amount: float) -> Dictionary:
	var pose: Dictionary = {}
	for key in from:
		pose[key] = lerp(from[key], to[key], amount)
	return pose

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	process_priority = 40

func prepare() -> void:
	var game: Node = hero.game
	if not is_instance_valid(fx) and not hero.ai_controlled:
		fx = game.get_node_or_null("RogueSharedClassEffects")
	if not is_instance_valid(fx):
		fx = load("res://assets/rogue/scripts/effects.gd").new()
		fx.name = "GatePipeEffects" if hero.ai_controlled else "RogueSharedClassEffects"
		fx.process_mode = Node.PROCESS_MODE_PAUSABLE
		game.add_child(fx)
	fx.apply_quality(0 if hero.ai_controlled else int(game.settings.quality))
	fx.reduced_flashes = game.settings.get("reduced_flashes", false)
	if not is_instance_valid(sound):
		sound = game.get_node_or_null("RogueSharedClassAudio")
	if not is_instance_valid(sound):
		sound = load("res://assets/rogue/scripts/audio.gd").new()
		sound.name = "RogueSharedClassAudio"
		sound.process_mode = Node.PROCESS_MODE_PAUSABLE
		sound.ambience_enabled = false
		game.add_child(sound)
	if hero.ai_controlled and sound.get_script()==load("res://assets/rogue/scripts/audio.gd"):
		var proxy=preload("res://scripts/forest/forest_gate_audio.gd").new();proxy.hero=hero;proxy.shared=sound;hero.add_child(proxy);sound=proxy
	sound.game = game
	sound.set_volume(float(game.settings.volume))

func release(stage: int) -> void:
	prepare()
	sound.play("blade", {"style": "magic-swordsman", "combo": clampi(stage - 1, 0, 2)})

func slash(stage: int) -> void:
	prepare()
	var index: int = clampi(stage - 1, 0, 2)
	var angle: float = atan2(hero.facing.x, hero.facing.z)
	fx.slash(hero.global_position, angle, index, TINT, hero.melee_strike_reach(),
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
	if not hero.ai_controlled:game.hit_stop = maxf(game.hit_stop, duration_)
	if not hero.ai_controlled:game.camera_rig.kick(direction, 0.065 if heavy else 0.035)
	# weapon_impact takes a feet position and supplies its own contact height.
	fx.weapon_impact(point - Vector3.UP, atan2(direction.x, direction.z), "gold-pipe", TINT, heavy)
	sound.play("heavy" if heavy else "hit", {"pitch": 0.77 if victim.boss else 1.0})
	game.sound("enemy_reaction", 0.38 if heavy else 0.22)

func clear() -> void:
	_set_glow(false)
	brush.clear()
	# A native adapter owns the same pool when another fighter is selected.
	if not hero.ai_controlled and hero.character_id == 1 and is_instance_valid(fx):
		fx.clear()

func _cache_pipe(node: Node) -> void:
	if node is MeshInstance3D:
		pipe_meshes.append(node)
		old_overlays.append(node.material_overlay)
	for child in node.get_children():
		_cache_pipe(child)

func _set_glow(active: bool) -> void:
	if glow_active == active:return
	glow_active = active
	for i in pipe_meshes.size():
		if is_instance_valid(pipe_meshes[i]):
			pipe_meshes[i].material_overlay = gold_material if active else old_overlays[i]

func _gold_swing(delta: float) -> void:
	var active: bool = hero.attack_left > 0 and hero.weapon_slot == 1 and hero.hp > 0
	if not active and not is_instance_valid(fx):return
	if active and not is_instance_valid(fx):prepare()
	if pipe_meshes.is_empty():
		_cache_pipe(hero.model.pipe)
		if hero.model.pipe_bounds.is_empty():hero.model.cache_pipe_bounds(hero.model.pipe)
		for corner in hero.model.pipe_bounds:
			if corner.length_squared() > pipe_tip.length_squared():pipe_tip = corner
		gold_material = ShaderMaterial.new()
		gold_material.shader = GoldEnergy
	var blades = [{"node":hero.model.pipe,"axis":pipe_tip}]
	if not active:
		_set_glow(false)
		brush.clear()
		fx.weapon_brush_sample(null,blades,TINT)
		return
	var elapsed: float = hero.attack_duration - hero.attack_left
	var index: int = clampi(hero.combo-1,0,2)
	if brush.is_empty() or elapsed < float(brush.time) or index != int(brush.index):
		brush = {"duration":hero.attack_duration,"contact":hero.attack_duration*hero.attack_contact_phase(),"time":elapsed,"index":index}
	brush.time = elapsed
	gold_clock += delta
	gold_material.set_shader_parameter("brush_clock",gold_clock)
	gold_material.set_shader_parameter("energy",.35 if hero.game.settings.get("reduced_flashes",false) else .8)
	_set_glow(true)
	fx.weapon_brush_sample(brush,blades,TINT)

func _process(delta: float) -> void:
	if not is_instance_valid(hero):return
	if hero.character_id==1 and hero.model.get_meta("original_goemon",false):
		_set_glow(false);brush.clear();return
	if hero.character_id != 1 or not hero.game.rogue_roster_mode:
		_set_glow(false)
		brush.clear()
		return
	var game: Node = hero.game
	if not game.playing or game.transitioning:
		_set_glow(false)
		brush.clear()
		return
	if game.paused:return
	_gold_swing(delta)
	if not is_instance_valid(fx):return
	var quality: int = 0 if hero.ai_controlled else int(game.settings.quality)
	if fx.quality != quality:fx.apply_quality(quality)
	fx.reduced_flashes = game.settings.get("reduced_flashes",false)
	if fx.get_meta("tick_frame",-1)!=Engine.get_process_frames():
		fx.set_meta("tick_frame",Engine.get_process_frames());fx.tick(delta)
	if is_instance_valid(sound):sound.set_volume(float(game.settings.volume))
	if not hero.ai_controlled:game.camera_rig.impulse = maxf(game.camera_rig.impulse, minf(0.23, fx.shake))

func _exit_tree():
	if is_instance_valid(hero) and hero.ai_controlled and is_instance_valid(fx):fx.queue_free()
