extends Node

var game: Node
var checks=0
var failures=0

func check(ok: bool,label: String):
	checks+=1
	if not ok:failures+=1;push_error("FAIL: "+label)
	else:print("PASS: ",label)

func near(a: float,b: float)->bool:return absf(a-b)<.000001

func frames(count: int):
	for i in range(count):await get_tree().process_frame

func director():return game.encounters

func prepare():
	Input.action_release("siege_start");Input.action_release("siege_build")
	director().set_physics_process(false)
	game.player.set_physics_process(false);game.player.smoke_mode=true
	game.tuning.freeze_ai=true;game.tuning.invincible=true

func living()->Array:
	return game.enemies.filter(func(actor):return is_instance_valid(actor) and not actor.dead and not actor.is_queued_for_deletion())

func freeze_actors():
	for actor in game.enemies:
		if is_instance_valid(actor):actor.set_physics_process(false)

func start_wave():
	Input.action_release("siege_start");director().update_start_input(0,false)
	Input.action_press("siege_start");director().update_start_input(3,true)

func build(index: int):
	var run=director()
	var mine=index==game.world.cannon_sites.size()
	var pad: Vector3=game.world.mine_build_position if mine else game.world.cannon_sites[index].build_position
	var center: Vector3=game.world.mine_position if mine else game.world.cannon_sites[index].position
	game.reset_player_at(pad);game.player.facing=(center-pad).normalized()
	run.update_build_input(0,false);run.update_build_input(4 if mine else 3,true)

func kill_all():
	for actor in living():actor.take_hit(10000,Vector3.FORWARD,false,{"tower":true})

func cleanup_corpses():
	for actor in game.enemies:
		if is_instance_valid(actor) and actor.dead:actor.queue_free()
	await frames(2)
	for i in range(game.enemies.size()-1,-1,-1):
		if not is_instance_valid(game.enemies[i]):game.enemies.remove_at(i)

func fresh():
	game.restart_area();prepare();await frames(2)

func run():
	game.smoke_test=true;game.tuning=PrototypeTuning.DEFAULTS.duplicate()
	game.defense_hard=false;game.start_mode("defense");prepare();await frames(2)
	await full_campaign()
	await fractional_economy()
	await depleted_power()
	await terminal_precedence()
	await retry_ownership()
	await hard_revival()
	Input.action_release("siege_start");Input.action_release("siege_build")
	game.show_main_menu();await frames(2)
	print("FIRE_SIEGE_CAMPAIGN_RESULT checks=",checks," failures=",failures)
	game.sound_library.cancel();game.music.stop()
	for voice in game.voices:voice.stop()
	# Headless frames can finish before the audio mixer releases WAV playback.
	# Match the game's normal quit_clean shutdown allowance.
	var audio_deadline=Time.get_ticks_msec()+300
	while Time.get_ticks_msec()<audio_deadline:await get_tree().process_frame
	get_tree().quit(1 if failures else 0)

func full_campaign():
	var run=director();var rewards=0.0
	run.queue_wave()
	check(run.wave==0 and run.phase=="setup","Raw legacy queue call cannot launch a wave")
	for number in range(1,11):
		start_wave()
		check(run.wave==number and run.phase=="spawning","Wave %d requires and accepts a fresh manual confirmation" % number)
		var before_spawned=run.total_spawned
		run.tick(.199)
		check(run.total_spawned==before_spawned,"Wave %d has no spawn before the first 0.2-second deadline" % number)
		run.tick(.001);freeze_actors()
		check(run.total_spawned==before_spawned+1,"Wave %d spawns exactly at the first deadline" % number)
		if number==1:
			var breached=living()[0];var kills=game.kills;var gold=run.money
			run.breach(breached);run.breach(breached);run.record_defeat(breached)
			check(run.base_hp==99 and run.run_breaches==1 and game.kills==kills and run.money==gold,"A breach resolves once, costs one integrity and grants no kill credit or gold")
		run.tick(59.8);freeze_actors()
		check(run.total_spawned-before_spawned==300 and run.pending==0 and run.phase=="clearance","Wave %d delivers all 300 actors by 60 seconds with no deferred demand" % number)
		var gold=run.money
		run.tick(3)
		check(run.total_spawned==number*300 and run.money==gold and run.phase=="clearance","Wave %d expiry does not spawn more or settle while actors remain" % number)
		var first=living()[0]
		first.take_hit(10000,Vector3.FORWARD,false,{"tower":true})
		var resolved_kills=run.wave_kills;run.record_defeat(first);run.record_defeat(first)
		check(run.wave_kills==resolved_kills and run.money==gold,"Wave %d duplicate death callbacks cannot duplicate credit or pay kill gold" % number)
		if number==10:
			game.player.hp=0;run.hero_died()
		kill_all()
		check(run.alive_count==0 and run.wave_kills+run.wave_breaches==300,"Wave %d conserves spawned = killed + breached + alive" % number)
		run.tick(0)
		check(near(run.money-gold,number*10),"Wave %d pays its one settlement reward" % number)
		rewards+=run.money-gold
		run.tick(9);run.queue_wave()
		check(run.wave==number and near(run.money,gold+number*10),"Wave %d held Y and stale queue calls cannot carry into another wave or duplicate reward" % number)
		await cleanup_corpses()
	check(run.total_spawned==3000 and run.total_scheduled==3000 and run.total_skipped==0,"Ten real waves schedule and spawn exactly 3000 actors")
	check(run.run_kills==2999 and run.run_breaches==1 and game.kills==2999,"Campaign actor accounting preserves the one breach without kill credit")
	check(near(rewards,550) and near(run.money,560),"All ten rewards sum to 550 and leave the untouched opening wallet at 560")
	check(game.won and run.phase=="complete" and not run.active and game.player.hp==0 and run.revive_left==0,"Final death cannot block victory and terminal state cancels revival")

