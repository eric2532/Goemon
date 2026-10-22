extends RefCounted
## Ordinary Soldier 1/2/3 combat from US SC01/FILE_077, funcs 80181B58..80181EF4.
## Rendering consumes soldier_clip/soldier_tick; the attack timer is independent of
## source clip length (melee A's 24-frame pose loop has a 20-tick combat timer).
## Event coordinates remain original actor-local PS1 units: scale by .01, flip
## source Y-down to Godot Y-up and source Z to glTF Z, then apply actor yaw+PI.
## Terrain movement, cover checks, damage application and projectile simulation
## belong to the caller. Green's approach uses the same navigation charge as red;
## it has one melee contact and no thrown-javelin attack in this source machine.
const FPS := 30.0
const MELEE_FROM := Vector3(0,-30,0)
const MELEE_TO := Vector3(0,-30,-80)
const MUZZLE := Vector3(0,-80,-48)

static func begin(e: Dictionary) -> void:
	cancel(e)
	var role := int(e.get("variant", -1))
	if role != 0 and role != 1 and role != 3: return
	e.soldier_action = "attack"
	e.soldier_shots = 0
	e.soldier_elapsed = 0.0
	_enter(e, "fire" if role == 1 else "melee_a")

static func active(e: Dictionary) -> bool:
	return e.get("soldier_action", "") == "attack"

static func cancel(e: Dictionary) -> void:
	e.soldier_action = "idle"
	e.soldier_phase = ""
	e.soldier_shots = 0
	e.soldier_tick = 0.0
	e.soldier_elapsed = 0.0
	e.soldier_clip = "Source__801afdd0"

static func advance(e: Dictionary, delta: float, context: Dictionary = {}) -> Array:
	var events: Array = []
	if not active(e) or delta <= 0.0: return events
	var remaining := delta * FPS
	while active(e) and remaining > 0.0:
		var phase: String = e.soldier_phase
		var duration := _duration(phase)
		var previous := float(e.soldier_tick)
		var step := minf(remaining, maxf(0.0, duration - previous))
		var next := minf(duration, previous + step)
		var start := float(e.soldier_elapsed) - previous
		if phase == "melee_a" or phase == "melee_b":
			var hit_tick := 13.0 if phase == "melee_a" else 14.0
			if previous < hit_tick and next >= hit_tick:
				events.append({"kind":"melee", "source_tick":start+hit_tick,
					"local_from":MELEE_FROM,"local_to":MELEE_TO,"damage":11})
		elif phase == "fire":
			if previous < 15.0 and next >= 15.0:
				events.append({"kind":"muzzle","source_tick":start+15.0,"local_origin":MUZZLE})
			if previous < 18.0 and next >= 18.0:
				events.append({"kind":"bullet","source_tick":start+18.0,"local_origin":MUZZLE,"damage":25})
		e.soldier_tick = next
		e.soldier_elapsed = float(e.soldier_elapsed) + step
		remaining -= step
		if next < duration: break
		match phase:
			"melee_a":
				if int(e.variant) == 0 and bool(context.get("continue_combo", true)):
					_enter(e,"combo_prepare")
				else: _finish(e,events)
			"combo_prepare": _enter(e,"melee_b")
			"fire":
				e.soldier_shots = int(e.soldier_shots) + 1
				_enter(e,"fire" if int(e.soldier_shots) < 3 else "reload")
			_: _finish(e,events)
	return events

static func _enter(e: Dictionary, phase: String) -> void:
	e.soldier_phase = phase
	e.soldier_tick = 0.0
	match phase:
		"melee_a": e.soldier_clip = "Source__801b0118"
		"combo_prepare": e.soldier_clip = "Source__801afd28"
		"melee_b": e.soldier_clip = "Source__801b01e0"
		"fire": e.soldier_clip = "Source__801b0d50"
		"reload": e.soldier_clip = "Source__801b0e48"

static func _duration(phase: String) -> float:
	match phase:
		"melee_a": return 20.0
		"combo_prepare": return 10.0
		"melee_b": return 24.0
		_: return 30.0

static func _finish(e: Dictionary, events: Array) -> void:
	e.soldier_action = "done"
	events.append({"kind":"done","source_tick":float(e.soldier_elapsed)})
