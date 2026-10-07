extends Node3D
## Native procedural actor. The authored Blender joints and actual weapons own the
## silhouette; the contact pose is synchronized with combat's damage frame.

var id: String = "pirate"
var model: Node3D
var joints: Dictionary = {}
var materials: Array = []
var seed: float = randf() * TAU
var flash: float = 0.0
var flash_color: Color = Color("ffdeb0")
var flash_strength: float = 1.4
var reduced_flashes: bool = false
var _flash_applied: bool = false

const WEAPON_AXES = {
	"pirate": Vector3(-0.565, 0.811, 0.009),
	"samurai": Vector3(-0.44, 1.08, 0.006),
	"ninja": Vector3(-0.375, 0.806, 0.015),
	"mage": Vector3(-0.28, 1.35, 0),
	"knight": Vector3(-0.292, 1.147, 0.011),
	"dragoon": Vector3(-0.479, 2.085, 0.019),
	"magic-swordsman": Vector3(-0.554, 1.965, 0.029),
	"explorer": Vector3(-0.473, 0.848, 0.03),
	"master-thief": Vector3(-0.705, 1.254, 0.055),
}
const LEFT_BLADE: Vector3 = Vector3(0.473, 0.848, 0.03)

func setup(character_id: String) -> void:
	id = character_id
	if is_instance_valid(model):
		model.queue_free()
	joints.clear()
	materials.clear()
	flash = 0.0
	_flash_applied = false
	var resource = load("res://assets/rogue/styled/models/%s.glb" % id)
	if resource is PackedScene:
		model = resource.instantiate()
		model.rotation_order = EULER_ORDER_XYZ
		add_child(model)
		_cache(model)
	else:
		push_error("Missing character model: %s" % id)
		model = Node3D.new()
		add_child(model)

func _cache(node: Node) -> void:
	if node is Node3D and node.name in ["Body", "Head", "Arm_L", "Arm_R", "Leg_L", "Leg_R", "Weapon_Cutlass", "Weapon_Pistol", "Flask"]:
		var rest: Transform3D = node.transform
		node.rotation_order = EULER_ORDER_XYZ
		node.transform = rest
		joints[str(node.name)] = {"node": node, "transform": node.transform, "rotation": node.rotation, "position": node.position, "scale": node.scale}
	if node is MeshInstance3D:
		for surface in range(node.mesh.get_surface_count()):
			var original = node.get_active_material(surface)
			if original is StandardMaterial3D:
				var material: StandardMaterial3D = original.duplicate()
				node.set_surface_override_material(surface, material)
				materials.append({"material": material, "emission": material.emission, "enabled": material.emission_enabled, "energy": material.emission_energy_multiplier})
	for child in node.get_children():
		_cache(child)

func flash_hit(color: Color = Color("ffdeb0"), strength: float = 1.4) -> void:
	flash = 0.115
	flash_color = color
	flash_strength = strength

func _r(name_: String, x: float = 0.0, y: float = 0.0, z: float = 0.0) -> void:
	if joints.has(name_):
		joints[name_].node.rotation += Vector3(x, y, z)

func _p(name_: String, x: float = 0.0, y: float = 0.0, z: float = 0.0) -> void:
	if joints.has(name_):
		joints[name_].node.position += Vector3(x, y, z)

func _smooth(t: float) -> float:
	t = clampf(t, 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)

func _phase(attack: Dictionary) -> Dictionary:
	var duration: float = maxf(0.01, float(attack.get("duration", 0.4)))
	var contact: float = clampf(float(attack.get("contact", duration * 0.3)), 0.015, duration * 0.8)
	var windup: float = contact * 0.52
	var follow: float = minf(duration * 0.78, contact + minf(0.09, (duration - contact) * 0.24))
	var time: float = maxf(0.0, float(attack.get("time", 0.0)))
	if time < windup:
		return {"from": 0, "to": 1, "mix": _smooth(time / windup)}
	if time < contact:
		var t: float = clampf((time - windup) / (contact - windup), 0.0, 1.0)
		return {"from": 1, "to": 2, "mix": t * t}
	if time < follow:
		var t: float = clampf((time - contact) / (follow - contact), 0.0, 1.0)
		return {"from": 2, "to": 3, "mix": 1.0 - (1.0 - t) * (1.0 - t)}
	return {"from": 3, "to": 4, "mix": _smooth((time - follow) / maxf(0.001, duration - follow))}

