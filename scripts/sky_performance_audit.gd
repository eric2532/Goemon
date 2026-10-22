extends SceneTree
# Run with godot --path . --script res://scripts/sky_performance_audit.gd -- --label=before
var game
var report={}
var label="after"

func _initialize():
	call_deferred("run")

func sample(title: String):
	for i in range(45):await process_frame
	var timings=[]
	var last=Time.get_ticks_usec()
	for i in range(180):
		await process_frame
		var now=Time.get_ticks_usec();timings.append((now-last)/1000.0);last=now
	var total=0.0
	for value in timings:total+=value
	timings.sort()
	report[title]={"mean_ms":total/timings.size(),"p95_ms":timings[int(timings.size()*.95)],"draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),"primitives":Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME),"nodes":Performance.get_monitor(Performance.OBJECT_NODE_COUNT),"physics_ms":Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)*1000}
	print("SKY_PROFILE ",title," ",JSON.stringify(report[title]))

func run():
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--label="):label=arg.trim_prefix("--label=")
	game=load("res://scenes/main.tscn").instantiate();root.add_child(game)
	game.tuning=PrototypeTuning.DEFAULTS.duplicate();game.tuning.invincible=true
	game.start_game();game.player.smoke_mode=true
	# Match the original layout's starting view, independent of island jitter.
	game.camera_rig.yaw=atan2(-sin(.6)*9,-(cos(.6)-1)*9)
	game.camera_rig.reset_follow()
	game.camera_rig.set_process_unhandled_input(false)
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED);Engine.max_fps=0
	root.set_flag(Window.FLAG_NO_FOCUS,true)
	game.encounters.next_reinforcement=1000000.0
	var sky=game.world.sky_islands
	report["layout"]={"islands":sky.islands.size(),"clouds":sky.clouds.size()}
	await sample("dawn_active")
	game.reset_player_at(sky.islands[6*sky.PER_LAYER+27]+Vector3.UP*.12)
	await sample("middle_active")
	if DisplayServer.get_name()!="headless":
		var scheduled=game.encounters.next_reinforcement
		game.encounters.next_reinforcement=game.encounters.elapsed+8
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://tests/sky-performance/"+label+"-middle.png")
		game.encounters.next_reinforcement=scheduled
	game.reset_player_at(sky.ground_point+Vector3(0,.2,0))
	await sample("ground_active")
	FileAccess.open("res://tests/sky-performance/"+label+".json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	quit()
