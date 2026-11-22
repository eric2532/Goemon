extends "res://scripts/recovered_leaders_tests.gd"
const Model=preload("res://scripts/forest/forest_model.gd")
const Roles=preload("res://scripts/forest/forest_enemy_roles.gd")
const OUT="res://build/Other Files/Kill Reinforcements/"

func fresh():
	var model=Model.new();model.reset(42,{"waves":[[0,0,0,0,0,0,0,0,0,0]]},{"buildings":[],"trees":[],"deposits":[]},false)
	model.start_wave();return model

func model_checks():
	var model=fresh();var waves=model.waves
	waves.enemy_defeated();waves.tick(0,model.hero_position)
	check(model.enemies.size()==2 and waves.kill_spawn_pending==0,"One defeat releases two enemies even with an exhausted wave roster")
	check(waves.pending==0 and waves.spawned==0 and waves.remaining_counts==model.balance.waves[0],"Kill reinforcements do not consume or enlarge scheduled wave counts")
	check(model.enemies.values().all(func(e):return e.variant in Roles.WAVE_TYPES and e.reinforcement_group==1),"Extra arrivals use ordinary native types at opening strength")
	model.enemies.clear()
	for i in 239:waves.spawn_enemy(0,Vector3.ZERO)
	waves.enemy_defeated();waves.tick(0,model.hero_position)
	check(model.enemies.size()==240 and waves.kill_spawn_pending==1,"A partial pair respects the existing army cap and retains its second arrival")
	waves.tick(0,model.hero_position)
	check(waves.kill_spawn_pending==1,"A full army cannot drop a pending arrival")
	model.enemies.clear();waves.tick(0,model.hero_position)
	check(model.enemies.size()==1 and waves.kill_spawn_pending==0,"The remaining arrival retries after capacity is available")
	model=fresh();waves=model.waves
	for x in range(-40,40):
		for z in range(-40,40):model.trees[Vector2i(x,z)]=1.0
	model.rebuild_navigation();waves.enemy_defeated();waves.tick(0,model.hero_position)
	check(model.enemies.is_empty() and waves.kill_spawn_pending==2 and not waves.spawn_query_active,"Blocked placement preserves both arrivals and releases its query snapshot")
	waves.wave_clock=0;waves.tick(0,model.hero_position)
	check(model.phase=="wave","Pending kill arrivals cannot trigger a premature cleared-wave victory")
	model.trees.clear();model.rebuild_navigation();waves.tick(0,model.hero_position)
	check(model.enemies.size()==2 and waves.kill_spawn_pending==0,"Both arrivals retry after ground becomes available")
	waves.enemy_defeated();model.phase="preparing";waves.tick(1,model.hero_position);waves.enemy_defeated()
	check(waves.kill_spawn_pending==2,"Preparation neither releases nor queues kill arrivals")
	model.wave=0;model.start_wave()
	check(waves.kill_spawn_pending==0,"A new run clears the old kill backlog")

