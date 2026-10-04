extends RefCounted
## Mode-local input rhythm. Damage, abilities and animation remain owned by Hero.
const PRIMARY_BUFFER = 0.17
const SECONDARY_BUFFER = 0.24
var hero: Hero
var held = false
var primary_buffer = 0.0
var secondary_buffer = 0.0
var next_stage = 1

func _init(player: Hero):
	hero = player

func reset(preserve_hold: bool = false):
	held = held and preserve_hold
	primary_buffer = 0.0
	secondary_buffer = 0.0
	next_stage = 1

func release(event: InputEvent):
	if event.is_action_released("light_attack"):
		held = false

func input(event: InputEvent) -> bool:
	if event.is_echo(): return false
	if event.is_action_pressed("light_attack"):
		held = true
		primary_buffer = PRIMARY_BUFFER
		tick(0)
		return true
	if event.is_action_pressed("heavy_attack"):
		secondary_buffer = SECONDARY_BUFFER
		tick(0)
		return true
	return false

func tick(delta: float):
	if hero.character_id != 1: return
	# Impact freeze preserves the input buffer, just as it preserves the pose.
	if hero.impact_pause > 0: return
	var available = hero.attack_left <= 0 and hero.dodge_time <= 0 and not hero.forward_dash.active and not hero.sky_strike.active and not hero.chain_pipe_combat.active and not hero.quick_attacks.active and hero.quick_attacks.pending.is_empty()
	if available and (secondary_buffer > 0 or primary_buffer > 0 or held):
		var heavy = secondary_buffer > 0
		if hero.combo_window <= 0: next_stage = 1
		hero.facing = hero.game.attack_direction()
		if hero.weapon_slot == 3:
			hero.chain_pipe_combat.start("sweep" if heavy else "throw")
		else:
			hero.start_attack(heavy or hero.surge_left > 0, 1 if heavy else next_stage, not heavy and hero.surge_left > 0)
		if heavy: next_stage = 1
		else: next_stage = next_stage % 3 + 1
		primary_buffer = 0
		secondary_buffer = 0
	primary_buffer = maxf(0, primary_buffer - delta)
	secondary_buffer = maxf(0, secondary_buffer - delta)
