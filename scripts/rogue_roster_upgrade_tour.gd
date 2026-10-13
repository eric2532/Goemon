extends "res://scripts/fire_siege_controls_tests.gd"
## Actual Fire Siege models, selector, input, collision, HUD and rendered effects.
## Main-game flag: --rogue-roster-upgrade-tour [--abilities-only | --roster-only | --hero=ID]
## Images and a machine-readable manifest accompany the verification report.

const TOUR_ORIGIN = Vector3(0, 0.1, 205)
const PREVIOUS_PRIMARY_REACH = [2.85, 3.3, 2.45, 28.0, 4.8, 6.2, 3.5, 20.0, 2.65, 4.8]
const REQUIRED_JOINTS = ["Body", "Head", "Arm_L", "Arm_R", "Leg_L", "Leg_R", "Weapon_Cutlass"]
var observations: Array[Dictionary] = []
var screenshots: Array[Dictionary] = []
var measurements: Dictionary = {}
var report_dir: String
var selected_indices: Array = []

func check(ok: bool, message: String):
	observations.append({"passed": ok, "message": message})
	super.check(ok, message)

func run():
	visual = true
	report_dir = "res://build/rogue-roster-upgrade" if OS.has_feature("editor") else "user://build/rogue-roster-upgrade"
	selected_indices = range(CLASS_IDS.size())
	var targeted = false
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--hero="):
			var id = argument.trim_prefix("--hero=")
			var index = CLASS_IDS.find(id)
			if index < 0:
				push_error("Unknown tour hero: " + id)
				get_tree().quit(1)
				return
			selected_indices = [index]
			targeted = true
			report_dir = report_dir.path_join("targeted-" + id)
	output_dir = report_dir.path_join("screenshots")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output_dir))
	if DisplayServer.get_name() == "headless":
		check(false, "Rendered tour requires a window; do not use --headless")
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
	check(game.is_fire_siege() and not game.rogue_battle_mode, "Tour runs in the current Fire Siege MVP")
	check(game.camera_rig.camera.projection == Camera3D.PROJECTION_PERSPECTIVE, "MVP perspective camera remains active")
	if not "--abilities-only" in OS.get_cmdline_user_args():
		await roster_review()
	if not targeted and not "--roster-only" in OS.get_cmdline_user_args():
		await magic_dive_review()
		await pirate_review()
		await energy_review(2)
		await energy_review(8)
		await dragoon_review()
		await mage_review()
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
	print("ROGUE_ROSTER_UPGRADE_TOUR_COMPLETE checks=", checks, " failures=", failures, " captures=", screenshots.size(), " output=", ProjectSettings.globalize_path(report_dir))
	await frames(18)
	get_tree().quit(1 if failures else 0)

func release_all():
	for action in ["light_attack", "heavy_attack", "weapon_chain", "jump", "equip", "dodge", "surge"]:
		press(action, false)
	game.player.smoke_move = Vector2.ZERO

func prepare_hero(index: int):
	release_all()
	if game.paused:
		game.resume()
	game.hud.show()
	game.player.cancel_charge()
	game.player.clear_powerups()
	game.player.buildings_broken = 0
	game.player.scale = Vector3.ONE
	game.player.run_upgrades = {"damage": 0, "vitality": 0, "tempo": 0}
	game.show_rogue_roster()
	var button = game.menu.find_child("RogueFighter_" + CLASS_IDS[index], true, false)
	check(button is Button, CLASS_IDS[index] + " is available in the live hero selector")
	if button is Button:
		button.pressed.emit()
	else:
		game.close_rogue_roster()
		return
	check(game.player.character_id == index + 3 and game.player.active_ability.class_id == CLASS_IDS[index] and not game.paused, CLASS_IDS[index] + " selects its native kit through the MVP picker")
	await clear_enemies()
	game.player.active_ability.reset_run()
	game.reset_player_at(TOUR_ORIGIN)
	game.player.hp = game.player.max_hp
	game.player.invuln = 0
	game.player.facing = Vector3.FORWARD
	game.player.model.rotation.y = 0
	game.camera_rig.yaw = 0
	aim_world(game.player.position + Vector3(0, 0, -8))
	standard_camera()
	await frames(15)
	native_projectiles.clear()

func standard_camera():
	game.camera_rig.yaw = 0
	game.camera_rig.pitch = 0.36
	game.camera_rig.distance = 14.0
	game.camera_rig.current_distance = 14.0
	game.camera_rig.camera.fov = 63
	game.camera_rig.reset_follow()
	game.camera_rig.set_process(true)

