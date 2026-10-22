extends SceneTree
## Animation review stage using the runtime model/state machine. World travel
## is illustrative; separate integration tests exercise real jump physics.
var game
var output=""
var index=0
var model
var hero
var label: Label
var trace=[]
func _initialize():run.call_deferred()
func frames(n: int):
	for i in n:await process_frame
func shot(title: String):
	await process_frame
	label.text=title
	RenderingServer.force_draw(false)
	root.get_texture().get_image().save_png(output+"/frame_%04d.png"%index)
	trace.append({"frame":index,"label":title,"clip":model.current_clip,"time":model.animation_player.current_animation_position})
	index+=1
func motion(title: String,n: int,speed: float,grounded: bool,vertical: float):
	for i in n:
		model.animate(1.0/30.0,speed,grounded,vertical,0,false,0,false)
		await shot(title)
func run():
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--motion-capture-dir="):output=arg.trim_prefix("--motion-capture-dir=")
	assert(not output.is_empty())
	DirAccess.make_dir_recursive_absolute(output)
	root.size=Vector2i(640,640)
	game=load("res://scenes/forest_title.tscn").instantiate()
	game.settings_path="user://musashi-motion-preview-%s.cfg"%OS.get_process_id()
	root.add_child(game);current_scene=game
	await frames(10)
	game.begin_forest();game.choose_rogue_character(13);game.start_wave()
	await frames(10)
	paused=true
	hero=game.player;model=hero.model
	model.reparent(root);model.position=Vector3.ZERO;model.rotation=Vector3.ZERO
	model.scale=Vector3.ONE;model.show();hero.active_ability.cancel()
	game.hide();game.forest_ui.hide()
	var camera=Camera3D.new();root.add_child(camera);camera.make_current()
	camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=2.9
	camera.position=Vector3(-2.0,1.5,-4);camera.look_at(Vector3.UP*.95)
	var world=WorldEnvironment.new();root.add_child(world)
	world.environment=Environment.new();world.environment.background_mode=Environment.BG_COLOR
	world.environment.background_color=Color("24313b")
	var canvas=CanvasLayer.new();root.add_child(canvas)
	label=Label.new();label.position=Vector2(20,20);label.add_theme_font_size_override("font_size",21)
	canvas.add_child(label)
	hero.jumps_used=0
	await motion("RECOVERED MUSASHI · IDLE",15,0,true,0)
	await motion("ORIGINAL RUN CYCLE",32,7,true,0)
	hero.jumps_used=1
	await motion("STANDING JUMP · RISE",13,0,false,6)
	await motion("STANDING JUMP · FALL",12,0,false,-4)
	hero.jumps_used=0
	await motion("STANDING JUMP · LAND",12,0,true,0)
	hero.jumps_used=1
	await motion("RUNNING JUMP · RISE",10,7,false,6)
	await motion("RUNNING JUMP · FALL",12,7,false,-4)
	hero.jumps_used=2
	await motion("DOUBLE JUMP · ORIGINAL FLIP",8,7,false,10)
	await motion("DOUBLE JUMP · RISE",8,7,false,5)
	await motion("DOUBLE JUMP · FALL",12,7,false,-4)
	hero.jumps_used=0
	await motion("MOVING LANDING",12,0,true,0)
	for cut in 3:
		var clip=model.STRIKES[cut]
		var n=roundi(model.animation_player.get_animation(clip).length*30)
		for i in n:
			model._sample(clip,i/30.0)
			await shot("FUSION · ORIGINAL CUT %d"%(cut+1))
	for i in 21:
		model._sample(model.HEAVY,i/30.0)
		await shot("LUMINA · ORIGINAL SWING")
	await motion("RECOVERED MUSASHI",12,0,true,0)
	var file=FileAccess.open(output+"/trace.json",FileAccess.WRITE);file.store_string(JSON.stringify(trace,"\t"));file.close()
	print("MUSASHI_PREVIEW frames=",index)
	paused=false;current_scene=null;game.queue_free();model.queue_free();canvas.queue_free();world.queue_free();camera.queue_free();await frames(3)
	quit()
