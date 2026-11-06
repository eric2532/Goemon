extends "res://scripts/recovered_leaders_tests.gd"
const Model=preload("res://scripts/forest/forest_model.gd")
const Roles=preload("res://scripts/forest/forest_enemy_roles.gd")
const OUT="res://build/Other Files/Random Enemy Spawns/Anywhere/"
var spawn_ms=[]

func fresh(total:int=100):
	var model=Model.new();model.reset(42,{"waves":[[total,0,0,0,0,0,0,0,0,0]]},{"buildings":[],"trees":[],"deposits":[]},false)
	model.start_wave();model.waves.spawn_clock=100000;return model

func model_checks():
	for rate in [30,60,144]:
		var model=fresh();var waves=model.waves
		for tick in range(rate-1):waves.tick(1.0/rate,model.hero_position)
		check(model.enemies.is_empty(),"Random arrivals wait a full second at %d Hz"%rate)
		waves.tick(1.0/rate,model.hero_position)
		check(model.enemies.size()==3 and waves.pending==97,"Exactly three appear at one second at %d Hz"%rate)
		for tick in rate:waves.tick(1.0/rate,model.hero_position)
		check(model.enemies.size()==6 and waves.pending==94,"Three more appear the next second at %d Hz"%rate)
	var model=fresh(5);var waves=model.waves
	waves.tick(1,model.hero_position);waves.tick(1,model.hero_position)
	check(model.enemies.size()==5 and waves.pending==0 and waves.spawned==5,"A final pair consumes only the configured remainder")
	check(model.balance.waves[0][0]==5,"Map arrivals preserve saved wave totals")
	waves.tick(20,model.hero_position)
	check(model.enemies.size()==5,"An exhausted roster does not repeat")
	model=fresh();waves=model.waves
	for i in 239:waves.spawn_enemy(0,Vector3.ZERO)
	waves.tick(1,model.hero_position)
	check(model.enemies.size()==240 and waves.pending==99,"Map arrivals share the unchanged native active cap")
	waves.tick(1,model.hero_position)
	check(waves.pending==99,"A full army consumes no pending enemies")
	model.enemies.clear();waves.tick(1,model.hero_position)
	check(model.enemies.size()==3 and waves.pending==96,"Capacity recovery releases a single group without a catch-up burst")
	model=fresh();waves=model.waves
	model.hero_position=Vector3(120,0,120);model.workers.clear()
	for i in 8:
		var before=model.next_id;waves.tick(1,model.hero_position)
		var points=[]
		for id in range(before,model.next_id):
			var enemy=model.enemies[id];points.append(enemy.pos)
			check(enemy.portal_index==waves.RANDOM_SPAWN_SOURCE and enemy.reinforcement_group==1,"Random enemies own no castle reinforcement group")
			check(waves.horizontal_distance(enemy.pos,model.center(model.shrine()))>=90 and waves.horizontal_distance(enemy.pos,model.hero_position)>=20,"Arrivals keep clear of the castle courtyard and player")
		check(points.size()==3,"An open clearing admits a complete group")
		if points.size()==3:check(points[0].distance_to(points[1])<80 and points[0].distance_to(points[2])<80,"A group appears together around its random clearing")
	check(waves.spawn_groups.is_empty(),"Random attacks never advance castle group strength")
	var saved=waves.pending;model.phase="preparing";waves.tick(10,model.hero_position)
	check(waves.pending==saved,"Preparation stops random arrivals")
	model.wave=0;model.start_wave();waves.spawn_clock=100000;waves.tick(.99,model.hero_position)
	check(waves.spawned==0,"Restart resets the full one-second arrival delay")
	model=fresh();waves=model.waves
	for x in range(-40,40):
		for z in range(-40,40):model.trees[Vector2i(x,z)]=1.0
	model.rebuild_navigation();var started=Time.get_ticks_msec()
	check(waves.spawn_random_batch()==0 and waves.pending==100,"Blocked terrain preserves all queued arrivals")
	check(Time.get_ticks_msec()-started<1000,"Blocked placement returns after bounded attempts")
	check(not waves.spawn_query_active,"Blocked placement clears its spatial snapshot")
	for kind in Roles.WAVE_TYPES:
		model=fresh();var roster=[0,0,0,0,0,0,0,0,0,0];roster[model.Balance.TYPES.find(kind)]=3
		model.balance.waves=[roster];model.phase="preparing";model.wave=0;model.start_wave()
		check(model.waves.spawn_random_batch()==3 and model.enemies.values().all(func(e):return e.variant==kind),"Map groups retain selected ordinary enemy type %d"%kind)
	model=fresh();model.balance.waves=[[0,0,0,0,0,0,0,1,0,0]];model.phase="preparing";model.wave=0;model.start_wave()
	check(model.waves.spawn_random_batch()==0 and model.waves.pending==1,"Bosses retain their existing entrance path")

