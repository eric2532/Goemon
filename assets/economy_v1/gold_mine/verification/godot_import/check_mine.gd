extends SceneTree

var failures: Array[String] = []
var results: Dictionary = {}

func require(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error(message)

func walk(node: Node, kind: String) -> Array:
	var output: Array = []
	if node.is_class(kind):
		output.append(node)
	for child in node.get_children():
		output.append_array(walk(child, kind))
	return output

func vector(value: Vector3) -> Array:
	return [value.x, value.y, value.z]

func stage(model: Node, name: String) -> Node3D:
	var found := model.find_child(name, true, false) as Node3D
	require(found != null, "Missing named node: " + name)
	return found

func pose_snapshot(model: Node) -> Dictionary:
	var output: Dictionary = {}
	for name in ["01_UNBUILT_MARKERS_Root", "02_BUILD_FOUNDATION_Root", "03_BUILD_POSTS_Root", "04_BUILD_LINTEL_Root", "05_BUILD_DETAILS_Root", "06_TEMP_CONSTRUCTION_Root", "07_WORKING_CART_Root", "08_WORKING_PICK_Root", "09_OPTIONAL_REINFORCEMENT_Root"]:
		var node := stage(model, name)
		if node != null:
			output[name] = {"scale":vector(node.scale), "position":vector(node.position), "rotation":vector(node.rotation)}
	return output

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var asset := ProjectSettings.globalize_path("res://").path_join("../../goldmine_v1.glb").simplify_path()
	if not args.is_empty() and not args[0].begins_with("--"):
		asset = args[0]
	results["asset_sha256"] = FileAccess.get_sha256(asset)
	var model: Node = null
	if args.has("--packed"):
		var packed: PackedScene = load("res://mine_under_test.glb")
		model = packed.instantiate()
		results["import_route"] = "Godot editor PackedScene, animation/remove_immutable_tracks=false, nodes/use_name_suffixes=false"
	else:
		var document := GLTFDocument.new()
		var state := GLTFState.new()
		var error := document.append_from_file(asset, state)
		require(error == OK, "GLB parse failed")
		if error != OK:
			finish()
			return
		model = document.generate_scene(state, 30.0, false, false)
		results["import_route"] = "GLTFDocument.generate_scene(state, 30.0, false, false)"
	require(model != null, "GLB scene generation failed")
	if model == null:
		finish()
		return
	get_root().add_child(model)
	var meshes := walk(model, "MeshInstance3D")
	require(meshes.size() == 248, "Expected 248 mesh instances")
	var triangles := 0
	var material_names: Dictionary = {}
	var material_holes: Array = []
	for mesh in meshes:
		for surface in range(mesh.mesh.get_surface_count()):
			var arrays: Array = mesh.mesh.surface_get_arrays(surface)
			if arrays[Mesh.ARRAY_INDEX] != null and arrays[Mesh.ARRAY_INDEX].size() > 0:
				triangles += arrays[Mesh.ARRAY_INDEX].size() / 3
			else:
				triangles += arrays[Mesh.ARRAY_VERTEX].size() / 3
			var material: Material = mesh.get_active_material(surface)
			if material == null:
				material_holes.append(str(mesh.name))
			else:
				material_names[material.resource_name] = true
	require(triangles == 9404, "Expected 9,404 triangles")
	require(material_holes.is_empty(), "Missing imported surface material")
	require(material_names.size() == 18, "Expected 18 distinct named materials")
	results["geometry"] = {"meshes":meshes.size(), "triangles":triangles, "materials":material_names.keys(), "missing_materials":material_holes}
	var sockets := {"socket_build_fx":Vector3(0,3.2,0), "socket_income_fx":Vector3(0,2.4,1.3), "socket_entrance":Vector3(0,0,1.25)}
	var actual_sockets: Dictionary = {}
	for name in sockets:
		var socket := stage(model, name)
		if socket != null:
			require(socket.global_position.distance_to(sockets[name]) < 0.001, "Incorrect Godot-axis socket: " + name)
			actual_sockets[name] = vector(socket.global_position)
	results["sockets_godot_coordinates"] = actual_sockets
	var animators := walk(model, "AnimationPlayer")
	require(animators.size() == 1, "Expected one AnimationPlayer")
	if animators.is_empty():
		finish()
		return
	var player: AnimationPlayer = animators[0]
	var names := player.get_animation_list()
	var durations: Dictionary = {}
	for name in ["build", "reverse_build", "work_loop", "upgrade_preview"]:
		require(names.has(name), "Missing clip: " + name)
		if names.has(name):
			var clip: Animation = player.get_animation(name)
			durations[name] = clip.length
			require(abs(clip.length - (4.0 if name == "work_loop" else 2.0)) < 0.001, "Incorrect animation length: " + name)
	results["clip_durations_seconds"] = durations
	if not failures.is_empty():
		finish()
		return
	player.play("build")
	var samples: Array = []
	for time in [0.0, 1.0, 2.0]:
		player.seek(time, true)
		samples.append({"time":time, "nodes":pose_snapshot(model)})
	results["build_samples"] = samples
	require(abs(samples[2]["nodes"]["07_WORKING_CART_Root"]["position"][2] - 1.56) < 0.001, "Build-end cart translation does not match working pose")
	var start: Dictionary = samples[0]["nodes"]
	var middle: Dictionary = samples[1]["nodes"]
	var end: Dictionary = samples[2]["nodes"]
	require(start["01_UNBUILT_MARKERS_Root"]["scale"][0] > 0.99, "Unbuilt stakes absent at build 0")
	for name in ["02_BUILD_FOUNDATION_Root", "03_BUILD_POSTS_Root", "04_BUILD_LINTEL_Root", "05_BUILD_DETAILS_Root", "06_TEMP_CONSTRUCTION_Root", "07_WORKING_CART_Root", "08_WORKING_PICK_Root", "09_OPTIONAL_REINFORCEMENT_Root"]:
		require(abs(start[name]["scale"][0]) < 0.001, "Built geometry visible at build 0: " + name)
	require(middle["02_BUILD_FOUNDATION_Root"]["scale"][0] > 0.99, "Mid-build foundation missing")
	require(middle["06_TEMP_CONSTRUCTION_Root"]["scale"][0] > 0.99, "Mid-build scaffold missing")
	require(middle["03_BUILD_POSTS_Root"]["scale"][0] > 0.5, "Mid-build posts missing")
	require(abs(middle["07_WORKING_CART_Root"]["scale"][0]) < 0.001, "Cart appeared before completed build")
	for name in ["02_BUILD_FOUNDATION_Root", "03_BUILD_POSTS_Root", "04_BUILD_LINTEL_Root", "05_BUILD_DETAILS_Root", "07_WORKING_CART_Root", "08_WORKING_PICK_Root"]:
		require(end[name]["scale"][0] > 0.99, "Completed geometry missing: " + name)
	for name in ["01_UNBUILT_MARKERS_Root", "06_TEMP_CONSTRUCTION_Root", "09_OPTIONAL_REINFORCEMENT_Root"]:
		require(abs(end[name]["scale"][0]) < 0.001, "Unexpected completed-stage geometry: " + name)
	# Seek partial construction forward/backward without switching to a full-reversal clip.
	player.seek(1.35, true)
	var forward := pose_snapshot(model)
	player.seek(0.65, true)
	player.seek(1.35, true)
	var repeat := pose_snapshot(model)
	require(forward == repeat, "Repeated seek did not restore identical partial build")
	results["partial_seek_reversible"] = forward == repeat
	# Full reverse endpoints must match the opposite build endpoints.
	player.play("reverse_build")
	player.seek(0.0, true)
	var reverse_start := pose_snapshot(model)
	player.seek(2.0, true)
	var reverse_end := pose_snapshot(model)
	require(reverse_start == end and reverse_end == start, "Full reverse endpoints differ from build endpoints")
	results["reverse_endpoints_match"] = reverse_start == end and reverse_end == start
	player.play("work_loop")
	var work: Array = []
	for time in [0.0, 1.0, 2.0, 3.0, 4.0]:
		player.seek(time, true)
		var cart := stage(model, "07_WORKING_CART_Root")
		var pick := stage(model, "08_WORKING_PICK_Root")
		work.append({"time":time, "cart_position":vector(cart.position), "pick_rotation":vector(pick.rotation), "cart_scale":vector(cart.scale)})
	results["work_loop_samples"] = work
	require(abs(work[0]["cart_position"][2] - work[2]["cart_position"][2]) > 0.4, "Working cart did not move along the Godot Z axis")
	require(work[0]["cart_position"] == work[4]["cart_position"], "Working cart loop seam differs")
	player.seek(0.5,true)
	var pick_peak := stage(model,"08_WORKING_PICK_Root").rotation
	player.seek(0.0,true)
	var pick_start := stage(model,"08_WORKING_PICK_Root").rotation
	require(pick_peak.distance_to(pick_start) > 0.2, "Working pick swing is static")
	results["pick_swing_radians"] = pick_peak.distance_to(pick_start)
	results["imported_work_loop_mode"] = player.get_animation("work_loop").loop_mode
	player.get_animation("work_loop").loop_mode = Animation.LOOP_LINEAR
	require(player.get_animation("work_loop").loop_mode == Animation.LOOP_LINEAR, "Could not enable looping on working clip")
	results["explicit_loop_mode_verified"] = true
	model.queue_free()
	finish()

func finish() -> void:
	var report := {"engine":Engine.get_version_info(), "status":"PASS" if failures.is_empty() else "FAIL", "failures":failures, "checks":results, "scope":"Isolated source-asset import and animation playback only; no game project edited"}
	var report_name := "godot_editor_playback_report.json" if OS.get_cmdline_user_args().has("--packed") else "godot_import_report.json"
	var report_path := ProjectSettings.globalize_path("res://").path_join("../").path_join(report_name).simplify_path()
	var out := FileAccess.open(report_path, FileAccess.WRITE)
	out.store_string(JSON.stringify(report,"  "))
	print(JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)