func _c(phase: Dictionary, wind: float, contact: float, follow: float, idle: float = 0.0) -> float:
	var values: Array = [idle, wind, contact, follow, idle]
	return lerpf(float(values[phase.from]), float(values[phase.to]), float(phase.mix))

func _aim_weapon(name_: String, source: Vector3, target: Vector3, amount: float = 1.0) -> void:
	if not joints.has(name_) or amount <= 0.0 or source.length_squared() < 0.00001:
		return
	var joint: Node3D = joints[name_].node
	# Model-to-parent rotation cancels the actor/world transform, so this also
	# works when a preview pose is prepared before insertion into the scene tree.
	var parent_basis: Basis = Basis.IDENTITY
	var ancestor: Node3D = joint.get_parent()
	while ancestor != null and ancestor != model:
		parent_basis = ancestor.basis.orthonormalized() * parent_basis
		ancestor = ancestor.get_parent() as Node3D
	var aimed_direction: Vector3 = (parent_basis.inverse() * target.normalized()).normalized()
	var aimed_rotation: Quaternion = Quaternion(source.normalized(), aimed_direction)
	var rest_rotation: Quaternion = joints[name_].transform.basis.get_rotation_quaternion()
	joint.quaternion = rest_rotation.slerp(aimed_rotation, clampf(amount, 0.0, 1.0))

func _sword(attack: Dictionary, phase: Dictionary) -> void:
	var index: int = int(attack.get("index", 0))
	var reverse: bool = index % 2 == 1
	var finish: bool = index == 2 or attack.get("style", "") == "iaijutsu"
	var side: float = -1.0 if reverse else 1.0
	var heavy: bool = id in ["knight", "magic-swordsman"]
	var quick: bool = id in ["ninja", "explorer"]
	var weight: float = 1.16 if heavy else (0.82 if quick else 1.0)
	var active: float = _c(phase, 1, 1, 1)
	var twist: float = _c(phase, -0.38, 0.08, 0.56) if finish else _c(phase, -0.48, 0.12, 0.6) * side
	_r("Body", _c(phase, -0.07, 0.13, 0.19) * weight, twist, _c(phase, 0.04, -0.055, -0.09) * side)
	_r("Head", _c(phase, 0.03, -0.045, -0.025), -twist * 0.55)
	_r("Leg_R", _c(phase, -0.19, 0.18, 0.12), 0, -_c(phase, 0.035, 0.085, 0.03))
	_r("Leg_L", _c(phase, 0.13, -0.16, -0.12))
	_p("Body", 0, -_c(phase, 0.045, 0.015, 0.06) * weight, _c(phase, -0.045, 0.09, 0.035))
	var arm: String = "Arm_L" if id == "explorer" and reverse else "Arm_R"
	var other: String = "Arm_L" if arm == "Arm_R" else "Arm_R"
	var weapon: String = "Weapon_Cutlass" if arm == "Arm_R" else "Weapon_Pistol"
	var handedness: float = 1.0 if arm == "Arm_R" else -1.0
	_r(arm, _c(phase, -1.55, -1.0, -0.35) if finish else _c(phase, -0.65, -1.18, -0.67), _c(phase, -0.55, 0.04, 0.62) * side, _c(phase, -0.65, -0.16, 0.4) * side * handedness)
	_p(arm, _c(phase, -0.045, 0.015, 0.065) * handedness, 0, _c(phase, -0.06, 0.17, 0.08))
	_r(other, _c(phase, -0.25, -0.65, -0.38), -twist * 0.3, _c(phase, 0.14, 0.29, 0.13) * handedness)
	if heavy and id == "magic-swordsman":
		_p(other, _c(phase, -0.16, -0.24, -0.13), _c(phase, 0.04, 0.02, 0), _c(phase, 0.02, 0.18, 0.06))
	var direction: Vector3
	if finish:
		direction = Vector3(_c(phase, -0.35, 0.02, 0.48), _c(phase, 1.1, -0.08, -0.64), _c(phase, -0.42, 1.1, 0.72))
	else:
		direction = Vector3(_c(phase, -1.2, 0.04, 1.15) * side, _c(phase, -0.1 if reverse else 0.64, 0.1, 0.62 if reverse else -0.32), _c(phase, -0.12, 1.15, 0.24))
	_aim_weapon(weapon, LEFT_BLADE if weapon == "Weapon_Pistol" else WEAPON_AXES.get(id, Vector3.UP), direction, active)
	if id == "explorer":
		_r(other, -_c(phase, 0.1, 0.2, 0.06), 0, -_c(phase, 0.15, 0.28, 0.12) * handedness)
	model.rotation.x += _c(phase, -0.035, 0.075, 0.035) * weight
	model.rotation.z += _c(phase, 0.045, -0.045, -0.08) * side

