extends SceneTree
const Document=preload("res://scripts/forest/forest_map_document.gd")
var checks=0
var failures=0
func _initialize():run.call_deferred()
func check(ok:bool,message:String):
 checks+=1
 if not ok:failures+=1;printerr("FAIL: ",message)
func run():
 var assets=preload("res://scripts/forest/forest_wind_meadow_assets.gd")
 var parts=assets.source("buildings/wall_cap");var count_=assets.parts.size()
 var alias=assets.source(assets.DIR+"buildings/wall_cap.glb")
 check(assets.parts.size()==count_ and is_same(parts,alias),"Short and full asset paths reuse the same prepared mesh records")
 var doc=Document.new(false)
 check(doc.decode(JSON.stringify({"format":"forest_shrine_map","schema":1,"title":"Navigation checks","buildings":[],"trees":[],"deposits":[],"roads":[],"portals":[]})).is_empty(),"Flat fixture loads")
 for pair in [["tree",Vector2i(10,10)],["rock",Vector2i(14,10)],["cedar",Vector2i(18,10)],["shrub",Vector2i(22,10)],["gate",Vector2i(-10,10)]]:
  check(doc.place(pair[0],pair[1],0).is_empty(),"Fixture places "+pair[0])
 var points=[Vector2i.ZERO,Vector2i(10,10),Vector2i(14,10),Vector2i(18,10),Vector2i(22,10),Vector2i(-10,9),Vector2i(-10,10),Vector2i(-10,11),Vector2i(30,30),Vector2i(-39,-39),Vector2i(39,39),Vector2i(40,40)]
 compare_previews(doc,points)
 var before=doc.encode();var cached=doc.validation_model()
 for i in 50:doc.road_error([Vector2i(10,10)],5);doc.placement_error("portal",Vector2i(30,30),i%4)
 check(doc.encode()==before and doc.validation_model()==cached and doc.history.size()==5,"Repeated cursor checks retain data, history and the cached model")
 check(doc.paint_road([Vector2i(10,10)],1).is_empty() and doc.data.trees.is_empty(),"Road commit still clears intersecting trees")
 check(doc.undo() and doc.encode()==before,"Undo restores road-cleared scenery exactly")
 check(not doc.paint_road([Vector2i(14,10)],1).is_empty() and doc.encode()==before,"Invalid road commits leave data unchanged")
 for path in [Document.WIND_MEADOW_PATH,Document.WIND_MEADOW_LARGE_PATH]:
  var meadow=Document.new(false);check(meadow.read_file(path).is_empty(),"Native meadow fixture loads")
  compare_previews(meadow,[Vector2i.ZERO,Vector2i(10,10),Vector2i(20,20),Vector2i(50,40),Vector2i(-50,-40),Vector2i(79,79),Vector2i(119,119),Vector2i(120,120)])
 var full=Document.new(false);full.decode(JSON.stringify({"format":"forest_shrine_map","schema":1,"title":"Portal limit","buildings":[],"trees":[],"deposits":[],"roads":[],"portals":[]}))
 for x in [-30,-15,15,30]:
  for z in [-30,-15,15,30]:check(full.place("portal",Vector2i(x,z),0).is_empty(),"Portal limit fixture places a separate portal")
 check(not full.placement_error("portal",Vector2i(0,25),0).is_empty(),"Local portal checks retain the sixteen-portal limit")
 var roads=Document.new(false);roads.load_wind_meadow();roads.data.trees=[];roads.data.buildings=[];roads.data.roads=[]
 for x in range(-79,80):
  for z in range(-79,80):
   if roads.data.roads.size()<8192:roads.data.roads.append({"x":x,"z":z})
 check(Document.validate(roads.data).is_empty(),"Road limit fixture is valid")
 check(roads.road_error([Vector2i(-79,-79)],1).is_empty(),"Existing road at the limit is permitted")
 check(not roads.road_error([Vector2i(75,75)],1).is_empty(),"New road at the limit is rejected")
 var folder="user://navigation-picker-%d"%OS.get_process_id()
 check(doc.save(folder).is_empty(),"Picker fixture saves a valid map")
 for pair in [["malformed.json","{broken"],["oversized.json"," ".repeat(Document.MAX_BYTES+1)],["invalid.json",JSON.stringify({"format":"other","schema":1})]]:
  var file=FileAccess.open(folder.path_join(pair[0]),FileAccess.WRITE);file.store_string(pair[1]);file.close()
 var bytes=FileAccess.get_file_as_string(doc.path);var items=Document.list_maps(folder)
 check(items.size()==1 and items[0].title==doc.data.title and items[0].path==doc.path,"Picker retains validated title/path and rejects invalid or oversized files")
 check(FileAccess.get_file_as_string(doc.path)==bytes,"Picker never rewrites or normalizes the saved map")
 for name_ in DirAccess.get_files_at(folder):DirAccess.remove_absolute(ProjectSettings.globalize_path(folder.path_join(name_)))
 DirAccess.remove_absolute(ProjectSettings.globalize_path(folder))
 var invalid=doc.data.duplicate(true);invalid.schema=999;doc.data=invalid;var unchanged=doc.encode()
 check(not doc.paint_road([Vector2i(30,30)],1).is_empty() and doc.encode()==unchanged,"Actual road commits retain complete document validation")
 print("MAP_EDITOR_NAVIGATION_DOCUMENT_RESULT checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)
func compare_previews(doc,points:Array):
 var road_mismatches=0;var portal_mismatches=0
 for cell in points:
  for width in [1,3,5]:
   var full=Document.validate(doc.road_candidate([cell],width));var local=doc.road_error([cell],width)
   if full.is_empty()!=local.is_empty():road_mismatches+=1;printerr("ROAD_MISMATCH ",cell," width=",width," full=",full," local=",local)
  for turn in 4:
   var full=Document.validate(doc.candidate("portal",cell,turn));var local=doc.placement_error("portal",cell,turn)
   if full.is_empty()!=local.is_empty():portal_mismatches+=1;printerr("PORTAL_MISMATCH ",cell," turn=",turn," full=",full," local=",local)
 check(road_mismatches==0,"Local road cursor validation agrees with full candidate validation")
 check(portal_mismatches==0,"Local portal cursor validation agrees with full candidate validation")
