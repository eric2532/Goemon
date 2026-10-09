extends "res://scripts/fire_siege_controls_tests.gd"
## Real input, terrain contacts and enemy damage regressions for equipment combat.

func run():
	Input.use_accumulated_input=false
	game.smoke_test=true;game.tuning=PrototypeTuning.DEFAULTS.duplicate()
	game.tuning.invincible=true;game.tuning.freeze_ai=true;game.player.smoke_mode=true
	game.start_mode("defense");pause_fixture_director();game.encounters.choose_card("supply_cache")
	await frames(3)
	await airborne_lance_rules()
	await grounded_lance_rules()
	await obstruction_rules()
	await cancel_rules()
	await ranger_rules()
	game.show_main_menu();game.sound_library.cancel();game.music.stop()
	await frames(3)
	stop_audio(game)
	var shared_audio=game.get_node_or_null("RogueSharedClassAudio")
	if is_instance_valid(shared_audio):shared_audio.cache.clear()
	await frames(20)
	print("ROGUE_EQUIPMENT_COMBAT_RESULT checks=",checks," failures=",failures)
	get_tree().quit(1 if failures else 0)

func stop_audio(node: Node):
	if node is AudioStreamPlayer or node is AudioStreamPlayer2D or node is AudioStreamPlayer3D:
		node.stop();node.stream=null
	for child in node.get_children():stop_audio(child)

func obstacle(offset: Vector3,size_: Vector3)->StaticBody3D:
	var body=StaticBody3D.new();body.collision_layer=1;body.collision_mask=0
	var shape=CollisionShape3D.new();var box=BoxShape3D.new()
	box.size=size_;shape.shape=box;body.add_child(shape)
	game.add_child(body);body.global_position=game.player.global_position+offset
	return body

func airborne_lance_rules():
	for input_action in ["heavy_attack","weapon_chain"]:
		await fresh_class(5);var p=game.player;var a=p.active_ability
		game.reset_player_at(TEST_ORIGIN+Vector3.UP*60);await frames(2)
		var start=p.position;var floating=fixture(Vector3(7.5,0,2.5))
		var ground=fixture(Vector3(0,TEST_ORIGIN.y-p.position.y,2.5))
		tap(input_action)
		check(a.player.travel!=null and p.velocity.y< -20,"Airborne %s immediately commits downward lance travel" % input_action)
		await frames(5)
		check(p.position.y<start.y-2 and absf(p.position.x-start.x)<.1,"Airborne %s drops straight down without a second upward arc" % input_action)
		await frames(41)
		check(p.position.y>2 and a.player.travel!=null and a.player.pulses.is_empty() and floating.hp==10000 and ground.hp==10000,"Elapsed leap animation cannot emit damage or pulses in midair (%s)" % input_action)
		var landed=false
		for count in range(100):
			await frames(1)
			if a.player.travel==null and p.position.y<.5:
				landed=true;break
		check(landed,"Airborne %s completes at the actual terrain floor" % input_action)
		await frames(42)
		check(is_equal_approx(10000-ground.hp,192) and floating.hp==10000,"Airborne %s produces exactly three ground-centered 64-damage pulses" % input_action)
		var health=ground.hp;await frames(35)
		check(ground.hp==health and a.player.pulses.is_empty(),"Airborne %s landing cannot replay after completion" % input_action)

func grounded_lance_rules():
	await fresh_class(5);var p=game.player;var a=p.active_ability
	var start=p.position;var target=fixture(Vector3(7.5,0,2.5));tap("heavy_attack")
	var apex=start.y;var air_damage=false
	for count in range(95):
		await frames(1);apex=maxf(apex,p.position.y)
		if p.position.y>start.y+.65 and target.hp<10000:air_damage=true
	check(apex-start.y>4.5 and absf(p.position.x-start.x-7.5)<.2,"Grounded lance leap retains its high arc and full forward distance")
	check(not air_damage and is_equal_approx(10000-target.hp,192),"Grounded lance leap waits for floor contact before exactly three pulses")
	# A raised surface must count as ground; the impact cannot assume world y=0.
	await fresh_class(5);a=p.active_ability
	var platform=obstacle(Vector3(7.5,1.5,0),Vector3(5,3,8));await frames(2)
	var raised=fixture(Vector3(7.5,3,2.5));tap("heavy_attack");await frames(95)
	check(p.position.y>2.8 and a.player.travel==null and is_equal_approx(10000-raised.hp,192),"Lance landing recognizes a real raised platform floor")
	platform.queue_free();await frames(2)

