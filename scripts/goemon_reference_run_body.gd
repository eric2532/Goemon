extends RefCounted
## Add articulated running to rigs whose native motion supplies only a body pivot.
## Phase is one full left/right stride in [0, 1]; apply before terrain leg IK.
static func cadence(speed: float) -> float:
	# Full left/right cycles per second. A modestly quicker run keeps all joints
	# on one beat; stance_fraction matches foot contact to the same cadence.
	speed = maxf(0,speed)
	if speed <= 2.2:return speed*.5
	if speed <= 10.2:return lerpf(1.1,1.85,smoothstep(2.2,10.2,speed))
	return lerpf(1.85,2.30,smoothstep(10.2,18.0,speed)) + minf(.30,maxf(0,speed-18)*.012)

static func cycles_per_meter(speed: float) -> float:
	return cadence(speed)/speed if speed>.001 else .5

static func stance_fraction(speed: float, foot_travel: float) -> float:
	# During contact the foot travels backward as fast as the actor advances.
	# Retiming cadence alone would make grounded feet visibly slide forward.
	return clampf(foot_travel*cycles_per_meter(speed),.025,.60)

static func apply(skeleton: Skeleton3D, phase: float, weight: float = 1.0, swing_scale: float = 1.0) -> void:
	weight = clampf(weight, 0.0, 1.0)
	if weight < .001: return
	var stride = sin(TAU * (phase - .12)) * weight * swing_scale
	# Retain the reference lean and weight shift, then align its turn to the
	# shared stride. Native ready poses must not bias one shoulder forward.
	turn_chain(skeleton, "Pelvis", Vector3(0, .25 * stride, .025 * stride))
	turn_chain(skeleton, "Spine", Vector3(-.07 * weight, -.29 * stride, -.035 * stride))
	turn_chain(skeleton, "Chest", Vector3(-.07 * weight, -.39 * stride, -.025 * stride))
	turn_chain(skeleton, "Neck", Vector3(.10 * weight, .38 * stride, .025 * stride))
	turn(skeleton, phase, weight,swing_scale)
	bank(skeleton, phase, weight,swing_scale)

static func turn(skeleton: Skeleton3D, phase: float, weight: float, swing_scale: float = 1.0) -> void:
	var stride = sin(TAU * (phase - .12)) * swing_scale
	# Each joint follows the same beat: hips carry the forward leg, shoulders
	# carry the opposite arm, and the spine connects them without a rigid pivot.
	# Resolve from the current pose so Goemon's authored clip and the cosplay
	# rigs reach the same turn rather than adding different amounts of yaw.
	for entry in [["Pelvis", .36], ["Spine", -.25], ["Chest", -.65], ["Neck", -.08]]:
		var index = skeleton.find_bone(entry[0])
		var frame = skeleton.get_bone_global_pose(index).basis * skeleton.get_bone_global_rest(index).basis.inverse()
		var yaw = atan2(-frame.x.z, frame.x.x)
		turn_chain(skeleton, entry[0], Vector3(0, angle_difference(yaw, float(entry[1]) * stride) * weight, 0))

static func swing_inset(side: String, recovery: float) -> float:
	# A small inward arc only in the air; vanish smoothly before foot plant.
	return (.065 if side == "L" else -.065) * pow(sin(PI * clampf(recovery, 0, 1)), 2)

static func bank(skeleton: Skeleton3D, phase: float, weight: float, swing_scale: float = 1.0) -> void:
	# One weight shift carries the waist, shoulders, head and limb roots.
	# Keep this separate from yaw: the hips/chest still counter-turn naturally.
	turn_chain(skeleton, "Pelvis", Vector3(0, 0, .30 * sin(TAU * (phase - .12)) * weight * swing_scale))

static func blend_base(skeleton: Skeleton3D, rest: Dictionary, frame: Transform3D, weight: float) -> void:
	# Blend a connected hierarchy. Interpolating each global bone origin alone
	# cuts across an arm's arc and visibly shortens it at partial run weights.
	var before: Array[Transform3D] = []
	var target: Array[Transform3D] = []
	var blended: Array[Transform3D] = []
	for i in range(skeleton.get_bone_count()):
		before.append(skeleton.get_bone_global_pose(i))
		var name_ = skeleton.get_bone_name(i)
		target.append(frame * rest[name_] if name_ != "Root" else before[i])
	for i in range(before.size()):
		var parent = skeleton.get_bone_parent(i)
		if parent < 0:
			blended.append(before[i]);continue
		var from = before[parent].affine_inverse() * before[i]
		var to = target[parent].affine_inverse() * target[i]
		var local = from.interpolate_with(to, weight)
		if from.origin.length() > .001 and to.origin.length() > .001:
			local.origin = direction_blend(from.origin.normalized(), to.origin.normalized(), weight) * lerpf(from.origin.length(), to.origin.length(), weight)
		blended.append(blended[parent] * local)
	for i in range(blended.size()):skeleton.set_bone_global_pose(i, blended[i])

static func direction_blend(from: Vector3, to: Vector3, weight: float) -> Vector3:
	# Nearly parallel rest offsets have an unstable cross-product axis in
	# Vector3.slerp; normalized lerp has the same limit without that singularity.
	if from.dot(to) > .9995:return from.lerp(to, weight).normalized()
	return (Basis(Quaternion.IDENTITY.slerp(Quaternion(from, to), weight)) * from).normalized()

