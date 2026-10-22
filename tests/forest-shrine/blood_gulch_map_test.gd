extends SceneTree
const Document=preload("res://scripts/forest/forest_map_document.gd")
const Model=preload("res://scripts/forest/forest_model.gd")
var checks=0
var failures=0
var folder="user://blood-gulch-map-%d"%OS.get_process_id()
func _initialize():run.call_deferred()
func check(ok:bool,label_:String):
 checks+=1;print("PASS: " if ok else "FAIL: ",label_)
 if not ok:failures+=1
func run():
 var doc=Document.new(false)
 check(doc.has_method("load_blood_gulch"),"The map document can load the Blood Gulch Castle preset")
 if not doc.has_method("load_blood_gulch"):finish();return
 var error=doc.load_blood_gulch()
 check(error.is_empty(),"The Blood Gulch preset passes the existing map validation: "+error)
 if not error.is_empty():finish();return
 check(doc.data.title=="Blood Gulch Castle" and doc.data.terrain_source=="blood_gulch","The preset retains its name and terrain identity")
 check(doc.data.portals.size()==8,"Eight enemy entries surround the castle")
 check(doc.data.buildings.filter(func(b):return b.kind=="gate").size()==4,"The castle keeps four gates")
 check(doc.data.trees.is_empty() and doc.data.deposits.is_empty(),"The battlefield has open approaches and no gold mines")
 var model=Model.new();model.reset(42,{},doc.data,false)
 check(model.terrain_source=="blood_gulch" and model.has_elevation(),"Authoritative terrain activates Blood Gulch")
 check(model.terrain.width==161 and is_equal_approx(model.terrain.spacing,3.6),"Stretched Blood Gulch reuses the same samples at 3.6-metre spacing")
 var clear_pad=true
 for x in range(-10,11):
  for z in range(-10,11):
   if not model.terrain.contains(x*6,z*6) or not is_zero_approx(model.surface_height(x*6,z*6)):clear_pad=false
 check(clear_pad,"The central castle and training area are level and supported")
 for portal in model.portals:
  var point=model.waves.routes.exit_point(portal,0);point.y=model.surface_height(point.x,point.z)
  check(model.waves.navigation.terrain_clear(point,3.9),"Portal %s has open ground for an ordinary enemy"%Vector2i(portal.x,portal.z))
  check(not model.route(model.cell_of(point),model.shrine_entry(),true).is_empty(),"Portal %s has a connected attack route to the castle"%Vector2i(portal.x,portal.z))
 var captured=Document.new(false);captured.capture(model)
 check(captured.data.get("terrain_source")=="blood_gulch","Capturing a custom map retains Blood Gulch terrain")
 doc.rename("My Sunny Castle");check(doc.save(folder).is_empty(),"A custom Blood Gulch layout saves separately")
 var loaded=Document.new(false);error=loaded.read_file(doc.path)
 check(error.is_empty() and loaded.encode()==doc.encode(),"Saving and reloading retains the full custom Blood Gulch layout")
 var previous=doc.encode();var invalid=doc.data.duplicate(true);invalid.terrain_source="unknown"
 check(not doc.decode(JSON.stringify(invalid)).is_empty() and doc.encode()==previous,"Unknown terrain cannot replace the current map")
 check(doc.remove({"group":"portals","index":0}).is_empty() and doc.undo(),"Map edits and undo retain the native terrain")
 check(doc.data.terrain_source=="blood_gulch" and doc.data.portals.size()==8,"Undo restores the portal without changing terrain identity")
 check(loaded.load_kai_highway().is_empty() and loaded.data.terrain_source=="kai_highway","Kai Highway remains available")
 check(loaded.load_original().is_empty() and loaded.data.get("terrain_source","")=="","The original map remains available")
 check(loaded.load_four_gates().is_empty(),"Four Gates remains available")
 finish()
func finish():
 if DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(folder)):
  for name in DirAccess.get_files_at(folder):DirAccess.remove_absolute(ProjectSettings.globalize_path(folder.path_join(name)))
  DirAccess.remove_absolute(ProjectSettings.globalize_path(folder))
 print("BLOOD_GULCH_MAP_RESULT checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)
