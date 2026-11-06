extends "res://scripts/recovered_leaders_tests.gd"
const Model=preload("res://scripts/forest/forest_model.gd")
const Camps=preload("res://scripts/forest/forest_camp_prototype.gd")
const PORTALS=[{"x":0,"z":24,"rotation":0},{"x":24,"z":0,"rotation":3},{"x":0,"z":-24,"rotation":2},{"x":-24,"z":0,"rotation":1}]

func fresh(camps:bool=false,spots:int=4,total:int=83):
	var model=Model.new();model.reset(42,{"waves":[[total,0,0,0,0,0,0,0,0,0]]},Camps.layout() if camps else {},false)
	if not camps:model.portals=PORTALS.slice(0,spots).duplicate(true)
	model.start_wave();model.waves.random_spawn_clock=100000;return model # Isolate castle group gates from map arrivals.

func clear_exits(model):
	for enemy in model.enemies.values():enemy.pos=Vector3.ZERO

func fill_groups(model)->int:
	var count=0
	for attempt in 30:
		clear_exits(model)
		var released:int=model.waves.spawn_batch();count+=released
		if released==0 or model.waves.spawn_groups.values().all(func(group):return group.members.size()==group.target_size):break
	return count

func source_counts(model)->Array:
	var counts=[0,0,0,0]
	for enemy in model.enemies.values():counts[enemy.portal_index]+=1
	return counts

