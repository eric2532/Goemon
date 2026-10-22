extends SceneTree
## Whole-scene Daruma diagnosis, including cold director spawn and first reveal.
const Model=preload("res://scripts/forest/forest_model.gd")
var game
var report={"fixtures":[],"frames":[]}
func _initialize():run.call_deferred()
func run():
	game=load("res://scenes/forest_shrine.tscn").instantiate();root.add_child(game);current_scene=game
	await process_frame;await process_frame
	AudioServer.set_bus_mute(0,true)
	for towers in [0,10,30]:
		var m=Model.new();m.reset(90824)
		for x in range(-40,40):
			for z in range(-40,40):m.explored[Vector2i(x,z)]=true
		var built=0
		for x in range(-14,15,4):
			for z in range(-14,15,4):
				if built>=towers or Vector2(x,z).length()<8:continue
				var cell=Vector2i(x,z)
				if m.placement_error("tower",cell,0).is_empty():m._make_building("tower",cell,0);built+=1
		m.rebuild_navigation();m.wave=2
		var begin=Time.get_ticks_usec();m.start_wave();var begin_ms=(Time.get_ticks_usec()-begin)/1000.0
		var start=Time.get_ticks_usec();m.waves.spawn_one();var spawn_ms=(Time.get_ticks_usec()-start)/1000.0
		var e: Dictionary=m.enemies.values()[0]
		var choices: Array=[]
		for p in m.waves.giant_staging():choices.append([p.x,p.z])
		start=Time.get_ticks_usec();m.waves.tick_enemy(e,1.0/60,Vector3(0,0,18))
		var row={"towers":built,"wave_begin_ms":begin_ms,"spawn_ms":spawn_ms,"first_movement_ms":(Time.get_ticks_usec()-start)/1000.0,"choices":choices,"target":e.target_id,"variant":e.variant}
		report.fixtures.append(row);print("GIANT_LAG_FIXTURE ",JSON.stringify(row))
	game.model.wave=2;game.start_wave();game.player.set_physics_process(false)
	game.model.waves.spawn_clock=100000;game.model.shrine().hp=1000000
	await measure_frames("empty",90)
	var start=Time.get_ticks_usec();game.model.waves.spawn_one();game.sync_enemies()
	report["scene_spawn_ms"]=(Time.get_ticks_usec()-start)/1000.0
	var e: Dictionary=game.model.enemies.values()[0]
	game.player.position=e.pos+Vector3(0,.15,34);game.player.hp=1000000
	game.model.update_vision(game.player.position);game.camera_rig.yaw=0;game.camera_rig.reset_follow();game.camera_rig._process(0)
	await measure_frames("first_reveal",30)
	await measure_frames("visible_moving_giant",180)
	game.set_physics_process(false)
	var costs={};var actor=game.actors[e.id];actor.set_physics_process(false)
	for component in ["simulation","actor","crowd"]:
		start=Time.get_ticks_usec()
		for i in range(120):
			match component:
				"simulation":game.model.tick(1.0/60,game.player.position)
				"actor":actor._physics_process(1.0/60)
				"crowd":game.crowd._process(1.0/60)
		costs[component+"_ms"]=(Time.get_ticks_usec()-start)/120000.0
	report["cpu"]=costs
	if DisplayServer.get_name()!="headless":
		await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png("/tmp/sonic-giant-profile.png")
	var path=OS.get_environment("FOREST_GIANT_REPORT")
	if not path.is_empty():
		var file=FileAccess.open(path,FileAccess.WRITE);file.store_string(JSON.stringify(report,"\t"))
	print("GIANT_LAG_PROFILE_RESULT ",JSON.stringify(report))
	await game.quit_clean();quit()
func measure_frames(label: String,count: int):
	var times: Array[float]=[];var last=Time.get_ticks_usec()
	for i in range(count):
		await process_frame
		var now=Time.get_ticks_usec();times.append((now-last)/1000.0);last=now
	times.sort()
	var row={"stage":label,"median_ms":times[count/2],"p95_ms":times[mini(count-1,roundi(count*.95))],"max_ms":times.back(),"draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),"primitives":Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)}
	report.frames.append(row);print("GIANT_LAG_FRAMES ",JSON.stringify(row))