func fixed_camera(focus: Vector3, offset: Vector3, field_of_view: float = 50.0):
	game.camera_rig.set_process(false)
	var camera = game.camera_rig.camera
	camera.fov = field_of_view
	camera.h_offset = 0
	camera.v_offset = 0
	camera.global_position = focus + offset
	camera.look_at(focus)
	await frames(2)

func shot(label: String, purpose: String):
	game.hud.banner_time = 0
	game.hud.toast_time = 0
	game.player.invuln = 0
	await RenderingServer.frame_post_draw
	var image = get_viewport().get_texture().get_image()
	var path = output_dir.path_join(label + ".png")
	var result = image.save_png(path)
	check(result == OK and image.get_width() > 0, "Saved rendered capture " + label)
	screenshots.append({"label": label, "purpose": purpose, "file": "screenshots/" + label + ".png", "width": image.get_width(), "height": image.get_height()})

func roster_review():
	var geometry: Dictionary = {}
	for index in selected_indices:
		await prepare_hero(index)
		var id: String = CLASS_IDS[index]
		var actor = game.player.active_ability.visual_actor
		var intact = is_instance_valid(actor) and is_instance_valid(actor.model)
		for joint in REQUIRED_JOINTS:
			intact = intact and actor.joints.has(joint)
		check(intact, id + " preserves the loaded body, head, limb and weapon joints")
		if not intact:
			continue
		var fingerprint = model_geometry_hash(actor.model)
		geometry[fingerprint] = true
		check(actor.model.scene_file_path == "res://assets/rogue/styled/models/%s.glb" % id, id + " renders the shipped styled GLB")
		game.hud.hide()
		var focus: Vector3 = actor.joints.Head.node.global_position + Vector3(0, 0.31 * 1.15, -0.025)
		for view in ["front", "side", "three-quarter"]:
			var direction: Vector3 = {"front": Vector3.FORWARD, "side": Vector3.RIGHT, "three-quarter": Vector3(1, 0, -1).normalized()}[view]
			await fixed_camera(focus, direction * 2.15, 35)
			await shot("%02d-%s-head-%s" % [index + 1, id, view], "Inspect painted facial landmarks, integrated nose, cheek, jaw, ear and hair volume in the actual MVP")
		await fixed_camera(game.player.position + Vector3.UP * 1.3, Vector3(4.1, 1.4, -5.1), 46)
		await shot("%02d-%s-body-three-quarter" % [index + 1, id], "Inspect complete class silhouette, preserved equipment and clothing depth")
		game.hud.show()
		await basic_range_review(index)
	check(geometry.size() == selected_indices.size() and not geometry.has(""), "All selected heroes retain distinct rendered model geometry")

func basic_range_review(index: int):
	await prepare_hero(index)
	var id: String = CLASS_IDS[index]
	var ability = game.player.active_ability
	var distance: float = PREVIOUS_PRIMARY_REACH[index] * (1.12 if index in [3, 7] else 1.7)
	var target = fixture(Vector3(0, 0, -distance))
	var behind = fixture(Vector3(0, 0, 3))
	await fixed_camera(game.player.position + Vector3(0, 1, -distance * 0.35), Vector3(maxf(9, distance * 0.65), maxf(5, distance * 0.35), maxf(10, distance * 0.7)))
	tap("light_attack")
	if index not in [3, 7]:
		check(ability.player.attack != null and is_equal_approx(float(ability.player.attack.reach), PREVIOUS_PRIMARY_REACH[index] * 3.0), id + " light attack commits exactly triple its previous reach")
	for frame in range(150):
		if target.hp < 10000:
			break
		await frames(1)
	check(target.hp < 10000 and behind.hp == 10000, id + " light attack damages a forward target beyond its previous reach without hitting behind")
	await shot("%02d-%s-basic-range-contact" % [index + 1, id], "Real light input and damage beyond the previous basic reach")

func wait_recovery(limit: int = 150):
	for frame in range(limit):
		var ability = game.player.active_ability
		var state: Dictionary = ability.player
		if state.attack == null and state.travel == null and state.roll <= 0 and ability.hit_stop <= 0 and ability.attack_buffer <= 0 and state.cooldowns.cutlass <= 0:
			return
		await frames(1)
	check(false, "Player action recovery finishes within its bounded duration")

