extends "res://scripts/rogue_equipment_upgrade_tour.gd"
## Fresh v2.37 art evidence in the live Fire Siege MVP.
## Run --rogue-mask-refinement-tour after model imports finish.

const REFINEMENT_HEROES = [1, 5, 6]

func run():
	visual = true
	checks = 0
	failures = 0
	observations.clear()
	screenshots.clear()
	measurements.clear()
	report_dir = "res://build/rogue-mask-refinement/tour" if OS.has_feature("editor") else "user://build/rogue-mask-refinement/tour"
	output_dir = report_dir.path_join("screenshots")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output_dir))
	if DisplayServer.get_name() == "headless":
		check(false, "Mask refinement tour requires a rendered window")
		write_report()
		get_tree().quit(1)
		return
	get_tree().root.size = Vector2i(1440, 900)
	Input.use_accumulated_input = false
	game.smoke_test = true
	game.tuning = PrototypeTuning.DEFAULTS.duplicate()
	game.tuning.invincible = true
	game.tuning.freeze_ai = true
	game.player.smoke_mode = true
	game.start_mode("defense")
	pause_fixture_director()
	await frames(5)
	check(game.is_fire_siege() and not game.rogue_battle_mode, "Mask refinement tour runs in the actual Fire Siege MVP")
	check(game.camera_rig.camera.projection == Camera3D.PROJECTION_PERSPECTIVE, "Mask refinement tour uses the MVP perspective renderer")
	await refined_hero_views()
	await scarf_motion()
	await samurai_action_fit()
	release_all()
	game.hud.show()
	game.camera_rig.set_process(true)
	game.player.active_ability.reset_run()
	game.show_main_menu()
	game.sound_library.cancel()
	game.music.stop()
	await frames(3)
	stop_audio(game)
	var shared_audio = game.get_node_or_null("RogueSharedClassAudio")
	if is_instance_valid(shared_audio):
		shared_audio.cache.clear()
	write_report()
	print("ROGUE_MASK_REFINEMENT_TOUR_COMPLETE checks=", checks, " failures=", failures, " captures=", screenshots.size(), " output=", ProjectSettings.globalize_path(report_dir))
	await frames(18)
	get_tree().quit(1 if failures else 0)

func refined_hero_views():
	var geometry: Dictionary = {}
	var proportions: Dictionary = {}
	for index in REFINEMENT_HEROES:
		await prepare_hero(index)
		game.hud.hide()
		var id: String = CLASS_IDS[index]
		var actor = game.player.active_ability.visual_actor
		var intact: bool = is_instance_valid(actor) and is_instance_valid(actor.model)
		for joint in REQUIRED_JOINTS:
			intact = intact and actor.joints.has(joint)
		check(intact, id + " retains its native body, head, limb and weapon joints")
		if not intact:
			continue
		check(actor.model.scene_file_path == "res://assets/rogue/styled/models/%s.glb" % id, id + " displays the shipped styled GLB")
		geometry[id] = model_geometry_hash(actor.model)
		proportions[id] = {
			"head_pivot_in_body": vector_values(actor.joints.Body.node.to_local(actor.joints.Head.node.global_position)),
			"head_rest_position": vector_values(actor.joints.Head.position),
			"head_geometry_bounds": node_mesh_bounds(actor.joints.Head.node),
			"model_scale": vector_values(actor.model.scale),
		}
		if id == "samurai":
			check(absf(actor.joints.Head.position.y - 0.472) < 0.001, "Samurai authored head sits 0.13 units lower relative to the unchanged torso")
		var head: Vector3 = actor.joints.Head.node.global_position + Vector3(0, 0.35, 0)
		for view in ["front", "profile", "three-quarter", "back"]:
			var direction: Vector3 = {"front": Vector3.FORWARD, "profile": Vector3.RIGHT, "three-quarter": Vector3(1, 0, -1).normalized(), "back": Vector3.BACK}[view]
			if view == "profile" and id == "dragoon":
				direction = Vector3.LEFT
			await fixed_camera(head, direction * 3.25 + Vector3.UP * 0.05, 40)
			await shot(id + "-head-" + view, "Inspect compact neck and fitted scarf" if id == "samurai" else "Inspect closed face coverage, narrow eye openings and helmet depth from " + view)
		await fixed_camera(game.player.position + Vector3.UP * 1.45, Vector3(4.0, 1.0, -6.0), 43)
		await shot(id + "-full-idle", "Full native idle silhouette, head-to-torso proportion and equipment clearance")
		var start: Vector3 = game.player.position
		game.player.smoke_move = Vector2(0, -1)
		await frames(21)
		await fixed_camera(game.player.position + Vector3.UP * 1.45, Vector3(4.0, 1.0, -6.0), 43)
		await shot(id + "-full-run", "Full native run pose with actual movement, mask stability and torso clearance")
		game.player.smoke_move = Vector2.ZERO
		check(game.player.position.distance_to(start) > 1.0, id + " run capture uses actual in-world movement")
	measurements.model_geometry_sha256 = geometry
	measurements.proportions = proportions
	check(geometry.size() == REFINEMENT_HEROES.size() and not geometry.values().has(""), "All three refined heroes contain imported mesh geometry")