func _lance(phase: Dictionary, index: int) -> void:
	var active: float = _c(phase, 1, 1, 1)
	_r("Body", _c(phase, -0.09, 0.13, 0.1), _c(phase, -0.22, 0.06, 0.09))
	_r("Head", _c(phase, 0.04, -0.08, -0.04), _c(phase, 0.16, -0.04, -0.04))
	_r("Arm_R", _c(phase, -0.6, -1.1, -1.05), _c(phase, -0.12, 0.09, 0.08), _c(phase, -0.16, -0.03, -0.02))
	_p("Arm_R", _c(phase, 0.08, 0.17, 0.13), _c(phase, -0.09, -0.06, -0.06), _c(phase, -0.29, 0.77 if index == 2 else 0.63, 0.61))
	_r("Arm_L", _c(phase, -0.93, -1.19, -1.13), _c(phase, -0.22, -0.32, -0.24), _c(phase, 0.13, 0.3, 0.22))
	_p("Arm_L", -_c(phase, 0.16, 0.27, 0.2), -_c(phase, 0.07, 0.09, 0.07), _c(phase, -0.06, 0.19, 0.12))
	_r("Leg_R", _c(phase, -0.3, 0.2, 0.15))
	_r("Leg_L", _c(phase, 0.19, -0.3, -0.22))
	_p("Body", 0, -_c(phase, 0.075, 0.045, 0.025), _c(phase, -0.08, 0.16, 0.1))
	model.rotation.x += _c(phase, -0.06, 0.12, 0.08)
	_aim_weapon("Weapon_Cutlass", WEAPON_AXES.dragoon, Vector3(_c(phase, -0.07, 0, 0), _c(phase, 0.16, 0, -0.035), 1), active)

func _staff(phase: Dictionary) -> void:
	var active: float = _c(phase, 1, 1, 1)
	_r("Arm_R", _c(phase, -1.45, -0.95, -0.7), _c(phase, -0.26, 0.1, 0.16), -_c(phase, 0.25, 0.08, 0.05))
	_r("Arm_L", _c(phase, -0.9, -1.2, -0.7), _c(phase, 0.1, -0.12, -0.08), _c(phase, 0.2, 0.32, 0.25))
	_r("Body", _c(phase, -0.13, 0.19, 0.13), _c(phase, -0.12, 0.04, 0.12))
	_r("Head", _c(phase, -0.09, 0.08, 0.04))
	_p("Arm_R", 0, _c(phase, 0.16, -0.09, -0.09), _c(phase, -0.08, 0.23, 0.1))
	_p("Body", 0, _c(phase, 0.04, -0.09, -0.06))
	_aim_weapon("Weapon_Cutlass", WEAPON_AXES.mage, Vector3(_c(phase, -0.18, 0, 0.1), _c(phase, 1, -0.3, -0.38), _c(phase, -0.24, 1, 0.85)), active)

