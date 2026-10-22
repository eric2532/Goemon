extends SceneTree
## Same visible population and camera for before/after CPU and frame costs.
var game
var report=[]
var output="res://docs/dense-crowd/after"
var rendered=false
func _initialize():run.call_deferred()
func run():
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):output=arg.trim_prefix("--out=")
	rendered=DisplayServer.get_name()!="headless"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	game=load("res://scenes/forest_shrine.tscn").instantiate();game.settings_path="user://dense-profile-%s.cfg"%OS.get_process_id();root.add_child(game);current_scene=game
	await process_frame;await physics_frame
	AudioServer.set_bus_mute(0,true)
	game.start_wave();game.model.waves.pending=1000;game.model.waves.spawn_clock=100000;game.model.hero_targetable=false;game.player.set_physics_process(false);game.set_physics_process(false);game.world.set_process(false)
	game.player.position=Vector3(0,.1,25)
	game.camera_rig.set_process(false)
	game.camera_rig.camera.projection=Camera3D.PROJECTION_ORTHOGONAL;game.camera_rig.camera.size=62
	game.camera_rig.camera.position=Vector3(0,42,47);game.camera_rig.camera.look_at(Vector3(0,0,0))
	game.model.shrine().hp=10000000
	for count in [80,240]:
		while game.model.enemies.size()<count:
			var i=game.model.enemies.size()
			game.model.waves.spawn_enemy([0,1,3][i%3],Vector3((i%16-7.5)*2.1,0,-18+int(i/16)*2.2))
		game.sync_enemies()
		for actor in game.actors.values():actor.set_physics_process(false);actor._physics_process(0)
		for x in range(-40,40):
			for z in range(-40,40):game.model.visible_cells[Vector2i(x,z)]=true
		game.world.update_fog()
		game.crowd._process(0)
		var costs={"count":count}
		for component in ["actors","crowd","simulation"]:
			var begin=Time.get_ticks_usec()
			for sample in range(30):
				match component:
					"actors":
						for actor in game.actors.values():actor._physics_process(1.0/60)
					"crowd":game.crowd._process(1.0/60)
					"simulation":game.model.waves.tick(1.0/60,game.player.position)
			costs[component+"_ms"]=(Time.get_ticks_usec()-begin)/30000.0
		# Keep poses moving for the frame measurement; pure static batching alone
		# does not represent a wave advancing toward the fort.
		for e in game.model.enemies.values():e.velocity=Vector3(0,0,-3)
		for frame in range(30):
			for e in game.model.enemies.values():e.walk_phase+=.1
			await process_frame
		var durations=[];var previous=Time.get_ticks_usec()
		for frame in range(90):
			for e in game.model.enemies.values():e.walk_phase+=.1
			await process_frame
			var now=Time.get_ticks_usec();durations.append((now-previous)/1000.0);previous=now
		durations.sort();costs.frame_median_ms=durations[45];costs.frame_p95_ms=durations[85]
		costs.draw_calls=Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME);costs.primitives=Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)
		var live=[];previous=Time.get_ticks_usec()
		for frame in range(60):
			game.model.waves.tick(1.0/60,game.player.position)
			for actor in game.actors.values():actor._physics_process(1.0/60)
			game.world.sync(1.0/60)
			await process_frame
			var now=Time.get_ticks_usec();live.append((now-previous)/1000.0);previous=now
		live.sort();costs.live_frame_median_ms=live[30];costs.live_frame_p95_ms=live[57]
		report.append(costs);print("DENSE_CROWD_PROFILE ",JSON.stringify(costs))
		if rendered:
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(output.path_join("crowd-%d.png"%count))
	FileAccess.open(output.path_join("metrics.json"),FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	await game.quit_clean();quit()