func model_checks():
	var model=fresh();var waves=model.waves
	waves.tick(0,model.hero_position)
	check(not model.enemies.is_empty(),"The first group arrives on START without a countdown")
	fill_groups(model)
	check(source_counts(model)==[10,10,10,10] and waves.pending==43,"Each of four spots releases ten enemies: forty total")
	var first=waves.spawn_groups[0].members.keys();var other_groups=[]
	for source in [1,2,3]:other_groups.append(waves.spawn_groups[source].members.keys())
	clear_exits(model);waves.tick(30,model.hero_position)
	check(model.enemies.size()==40 and waves.spawn_batch()==0,"All four spots wait after their own first ten")
	waves.enemy_started_attack(-1);waves.enemy_started_attack(0);waves.enemy_started_attack(999999)
	check(waves.spawn_batch()==0,"Player, allied and unrelated attacks cannot open a spot's gate")
	for i in 9:model.enemies.erase(first[i])
	check(waves.spawn_batch()==0,"One surviving enemy still waits to start attacking")
	waves.enemy_started_attack(first[9])
	check(fill_groups(model)==11 and waves.pending==32 and source_counts(model)==[12,10,10,10],"An attack at one spot releases only that spot's next eleven")
	var second=model.enemies[waves.spawn_groups[0].members.keys()[0]]
	check(second.reinforcement_group==2 and is_equal_approx(second.hp,waves.role_stats(0).hp*1.2) and is_equal_approx(second.damage_scale,1.1) and second.xp_reward_tenths==12,"Second group snapshots stronger health, damage and XP")
	check(model.enemies[first[9]].reinforcement_group==1 and model.enemies[first[9]].xp_reward_tenths==10,"Surviving older enemies keep their original strength and reward")
	for source in [1,2,3]:check(waves.spawn_groups[source].members.keys()==other_groups[source-1],"Spot %d keeps its own waiting group"%source)
	check(model.enemies[other_groups[0][0]].reinforcement_group==1,"Another entrance retains opening strength")
	waves.enemy_started_attack(first[9]);clear_exits(model)
	check(waves.spawn_batch()==0,"Attacks from an older group cannot release its spot's newer group")
	waves.enemy_started_attack(other_groups[0][0])
	check(fill_groups(model)==11 and waves.pending==21 and source_counts(model)==[12,21,10,10],"A second spot advances independently")
	for id in waves.spawn_groups[0].members:model.enemies[id].hp=0
	check(fill_groups(model)==12 and waves.pending==9,"A wiped-out group grows to twelve at only its own spot")
	check(model.enemies[waves.spawn_groups[0].members.keys()[0]].xp_reward_tenths==14,"A wiped-out second group advances rewards exactly once")
	waves.enemy_started_attack(other_groups[1][0]);waves.enemy_started_attack(other_groups[2][0])
	check(fill_groups(model)==9 and waves.pending==0,"Simultaneous spots share the exact final remainder without overspawning")
	check(model.balance.waves[0]==[83,0,0,0,0,0,0,0,0,0] and waves.spawned==83,"Exact wave totals and saved composition are preserved")
	model.enemies.clear();waves.tick(60,model.hero_position)
	check(model.phase=="victory","The final partial groups still allow normal victory")
	model.phase="preparing";model.wave=0;model.start_wave()
	check(waves.spawn_groups.is_empty(),"Starting a wave clears all previous groups and engagement latches")
	check(fill_groups(model)==40 and waves.spawn_groups[0].target_size==10,"A new numbered wave restarts every spot at ten")
	check(model.enemies.values().all(func(enemy):return enemy.reinforcement_group==1 and enemy.damage_scale==1 and enemy.xp_reward_tenths==10),"Fresh groups reset strength and rewards")
	model=fresh(false,1,23);waves=model.waves
	for i in 239:waves.spawn_enemy(0,Vector3.ZERO)
	check(waves.spawn_batch()==1 and waves.pending==22,"An active cap admits only the available slot")
	var member=waves.spawn_groups[0].members.keys()[0];waves.enemy_started_attack(member)
	for id in model.enemies.keys():
		if id!=member:model.enemies.erase(id)
	check(fill_groups(model)==9 and waves.spawn_groups[0].members.size()==10 and waves.pending==13,"A partial group resumes without exceeding ten")
	check(model.enemies.values().all(func(enemy):return enemy.reinforcement_group==1),"Capacity retries never increase strength partway through a group")
	check(fill_groups(model)==11,"Attack startup while a group was filling releases eleven next")
	model=fresh();waves=model.waves
	var portal=model.portals[0];var cell=model.cell_of(waves.routes.exit_point(portal,0))
	for x in range(-4,5):
		for z in range(-4,5):model.trees[cell+Vector2i(x,z)]=1.0
	model.rebuild_navigation();fill_groups(model)
	check(source_counts(model)==[0,10,10,10] and waves.pending==53,"A blocked spot consumes no slots and does not block the other three")
	model.trees.clear();model.rebuild_navigation()
	check(fill_groups(model)==10 and source_counts(model)==[10,10,10,10],"Clearing the blocked spot fills only its own first ten")
	model=fresh(true);waves=model.waves
	check(fill_groups(model)==30 and waves.pending==53,"Three-camp maps release ten from each camp")
	var destroyed=waves.spawn_groups[0].members.keys()[0]
	model.damage_enemy_objective(0,99999);waves.enemy_started_attack(destroyed)
	check(fill_groups(model)==0,"Destroying one camp stops its reinforcements without releasing other groups")
	waves.enemy_started_attack(waves.spawn_groups[1].members.keys()[0])
	check(fill_groups(model)==11,"A surviving camp grows independently to eleven")
	for source in [1,2]:model.damage_enemy_objective(source,99999)
	check(waves.spawn_batch()==0,"Destroyed camps cannot release another group")
	model=fresh(false,0,23);waves=model.waves
	check(fill_groups(model)==10 and waves.spawn_groups.has(-1),"Maps without portals retain one ten-enemy arrival group")
	waves.enemy_started_attack(waves.spawn_groups[-1].members.keys()[0])
	check(fill_groups(model)==11,"Nonportal enemies grow the next group at attack startup")
	model=fresh(true,4,10000);waves=model.waves
	for size in range(10,16):
		check(fill_groups(model)==3*size,"All camps fill growing groups of %d across retries"%size)
		check(waves.spawn_groups.values().all(func(group):return group.target_size==size),"Retries never increase group size")
		for group in waves.spawn_groups.values():waves.enemy_started_attack(group.members.keys()[0])
		model.enemies.clear()
	model=fresh(false,1,100);waves=model.waves
	model.balance.spawn_group_start=3;model.balance.spawn_group_growth=2
	check(fill_groups(model)==3,"Custom starting group size is used")
	waves.enemy_started_attack(waves.spawn_groups[0].members.keys()[0])
	check(fill_groups(model)==5,"Custom growth is added once")
	model.balance.spawn_group_growth=0
	waves.enemy_started_attack(waves.spawn_groups[0].members.keys()[0])
	check(fill_groups(model)==5,"Zero growth retains a fixed group size")
	check(model.enemies[waves.spawn_groups[0].members.keys()[0]].reinforcement_group==3,"Strength and XP still advance when count growth is set to zero")
	model=fresh();model.trees.clear();model.rebuild_navigation();waves=model.waves
	check(waves.spawn_skullpion([],2) and model.enemies.values().back().portal_index==2,"Boss entry and fallback remain assigned to their requested spot")
	model.portals[2].hp=0
	check(not waves.spawn_skullpion([],2),"Boss fallback cannot escape a destroyed spot through another portal")