func _bow(phase: Dictionary, samurai: bool = false) -> void:
	var active: float = _c(phase, 1, 1, 1)
	var bow_arm: String = "Arm_L" if samurai else "Arm_R"
	var draw_arm: String = "Arm_R" if samurai else "Arm_L"
	var side: float = -1.0 if samurai else 1.0
	_r("Body", _c(phase, -0.035, 0.06, 0.025), _c(phase, -0.28, -0.2, -0.13) * side)
	_r("Head", _c(phase, 0, -0.035, 0.005), _c(phase, 0.22, 0.17, 0.1) * side)
	_r(bow_arm, _c(phase, -1.32, -1.42, -1.22), _c(phase, 0.08, 0.05, 0.08) * side, -_c(phase, 0.18, 0.13, 0.17) * side)
	_p(bow_arm, _c(phase, 0.1, 0.11, 0.08) * side, _c(phase, 0.06, 0.02, 0.03), _c(phase, 0.2, 0.17, 0.12))
	_r(draw_arm, _c(phase, -1.37, -1.04, -0.97), _c(phase, -0.5, -0.78, -0.55) * side, _c(phase, 0.36, 0.66, 0.4) * side)
	_p(draw_arm, -_c(phase, 0.2, 0.08, 0.04) * side, _c(phase, 0.06, 0.05, 0.02), _c(phase, -0.06, -0.21, -0.14))
	_aim_weapon("Weapon_Pistol" if samurai else "Weapon_Cutlass", Vector3.UP, Vector3(0.02 * side, 1, 0.035), active)

func _shield(phase: Dictionary) -> void:
	var active: float = _c(phase, 1, 1, 1)
	_r("Arm_L", _c(phase, -1.08, -1.34, -1.22), -_c(phase, 0.13, 0.08, 0.05), _c(phase, 0.23, 0.06, 0.08))
	_p("Arm_L", -_c(phase, 0.07, 0.15, 0.11), 0, _c(phase, -0.13, 0.42, 0.29))
	_r("Arm_R", -_c(phase, 0.35, 0.63, 0.3), _c(phase, -0.12, -0.22, -0.08))
	_r("Body", _c(phase, -0.07, 0.18, 0.1), _c(phase, 0.2, -0.16, -0.09))
	_r("Head", -_c(phase, 0.02, 0.1, 0.04))
	_r("Leg_L", _c(phase, 0.14, -0.28, -0.15))
	_aim_weapon("Weapon_Pistol", Vector3.UP, Vector3.UP, active)

func _pipe(attack: Dictionary, phase: Dictionary) -> void:
	_sword(attack, phase)
	_r("Body", _c(phase, -0.08, 0.1, 0.11))
	_p("Body", 0, -_c(phase, 0.06, 0.13, 0.07))
	if attack.get("style", "") == "low-pipe":
		model.rotation.y += _c(phase, -0.58, 0.23, 1.2)
		_aim_weapon("Weapon_Cutlass", WEAPON_AXES["master-thief"], Vector3(_c(phase, -1.2, 0, 1.25), -0.25, _c(phase, -0.12, 1, 0.1)), _c(phase, 1, 1, 1))

func _spin(attack: Dictionary, phase: Dictionary) -> void:
	var duration: float = maxf(0.01, float(attack.get("duration", 0.4)))
	var contact: float = float(attack.get("contact", 0.1))
	var t: float = clampf(float(attack.get("time", 0.0)) / duration, 0, 1)
	var launch: float = clampf(float(attack.get("time", 0.0)) / maxf(0.015, contact), 0, 1)
	model.rotation.y += -0.4 * _smooth(launch) if launch < 1 else -0.4 + (TAU + 0.4) * _smooth((t - contact / duration) / maxf(0.001, 1.0 - contact / duration))
	_r("Arm_R", _c(phase, -0.55, -0.95, -0.92), 0, -_c(phase, 0.7, 1.08, 1.12))
	_r("Arm_L", _c(phase, -0.55, -0.95, -0.92), 0, _c(phase, 0.7, 1.08, 1.12))
	_p("Body", 0, -_c(phase, 0.1, 0.14, 0.09))
	_r("Leg_R", _c(phase, -0.2, -0.18, 0.12))
	_r("Leg_L", _c(phase, 0.2, 0.18, -0.12))
	_aim_weapon("Weapon_Cutlass", WEAPON_AXES.explorer, Vector3(-1, 0.08, 0.45), _c(phase, 1, 1, 1))
	_aim_weapon("Weapon_Pistol", LEFT_BLADE, Vector3(1, 0.08, -0.45), _c(phase, 1, 1, 1))

