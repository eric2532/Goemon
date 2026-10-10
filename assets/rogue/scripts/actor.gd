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
var _guard_glow_applied: bool = false
var locomotion = preload("res://assets/rogue/scripts/locomotion.gd").new()
var ultimate_aura: Node3D
var movement_wind: Node3D
var scarf_wind: RefCounted

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
	scarf_wind = null
	flash = 0.0
	_flash_applied = false
	_guard_glow_applied = false
	var resource = load("res://assets/rogue/styled/models/%s.glb" % id)
	if resource is PackedScene:
		model = resource.instantiate()
		# Fuller side silhouette; the painted front, height and collision stay intact.
		model.scale.z *= 1.15
		model.rotation_order = EULER_ORDER_XYZ
		add_child(model)
		_cache(model)
		if id == "samurai":
			scarf_wind = preload("res://assets/rogue/scripts/scarf_wind.gd").new()
			scarf_wind.configure(model)
		if is_instance_valid(ultimate_aura): ultimate_aura.queue_free()
		ultimate_aura = preload("res://assets/rogue/scripts/ultimate_aura.gd").new()
		add_child(ultimate_aura)
		ultimate_aura.configure(self, id)
		if is_instance_valid(movement_wind): movement_wind.queue_free()
		movement_wind = preload("res://assets/rogue/scripts/movement_wind.gd").new()
		add_child(movement_wind)
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

func reset_motion(clear_power: bool = true) -> void:
	locomotion.reset()
	if is_instance_valid(movement_wind): movement_wind.clear()
	if scarf_wind != null: scarf_wind.clear()
	if clear_power and is_instance_valid(ultimate_aura): ultimate_aura.clear()
	if _guard_glow_applied:
		for entry in materials:
			entry.material.emission_enabled = entry.enabled
			entry.material.emission = entry.emission
			entry.material.emission_energy_multiplier = entry.energy
		_guard_glow_applied = false

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
	var rest_rotation: Quaternion = joint.quaternion
	# Layer action entry over this frame's carrying pose; full contact remains exact.
	joint.quaternion = rest_rotation.slerp(aimed_rotation, clampf(amount, 0.0, 1.0))

# Authored native actors face +Z: anatomical right is -X. Weapon origins are
# palm centers, so turns keep the mesh attached to the actual hand.
func _hand_anchor(side: String) -> Vector3:
	var weapon: String = "Weapon_Cutlass" if side == "R" else "Weapon_Pistol"
	if joints.has(weapon):
		return joints[weapon].position
	var right: Vector3 = joints.Weapon_Cutlass.position
	return Vector3(-right.x, right.y, right.z)

func _place_hand(side: String, target: Vector3, amount: float = 1.0) -> void:
	var arm: Node3D = joints["Arm_" + side].node
	var grip: Vector3 = _hand_anchor(side)
	var direction: Vector3 = target - arm.position
	if direction.length_squared() < 0.0001:
		return
	var rotation_to_hand := Quaternion(grip.normalized(), direction.normalized())
	arm.quaternion = arm.quaternion.slerp(rotation_to_hand, amount)
	# The stylized rig has one solid arm per side; a small shoulder adjustment
	# closes the grip exactly without scaling arms or moving the weapon alone.
	arm.position = arm.position.lerp(target - arm.basis * grip, amount)

func _two_hand_grip() -> void:
	if id != "magic-swordsman" or not joints.has("Weapon_Cutlass"):
		return
	var weapon: Node3D = joints.Weapon_Cutlass.node
	var right: Node3D = joints.Arm_R.node
	var blade: Vector3 = (right.basis * weapon.basis * WEAPON_AXES[id]).normalized()
	var main_grip: Vector3 = right.transform * weapon.position
	# The other palm wraps the lower hilt, behind the right hand on the pommel.
	_place_hand("L", main_grip - blade * 0.19)