static func arms(skeleton: Skeleton3D, phase: float, weight: float) -> void:
	if weight < .001:return
	var chest_index = skeleton.find_bone("Chest")
	var chest = (skeleton.get_bone_global_pose(chest_index).basis * skeleton.get_bone_global_rest(chest_index).basis.inverse()).orthonormalized()
	for i in range(2):
		var side = "L" if i == 0 else "R"
		var upper_index = skeleton.find_bone("Arm_" + side)
		var lower_index = skeleton.find_bone("Forearm_" + side)
		var hand_index = skeleton.find_bone("Hand_" + side)
		var upper_rest = skeleton.get_bone_global_rest(upper_index)
		var lower_rest = skeleton.get_bone_global_rest(lower_index)
		var hand_rest = skeleton.get_bone_global_rest(hand_index)
		var upper = skeleton.get_bone_global_pose(upper_index)
		var lower = skeleton.get_bone_global_pose(lower_index)
		var hand = skeleton.get_bone_global_pose(hand_index)
		var sign_ = -1.0 if i == 0 else 1.0
		var stride = sin(TAU * (phase + i * .5 - .12))
		# Swing across the body in three dimensions: the forward forearm folds
		# inward over the chest while the trailing arm opens outward and back.
		# Both paths inherit the chest turn and trade places every half stride.
		var swing = 1.50 * stride - .30
		var bend = 1.0 + .55 * stride
		var forward = (stride + 1.0) * .5
		# Open the passing arm away from the hip, preserving the inward fold
		# at the forward peak and the outward reach at the trailing peak.
		var hip_clearance = .22 * (1.0 - stride * stride)
		var upper_side = lerpf(.68,.16,forward) + hip_clearance
		var lower_side = lerpf(.45,-.90,forward) + hip_clearance * .5
		var upper_dir = Vector3(sign_ * upper_side, -cos(swing), -sin(swing)).normalized()
		var lower_dir = Vector3(sign_ * lower_side, -cos(swing + bend), -sin(swing + bend)).normalized()
		var upper_vector = lower_rest.origin - upper_rest.origin
		var lower_vector = hand_rest.origin - lower_rest.origin
		var upper_basis = chest * Basis(Quaternion(upper_vector.normalized(), upper_dir)) * upper_rest.basis
		var lower_basis = chest * Basis(Quaternion(lower_vector.normalized(), lower_dir)) * lower_rest.basis
		var upper_ray = (lower.origin - upper.origin).normalized().slerp(chest * upper_dir, weight).normalized()
		var lower_ray = (hand.origin - lower.origin).normalized().slerp(chest * lower_dir, weight).normalized()
		var elbow = upper.origin + upper_ray * lerpf(upper.origin.distance_to(lower.origin), upper_vector.length(), weight)
		var wrist = elbow + lower_ray * lerpf(lower.origin.distance_to(hand.origin), lower_vector.length(), weight)
		upper.basis = blend_basis(upper.basis, upper_basis, weight)
		lower.basis = blend_basis(lower.basis, lower_basis, weight);lower.origin = elbow
		hand.basis = blend_basis(hand.basis, chest * Basis(Quaternion(lower_vector.normalized(), lower_dir)) * hand_rest.basis, weight)
		hand.origin = wrist
		skeleton.set_bone_global_pose(upper_index, upper)
		skeleton.set_bone_global_pose(lower_index, lower)
		skeleton.set_bone_global_pose(hand_index, hand)

static func blend_basis(from: Basis, to: Basis, weight: float) -> Basis:
	# Goemon's idle scales the arms to 81%; rotation interpolation must first
	# separate that scale when blending out of idle or back from an attack.
	return Basis(from.get_rotation_quaternion().slerp(to.get_rotation_quaternion(), weight)).scaled(from.get_scale().lerp(to.get_scale(), weight))

static func hip_frame(skeleton: Skeleton3D) -> Basis:
	var index = skeleton.find_bone("Pelvis")
	return (skeleton.get_bone_global_pose(index).basis * skeleton.get_bone_global_rest(index).basis.inverse()).orthonormalized()

static func turn_chain(skeleton: Skeleton3D, bone_name: String, angles: Vector3) -> void:
	var root = skeleton.find_bone(bone_name)
	if root < 0: return
	var pivot = skeleton.get_bone_global_pose(root).origin
	var rotation = Basis.from_euler(angles)
	var transformed: Dictionary = {}
	for bone in range(skeleton.get_bone_count()):
		var ancestor = bone
		while ancestor >= 0 and ancestor != root:
			ancestor = skeleton.get_bone_parent(ancestor)
		if ancestor != root: continue
		var pose = skeleton.get_bone_global_pose(bone)
		pose.origin = pivot + rotation * (pose.origin - pivot)
		pose.basis = rotation * pose.basis
		transformed[bone] = pose
	# Cache descendants before changing the parent so inherited updates
	# cannot be applied a second time to the transforms still being read.
	for bone in transformed:
		skeleton.set_bone_global_pose(bone, transformed[bone])
