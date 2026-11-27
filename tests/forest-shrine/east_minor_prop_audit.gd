extends SceneTree
const East=preload("res://scripts/forest/forest_east_region_art.gd")
const Forms=preload("res://scripts/forest/forest_original_map_solids.gd")
const ROOT="res://build/Other Files/Asset Toolkit/East Gate Region/Visual Landmarks/"
func _initialize():call_deferred("run")
func run():
 East.Art.load_east();var usage=JSON.parse_string(FileAccess.get_file_as_string(ROOT+"source-object-usage.json"));var rows=[];var failures=[];var placements=0;var source_markers=[];var exact_owners=[]
 for token in usage.graphics:
  if int(token)<1000:source_markers.append(usage.graphics[token]);continue
  if not East.Art.data().graphics.has(token):failures.append("Missing graphic "+token);continue
  var serial=int(token);var g:Dictionary=East.Art.data().graphics[token]
  if East.owns(0,serial) or Forms.kind(serial,false,g)!="prop":continue
  var allowed=East.minor_prop_allowed(serial,g);var mesh:Mesh=Forms.mesh(serial,"prop",g,East.texture(g),false,allowed);var bounds=mesh.get_aabb()
  if not East.minor_meshes.has(serial):exact_owners.append(usage.graphics[token]);continue
  if not bounds.position.is_finite() or not bounds.size.is_finite() or bounds.size.length_squared()<.00001:failures.append("Invalid native card "+token)
  var row:Dictionary=usage.graphics[token].duplicate();row["pixels"]=[g.rect[2],g.rect[3]];row["presentation"]="native thin floor artwork" if float(g.rect[3])<=float(g.rect[2])*.6 else "native upright alpha card"
  rows.append(row);placements+=int(row.placements)
 var file=FileAccess.open(ROOT+"minor-prop-audit.json",FileAccess.WRITE);file.store_string(JSON.stringify({"graphics":rows,"generic_prop_graphics":rows.size(),"placements":placements,"maps_in_source_inventory":usage.maps,"retained_structural_or_existing_forms":exact_owners,"invisible_source_markers":source_markers,"failures":failures,"scope":"Native art fallback only after exact East and shared owners; raw map planes, anchors, footprint/collision/navigation remain unchanged. Low serials below1000 are source markers/void without visible graphic records. No 3D or visual certification for unclassified forms."},"  "));file.close()
 print("EAST_MINOR_PROP_AUDIT graphics=",rows.size()," placements=",placements," failures=",failures.size())
 for failure in failures:push_error(failure)
 quit(0 if failures.is_empty() else 1)
