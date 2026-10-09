extends SceneTree
## Deterministic, actual-engine art review for the two Rogue redesign pilots.
## godot --path . --script scripts/rogue_design_pilot_tour.gd -- --output <directory>
## --baseline reads backed-up GLBs directly, without importing ignored build files.

const Actor = preload("res://assets/rogue/scripts/actor.gd")
const HEROES = ["magic-swordsman", "explorer"]
const REQUIRED_JOINTS = ["Body", "Head", "Arm_L", "Arm_R", "Leg_L", "Leg_R", "Weapon_Cutlass"]
const VIEWS = {"front": Vector3(0, 0, 1), "side": Vector3(1, 0, 0), "three-quarter": Vector3(1, 0, 1), "back": Vector3(0, 0, -1)}

var stage: Node3D
var camera: Camera3D
var output_dir: String
var baseline: bool = false
var failures: int = 0
var captures: Array[Dictionary] = []
var reference_frames: Dictionary = {}

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var args := OS.get_cmdline_user_args()
	baseline = "--baseline" in args
	output_dir = ProjectSettings.globalize_path("res://build/rogue-design-pilot/" + ("runtime-before" if baseline else "runtime"))
	var output_index := args.find("--output")
	if output_index >= 0 and output_index + 1 < args.size():
		output_dir = ProjectSettings.globalize_path(args[output_index + 1])
	DirAccess.make_dir_recursive_absolute(output_dir)
	if not baseline:
		var reference_path := ProjectSettings.globalize_path("res://build/rogue-design-pilot/runtime-before/manifest.json")
		if FileAccess.file_exists(reference_path):
			var reference = JSON.parse_string(FileAccess.get_file_as_string(reference_path))
			if reference is Dictionary:
				for frame in reference.get("captures", []):
					reference_frames[frame.hero + "/" + frame.view] = frame
	if DisplayServer.get_name() == "headless":
		push_error("Pilot tour requires a rendered window; use --rendering-method gl_compatibility if necessary.")
		quit(1)
		return
	root.size = Vector2i(1000, 1000)
	root.content_scale_size = Vector2i.ZERO
	root.msaa_3d = Viewport.MSAA_4X
	_make_stage()
	for hero in HEROES:
		var actor = _make_actor(hero)
		if actor == null:
			continue
		actor.seed = 0.0
		actor.animate_pose({"grounded": true}, 1.0 / 60.0, 0.0, 0.0)
		var full_bounds := _world_bounds(actor.model)
		var full_center := full_bounds.get_center()
		# Keep all four body views at one scale so proportions remain comparable.
		var full_size := maxf(full_bounds.size.y, Vector2(full_bounds.size.x, full_bounds.size.z).length()) * 1.18
		for view in VIEWS:
			await _capture(hero, "idle-" + view, full_center, VIEWS[view], full_size)
		# The Explorer's braid extends to the waist. Frame the skull from its
		# authored neck joint rather than treating that long hair as the face.
		var head_center: Vector3 = actor.joints.Head.node.global_position + Vector3(0, 0.31, 0.025)
		var head_size: float = 1.25
		for view in ["front", "side", "three-quarter"]:
			await _capture(hero, "head-" + view, head_center, VIEWS[view], head_size)
		var moving := {"grounded": true, "motionSpeed": 10.2, "localMotion": Vector3(0, 0, 10.2)}
		for frame in range(40):
			actor.animate_pose(moving, 1.0 / 60.0, frame / 60.0, 1.0)
		await _capture(hero, "run-three-quarter", _world_bounds(actor.model).get_center(), VIEWS["three-quarter"], full_size)
		actor.reset_motion()
		for combo in range(2 if hero == "explorer" else 1):
			var attack := {"index": combo, "swingSide": 1 if combo == 0 else -1, "style": "evasive-slash" if hero == "explorer" else "claymore", "duration": 0.3 if hero == "explorer" else 0.72, "contact": 0.07 if hero == "explorer" else 0.21, "time": 0.07 if hero == "explorer" else 0.21}
			actor.animate_pose({"grounded": true, "attack": attack}, 1.0 / 60.0, 0.0, 0.0)
			var attack_bounds := _world_bounds(actor.model)
			var attack_size := maxf(full_size, maxf(attack_bounds.size.y, Vector2(attack_bounds.size.x, attack_bounds.size.z).length()) * 1.15)
			await _capture(hero, "attack-contact-" + str(combo + 1), attack_bounds.get_center(), VIEWS["three-quarter"], attack_size)
		actor.free()
	var manifest := {"baseline": baseline, "rendering_method": RenderingServer.get_current_rendering_method(), "resolution": [root.size.x, root.size.y], "native_model_depth_scale": 1.15, "failures": failures, "captures": captures}
	var file := FileAccess.open(output_dir.path_join("manifest.json"), FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(manifest, "\t"))
	else:
		failures += 1
	print("ROGUE_DESIGN_PILOT_TOUR_COMPLETE captures=", captures.size(), " failures=", failures, " output=", output_dir)
	quit(1 if failures else 0)

