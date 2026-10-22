extends SceneTree
var checks=0
var failures=0
var folder="user://forest-kai-map-test-%d"%OS.get_process_id()
var config_path="user://forest-kai-map-test-%d.cfg"%OS.get_process_id()
func check(ok: bool,message: String):
	checks+=1
	if not ok:failures+=1;printerr("FAIL: "+message)
func _initialize():
	create_timer(90).timeout.connect(func():printerr("FAIL: Kai map document timeout");quit(1));run.call_deferred()
func run():
	var D=load("res://scripts/forest/forest_map_document.gd")
	var Model=load("res://scripts/forest/forest_model.gd")
	var legacy=JSON.parse_string(FileAccess.get_file_as_string(D.ORIGINAL_PATH))
	check(D.validate(legacy).is_empty(),"Legacy maps without a terrain source still load")
	var empty_source=legacy.duplicate(true);empty_source.terrain_source=""
	check(D.validate(empty_source).is_empty(),"An explicitly empty terrain source retains legacy terrain")
	for source in [null,1,true,[],{},"unknown","Kai Highway","kai_highway "]:
		var invalid=legacy.duplicate(true);invalid.terrain_source=source
		check(not D.validate(invalid).is_empty(),"Invalid terrain source is rejected: %s"%str(source))
	var blank={"format":"forest_shrine_map","schema":1,"title":"Terrain placement","buildings":[],"trees":[],"deposits":[],"portals":[],"roads":[],"ramparts":[],"terrain_source":"kai_highway"}
	var placement=blank.duplicate(true);placement.trees.append({"x":5,"z":-4,"scale":1})
	check(D.validate(placement).is_empty(),"Kai castle clearing accepts a tree outside protected ground")
	placement=blank.duplicate(true);placement.trees.append({"x":-34,"z":-34,"scale":1})
	check(not D.validate(placement).is_empty(),"Kai placement rejects an off-terrain tile")
	placement.erase("terrain_source")
	check(D.validate(placement).is_empty(),"Legacy flat terrain keeps its original placement rules")
	var workspace=load("res://scripts/forest/forest_map_editor.gd").new();root.add_child(workspace)
	check(workspace.find_child("KaiHighwayForestMap",true,false) is Button,"Map Editor offers the Kai Highway Castle preset")
	workspace.free()
	var doc=D.new()
	if not doc.has_method("load_kai_highway"):
		check(false,"The Kai Highway Castle preset can be opened as an editable document");finish();return
	var error=doc.load_kai_highway()
	check(error.is_empty(),"Kai Highway Castle loads: "+error)
	if not error.is_empty():finish();return
	check(doc.data.title=="Kai Highway Castle" and doc.data.get("terrain_source")=="kai_highway","The bundled preset retains its title and terrain identity")
	check(doc.data.portals.size()==8,"The Kai preset retains all eight spawn portals")
	check(not doc.dirty,"Opening Kai starts with a clean document")
	var model=Model.new();model.reset(42,{},doc.data)
	check(model.get("terrain_source")=="kai_highway","The real model activates the Kai terrain from the document")
	var captured=D.new();captured.capture(model)
	check(captured.data.get("terrain_source")=="kai_highway","Capturing the active model retains Kai terrain")
	check(captured.data.portals.size()==8,"Capturing Kai retains all eight portals")
	var before=doc.encode()
	var invalid=doc.data.duplicate(true);invalid.terrain_source="unknown"
	check(not doc.decode(JSON.stringify(invalid)).is_empty() and doc.encode()==before,"Invalid terrain cannot replace the open Kai map")
	check(doc.remove({"group":"portals","index":0}).is_empty(),"Kai portal edits use the existing document history")
	check(doc.data.portals.size()==7 and doc.data.get("terrain_source")=="kai_highway","Editing a portal preserves Kai terrain identity")
	check(doc.undo() and doc.data.portals.size()==8 and doc.data.get("terrain_source")=="kai_highway","Undo restores the Kai portal without changing terrain")
	check(doc.redo() and doc.data.portals.size()==7 and doc.data.get("terrain_source")=="kai_highway","Redo preserves Kai terrain identity")
	check(doc.undo(),"Restore all eight portals before saving")
	doc.rename("My Kai Castle")
	check(doc.save(folder).is_empty(),"A custom Kai layout saves to the user map folder")
	var restored=D.new();error=restored.read_file(doc.path)
	check(error.is_empty() and restored.encode()==doc.encode(),"Disk roundtrip preserves the complete Kai map")
	check(restored.data.get("terrain_source")=="kai_highway" and restored.data.portals.size()==8,"The saved Kai map retains terrain and all eight portals")
	var reloaded_model=Model.new();reloaded_model.reset(42,{},restored.data)
	check(reloaded_model.get("terrain_source")=="kai_highway","Reloading a saved Kai map activates the real terrain")
	check(restored.load_original().is_empty(),"Original Map remains available after loading Kai")
	check(restored.data.get("terrain_source","")=="","Original Map clears the Kai terrain identity")
	check(restored.load_ramparts().is_empty(),"Twin Ramparts remains available after loading Kai")
	check(restored.load_four_gates().is_empty(),"Four Gates remains available after loading Kai")
	if "--editor" in OS.get_cmdline_user_args():await editor_checks(D)
	finish()
