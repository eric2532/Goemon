extends SceneTree
## Exercises torso/hip opposition, torso-relative arms, heel recovery and terrain IK.
## Measures the real weighted rig so a single rigid body pivot cannot pass as a run.
var stage: Node3D
var model: HeroModel
var checks = 0
var failures = 0

func _initialize():
	call_deferred("run")

func setup():
	stage = Node3D.new()
	root.add_child(stage)
	var floor_body = StaticBody3D.new()
	stage.add_child(floor_body)
	var collision = CollisionShape3D.new()
	collision.shape = BoxShape3D.new()
	collision.shape.size = Vector3(200, .2, 200)
	collision.position.y = -.1
	floor_body.add_child(collision)
	model = HeroModel.new()
	stage.add_child(model)
	model.set_process(false)
	model.equipped = false
	await physics_frame
	await physics_frame

func step(velocity: Vector3, delta: float = 1.0 / 120.0):
	model.position += velocity * delta
	model.locomotion_velocity = velocity
	model.animate(delta, velocity.length(), true, 0, 0, false, 0, false)
	model.sync_skeleton()

func check(ok: bool, message: String):
	checks += 1
	if not ok: failures += 1
	print("PASS: " if ok else "FAIL: ", message)

func run():
	await setup()
	for speed in [10.2, 18.0]:
		var heel_lift = [0.0, 0.0]
		var rear_sole = [0.0, 0.0]
		var joint_error = 0.0
		var root_drift = 0.0
		var shoulder_yaw = Vector2(INF, -INF)
		var hip_yaw = Vector2(INF, -INF)
		var head_yaw = Vector2(INF, -INF)
		var opposing_frames = 0
		var turning_frames = 0
		var arm_outboard = INF
		for frame in range(360):
			step(Vector3.FORWARD * speed)
			if frame < 120: continue
			var motion = model.locomotion
			root_drift = maxf(root_drift, motion.pose("Root").origin.length())
			# Measure the actual shoulder and hip lines, not local Euler channels:
			# rotating one rigid body must not masquerade as torso counter-rotation.
			var shoulders = motion.pose("Arm_R").origin - motion.pose("Arm_L").origin
			var hips = motion.pose("Leg_R").origin - motion.pose("Leg_L").origin
			var shoulder_angle = atan2(-shoulders.z, shoulders.x)
			var hip_angle = atan2(-hips.z, hips.x)
			var head_forward = (motion.pose("Head").basis * motion.rest.Head.basis.inverse()) * Vector3.FORWARD
			var head_angle = atan2(-head_forward.x, -head_forward.z)
			shoulder_yaw = Vector2(minf(shoulder_yaw.x, shoulder_angle), maxf(shoulder_yaw.y, shoulder_angle))
			hip_yaw = Vector2(minf(hip_yaw.x, hip_angle), maxf(hip_yaw.y, hip_angle))
			head_yaw = Vector2(minf(head_yaw.x, head_angle), maxf(head_yaw.y, head_angle))
			if absf(shoulder_angle) > .10 and absf(hip_angle) > .06:
				turning_frames += 1
				if shoulder_angle * hip_angle < 0: opposing_frames += 1
			for i in range(2):
				var side = "L" if i == 0 else "R"
				var chest_frame = (motion.pose("Chest").basis * motion.rest.Chest.basis.inverse()).orthonormalized()
				var shoulder_to_hand = chest_frame.inverse() * (motion.pose("Hand_" + side).origin - motion.pose("Arm_" + side).origin)
				arm_outboard = minf(arm_outboard, shoulder_to_hand.x * (-1.0 if i == 0 else 1.0))
				var hip = motion.pose("Leg_" + side).origin
				var knee = motion.pose("Shin_" + side).origin
				var foot = motion.pose("Foot_" + side)
				var other = motion.pose("Foot_" + ("R" if i == 0 else "L")).origin
				var upper = motion.rest["Leg_" + side].origin.distance_to(motion.rest["Shin_" + side].origin)
				var lower = motion.rest["Shin_" + side].origin.distance_to(motion.rest["Foot_" + side].origin)
				joint_error = maxf(joint_error, maxf(absf(hip.distance_to(knee) - upper), absf(knee.distance_to(foot.origin) - lower)))
				if foot.origin.z > hip.z + .10:
					heel_lift[i] = maxf(heel_lift[i], foot.origin.y - other.y)
					var sole = (foot.basis * motion.rest["Foot_" + side].basis.inverse()) * Vector3.DOWN
					rear_sole[i] = maxf(rear_sole[i], sole.dot(Vector3.BACK))
		print("REFERENCE_RUN speed=", speed, " heel_lift=", heel_lift, " rear_sole=", rear_sole, " joint_error=", joint_error, " shoulder_yaw=", shoulder_yaw, " hip_yaw=", hip_yaw, " head_yaw=", head_yaw, " opposition=", opposing_frames, "/", turning_frames)
		for i in range(2):
			check(heel_lift[i] > .32, "At speed %s foot %s kicks visibly up behind the body" % [speed, i])
			check(rear_sole[i] > .65, "At speed %s foot %s shows its sole from behind during recovery" % [speed, i])
		check(joint_error < .012, "At speed %s both legs preserve their segment lengths" % speed)
		check(root_drift < .0001, "At speed %s the controller retains ownership of root movement" % speed)
		check(shoulder_yaw.x < -.20 and shoulder_yaw.y > .20, "At speed %s the shoulder line visibly turns to both sides each stride" % speed)
		check(hip_yaw.x < -.13 and hip_yaw.y > .13, "At speed %s the hips visibly turn to both sides each stride" % speed)
		check(turning_frames > 60 and opposing_frames > turning_frames * .85, "At speed %s shoulders and hips oppose instead of turning as one rigid block" % speed)
		check(head_yaw.y - head_yaw.x < .35, "At speed %s head counter-rotation keeps the face readable" % speed)
		print("REFERENCE_ARM_OUTBOARD speed=", speed, " minimum=", arm_outboard)
		check(arm_outboard > .10, "At speed %s compact hands retain clearance beside the turning torso" % speed)
	check_mapped_body_run()
	stage.free()
	print("GOEMON_RUN_REFERENCE_RESULT checks=", checks, " failures=", failures)
	quit(1 if failures else 0)