func native_route_checks():
	var runtime=load("res://scripts/forest/crowd/army_runtime.gd").new();check(runtime.configure(null,64),"Native spawn query initializes")
	var start=Vector3(-20,0,0);var goal=Vector3(20,0,0)
	var data={"bounds_min":Vector3(-30,0,-30),"bounds_max":Vector3(30,0,30)}
	runtime.set_navigation(1,data)
	check(runtime.native.can_reach(start,goal,1.3),"Spawn query accepts connected ground")
	check(not runtime.native.can_reach(Vector3(NAN,0,0),goal,1.3) and not runtime.native.can_reach(start,goal,-1),"Spawn query rejects invalid points and radii")
	data.obstacle_min=PackedVector3Array([Vector3(-3,0,-30)]);data.obstacle_max=PackedVector3Array([Vector3(3,50,30)])
	runtime.set_navigation(2,data)
	check(not runtime.native.can_reach(start,goal,1.3),"Spawn query rejects a disconnected pocket")
	data.obstacle_min=PackedVector3Array();data.obstacle_max=PackedVector3Array();runtime.set_navigation(3,data)
	runtime.native.begin_step(.01)
	check(runtime.native.can_reach(start,goal,1.3),"Spawn query joins pending simulation and refreshes changed terrain")
	var layout=JSON.parse_string(FileAccess.get_file_as_string("res://assets/maps/forest_wind_meadow.json"));layout.erase("raised_castle")
	var model=Model.new();model.reset(42,{},layout,false);model.start_wave();model.army_runtime=runtime
	runtime.configure(null,64)
	runtime.set_navigation(model.navigation_revision,runtime.navigation_data(model))
	var entrance:Vector3=model.waves.routes.exit_point(model.portals[0],0);entrance.y=model.surface_height(entrance.x,entrance.z)
	check(not runtime.native.can_reach(entrance,model.point(model.shrine_entry()),1.3),"Older saved castles retain their closed entrances")
	check(model.waves.spawn_random_batch()==3,"Random arrivals can reach the exterior of an older closed castle")
	model.rebuild_navigation();var pending=model.waves.pending
	check(model.waves.spawn_random_batch()==0 and model.waves.pending==pending,"Changed terrain defers arrivals until native navigation is refreshed")
	runtime.free()

