extends SceneTree
var game
var checks=0
var failures=0
var config_path="user://forest-editor-%d.cfg"%OS.get_process_id()
var folder="user://forest-editor-maps-%d"%OS.get_process_id()
func _initialize():
	node_added.connect(func(node):
		if node.get_script()==load("res://scripts/forest/forest_game.gd"):node.settings_path=config_path)
	create_timer(90).timeout.connect(func():printerr("FAIL: map editor timeout");quit(1));run.call_deferred()
func check(ok: bool,message: String):
	checks+=1
	if not ok:failures+=1;printerr("FAIL: "+message)
func settle():
	for i in range(4):await process_frame
func run():
	game=load("res://scenes/forest_shrine.tscn").instantiate();game.settings_path=config_path;root.add_child(game);current_scene=game;await settle()
	var entry=game.forest_ui.find_child("PreparationMapEditor",true,false)
	check(entry is Button,"Building view exposes Map Editor")
	if entry==null:await finish();return
	var previous=game.model;var gold=previous.gold
	if "--visual" in OS.get_cmdline_user_args():await shot("building")
	await click(entry);var editor=game.map_editor;editor.map_folder=folder
	check(editor.active and paused and not game.forest_ui.visible,"Editor pauses gameplay and clears construction HUD")
	check(game.model!=previous and previous.gold==gold,"Editor preview isolates the existing run")
	game.preparation_size=220;game.update_preparation_camera();await settle()
	editor.choose_piece("tower");await map_click(Vector2i(12,10))
	check(game.model.occupancy.has(Vector2i(12,10)) and game.model.gold==gold,"Actual map click places a free preview tower")
	editor.choose_piece("");await map_click(Vector2i(12,10));await key(KEY_R)
	var selected=editor.document.selected_item(editor.selection)
	check(selected.get("rotation")==1,"R rotates the selected structure")
	await key(KEY_DELETE)
	check(not game.model.occupancy.has(Vector2i(12,10)),"Delete removes selected structure and collision occupancy")
	editor.undo();await settle();check(game.model.occupancy.has(Vector2i(12,10)),"Undo restores structure and navigation")
	editor.choose_piece("tree");await map_click(Vector2i(12,14));await settle()
	check(game.model.trees.has(Vector2i(12,14)) and game.model.allied_grid.is_point_solid(Vector2i(12,14)),"Trees update visible map and navigation")
	await physics_frame
	var query=PhysicsRayQueryParameters3D.create(Vector3(72,20,84),Vector3(72,1,84),1)
	check(not game.world.get_world_3d().direct_space_state.intersect_ray(query).is_empty(),"Authored trees have physical collision")
	editor.choose_piece("");await map_click(Vector2i(12,14));await key(KEY_DELETE);await settle();await physics_frame
	check(game.world.get_world_3d().direct_space_state.intersect_ray(query).is_empty(),"Deleted tree leaves no stale collision body")
	editor.name_field.grab_focus();editor.name_field.text="River Defense"
	var hover=InputEventMouseMotion.new();hover.position=game.camera_rig.camera.unproject_position(game.model.point(Vector2i(12,10)))
	root.push_input(hover,true);await settle()
	check(editor.name_field.has_focus(),"Moving the pointer out of the name field keeps text focus")
	var rotation=editor.placement_rotation;await key(KEY_R);await key(KEY_2)
	check(editor.placement_rotation==rotation and game.build_kind.is_empty() and not game.rogue_roster_open,"Typing cannot trigger editor or construction shortcuts")
	editor.choose_piece("");editor.name_field.grab_focus();await map_click(Vector2i(12,10))
	check(not editor.name_field.has_focus() and not editor.selection.is_empty(),"Clicking the map after typing resumes selection")
	editor.save_map();await settle()
	check(not editor.document.dirty and editor.saved_maps.item_count==1,"Saved map appears in the load picker")
	var saved_path=editor.document.path
	editor.name_field.text="Second Layout";editor.save_map();await settle()
	editor.name_field.text="River Defense";editor.save_map();await settle()
	check(editor.confirmation.visible,"Saving over another named map requires confirmation")
	editor.confirmation.canceled.emit();editor.confirmation.hide();await settle()
	editor.choose_piece("wall");await map_click(Vector2i(12,12));check(editor.document.dirty,"Further edits mark map unsaved")
	editor.load_original();await settle()
	check(editor.confirmation.visible and editor.document.dirty,"Original Map asks before discarding unsaved edits")
	editor.confirmation.canceled.emit();editor.confirmation.hide();await settle()
	check(editor.document.dirty,"Cancel preserves unsaved work")
	editor.load_original();editor.confirmation.confirmed.emit();editor.confirmation.hide();await settle()
	check(editor.document.data.title=="Original Forest Shrine" and game.model.buildings.size()==17 and game.model.trees.size()==650,"Original Map restores the protected current map")
	if "--visual" in OS.get_cmdline_user_args():await shot("original")
	for i in range(editor.saved_maps.item_count):
		if editor.saved_maps.get_item_metadata(i)==saved_path:editor.saved_maps.selected=i
	await click(editor.find_child("LoadForestMap",true,false));await settle()
	check(editor.document.path==saved_path and editor.document.data.title=="River Defense","Load picker restores the named layout from disk")
	editor.play_map();await settle()
	check(not editor.active and game.forest_ui.visible and game.model.phase=="preparing" and game.model.wave==0,"Play map starts fresh in building preparation")
	check(game.model.occupancy.has(Vector2i(12,10)) and game.model.gold==gold,"Played map uses its saved layout and current starting gold")
	check(get_meta("forest_custom_layout",{}).get("title")=="River Defense","Selected map remains available to Instant Restart")
	game.restart_area();await settle();game=current_scene;editor=game.map_editor;editor.map_folder=folder
	check(game.model.occupancy.has(Vector2i(12,10)) and game.model.wave==0 and game.model.gold==gold,"Actual Instant Restart retains the custom layout and resets the run")
	game.open_map_editor();await settle();editor=game.map_editor;editor.map_folder=folder
	game.preparation_size=220;game.update_preparation_camera();await settle()
	editor.choose_piece("tree");await map_click(Vector2i(12,14));editor.back_to_building();await settle()
	check(editor.confirmation.visible,"Leaving unsaved edits requires discard confirmation")
	editor.confirmation.confirmed.emit();editor.confirmation.hide();await settle()
	check(not editor.active and not game.model.trees.has(Vector2i(12,14)),"Discard returns to the pre-editor map")
	game.start_wave();await settle();game.open_map_editor()
	check(not editor.active and game.model.phase=="wave","Editor cannot mutate an active wave")
	game.model.phase="preparing";game.set_phase_view();game.open_map_editor();await settle()
	if "--visual" in OS.get_cmdline_user_args():await shot("workspace")
	editor.close_discard();await finish()