func _stow_weapon(name_: String, origin: Vector3, axis: Vector3) -> void:
	if not joints.has(name_):
		return
	var weapon: Node3D = joints[name_].node
	var arm: Node3D = weapon.get_parent()
	var source: Vector3 = Vector3.UP if name_ == "Weapon_Pistol" else WEAPON_AXES[id]
	var stowed := Transform3D(Basis(Quaternion(source.normalized(), axis.normalized())), origin)
	weapon.transform = arm.transform.affine_inverse() * stowed

func _underhand(attack: Dictionary, phase: Dictionary) -> void:
	var left: bool = id == "explorer" and int(attack.get("swingSide", -1 if int(attack.get("index", 0)) % 2 else 1)) < 0
	var side: String = "L" if left else "R"
	var sign_: float = 1.0 if left else -1.0
	var arm: String = "Arm_" + side
	var weapon: String = "Weapon_Pistol" if left else "Weapon_Cutlass"
	var active: float = _c(phase, 1, 1, 1)
	var sweep: float = _c(phase, -0.22, 0.18, 0.42) * -sign_
	_r("Body", _c(phase, 0.03, 0.11, 0.07), sweep)
	_r("Head", -_c(phase, 0.01, 0.07, 0.02), -sweep * 0.45)
	_p("Body", 0, -_c(phase, 0.07, 0.02, 0.04), _c(phase, -0.06, 0.13, 0.06))
	_r(arm, _c(phase, 0.24, -0.65, -1.08), _c(phase, -0.34, 0.13, 0.68) * -sign_, _c(phase, -0.1, 0.22, 0.34) * sign_)
	_p(arm, _c(phase, 0.035, -0.04, -0.07) * sign_, _c(phase, -0.035, 0.07, 0.12), _c(phase, -0.09, 0.14, 0.2))
	_r("Leg_R", _c(phase, -0.2, 0.2, 0.12))
	_r("Leg_L", _c(phase, 0.17, -0.17, -0.1))
	# A low outside-to-inside rising cut. The reverse blade leaves the little-
	# finger end of the fist; the recovery never changes back to a forward grip.
	var direction := Vector3(_c(phase, 0.56, 0.3, -0.66) * sign_, _c(phase, -0.42, -0.02, 0.58), _c(phase, -0.65, 1.0, 0.28))
	_aim_weapon(weapon, LEFT_BLADE if left else WEAPON_AXES[id], direction, active)
	model.rotation.x += _c(phase, -0.02, 0.06, 0.03)

func _special_cut(attack: Dictionary, phase: Dictionary) -> void:
	var style: String = attack.get("style", "")
	if id in ["ninja", "explorer"]:
		_underhand(attack, phase)
	else:
		_sword(attack, phase)
	var active: float = _c(phase, 1, 1, 1)
	if style in ["dash-cut", "evasive-slash"]:
		_r("Body", _c(phase, 0.12, 0.24, 0.1), _c(phase, -0.4, 0.16, 0.65))
		_p("Body", 0, -_c(phase, 0.08, 0.13, 0.03), _c(phase, -0.04, 0.16, 0.08))
	elif style == "cross-slash":
		_r("Arm_L", _c(phase, -0.3, -1.1, -0.65), _c(phase, -0.4, 0.1, 0.35), _c(phase, 0.4, -0.1, -0.2))
		_aim_weapon("Weapon_Pistol", LEFT_BLADE, Vector3(_c(phase, 0.9, -0.2, -0.8), _c(phase, -0.3, 0.1, 0.45), _c(phase, -0.3, 1, 0.35)), active)
	elif style == "power-slash":
		_r("Body", _c(phase, -0.12, 0.23, 0.18))
		_p("Body", 0, -_c(phase, 0.1, 0.06, 0.1))

