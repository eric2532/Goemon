extends "res://scripts/rogue_roster_upgrade_tour.gd"
## Focused, rendered v2.36 evidence using the real picker, input and collision.
## Run with --rogue-equipment-upgrade-tour; optional --art-only/--combat-only.

const EQUIPMENT_HEROES = [5, 6, 1, 2]
const PREVIOUS_RANGER_INTERVAL = 0.62
var track_arrows: bool = false
var arrow_events: Array[Dictionary] = []
var arrow_ids: Dictionary = {}

func run():
	visual = true
	report_dir = "res://build/rogue-equipment-upgrade/tour" if OS.has_feature("editor") else "user://build/rogue-equipment-upgrade/tour"
	output_dir = report_dir.path_join("screenshots")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output_dir))
	if DisplayServer.get_name() == "headless":
		check(false, "Equipment tour requires a rendered window")
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
	check(game.is_fire_siege() and not game.rogue_battle_mode, "Equipment tour runs in the actual Fire Siege MVP")
	check(game.camera_rig.camera.projection == Camera3D.PROJECTION_PERSPECTIVE, "Equipment tour preserves the MVP perspective renderer")
	if not "--combat-only" in OS.get_cmdline_user_args():
		await equipment_portraits()
		await scarf_motion()
	if not "--art-only" in OS.get_cmdline_user_args():
		await dragoon_grounded_pulses()
		await dragoon_airborne_drop("heavy_attack", "rmb", true)
		await dragoon_airborne_drop("weapon_chain", "key-3", false)
		await ranger_arrows()
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
	print("ROGUE_EQUIPMENT_UPGRADE_TOUR_COMPLETE checks=", checks, " failures=", failures, " captures=", screenshots.size(), " output=", ProjectSettings.globalize_path(report_dir))
	await frames(18)
	get_tree().quit(1 if failures else 0)

func equipment_portraits():
	var geometry: Dictionary = {}
	for index in EQUIPMENT_HEROES:
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
		var head: Vector3 = actor.joints.Head.node.global_position + Vector3(0, 0.43, 0)
		for view in ["front", "profile", "three-quarter", "back"]:
			var direction: Vector3 = {"front": Vector3.FORWARD, "profile": Vector3.RIGHT, "three-quarter": Vector3(1, 0, -1).normalized(), "back": Vector3.BACK}[view]
			if view == "profile" and id == "dragoon":
				direction = Vector3.LEFT
			var focus: Vector3 = head
			var distance: float = 3.3
			if view == "three-quarter":
				focus -= Vector3.UP * 0.35
				distance = 4.8
			if view == "back":
				focus = game.player.position + Vector3.UP * 1.45
				distance = 5.8
			await fixed_camera(focus, direction * distance + Vector3.UP * 0.05, 40)
			await shot("%s-%s" % [id, view], "Actual in-game %s equipment, facial volume and preserved class silhouette from %s" % [id, view])
	measurements.model_geometry_sha256 = geometry
	check(geometry.size() == EQUIPMENT_HEROES.size() and not geometry.values().has(""), "All four revised heroes contain imported mesh geometry")