func fractional_economy():
	await fresh();var run=director()
	build(12)
	check(run.mine_built and near(run.money,0),"Real mine construction debits the opening ten gold")
	start_wave();run.tick(2.5);freeze_actors()
	check(near(run.money,5),"Purchased mine earns five gold in 2.5 spawning seconds")
	build(0)
	check(run.cannons.size()==1 and near(run.money,0),"Earned mine income can purchase the first arrow tower")
	for i in range(10):run.tick(.013)
	freeze_actors()
	check(near(run.money,.247),"Real director preserves fractional 2.00 income minus 0.10 upkeep")
	game.show_pause();var paused_gold=run.money;var paused_time=run.wave_elapsed
	run.tick(10)
	check(near(run.money,paused_gold) and near(run.wave_elapsed,paused_time),"Pause freezes actual economy and spawning clocks")
	game.resume();run.tick(60-run.wave_elapsed);freeze_actors()
	check(run.phase=="clearance" and near(run.money,109.25),"Mine gross income stops at 120 and purchased-tower upkeep accrues over its combat lifetime")
	run.tick(2.5)
	check(near(run.money,109.0),"Clearance charges idle tower upkeep without allowing mine farming")

func depleted_power():
	await fresh();var run=director()
	build(0);var tower=run.cannons[0]
	start_wave();run.tick(60);freeze_actors()
	check(near(run.money,0) and not run.powered,"Idle completed tower exhausts its wallet without debt")
	var target=living()[0]
	target.position=tower.position+Vector3(0,-tower.position.y,-12)
	var shots=tower.shots_fired
	run.tick(1)
	check(tower.shots_fired==shots and near(run.money,0),"Depleted tower cannot fire even when a real target enters range")
	kill_all();run.tick(0);await cleanup_corpses()
	check(near(run.money,10) and run.phase=="setup","Wave settlement restores an empty wallet")
	start_wave();run.tick(.2);freeze_actors()
	target=living()[0];target.position=tower.position+Vector3(0,-tower.position.y,-12)
	run.tick(.001)
	check(tower.shots_fired>shots and run.money>0 and run.powered,"Available reward gold automatically restores tower firing")

func terminal_precedence():
	await fresh();var run=director()
	# Earlier waves were exercised above; this fixture isolates a final-wave
	# simultaneous last resolution and loss of the last integrity point.
	run.wave=9;start_wave();run.tick(60);freeze_actors()
	var actors=living();var last=actors.pop_back()
	for actor in actors:actor.take_hit(10000,Vector3.FORWARD,false,{"tower":true})
	run.base_hp=1;var gold=run.money
	run.breach(last);run.tick(0);run.record_defeat(last)
	check(run.base_hp==0 and run.phase=="defeat" and not game.won and not run.active,"Base failure wins when the last final-wave actor breaches")
	check(near(run.money,gold) and run.wave_kills==299 and run.wave_breaches==1,"Failed final clearance pays no reward and retains exact resolution totals")

func retry_ownership():
	await fresh();var run=director()
	build(4);var old_tower=run.cannons[0]
	start_wave();run.tick(.2);freeze_actors()
	var old_actor=living()[0]
	old_actor.position=old_tower.position+Vector3(0,0,-35)
	old_tower.retire_wave_effects();run.tick(.001)
	check(old_tower.shells.size()==1,"Retry fixture contains an actual in-flight arrow")
	var generation=run.generation
	game.restart_area();prepare()
	check(run.generation>generation and not run.owns(old_actor) and old_tower.shells.is_empty(),"Retry invalidates outgoing actor ownership and retires actual projectiles synchronously")
	old_actor.dead=true;run.record_defeat(old_actor);run.breach(old_actor)
	check(run.wave==0 and run.run_kills==0 and run.run_breaches==0 and near(run.money,10),"Old actor callbacks cannot credit, breach or spend in the replacement run")
	start_wave();run.tick(.2);freeze_actors()
	var replacement=living()[0];var hp=replacement.hp
	old_tower.tick(10,10)
	check(replacement.hp==hp and old_tower.shells.is_empty(),"A queued outgoing tower cannot launch or damage replacement actors")
	await frames(2)

func hard_revival():
	game.defense_hard=true;game.start_mode("defense");prepare();await frames(2)
	var run=director()
	check(run.hard_mode and run.base_hp==50 and near(run.money,10),"Hard retains fifty integrity with the redesigned opening economy")
	start_wave();game.player.hp=0;game.defeat()
	check(run.hero_dead and not run.revive_now(),"Hard hero death continues the run but cannot skip revival")
	run.tick(4.9);freeze_actors()
	check(run.hero_dead and game.player.hp==0 and run.total_spawned==24,"Hard spawning continues while the hero awaits the complete five seconds")
	run.tick(.1);freeze_actors()
	check(not run.hero_dead and game.player.hp==game.player.max_hp and near(game.player.invuln,2),"Hard automatically restores full HP and two seconds of protection at five seconds")