func _charge_guard(state: Dictionary, time: float) -> void:
	var charge: float = clampf(float(state.get("chargeTime", 0.0)) / 3.0, 0, 1)
	if id == "mage" and charge > 0.0:
		var lift: float = _smooth(minf(1, charge * 5))
		_r("Arm_R", -1.5 * lift, 0.15 * lift, -0.23 * lift)
		_r("Arm_L", -1.1 * lift, -0.3 * lift, 0.24 * lift)
		_r("Body", -0.09 * lift)
		_p("Body", 0, -0.055 * lift)
		_aim_weapon("Weapon_Cutlass", WEAPON_AXES.mage, Vector3(-0.12, 1, 0.25), lift)
		model.rotation.z += sin(time * 32) * 0.012 * charge
	if bool(state.get("blocking", false)) or float(state.get("guardTime", 0.0)) > 0:
		if id == "master-thief":
			_place_hand("R", Vector3(-0.36, 0.17, 0.42))
			_place_hand("L", Vector3(0.27, 0.23, 0.45))
			_aim_weapon("Weapon_Cutlass", WEAPON_AXES[id], Vector3(1, 0.12, 0.05))
			_r("Body", 0.06)
		elif id == "knight":
			_place_hand("L", Vector3(0.26, 0.15, 0.42))
			_aim_weapon("Weapon_Pistol", Vector3.UP, Vector3.UP)

func _orient_bow(name_: String, forward: Vector3, up: Vector3, amount: float = 1.0) -> void:
	if not joints.has(name_):
		return
	var weapon: Node3D = joints[name_].node
	var parent_basis := Basis.IDENTITY
	var ancestor: Node3D = weapon.get_parent()
	while ancestor != null and ancestor != model:
		parent_basis = ancestor.basis.orthonormalized() * parent_basis
		ancestor = ancestor.get_parent() as Node3D
	# Ranger's nocked arrow points -X in the source mesh; Samurai's bow curves
	# +X. Align the complete bow plane, not only its long vertical axis.
	var x: Vector3 = forward.normalized() * (-1.0 if id == "ranger" else 1.0)
	var y: Vector3 = (up - x * up.dot(x)).normalized()
	var desired := Basis(x, y, x.cross(y))
	var orientation: Quaternion = (parent_basis.inverse() * desired).get_rotation_quaternion()
	weapon.quaternion = weapon.quaternion.slerp(orientation, amount)

