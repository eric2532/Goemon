extends SceneTree

var failures: Array[String] = []
var results: Array = []

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

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var dir := "/workspace/scratch/23f1a29e8f92/construction_fx_v1/exports/"
	var entries := [
		["FS_FX_Hammer_BuildLoop.glb", "FX_HammerRoot", "Build_HammerLoop", 16],
		["FS_FX_ProgressFrame.glb", "FX_ProgressRoot", "", 6],
		["FS_FX_BPrompt.glb", "FX_BPromptRoot", "", 3],
		["FS_FX_CompletionPulse.glb", "FX_CompletionRoot", "Complete_GoldPulse", 12]
	]
	for entry in entries:
		var document := GLTFDocument.new()
		var state := GLTFState.new()
		var error := document.append_from_file(dir + entry[0], state)
		require(error == OK, entry[0] + " parsing failed")
		if error != OK:
			continue
		var model := document.generate_scene(state)
		require(model != null, entry[0] + " scene generation failed")
		if model == null:
			continue
		get_root().add_child(model)
		var meshes := walk(model, "MeshInstance3D")
		require(meshes.size() == entry[3], entry[0] + " mesh count mismatch")
		var animators := walk(model, "AnimationPlayer")
		var animation_names: Array = []
		var track_names: Array = []
		for animator in animators:
			for animation_name in animator.get_animation_list():
				animation_names.append(animation_name)
				var animation: Animation = animator.get_animation(animation_name)
				for track in range(animation.get_track_count()):
					track_names.append(str(animation.track_get_path(track)))
				if animation_name == entry[2]:
					require(abs(animation.length - 1.0) < 0.01, entry[0] + " incorrect clip length")
		if entry[2] != "":
			require(animation_names.has(entry[2]), entry[0] + " missing animation: " + entry[2])
		var shape_count := 0
		for mesh in meshes:
			shape_count += mesh.get_blend_shape_count()
		if entry[0].contains("Completion"):
			require(shape_count == 2, "Completion ring blend shapes missing")
			var blend_tracks := 0
			for track in track_names:
				if track.ends_with(":ThinToZero"):
					blend_tracks += 1
			require(blend_tracks == 2, "Completion ring animation tracks missing")
		if entry[0].contains("Progress"):
			var fill := model.find_child("ProgressFill", true, false) as MeshInstance3D
			require(fill != null, "ProgressFill missing")
			if fill != null:
				require(abs(fill.mesh.get_aabb().position.x) < 0.001, "Progress left anchor shifted")
		var playback_samples: Array = []
		if entry[2] != "" and not animators.is_empty():
			var player: AnimationPlayer = animators[0]
			player.play(entry[2])
			for time in ([0.0, 0.5, 1.0] if entry[0].contains("Hammer") else [0.0, 0.25, 1.0]):
				player.seek(time, true)
				if entry[0].contains("Hammer"):
					var pivot := model.find_child("FX_HammerSwingPivot", true, false) as Node3D
					playback_samples.append({"time":time,"rotation_z":pivot.rotation.z})
				if entry[0].contains("Completion"):
					var ring := model.find_child("Completion_OuterRing", true, false) as MeshInstance3D
					var spark := model.find_child("Completion_Spark_01", true, false) as Node3D
					playback_samples.append({"time":time,"ring_weight":ring.get_blend_shape_value(0),"spark_scale_x":spark.scale.x})
			if entry[0].contains("Hammer"):
				require(abs(playback_samples[0]["rotation_z"] - playback_samples[1]["rotation_z"]) > 0.01, "Hammer playback did not move")
				require(abs(playback_samples[0]["rotation_z"] - playback_samples[2]["rotation_z"]) < 0.001, "Hammer loop seam mismatch")
			if entry[0].contains("Completion"):
				require(playback_samples[0]["ring_weight"] > 0.99, "Pulse start ring visible")
				require(playback_samples[1]["ring_weight"] < 0.01, "Pulse midpoint ring missing")
				require(playback_samples[2]["ring_weight"] > 0.99, "Pulse end ring visible")
				require(playback_samples[1]["spark_scale_x"] > 0.03, "Pulse spark playback failed")
		results.append({"playback_samples":playback_samples,"file":entry[0],"meshes":meshes.size(),"animations":animation_names,"animation_tracks":track_names,"blend_shapes":shape_count})
		model.queue_free()
	var report := {"engine":Engine.get_version_info(),"status":"PASS" if failures.is_empty() else "FAIL","failures":failures,"checks":results}
	var out := FileAccess.open("/workspace/scratch/23f1a29e8f92/construction_fx_v1/qa/godot_import_report.json", FileAccess.WRITE)
	out.store_string(JSON.stringify(report, "  "))
	print(JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)