func _make_actor(hero: String):
	var actor := Actor.new()
	stage.add_child(actor)
	if baseline:
		var path := ProjectSettings.globalize_path("res://build/rogue-design-pilot/baseline/assets/rogue/styled/models/%s.glb" % hero)
		var document := GLTFDocument.new()
		var state := GLTFState.new()
		var error := document.append_from_file(path, state)
		if error != OK:
			push_error("Cannot read baseline model: %s (%s)" % [path, error])
			failures += 1
			actor.free()
			return null
		actor.id = hero
		actor.model = document.generate_scene(state)
		actor.model.scale.z *= 1.15
		actor.model.rotation_order = EULER_ORDER_XYZ
		actor.add_child(actor.model)
		actor._cache(actor.model)
	else:
		actor.setup(hero)
	var required := REQUIRED_JOINTS.duplicate()
	if hero == "explorer":
		required.append("Weapon_Pistol")
	for joint in required:
		if not actor.joints.has(joint):
			push_error("Missing joint %s in %s" % [joint, hero])
			failures += 1
			actor.free()
			return null
	return actor

func _make_stage() -> void:
	stage = Node3D.new()
	root.add_child(stage)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("d3d7dd")
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color("eef2ff")
	environment.environment.ambient_light_energy = 0.58
	environment.environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	stage.add_child(environment)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-35, -32, 0)
	key.light_color = Color("fff5e9")
	key.light_energy = 1.05
	key.shadow_enabled = true
	key.directional_shadow_max_distance = 16.0
	key.light_angular_distance = 2.0
	stage.add_child(key)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-20, 135, 0)
	fill.light_color = Color("dce7ff")
	fill.light_energy = 0.38
	stage.add_child(fill)
	var floor_mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(200, 200)
	floor_mesh.mesh = plane
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("cdd2d9")
	material.roughness = 1.0
	material.metallic_specular = 0.0
	floor_mesh.material_override = material
	floor_mesh.position.y = -0.025
	stage.add_child(floor_mesh)
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.near = 0.05
	camera.far = 50.0
	stage.add_child(camera)
	camera.current = true

func _world_bounds(node: Node3D) -> AABB:
	var boxes: Array[AABB] = []
	_collect_bounds(node, boxes)
	if boxes.is_empty():
		failures += 1
		push_error("No mesh bounds found under " + str(node.name))
		return AABB(Vector3.ZERO, Vector3.ONE)
	var result := boxes[0]
	for index in range(1, boxes.size()):
		result = result.merge(boxes[index])
	return result

func _collect_bounds(node: Node, boxes: Array[AABB]) -> void:
	if node is MeshInstance3D and node.visible and node.mesh != null:
		boxes.append(node.global_transform * node.get_aabb())
	for child in node.get_children():
		_collect_bounds(child, boxes)

func _capture(hero: String, label: String, focus: Vector3, direction: Vector3, size_: float) -> void:
	var reference_key := hero + "/" + label
	if reference_frames.has(reference_key):
		var frame: Dictionary = reference_frames[reference_key]
		size_ = frame.camera_size
		focus = Vector3(frame.focus[0], frame.focus[1], frame.focus[2])
		direction = Vector3(frame.direction[0], frame.direction[1], frame.direction[2])
	camera.size = size_
	camera.position = focus + direction.normalized() * 9.0
	camera.look_at(focus)
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var path := output_dir.path_join(hero + "-" + label + ".png")
	var image := root.get_texture().get_image()
	var error := image.save_png(path)
	if error != OK:
		failures += 1
		push_error("Cannot save pilot image: " + path)
	captures.append({"hero": hero, "view": label, "path": path, "camera_size": size_, "focus": [focus.x, focus.y, focus.z], "direction": [direction.x, direction.y, direction.z]})
	print("PILOT_CAPTURE ", path)