func _shot(remaining: float) -> void:
	var duration: float = 0.28 if id == "pirate" else 0.2
	var t: float = 1.0 - clampf(remaining / duration, 0, 1)
	var weight: float = 1.0 - _smooth(t)
	var recoil: float = sin(PI * clampf(t / 0.55, 0, 1)) * weight
	var phase: Dictionary = {"from": 2, "to": 4, "mix": _smooth(t)}
	match id:
		"samurai", "ranger": _bow(phase, id == "samurai")
		"magic-swordsman": _sword({"index": 2, "style": "claymore"}, phase)
		"ninja":
			_r("Arm_L", -1.35 * weight, -0.6 * weight, 0.65 * weight)
			_p("Arm_L", -0.05 * weight, 0, 0.18 * weight)
			_r("Body", 0.12 * weight, -0.28 * weight)
			_r("Head", -0.05 * weight, 0.15 * weight)
		"mage":
			_r("Arm_L", -1.45 * weight, -0.13 * weight, 0.08 * weight)
			_p("Arm_L", 0, 0, -0.12 * recoil)
			_r("Body", -0.085 * recoil, -0.08 * weight)
			_r("Head", 0, 0.06 * weight)
		"pirate":
			_r("Arm_L", -1.36 * weight - 0.22 * recoil, -0.15 * weight, 0.1 * weight)
			_p("Arm_L", -0.04 * weight, 0.02 * recoil, -0.13 * recoil)
			_r("Body", -0.065 * recoil, -0.14 * weight)
			_r("Head", 0.05 * recoil, 0.1 * weight)

func animate_pose(state: Dictionary, dt: float, time: float, movement: float = 0.0) -> void:
	if not is_instance_valid(model):
		return
	var is_player: bool = bool(state.get("isPlayer", id not in ["revenant", "warden"]))
	var stride: float = sin(time * (13.0 if is_player else 9.0) + seed) * minf(1.0, movement) * 0.62
	for joint in joints.values():
		joint.node.transform = joint.transform
	_r("Leg_L", stride)
	_r("Leg_R", -stride)
	_r("Arm_L", -stride * 0.4)
	_r("Arm_R", stride * 0.4)
	model.position.y = absf(sin(time * 9.0 + seed)) * 0.045 * movement + sin(time * 2.4 + seed) * 0.025
	model.rotation = Vector3(0, 0, sin(time * 6.0 + seed) * 0.03 * movement)
	var attack = state.get("attack")
	if not is_player:
		if attack is Dictionary and not attack.is_empty():
			var t: float = float(attack.get("time", 0)) / maxf(0.01, float(attack.get("duration", 0.6)))
			var s: float = sin(minf(1, t) * PI)
			var even: bool = int(attack.get("index", 0)) % 2 == 0
			_r("Arm_R", -s * 0.7, (1.0 if even else -1.0) * sin(t * PI * 1.7) * 1.1, s * (-1.2 if even else 1.1))
			_r("Body", 0, sin(t * TAU) * 0.32)
			model.rotation.z += s * (-0.1 if even else 0.1)
			if int(attack.get("index", 0)) == 2:
				model.rotation.y = -minf(1.0, t * 1.25) * TAU
	else:
		_stance(state, time)
		if float(state.get("roll", 0)) <= 0 and not state.get("travel") and float(state.get("drinkGesture", 0)) <= 0:
			if attack is Dictionary and not attack.is_empty():
				var phase: Dictionary = _phase(attack)
				match str(attack.get("style", "cutlass")):
					"thrust": _lance(phase, int(attack.get("index", 0)))
					"staff": _staff(phase)
					"bow": _bow(phase)
					"bash": _shield(phase)
					"spin": _spin(attack, phase)
					"pipe", "low-pipe", "fireburst": _pipe(attack, phase)
					_: _sword(attack, phase)
			elif float(state.get("shot", 0)) > 0 and not bool(state.get("blocking", false)):
				_shot(float(state.shot))
	flash = maxf(0, flash - dt)
	# Unchanged imported materials stay on the GPU between hits.
	if flash > 0.0 or _flash_applied:
		for entry in materials:
			var material: StandardMaterial3D = entry.material
			if flash > 0:
				material.emission_enabled = true
				material.emission = flash_color
				material.emission_energy_multiplier = (0.28 if reduced_flashes else flash_strength) * minf(1.0, flash * 24.0)
			else:
				material.emission_enabled = entry.enabled
				material.emission = entry.emission
				material.emission_energy_multiplier = entry.energy
		_flash_applied = flash > 0.0