func editor_checks(D):
	var game=load("res://scenes/forest_shrine.tscn").instantiate();game.settings_path=config_path;root.add_child(game);current_scene=game
	for i in range(4):await process_frame
	var source=JSON.parse_string(FileAccess.get_file_as_string(D.KAI_HIGHWAY_PATH))
	if has_meta("forest_custom_layout"):remove_meta("forest_custom_layout")
	game.preview_forest_map(source)
	game.open_map_editor()
	for i in range(4):await process_frame
	var editor=game.map_editor
	check(editor.active and editor.name_field.text=="Kai Highway Castle","Opening the active Kai map uses its terrain identity before eight-portal Four Gates detection")
	check(editor.document.data.get("terrain_source")=="kai_highway","Opening the real editor captures active Kai terrain")
	var kai_button=editor.find_child("KaiHighwayForestMap",true,false)
	check(kai_button is Button,"Map Editor exposes the Kai Highway Castle preset")
	check(editor.find_child("FourGatesForestMap",true,false) is Button and editor.find_child("RampartsForestMap",true,false) is Button and editor.find_child("OriginalForestMap",true,false) is Button,"Map Editor keeps the existing map presets")
	editor.load_original()
	for i in range(4):await process_frame
	if kai_button is Button:
		kai_button.pressed.emit()
		for i in range(4):await process_frame
		check(editor.name_field.text=="Kai Highway Castle" and game.model.get("terrain_source")=="kai_highway" and editor.document.data.portals.size()==8,"The actual Kai preset button loads its terrain, title and all eight portals")
		editor.name_field.text="My Kai Castle";editor.document.rename("My Kai Castle");editor.play_map()
		for i in range(4):await process_frame
		check(not editor.active and get_meta("forest_custom_layout",{}).get("title")=="My Kai Castle","Playing a custom Kai map retains its chosen name")
		if not editor.active:
			game.open_map_editor()
			for i in range(4):await process_frame
			check(editor.active and editor.name_field.text=="My Kai Castle" and editor.document.data.get("terrain_source")=="kai_highway","Reopening a custom Kai map prefers its saved name over the preset title")
	if editor.active:editor.close_discard()
	if has_meta("forest_custom_layout"):remove_meta("forest_custom_layout")
	game.sound_library.cancel();game.music.stop()
	for voice in game.voices:voice.stop()
	game.queue_free();paused=false
	for i in range(4):await process_frame
	await create_timer(.35).timeout
	DirAccess.remove_absolute(ProjectSettings.globalize_path(config_path))
func finish():
	if DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(folder)):
		for name in DirAccess.get_files_at(folder):DirAccess.remove_absolute(ProjectSettings.globalize_path(folder.path_join(name)))
		DirAccess.remove_absolute(ProjectSettings.globalize_path(folder))
	print("FOREST_KAI_MAP_DOCUMENT_RESULT checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)