func scarf_motion():
	await prepare_hero(1)
	game.hud.hide()
	var actor = game.player.active_ability.visual_actor
	var tail = actor.model.find_child("ScarfTail_Geometry", true, false)
	check(tail is MeshInstance3D, "Samurai loads the long separate ScarfTail_Geometry mesh")
	if not tail is MeshInstance3D:
		return
	var pivot: Node3D = tail.get_parent()
	check(pivot.name == "ScarfTail" and pivot.get_parent().name == "Head", "Scarf tail remains attached to its authored head pivot")
	var samples: Array[Dictionary] = []
	await fixed_camera(game.player.position + Vector3(0, 1.7, 0.25), Vector3(3.4, 0.55, 3.8), 40)
	var idle_a: Vector3 = scarf_tip(tail)
	samples.append(scarf_sample("idle-a", tail))
	await shot("samurai-scarf-idle-a", "Long red scarf tail in the first live idle wind phase")
	await frames(19)
	var idle_b: Vector3 = scarf_tip(tail)
	samples.append(scarf_sample("idle-b", tail))
	await shot("samurai-scarf-idle-b", "Same camera with a later live idle wind phase")
	check(not idle_a.is_equal_approx(idle_b), "Samurai scarf deforms its mesh tip while idling")
	var start: Vector3 = game.player.position
	game.player.smoke_move = Vector2(0, -1)
	await frames(13)
	await fixed_camera(game.player.position + Vector3(0, 1.7, 0.25), Vector3(3.4, 0.55, 3.8), 40)
	var run_a: Vector3 = scarf_tip(tail)
	samples.append(scarf_sample("run-a", tail))
	await shot("samurai-scarf-run-a", "Samurai running with the long red tail trailing behind the shoulders")
	await frames(13)
	await fixed_camera(game.player.position + Vector3(0, 1.7, 0.25), Vector3(3.4, 0.55, 3.8), 40)
	var run_b: Vector3 = scarf_tip(tail)
	samples.append(scarf_sample("run-b", tail))
	await shot("samurai-scarf-run-b", "Second live run phase demonstrates continued scarf motion")
	game.player.smoke_move = Vector2.ZERO
	check(game.player.position.distance_to(start) > 1.0, "Scarf run captures use actual in-world hero movement")
	check(not run_a.is_equal_approx(run_b), "Samurai scarf deforms its mesh tip while running")
	measurements.samurai_scarf_motion = samples

func scarf_tip(tail: MeshInstance3D) -> Vector3:
	var tip: Vector3 = Vector3.ZERO
	for surface in range(tail.mesh.get_surface_count()):
		var vertices: PackedVector3Array = tail.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]
		for vertex in vertices:
			if vertex.z < tip.z:
				tip = vertex
	return tip

func scarf_sample(label: String, tail: MeshInstance3D) -> Dictionary:
	return {"label": label, "physics_frame": Engine.get_physics_frames(), "local_tip": vector_values(scarf_tip(tail)), "airflow": game.player.active_ability.visual_actor.scarf_wind.airflow, "hero_position": vector_values(game.player.position)}

func dragoon_grounded_pulses():
	await prepare_hero(5)
	game.hud.hide()
	var target = fixture(Vector3(2.4, 0, -7.5))
	var ground_y: float = game.player.position.y
	await fixed_camera(game.player.position + Vector3(0, 1.8, -4.0), Vector3(12, 6, 12), 48)
	tap("heavy_attack")
	var ability = game.player.active_ability
	check(ability.player.travel != null and ability.player.travel.get("phase", "") == "arc", "Grounded Dragoon RMB starts the forward jump arc")
	await frames(16)
	check(game.player.position.y > ground_y + 2.0 and target.hp == 10000, "Grounded Dragoon rises before dealing any landing damage")
	await shot("dragoon-grounded-jump-arc", "Grounded RMB carries the Dragoon through its forward jump before ground contact")
	var impacts: Array[Dictionary] = await observe_dragoon_damage(target, ground_y, "dragoon-grounded-blue-pulse", true)
	measurements.dragoon_grounded_pulses = impacts
	check(impacts.size() == 3 and is_equal_approx(10000 - target.hp, 192), "Grounded Dragoon landing deals exactly three separate 64-damage pulses")
	check(ability.player.travel == null and ability.player.pulses.is_empty(), "Grounded leap and its pulse queue finish cleanly")