func _equipment_pose(state: Dictionary) -> void:
	if id != "samurai":
		return
	# Resolve after arm actions, so stowed equipment follows the torso and cannot
	# be lifted by the hand that just drew the other weapon.
	if float(state.get("shot", 0)) > 0:
		_stow_weapon("Weapon_Cutlass", Vector3(-0.42, -0.12, -0.14), Vector3(-0.08, -1, -0.2))
	else:
		_stow_weapon("Weapon_Pistol", Vector3(0.04, 0.27, -0.4), Vector3(0.42, 1, 0))

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
	var bow_hand := Vector3(-0.27 * side, 0.28, 0.6)
	_place_hand("L" if samurai else "R", bow_hand, active)
	_place_hand("R" if samurai else "L", bow_hand + Vector3(0.2 * side, 0.035, -0.22), active)
	_orient_bow("Weapon_Pistol" if samurai else "Weapon_Cutlass", Vector3.BACK, Vector3.UP, active)

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
	for joint in joints.values():
		joint.node.transform = joint.transform
	model.position = Vector3.ZERO
	locomotion.apply(self, state, dt, time, movement)
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
					"bow", "bow-fan":
						_bow(phase)
						if bool(attack.get("downward", false)):
							_aerial_bow(_c(phase, 1, 1, 1))
					"bash", "shield-bash": _shield(phase)
					"dash-cut", "cross-slash", "power-slash", "evasive-slash": _special_cut(attack, phase)
					"ninja", "twin": _underhand(attack, phase)
					"charge-fireball": _staff(phase)
					"spin": _spin(attack, phase)
					"pipe", "low-pipe", "fireburst": _pipe(attack, phase)
					_: _sword(attack, phase)
			elif float(state.get("shot", 0)) > 0 and not bool(state.get("blocking", false)):
				_shot(float(state.shot))
				if id == "ranger" and bool(state.get("shotDownward", false)):
					_aerial_bow(clampf(float(state.shot) / 0.2, 0, 1))
		_charge_guard(state, time)
	locomotion.flip(self, state)
	if is_player:
		_two_hand_grip()
		_equipment_pose(state)
	if is_instance_valid(ultimate_aura): ultimate_aura.tick(state, dt)
	if is_instance_valid(movement_wind): movement_wind.tick(state, dt)
	if scarf_wind != null: scarf_wind.tick(state, dt)
	flash = maxf(0, flash - dt)
	var guard_glow: bool = id == "master-thief" and bool(state.get("blocking", false)) and state.get("guardStyle", "thief") == "thief"
	# Guard power adds light to the existing painted materials; releasing or
	# cancelling restores their saved emission immediately, including after hits.
	if flash > 0.0 or _flash_applied or guard_glow or _guard_glow_applied:
		for entry in materials:
			var material: StandardMaterial3D = entry.material
			if flash > 0:
				material.emission_enabled = true
				material.emission = flash_color
				material.emission_energy_multiplier = (0.28 if reduced_flashes else flash_strength) * minf(1.0, flash * 24.0)
			elif guard_glow:
				material.emission_enabled = true
				material.emission = Color("e52b29")
				material.emission_energy_multiplier = 0.38 if reduced_flashes else 0.62 + sin(time * 5.0) * 0.07
			else:
				material.emission_enabled = entry.enabled
				material.emission = entry.emission
				material.emission_energy_multiplier = entry.energy
		_flash_applied = flash > 0.0
	_guard_glow_applied = guard_glow

func _aerial_bow(weight: float) -> void:
	model.rotation.x += 0.65 * weight
	_r("Head", 0.22 * weight)
	_r("Leg_L", -0.85 * weight)
	_r("Leg_R", -0.65 * weight)