func key(code: int):
	var event=InputEventKey.new();event.physical_keycode=code;event.pressed=true;root.push_input(event,true);await process_frame
	event=event.duplicate();event.pressed=false;root.push_input(event,true);await settle()
func click(button: Button):
	await pointer(button.get_global_rect().get_center())
func map_click(cell: Vector2i):
	await pointer(game.camera_rig.camera.unproject_position(game.model.point(cell)))
func pointer(position: Vector2):
	var event=InputEventMouseButton.new();event.position=position;event.button_index=MOUSE_BUTTON_LEFT;event.pressed=true;root.push_input(event,true);await process_frame
	event=event.duplicate();event.pressed=false;root.push_input(event,true);await settle()
func shot(label: String):
	await RenderingServer.frame_post_draw
	var directory=OS.get_environment("SONIC_MAP_CAPTURE_DIR")
	if directory.is_empty():directory="/tmp"
	root.get_texture().get_image().save_png(directory+"/forest-map-editor-"+label+".png")
func finish():
	if is_instance_valid(game):
		game.sound_library.cancel();game.music.stop()
		for voice in game.voices:voice.stop()
		game.queue_free()
	paused=false;await settle();await create_timer(.35).timeout
	DirAccess.remove_absolute(ProjectSettings.globalize_path(config_path))
	if DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(folder)):
		for name in DirAccess.get_files_at(folder):DirAccess.remove_absolute(ProjectSettings.globalize_path(folder.path_join(name)))
		DirAccess.remove_absolute(ProjectSettings.globalize_path(folder))
	if has_meta("forest_custom_layout"):remove_meta("forest_custom_layout")
	print("FOREST_MAP_EDITOR_RESULT checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)