func run():
	model_checks()
	await gameplay_checks()
	print("KILL_REINFORCEMENTS_RESULT checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)

func gameplay_checks():
	var large="--large" in OS.get_cmdline_user_args()
	set_meta("forest_custom_layout",JSON.parse_string(FileAccess.get_file_as_string("res://tests/forest-shrine/reference/maps/forest_wind_meadow_large_valley.json" if large else "res://tests/forest-shrine/reference/maps/forest_wind_meadow_valley.json")))
	game=load("res://scenes/forest_shrine.tscn").instantiate();game.settings_path="user://kill-reinforcements-%d.cfg"%OS.get_process_id()
	root.add_child(game);current_scene=game;await frames(3)
	game.set_process(false);game.set_physics_process(false);game.player.set_physics_process(false);game.camera_rig.set_process(false)
	game.start_wave();game.tuning.invincible=true
	var model=game.model;var waves=model.waves;var army=game.army_runtime
	waves.spawn_clock=100000;waves.random_spawn_clock=100000
	army.integration_tick(1.0/60)
	check(game.painterly_preview and model.terrain_source=="wind_meadow","Launcher retains painterly Wind Meadow and native ownership")
	var pending:int=waves.pending;var spawned:int=waves.spawned;var roster=waves.remaining_counts.duplicate()
	var kills:int=game.kills;var quadrants={};var types={};var spawn_ms=[]
	var nodes=0;var resources=0
	for cycle in 12:
		var victim=waves.spawn_enemy(0,Vector3(120,model.surface_height(120,120),120));army.import_arrivals();army.sync_compatibility()
		var handle:int=army.handles[victim.id]
		model.damage_enemy(victim.id,.5)
		check(waves.kill_spawn_pending==0,"Nonlethal native damage cannot trigger the mechanic")
		model.damage_enemy(victim.id,1000000)
		check(waves.kill_spawn_pending==2 and not army.valid(handle),"A native kill queues exactly two arrivals")
		model.damage_enemy(victim.id,1000000);army.dispatch_events()
		check(waves.kill_spawn_pending==2,"Repeated damage/event draining cannot duplicate a defeat")
		army.sync_compatibility()
		game.show_pause();game._physics_process(1)
		check(waves.kill_spawn_pending==2,"Pause retains the pair without spawning it");game.resume()
		var first:int=model.next_id;var started=Time.get_ticks_usec()
		waves.tick(0,game.player.position);spawn_ms.append((Time.get_ticks_usec()-started)/1000.0)
		check(model.next_id-first==2 and waves.kill_spawn_pending==0,"The next world tick places the complete pair on the real map")
		army.import_arrivals();army.sync_compatibility()
		for id in range(first,model.next_id):
			var row=model.enemies[id];var radius=Roles.footprint_radius(row.variant,model.balance.enemy_size_mult)
			types[row.variant]=true;quadrants[Vector2(signf(row.pos.x),signf(row.pos.z))]=true
			check(army.handles.has(id) and army.valid(army.handles[id]),"Each extra enemy joins the existing native army")
			check(waves.navigation.move_clear(row.pos,radius) and army.native.can_reach(row.pos,model.point(model.shrine_entry()),radius),"Random placement clears scenery and has a native route to the castle")
			check(waves.horizontal_distance(row.pos,game.player.position)>=20,"Extra arrivals keep the existing player safety distance")
		if cycle==0:
			var child=model.enemies[first];model.damage_enemy(child.id,1000000)
			if army.valid(army.handles.get(child.id,0)):
				check(child.variant==Roles.VAMBEE_TORSO and waves.kill_spawn_pending==0,"Vambee's form change does not count as a death")
				model.damage_enemy(child.id,1000000)
			check(waves.kill_spawn_pending==2,"Killing a spawned child produces another pair")
			army.sync_compatibility();waves.tick(0,game.player.position);army.import_arrivals();army.sync_compatibility()
			check(waves.kill_spawn_pending==0,"The next generation also uses normal placement and ownership")
		if cycle==11 and DisplayServer.get_name()!="headless":
			var point:Vector3=model.enemies[first].pos
			game.camera_rig.camera.projection=Camera3D.PROJECTION_PERSPECTIVE;game.camera_rig.camera.fov=63
			game.camera_rig.camera.global_position=point+Vector3(18,30,25);game.camera_rig.camera.look_at(point+Vector3.UP*2)
			army.flush_presentation();await frames(3);await RenderingServer.frame_post_draw
			DirAccess.make_dir_recursive_absolute(OUT)
			root.get_texture().get_image().save_png(OUT+("large" if large else "standard")+".png")
		for id in model.enemies.keys():
			if army.handles.has(id):army.despawn(army.handles[id])
		army.sync_compatibility();army.flush_presentation();await frames(3)
		check(waves.kill_spawn_pending==0,"Cleanup/despawn produces no kill reinforcements")
		if cycle==1:nodes=Performance.get_monitor(Performance.OBJECT_NODE_COUNT);resources=Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)
	check(game.kills-kills==13,"Each actual native death is counted once")
	check(types.size()>1 and quadrants.size()>=2,"Extra enemies vary type and appear in different map quadrants")
	check(waves.pending==pending and waves.spawned==spawned and waves.remaining_counts==roster,"Repeated kills preserve the configured wave roster exactly")
	var node_delta=Performance.get_monitor(Performance.OBJECT_NODE_COUNT)-nodes;var resource_delta=Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)-resources
	spawn_ms.sort();print("KILL_SPAWN_DIAGNOSTICS ",JSON.stringify({"large":large,"spawn_p95_ms":spawn_ms[int(spawn_ms.size()*.95)],"spawn_max_ms":spawn_ms[-1],"node_delta":node_delta,"resource_delta":resource_delta}))
	check(node_delta<=0 and resource_delta<=0,"Repeated spawn/retire cycles retain no nodes or resources after warm-up")
	for i in 3:
		var row=waves.spawn_enemy(0,Vector3(100+i*4,model.surface_height(100+i*4,100),100));army.import_arrivals()
		army.native.apply_hit(army.handles[row.id],{"amount":1000000.0})
	army.dispatch_events();army.sync_compatibility()
	check(waves.kill_spawn_pending==6,"Three deaths in one native event drain queue all six arrivals")
	for i in 3:waves.tick(0,game.player.position);army.import_arrivals();army.sync_compatibility()
	check(waves.kill_spawn_pending==0 and model.enemies.size()==6,"Simultaneous deaths release every queued pair through bounded batches")
	for id in model.enemies.keys():army.despawn(army.handles[id])
	army.sync_compatibility()
	var ally=army.spawn(-5000,1,0,Vector3(110,0,110),100,.4)
	army.apply_hit(ally,{"amount":1000000.0});army.dispatch_events()
	check(waves.kill_spawn_pending==0,"Ally deaths cannot spawn enemy pairs")
	waves.enemy_defeated()
	for camp in model.portals:camp.hp=0
	check(waves.spawn_random_batch(true)==0 and waves.kill_spawn_pending==2,"Destroyed enemy objectives stop extra reinforcements")
	var config=game.settings_path;stop_audio(game);game.move_audio.stop();current_scene=null;game.queue_free();paused=false;await frames(3)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(config))
