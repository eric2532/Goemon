extends SceneTree
## A nearby placement preview must commit the displayed footprint, exactly once.
const OUT="/Users/eric/Desktop/Projects_Codex/Sonic/build/Other Files/Building Anywhere/"
var game
var checks=0
var failures=0
var cfg="user://preparation-placement-%d.cfg"%OS.get_process_id()
func _initialize():
	set_meta("forest_army_backend","legacy");set_meta("forest_painterly_preview",true)
	create_timer(90).timeout.connect(func():printerr("FAIL: placement preview timed out");quit(1))
	run.call_deferred()
func check(ok:bool,label_:String):
	checks+=1
	if not ok:failures+=1;printerr("FAIL: ",label_)
func frames():
	for i in 3:await process_frame
func run():
	await process_frame
	# The development launcher supplies a scene; replace it with this fixture.
	if current_scene!=null:
		current_scene.queue_free();current_scene=null;await frames()
	for child in root.get_children():
		if child.scene_file_path=="res://scenes/forest_shrine.tscn":child.queue_free()
	await frames()
	root.size=Vector2i(1280,800)
	var doc=load("res://scripts/forest/forest_map_document.gd").new()
	if "--visual" in OS.get_cmdline_user_args():doc.load_blood_gulch()
	else:doc.load_original()
	set_meta("forest_custom_layout",doc.data)
	game=load("res://scenes/forest_shrine.tscn").instantiate();game.settings_path=cfg;root.add_child(game);current_scene=game
	await frames();AudioServer.set_bus_mute(0,true)
	check(game.has_method("build_placement_target"),"Construction resolves a shared preview and click target")
	if not game.has_method("build_placement_target"):await finish();return
	game.model.gold=5000;game.forest_ui.open_build_menu();game.select_build("tower");game.build_rotation=1
	var raw=Vector2i.ZERO;var resolved={}
	for z in range(5,23):
		for x in range(-22,23):
			var target=game.build_placement_target(Vector2i(x,z))
			if target.adjusted and target.error.is_empty():raw=Vector2i(x,z);resolved=target;break
		if not resolved.is_empty():break
	check(not resolved.is_empty(),"An obstructed footprint finds an adjacent clear construction site")
	if resolved.is_empty():await finish();return
	check(absi(resolved.cell.x-raw.x)<=1 and absi(resolved.cell.y-raw.y)<=1,"Automatic placement stays within one grid tile of the cursor")
	var count=game.model.buildings.size();var gold=game.model.gold
	var same=game.build_placement_target(raw)
	check(same.cell==resolved.cell and game.model.buildings.size()==count and game.model.gold==gold,"Preview is stable and does not build or charge")
	game.pan=game.model.point(raw);game.pan.y=0;game.preparation_size=72;game.update_preparation_camera()
	game.set_process(false)
	game.update_build_preview(raw);game.forest_ui.sync();await frames()
	var expected=game.model.center({"kind":"tower","cell":resolved.cell,"rotation":1})
	check(game.world.preview.visible and game.world.preview.position.distance_to(expected)<.01,"The production hover preview shows the resolved footprint")
	check(game.forest_ui.hint.visible and game.forest_ui.hint.text.contains("Nearby clear spot"),"The selected build card keeps placement feedback visible")
	await capture("nearby-preview")
	var worker=game.model.workers.values()[0];worker.pos=game.model.point(resolved.cell)
	var worker_origin:Vector3=worker.pos
	check(game.place_cell(raw),"An actor entering the preview steps aside while its displayed tower is placed")
	check(not game.model.occupancy.has(game.model.cell_of(worker.pos)) and worker.pos.distance_to(worker_origin)<16,"The covered worker moves to nearby open ground after purchase")
	var added=game.model.buildings.values().filter(func(b):return b.kind=="tower" and b.cell==resolved.cell)
	check(added.size()==1 and game.model.buildings.size()==count+1 and game.model.gold==gold-game.model.COSTS.tower,"The displayed footprint is built and charged exactly once")
	check(game.build_kind=="tower" and game.build_rotation==1 and game.world.preview.visible,"A successful placement retains the building, rotation, and next preview")
	await capture("placed-tower")
	var fresh=game.build_placement_target(raw)
	check(not fresh.error.is_empty() or fresh.cell!=resolved.cell,"The next preview never reuses a newly occupied footprint")
	var fresh_center=game.model.center({"kind":"tower","cell":fresh.cell,"rotation":1})
	check(game.world.preview.position.distance_to(fresh_center)<.01,"The next preview refreshes immediately after construction")
	var next_cell=clear_cell("tower",1)
	check(next_cell.x!=-999 and game.place_cell(next_cell),"A second tower can be placed without selecting its card again")
	check(game.model.buildings.size()==count+2 and game.model.gold==gold-2*game.model.COSTS.tower,"Two repeated placements create and charge for exactly two towers")
	game.forest_ui.sync()
	check(game.forest_ui.build_buttons.tower.button_pressed,"The tower card stays selected after repeated placement")
	game.select_build("barracks");game.build_rotation=3
	count=game.model.buildings.size();gold=game.model.gold
	for i in 2:
		next_cell=clear_cell("barracks",3)
		check(next_cell.x!=-999 and game.place_cell(next_cell),"Barracks placement %d succeeds without reselecting the card"%(i+1))
	check(game.build_kind=="barracks" and game.build_rotation==3 and game.model.buildings.size()==count+2 and game.model.gold==gold-2*game.model.COSTS.barracks,"Repeated barracks preserve rotation and charge once per building")
	gold=game.model.gold;count=game.model.buildings.size()
	check(not game.place_cell(Vector2i(500,500)) and game.model.gold==gold and game.model.buildings.size()==count and game.build_kind=="barracks","Invalid ground keeps the selected building without spending")
	next_cell=clear_cell("barracks",3);game.model.gold=0
	check(next_cell.x!=-999 and not game.place_cell(next_cell) and game.model.gold==0 and game.model.buildings.size()==count and game.build_kind=="barracks","Insufficient funds keep the selected building without constructing")
	var cancel=InputEventMouseButton.new();cancel.button_index=MOUSE_BUTTON_RIGHT;cancel.pressed=true
	game._unhandled_input(cancel)
	check(game.build_kind.is_empty() and not game.world.preview.visible,"Right-click cancels repeated placement and hides the preview")
	game.model.gold=gold
	game.select_build("wall");var wall=game.build_placement_target(raw)
	check(wall.cell==raw and not wall.adjusted,"Wall drags retain their exact grid endpoints")
	game.build_kind="";game.world.preview.hide();game.reset_preparation_zoom();game.forest_ui.sync();await frames();await capture("map-overview")
	await finish()
func clear_cell(kind:String,rotation:int)->Vector2i:
	for z in range(5,23):
		for x in range(-22,23):
			var cell=Vector2i(x,z)
			if game.model.placement_error(kind,cell,rotation).is_empty():return cell
	return Vector2i(-999,-999)
func capture(label_:String):
	if "--visual" not in OS.get_cmdline_user_args() or DisplayServer.get_name()=="headless":return
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(OUT);root.get_texture().get_image().save_png(OUT+label_+".png")
func finish():
	game.sound_library.cancel();game.music.stop();game.queue_free();paused=false;await frames();await create_timer(.25).timeout
	if FileAccess.file_exists(cfg):DirAccess.remove_absolute(ProjectSettings.globalize_path(cfg))
	print("PREPARATION_PLACEMENT_PREVIEW_RESULT checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)
