extends SceneTree
## Captures the desktop reference through the same title buttons as the web build.
const Tour = preload("res://scripts/forest/forest_falan_tour.gd")
const Title = preload("res://scenes/forest_title.tscn")
const DEFAULT_OUTPUT = "res://build/Other Files/Cross Gate Web Parity/"
var output_dir: String = DEFAULT_OUTPUT
var game
var report: Dictionary = {}
var started: int

func _initialize():
	started = Time.get_ticks_usec()
	create_timer(270).timeout.connect(func(): fail("Desktop parity timed out"))
	run.call_deferred()

func fail(problem: String):
	push_error(problem)
	quit(1)

func begin(title_button: String) -> bool:
	game = Title.instantiate()
	game.settings_path = "/tmp/cross-gate-parity-%d.cfg" % OS.get_process_id()
	root.add_child(game)
	current_scene = game
	# Native pointer capture can synthesize mouse motion as the OS moves the cursor.
	game.camera_rig.set_process_unhandled_input(false)
	await process_frame
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
	report["title_visible_seconds"] = (Time.get_ticks_usec() - started) / 1000000.0
	return choose_mode(title_button)

func choose_mode(title_button: String) -> bool:
	var start_button = game.menu.find_child(title_button, true, false)
	if not start_button is Button:
		fail("Missing desktop title button " + title_button)
		return false
	start_button.pressed.emit()
	if not game.rogue_roster_open:
		fail("Roster did not open from " + title_button)
		return false
	game.choose_rogue_character(game.player.RogueRoster.KAZI_ID)
	game.settings.forest_level_up_cards = false
	game.settings.music_enabled = true
	game.equipment_hub.enter_button.pressed.emit()
	return game.playing and game.model.phase == "wave"

func capture(label: String, sample_count: int = 15):
	game.camera_rig.pitch = game.COMBAT_CAMERA_PITCH
	game.camera_rig.reset_follow()
	for i in 12:
		await process_frame
	var intervals: Array[float] = []
	var last: int = Time.get_ticks_usec()
	for i in sample_count:
		await process_frame
		var now: int = Time.get_ticks_usec()
		intervals.append((now - last) / 1000.0)
		last = now
	intervals.sort()
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		var image = root.get_texture().get_image()
		if image.save_png(output_dir.path_join("desktop-" + label + ".png")) != OK:
			fail("Could not capture " + label)
	var view: Camera3D = game.camera_rig.camera
	report[label] = {
		"player": str(game.player.global_position),
		"camera": str(view.global_position),
		"yaw": game.camera_rig.yaw,
		"pitch": game.camera_rig.pitch,
		"ms_median": intervals[intervals.size() / 2],
		"ms_p95": intervals[ceili(intervals.size() * .95) - 1],
		"ms_max": intervals.back(),
		"music_stream": game.music.stream.resource_path if game.music.stream != null else "",
		"music_playing": game.music.playing,
		"enemies": game.model.enemies.size(),
		"render_objects": RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME),
		"draw_calls": RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),
	}

func cross(link: Dictionary, expected_area: String) -> bool:
	var at: Vector2 = link.at
	var current: String = Tour.area(game.model)
	game.player.global_position = game.model.world_point(at, .15)
	game.player.velocity = Vector3.ZERO
	if not Tour.enter_link(game, current, link, at):
		return false
	for i in 12:
		await physics_frame
	return Tour.area(game.model) == expected_area

func press_key(key: Key):
	var event := InputEventKey.new()
	event.physical_keycode = key
	event.pressed = true
	Input.parse_input_event(event)
	await process_frame
	event = event.duplicate()
	event.pressed = false
	Input.parse_input_event(event)
	await process_frame

func capture_tina():
	if not await begin("ForestPlay"):
		fail("Arena did not open before Tina travel")
		return
	game.show_title()
	if not choose_mode("ForestFalan"):
		fail("Adventure did not open before Tina travel")
		return
	if not await capture_region("tina", 0, [4200, 4201, 51005]):
		return
	await finish("desktop-tina-report.json")

