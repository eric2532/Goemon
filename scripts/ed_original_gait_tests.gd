extends SceneTree
## Compare playable ground movement against the untouched original ROM clip.
const ORIGINAL = "Ed_source_01__8019426c"
var checks = 0
var failures = 0

func _initialize(): run.call_deferred()

func check(ok: bool, label_: String):
	checks += 1
	if not ok: failures += 1
	print("PASS: " if ok else "FAIL: ", label_)

func pose_error(actual: Skeleton3D, expected: Skeleton3D) -> float:
	var error = 0.0
	for bone in actual.get_bone_count():
		var a = actual.get_bone_global_pose(bone)
		var b = expected.get_bone_global_pose(bone)
		error = maxf(error, a.origin.distance_to(b.origin))
		for axis in 3: error = maxf(error, a.basis[axis].distance_to(b.basis[axis]))
	return error

func run():
	var ed = load("res://scripts/recovered_ed_model.gd").new()
	root.add_child(ed)
	var raw = load("res://assets/characters/recovered_leaders/ed/model.glb").instantiate()
	root.add_child(raw)
	var reference: AnimationPlayer = raw.find_child("AnimationPlayer", true, false)
	var skeleton: Skeleton3D = raw.find_child("Skeleton3D", true, false)
	reference.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	check(reference.has_animation(ORIGINAL), "The original recovered Ed ground cycle is available")
	var duration = reference.get_animation(ORIGINAL).length
	check(is_equal_approx(duration, 16.0 / 30.0), "Original movement retains the ROM's sixteen 30 Hz poses")
	for entry in [[2.2, false], [7.0, false], [12.0, false], [7.0, true]]:
		ed.was_grounded = true
		ed.was_moving = false
		ed.landing_clock = -1
		ed.animate(0.1, entry[0], true, 0, 0, false, 0, entry[1])
		check(ed.current_clip == ORIGINAL, "Movement at speed %s / dodge %s selects Ed's original cycle" % entry)
		var worst = 0.0
		for frame in 32:
			ed.animate(1.0 / 30.0, entry[0], true, 0, 0, false, 0, entry[1])
			reference.play(ORIGINAL)
			reference.seek(ed.gait_phase * duration, true)
			skeleton.force_update_all_bone_transforms()
			worst = maxf(worst, pose_error(ed.skeleton, skeleton))
		check(worst < 0.0001, "Moving body matches untouched ROM poses at speed %s / dodge %s (error %.6f)" % [entry[0], entry[1], worst])
		check(ed.position == Vector3.ZERO and ed.body.transform == Transform3D.IDENTITY, "Animation leaves movement to the player controller")
	for key in ["source_00", "source_06", "source_03", "source_04", "source_05", "JumpRise", "JumpAir", "JumpFall", "Land"]:
		ed._sample(ed.motion("Run"), 0.2, 0.1, true)
		var clip = ed.motion(key)
		ed._sample(clip, 0.2, 0.1)
		reference.play(clip)
		reference.seek(0.2, true)
		skeleton.force_update_all_bone_transforms()
		check(pose_error(ed.skeleton, skeleton) < 0.0001, "Leaving movement preserves the existing %s pose" % key)
	ed.queue_free()
	raw.queue_free()
	await process_frame
	print("ED_ORIGINAL_GAIT_RESULT checks=", checks, " failures=", failures)
	quit(1 if failures else 0)
