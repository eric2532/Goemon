extends SceneTree
var checks=0
var failures=0
func check(ok:bool,message:String):
	checks+=1
	if not ok:failures+=1;printerr("FAIL: "+message)
func _initialize():
	var Document=load("res://scripts/forest/forest_map_document.gd")
	if not "include_mines" in Document.new():
		check(false,"The editor can load legacy maps with mines disabled");finish();return
	var source=FileAccess.get_file_as_string(Document.ORIGINAL_PATH)
	var legacy=Document.new();check(legacy.decode(source).is_empty(),"Legacy map still decodes")
	var mines=legacy.data.buildings.filter(func(b):return b.kind=="mine")
	check(not mines.is_empty() and not legacy.data.deposits.is_empty(),"Generic map data preserves legacy mine records")
	var doc=Document.new(false)
	check(doc.load_original().is_empty(),"Mine-free editor loads the original map")
	check(doc.data.buildings.all(func(b):return b.kind!="mine") and doc.data.deposits.is_empty(),"Editor geometry omits disabled structures and deposits")
	var cell=Vector2i(mines[0].x,mines[0].z)
	check(doc.object_at(cell).is_empty(),"No invisible mine or deposit is selectable")
	check(doc.placement_error("tower",cell,0).is_empty(),"Former mine ground is buildable")
	check(doc.place("tower",cell,0).is_empty(),"A new tower can occupy the removed mine footprint")
	check(doc.undo() and doc.object_at(cell).is_empty(),"Undo restores clear ground")
	check(doc.redo() and doc.object_at(cell).get("group")=="buildings","Redo restores the new tower")
	check(not doc.placement_error("mine",cell,0).is_empty() and not doc.place("deposit",Vector2i(20,20),0).is_empty(),"Disabled mine tools cannot create invisible objects")
	check(FileAccess.get_file_as_string(Document.ORIGINAL_PATH)==source,"Loading and editing never modifies the original file")
	var custom=legacy.data.duplicate(true);custom.title="Legacy custom map"
	check(doc.decode(JSON.stringify(custom)).is_empty() and doc.data.deposits.is_empty(),"Custom saved maps also normalize into a mine-free editor")
	check(legacy.data.buildings.filter(func(b):return b.kind=="mine").size()==mines.size(),"Source map object remains intact")
	finish()
func finish():
	print("MINE_FREE_EDITOR_RESULT checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)
