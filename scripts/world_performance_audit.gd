extends SceneTree
# Fixed-resolution views with separate rendering CPU/GPU and physics timings.
var game
var label="after"
var report={}
var isolate=false
var measuring_physics=false
var physics_started=0
var physics_samples=[]

class PhysicsProbe extends Node:
	var audit
	func _physics_process(_delta):
		if audit.measuring_physics:audit.physics_samples.append((Time.get_ticks_usec()-audit.physics_started)/1000.0)


func _initialize():
	physics_frame.connect(func():physics_started=Time.get_ticks_usec())
	call_deferred("run")

func sample(title: String):
	for i in range(90):await process_frame
	var rows=[];var last=Time.get_ticks_usec();var viewport=root.get_viewport_rid()
	physics_samples.clear();measuring_physics=true
	for i in range(180):
		await process_frame
		var now=Time.get_ticks_usec()
		rows.append({"frame_ms":(now-last)/1000.0,"render_cpu_ms":RenderingServer.viewport_get_measured_render_time_cpu(viewport)+RenderingServer.get_frame_setup_time_cpu(),"gpu_ms":RenderingServer.viewport_get_measured_render_time_gpu(viewport),"physics_ms":Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)*1000,"draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),"primitives":Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)})
		last=now
	measuring_physics=false
	var result={}
	for key in rows[0]:
		var values=[];var total=0.0
		for row in rows:values.append(row[key]);total+=row[key]
		values.sort();result[key]={"mean":total/values.size(),"p95":values[int(values.size()*.95)]}
	if not physics_samples.is_empty():
		physics_samples.sort();var sum=0.0
		for value in physics_samples:sum+=value
		result.physics_callbacks_ms={"mean":sum/physics_samples.size(),"p95":physics_samples[int(physics_samples.size()*.95)],"samples":physics_samples.size()}
	result.nodes=Performance.get_monitor(Performance.OBJECT_NODE_COUNT)
	result.enemies=game.enemies.size()
	report[title]=result
	print("WORLD_PROFILE ",title," ",JSON.stringify(result))
	if DisplayServer.get_name()!="headless" and not title.ends_with("hidden"):
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://tests/world-performance/"+label+"-"+title+".png")

func locate(point: Vector3,on_ground: bool=false):
	game.reset_player_at(point+Vector3.UP*.12)
	game.encounters.completed=on_ground
	game.encounters.refresh_encounters()
	while not game.encounters.pending_spawns.is_empty():
		game.encounters.spawn_pending();await process_frame
	game.player.set_physics_process(false)
	game.player.velocity=Vector3.ZERO
	game.camera_rig.pitch=.65;game.camera_rig.yaw=-1.27
	game.camera_rig.reset_follow()

func run():
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--label="):label=arg.trim_prefix("--label=")
		if arg=="--isolate":isolate=true
	seed(90824)
	game=load("res://scenes/main.tscn").instantiate();root.add_child(game)
	var probe=PhysicsProbe.new();probe.audit=self;probe.process_physics_priority=10000;root.add_child(probe)
	game.tuning=PrototypeTuning.DEFAULTS.duplicate();game.tuning.freeze_ai=true;game.tuning.invincible=true
	game.settings.quality=1;game.settings.fullscreen=false
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	root.size=Vector2i(1280,800)
	root.set_flag(Window.FLAG_NO_FOCUS,true)
	game.start_game();game.apply_quality()
	for i in range(2):await process_frame
	game.apply_quality()
	game.encounters.active=false
	game.encounters.next_reinforcement=8
	game.camera_rig.set_process_unhandled_input(false)
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED);Engine.max_fps=0
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(),true)
	var sky=game.world.sky_islands
	await locate(sky.islands[0]);await sample("dawn")
	await locate(sky.islands[6*sky.PER_LAYER+27]);await sample("middle")
	game.tuning.freeze_ai=false;await sample("middle_active");game.tuning.freeze_ai=true
	if isolate:
		game.world.hide();await sample("middle_world_hidden");game.world.show()
		game.settings.quality=0;game.apply_quality();await sample("middle_low");game.settings.quality=1;game.apply_quality()
	await locate(sky.ground_point,true);game.encounters.spawn_ground_giants();await sample("ground")
	await locate(game.world.furnished_districts[0]+Vector3(0,0,15),true);await sample("town")
	game.tuning.freeze_ai=false;await sample("town_active");game.tuning.freeze_ai=true
	if isolate:
		game.world.hide();await sample("town_world_hidden");game.world.show()
		game.settings.quality=0;game.apply_quality();await sample("town_low");game.settings.quality=1;game.apply_quality()
	FileAccess.open("res://tests/world-performance/"+label+".json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	quit()
