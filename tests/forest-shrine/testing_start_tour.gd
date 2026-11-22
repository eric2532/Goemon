extends SceneTree
var failures=0
var game
var capture_dir=""
func check(ok: bool,message: String):
	if not ok:failures+=1;printerr("FAIL: "+message)
func _initialize():call_deferred("run")
func capture(name_: String):
	for i in range(5):await process_frame
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(capture_dir+"/"+name_+".png")==OK,"Capture saves: "+name_)
func run():
	if DisplayServer.get_name()=="headless":quit(1);return
	capture_dir=OS.get_environment("FOREST_TESTING_CAPTURE_DIR")
	DirAccess.make_dir_recursive_absolute(capture_dir)
	game=load("res://scenes/forest_shrine.tscn").instantiate();root.add_child(game);current_scene=game
	await process_frame;await process_frame
	game.set_process(false)
	game.forest_ui.sync()
	check(game.model.gold==1000000,"The run starts with the testing treasury")
	check(game.model.buildings.values().filter(func(b):return b.kind=="mine" and game.world.structure_nodes.has(b.id)).size()==2,"Both starter mines appear in the battlefield")
	check(game.model.workers.is_empty(),"The opening settlement has no workers")
	await capture("starting-settlement")
	game.recruit_worker()
	check(game.model.workers.size()==1,"The opening settlement supports paid worker recruitment")
	for x in range(-8,-2):game.model.explored[Vector2i(x,7)]=true
	var wall=game.model.build("wall",Vector2i(-8,7),0)
	check(not wall.is_empty(),"A six-cell wall can be bought through the live model")
	game.world.sync(0);game.forest_ui.sync()
	game.world.show_preview("wall",Vector2i(-8,7),0,true)
	check(game.world.preview_mesh.mesh.size.x==36,"The placement preview spans the full doubled wall length")
	game.world.preview.hide()
	await capture("workers-and-doubled-wall")
	print("FOREST_TESTING_TOUR_RESULT failures=%d"%failures)
	await game.quit_clean();quit(1 if failures else 0)
