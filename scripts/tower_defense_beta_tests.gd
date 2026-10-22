extends "res://scripts/tower_defense_tests.gd"

var performance_report={}

func finish_beta(code: int):
	# Match the game's normal audio shutdown so an accelerated headless test
	# does not quit while the audio thread still owns active stream playback.
	game.sound_library.cancel();game.music.stop()
	for voice in game.voices:voice.stop()
	var audio_deadline=Time.get_ticks_msec()+300
	while Time.get_ticks_msec()<audio_deadline:await get_tree().process_frame
	get_tree().quit(code)

func capture_beta(label: String):
	if not visual:return
	game.hud.banner_time=0;game.hud.toast_time=0;game.player.invuln=0
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://tests/tower-defense-beta/"+label+".png")

func capture_defense(label: String):
	await capture_beta(label)

func fill_live_cap(director,limit: int):
	var bounded=true;var ticks=0
	while game.active_enemy_count()<limit and director.pending>0 and ticks<300:
		var before=director.total_spawned
		director.tick(0)
		bounded=bounded and director.total_spawned-before<=8
		ticks+=1
		await frames(1)
	check(bounded,"Beta arrivals are spread across updates with at most eight actors per tick")
	check(game.active_enemy_count()==limit,"Beta arrivals fill the configured live-enemy allowance (%d)" % limit)

func beta_setup():
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://tests/tower-defense-beta"))
	Input.use_accumulated_input=false
	get_window().set_flag(Window.FLAG_NO_FOCUS,true)
	game.camera_rig.set_process_unhandled_input(false)
	game.tuning=PrototypeTuning.DEFAULTS.duplicate()
	game.tuning.invincible=true;game.tuning.freeze_ai=true
	game.start_mode("defense")
	game.encounters.set_physics_process(false)
	game.player.smoke_mode=true
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	await frames(15)

func beta_functional():
	await beta_setup()
	var s=game.encounters
	var hero_id=game.player.get_instance_id()
	check(s.beta_mode and game.world.beta_mode,"Defense launches its accelerated beta configuration")
	check(s.cannons.size()==24 and game.world.cannon_sites.size()==24,"Beta starts with 24 ready cannons")
	var ready=true;var stations={}
	for i in range(game.world.cannon_sites.size()):
		var site=game.world.cannon_sites[i]
		ready=ready and site.lane==1 and s.site_states[i].level==1 and is_instance_valid(s.site_states[i].cannon)
		stations[site.position.z]=int(stations.get(site.position.z,0))+1
	check(ready and stations.size()==6 and stations.values().all(func(n):return n==4),"All 24 built guns occupy six center-lane defense stations with four guns each")
	check(s.money==12000,"Beta provides 12,000 gold for immediate cannon upgrades")
	check(s.wave==0 and s.prep_left>0 and s.prep_left<=4.0 and game.enemies.is_empty(),"Beta opens with a short, enemy-free preparation window")
	var money=s.money;var site=game.world.cannon_sites[0]
	await move_to(site.build_position)
	var cost=s.site_cost(0)
	await key(KEY_F)
	check(s.site_states[0].level==2 and s.cannons.size()==24 and s.money==money-cost,"F upgrades a prebuilt cannon and charges only its upgrade cost")
	await capture_beta("01-ready-cannon-line")
	var prep=s.prep_left
	s.tick(prep-.01)
	check(s.wave==0 and game.active_enemy_count()==0,"The opening swarm respects the brief preparation countdown")
	s.tick(.02)
	check(s.wave==1 and s.total_scheduled==600 and s.total_spawned<=8 and s.pending>0,"A single 600-enemy wave is queued without a synchronous spawn burst")
	await fill_live_cap(s,180)
	check(s.total_spawned==180 and s.pending==420 and s.total_skipped==0,"The 180-actor cap defers the other 420 attackers without discarding the finite wave")
	var central=true;var distant=true
	for actor in living_defenders():
		central=central and actor.defense_lane==1 and absf(actor.position.x)<10
		distant=distant and actor.position.z<=-300
	check(central and distant,"Every beta attacker enters from the distant center approach")
	var pending=s.pending
	for i in range(10):s.tick(0)
	check(s.pending==pending and game.active_enemy_count()==180,"Saturated live capacity never creates additional actors or loses queued arrivals")
	var victim=living_defenders()[0]
	victim.take_hit(1000000,Vector3.FORWARD,false,{"tower":true});s.tick(0)
	check(game.active_enemy_count()==180 and s.pending==pending-1 and s.total_spawned==181,"A defeated actor frees exactly one slot for the next queued arrival")
	var cannon=s.cannons[0];var target=living_defenders()[0]
	target.position=Vector3(0,.1,site.position.z-25);target.velocity=Vector3.ZERO
	target.hp=2000000;target.max_hp=2000000
	cannon.fire_at(target)
	var shell=cannon.shells[-1];var age=shell.age;var at=shell.position
	var elapsed=s.elapsed;pending=s.pending;var cooldown=cannon.cooldown
	game.show_pause();s.tick(10);cannon.tick(10);await frames(10)
	check(s.elapsed==elapsed and s.pending==pending and shell.age==age and shell.position==at and cannon.cooldown==cooldown,"Pause freezes the beta wave queue, clock, cannon, and in-flight projectile")
	game.resume()
	if visual:
		game.camera_rig.set_process(false)
		game.camera_rig.camera.global_position=Vector3(48,95,-80)
		game.camera_rig.camera.look_at(Vector3(0,0,-190))
		await frames(2);await capture_beta("02-central-swarm")
		game.camera_rig.set_process(true)
	# Resolve the finite roster through the actual enemy death path. The
	# artillery ticket avoids unrelated hero XP and hundreds of death effects.
	var ticks=0
	while s.active and ticks<1200:
		for actor in living_defenders():actor.take_hit(1000000000,Vector3.FORWARD,false,{"tower":true})
		s.tick(0);ticks+=1;await frames(1)
	check(s.total_spawned==600 and s.total_scheduled==600 and s.pending==0 and s.alive_count==0,"All 600 queued enemies are eventually delivered and resolved exactly once")
	check(s.wave==1 and s.phase=="complete" and not s.active and game.won and game.paused,"Clearing the one beta wave opens victory and stops the run")
	var spawned=s.total_spawned;s.tick(3600);s.queue_wave();game.resume()
	check(s.total_spawned==spawned and s.wave==1 and not s.active and game.paused,"A completed beta cannot resume or schedule a second wave")
	await capture_beta("03-beta-complete")
	game.restart_area();s=game.encounters;s.set_physics_process(false);await frames(15)
	check(not game.won and not game.paused and s.active and s.wave==0 and s.total_spawned==0 and s.money==12000 and s.cannons.size()==24 and s.site_states.all(func(state):return state.level==1),"Retry restores the finite beta wave, 24 base-level guns, gold, and victory state")
	game.tuning.max_active_enemies=32;game.restart_area();s=game.encounters;s.set_physics_process(false)
	s.tick(s.prep_left+.01);await fill_live_cap(s,32)
	check(game.active_enemy_limit==32 and game.active_enemy_count()==32 and s.pending==568,"Beta also respects a smaller user-configured enemy limit")
	game.tuning.max_active_enemies=200;game.restart_area();game.encounters.set_physics_process(false);await frames(15)
	await shared_controls()
	check(game.player.get_instance_id()==hero_id,"Beta preserves the same hero and shared character controller")
	game.show_main_menu()
	print("TOWER_DEFENSE_BETA_RESULT failures=",failures)
	await finish_beta(1 if failures else 0)

