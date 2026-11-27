extends SceneTree
## Read-only current runtime type predicates; no map or art construction.
const Forms=preload("res://scripts/forest/forest_original_map_solids.gd")
const PATH="res://build/Other Files/Asset Toolkit/East Gate Region/Visual Landmarks/Remaining Fallback Audit/33608-room-wall-border-ledger.json"
func _initialize():
 var report=JSON.parse_string(FileAccess.get_file_as_string(PATH));var cat=JSON.parse_string(FileAccess.get_file_as_string("res://assets/maps/original_crossgate/east/catalog.json"));var families={}
 for row:Dictionary in report.graphics:
  var serial=int(row.runtime_graphic);var g:Dictionary=row.runtime_graphic_metadata
  row.typed_family=Forms.kind(serial,int(row.layer)==0,g)
  var key=str(int(row.layer))+":"+row.typed_family;families[key]=int(families.get(key,0))+int(row.retained_count)
  if row.mouse_replaced_count>0:row.status="Accepted Mouse sculpture exact BG constituent"
  elif row.typed_family=="prop":row.status="Current final prop fallback; source-confirmed wall/border role requires native review, not accepted by Mouse sculpture"
  else:row.status="Unchanged "+row.typed_family+" owner; Mouse sculpture acceptance does not establish visual completion"
 report.current_family_counts=families;report.source_forms_sha256=FileAccess.get_sha256("res://scripts/forest/forest_original_map_solids.gd");report.retained_typed_room_wall_placements=0;report.retained_typed_room_wall_ids=[]
 for row:Dictionary in report.graphics:
  if row.typed_family=="room_wall":report.retained_typed_room_wall_placements+=int(row.retained_count);report.retained_typed_room_wall_ids.append(int(row.runtime_graphic))
 report.limitations="Current Forms.kind predicates evaluated on exact active graphics. Semantic types are not shape/paint acceptance. No raw planes, graphics, owners, colliders or routes changed. Existing197global-wall inventory is separate from this one room's aliases."
 var file=FileAccess.open(PATH,FileAccess.WRITE);file.store_string(JSON.stringify(report,"  "));file.close();print("MOUSE_ROOM_FAMILIES ",JSON.stringify(families));quit()
