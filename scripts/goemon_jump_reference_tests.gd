extends SceneTree
## Exercise the final skinned pose through launch, apex, fall and landing.
const Actor = preload("res://assets/rogue/scripts/actor.gd")
const IDS = ["goemon", "edo", "pirate", "samurai", "ninja", "mage", "knight", "dragoon", "magic-swordsman", "ranger", "explorer", "master-thief"]
var stage: Node3D
var checks = 0
var failures = 0

func _initialize():call_deferred("run")
func check(ok: bool, label: String):
	checks += 1
	if not ok:failures += 1
	print("PASS: " if ok else "FAIL: ", label)
func pose(sk: Skeleton3D, name_: String) -> Transform3D:
	return sk.get_bone_global_pose(sk.find_bone(name_))
func rest(sk: Skeleton3D, name_: String) -> Transform3D:
	return sk.get_bone_global_rest(sk.find_bone(name_))

func setup():
	stage = Node3D.new();root.add_child(stage)
	var ground = StaticBody3D.new();stage.add_child(ground)
	var collision = CollisionShape3D.new();collision.shape = BoxShape3D.new()
	collision.shape.size = Vector3(200, .2, 200);collision.position.y = -.1
	ground.add_child(collision)
	await physics_frame

func tick(model: Node3D, id: String, grounded: bool, vertical: float):
	if id in ["goemon", "edo"]:
		model.locomotion_velocity = Vector3.FORWARD * 10.2
		model.position += Vector3.FORWARD * 10.2 / 60.0
		model.animate(1.0 / 60, 10.2, grounded, vertical, 0, false, 0, false)
		model.sync_skeleton()
	else:
		model.animate_pose({"grounded":grounded, "vertical":vertical, "motionSpeed":10.2, "localMotion":Vector3.BACK * 10.2}, 1.0 / 60, 0, 1)