func _stance(state: Dictionary, time: float) -> void:
	# Keep the approved gait and its small carrying lag, then establish each
	# class's recognizable rest silhouette before layering the contact pose.
	match id:
		"magic-swordsman":
			var lag: Vector3 = joints.Arm_R.node.position - joints.Arm_R.position
			_place_hand("R", Vector3(-0.29, 0.02, 0.36) + lag)
			_aim_weapon("Weapon_Cutlass", WEAPON_AXES[id], Vector3(-0.9, -0.46, -0.32))
			_r("Body", 0.03, -0.06)
		"pirate":
			_r("Arm_R", -0.28, -0.08, -0.14)
			_aim_weapon("Weapon_Cutlass", WEAPON_AXES[id], Vector3(-0.23, 1, 0.12))
		"knight":
			_r("Arm_R", -0.12, 0.06, 0.08)
			_r("Arm_L", -0.2, -0.1, -0.12)
			_aim_weapon("Weapon_Cutlass", WEAPON_AXES[id], Vector3(-0.2, -0.87, 0.5))
			_aim_weapon("Weapon_Pistol", Vector3.UP, Vector3.UP)
		"explorer":
			_r("Arm_R", -0.12, -0.1, 0.08)
			_r("Arm_L", -0.12, 0.1, -0.08)
			_aim_weapon("Weapon_Cutlass", WEAPON_AXES[id], Vector3(-0.28, -0.74, -0.7))
			_aim_weapon("Weapon_Pistol", LEFT_BLADE, Vector3(0.28, -0.74, -0.7))
		"ninja":
			model.position.y -= 0.07
			model.rotation.x += 0.08
			_r("Arm_L", 0, 0, 0.1)
			_r("Arm_R", -0.2, -0.16, -0.12)
			_aim_weapon("Weapon_Cutlass", WEAPON_AXES[id], Vector3(-0.78, -0.16, -1))
		"samurai":
			_r("Body", 0, -0.09)
			_r("Head", 0, 0.06)
			_r("Arm_R", -0.08, -0.06, 0.08)
			_aim_weapon("Weapon_Cutlass", WEAPON_AXES[id], Vector3(-0.25, -0.68, 0.8))
		"mage": _r("Arm_L", -0.2 - sin(time * 1.5) * 0.035)
		"ranger":
			_r("Arm_R", -0.36, 0.04, 0.14)
			_r("Arm_L", -0.38, -0.16, -0.12)
			_r("Body", 0.02, -0.06)
			_r("Head", -0.035, 0.08)
			var lag: Vector3 = joints.Arm_R.node.position - joints.Arm_R.position
			_place_hand("R", Vector3(-0.33, 0.08, 0.39) + lag)
			_place_hand("L", Vector3(-0.1, 0.12, 0.17) + lag * 0.4)
			_orient_bow("Weapon_Cutlass", Vector3(0, -0.28, 1), Vector3(-0.18, 1, 0.28))
		"master-thief":
			model.rotation.z += sin(time * 1.5) * 0.025
			_r("Head", 0, 0, -0.04)
	var travel = state.get("travel")
	if travel is Dictionary and not travel.is_empty():
		var t: float = float(travel.get("time", 0)) / maxf(0.01, float(travel.get("duration", 0.5)))
		model.position.y += sin(t * PI) * float(travel.get("height", 2.5))
		match str(travel.get("kind", "")):
			"lance-leap":
				var dropping: bool = travel.get("phase", "arc") == "drop"
				model.rotation.x = -0.5 if dropping or t > 0.55 else 0.25
				_r("Arm_R", -2.2)
				# Turn the actual lance point down for the landing, not just an effect.
				_aim_weapon("Weapon_Cutlass", WEAPON_AXES.dragoon, Vector3(0, -1, 0.25), 1.0 if dropping else clampf((t - 0.25) * 4.0, 0, 1))
			"fast-leap": model.rotation.z = sin(t * PI) * 0.25
			_: model.rotation.x = -0.25
	if float(state.get("roll", 0)) > 0:
		var duration: float = float(state.get("rollDuration", 0.32))
		var t: float = 1.0 - float(state.roll) / maxf(0.01, duration)
		if id == "ranger" and state.get("rollStyle", "") == "roll":
			model.rotation.x = t * TAU
			var pivot: Vector3 = Vector3(0, 0.78, 0)
			model.position += pivot - model.basis * pivot
			_p("Body", 0, -0.22)
			_r("Leg_L", -1.1)
			_r("Leg_R", -1.1)
			_r("Arm_L", -0.9, 0, 0.3)
			_r("Arm_R", -0.9, 0, -0.3)
		elif id == "pirate":
			model.position.y += sin(t * PI) * 0.4
			model.rotation.x = -t * TAU
		else:
			var flip: bool = state.get("rollStyle", "") == "backflip"
			model.position.y += sin(t * PI) * (1.4 if flip else 0.12)
			model.rotation.x = -t * TAU if flip else -sin(t*PI)*0.22
			if flip:
				var pivot := Vector3(0, 1.05, 0)
				model.position += pivot-model.basis*pivot
		if state.get("rollStyle", "") in ["dash-cut", "cross-slash"]:
			var cut := {"style": state.rollStyle, "duration": duration, "contact": duration * 0.35, "time": duration - float(state.roll), "index": 0}
			_special_cut(cut, _phase(cut))
	if state.get("dive") != null and id == "magic-swordsman":
		model.rotation.x = -0.72
		_r("Body", 0.18, -0.12)
		_r("Arm_R", -1.9, -0.35, -0.2)
		_r("Arm_L", -1.8, 0.35, 0.2)
		_aim_weapon("Weapon_Cutlass", WEAPON_AXES["magic-swordsman"], Vector3(0, -0.85, 1), 1.0)
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
