extends "res://scripts/tower_defense_beta_tests.gd"

var progression_rows=[]
var melee_damage={}

func capture_beta(label: String):
	if not visual:return
	game.hud.banner_time=0;game.hud.toast_time=0;game.player.invuln=0
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://tests/defense-fire/"+label+".png")

func prepare_fire_suite():
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://tests/defense-fire"))
	await beta_setup()

func sample_wave(director,number: int)->Ninja:
	for i in range(15):
		if living_defenders().any(func(actor):return actor.variant==0):break
		director.tick(0);await frames(1)
	var actor: Ninja=living_defenders().filter(func(enemy):return enemy.variant==0)[0]
	var profile=director.wave_profile(number)
	var shape: CollisionShape3D=actor.find_children("*","CollisionShape3D",true,false)[0]
	var row={"wave":number,"scale":actor.defense_scale,"radius":shape.shape.radius,"height":shape.shape.height,"model_scale":actor.model.scale.x,"hp":actor.max_hp,"damage":actor.defense_damage_multiplier,"speed":director.defense_speed(actor)}
	var correct=is_equal_approx(row.scale,profile["size"]) and is_equal_approx(row.radius,.45*profile["size"]) and is_equal_approx(row.height,1.8*profile["size"]) and is_equal_approx(shape.position.y,row.height*.5)
	correct=correct and actor.scale.is_equal_approx(Vector3.ONE) and is_equal_approx(row.model_scale,profile["size"])
	correct=correct and is_equal_approx(row.hp,game.tuning.enemy_hp*5*.45*profile.health) and is_equal_approx(row.damage,profile.damage) and is_equal_approx(row.speed,8.5*profile.speed)
	check(correct,"Wave %d applies its profile to real capsule, model, health, damage, and movement speed" % number)
	if not progression_rows.is_empty():
		var previous=progression_rows[-1]
		check(row.scale>previous.scale and row.hp>previous.hp and row.damage>previous.damage and row.speed>previous.speed,"Wave %d is strictly larger and stronger than the preceding wave" % number)
	progression_rows.append(row)
	return actor

func real_melee_probe(actor: Ninja,number: int):
	var p=game.player;var saved_position=p.position;var saved_hp=p.hp
	p.position=Vector3(0,.06,102);p.velocity=Vector3.ZERO;p.invuln=0
	p.forward_dash.immunity_left=0;p.sky_strike.cancel()
	actor.position=Vector3(0,.06,100);actor.velocity=Vector3.ZERO
	actor.state="strike";actor.attack_kind="dash";actor.attack_dir=Vector3.BACK
	actor.timer=.25;actor.attack_hit=false;actor.stun=0;actor.impact_pause=0
	game.tuning.invincible=false;game.tuning.freeze_ai=false
	actor._physics_process(.01)
	melee_damage[number]=saved_hp-p.hp
	check(is_equal_approx(melee_damage[number],11*actor.defense_damage_multiplier*game.tuning.enemy_damage),"Wave %d melee delivers its scaled damage through the actual strike and hero health code" % number)
	game.tuning.invincible=true;game.tuning.freeze_ai=true
	p.hp=saved_hp;p.position=saved_position;p.velocity=Vector3.ZERO;p.invuln=0

func large_gap_probe(actor: Ninja):
	var clear=true
	for z in [-170,-100,-30,40,110,180]:
		for x in [-4.4,0.0,4.4]:
			var from=Transform3D(Basis.IDENTITY,Vector3(x,.06,z-4))
			clear=clear and not actor.test_move(from,Vector3(0,0,8))
	check(clear,"The largest wave-10 capsule fits through every center-lane wall gap, including outer formation positions")