func magic_dive_review():
	await prepare_hero(6)
	var target = fixture(Vector3(0, 0, -6))
	var origin: Vector3 = game.player.position
	await fixed_camera(origin + Vector3(0, 2, -3), Vector3(11, 4, 10))
	tap("jump")
	await frames(16)
	tap("jump")
	await frames(8)
	check(game.player.jumps_used == 2 and not game.player.is_on_floor(), "Magic Swordsman reaches the second jump through real Space input")
	var before: Vector3 = game.player.position
	tap("light_attack")
	var ability = game.player.active_ability
	check(ability.player.get("dive") != null, "Second-jump light input starts Magic Swordsman's committed energy dive")
	await frames(3)
	check(game.player.position.z < before.z - 0.5 and game.player.position.y < before.y - 0.5, "Magic Swordsman's dive moves both forward and downward")
	await shot("magic-swordsman-energy-dive", "Forward/down energy dive with the real airborne body and effect")
	for frame in range(65):
		if target.hp < 10000:
			break
		await frames(1)
	check(10000 - target.hp >= 250, "Energy dive landing deals its heavy impact damage to a live target")
	await shot("magic-swordsman-dive-impact", "Heavy landing impact and enemy hit in Fire Siege")
	var health = target.hp
	await frames(24)
	check(target.hp == health and ability.player.get("dive") == null, "Dive resolves once and clears its airborne action state")
	measurements.magic_dive_forward_distance = origin.z - game.player.position.z

func pirate_review():
	await prepare_hero(0)
	var targets = [fixture(Vector3(0, 0, -3.5)), fixture(Vector3(0, 0, -7)), fixture(Vector3(0, 0, -11))]
	await fixed_camera(game.player.position + Vector3(0, 1.0, -3), Vector3(9, 4, 9))
	tap("heavy_attack")
	var ability = game.player.active_ability
	check(ability.projectiles.size() == 1, "Pirate secondary creates a visible projectile")
	if not ability.projectiles.is_empty():
		var projectile: Dictionary = ability.projectiles[0]
		check(projectile.kind == "bullet" and projectile.pierce and is_equal_approx(float(projectile.get("visualScale", 0)), 10.0), "Pirate bullet uses tenfold visible scale and pierces enemies")
		measurements.pirate_bullet_visual_scale = projectile.get("visualScale", 0)
		measurements.pirate_bullet_width = projectile.width
	await frames(3)
	await shot("pirate-tenfold-bullet", "Visible tenfold bullet between the Pirate and lined-up enemies")
	await frames(23)
	check(targets.all(func(target): return target.hp < 10000), "One Pirate bullet pierces three successive live targets")
	await shot("pirate-piercing-targets", "Three targets damaged by the same secondary shot")
	var health = targets.map(func(target): return target.hp)
	await frames(15)
	check(targets.map(func(target): return target.hp) == health, "Pirate piercing bullet does not hit the same target twice")

func energy_review(index: int):
	await prepare_hero(index)
	var id: String = CLASS_IDS[index]
	var ability = game.player.active_ability
	for count in range(4):
		tap("light_attack")
		await wait_recovery()
		check(ability.player.get("energy", -1) == (count + 1) * 20, id + " gains exactly 20 energy from completed light %d" % (count + 1))
		if count == 1:
			await shot(id + "-energy-partial", "Small MVP energy bar at two completed attacks")
	# Start a normal secondary at 80, then finish the fifth light while its cooldown runs.
	tap("heavy_attack")
	await wait_recovery()
	check(ability.player.get("energy", -1) == 80, id + " keeps partial energy when using a normal heavy")
	tap("light_attack")
	await wait_recovery()
	check(ability.player.get("energy", -1) == 100 and ability.energy_ready(), id + " becomes ready only after the fifth completed light")
	check(ability.player.cooldowns.flintlock > 0 and ability.player.roll <= 0, id + " holds ready energy for manual use while the normal heavy cooldown is active")
	await shot(id + "-energy-ready", "Full small energy bar and manually available free heavy during normal cooldown")
	var cooldown: float = ability.player.cooldowns.flintlock
	tap("heavy_attack")
	check(ability.player.get("energy", -1) == 0 and ability.player.roll > 0, id + " manually spends full energy to start its heavy during cooldown")
	check(ability.player.cooldowns.flintlock <= cooldown + 0.01, id + " free heavy does not restart or extend its existing cooldown")
	await frames(5)
	await shot(id + "-free-heavy-consumed", "Manually triggered free heavy and emptied energy bar")

