extends RefCounted
## Shared Goemon jump silhouette. This only poses bones; the controller owns the arc.
const PoseBlend = preload("res://scripts/goemon_reference_run_body.gd")
var last_vertical = 0.0

static func flip_weight(progress: float) -> float:
	# The turn begins and ends in the airborne silhouette, with the authored
	# tuck owning the middle of the somersault. Keep the boundary poses equal.
	if progress < 0 or progress > 1:return 1.0
	return 1.0 - smoothstep(0.0,.25,progress) + smoothstep(.75,1.0,progress)

func apply(skeleton: Skeleton3D, vertical: float, weight: float, grounded: bool) -> void:
	if weight < .001:return
	if not grounded:last_vertical = vertical
	var rest = {};var target = {}
	for i in range(skeleton.get_bone_count()):
		var name_ = skeleton.get_bone_name(i)
		rest[name_] = skeleton.get_bone_global_rest(i)
		target[name_] = skeleton.get_bone_global_pose(i) if grounded else rest[name_]
	# Keep the final airborne leg target while its weight fades on landing.
	# Resetting vertical velocity on contact must not retuck or drop both heels.
	var tuck = 1.0 - .65 * smoothstep(5.0, 22.0, maxf(0, -last_vertical))
	if not grounded:
		var pivot: Vector3 = rest.Pelvis.origin
		var lean = Basis(Vector3.RIGHT, -.10 * tuck)
		for name_ in target:
			if name_ == "Root":continue
			target[name_] = Transform3D(lean * target[name_].basis, pivot + lean * (target[name_].origin - pivot))
	var chest: Basis = (target.Chest.basis * rest.Chest.basis.inverse()).orthonormalized()
	var hips: Basis = (target.Pelvis.basis * rest.Pelvis.basis.inverse()).orthonormalized()
	for i in range(2):
		var side = "L" if i == 0 else "R"
		var sign_ = -1.0 if i == 0 else 1.0
		# A slight elbow bend lifts the fists just above the shoulder line.
		limb(target, rest, ["Arm_" + side, "Forearm_" + side, "Hand_" + side], chest,
			Vector3(sign_, -.06, -.12).normalized(), Vector3(sign_, .25, -.04).normalized())
		limb(target, rest, ["Leg_" + side, "Shin_" + side, "Foot_" + side], hips,
			Vector3(sign_ * .10, -cos(.16 * tuck), -sin(.16 * tuck)).normalized(),
			Vector3(sign_ * .12, -cos(1.15 * tuck), sin(1.15 * tuck)).normalized())
		target["Foot_" + side].basis = hips * Basis(Vector3.UP, -sign_ * .18 * tuck) * Basis(Vector3.RIGHT, -1.05 * tuck) * rest["Foot_" + side].basis
	PoseBlend.blend_base(skeleton, target, Transform3D.IDENTITY, clampf(weight, 0, 1))
	if not grounded:preserve_leg_lengths(skeleton)

static func limb(target: Dictionary, rest: Dictionary, names: Array, frame: Basis, upper_dir: Vector3, lower_dir: Vector3) -> void:
	var upper: Transform3D = target[names[0]]
	var lower: Transform3D = target[names[1]]
	var end: Transform3D = target[names[2]]
	var upper_rest: Vector3 = rest[names[1]].origin - rest[names[0]].origin
	var lower_rest: Vector3 = rest[names[2]].origin - rest[names[1]].origin
	upper.basis = frame * Basis(Quaternion(upper_rest.normalized(), upper_dir)) * rest[names[0]].basis
	lower.basis = frame * Basis(Quaternion(lower_rest.normalized(), lower_dir)) * rest[names[1]].basis
	end.basis = frame * Basis(Quaternion(lower_rest.normalized(), lower_dir)) * rest[names[2]].basis
	lower.origin = upper.origin + frame * upper_dir * upper_rest.length()
	end.origin = lower.origin + frame * lower_dir * lower_rest.length()
	target[names[0]] = upper;target[names[1]] = lower;target[names[2]] = end

static func preserve_leg_lengths(skeleton: Skeleton3D) -> void:
	# Authored ground/air clips interpolate joint translations. Keep the actual
	# segment lengths during that transition, including flips and air attacks.
	for side in ["L", "R"]:
		var a = skeleton.find_bone("Leg_" + side)
		var b = skeleton.find_bone("Shin_" + side)
		var c = skeleton.find_bone("Foot_" + side)
		var hip = skeleton.get_bone_global_pose(a)
		var knee = skeleton.get_bone_global_pose(b)
		var foot = skeleton.get_bone_global_pose(c)
		var upper = skeleton.get_bone_global_rest(a).origin.distance_to(skeleton.get_bone_global_rest(b).origin)
		var lower = skeleton.get_bone_global_rest(b).origin.distance_to(skeleton.get_bone_global_rest(c).origin)
		var lower_dir = (foot.origin - knee.origin).normalized()
		knee.origin = hip.origin + (knee.origin - hip.origin).normalized() * upper
		foot.origin = knee.origin + lower_dir * lower
		skeleton.set_bone_global_pose(b, knee)
		skeleton.set_bone_global_pose(c, foot)
