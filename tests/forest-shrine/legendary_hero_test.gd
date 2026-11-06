extends "res://tests/forest-shrine/team_leveling_gameplay_test.gd"

func run():
	create_timer(240).timeout.connect(func():printerr("LEGENDARY_HERO_TIMEOUT");quit(1))
	game=load("res://scenes/forest_shrine.tscn").instantiate();game.settings_path=cfg
	root.add_child(game);current_scene=game;await frames(8)
	game.start_wave();game.model.waves.spawn_clock=100000
	game.set_process(false);game.set_physics_process(false);game.player.set_physics_process(false);game.camera_rig.set_process(false)
	root.gui_disable_input=true;game.set_process_input(false);game.set_process_unhandled_input(false)
	game.player.set_process_input(false);game.player.set_process_unhandled_input(false)
	game.music.stop();root.title="Goemon Legendary Hero Verification"
	var p=game.model.team_progression;var helpers=game.explorer_helpers;var heroes=helpers.legendary_heroes;var runtime=game.army_runtime
	check(helpers.HEROES.map(func(id):return game.player.ROSTER[id].name)==["Goemon","Musashi","Kojiro","Blademaster","Illidan","Mountain King"],"Card names match the actual playable hero IDs")
	p.ranks.character_damage=2;game.model.gold=0;game.model.starting_food=0
	var chosen=[]
	for character in helpers.HEROES:
		var card_id=""
		for id in p.CARDS:
			if p.CARDS[id].get("hero",-1)==character:card_id=id
		legendary_offer();p.offer[2]=card_id;game.team_upgrade_picker.refresh()
		if character==1:await create_timer(.3).timeout;await capture("06-legendary-hero-card")
		if character==33:await create_timer(.3).timeout;await capture("09-mountain-king-card")
		var choice=p.choice_level();var count=heroes.bodies.filter(func(body):return body.leased).size()
		check(game.choose_team_upgrade(card_id,choice),"Named hero card summons fighter %d"%character)
		var body=heroes.bodies.back();chosen.append(body)
		check(heroes.bodies.filter(func(candidate):return candidate.leased).size()==count+1 and body.character_id==character,"Exactly the hero named on the card arrives")
		check(not game.choose_team_upgrade(card_id,choice),"Stale hero choice cannot grant twice")
		var handle=heroes.handles[heroes.bodies.find(body)];var state=runtime.unit_state(handle)
		check(state.get("kind",0)==100+character and state.get("hp",0)==body.max_hp,"Hero life is owned by the native army with its own health")
		check(body.team_progression==p and game.model.gold==0 and helpers.active_units().is_empty(),"Hero receives team upgrades without charging or adding ordinary mercenaries")
		check(body.character_models.size()==1,"Only the selected hero's model is prepared")
	check(heroes.left==INF,"Legendary heroes have no fifteen-second summon expiry")
	game.player.select_character(31)
	check(chosen.all(func(body):return body.leased) and chosen.map(func(body):return body.character_id)==helpers.HEROES,"Changing the player preserves every summoned hero's identity")
	var goemon=chosen[0];var projectiles=game.get_node("CharacterProjectiles");var coins=[]
	var remember_coin=func(coin):coins.append(coin)
	projectiles.launched.connect(remember_coin)
	var ticket=goemon.attack_chain.make_ticket("coin");ticket.move_audio=game.move_audio.begin(goemon,"coin","coin_charged")
	var misses=projectiles.misses
	game.throw_coin(true,true,1.0,ticket,false,goemon)
	check(coins.size()==1 and coins[0].hero==goemon and is_equal_approx(coins[0].damage,goemon.combat_tuning("charged_damage")*goemon.damage_multiplier()),"Summoned Goemon's charged coin uses its actual owner and damage while the player is Blademaster")
	check(projectiles.misses==misses,"Hero coin visuals are prepared before the attack")
	projectiles.launched.disconnect(remember_coin);projectiles.release_owner(goemon)
	var center=Vector3.ZERO
	for body in chosen:center+=body.position
	center/=chosen.size()
	var camera=game.camera_rig.camera;camera.projection=Camera3D.PROJECTION_PERSPECTIVE;camera.fov=55
	camera.global_position=center+Vector3(0,55,18);camera.look_at(center+Vector3.UP*3)
	await capture("07-legendary-heroes")
	var targets=[]
	for i in chosen.size():
		var point=chosen[i].position+Vector3(0,0,-3)
		var handle=runtime.spawn(910000+i,0,0,point,1000000000,.4);targets.append(handle)
		game.model.enemies[910000+i]={"id":910000+i,"hp":1000000000.0,"max_hp":1000000000.0,"pos":point,"variant":0}
		runtime.enemy_target(910000+i);runtime.apply_hit(handle,{"element":"ice","status_seconds":60.0})
	runtime.record_events=true;runtime.event_log.clear()
	for frame in 960:
		runtime.integration_tick(1.0/60)
		await process_frame
		if frame==120:await capture("08-legendary-heroes-combat")
	check(chosen.all(func(body):return body.leased),"Heroes remain after sixteen simulated seconds")
	for body in chosen:check(not body.action_history.is_empty(),"Hero autonomously uses existing attacks/skills: %d"%body.character_id)
	check(runtime.event_log.any(func(event):return event.kind=="damage" and event.target_id>=910000 and event.target_id<910000+chosen.size() and event.amount>0),"Hero abilities hit real native enemies")
	var blade=chosen[3];var index=heroes.bodies.find(blade);var old_handle=heroes.handles[index]
	runtime.apply_hit(old_handle,{"amount":1000000.0});heroes.tick(1.0/60)
	check(not blade.leased and not runtime.valid(old_handle),"Defeated hero retires its attacks and native identity")
	for target in targets:
		if runtime.valid(target):runtime.despawn(target)
	await frames(5)
	var pool_count=heroes.bodies.size();var point=helpers.castle_point(0,true)
	check(heroes.reinforce(31,point) and heroes.bodies.size()==pool_count and heroes.handles[index]!=old_handle,"Another Blademaster reuses the retired body with a fresh native handle")
	check(blade.hp==blade.max_hp and blade.action_history.is_empty(),"Reused hero resets health and attack history")
	var layout=game.active_forest_map();game.preview_forest_map(layout,false)
	check(heroes.handles.is_empty() and chosen.all(func(body):return not body.leased),"New run clears every permanent hero")
	check(not runtime.mirror_action.is_connected(heroes._action) and not runtime.mirrors_advanced.is_connected(heroes.tick),"Reset removes hero action and simulation callbacks")
	game.queue_free();current_scene=null;paused=false;await frames(5)
	if FileAccess.file_exists(cfg):DirAccess.remove_absolute(ProjectSettings.globalize_path(cfg))
	print("LEGENDARY_HERO_RESULT checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)