func run():
	native_route_checks()
	model_checks()
	if "--visual" in OS.get_cmdline_user_args():
		await desktop_checks()
		check(checks>=220,"Desktop spawning, assault and reuse checks all completed")
	print("RANDOM_ENEMY_SPAWN_RESULT checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)

func desktop_checks():
	var large="--large" in OS.get_cmdline_user_args()
	set_meta("forest_custom_layout",JSON.parse_string(FileAccess.get_file_as_string("res://assets/maps/forest_wind_meadow_large.json" if large else "res://assets/maps/forest_wind_meadow.json")))
	set_meta("forest_fighter",1)
	var output=OUT+("large" if large else "standard")
	DirAccess.make_dir_recursive_absolute(output)
	game=load("res://scenes/forest_shrine.tscn").instantiate();game.settings_path="user://random-spawn-%d.cfg"%OS.get_process_id()
	root.add_child(game);current_scene=game;await frames(5)
	game.set_process(false);game.set_physics_process(false);game.player.set_physics_process(false);game.camera_rig.set_process(false);game.camera_rig.set_process_unhandled_input(false)
	game.core_balance.waves=[[35,35,35,35,30,0,30,0,0,0]];game.start_wave();game.tuning.invincible=true
	var model=game.model;var waves=model.waves;var army=game.army_runtime
	check(game.painterly_preview and model.terrain_source=="wind_meadow","Desktop launcher runs painterly Wind Meadow")
	game.show_pause();var clock:float=waves.random_spawn_clock;game._physics_process(5)
	check(waves.random_spawn_clock==clock,"Ordinary pause stops the random spawn clock");game.resume()
	waves.tick(0,game.player.position);army.integration_tick(1.0/60)
	check(model.enemies.values().any(func(e):return e.get("portal_index",-1)>=0),"Castle arrivals remain active alongside random groups")
	waves.spawn_clock=100000
	var ids=[];var starts={};var types={};var quadrants={};var off_road=0
	for second in 20:
		var first=model.next_id;var started=Time.get_ticks_usec()
		waves.tick(1,game.player.position);spawn_ms.append((Time.get_ticks_usec()-started)/1000.0)
		check(model.next_id-first<=3,"Second %d respects the three-enemy arrival limit"%(second+1))
		for id in range(first,model.next_id):
			ids.append(id);starts[id]=model.enemies[id].pos
			var e=model.enemies[id]
			types[e.variant]=true;quadrants[Vector2(signf(e.pos.x),signf(e.pos.z))]=true
			if not model.roads.has(model.cell_of(e.pos)):off_road+=1
			check(waves.navigation.move_clear(e.pos,Roles.footprint_radius(e.variant,model.balance.enemy_size_mult)),"Random enemy has supported ground and clears scenery")
			check(army.native.can_reach(e.pos,model.point(model.shrine_entry()),Roles.footprint_radius(e.variant,model.balance.enemy_size_mult)),"Spawn has a supported native route to the castle")
		army.integration_tick(1.0/60);army.flush_presentation();await process_frame
		if ids.size()>=30:break
	check(ids.size()>=30,"Bounded retries release at least thirty enemies on the real map")
	check(ids.all(func(id):return army.handles.has(id)),"Every map arrival enters the existing native army")
	check(off_road>0 and quadrants.size()==4,"Random groups cover all four map quadrants and include off-road ground")
	check(types.size()==Roles.WAVE_TYPES.size(),"All six ordinary types join the same native assault")
	check(waves.pending==200-waves.spawned,"Castle and map arrivals share exact roster accounting")
	if ids.is_empty():return
	await capture_group(output+"/arrival.png",starts[ids[0]])
	# Hold real castle targets alive while testing native route/combat delivery.
	var targets:Dictionary=army.external_targets()
	for row in targets.ids.size():
		if targets.kinds[row]!=2:targets.targetable[row]=0
		else:check(is_equal_approx(targets.minimum[row].y,model.center(model.buildings[targets.ids[row]]).y),"Castle targets use their actual foundation height")
	army.native.set_targets(targets)
	var hits={};var step_ms=[]
	for tick in (24000 if large else 9000):
		var started=Time.get_ticks_usec();army.step(.05,{})
		step_ms.append((Time.get_ticks_usec()-started)/1000.0)
		for event in army.take_events():
			if event.kind=="external_damage" and ids.has(event.source_id):hits[event.source_id]=event.target_id
		if tick%60==0:
			game.crowd.army.present(army.render_snapshot(),[]);await process_frame
		if ids.all(func(id):return hits.has(id)):break
	for id in ids:
		check(hits.has(id),"Random enemy %d reaches and attacks a castle defense through native combat"%id)
		if not hits.has(id):print("RANDOM_ROUTE_FAILURE start=",starts[id]," state=",army.unit_state(army.handles[id]))
	game.crowd.army.present(army.render_snapshot(),[])
	await capture_group(output+"/castle-assault.png",model.center(model.shrine()))
	for id in model.enemies.keys():
		if army.handles.has(id):army.despawn(army.handles[id])
	army.sync_compatibility();game.crowd.army.present(army.render_snapshot(),[]);await frames(5)
	var nodes=0;var resources=0
	var spawn_state=[waves.rng.state,waves.spawned,waves.pending,waves.remaining_counts.duplicate()]
	# Repeat identical locations/types after warming their existing spatial render batches.
	for cycle in 6:
		waves.rng.state=spawn_state[0];waves.spawned=spawn_state[1];waves.pending=spawn_state[2];waves.remaining_counts=spawn_state[3].duplicate()
		var cycle_arrivals=0
		for group in 2:
			var released:int=waves.spawn_random_batch();cycle_arrivals+=released
			check(released<=3,"Repeated spawn/retire cycle %d respects the arrival limit"%cycle)
			army.import_arrivals();army.sync_compatibility();game.crowd.army.present(army.render_snapshot(),[]);await frames(2)
		check(cycle_arrivals>0,"Repeated spawn/retire cycle %d exercises real arrivals"%cycle)
		for id in model.enemies.keys():
			if army.handles.has(id):army.despawn(army.handles[id])
		army.sync_compatibility();game.crowd.army.present(army.render_snapshot(),[]);await frames(5)
		if cycle==0:nodes=Performance.get_monitor(Performance.OBJECT_NODE_COUNT);resources=Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)
	var node_delta=Performance.get_monitor(Performance.OBJECT_NODE_COUNT)-nodes;var resource_delta=Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)-resources
	check(node_delta<=0 and resource_delta<=0 and waves.spawn_query_buckets.is_empty(),"Repeated native arrivals retire without node, resource or spawn snapshot growth")
	spawn_ms.sort();step_ms.sort()
	var report={"checks":checks,"failures":failures,"random_enemies":ids.size(),"castle_attackers":hits.size(),"node_delta":node_delta,"resource_delta":resource_delta,"spawn_p95_ms":spawn_ms[int(spawn_ms.size()*.95)],"spawn_max_ms":spawn_ms[-1],"native_step_p95_ms":step_ms[int(step_ms.size()*.95)],"native_step_max_ms":step_ms[-1]}
	var file=FileAccess.open(output+"/results.json",FileAccess.WRITE);file.store_string(JSON.stringify(report,"  "));file.close();print("RANDOM_SPAWN_DESKTOP ",JSON.stringify(report))
	model.enemies.clear()
	for camp in model.portals:camp.hp=0
	check(waves.spawn_random_batch()==0,"Destroyed enemy objectives stop further map reinforcements")
	var config=game.settings_path;stop_audio(game);game.move_audio.stop();current_scene=null;game.queue_free();paused=false;await frames(3)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(config))

func capture_group(path:String,point:Vector3):
	game.camera_rig.camera.projection=Camera3D.PROJECTION_PERSPECTIVE;game.camera_rig.camera.fov=63
	game.camera_rig.camera.global_position=point+Vector3(25,65,42);game.camera_rig.camera.look_at(point+Vector3.UP*2)
	await process_frame;await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(path)