func node_mesh_bounds(root: Node3D) -> Dictionary:
	var result: Dictionary = {}
	for child in root.find_children("*", "MeshInstance3D", true, false):
		var mesh_node: MeshInstance3D = child
		var bounds: AABB = mesh_node.get_aabb()
		var minimum: Vector3 = Vector3(INF, INF, INF)
		var maximum: Vector3 = Vector3(-INF, -INF, -INF)
		for corner in range(8):
			var point: Vector3 = root.to_local(mesh_node.to_global(bounds.get_endpoint(corner)))
			minimum = minimum.min(point)
			maximum = maximum.max(point)
		result[mesh_node.name] = {"minimum": vector_values(minimum), "maximum": vector_values(maximum)}
	return result

func samurai_action_fit():
	await prepare_hero(1)
	game.hud.hide()
	var actor = game.player.active_ability.visual_actor
	await fixed_camera(game.player.position + Vector3(0, 1.5, 0), Vector3(4.3, 1.0, -5.3), 43)
	tap("light_attack")
	await frames(8)
	check(game.player.active_ability.player.attack != null, "Samurai primary fit capture occurs during its native sword attack")
	await shot("samurai-primary-sword-fit", "Native sword pose: inspect compact head, scarf root, shoulders and back bow clearance")
	await wait_recovery()
	await fixed_camera(game.player.position + Vector3(0, 1.5, 0), Vector3(3.5, 0.7, 4.7), 42)
	tap("heavy_attack")
	await frames(8)
	check(game.player.active_ability.player.attack != null, "Samurai secondary fit capture occurs during its native power slash")
	await shot("samurai-power-slash-back-fit", "Native secondary before contact from behind: inspect scarf tail and stored bow clearance")
	await fixed_camera(game.player.position + Vector3(0, 1.5, -0.3), Vector3(4.3, 1.0, -5.3), 43)
	for frame in range(20):
		var attack = game.player.active_ability.player.attack
		if attack == null or attack.time >= attack.contact:
			break
		await frames(1)
	var contact_attack = game.player.active_ability.player.attack
	check(contact_attack != null and contact_attack.time >= contact_attack.contact and contact_attack.time < contact_attack.contact + 0.07, "Samurai front fit capture reaches the actual power-slash contact pose")
	if contact_attack != null:
		measurements.samurai_contact_pose = {"time": contact_attack.time, "contact": contact_attack.contact, "duration": contact_attack.duration}
	await shot("samurai-power-slash-front-fit", "Native secondary slash: inspect head, scarf and torso overlap at contact")
	await wait_recovery()
	tap("equip")
	await frames(5)
	await fixed_camera(game.player.position + Vector3(0, 1.6, 0), Vector3(4.0, 0.8, -4.7), 42)
	check(game.player.active_ability.player.shot > 0, "Samurai bow fit capture occurs during its native utility shot")
	await shot("samurai-bow-drawn-fit", "Native drawn bow: inspect hands, bow, compact neck, scarf and head clearance")
	measurements.samurai_action_fit = {
		"bow_position": vector_values(actor.joints.Weapon_Pistol.node.position),
		"head_position": vector_values(actor.joints.Head.node.position),
		"scarf_tail_present": actor.model.find_child("ScarfTail_Geometry", true, false) != null,
	}

func write_report():
	var manifest = {"suite": "rogue-mask-refinement-v237", "checks": checks, "failures": failures, "rendering_method": RenderingServer.get_current_rendering_method(), "physics_ticks_per_second": Engine.physics_ticks_per_second, "measurements": measurements, "observations": observations, "screenshots": screenshots}
	var file = FileAccess.open(report_dir.path_join("verification-manifest.json"), FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(manifest, "\t"))
	var lines: Array[String] = ["# Rogue mask refinement — rendered verification", "", "Fresh result: **%d checks, %d failures, %d captures**." % [checks, failures, screenshots.size()], "", "This run independently captures the three v2.37 corrections in the actual Fire Siege MVP. Counts are generated from this invocation and do not reuse the v2.36 equipment/combat result.", "", "Native hero selection, joints, imported geometry, real movement, scarf deformation and action poses are checked automatically. Face coverage and clipping require review of the rendered captures; automated structure checks do not prove visual fit.", "", "## Checks", ""]
	for result in observations:
		if not result.message.begins_with("Saved rendered capture"):
			lines.append("- [%s] %s" % ["x" if result.passed else " ", result.message])
	lines.append_array(["", "## Measurements", "", "```json", JSON.stringify(measurements, "\t"), "```", "", "## Captures", "", "Review Samurai's compact head/neck and mouth wrap from each direction. Compare both live scarf wind phases and the sword/bow poses for head, torso, shoulder and bow clipping. Dragoon and Magic Swordsman should cover the painted face except narrow eye openings, with closed cheek and jaw profiles.", ""])
	for screenshot in screenshots:
		lines.append("- [%s](%s) — %s" % [screenshot.label, screenshot.file, screenshot.purpose])
	lines.append_array(["", "## Reproduce", "", "Run `godot --fixed-fps 60 --max-fps 120 --path . -- --rogue-mask-refinement-tour` after asset imports finish. Packaged output uses `user://build/rogue-mask-refinement/tour`.", ""])
	file = FileAccess.open(report_dir.path_join("verification-report.md"), FileAccess.WRITE)
	if file:
		file.store_string("\n".join(lines))
