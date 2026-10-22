extends SceneTree
## Test the visible imported Goemon joints, not the old rigid Edo body pivot.
var checks = 0
var failures = 0

func _initialize():call_deferred("run")

func check(ok: bool, label: String):
	checks += 1
	if not ok:failures += 1
	print("PASS " if ok else "FAIL ", label)

func pose(model, name_: String) -> Transform3D:
	return model.skeleton.get_bone_global_pose(model.skeleton.find_bone(name_))

func run():
	var model = MusashiModel.new()
	root.add_child(model)
	model.set_process(false)
	for speed in [10.2, 18.0]:
		model.locomotion.reset()
		model.locomotion_velocity = Vector3.FORWARD * speed
		var shoulders = Vector2(INF, -INF)
		var hips = Vector2(INF, -INF)
		var head = Vector2(INF, -INF)
		var heel_lift = [0.0, 0.0]
		var rear_sole = [0.0, 0.0]
		var knee_bend = [0.0, 0.0]
		var elbow_bend = [INF, INF]
		var lengths_error = 0.0
		var opposing = 0
		var turning = 0
		for frame in range(360):
			model.animate(1.0 / 120, speed, true, 0, 0, false, 0, false)
			if frame < 120:continue
			var shoulder_line: Vector3 = pose(model, "Arm_R").origin - pose(model, "Arm_L").origin
			var hip_line: Vector3 = pose(model, "Leg_R").origin - pose(model, "Leg_L").origin
			var shoulder_yaw = atan2(-shoulder_line.z, shoulder_line.x)
			var hip_yaw = atan2(-hip_line.z, hip_line.x)
			var head_forward: Vector3 = (pose(model, "Head").basis * model.locomotion.rest.Head.basis.inverse()) * Vector3.FORWARD
			var head_yaw = atan2(-head_forward.x, -head_forward.z)
			shoulders = Vector2(minf(shoulders.x, shoulder_yaw), maxf(shoulders.y, shoulder_yaw))
			hips = Vector2(minf(hips.x, hip_yaw), maxf(hips.y, hip_yaw))
			head = Vector2(minf(head.x, head_yaw), maxf(head.y, head_yaw))
			if absf(shoulder_yaw) > .1 and absf(hip_yaw) > .06:
				turning += 1
				if shoulder_yaw * hip_yaw < 0:opposing += 1
			for i in range(2):
				var side = "L" if i == 0 else "R"
				var hip = pose(model, "Leg_" + side).origin
				var knee = pose(model, "Shin_" + side).origin
				var foot = pose(model, "Foot_" + side)
				var other = pose(model, "Foot_" + ("R" if i == 0 else "L")).origin
				knee_bend[i] = maxf(knee_bend[i], (knee - hip).angle_to(foot.origin - knee))
				var shoulder = pose(model, "Arm_" + side).origin
				var elbow = pose(model, "Forearm_" + side).origin
				var hand = pose(model, "Hand_" + side).origin
				elbow_bend[i] = minf(elbow_bend[i], (elbow - shoulder).angle_to(hand - elbow))
				for pair in [["Leg_", "Shin_"], ["Shin_", "Foot_"], ["Arm_", "Forearm_"], ["Forearm_", "Hand_"]]:
					var a: String = pair[0] + side
					var b: String = pair[1] + side
					var original: float = model.locomotion.rest[a].origin.distance_to(model.locomotion.rest[b].origin)
					lengths_error = maxf(lengths_error, absf(pose(model, a).origin.distance_to(pose(model, b).origin) - original))
				if foot.origin.z > hip.z + .1:
					heel_lift[i] = maxf(heel_lift[i], foot.origin.y - other.y)
					var sole: Vector3 = (foot.basis * model.locomotion.rest["Foot_" + side].basis.inverse()) * Vector3.DOWN
					rear_sole[i] = maxf(rear_sole[i], sole.dot(Vector3.BACK))
		print("EDO_RUN speed=", speed, " shoulders=", shoulders, " hips=", hips, " head=", head, " opposing=", opposing, "/", turning, " heel=", heel_lift, " sole=", rear_sole, " knee=", knee_bend, " elbow=", elbow_bend, " length_error=", lengths_error)
		check(shoulders.x < -.2 and shoulders.y > .2, "Edo shoulders visibly turn both ways at speed %s" % speed)
		check(hips.x < -.13 and hips.y > .13, "Edo hips turn independently at speed %s" % speed)
		check(turning > 60 and opposing > turning * .85, "Edo shoulders oppose its hips at speed %s" % speed)
		check(head.y - head.x < .35, "Edo face stays readable during the torso turn at speed %s" % speed)
		check(lengths_error < .012, "Edo run preserves original arm and leg lengths at speed %s" % speed)
		for i in range(2):
			check(heel_lift[i] > .32 and rear_sole[i] > .65, "Edo foot %s lifts behind and exposes its sole at speed %s" % [i, speed])
			check(knee_bend[i] > .8, "Edo knee %s bends during recovery at speed %s" % [i, speed])
			check(elbow_bend[i] > .6, "Edo arm %s keeps a bent running elbow at speed %s" % [i, speed])
		var hand_before = pose(model, "Hand_R")
		model.sync_skeleton()
		check(hand_before.is_equal_approx(pose(model, "Hand_R")), "Repeated skeleton sync does not accumulate the Edo run turn")
	model.free()
	print("EDO_REFERENCE_RUN_RESULT checks=", checks, " failures=", failures)
	quit(1 if failures else 0)
