class_name RecoveredGoemonCombatProfile
extends RefCounted
## Original ROM timing, derived from Goemon's original action rows and event curves.
## Native gameplay is 30 Hz, proven by 2 VI retraces/game step at ROM 0x33F4.
## Contact cues below are sound timing. Exact collision predicates are not yet decoded.
const LOGIC_HZ: float = 30.0
const DATA_PATH := "res://assets/characters/recovered_goemon/combat_profile.json"
const COMBO_ACTIONS := [0x68, 0x69, 0x6a]
const COMBO_RECOVERIES := [0x6b, 0x6c, 0x6d]
const COMBO_CUE_FRAMES := [3.0, 4.0, 6.0]
const COIN_ACTION := 0x7c
const COIN_RELEASE_FRAME: float = 4.5
const GOLDEN_ACTION := 0x82
const GOLDEN_RECOVERY := 0x83
const GOLDEN_AURA_FRAME: float = 4.0
const GOLDEN_APPEARANCE_FRAME: float = 10.0
static var _data: Dictionary = {}

static func data() -> Dictionary:
	if _data.is_empty():
		var file := FileAccess.open(DATA_PATH, FileAccess.READ)
		if file != null:
			var parsed: Variant = JSON.parse_string(file.get_as_text())
			if parsed is Dictionary:
				_data = parsed
	return _data

static func action(action_id: int) -> Dictionary:
	return data().get("actions", {}).get(str(action_id), {})

static func source_fps(action_id: int) -> float:
	return absf(float(action(action_id).get("rate", 1.0))) * LOGIC_HZ

static func action_duration(action_id: int) -> float:
	return float(action(action_id).get("transition_ticks", 0)) / LOGIC_HZ

static func cue_time(action_id: int, source_frame: float) -> float:
	var rate := absf(float(action(action_id).get("rate", 1.0)))
	return ceilf(source_frame / maxf(rate, 0.001)) / LOGIC_HZ

static func combo(index: int) -> Dictionary:
	var slot := clampi(index, 0, 2)
	var attack_id: int = COMBO_ACTIONS[slot]
	var recovery_id: int = COMBO_RECOVERIES[slot]
	return {
		"action_id": attack_id,
		"clip_index": int(action(attack_id).get("clip", 0)),
		"attack_duration": action_duration(attack_id),
		"recovery_action": recovery_id,
		"recovery_duration": action_duration(recovery_id),
		"cue_time": cue_time(attack_id, COMBO_CUE_FRAMES[slot]),
		"fps": source_fps(attack_id),
		"recovery_fps": source_fps(recovery_id),
	}

## Stages are 1..3. Earlier strikes flow straight into the next queued strike.
static func duration(stage: int) -> float:
	var slot := clampi(stage - 1, 0, 2)
	var strike := action_duration(COMBO_ACTIONS[slot])
	return strike + action_duration(COMBO_RECOVERIES[slot]) if slot == 2 else strike

static func contact_phase(stage: int) -> float:
	var slot := clampi(stage - 1, 0, 2)
	return cue_time(COMBO_ACTIONS[slot], COMBO_CUE_FRAMES[slot]) / maxf(duration(stage), 0.001)

static func action_at(stage: int, elapsed: float) -> Dictionary:
	var slot := clampi(stage - 1, 0, 2)
	var action_id: int = COMBO_ACTIONS[slot]
	var strike_duration := action_duration(action_id)
	if slot == 2 and elapsed >= strike_duration:
		return {"action": COMBO_RECOVERIES[slot], "action_id": COMBO_RECOVERIES[slot], "time_seconds": elapsed - strike_duration}
	return {"action": action_id, "action_id": action_id, "time_seconds": elapsed}

static func golden_progress(elapsed: float) -> Dictionary:
	var phase_duration := action_duration(GOLDEN_ACTION)
	return {
		"action": GOLDEN_ACTION if elapsed < phase_duration else GOLDEN_RECOVERY,
		"time_seconds": elapsed if elapsed < phase_duration else elapsed - phase_duration,
		"aura_visible": elapsed >= cue_time(GOLDEN_ACTION, GOLDEN_AURA_FRAME),
		"golden_visible": elapsed >= cue_time(GOLDEN_ACTION, GOLDEN_APPEARANCE_FRAME),
		"duration": phase_duration + action_duration(GOLDEN_RECOVERY),
	}

## Native chain windup then holds until the existing projectile returns.
## Current trajectory/control remains authoritative, as in the source dynamic hold.
static func chain_release_time() -> float:
	return action_duration(0x70)

static func chain_at(elapsed:float,total_duration:float=1.0,airborne:bool=false)->Dictionary:
	var windup=0x77 if airborne else 0x70
	var hold=windup+1
	var catch_=windup+2
	var first=action_duration(windup)
	var recovery=action_duration(catch_)
	if elapsed<first:return {"action":windup,"time_seconds":elapsed}
	if elapsed<total_duration-recovery:return {"action":hold,"time_seconds":0.0}
	return {"action":catch_,"time_seconds":maxf(0,elapsed-(total_duration-recovery))}

static func coin_action(on_floor:bool,_moving:bool)->int:
	# Native jump/fall callers pass state 1 to 801E4624 (801DF2E4,
	# 801E8244): 7D/80. State 2 selects the crouched 7E/81 clip.
	return 0x7C if on_floor else 0x7D
