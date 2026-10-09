extends "res://scripts/fire_siege_controls_tests.gd"
## Real native attacks: far contact, bounded reach, growth, cover and projectiles.

func run():
	game.smoke_test = true
	game.tuning = PrototypeTuning.DEFAULTS.duplicate()
	game.tuning.invincible = true
	game.tuning.freeze_ai = true
	game.player.smoke_mode = true
	game.start_mode("defense")
	pause_fixture_director()
	await frames(5)
	await pipe_rules()
	await projectile_rules()
	game.show_main_menu()
	game.sound_library.cancel()
	game.music.stop()
	await frames(3)
	_stop_audio(game)
	await frames(18)
	print("NATIVE_PRIMARY_RANGE_RESULT checks=", checks, " failures=", failures)
	get_tree().quit(1 if failures else 0)

func pipe_rules():
	for growth in [0, 2]:
		await fresh_goemon()
		var p = game.player
		p.soft_target = false
		p.buildings_broken = growth
		p.scale = Vector3.ONE * p.growth_multiplier()
		p.facing = Vector3.FORWARD
		var reach: float = game.tuning.pipe_range * 3.0 * p.melee_range_multiplier()
		var near = fixture(Vector3(0, 0, -reach + 0.2))
		var beyond = fixture(Vector3(0, 0, -reach - 2.0))
		p.start_attack(false, 1)
		p.strike()
		check(near.hp < 10000, "Goemon basic reaches three times the old boundary at growth %d" % growth)
		check(beyond.hp == 10000, "Goemon basic remains bounded at growth %d" % growth)
		p.cancel_charge()
	await fresh_goemon()
	var p = game.player
	p.soft_target = false
	p.facing = Vector3.FORWARD
	var outside_heavy = fixture(Vector3(0, 0, -8))
	p.start_attack(true)
	p.strike()
	check(outside_heavy.hp == 10000, "Goemon heavy range is unchanged by the basic upgrade")
	p.cancel_charge()
	await fresh_goemon()
	p.facing = Vector3.FORWARD
	var covered = fixture(Vector3(0, 0, -8))
	var wall = Geo.box(game, p.position + Vector3(0, 2, -4), Vector3(6, 5, 0.5), Geo.mat("665544"), true)
	await frames(2)
	p.start_attack(false, 1)
	p.strike()
	check(covered.hp == 10000, "Extended Goemon basic still respects solid cover")
	p.cancel_charge()
	wall.queue_free()

func projectile_rules():
	await fresh_goemon()
	var p = game.player
	p.soft_target = false
	p.attack_ticket = p.attack_chain.begin("coin")
	game.throw_coin(false)
	var coins = get_tree().get_nodes_in_group("projectiles")
	var basic_coin = coins.back()
	check(is_equal_approx(basic_coin.lifetime, 6.0 * p.growth_multiplier() / p.attack_speed_multiplier()), "Goemon basic coin has triple travel duration at unchanged speed")
	for coin in coins:
		coin.queue_free()
	await frames(2)
	game.throw_coin(true)
	coins = get_tree().get_nodes_in_group("projectiles")
	check(is_equal_approx(coins.back().lifetime, 2.0 * p.growth_multiplier() / p.attack_speed_multiplier()), "Goemon heavy coin lifetime stays unchanged")
	for coin in coins:
		coin.queue_free()
	await frames(2)
	p.cancel_charge()
	p.select_character(2)
	p.musashi.large_cast = false
	p.musashi.launch()
	var balls = get_tree().get_nodes_in_group("edo_fireballs")
	check(balls.size() == 3, "Edo basic retains its three fireballs")
	check(is_equal_approx(balls.back().lifetime, 3.0 * p.musashi.balance.projectile_lifetime * p.growth_multiplier() / p.attack_speed_multiplier()), "Edo basic volley travels three times farther")
	for ball in balls:
		ball.queue_free()
	await frames(2)
	p.musashi.large_cast = true
	p.musashi.launch()
	balls = get_tree().get_nodes_in_group("edo_fireballs")
	check(is_equal_approx(balls.back().lifetime, p.musashi.balance.projectile_lifetime * p.growth_multiplier() / p.attack_speed_multiplier()), "Edo giant heavy fireball retains its existing travel")
	p.musashi.cancel()
	p.musashi.activate_shield()
	p.musashi.start_beam("light_attack")
	check(is_equal_approx(p.musashi.beam.length_now, game.tuning.beam_length * 3.0 * p.base_attack_speed_multiplier() * p.growth_multiplier()), "Edo empowered light beam also gets triple reach")
	p.musashi.cancel()

func _stop_audio(node: Node):
	if node is AudioStreamPlayer or node is AudioStreamPlayer2D or node is AudioStreamPlayer3D:
		node.stop()
		node.stream = null
	for child in node.get_children():
		_stop_audio(child)