func capture_region(label: String, option_index: int, accepted_floors: Array) -> bool:
	await press_key(KEY_J)
	if not is_instance_valid(game.dialogue) or game.dialogue.options.get_child_count() <= option_index:
		fail("J did not open the Adventure region choices")
		return false
	var option: Button = game.dialogue.options.get_child(option_index)
	report[label + "_travel_option"] = option.text
	await press_key(KEY_SPACE)
	for i in option_index:
		await press_key(KEY_RIGHT)
	await press_key(KEY_ENTER)
	for i in 12:
		await physics_frame
	if game.model.falan_floor not in accepted_floors:
		fail("Adventure region choice did not reach " + label)
		return false
	report[label + "_floor"] = game.model.falan_floor
	await capture(label, 120)
	return true

func run():
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--evidence-dir="):
			output_dir = arg.trim_prefix("--evidence-dir=")
	DirAccess.make_dir_recursive_absolute(output_dir)
	root.size = Vector2i(1440, 900)
	if "--tina" in OS.get_cmdline_user_args():
		await capture_tina()
		return
	if not await begin("ForestPlay"):
		fail("The Arena did not enter combat")
		return
	report["title_to_arena_seconds"] = (Time.get_ticks_usec() - started) / 1000000.0
	await capture("arena")
	game.show_title()
	if not choose_mode("ForestFalan") or Tour.area(game.model) != "city":
		fail("Adventure did not spawn in Falan")
		return
	await capture("falan-city", 120)
	var npcs = game.world.find_child("OriginalFalanNPCs", true, false)
	report["falan_city_npcs"] = npcs.get_child_count() if npcs != null else 0
	var links: Array = game.model.get_meta("falan_links", [])
	var bank: Array = links.filter(func(link): return link.get("floor", 0) == 1091)
	if not bank.is_empty():
		var spawn = game.player.global_position / game.model.falan_scale
		var spawn_point := Vector2(spawn.x, spawn.z)
		var blocked := []
		for step in 21:
			var at: Vector2 = spawn_point.lerp(bank[0].at, step * .05)
			var point := Vector3(at.x, game.model.surface_height(at.x, at.y) + .5, at.y)
			if game.model.scenery_obstacles.values().any(func(box): return box.grow(.5).has_point(point)):
				blocked.append(str(at))
		report["bank_straight_path_blockers"] = blocked
	if bank.is_empty() or not await cross(bank[0], "interior") or game.model.falan_floor != 1091:
		fail("The linked Bank doorway failed")
		return
	await capture("falan-bank")
	links = game.model.get_meta("falan_links", [])
	var exits: Array = links.filter(func(link): return link.to == "city")
	if exits.is_empty() or not await cross(exits[0], "city"):
		fail("The Bank return doorway failed")
		return
	if "--regions" in OS.get_cmdline_user_args():
		if not await capture_region("tina", 0, [4200, 4201, 51005]):
			return
		if not await capture_region("university-32193", 2, [32193]):
			return
	else:
		links = game.model.get_meta("falan_links", [])
		var gates: Array = links.filter(func(link): return link.to == "east_gate")
		if gates.is_empty() or not await cross(gates[0], "east_gate"):
			fail("The Falan East Gate failed")
			return
		await capture("freyja-east-gate")
	if game.save_settings() != OK:
		fail("Desktop settings save failed")
		return
	game.settings.music_enabled = false
	game.load_settings()
	if not game.settings.music_enabled:
		fail("Desktop settings did not reload")
		return
	await finish("desktop-report.json")

func finish(filename: String):
	print("WEB_PARITY_DESKTOP ", JSON.stringify(report))
	var output = FileAccess.open(output_dir.path_join(filename), FileAccess.WRITE)
	if output == null:
		fail("Could not write desktop report")
		return
	output.store_string(JSON.stringify(report, "  "))
	output.close()
	var settings_file: String = game.settings_path
	game.music.stop()
	current_scene = null
	game.queue_free()
	await process_frame
	DirAccess.remove_absolute(settings_file)
	quit()