func dragoon_airborne_drop(action: String, label: String, capture_impact: bool):
	await prepare_hero(5)
	game.hud.hide()
	var target = fixture(Vector3(2.4, 0, 0))
	var ground_y: float = game.player.position.y
	await fixed_camera(game.player.position + Vector3(0, 2.0, 0), Vector3(11, 3, 10), 47)
	tap("jump")
	await frames(16)
	var before: Vector3 = game.player.position
	check(not game.player.is_on_floor() and before.y > ground_y + 2, "Dragoon " + label + " fixture reaches a real airborne position")
	tap(action)
	var ability = game.player.active_ability
	check(ability.player.travel != null and ability.player.travel.get("phase", "") == "drop", "Airborne Dragoon " + label + " enters immediate downward travel")
	await frames(2)
	var dropping: Vector3 = game.player.position
	check(dropping.y < before.y - 0.5 and target.hp == 10000, "Airborne Dragoon " + label + " visibly descends while the ground target remains undamaged")
	check(Vector2(dropping.x - before.x, dropping.z - before.z).length() < 0.08, "Airborne Dragoon " + label + " drops vertically at its activation position")
	await shot("dragoon-airborne-" + label + "-descent", "Real airborne secondary input drives the body downward before the blue ground impact")
	var impacts: Array[Dictionary] = await observe_dragoon_damage(target, ground_y, "dragoon-airborne-" + label + "-impact", false, capture_impact)
	measurements["dragoon_airborne_" + label] = {"activation_position": vector_values(before), "descent_position": vector_values(dropping), "impacts": impacts}
	check(impacts.size() == 3 and is_equal_approx(10000 - target.hp, 192), "Airborne Dragoon " + label + " produces all three 64-damage ground pulses")
	check(ability.player.travel == null and ability.player.pulses.is_empty(), "Airborne Dragoon " + label + " clears descent and pulse state")

func observe_dragoon_damage(target: Ninja, ground_y: float, label: String, all_pulses: bool, first_pulse: bool = false) -> Array[Dictionary]:
	var impacts: Array[Dictionary] = []
	var previous_hp: float = target.hp
	var start_frame: int = Engine.get_physics_frames()
	for frame in range(130):
		await frames(1)
		if target.hp < previous_hp:
			var damage: float = previous_hp - target.hp
			var floor_distance: float = game.player.position.y - ground_y
			impacts.append({"frame_after_observation": Engine.get_physics_frames() - start_frame, "damage": damage, "height_above_starting_floor": floor_distance, "player_position": vector_values(game.player.position)})
			check(is_equal_approx(damage, 64) and floor_distance < 0.16, label + " %d occurs only at ground level and deals 64 damage" % impacts.size())
			previous_hp = target.hp
			if all_pulses or (first_pulse and impacts.size() == 1):
				await shot(label + ("-%d" % impacts.size() if all_pulses else ""), "Blue shockwave %d follows actual floor contact; live enemy has taken %d damage" % [impacts.size(), 10000 - target.hp])
		if impacts.size() == 3 and game.player.active_ability.player.pulses.is_empty():
			break
	return impacts

func record_projectiles():
	super.record_projectiles()
	if not track_arrows or not is_instance_valid(game.player.active_ability):
		return
	for projectile in game.player.active_ability.projectiles:
		if projectile.kind != "arrow" or not is_instance_valid(projectile.mesh):
			continue
		var key: int = projectile.mesh.get_instance_id()
		if arrow_ids.has(key):
			continue
		arrow_ids[key] = true
		arrow_events.append({"physics_frame": Engine.get_physics_frames(), "damage": projectile.damage, "speed": projectile.vel.length(), "visual_scale": projectile.get("visualScale", 1.0), "mesh_scale": vector_values(projectile.mesh.scale), "collision_width": projectile.width, "weapon": projectile.weapon})