func camp_wave_checks():
	var configured=[[13,0,0,0,0,0,0,0,0,0],[0,0,0,7,0,0,0,0,0,0],[0,0,0,0,13,0,0,0,0,0]]
	var model=Model.new();model.reset(42,{"waves":configured},Camps.layout(),false);model.start_wave()
	var waves=model.waves
	waves.tick(0,model.hero_position);fill_groups(model)
	check(model.wave==1 and waves.spawned==13 and waves.pending==0,"Castle wave one releases its exact finite total")
	check(model.enemies.values().all(func(enemy):return enemy.variant==0),"Only the first mix arrives before minute two")
	waves.enemy_started_attack(model.enemies.keys()[0])
	check(fill_groups(model)==0 and model.wave==1,"Attacks cannot advance the next scheduled wave")
	waves.tick(60,model.hero_position);fill_groups(model)
	check(model.wave==2 and waves.spawned==20 and waves.pending==0,"Minute two releases exactly seven Vambees")
	check(waves.spawn_groups.values().all(func(group):return group.number==1),"A scheduled wave resets each entrance's growth")
	waves.tick(60,model.hero_position);fill_groups(model)
	check(model.wave==3 and waves.spawned==33 and waves.pending==0,"Minute three releases exactly thirteen wolves")
	check(fill_groups(model)==0 and model.balance.waves==configured,"The final wave does not repeat or mutate saved composition")
	model.enemies.clear();waves.tick(60,model.hero_position)
	check(model.phase=="victory","Clearing all scheduled castle waves after their final minute wins")
	model.phase="preparing";model.start_wave()
	check(model.wave==1 and waves.released_waves==1 and waves.wave_clock==60 and waves.spawn_groups.is_empty(),"Restarting resets clock, mix and growth")