func inspect_flame_asset(flame)->AnimationPlayer:
	var animation_player: AnimationPlayer=null
	var animated_tracks=0;var loop_name=""
	for candidate in flame.find_children("*","AnimationPlayer",true,false):
		for animation_name in candidate.get_animation_list():
			# Godot's scene importer consumes the Blender _loop name suffix.
			if animation_name!="flame" and "flame_loop" not in animation_name:continue
			animation_player=candidate;loop_name=animation_name
			var animation=candidate.get_animation(animation_name)
			for track in range(animation.get_track_count()):
				if animation.track_get_key_count(track)>2:animated_tracks+=1
	var assets=[];var triangles=0
	for node in flame.find_children("*","MeshInstance3D",true,false):
		if node.mesh==null:continue
		for surface in range(node.mesh.get_surface_count()):
			var arrays=node.mesh.surface_get_arrays(surface)
			var indices=arrays[Mesh.ARRAY_INDEX]
			triangles+=indices.size()/3 if indices!=null and indices.size()>0 else arrays[Mesh.ARRAY_VERTEX].size()/3
	for node in flame.find_children("*","Node3D",true,false):
		if node.scene_file_path.ends_with("fire_tower.glb") or node.scene_file_path.ends_with("fire_stream.glb"):assets.append(node.scene_file_path)
	check(assets.size()>=2 and triangles>0,"The flame defense instantiates the authored Blender tower and flame-stream meshes")
	check(animation_player!=null and animated_tracks>0,"The imported Blender flame_loop contains keyed animation tracks")
	print("FIRE_ASSET_QA triangles=",triangles," keyed_tracks=",animated_tracks," loop=",loop_name," scenes=",assets)
	return animation_player

func run_functional():
	await prepare_fire_suite()
	var s=game.encounters
	check(s.beta_mode and s.MAX_WAVES==10 and s.wave==0,"Center Siege starts a finite ten-wave campaign")
	check(s.tower_count("fire")==12 and s.tower_count("cannon")==12 and s.cannons.size()==24,"Six defense stations start with twelve flame towers and twelve artillery cannons")
	var kinds=true
	for i in range(s.site_states.size()):
		kinds=kinds and s.site_states[i].kind==("fire" if i%4 in [1,2] else "cannon")
	check(kinds,"Inner wall mounts use fire towers and outer mounts use artillery")
	var flame_index=1;var flame=s.site_states[flame_index].cannon
	var animation_player=inspect_flame_asset(flame)
	var site=game.world.cannon_sites[flame_index]
	await move_to(site.build_position)
	var before_money=s.money;var price=s.site_cost(flame_index)
	await key(KEY_F)
	check(s.site_states[flame_index].level==2 and flame.level==2 and s.money==before_money-price,"Physical F upgrades a fire tower through the shared purchase economy")
	await capture_beta("01-mixed-defense-line")
	s.tick(s.prep_left+.01)
	for number in range(1,11):
		check(s.wave==number and s.total_scheduled==600*number,"Wave %d schedules exactly 600 additional center-lane attackers" % number)
		var actor=await sample_wave(s,number)
		if number==1:
			await fill_live_cap(s,180)
			check(s.pending==420 and s.peak_spawn_count<=8 and living_defenders().all(func(e):return e.defense_lane==1),"The larger campaign preserves central-only arrivals, eight-spawn batches, and the 180-enemy cap")
			await real_melee_probe(actor,number)
			await flame_combat_checks(flame,animation_player,site)
		if number==10:
			await real_melee_probe(actor,number)
			var large=living_defenders().filter(func(e):return e.variant==2)[0]
			large_gap_probe(large)
			check(melee_damage[10]>melee_damage[1],"Final-wave attacks cause more real health loss than opening-wave attacks")
			if visual:
				actor.position=Vector3(0,.06,-155)
				await move_to(Vector3(6,0,-149))
				game.camera_rig.set_process(false)
				game.camera_rig.camera.global_position=Vector3(11,7,-141)
				game.camera_rig.camera.look_at(Vector3(0,2,-155))
				await capture_beta("04-wave-ten-scale")
				game.camera_rig.set_process(true)
		var cycles=0
		while s.phase=="wave" and cycles<1200:
			for remaining in living_defenders():remaining.take_hit(1000000000,Vector3.FORWARD,false,{"tower":true})
			s.tick(0);cycles+=1;await frames(1)
		check(s.total_spawned==600*number and s.run_kills==600*number and s.pending==0 and s.alive_count==0,"Wave %d fully delivers and resolves its finite roster without losing queued enemies" % number)
		if number<10:
			check(s.active and s.phase=="rest" and not game.won and is_equal_approx(s.next_wave_in(),12),"Wave %d offers twelve seconds to rebuild without declaring an early victory" % number)
			s.tick(11.99)
			check(s.wave==number and living_defenders().is_empty(),"Wave %d cannot start its successor before the rebuild timer expires" % number)
			s.tick(.02)
	check(s.wave==10 and s.phase=="complete" and not s.active and game.won and game.paused and s.total_spawned==6000,"Victory occurs only after all ten waves and all 6,000 attackers are resolved")
	s.tick(10000);s.queue_wave();game.resume()
	check(s.wave==10 and s.total_scheduled==6000 and s.total_spawned==6000 and game.paused,"The completed campaign cannot resume or create an eleventh wave")
	await capture_beta("05-ten-wave-victory")
	FileAccess.open("res://tests/defense-fire/progression.json",FileAccess.WRITE).store_string(JSON.stringify(progression_rows,"\t"))
	game.restart_area();s=game.encounters;s.set_physics_process(false);await frames(15)
	check(s.wave==0 and s.run_kills==0 and s.run_breaches==0 and s.total_spawned==0 and s.tower_count("fire")==12 and s.tower_count("cannon")==12 and s.site_states.all(func(state):return state.level==1) and not game.won,"Retry restores wave one, both tower types, base upgrades, and campaign counters")
	await shared_controls()
	game.show_main_menu()
	print("DEFENSE_FIRE_RESULT failures=",failures)
	await finish_beta(1 if failures else 0)