func _stance(state: Dictionary, time: float) -> void:
	match id:
		"ninja":
			model.position.y -= 0.07
			model.rotation.x += 0.08
			_r("Arm_L", 0, 0, 0.1)
			_r("Arm_R", 0, 0, -0.1)
		"samurai":
			_r("Body", 0, -0.09)
			_r("Head", 0, 0.06)
		"mage": _r("Arm_L", -0.2 - sin(time * 1.5) * 0.035)
		"ranger":
			_r("Arm_L", -0.18)
			_r("Head", 0, 0.08)
		"master-thief":
			model.rotation.z += sin(time * 1.5) * 0.025
			_r("Head", 0, 0, -0.04)
	var travel = state.get("travel")
	if travel is Dictionary and not travel.is_empty():
		var t: float = float(travel.get("time", 0)) / maxf(0.01, float(travel.get("duration", 0.5)))
		model.position.y += sin(t * PI) * float(travel.get("height", 2.5))
		match str(travel.get("kind", "")):
			"lance-leap":
				model.rotation.x = -0.5 if t > 0.55 else 0.25
				_r("Arm_R", -2.2)
				# Turn the actual lance point down for the landing, not just an effect.
				_aim_weapon("Weapon_Cutlass", WEAPON_AXES.dragoon, Vector3(0, -1, 0.25), clampf((t - 0.25) * 4.0, 0, 1))
			"fast-leap": model.rotation.z = sin(t * PI) * 0.25
			_: model.rotation.x = -0.25
	if float(state.get("roll", 0)) > 0:
		var duration: float = float(state.get("rollDuration", 0.32))
		var t: float = 1.0 - float(state.roll) / maxf(0.01, duration)
		if id == "pirate":
			model.position.y += sin(t * PI) * 0.4
			model.rotation.x = -t * TAU
		else:
			var flip: bool = state.get("rollStyle", "") == "backflip"
			model.position.y += sin(t * PI) * (1.4 if flip else 0.12)
			model.rotation.x = t * TAU if flip else -0.22
	if bool(state.get("crouched", false)):
		model.position.y -= 0.52
		_r("Body", 0.2)
		_r("Leg_L", -0.65)
		_r("Leg_R", -0.65)
	if bool(state.get("blocking", false)):
		_r("Arm_L", -1.25, 0, 0.2)
		if id == "master-thief":
			_r("Arm_R", -1.2, 0, -0.3)
		model.rotation.x = 0.12
	if joints.has("Weapon_Cutlass") and id == "master-thief" and float(state.get("buffTime", 0)) > 0:
		joints.Weapon_Cutlass.node.scale = joints.Weapon_Cutlass.scale * 3.0
	var gesture: float = float(state.get("drinkGesture", 0))
	if joints.has("Weapon_Pistol"):
		joints.Weapon_Pistol.node.visible = gesture <= 0
	if gesture > 0:
		_r("Arm_L", -1.9, 0, -0.5)
		_p("Arm_L", -0.17)
		_r("Head", -0.16)
		if joints.has("Flask"):
			joints.Flask.node.position = Vector3(0.17, 0.64, 0.39)
			joints.Flask.node.rotation = Vector3(-1.3, 0, -0.4)
	if float(state.get("drink", 0)) > 0:
		model.rotation.z += sin(time * 7.0) * 0.06
