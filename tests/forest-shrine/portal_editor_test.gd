extends SceneTree
var game
var checks=0
var failures=0
var config_path="user://portal-editor-%d.cfg"%OS.get_process_id()
var folder="user://portal-editor-maps-%d"%OS.get_process_id()
var pointer_down=false
func _initialize():
	create_timer(90).timeout.connect(func():printerr("FAIL: portal editor timeout");quit(1));run.call_deferred()
func check(ok: bool,message: String):
	checks+=1
	if not ok:failures+=1;printerr("FAIL: "+message)
func settle():
	for i in range(4):await process_frame
func run():
	game=load("res://scenes/forest_shrine.tscn").instantiate();game.settings_path=config_path;root.add_child(game);current_scene=game;await settle();game.open_map_editor();await settle()
	var editor=game.map_editor;editor.map_folder=folder
	check(editor.LABELS.has("portal") and editor.LABELS.has("road"),"Editor palette offers Spawn Portal and Road")
	if failures:await finish();return
	editor.document.decode(JSON.stringify({"format":"forest_shrine_map","schema":1,"title":"Portal Road Test","buildings":[],"trees":[],"deposits":[]}));editor.refresh_document()
	game.pan=Vector3(0,0,90);game.preparation_size=220;game.update_preparation_camera();await settle()
	editor.choose_piece("portal");await click_cell(Vector2i(0,20))
	check(game.model.portals.size()==1 and game.world.portal_nodes.size()==1,"Actual click places a rendered portal")
	editor.choose_piece("");await click_cell(Vector2i(0,20));await key(KEY_R)
	check(game.model.portals[0].rotation==1,"R rotates a selected portal and its exit")
	for i in range(3):await key(KEY_R)
	editor.choose_piece("road");var before=editor.document.history.size()
	await pointer(Vector2i(0,19),true);await motion(Vector2i(0,10));await pointer(Vector2i(0,10),false)
	check(game.model.roads.size()>40 and editor.document.history.size()==before+1,"Dragging paints a wide road as one undo step")
	var road_count=game.model.roads.size();editor.undo();await settle();check(game.model.roads.is_empty(),"Undo removes a whole painted road")
	editor.redo();await settle();check(game.model.roads.size()==road_count,"Redo restores the road and visual batch")
	var batch=game.world.map_features.find_child("RoadTiles",true,false)
	check(batch!=null and batch.multimesh.instance_count==road_count,"Road visuals match every authored tile")
	before=editor.document.history.size();await pointer(Vector2i(6,18),true);await motion(Vector2i(6,12));await key(KEY_ESCAPE);await pointer(Vector2i(6,12),false)
	check(editor.document.history.size()==before and game.model.roads.size()==road_count,"Escape cancels an unfinished stroke")
	var width=editor.find_child("RoadBrushWidth",true,false);width.selected=0;width.item_selected.emit(0)
	await pointer(Vector2i(10,18),true);await motion(Vector2i(10,12));await motion(Vector2i(10,18));await motion(Vector2i(20,18));await pointer(Vector2i(20,18),false)
	check(game.model.roads.has(Vector2i(15,18)) and not game.model.roads.has(Vector2i(15,12)),"Retracing a drag follows the pointer when it changes direction")
	editor.undo();width.selected=2;width.item_selected.emit(2);await settle()
	editor.choose_piece("road");editor.name_field.grab_focus();await motion(Vector2i(8,14));await key(KEY_R)
	check(editor.name_field.has_focus() and game.model.roads.size()==road_count,"Typing and pointer hover cannot paint or rotate")
	editor.choose_piece("");editor.name_field.text="Portal Road Test";editor.save_map();await settle()
	check(not editor.document.dirty,"Portal map saves through normal editor controls")
	if "--visual" in OS.get_cmdline_user_args():await shot("workspace")
	editor.play_map();await settle();game.start_wave();game.model.waves.spawn_clock=0;game.model.waves.tick(.001,game.player.position)
	check(game.model.enemies.size()==3 and game.model.enemies.values().all(func(e):return e.get("portal_index",-1)==0),"A live wave releases its first batch through the authored portal")
	if "--visual" in OS.get_cmdline_user_args():
		game.model.phase="preparing";game.set_phase_view();game.open_map_editor();await settle();await shot("portal")
	await finish()
func click_cell(cell: Vector2i):await pointer(cell,true);await pointer(cell,false)
func pointer(cell: Vector2i,pressed: bool):
	pointer_down=pressed
	var event=InputEventMouseButton.new();event.position=game.camera_rig.camera.unproject_position(game.model.point(cell));event.button_index=MOUSE_BUTTON_LEFT;event.pressed=pressed;root.push_input(event,true);await settle()
func motion(cell: Vector2i):
	var event=InputEventMouseMotion.new();event.position=game.camera_rig.camera.unproject_position(game.model.point(cell));event.button_mask=MOUSE_BUTTON_MASK_LEFT if pointer_down else 0;root.push_input(event,true);await settle()
func key(code: int):
	var event=InputEventKey.new();event.physical_keycode=code;event.pressed=true;root.push_input(event,true);await process_frame;event=event.duplicate();event.pressed=false;root.push_input(event,true);await settle()
func shot(label: String):
	await RenderingServer.frame_post_draw
	var directory=OS.get_environment("SONIC_PORTAL_CAPTURE_DIR")
	if directory.is_empty():directory="/tmp"
	root.get_texture().get_image().save_png(directory+"/portal-road-"+label+".png")
func finish():
	if is_instance_valid(game):
		game.sound_library.cancel();game.music.stop()
		for voice in game.voices:voice.stop()
		game.queue_free()
	paused=false;await settle();await create_timer(.35).timeout
	DirAccess.remove_absolute(ProjectSettings.globalize_path(config_path))
	if DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(folder)):
		for file in DirAccess.get_files_at(folder):DirAccess.remove_absolute(ProjectSettings.globalize_path(folder.path_join(file)))
		DirAccess.remove_absolute(ProjectSettings.globalize_path(folder))
	if has_meta("forest_custom_layout"):remove_meta("forest_custom_layout")
	print("FOREST_PORTAL_EDITOR_RESULT checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)