func jump_apex(index: int, label: String) -> float:
	await prepare_hero(index)
	var origin: Vector3 = game.player.position
	await fixed_camera(origin + Vector3(0, 2, 0), Vector3(8, 3, 10))
	tap("jump")
	var peak: float = origin.y
	var airborne = false
	for frame in range(110):
		await frames(1)
		peak = maxf(peak, game.player.position.y)
		airborne = airborne or not game.player.is_on_floor()
		if airborne and game.player.velocity.y <= 0:
			break
	check(airborne and peak > origin.y + 0.5, CLASS_IDS[index] + " jump reaches a measured airborne apex")
	await shot(label, "Same camera, ground and input for a measured jump-height comparison")
	return peak - origin.y

func dragoon_review():
	var normal_height: float = await jump_apex(0, "pirate-normal-jump-apex")
	var dragoon_height: float = await jump_apex(5, "dragoon-double-height-jump-apex")
	var ratio: float = dragoon_height / maxf(normal_height, 0.001)
	measurements.jump_apex = {"pirate": normal_height, "dragoon": dragoon_height, "ratio": ratio}
	check(ratio > 1.8 and ratio < 2.2, "Dragoon actual jump apex is approximately twice the normal hero height")

func mage_review():
	await prepare_hero(3)
	var targets = [fixture(Vector3(0, 0, -3)), fixture(Vector3(0, 0, -6)), fixture(Vector3(0, 0, -9))]
	await fixed_camera(game.player.position + Vector3(0, 1, -3), Vector3(9, 4, 9))
	press("light_attack")
	await frames(185)
	await shot("mage-charged-piercing-ready", "Fully charged Mage fireball before release")
	press("light_attack", false)
	var ability = game.player.active_ability
	check(ability.projectiles.size() == 1 and ability.projectiles[0].pierce, "Charged Mage fireball is a single piercing projectile")
	await frames(5)
	await shot("mage-piercing-fireball", "Released charged fireball traveling through the enemy line")
	await frames(35)
	check(targets.all(func(target): return target.hp < 10000), "One Mage fireball pierces three successive live targets")
	await shot("mage-piercing-targets", "Three targets damaged by the same charged fireball")
	var health = targets.map(func(target): return target.hp)
	await frames(20)
	check(targets.map(func(target): return target.hp) == health, "Mage fireball does not hit the same target twice")

func write_report():
	var manifest = {"checks": checks, "failures": failures, "rendering_method": RenderingServer.get_current_rendering_method(), "measurements": measurements, "observations": observations, "screenshots": screenshots}
	var file = FileAccess.open(report_dir.path_join("verification-manifest.json"), FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(manifest, "\t"))
	var lines: Array[String] = ["# Rogue roster upgrade verification", "", "Rendered tour result: **%d checks, %d failures, %d captures**." % [checks, failures, screenshots.size()], "", "This run uses the current Fire Siege world, its hero-selector buttons, real action input, player collision, live enemy damage and current HUD. AI/directors are paused to isolate owned targets. Portrait review changes only the camera and HUD visibility.", "", "## Behavioral observations", ""]
	for result in observations:
		if not result.message.begins_with("Saved rendered capture"):
			lines.append("- [%s] %s" % ["x" if result.passed else " ", result.message])
	lines.append_array(["", "## Measurements", "", "```json", JSON.stringify(measurements, "\t"), "```", "", "## Rendered capture index", "", "Inspect the three head views for each class for facial landmarks and dimensional form. Automated geometry/selection assertions do not replace visual review.", ""])
	for screenshot in screenshots:
		lines.append("- [%s](%s) — %s" % [screenshot.label, screenshot.file, screenshot.purpose])
	lines.append_array(["", "## Reproduction", "", "Run the current Godot project with `-- --rogue-roster-upgrade-tour` in a rendered window after asset import completes. `--abilities-only` skips roster captures; `--roster-only` skips the skill tour. A full run is required for complete evidence.", "", "Companion regression checks: `--rogue-combat-upgrade-test`, `--fire-siege-controls-test`, `--fire-siege-motion-test`, `--fire-siege-weight-test`, and the new roster combat suite. The tour exits nonzero on assertion or image-save failure.", ""])
	file = FileAccess.open(report_dir.path_join("verification-report.md"), FileAccess.WRITE)
	if file:
		file.store_string("\n".join(lines))

func stop_audio(node: Node):
	if node is AudioStreamPlayer or node is AudioStreamPlayer2D or node is AudioStreamPlayer3D:
		node.stop()
		node.stream = null
	for child in node.get_children():
		stop_audio(child)