func ranger_arrows():
	await prepare_hero(7)
	# Native world damage labels outlive the prior hero fixture.
	await frames(75)
	game.hud.hide()
	await fixed_camera(game.player.position + Vector3(0, 1.2, -3), Vector3(7.8, 2.6, 5.0), 45)
	arrow_events.clear()
	arrow_ids.clear()
	track_arrows = true
	press("light_attack")
	await frames(4)
	await shot("ranger-double-size-primary-arrow", "The Ranger releases a visibly enlarged primary arrow from the native bow")
	await frames(76)
	press("light_attack", false)
	track_arrows = false
	var intervals: Array[float] = []
	for index in range(1, arrow_events.size()):
		intervals.append(float(arrow_events[index].physics_frame - arrow_events[index - 1].physics_frame) / Engine.physics_ticks_per_second)
	var mean_interval: float = 0.0
	for interval in intervals:
		mean_interval += interval
	mean_interval /= maxi(1, intervals.size())
	var ratio: float = PREVIOUS_RANGER_INTERVAL / maxf(0.001, mean_interval)
	check(arrow_events.size() >= 5 and ratio > 2.65 and ratio < 3.3, "Held Ranger primary delivers approximately three times the previous fire cadence")
	check(not arrow_events.is_empty() and arrow_events.all(func(event): return is_equal_approx(float(event.visual_scale), 2.0) and is_equal_approx(float(event.mesh_scale[0]), 2.0) and is_equal_approx(float(event.collision_width), 0.25)), "Every sampled primary arrow has doubled visible scale and its original collision width")
	check(not arrow_events.is_empty() and arrow_events.all(func(event): return is_equal_approx(float(event.speed), 36.0)), "Ranger primary preserves its 36-unit arrow flight speed")
	measurements.ranger_primary = {"previous_interval_seconds": PREVIOUS_RANGER_INTERVAL, "mean_interval_seconds": mean_interval, "measured_cadence_multiplier": ratio, "projectiles": arrow_events.duplicate(true)}
	await prepare_hero(7)
	game.hud.hide()
	await fixed_camera(game.player.position + Vector3(0, 1.1, -6), Vector3(10, 4, 5), 49)
	arrow_events.clear()
	arrow_ids.clear()
	track_arrows = true
	tap("heavy_attack")
	await frames(23)
	await shot("ranger-double-size-four-arrow-barrage", "The complete four-arrow Ranger barrage uses enlarged visible arrows in the world")
	await frames(6)
	track_arrows = false
	check(arrow_events.size() == 4 and arrow_events.all(func(event): return is_equal_approx(float(event.visual_scale), 2.0) and is_equal_approx(float(event.mesh_scale[0]), 2.0)), "Ranger secondary retains four arrows and doubles every arrow's visible scale")
	check(not arrow_events.is_empty() and arrow_events.all(func(event): return is_equal_approx(float(event.speed), 34.0)), "Ranger barrage preserves its 34-unit arrow flight speed")
	measurements.ranger_secondary = {"projectiles": arrow_events.duplicate(true)}

func vector_values(value: Vector3) -> Array:
	return [value.x, value.y, value.z]

func write_report():
	var manifest = {"suite": "rogue-equipment-upgrade-v236", "checks": checks, "failures": failures, "rendering_method": RenderingServer.get_current_rendering_method(), "physics_ticks_per_second": Engine.physics_ticks_per_second, "measurements": measurements, "observations": observations, "screenshots": screenshots}
	var file = FileAccess.open(report_dir.path_join("verification-manifest.json"), FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(manifest, "\t"))
	var lines: Array[String] = ["# Rogue equipment upgrade — rendered verification", "", "Result: **%d checks, %d failures, %d captures**." % [checks, failures, screenshots.size()], "", "Uses the live Fire Siege hero picker, native GLBs, real action input, player collision and live enemy damage. Directors and fixture AI are paused for repeatability; cameras and HUD visibility are adjusted for readable evidence.", "", "## Checks", ""]
	for result in observations:
		if not result.message.begins_with("Saved rendered capture"):
			lines.append("- [%s] %s" % ["x" if result.passed else " ", result.message])
	lines.append_array(["", "## Measurements", "", "```json", JSON.stringify(measurements, "\t"), "```", "", "## Captures", "", "Review the front/profile/three-quarter/back views for equipment, face coverage and volume; compare both idle and run scarf pairs. Geometry assertions supplement visual review.", ""])
	for screenshot in screenshots:
		lines.append("- [%s](%s) — %s" % [screenshot.label, screenshot.file, screenshot.purpose])
	lines.append_array(["", "## Reproduce", "", "Run `godot --fixed-fps 60 --max-fps 120 --path . -- --rogue-equipment-upgrade-tour` after asset imports finish. A full run produces the complete evidence; `--art-only` or `--combat-only` narrows a diagnostic rerun. Packaged output uses `user://build/rogue-equipment-upgrade/tour`.", ""])
	file = FileAccess.open(report_dir.path_join("verification-report.md"), FileAccess.WRITE)
	if file:
		file.store_string("\n".join(lines))