func summary_stats(values: Array)->Dictionary:
	var total=0.0
	for value in values:total+=float(value)
	values.sort()
	return {"mean":total/maxi(1,values.size()),"p95":values[mini(values.size()-1,int(values.size()*.95))],"max":values[-1]}

func benchmark_population(population: int,close_view: bool=false):
	game.restart_area()
	var s=game.encounters
	s.set_physics_process(false);game.active_enemy_limit=population
	game.tuning.freeze_ai=true;s.tick(s.prep_left+.01)
	await fill_live_cap(s,population)
	var stations=[-170.0,-100.0,-30.0,40.0,110.0,180.0]
	var per_station=population/6
	var actors=living_defenders()
	for i in range(actors.size()):
		var actor=actors[i];var station=i/per_station;var slot=i%per_station
		actor.position=Vector3((float(slot%6)-2.5)*1.3,.1,stations[station]-65-float(slot/6)*1.8)
		if close_view:actor.position=Vector3((float(i%9)-4)*1.0,.1,-181-float(i/9)*1.15)
		actor.defense_offset=Vector3(actor.position.x,0,0);actor.defense_waypoint=1
		actor.hp=2000000;actor.max_hp=2000000;actor.velocity=Vector3.ZERO
		actor.stun=0;actor.frozen_left=0
	await move_to(Vector3(9,0,-164) if close_view else Vector3(40,0,20))
	game.camera_rig.set_process(false)
	var eye=Vector3(22,13,-147) if close_view else Vector3(135,260,360)
	var aim=Vector3(0,1,-178) if close_view else Vector3(0,0,-25)
	game.camera_rig.camera.global_position=eye
	game.camera_rig.camera.look_at(aim);game.camera_rig.camera.fov=60
	game.tuning.freeze_ai=false;s.set_physics_process(true)
	# Warm shaders, targeting and real artillery impacts before collecting data.
	var warm_until=Time.get_ticks_msec()+2200
	while Time.get_ticks_msec()<warm_until:await get_tree().process_frame
	var samples={"frame_ms":[],"process_ms":[],"physics_ms":[],"render_cpu_ms":[],"gpu_ms":[],"draw_calls":[]}
	var peak_nodes=0;var peak_shells=0;var peak_blasts=0;var peak_projectiles=0
	var min_enemies=population;var max_enemies=0;var fired={}
	var shots_before=0;var scans_before=0
	for gun in s.cannons:shots_before+=gun.shots_fired;scans_before+=gun.acquire_scans
	var now=Time.get_ticks_usec();var last=now;var until=now+4000000;var count=0
	var viewport=get_viewport().get_viewport_rid()
	while count<480 and (Time.get_ticks_usec()<until or count<120):
		await get_tree().process_frame
		now=Time.get_ticks_usec();samples.frame_ms.append((now-last)/1000.0);last=now
		samples.process_ms.append(Performance.get_monitor(Performance.TIME_PROCESS)*1000)
		samples.physics_ms.append(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)*1000)
		samples.render_cpu_ms.append(RenderingServer.viewport_get_measured_render_time_cpu(viewport)+RenderingServer.get_frame_setup_time_cpu())
		samples.gpu_ms.append(RenderingServer.viewport_get_measured_render_time_gpu(viewport))
		samples.draw_calls.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
		var shell_count=0;var blast_count=0
		for gun in s.cannons:
			shell_count+=gun.shells.size();blast_count+=gun.blasts.size()
			if gun.shots_fired>0:fired[gun.get_instance_id()]=true
		peak_shells=maxi(peak_shells,shell_count);peak_blasts=maxi(peak_blasts,blast_count)
		peak_nodes=maxi(peak_nodes,int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)))
		peak_projectiles=maxi(peak_projectiles,get_tree().get_nodes_in_group("projectiles").size()+shell_count)
		var active=game.active_enemy_count();min_enemies=mini(min_enemies,active);max_enemies=maxi(max_enemies,active)
		count+=1
	var row={"sample_frames":count,"live_enemies_min":min_enemies,"live_enemies_max":max_enemies,"cannons_installed":s.cannons.size(),"cannons_firing":fired.size(),"peak_nodes":peak_nodes,"peak_shells":peak_shells,"peak_blasts":peak_blasts,"peak_projectiles":peak_projectiles,"camera_eye":[eye.x,eye.y,eye.z],"camera_target":[aim.x,aim.y,aim.z]}
	for metric in samples:row[metric]=summary_stats(samples[metric])
	row.gpu_timing_available=row.gpu_ms.max>0
	var shots_after=0;var scans_after=0
	for gun in s.cannons:shots_after+=gun.shots_fired;scans_after+=gun.acquire_scans
	row.shots_during_sample=shots_after-shots_before;row.target_scans_during_sample=scans_after-scans_before
	var label="close_frontline_%d" % population if close_view else "active_%d" % population
	performance_report[label]=row
	print("BETA_PROFILE %s " % label,JSON.stringify(row))
	check(min_enemies==population and max_enemies==population,"Rendered benchmark maintains %d real moving attackers throughout its sample" % population)
	if close_view:
		check(fired.size()>=4 and row.shots_during_sample>=4 and s.cannons.size()==24,"Frontline benchmark retains all 24 guns and active artillery against the close 180-enemy swarm")
	else:check(fired.size()==24 and row.shots_during_sample>=24,"All 24 cannons fire real artillery during the %d-enemy benchmark" % population)
	await capture_beta("benchmark-"+label)
	s.set_physics_process(false)

