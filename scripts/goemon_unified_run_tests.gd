extends SceneTree
## The reference's rear silhouette: a shared body bank, rear arm and turned sole.
## Measure the rendered skeleton after every animation/IK layer has evaluated.
const Actor = preload("res://assets/rogue/scripts/actor.gd")
const IDS = ["goemon", "edo", "pirate", "samurai", "ninja", "mage", "knight", "dragoon", "magic-swordsman", "ranger", "explorer", "master-thief"]
var checks = 0
var failures = 0
var stage: Node3D

func _initialize():call_deferred("run")

func check(ok: bool, label: String):
	checks += 1
	if not ok:failures += 1
	print("PASS: " if ok else "FAIL: ", label)

func pose(sk: Skeleton3D, name_: String) -> Transform3D:
	return sk.get_bone_global_pose(sk.find_bone(name_))

func rest(sk: Skeleton3D, name_: String) -> Transform3D:
	return sk.get_bone_global_rest(sk.find_bone(name_))

func run():
	stage = Node3D.new();root.add_child(stage)
	var floor_body = StaticBody3D.new();stage.add_child(floor_body)
	var collision = CollisionShape3D.new();collision.shape = BoxShape3D.new()
	collision.shape.size = Vector3(200, .2, 200);collision.position.y = -.1
	floor_body.add_child(collision)
	await physics_frame
	for id in IDS:
		var model: Node3D
		if id == "goemon":model = HeroModel.new()
		elif id == "edo":model = MusashiModel.new()
		else:model = Actor.new()
		stage.add_child(model);model.set_process(false)
		if id not in ["goemon", "edo"]:model.setup(id)
		else:model.equipped = false
		var sk: Skeleton3D = model.skeleton if id in ["goemon", "edo"] else model.cosplay_rig.skeleton
		for speed in [10.2, 18.0]:
			model.position = Vector3.ZERO
			if id in ["goemon", "edo"]:model.locomotion.reset()
			else:model.reset_motion()
			var bank = Vector2(INF, -INF)
			var shared_bank = 0;var bank_samples = 0
			var rear_arm = [0.0, 0.0]
			var sole_error = 0.0;var sole_samples = 0
			var bone_error = 0.0
			for frame in range(360):
				if id in ["goemon", "edo"]:
					model.position += Vector3.FORWARD * speed / 120.0
					model.locomotion_velocity = Vector3.FORWARD * speed
					model.animate(1.0 / 120, speed, true, 0, 0, false, 0, false)
					model.sync_skeleton()
				else:model.animate_pose({"grounded":true, "motionSpeed":speed, "localMotion":Vector3.BACK * speed}, 1.0 / 120, frame / 120.0, 1)
				if frame < 120:continue
				var shoulders = pose(sk, "Arm_R").origin - pose(sk, "Arm_L").origin
				var hips = pose(sk, "Leg_R").origin - pose(sk, "Leg_L").origin
				var shoulder_bank = atan2(shoulders.y, Vector2(shoulders.x, shoulders.z).length())
				var hip_bank = atan2(hips.y, Vector2(hips.x, hips.z).length())
				bank = Vector2(minf(bank.x, shoulder_bank), maxf(bank.y, shoulder_bank))
				if absf(shoulder_bank) > .12:
					bank_samples += 1
					if shoulder_bank * hip_bank > 0 and absf(hip_bank) > .08:shared_bank += 1
				var chest = (pose(sk, "Chest").basis * rest(sk, "Chest").basis.inverse()).orthonormalized()
				var hip_yaw = atan2(-hips.z, hips.x)
				for i in range(2):
					var side = "L" if i == 0 else "R"
					var hand_in_chest = chest.inverse() * (pose(sk, "Hand_" + side).origin - pose(sk, "Arm_" + side).origin)
					if hand_in_chest.y > -.42:rear_arm[i] = maxf(rear_arm[i], hand_in_chest.z)
					var hip = pose(sk, "Leg_" + side).origin
					var foot = pose(sk, "Foot_" + side)
					var other = pose(sk, "Foot_" + ("R" if i == 0 else "L")).origin
					if foot.origin.y - other.y > .25 and foot.origin.z - hip.z > .10 and absf(hip_yaw) > .12:
						var foot_right = (foot.basis * rest(sk, "Foot_" + side).basis.inverse()) * Vector3.RIGHT
						var foot_yaw = atan2(-foot_right.z, foot_right.x)
						sole_error = maxf(sole_error, absf(angle_difference(hip_yaw, foot_yaw)))
						sole_samples += 1
					for pair in [["Arm_", "Forearm_"], ["Forearm_", "Hand_"], ["Leg_", "Shin_"], ["Shin_", "Foot_"]]:
						var a = pair[0] + side;var b = pair[1] + side
						bone_error = maxf(bone_error, absf(pose(sk, a).origin.distance_to(pose(sk, b).origin) - rest(sk, a).origin.distance_to(rest(sk, b).origin)))
			print("UNIFIED_RUN ", id, " speed=", speed, " shoulder_bank=", bank, " shared_bank=", shared_bank, "/", bank_samples, " rear_arm=", rear_arm, " sole_yaw_error=", sole_error, " sole_samples=", sole_samples, " bone_error=", bone_error)
			check(bank.x < -.16 and bank.y > .16, "%s at %s visibly banks the body to both sides" % [id, speed])
			check(bank_samples > 60 and shared_bank > bank_samples * .85, "%s at %s carries the shoulder bank through the hips" % [id, speed])
			check(rear_arm[0] > .25 and rear_arm[1] > .25, "%s at %s opens each rear arm behind the turning chest" % [id, speed])
			check(sole_samples > 8 and sole_error < .14, "%s at %s carries the raised sole around with the hip turn" % [id, speed])
			check(bone_error < .012, "%s at %s preserves all arm and leg segment lengths" % [id, speed])
		if id != "goemon":check_blended_stride(model, sk, id)
		model.free()
	stage.free()
	print("GOEMON_UNIFIED_RUN_RESULT checks=", checks, " failures=", failures)
	quit(1 if failures else 0)

func check_blended_stride(model: Node3D, sk: Skeleton3D, id: String):
	var worst = 0.0
	for speed in [2.0, 4.0, 8.0]:
		for direction in [Vector3.BACK, Vector3(.8, 0, .6)]:
			for frame in range(40):
				if id == "edo":
					model.locomotion_velocity = -direction * speed
					model.animate(1.0 / 60, speed, true, 0, 0, false, 0, false)
					model.sync_skeleton()
				else:model.animate_pose({"grounded":true, "motionSpeed":speed, "localMotion":direction * speed}, 1.0 / 60, frame / 60.0, 1)
				for side in ["L", "R"]:
					for pair in [["Arm_", "Forearm_"], ["Forearm_", "Hand_"]]:
						var a = pair[0] + side;var b = pair[1] + side
						worst = maxf(worst, absf(pose(sk, a).origin.distance_to(pose(sk, b).origin) - rest(sk, a).origin.distance_to(rest(sk, b).origin)))
	print("UNIFIED_RUN_BLEND ", id, " arm_length_error=", worst)
	check(worst < .012, id + " keeps arm lengths while starting, slowing and running diagonally")