func run():
	model_checks()
	camp_wave_checks()
	native_start_checks()
	if "--visual" in OS.get_cmdline_user_args():await native_checks()
	print("WAVE_GROUPS_RESULT checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)

func native_start_checks():
	var model=fresh();var runtime=preload("res://scripts/forest/crowd/army_runtime.gd").new();runtime.configure(null)
	runtime.configure_kits(preload("res://scripts/forest/crowd/army_kit_data.gd").from_model(model))
	for compact in [false,true]:
		for kind in preload("res://scripts/forest/core_balance.gd").TYPES:
			runtime.clear();runtime.set_navigation(kind+1,{"width":0})
			runtime.spawn(1,0,kind,Vector3.ZERO,100000,.4)
			var victim:int=runtime.spawn(-1,1,12,Vector3(0,0,-3),100000,.4)
			var started=false;var damaged=false
			for tick in 600:
				runtime.step(1.0/60,{})
				var events=runtime.native.take_scene_events() if compact else runtime.take_events()
				started=events.any(func(event):return event.kind=="attack_started" and event.source_id==1)
				damaged=damaged or runtime.unit_state(victim).hp<100000
				if started:break
			check(started and not damaged,"Enemy kind %d reports attack startup before damage (compact=%s)"%[kind,compact])
	runtime.clear();runtime.free()

func native_checks():
	set_meta("forest_fighter",1)
	game=load("res://scenes/forest_shrine.tscn").instantiate();game.settings_path="user://wave-groups-%d.cfg"%OS.get_process_id()
	root.add_child(game);current_scene=game;await frames(5)
	game.set_physics_process(false);game.player.set_physics_process(false);game.camera_rig.set_process(false)
	game.core_balance.waves=[[100,0,0,0,0,0,0,0,0,0]];game.start_wave();game.model.waves.random_spawn_clock=100000
	game.model.waves.tick(60,game.player.position)
	var waves=game.model.waves;var runtime=game.army_runtime
	waves.spawn_clock=0
	for tick in 900:
		waves.tick(1.0/60,game.player.position);runtime.integration_tick(1.0/60);runtime.flush_presentation()
		await process_frame
		if runtime.handles.size()==40:break
	check(source_counts(game.model)==[10,10,10,10] and runtime.handles.size()==40,"Painterly game admits ten from each of four spots through the native army")
	check(waves.spawn_batch()==0,"All four native groups wait before an attack starts")
	var other_groups=[]
	for source in [1,2,3]:other_groups.append(waves.spawn_groups[source].members.keys())
	var id=waves.spawn_groups[0].members.keys()[0];var handle:int=runtime.handles[id]
	var point=game.player.position+Vector3(0,0,2)
	runtime.set_pose(handle,point,0)
	var before:float=game.player.hp
	for tick in 180:
		runtime.integration_tick(1.0/60);runtime.flush_presentation()
		await process_frame
		if waves.spawn_groups[0].engaged:break
	check(waves.spawn_groups[0].engaged and game.player.hp==before,"One spot's real native attack opens its own gate before damage lands")
	game.tuning.invincible=true
	for tick in 900:
		waves.tick(1.0/60,game.player.position);runtime.integration_tick(1.0/60);runtime.flush_presentation()
		await process_frame
		if runtime.handles.size()==51:break
	check(source_counts(game.model)==[21,10,10,10] and runtime.handles.size()==51,"Only the attacking spot admits eleven next; the other thirty keep waiting")
	var second_id=waves.spawn_groups[0].members.keys()[0]
	check(game.model.wave==1 and waves.spawn_groups[0].members.keys().all(func(member):return game.model.enemies[member].variant==0),"The next eleven native enemies retain the current scheduled mix")
	check(is_equal_approx(runtime.unit_state(runtime.handles[second_id]).max_hp,waves.role_stats(0).hp*1.2),"Rendered second group enters native combat with 20 percent more health")
	await capture_camp_group("timed-wave-group-2",second_id)
	for source in [1,2,3]:check(waves.spawn_groups[source].members.keys()==other_groups[source-1],"Rendered spot %d retains its original group"%source)
	check(not waves.spawn_groups[0].engaged and waves.spawn_batch()==0,"The attacking spot's second group gets a fresh gate")
	id=waves.spawn_groups[0].members.keys()[0];handle=runtime.handles[id]
	runtime.set_pose(handle,game.player.position+Vector3(0,0,-2),PI)
	for tick in 180:
		runtime.integration_tick(1.0/60);runtime.flush_presentation()
		await process_frame
		if waves.spawn_groups[0].engaged:break
	check(waves.spawn_groups[0].engaged,"A member of the second native group starts the next release")
	for tick in 900:
		waves.tick(1.0/60,game.player.position);runtime.integration_tick(1.0/60);runtime.flush_presentation()
		await process_frame
		if runtime.handles.size()==63:break
	check(source_counts(game.model)==[33,10,10,10] and runtime.handles.size()==63,"The next native group grows to twelve while other spots still wait")
	var third_id=waves.spawn_groups[0].members.keys()[0]
	check(game.model.wave==1 and waves.spawn_groups[0].members.keys().all(func(member):return game.model.enemies[member].variant==0),"The next twelve native enemies retain the current scheduled mix")
	check(is_equal_approx(runtime.unit_state(runtime.handles[third_id]).max_hp,waves.role_stats(0).hp*1.4),"Rendered third group enters native combat with 40 percent more health")
	await capture_camp_group("timed-wave-group-3",third_id)
	var xp=game.model.team_progression;xp.reset()
	for victim in [second_id,third_id]:
		var actor=runtime.enemy_target(victim)
		actor.take_hit(1000000,Vector3.FORWARD,false,{"tower":true});runtime.dispatch_events()
		actor.take_hit(1000000,Vector3.FORWARD,false,{"tower":true});runtime.dispatch_events()
	check(is_equal_approx(xp.experience(),2.6),"Real native deaths award each spawn's 1.2 or 1.4 XP exactly once")
	game.forest_ui.sync()
	check(game.forest_ui.team_level_label.text.contains("2.6 / 20 XP") and is_equal_approx(game.forest_ui.team_xp_bar.value,.13),"Rendered HUD includes fractional XP in its label and gold meter")
	if DisplayServer.get_name()!="headless":
		game.camera_rig.camera.global_position=game.player.position+Vector3(15,14,20)
		game.camera_rig.camera.look_at(game.player.position+Vector3.UP*2)
		await process_frame;await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://build/Other Files/Asset Toolkit/Wave Groups/growing-per-spot-attack-start.png")
	var config_path=game.settings_path
	stop_audio(game);game.move_audio.stop();current_scene=null;game.queue_free();await frames(3)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(config_path))

func capture_camp_group(label_:String,id:int):
	if DisplayServer.get_name()=="headless":return
	var point:Vector3=game.army_runtime.unit_state(game.army_runtime.handles[id]).position
	game.camera_rig.camera.global_position=point+Vector3(15,12,18)
	game.camera_rig.camera.look_at(point+Vector3.UP*2)
	await process_frame;await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://build/Other Files/Asset Toolkit/Wave Groups/"+label_+".png")