func beta_benchmark():
	if DisplayServer.get_name()=="headless":
		check(false,"Performance evidence requires the actual renderer; run without --headless")
		get_tree().quit(1);return
	visual=true
	await beta_setup()
	game.settings.quality=1;game.settings.fullscreen=false
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	get_window().size=Vector2i(1280,800)
	game.apply_quality()
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED);Engine.max_fps=0
	RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(),true)
	performance_report={"date":"2026-10-04","renderer":RenderingServer.get_current_rendering_method(),"resolution":"1280x800","quality":1,"vsync":"disabled","camera_eye":[135,260,360],"camera_target":[0,0,-25],"fixture":"Live AI, normal artillery, durable targets distributed across all six stations; same world/camera/quality for both populations."}
	await benchmark_population(36)
	await benchmark_population(180)
	await benchmark_population(180,true)
	performance_report["mean_frame_ratio_180_to_36"]=performance_report.active_180.frame_ms.mean/performance_report.active_36.frame_ms.mean
	performance_report["p95_frame_ratio_180_to_36"]=performance_report.active_180.frame_ms.p95/performance_report.active_36.frame_ms.p95
	FileAccess.open("res://tests/tower-defense-beta/performance.json",FileAccess.WRITE).store_string(JSON.stringify(performance_report,"\t"))
	print("TOWER_DEFENSE_BETA_BENCHMARK failures=",failures)
	game.show_main_menu()
	await finish_beta(1 if failures else 0)

func run():
	visual="--tower-defense-beta-visual" in OS.get_cmdline_user_args()
	if "--tower-defense-beta-benchmark" in OS.get_cmdline_user_args():await beta_benchmark()
	else:await beta_functional()
