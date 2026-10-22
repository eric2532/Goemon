extends "res://scripts/fire_siege_controls_tests.gd"
## Two-pilot art review in the real Fire Siege map, controller, and combat loop.
## Main-game flag: --rogue-design-gameplay-tour

const PILOT_INDICES = [6, 8]
const PILOT_ORIGIN = Vector3(0, 0.1, 205)

func run():
	visual = true
	output_dir = "res://tests/rogue-design-pilot" if OS.has_feature("editor") else "user://tests/rogue-design-pilot"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output_dir))
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
	check(game.is_fire_siege() and not game.rogue_battle_mode, "Design pilot uses the current Fire Siege MVP world")
	for index in PILOT_INDICES:
		var hero_id: String = CLASS_IDS[index]
		await prepare_pilot(index)
		check(game.player.active_ability.class_id == hero_id, hero_id + " loads through the live hero selector")
		var actor = game.player.active_ability.visual_actor
		check(actor.joints.has("Head") and actor.joints.has("Arm_R") and actor.joints.has("Weapon_Cutlass"), hero_id + " retains head and weapon joints")
		game.camera_rig.set_process(false)
		game.camera_rig.camera.fov = 50
		await close_view(Vector3(0, 1.95, -6.2))
		await capture(hero_id + "-world-front")
		await close_view(Vector3(4.1, 2.0, -5.0))
		await capture(hero_id + "-world-three-quarter")
		standard_camera()
		await frames(20)
		await capture(hero_id + "-gameplay-idle")
		game.player.smoke_move = Vector2.UP
		await frames(24)
		check(game.player.velocity.length() > 1.0, hero_id + " runs through the real movement controller")
		await capture(hero_id + "-gameplay-run")
		game.player.smoke_move = Vector2.ZERO

		await prepare_pilot(index)
		standard_camera()
		await frames(12)
		var victim = fixture(Vector3(0, 0, -2.2))
		tap("light_attack")
		var contact_reached := false
		for frame in range(45):
			await frames(1)
			var attack = game.player.active_ability.player.attack
			if attack != null and float(attack.time) >= float(attack.contact):
				contact_reached = true
				break
		check(contact_reached, hero_id + " reaches its primary contact frame through real input")
		await capture(hero_id + "-gameplay-primary-contact")
		check(victim.hp < 10000, hero_id + " primary contact damages the live target")

		await prepare_pilot(index)
		standard_camera()
		await frames(12)
		var before: Vector3 = game.player.position
		tap("weapon_chain")
		await frames(5)
		var ability = game.player.active_ability
		check(ability.player.cooldowns.flintlock > 0, hero_id + " activates secondary with key 3")
		if index == 6:
			check(not ability.projectiles.is_empty(), "Magic Swordsman launches his live energy wave")
		else:
			check(game.player.position.distance_to(before) > 0.5 and ability.player.rollStyle == "cross-slash", "Explorer performs the live dash cross slash")
		await capture(hero_id + "-gameplay-secondary")
	game.player.smoke_move = Vector2.ZERO
	press("light_attack", false)
	press("heavy_attack", false)
	press("weapon_chain", false)
	game.player.active_ability.reset_run()
	game.camera_rig.set_process(true)
	game.show_main_menu()
	game.sound_library.cancel()
	game.music.stop()
	await frames(3)
	_stop_audio(game)
	var shared_audio = game.get_node_or_null("RogueSharedClassAudio")
	if is_instance_valid(shared_audio):
		shared_audio.cache.clear()
	await frames(18)
	print("ROGUE_DESIGN_GAMEPLAY_TOUR_COMPLETE checks=", checks, " failures=", failures, " output=", ProjectSettings.globalize_path(output_dir))
	get_tree().quit(1 if failures else 0)

func prepare_pilot(index: int):
	press("weapon_chain", false)
	await fresh_class(index)
	game.reset_player_at(PILOT_ORIGIN)
	game.camera_rig.yaw = 0
	game.player.facing = Vector3.FORWARD
	game.player.model.rotation.y = 0
	game.player.active_ability.reset_run()
	aim_world(game.player.position + Vector3(0, 0, -8))
	await frames(15)

func close_view(offset: Vector3):
	game.camera_rig.camera.global_position = game.player.position + offset
	game.camera_rig.camera.look_at(game.player.position + Vector3(0, 1.2, 0))
	await frames(5)

func standard_camera():
	game.camera_rig.yaw = 0
	game.camera_rig.pitch = 0.36
	game.camera_rig.distance = 14.0
	game.camera_rig.current_distance = 14.0
	game.camera_rig.camera.fov = 63
	game.camera_rig.reset_follow()
	game.camera_rig.set_process(true)

func _stop_audio(node: Node):
	if node is AudioStreamPlayer or node is AudioStreamPlayer2D or node is AudioStreamPlayer3D:
		node.stop()
		node.stream = null
	for child in node.get_children():
		_stop_audio(child)