func check_mapped_body_run():
	# Costume adapters have no authored torso tracks. The same real weighted
	# skeleton must gain separate shoulder/hip motion from a neutral body pivot.
	var body_run = load("res://scripts/goemon_reference_run_body.gd")
	var shoulder_range = Vector2(INF, -INF)
	var hip_range = Vector2(INF, -INF)
	var head_range = Vector2(INF, -INF)
	var opposing = 0
	var length_error = 0.0
	for frame in range(120):
		model.skeleton.reset_bone_poses()
		body_run.apply(model.skeleton, float(frame) / 120.0, 1.0)
		var shoulders = model.locomotion.pose("Arm_R").origin - model.locomotion.pose("Arm_L").origin
		var hips = model.locomotion.pose("Leg_R").origin - model.locomotion.pose("Leg_L").origin
		var shoulder_angle = atan2(-shoulders.z, shoulders.x)
		var hip_angle = atan2(-hips.z, hips.x)
		var head_forward = (model.locomotion.pose("Head").basis * model.locomotion.rest.Head.basis.inverse()) * Vector3.FORWARD
		var head_angle = atan2(-head_forward.x, -head_forward.z)
		shoulder_range = Vector2(minf(shoulder_range.x, shoulder_angle), maxf(shoulder_range.y, shoulder_angle))
		hip_range = Vector2(minf(hip_range.x, hip_angle), maxf(hip_range.y, hip_angle))
		head_range = Vector2(minf(head_range.x, head_angle), maxf(head_range.y, head_angle))
		if shoulder_angle * hip_angle < 0: opposing += 1
		for bone in range(model.skeleton.get_bone_count()):
			var parent = model.skeleton.get_bone_parent(bone)
			if parent < 0: continue
			var rest_length = model.skeleton.get_bone_global_rest(bone).origin.distance_to(model.skeleton.get_bone_global_rest(parent).origin)
			var posed_length = model.skeleton.get_bone_global_pose(bone).origin.distance_to(model.skeleton.get_bone_global_pose(parent).origin)
			length_error = maxf(length_error, absf(posed_length - rest_length))
	print("REFERENCE_MAPPED_RUN shoulders=", shoulder_range, " hips=", hip_range, " head=", head_range, " opposition=", opposing, "/120 length_error=", length_error)
	check(shoulder_range.x < -.30 and shoulder_range.y > .30, "Mapped body pivots gain a visible alternating shoulder turn")
	check(hip_range.x < -.18 and hip_range.y > .18, "Mapped body pivots gain an independent alternating hip turn")
	check(opposing > 110, "Mapped shoulders oppose the hips through both halves of the stride")
	check(head_range.y - head_range.x < .25, "Mapped neck counter-turn keeps the head facing travel")
	check(length_error < .0001, "Mapped torso turn preserves every connected bone segment")
	model.skeleton.reset_bone_poses()
	body_run.apply(model.skeleton, .25, 0.0)
	var neutral_error = 0.0
	for bone in range(model.skeleton.get_bone_count()):
		var rest = model.skeleton.get_bone_global_rest(bone)
		var posed = model.skeleton.get_bone_global_pose(bone)
		neutral_error = maxf(neutral_error, rest.origin.distance_to(posed.origin))
		neutral_error = maxf(neutral_error, rest.basis.get_rotation_quaternion().angle_to(posed.basis.get_rotation_quaternion()))
	check(neutral_error < .0001, "Zero run weight leaves mapped idle, air and action poses unchanged")