func flame_combat_checks(flame,animation_player,site):
	var actors=living_defenders();var front=actors[0];var rear=actors[1];var outside=actors[2]
	front.position=Vector3(0,.1,site.position.z-23)
	rear.position=Vector3(site.position.x,.1,site.position.z+16)
	outside.position=Vector3(site.position.x+35,.1,site.position.z-15)
	for actor in [front,rear,outside]:actor.hp=5000;actor.max_hp=5000;actor.velocity=Vector3.ZERO
	flame.retire_wave_effects();flame.fire_at(front);flame.target_clock=1000
	var poses={}
	for node in flame.flame_visual.find_children("*","Node3D",true,false):poses[node.get_instance_id()]=node.transform
	for i in range(10):flame.tick(.05);await frames(1)
	var animated=false
	for node in flame.flame_visual.find_children("*","Node3D",true,false):
		if poses.has(node.get_instance_id()) and not node.transform.is_equal_approx(poses[node.get_instance_id()]):animated=true
	check(front.hp<5000 and rear.hp==5000 and outside.hp==5000,"Real flame pulses damage the forward cone while sparing targets behind and outside it")
	check(flame.shells.is_empty() and flame.damage_pulses>0 and flame.burst_left>0,"The flame tower deals continuous burst damage without artillery shells")
	check(animation_player!=null and flame.animation_seconds>0 and animated,"The active jet advances Blender keyframes and visibly changes its authored mesh transforms")
	if visual:
		game.camera_rig.set_process(false)
		game.camera_rig.camera.global_position=site.position+Vector3(20,10,18)
		game.camera_rig.camera.look_at(site.position+Vector3(2,1,-9))
		await capture_beta("02-blender-flame-burst")
		game.camera_rig.set_process(true)
	var hp=front.hp;var burst=flame.burst_left;var clock=flame.animation_seconds
	var animation_position=animation_player.current_animation_position if animation_player!=null else 0.0
	game.show_pause();flame.tick(2);await frames(12)
	check(front.hp==hp and flame.burst_left==burst and flame.animation_seconds==clock and (animation_player==null or animation_player.current_animation_position==animation_position),"Pause freezes flame damage, burst time, and the imported animation")
	game.resume();flame.retire_wave_effects()
	front.position=Vector3(0,.1,site.position.z-23);front.velocity=Vector3.ZERO
	flame.fire_at(front);flame.target_clock=1000
	var obstruction_position=flame.flame_origin.lerp(front.position+Vector3.UP,.5)
	var obstruction=Geo.box(game,obstruction_position,Vector3(22,12,1),Geo.mat("596158"),true)
	await frames(2);hp=front.hp
	for i in range(10):flame.tick(.05);await frames(1)
	check(front.hp==hp and flame.flame_visual.scale.z<flame.attack_range()/6.0,"A physical wall blocks flame damage and truncates the visible fire stream")
	await capture_beta("03-cover-blocks-flame")
	flame.retire_wave_effects();obstruction.queue_free();await frames(2)
	front.hp=1;front.position=Vector3(0,.1,site.position.z-23)
	var money=game.encounters.money;var hero_hp=game.player.hp;var hero_kills=game.player.progression.total_kills
	flame.fire_at(front);flame.target_clock=1000;flame.tick(.05)
	check(front.dead and game.encounters.money==money+game.encounters.KILL_REWARD,"A real flame kill pays exactly one enemy bounty")
	check(game.player.hp==hero_hp and game.player.progression.total_kills==hero_kills,"Flame kills preserve the artillery rules for hero healing and personal progression")
	flame.retire_wave_effects()