func obstruction_rules():
	for ceiling in [false,true]:
		await fresh_class(5);var p=game.player;var a=p.active_ability
		var solid=obstacle(Vector3(3,3.2,0) if ceiling else Vector3(2,8,0),Vector3(12,.4,8) if ceiling else Vector3(.4,18,10))
		var target=fixture(Vector3(0,0,2.5));await frames(2);tap("heavy_attack")
		var air_damage=false;var air_pulses=false
		for count in range(90):
			await frames(1)
			if p.position.y>.7:
				air_damage=air_damage or target.hp<10000
				air_pulses=air_pulses or not a.player.pulses.is_empty()
		check(not air_damage and not air_pulses,"Lance %s contact cannot trigger an airborne landing impact" % ("ceiling" if ceiling else "wall"))
		check(a.player.travel==null and p.position.y<.5 and is_equal_approx(10000-target.hp,192),"Lance falls from %s contact to one real three-pulse floor landing" % ("ceiling" if ceiling else "wall"))
		solid.queue_free();await frames(2)

func cancel_rules():
	for mode in ["cancel","pause","swap","reset"]:
		await fresh_class(5);var p=game.player;var a=p.active_ability
		game.reset_player_at(TEST_ORIGIN+Vector3.UP*12);await frames(2)
		var target=fixture(Vector3(0,TEST_ORIGIN.y-p.position.y,2.5));tap("heavy_attack")
		match mode:
			"cancel":a.cancel()
			"pause":game.show_pause();game.resume()
			"swap":p.select_character(3)
			"reset":a.reset_run()
		await frames(95)
		check(a.player.travel==null and a.player.pulses.is_empty() and target.hp==10000,"%s clears the pending aerial lance impact" % mode)
	await fresh_class(5);var p=game.player;var a=p.active_ability
	game.reset_player_at(TEST_ORIGIN+Vector3.UP*6);await frames(2)
	tap("heavy_attack");tap("jump");await frames(70)
	check(p.position.y<.5 and p.jump_buffer==0,"Jump during lance descent cannot queue an automatic landing bounce")

func ranger_rules():
	# Count real releases over the old 0.62-second firing cycle, including held input.
	for boosted in [false,true]:
		await fresh_class(7);var p=game.player;var a=p.active_ability
		if boosted:tap("surge")
		press("light_attack");await frames(4)
		check(native_projectiles.size()==1,"Ranger %s first arrow releases within the shortened draw time" % ("buffed" if boosted else "normal"))
		await frames(34);press("light_attack",false)
		check(native_projectiles.size()==3,"Ranger %s held primary releases three arrows per old firing cycle" % ("buffed" if boosted else "normal"))
		var correct=true
		for arrow in a.projectiles:
			correct=correct and arrow.mesh.scale.is_equal_approx(Vector3.ONE*2) and is_equal_approx(arrow.vel.length(),36) and is_equal_approx(arrow.width,.25)
		check(not a.projectiles.is_empty() and correct,"Ranger %s primary doubles visuals while retaining projectile speed and collision width" % ("buffed" if boosted else "normal"))
		await fresh_class(7);a=p.active_ability
		if boosted:tap("surge")
		tap("heavy_attack");await frames(25)
		correct=a.projectiles.size()==4
		for arrow in a.projectiles:
			correct=correct and arrow.mesh.scale.is_equal_approx(Vector3.ONE*2) and is_equal_approx(arrow.vel.length(),34) and is_equal_approx(arrow.width,.25)
		check(correct,"Ranger %s secondary retains four arrows with doubled visuals and original flight handling" % ("buffed" if boosted else "normal"))
	for boosted in [false,true]:
		await fresh_class(7)
		if boosted:tap("surge")
		var far=fixture(Vector3(48,0,0));var outside=fixture(Vector3(66,0,0));tap("light_attack");await frames(130)
		check(is_equal_approx(10000-far.hp,67) and outside.hp==10000,"Ranger %s enlarged primary keeps its long range and single-target damage" % ("buffed" if boosted else "normal"))
		far.queue_free();await frames(2);tap("light_attack");await frames(130)
		check(outside.hp==10000 and game.player.active_ability.projectiles.is_empty(),"Ranger %s primary expires before an unobstructed target beyond its original 60-unit range" % ("buffed" if boosted else "normal"))
		await fresh_class(7)
		if boosted:tap("surge")
		outside=fixture(Vector3(24,0,0));tap("heavy_attack");await frames(70)
		check(outside.hp==10000 and game.player.active_ability.projectiles.is_empty(),"Ranger %s secondary arrows retain their original 20-unit range" % ("buffed" if boosted else "normal"))
	var a=game.player.active_ability
	for boosted in [false,true]:
		await fresh_class(7);a=game.player.active_ability
		var wall=obstacle(Vector3(4,3,0),Vector3(.4,8,8));var hidden=fixture(Vector3(7,0,0));await frames(2)
		if boosted:tap("surge")
		tap("light_attack");await frames(30);tap("heavy_attack");await frames(55)
		check(hidden.hp==10000 and a.projectiles.is_empty(),"Ranger %s enlarged primary and burst remain blocked by solid cover" % ("buffed" if boosted else "normal"))
		wall.queue_free();await frames(2)
	await fresh_class(1);a=game.player.active_ability;tap("equip")
	check(a.projectiles.size()==1 and a.projectiles[0].mesh.scale.is_equal_approx(Vector3.ONE) and is_equal_approx(a.projectiles[0].vel.length(),32),"Samurai's utility arrow retains its original size and speed")
