extends SceneTree
## Deterministic grip constraints and rendered review of the native Rogue rigs.
const Actor = preload("res://assets/rogue/scripts/actor.gd")
const IDS = ["pirate", "samurai", "ninja", "mage", "knight", "dragoon", "magic-swordsman", "ranger", "explorer", "master-thief"]
var checks: int = 0
var failures: int = 0
var stage: Node3D
var camera: Camera3D

func _initialize() -> void:
	call_deferred("run")

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)

func axis(actor: Node3D, weapon: String = "Weapon_Cutlass") -> Vector3:
	var source: Vector3 = actor.LEFT_BLADE if weapon == "Weapon_Pistol" else actor.WEAPON_AXES.get(actor.id, Vector3.UP)
	return (actor.model.global_basis.inverse() * actor.joints[weapon].node.global_basis * source).normalized()

func run() -> void:
	stage = Node3D.new()
	root.add_child(stage)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("182330")
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color("e2e9ff")
	environment.environment.ambient_light_energy = 0.65
	stage.add_child(environment)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-28, -30, 0)
	key.light_energy = 1.4
	stage.add_child(key)
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 3.7
	stage.add_child(camera)
	camera.position = Vector3(0, 1.5, 7)
	camera.look_at(Vector3(0, 1.12, 0))
	camera.current = true
	var capture: bool = "--capture" in OS.get_cmdline_user_args()
	if capture:
		root.size = Vector2i(900, 900)
		DirAccess.make_dir_recursive_absolute("/tmp/rogue-pose-review")
	for id in IDS:
		var actor = Actor.new()
		stage.add_child(actor)
		actor.setup(id)
		actor.seed = 0
		actor.animate_pose({}, 0.016, 0, 0)
		if id == "pirate":
			check(axis(actor).y > 0.8, "Pirate keeps the cutlass high at rest")
		if id == "magic-swordsman":
			check(axis(actor).x < -0.7 and axis(actor).y < -0.2, "Claymore trails down to anatomical right")
		if id == "samurai":
			var bow: Node3D = actor.joints.Weapon_Pistol.node
			check(actor.joints.Body.node.to_local(bow.global_position).z < -0.3, "Samurai bow rests on back")
		if id == "ninja":
			check(axis(actor).z < -0.65 and axis(actor).x < -0.4, "Ninja reverse blade trails along the side")
		if id == "explorer":
			check(axis(actor).y < -0.5 and axis(actor, "Weapon_Pistol").y < -0.5, "Explorer carries both blades reversed")
		if capture:
			await snap(actor, id + "-idle-front")
			actor.rotation.y = -0.65
			await snap(actor, id + "-idle-side")
		actor.rotation.y = 0
		var moving := {"grounded": true, "motionSpeed": 10.2, "localMotion": Vector3(10.2, 0, 0)}
		for i in range(40):
			actor.animate_pose(moving, 1.0 / 60, i / 60.0, 1)
		if id == "pirate":
			check(axis(actor).y > 0.8, "Pirate keeps the cutlass high while running")
		if capture:
			await snap(actor, id + "-run")
		for index in range(3):
			for t in [0.0, 0.06, 0.12, 0.24, 0.48]:
				var attack := {"index": index, "style": "twin" if id == "explorer" else ("ninja" if id == "ninja" else "claymore"), "duration": 0.5, "contact": 0.12, "time": t}
				actor.animate_pose({"attack": attack}, 0.016, 1, 0)
				if id == "magic-swordsman":
					var right: Node3D = actor.joints.Arm_R.node
					var left: Node3D = actor.joints.Arm_L.node
					var weapon: Node3D = actor.joints.Weapon_Cutlass.node
					var grip: Vector3 = right.transform * weapon.position
					var direction: Vector3 = (right.basis * weapon.basis * actor.WEAPON_AXES[id]).normalized()
					check((left.transform * actor._hand_anchor("L")).distance_to(grip - direction * 0.19) < 0.002, "Claymore support palm remains on pommel through combo")
				if capture and t == 0.12 and id in ["magic-swordsman", "ninja", "explorer"]:
					await snap(actor, id + "-contact-" + str(index))
		if id == "samurai":
			actor.animate_pose(moving, 0.016, 1, 1)
			check(actor.joints.Body.node.to_local(actor.joints.Weapon_Pistol.node.global_position).z < -0.3, "Samurai keeps bow behind torso while running")
			actor.animate_pose({"shot": 0.2}, 0.016, 1, 0)
			check(actor.joints.Weapon_Pistol.node.position.is_equal_approx(actor.joints.Weapon_Pistol.position), "Samurai draws the bow only for a shot")
			if capture: await snap(actor, id + "-bow-shot")
		if id == "ranger":
			actor.animate_pose({"attack": {"style": "bow", "duration": 0.62, "contact": 0.11, "time": 0.11}}, 0.016, 1, 0)
			var arrow: Vector3 = (actor.model.global_basis.inverse() * actor.joints.Weapon_Cutlass.node.global_basis * Vector3.LEFT).normalized()
			check(arrow.z > 0.95, "Ranger arrow points forward at release")
			if capture: await snap(actor, id + "-bow-shot")
		if id == "explorer":
			actor.animate_pose({"attack": {"style": "evasive-slash", "duration": 0.3, "contact": 0.07, "time": 0.07, "index": 0, "swingSide": -1}}, 0.016, 1, 0)
			check(axis(actor, "Weapon_Pistol").z > 0.85 and axis(actor).y < -0.4, "Explorer fourth cut changes hand despite combo index wrapping")
		if id in ["explorer", "ninja"]:
			var style: String = "dash-cut" if id == "ninja" else "cross-slash"
			actor.animate_pose({"roll": 0.2, "rollDuration": 0.3, "rollStyle": style}, 0.016, 1, 0)
			if capture: await snap(actor, id + "-dash-cut")
		if id == "mage":
			actor.animate_pose({"chargeTime": 2.8}, 0.016, 1, 0)
			if capture: await snap(actor, id + "-charge")
		if id in ["knight", "master-thief"]:
			actor.animate_pose({"blocking": true, "guardTime": 1.0}, 0.016, 1, 0)
			if capture: await snap(actor, id + "-guard")
			if id == "master-thief":
				var entry: Dictionary = actor.materials[0]
				check(entry.material.emission_enabled and entry.material.emission.r > entry.material.emission.g * 3, "Thief guard sustains red glow after startup")
				actor.animate_pose({}, 0.016, 2, 0)
				check(entry.material.emission == entry.emission and entry.material.emission_enabled == entry.enabled, "Guard release restores painted material emission")
		actor.free()
	print("ROGUE_POSE_RESULT checks=", checks, " failures=", failures)
	quit(1 if failures else 0)

func snap(_actor: Node3D, label: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("/tmp/rogue-pose-review/" + label + ".png")