func run_fire_benchmark():
	if DisplayServer.get_name()=="headless":
		check(false,"Mixed-defense performance requires an actual renderer")
		get_tree().quit(1);return
	visual=true;await prepare_fire_suite()
	game.settings.quality=1;game.settings.fullscreen=false
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	get_window().size=Vector2i(1280,800);game.apply_quality()
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED);Engine.max_fps=0
	RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(),true)
	var s=game.encounters
	# Progression itself is exercised from wave one in the functional suite;
	# this fixture starts directly at the most expensive final-wave profile.
	s.wave=9;s.phase="rest";s.prep_left=0;s.tick(0)
	await fill_live_cap(s,180)
	var actors=living_defenders();var stations=[-170.0,-100.0,-30.0,40.0,110.0,180.0]
	for i in range(actors.size()):
		var actor=actors[i];var station=i/30;var slot=i%30
		actor.position=Vector3((float(slot%6)-2.5)*1.3,.1,stations[station]-24-float(slot/6)*1.8)
		actor.defense_offset=Vector3(actor.position.x,0,0);actor.defense_waypoint=1
		actor.hp=2000000;actor.max_hp=2000000;actor.velocity=Vector3.ZERO;actor.stun=0
	await move_to(Vector3(35,0,10))
	game.camera_rig.set_process(false)
	game.camera_rig.camera.global_position=Vector3(90,200,270)
	game.camera_rig.camera.look_at(Vector3(0,0,-15));game.camera_rig.camera.fov=64
	game.tuning.freeze_ai=false;s.set_physics_process(true)
	var warm_until=Time.get_ticks_msec()+2200
	while Time.get_ticks_msec()<warm_until:await get_tree().process_frame
	var samples={"frame_ms":[],"process_ms":[],"physics_ms":[],"render_cpu_ms":[],"gpu_ms":[],"draw_calls":[]}
	var peak_nodes=0;var peak_shells=0;var peak_flames=0;var minimum=180;var maximum=0
	var firing={};var initial_shots={};var damage_before=0;var animation_before=0.0
	for tower in s.cannons:
		initial_shots[tower.get_instance_id()]=tower.shots_fired
		if tower is DefenseFlameTower:damage_before+=tower.damage_pulses;animation_before+=tower.animation_seconds
	var until=Time.get_ticks_usec()+4000000;var last=Time.get_ticks_usec();var count=0
	var viewport=get_viewport().get_viewport_rid()
	while count<480 and (Time.get_ticks_usec()<until or count<120):
		await get_tree().process_frame
		var now=Time.get_ticks_usec();samples.frame_ms.append((now-last)/1000.0);last=now
		samples.process_ms.append(Performance.get_monitor(Performance.TIME_PROCESS)*1000)
		samples.physics_ms.append(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)*1000)
		samples.render_cpu_ms.append(RenderingServer.viewport_get_measured_render_time_cpu(viewport)+RenderingServer.get_frame_setup_time_cpu())
		samples.gpu_ms.append(RenderingServer.viewport_get_measured_render_time_gpu(viewport))
		samples.draw_calls.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
		var shells=0;var flames=0
		for tower in s.cannons:
			shells+=tower.shells.size()
			if tower.shots_fired>initial_shots[tower.get_instance_id()]:firing[tower.get_instance_id()]=tower is DefenseFlameTower
			if tower is DefenseFlameTower and tower.burst_left>0:flames+=1
		peak_nodes=maxi(peak_nodes,int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)))
		peak_shells=maxi(peak_shells,shells);peak_flames=maxi(peak_flames,flames)
		var active=game.active_enemy_count();minimum=mini(minimum,active);maximum=maxi(maximum,active)
		count+=1
	var flame_fired=0;var cannon_fired=0;var pulses=0;var animation_time=0.0
	for key in firing:
		if firing[key]:flame_fired+=1
		else:cannon_fired+=1
	for tower in s.cannons:
		if tower is DefenseFlameTower:pulses+=tower.damage_pulses;animation_time+=tower.animation_seconds
	var report={"date":"2026-10-04","renderer":RenderingServer.get_current_rendering_method(),"resolution":"1280x800","quality":1,"vsync":"disabled","wave":s.wave,"enemy_scale":s.wave_profile(10)["size"],"sample_frames":count,"live_enemies_min":minimum,"live_enemies_max":maximum,"flame_towers_firing":flame_fired,"cannons_firing":cannon_fired,"peak_nodes":peak_nodes,"peak_shells":peak_shells,"peak_active_flames":peak_flames,"flame_damage_pulses":pulses-damage_before,"blender_animation_seconds":animation_time-animation_before,"fixture":"180 live final-wave actors with durable health distributed across all six stations; 12 fire towers and 12 cannons use normal combat logic."}
	for metric in samples:report[metric]=summary_stats(samples[metric])
	report.gpu_timing_available=report.gpu_ms.max>0
	check(minimum==180 and maximum==180 and s.wave==10,"The rendered late-wave benchmark retains 180 real scaled attackers")
	check(flame_fired==12 and cannon_fired==12,"All twelve flame towers and twelve cannons fire during the measured benchmark")
	check(report.flame_damage_pulses>0 and report.blender_animation_seconds>0,"Performance measurement includes real flame damage checks and animated Blender jets")
	FileAccess.open("res://tests/defense-fire/performance.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("DEFENSE_FIRE_PROFILE ",JSON.stringify(report))
	await capture_beta("benchmark-wave-ten-mixed-defenses")
	game.show_main_menu();print("DEFENSE_FIRE_BENCHMARK failures=",failures)
	await finish_beta(1 if failures else 0)

func run():
	visual="--defense-fire-visual" in OS.get_cmdline_user_args() or "--tower-defense-beta-visual" in OS.get_cmdline_user_args()
	if "--defense-fire-benchmark" in OS.get_cmdline_user_args() or "--tower-defense-beta-benchmark" in OS.get_cmdline_user_args():await run_fire_benchmark()
	else:await run_functional()
