extends "res://scripts/musashi_tests.gd"

func drain_wave():
	for frame in range(600):
		if game.encounters.pending==0:return
		game.encounters.tick(0)
		await get_tree().physics_frame
	check(false,"Pending wave spawns within its budget")

func capture_survival(label: String):
	if not visual:return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://tests/survival-"+label+".png")

func run():
	visual="--survival-visual" in OS.get_cmdline_user_args()
	get_window().set_flag(Window.FLAG_NO_FOCUS,true)
	game.camera_rig.set_process_unhandled_input(false)
	game.encounters.set_physics_process(false)
	game.tuning=PrototypeTuning.DEFAULTS.duplicate()
	game.tuning.invincible=true;game.tuning.freeze_ai=true
	check(game.gates.is_empty() and game.enemies.is_empty(),"Menu has no portals, guardians or preplaced population")
	await capture_survival("menu")
	game.start_game();game.player.smoke_mode=true
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	var s=game.encounters
	check(s.remaining()==600 and s.wave==1 and s.pending==100,"Fresh run starts at 10:00 with 100 opening enemies")
	check(s.next_wave_in()==10 and s.clock_text(s.remaining())=="10:00","HUD clock and next-wave countdown initialize correctly")
	await wait(.15)
	await drain_wave()
	check(s.total_spawned==100 and game.enemies.size()==100,"Opening wave creates exactly 100 real combatants")
	var safe=true;var starts=[]
	for enemy in game.enemies:
		starts.append(enemy.position)
		if enemy.position.distance_to(game.player.position)<21 or enemy.boss or not enemy.swarm or enemy.model.skeleton!=null:safe=false
	check(safe,"Swarm spawns outside melee range and uses lightweight crowd models")
	game.tuning.freeze_ai=false
	await wait(3)
	var closing=0
	for i in range(game.enemies.size()):
		if game.enemies[i].position.distance_to(game.player.position)<starts[i].distance_to(game.player.position)-1:closing+=1
	check(closing>=80,"At least 80%% of the opening swarm automatically closes on the hero (%d/100)" % closing)
	await capture_survival("wave-01")
	game.tuning.freeze_ai=true
	var at=game.enemies[0].position
	game.show_pause();s.tick(40);await wait(.2)
	check(s.elapsed==0 and s.wave==1 and game.enemies[0].position.is_equal_approx(at),"Pause freezes time, waves and enemy movement")
	game.resume()
	game.show_lab();s.tick(20)
	check(s.elapsed==0,"Prototype Lab freezes the survival clock")
	game.resume()
	s.tick(9.999)
	check(s.wave==1,"No early wave before 10 seconds")
	s.tick(.001)
	check(s.wave==2 and s.total_spawned+s.pending==200,"Exactly 100 additional enemies at 10 seconds")
	s.tick(49.999)
	check(s.wave==6 and s.total_spawned+s.pending==600,"Time jumps catch up every scheduled wave without duplication")
	s.tick(.001)
	check(s.wave==7 and s.wave_size(s.wave)==110 and s.total_spawned+s.pending==710,"At one minute, each wave grows to 110 enemies")
	check(s.clock_text(s.remaining())=="09:00","Countdown displays the correct minute boundary")
	s.tick(539.99)
	check(s.wave==60 and s.wave_size(s.wave)==190 and s.total_spawned+s.pending==8700,"Full run schedules all 60 growing waves (8,700 enemies), without a population cap")
	if "--survival-stress" in OS.get_cmdline_user_args():
		for frame in range(5000):
			if s.pending==0:break
			s.tick(0)
			await get_tree().physics_frame
		check(s.pending==0 and game.enemies.size()==8700,"Worst-case run retains all 8,700 living enemies")
		game.tuning.freeze_ai=false
		var start=Time.get_ticks_usec()
		await wait(2)
		print("SURVIVAL_STRESS simulation_2s_wall_ms=",(Time.get_ticks_usec()-start)/1000.0," physics_ms=",Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)*1000," nodes=",Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
		await capture_survival("stress")
		game.tuning.freeze_ai=true
	s.tick(.01)
	check(game.won and game.paused and not s.active and s.remaining()==0 and s.pending==0,"Zero triggers victory and stops pending spawning")
	s.tick(20);game.resume()
	check(s.wave==60 and s.elapsed==600 and game.paused,"Victory cannot resume or spawn a 61st wave")
	await capture_survival("victory")
	game.restart_area()
	check(not game.won and not game.paused and game.kills==0 and s.remaining()==600 and s.wave==1 and game.enemies.is_empty(),"Restart clears the old crowd, counters and victory state")
	await wait(.15);await drain_wave()
	var combat_target=game.enemies[1]
	combat_target.position=game.player.position+Vector3(0,0,-2.5)
	combat_target.hp=1000;combat_target.max_hp=1000
	game.player.soft_target=false
	await mouse(true);await mouse(false);await wait(1.6)
	check(combat_target.hp==926,"One physical pipe click deals all three combo hits to a swarm enemy")
	combat_target.position=game.player.position+Vector3(0,0,-6)
	var origin=game.player.position
	await key(KEY_T);await wait(.7)
	check(combat_target.hp==766 and game.player.position.distance_to(origin)<.2,"Sky Strike damages shared-renderer enemies and returns to its origin")
	game.player.select_character(2)
	await key(KEY_R);await mouse(true);await wait(.5)
	check(combat_target.hp<766 and is_instance_valid(game.player.musashi.beam),"Edo's held beam damages swarm enemies")
	await mouse(false);await wait(.1)
	game.player.select_character(1)
	# A piercing beam may also kill enemies beyond the intended combat target.
	# Let those deaths settle, then measure this isolated kill relative to them.
	await wait(1);s.tick(0)
	var kills_before=game.kills
	var population_before=game.enemies.size()
	var drops_before=get_tree().get_nodes_in_group("energy_pickups").size()
	var victim=game.enemies[0]
	var hp=victim.hp
	victim.take_hit(10,Vector3.FORWARD,false)
	check(victim.hp==hp-10 and victim.bar.visible,"Shared-renderer enemy takes damage and displays health")
	victim.take_hit(1000,Vector3.FORWARD,true)
	var drop_count=get_tree().get_nodes_in_group("energy_pickups").size()-drops_before
	await wait(1);s.tick(0)
	check(game.kills==kills_before+1 and game.enemies.size()==population_before-1 and s.total_spawned==100,"Dead enemies are removed and do not independently respawn")
	check(drop_count>=1 and drop_count<=5,"Swarm kills drop one to five prototype orbs")
	await game.travel_to(1)
	check(game.area_index==0 and game.gates.is_empty(),"Map travel remains disabled even when requested directly")
	game.tuning.invincible=false;game.player.invuln=0
	game.player.take_hit(1000,Vector3.FORWARD)
	s.tick(20)
	check(game.player.hp<=0 and game.paused and not s.active and not game.won and s.elapsed==0,"Player death stops the run without awarding survival victory")
	await capture_survival("defeat")
	game.show_main_menu();s.tick(20)
	check(not game.playing and not game.paused and not s.active and s.elapsed==0 and game.crowd.batch.multimesh.visible_instance_count==0,"Main menu stops the run and hides the previous crowd")
	game.tuning.invincible=true;game.start_game()
	s.set_physics_process(true)
	await wait(10.25)
	check(s.wave==2 and s.total_spawned==200 and s.remaining()<590,"Live physics clock automatically advances and delivers the second wave")
	game.show_main_menu()
	print("SURVIVAL_RESULT failures=",failures)
	get_tree().quit(1 if failures else 0)
