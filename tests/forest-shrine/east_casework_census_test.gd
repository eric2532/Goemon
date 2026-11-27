extends SceneTree
## Isolate source census from renderer/camera failures; JSON numbers normalize to integers.
const Maps=preload("res://scripts/forest/forest_original_maps.gd")
const Sources=preload("res://tests/forest-shrine/east_review_sources.gd")
const OUT="res://build/Other Files/Asset Toolkit/East Gate Region/Room Casework/Actual Rooms/"
var checks=0
var failures=0
func _initialize():run.call_deferred()
func check(ok:bool,label:String):
 checks+=1
 if not ok:failures+=1;printerr("FAIL ",label)
func run():
 var hashes=Sources.snapshot([get_script().resource_path,"scripts/forest/forest_original_maps.gd","scripts/forest/forest_original_map_art.gd","assets/maps/original_crossgate/east/catalog.json",OUT+"native-placements.json"])
 var data=JSON.parse_string(FileAccess.get_file_as_string(OUT+"native-placements.json"));var ids={}
 for serial in data.ids:ids[int(serial)]=true
 Maps.Art.load_east();var rows=[];var total=0
 for token in data.counts:
  var id=Maps.runtime_id(int(token));var row=Maps.state(id);var aliases:Dictionary=Maps.Art.data().maps[Maps.path_for(id)].get("graphic_aliases",{});var cells:int=row.size.x*row.size.y;var counts={};var wanted={}
  for i in cells:
   var native=row.raw.decode_u16(20+(cells+i)*2);var serial=int(aliases.get(str(native),native))
   if not ids.has(serial):continue
   var key=str(serial);counts[key]=int(counts.get(key,0))+1;total+=1
  for serial in data.counts[token]:wanted[str(serial)]=int(data.counts[token][serial])
  check(counts==wanted,"Exact original active object census "+token)
  rows.append({"source":int(token),"actual":counts,"expected":wanted})
 check(total==data.placements.size() and ids.size()==23,"Every137placement and23published appearance accounted")
 var changed=Sources.changed(hashes);check(changed.is_empty(),"Loaded census inputs remain current")
 var f=FileAccess.open(OUT+"source-census.json",FileAccess.WRITE);f.store_string(JSON.stringify({"checks":checks,"failures":failures,"total_placements":total,"maps":rows,"source_hashes":hashes,"source_changed_during_run":changed,"scope":"Pure67map/137object source census; no actual renderer/camera/navigation/quest acceptance."},"  "));f.close();print("EAST_CASEWORK_CENSUS_RESULT checks=",checks," failures=",failures);quit(failures)
