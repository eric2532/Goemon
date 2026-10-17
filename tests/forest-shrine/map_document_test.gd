extends SceneTree
var checks=0
var failures=0
var folder="user://forest-map-test-%d"%OS.get_process_id()
func check(ok: bool,message: String):
	checks+=1
	if not ok:failures+=1;printerr("FAIL: "+message)
func _initialize():run.call_deferred()
func run():
	if not ResourceLoader.exists("res://scripts/forest/forest_map_document.gd"):
		check(false,"Forest maps have an editable persistent document");finish();return
	var D=load("res://scripts/forest/forest_map_document.gd")
	var doc=D.new();var original=FileAccess.get_file_as_string(D.ORIGINAL_PATH)
	check(doc.load_original().is_empty(),"Bundled original loads")
	var baseline=doc.encode()
	check(doc.data.buildings.size()==16 and doc.data.deposits.size()==2,"Original preserves the starter fort and two deposits")
	check(not doc.dirty,"Opening a map starts clean")
	check(doc.place("tower",Vector2i(12,10),0).is_empty(),"Editor places a tower without spending gold")
	var pick=doc.object_at(Vector2i(13,11))
	check(pick.get("group")=="buildings","Selection finds the whole tower footprint")
	check(doc.rotate(pick).is_empty() and doc.data.buildings.back().rotation==1,"Selected tower rotates one quarter-turn")
	check(not doc.place("tree",Vector2i(12,10),0).is_empty(),"Trees cannot overlap structures")
	check(not doc.place("wall",Vector2i(2,2),0).is_empty(),"Training dummy ground remains clear")
	check(not doc.place("tree",Vector2i(0,3),0).is_empty(),"Hero start remains clear")
	check(not doc.remove(doc.object_at(Vector2i(0,0))).is_empty(),"Original shrine cannot be deleted")
	check(doc.place("tree",Vector2i(12,14),0).is_empty(),"Editor places a tree")
	check(doc.remove(doc.object_at(Vector2i(12,14))).is_empty(),"Editor deletes a tree")
	check(doc.undo() and doc.object_at(Vector2i(12,14)).get("group")=="trees","Undo restores deleted tree")
	check(doc.redo() and doc.object_at(Vector2i(12,14)).is_empty(),"Redo reapplies deletion")
	check(doc.place("wall",Vector2i(12,12),0).is_empty() and doc.place("tree",Vector2i(12,15),0).is_empty(),"Free space accepts a wall and a nearby tree")
	var before_rotation=doc.encode()
	check(not doc.rotate(doc.object_at(Vector2i(12,12))).is_empty() and doc.encode()==before_rotation,"Rotation rejects a blocked footprint atomically")
	check(doc.place("deposit",Vector2i(16,10),0).is_empty(),"Editor places a gold deposit")
	check(doc.place("mine",Vector2i(16,10),0).is_empty(),"Mines can be authored on deposits")
	check(not doc.remove({"group":"deposits","index":doc.data.deposits.size()-1}).is_empty(),"Delete deposit requires removing its mine first")
	doc.rename("Valley / Test");check(doc.save(folder).is_empty(),"Named map saves atomically")
	check(not doc.dirty and doc.path.begins_with(folder+"/"),"Save stays inside custom map folder")
	var restored=D.new();check(restored.read_file(doc.path).is_empty() and restored.encode()==doc.encode(),"Disk round-trip preserves complete authored layout")
	doc.rename("Other Valley");check(doc.save(folder).is_empty() and D.list_maps(folder).size()==2,"Different names preserve separate maps")
	doc.place("tree",Vector2i(12,14),0);doc.rename("Renamed Valley");doc.undo()
	check(doc.data.title=="Renamed Valley","Undoing geometry preserves the typed map name")
	var before=doc.encode()
	for invalid in ["{broken",JSON.stringify({"format":"other","schema":1})," ".repeat(600000)]:
		check(not doc.decode(invalid).is_empty() and doc.encode()==before,"Invalid file cannot replace the open map")
	var bad=doc.data.duplicate(true);bad.buildings.append({"kind":"tower","x":999999,"z":0,"rotation":0,"span":0})
	check(not doc.decode(JSON.stringify(bad)).is_empty() and doc.encode()==before,"Out-of-bounds objects reject the whole file")
	bad=doc.data.duplicate(true);bad.trees.append({"x":12,"z":10,"scale":1})
	check(not doc.decode(JSON.stringify(bad)).is_empty(),"Loaded overlaps are rejected")
	check(FileAccess.get_file_as_string(D.ORIGINAL_PATH)==original,"Saving custom layouts never changes the original")
	check(doc.load_original().is_empty() and doc.encode()==baseline,"Original Map restores the exact protected layout")
	check(doc.play_error().is_empty(),"Protected original has valid worker routes")
	check(doc.place("tree",Vector2i(-3,3),0).is_empty() and not doc.play_error().is_empty(),"Play rejects layouts with a blocked tower entrance")
	var model=load("res://scripts/forest/forest_model.gd").new();model.reset(42)
	var copy=D.new();copy.capture(model);copy.data.title="Original Forest Shrine"
	check(copy.encode()==baseline,"Bundled original exactly matches the pre-editor generated map")
	doc.load_original()
	for cell in [Vector2i(-2,3),Vector2i(-1,4),Vector2i(-2,5)]:doc.place("tree",cell,0)
	check(not doc.play_error().is_empty(),"Play rejects layouts that strand starting workers")
	finish()
func finish():
	if DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(folder)):
		for name in DirAccess.get_files_at(folder):DirAccess.remove_absolute(ProjectSettings.globalize_path(folder.path_join(name)))
		DirAccess.remove_absolute(ProjectSettings.globalize_path(folder))
	print("FOREST_MAP_DOCUMENT_RESULT checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)