func run():
	await setup()
	for id in IDS:
		var model: Node3D = HeroModel.new() if id == "goemon" else (MusashiModel.new() if id == "edo" else Actor.new())
		stage.add_child(model);model.set_process(false)
		if id not in ["goemon", "edo"]:model.setup(id)
		else:model.equipped = false
		var sk: Skeleton3D = model.skeleton if id in ["goemon", "edo"] else model.cosplay_rig.skeleton
		for frame in range(40):tick(model, id, true, 0)
		var lengths_error = 0.0;var root_error = 0.0;var grip_error = 0.0
		var apex_height = [0.0, 0.0];var fall_height = [0.0, 0.0]
		for phase in range(4):
			var grounded = phase == 3
			var vertical = [12.0, 0.0, -22.0, 0.0][phase]
			for frame in range(24):
				tick(model, id, grounded, vertical)
				root_error = maxf(root_error, absf(model.global_position.y))
				for side in ["L", "R"]:
					for pair in [["Leg_", "Shin_"], ["Shin_", "Foot_"]]:
						var a = pair[0] + side;var b = pair[1] + side
						lengths_error = maxf(lengths_error, absf(pose(sk, a).origin.distance_to(pose(sk, b).origin) - rest(sk, a).origin.distance_to(rest(sk, b).origin)))
				if id not in ["goemon", "edo"]:
					grip_error = maxf(grip_error, model.joints.Weapon_Cutlass.node.global_position.distance_to(sk.global_transform * pose(sk, "Hand_R").origin))
			if phase == 1:
				var chest = (pose(sk, "Chest").basis * rest(sk, "Chest").basis.inverse()).orthonormalized()
				for i in range(2):
					var side = "L" if i == 0 else "R"
					var hand = chest.inverse() * (pose(sk, "Hand_" + side).origin - pose(sk, "Arm_" + side).origin)
					var hip = pose(sk, "Leg_" + side).origin;var knee = pose(sk, "Shin_" + side).origin;var foot = pose(sk, "Foot_" + side)
					var sole = (foot.basis * rest(sk, "Foot_" + side).basis.inverse()) * Vector3.DOWN
					apex_height[i] = foot.origin.y - hip.y
					print("JUMP_REFERENCE ", id, " ", side, " hand=", hand, " knee=", (knee-hip).angle_to(foot.origin-knee), " sole=", sole, " heel=", foot.origin-hip)
					check(hand.x * (-1.0 if i == 0 else 1.0) > .48 and absf(hand.y) < .20, id + " spreads " + side + " arm beside the shoulder")
					check((knee-hip).angle_to(foot.origin-knee) > .8 and foot.origin.z > hip.z + .05, id + " bends " + side + " knee and tucks its heel behind")
					check(sole.dot(Vector3.BACK) > .65, id + " shows " + side + " sole from the rear at the apex")
				check(absf(pose(sk, "Hand_L").origin.y - pose(sk, "Hand_R").origin.y) < .09, id + " holds a balanced two-arm jump silhouette")
			elif phase == 2:
				for i in range(2):
					var side = "L" if i == 0 else "R"
					fall_height[i] = pose(sk, "Foot_" + side).origin.y - pose(sk, "Leg_" + side).origin.y
			elif phase == 3:
				if preload("res://scripts/user_stride_run.gd").enabled(id):
					# The approved stride separates the hands fore/aft more than the
					# former run. Check return to that actual pose after the jump.
					var data: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/animations/goemon_edo_run.json"))
					var phase_: float=model.locomotion.phase/(1.0 if id=="goemon" else TAU)
					var frame_=fposmod(phase_,1.0)*60.0
					var error=0.0
					for side in ["L","R"]:
						var index=data.bones.find("Hand_"+side)
						var a: Array=data.frames[int(frame_)][index]
						var b: Array=data.frames[int(frame_)+1][index]
						var expected=Vector3(a[0],a[1]+data.floor_offset,a[2]).lerp(Vector3(b[0],b[1]+data.floor_offset,b[2]),frame_-int(frame_))
						error=maxf(error,pose(sk,"Hand_"+side).origin.distance_to(expected))
					check(error<.04,id+" returns to the approved Blender run after landing")
				else:
					check(pose(sk, "Hand_L").origin.distance_to(pose(sk, "Hand_R").origin) < 1.8, id + " releases the wide arm pose after landing")
		check(fall_height[0] < apex_height[0] - .08 and fall_height[1] < apex_height[1] - .08, id + " extends both legs in preparation for landing")
		check(lengths_error < .012, id + " preserves leg lengths through every jump transition")
		check(root_error < .0001, id + " leaves jump height and root movement to the controller")
		if id not in ["goemon", "edo"]:check(grip_error < .22, id + " keeps its weapon attached through the jump")
		for frame in range(30):stationary_tick(model,id,false,-22)
		var last_feet = limb_ends(sk).slice(2)
		stationary_tick(model,id,true,0)
		check(endpoint_motion(last_feet,limb_ends(sk).slice(2)) < .20,id + " releases the tucked legs continuously on landing")
		if id in ["goemon", "edo"]:
			for frame in range(30):stationary_tick(model,id,false,0)
			var endpoints = limb_ends(sk)
			model.locomotion.free_feet = true;model.locomotion.reference_jump_flip = 0
			stationary_tick(model,id,false,0)
			check(endpoint_motion(endpoints,limb_ends(sk)) < .10,id + " enters its double-jump flip without a pose snap")
			for frame in range(25):
				model.locomotion.reference_jump_flip = float(frame)/24
				stationary_tick(model,id,false,0)
			endpoints = limb_ends(sk)
			model.locomotion.free_feet = false;model.locomotion.reference_jump_flip = -1
			stationary_tick(model,id,false,0)
			check(endpoint_motion(endpoints,limb_ends(sk)) < .10,id + " returns from its double-jump flip without a pose snap")
		if id not in ["goemon", "edo"]:
			for frame in range(30):model.animate_pose({"grounded":false,"vertical":0.0},1.0/60,0,0)
			var endpoints = limb_ends(sk)
			model.animate_pose({"grounded":false,"vertical":0.0,"flip":0.0},1.0/60,0,0)
			check(endpoint_motion(endpoints,limb_ends(sk)) < .10,id + " enters its double-jump flip without a pose snap")
			for frame in range(25):model.animate_pose({"grounded":false,"vertical":0.0,"flip":float(frame)/24},1.0/60,0,0)
			endpoints = limb_ends(sk)
			model.animate_pose({"grounded":false,"vertical":0.0,"flip":-1.0},1.0/60,0,0)
			check(endpoint_motion(endpoints,limb_ends(sk)) < .10,id + " returns from its double-jump flip without a pose snap")
		model.free()
	stage.free()
	print("GOEMON_JUMP_REFERENCE_RESULT checks=", checks, " failures=", failures)
	quit(1 if failures else 0)

func limb_ends(sk: Skeleton3D) -> Array[Vector3]:
	var result: Array[Vector3] = []
	for name_ in ["Hand_L","Hand_R","Foot_L","Foot_R"]:result.append(pose(sk,name_).origin)
	return result

func stationary_tick(model: Node3D,id: String,grounded: bool,vertical: float):
	if id in ["goemon","edo"]:
		model.locomotion_velocity = Vector3.ZERO
		model.animate(1.0/60,0,grounded,vertical,0,false,0,false)
		model.sync_skeleton()
	else:model.animate_pose({"grounded":grounded,"vertical":vertical},1.0/60,0,0)

func endpoint_motion(before: Array[Vector3], after: Array[Vector3]) -> float:
	var largest = 0.0
	for i in range(before.size()):largest = maxf(largest,before[i].distance_to(after[i]))
	return largest
