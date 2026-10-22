extends SceneTree
## Measures the real scene, separating simulation, fitted actors and rendering.
## Run rendered for frame timings; --headless still reports CPU component costs.
var game
var report: Array=[]
func _initialize():run.call_deferred()
func run():
	game=load("res://scenes/forest_shrine.tscn").instantiate();root.add_child(game);current_scene=game
	await process_frame;await process_frame
	AudioServer.set_bus_mute(0,true)
	game.start_wave();game.model.waves.pending=100;game.model.waves.spawn_clock=100000
	game.model.hero_targetable=false;game.player.set_physics_process(false)
	game.set_physics_process(false);game.model.shrine().hp=1000000
	for kind in range(4):
		var started=Time.get_ticks_usec()
		var e=game.model.waves.spawn_enemy(kind,Vector3(0,0,100+kind*30))
		game.sync_enemies()
		report.append({"stage":"first_spawn","kind":kind,"ms":(Time.get_ticks_usec()-started)/1000.0})
		game.actors[e.id].set_physics_process(false)
	for actor in game.actors.values():actor.free()
	game.actors.clear();game.enemies.clear();game.model.enemies.clear();game.crowd.clear()
	for count in [0,12,24,60]:
		while game.model.enemies.size()<count:
			var i=game.model.enemies.size()
			var e=game.model.waves.spawn_enemy([0,1,3][i%3],Vector3((i%10-5)*3,0,50+(i/10)*3))
			game.sync_enemies();game.actors[e.id].set_physics_process(false)
		game.model.update_vision(Vector3(0,0,45))
		for actor in game.actors.values():actor._physics_process(0)
		game.crowd._process(0)
		var costs={}
		for component in ["simulation","actors","crowd","world"]:
			var started=Time.get_ticks_usec()
			for i in range(60):
				match component:
					"simulation":game.model.tick(1.0/60,game.player.position)
					"actors":
						for actor in game.actors.values():actor._physics_process(1.0/60)
					"crowd":game.crowd._process(1.0/60)
					"world":game.world.sync(1.0/60)
			costs[component+"_ms"]=(Time.get_ticks_usec()-started)/60000.0
		for actor in game.actors.values():actor.set_physics_process(true)
		game.set_physics_process(true)
		game.model.update_vision(Vector3(0,0,45))
		for i in range(30):await process_frame
		var durations: Array[float]=[]
		var last=Time.get_ticks_usec()
		for i in range(120):
			await process_frame
			var now=Time.get_ticks_usec();durations.append((now-last)/1000.0);last=now
		game.set_physics_process(false)
		for actor in game.actors.values():actor.set_physics_process(false)
		durations.sort()
		costs["stage"]="crowd";costs["enemies"]=count
		costs["frame_median_ms"]=durations[60];costs["frame_p95_ms"]=durations[114]
		costs["draw_calls"]=Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
		costs["primitives"]=Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)
		report.append(costs);print("ENEMY_LAG_PROFILE ",JSON.stringify(costs))
	var path=OS.get_environment("FOREST_LAG_REPORT")
	if not path.is_empty():
		var file=FileAccess.open(path,FileAccess.WRITE);file.store_string(JSON.stringify(report,"\t"))
	print("ENEMY_LAG_PROFILE_COMPLETE ",JSON.stringify(report))
	await game.quit_clean();quit()
