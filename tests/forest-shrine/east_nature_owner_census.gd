extends SceneTree
## Evaluate current production owner predicates, without constructing map scenes.
const Maps=preload("res://scripts/forest/forest_original_maps.gd")
const East=preload("res://scripts/forest/forest_east_region_art.gd")
const Nature=preload("res://scripts/forest/forest_east_nature.gd")
const Sokia=preload("res://scripts/forest/forest_sokia_scenery.gd")
const OUT="res://build/Other Files/Asset Toolkit/East Gate Region/Visual Landmarks/Nature/Owned240/"
func _initialize():run.call_deferred()
func run():
 East.Art.load_east();var input=JSON.parse_string(FileAccess.get_file_as_string(OUT+"native-placements.json"));var rows={};var sums={};var fixed={};var failures=[]
 var sources={}
 for path in ["scripts/forest/forest_original_maps.gd","scripts/forest/forest_east_region_art.gd","scripts/forest/forest_east_nature.gd","scripts/forest/forest_west_route_scenery.gd","scripts/forest/forest_university_route_art.gd","scripts/forest/forest_sokia_scenery.gd","scripts/forest/forest_jenova_village_art.gd","scripts/forest/forest_tina_village_art.gd","scripts/forest/forest_tina_scenery.gd"]:sources[path]=FileAccess.get_sha256("res://"+path)
 for token in input.candidate_ids:rows[str(int(token))]={"graphic":int(token),"owners":{},"contexts":{}}
 for item:Array in input.placements:
  var source=int(item[0]);var cell=Vector2i(item[1],item[2]);var serial=int(item[3]);var token=str(serial);var id=Maps.runtime_id(source);var local=cell-Maps.crop(id).position;var owner="proposed_Nature240"
  var g:Dictionary=East.Art.data().graphics[token];var family=Maps.Forms.kind(serial,false,g)
  if not fixed.has(source):fixed[source]=Sokia.fixed_map(source)
  if input.maps[str(source)].legacy_owner:owner="existing_legacy_map_owner"
  elif not Maps.owns(id):owner="existing_non_OriginalMaps_owner"
  elif Maps.EastAnnexes.owns(serial):owner="EastAnnexes"
  elif Maps.EastColumns.owns(serial):owner="EastColumns"
  elif Maps.EastRuins.owns(serial):owner="EastRuins"
  elif East.owns(source,serial):owner="EastArt"
  elif Maps.AbanisVillageArt.owns(source,serial):owner="AbanisVillageArt"
  elif not Maps.JenovaVillageArt.owns(source,serial,cell) and Maps.UniversityRouteArt.owns(source,serial,cell):owner="UniversityRouteArt"
  elif Maps.JenovaVillageArt.owns(source,serial,cell):owner="JenovaVillageArt"
  elif Maps.TinaVillageArt.owns(source,serial,local):owner="TinaVillageArt"
  elif Maps.TinaScenery.owns(source,serial):owner="TinaScenery"
  elif Maps.EastFurniture.owns(serial):owner="EastFurniture"
  elif Maps.EastGroundMotifs.owns(serial):owner="EastGroundMotifs"
  elif family=="tree" and not fixed[source].is_empty():owner="Sokia contextual tree"
  elif family=="tree" and Maps.UniversityRouteArt.contains(source,cell):owner="University contextual tree"
  elif family=="tree" and Maps.WestScenery.contains(str(source),Vector2(cell)):owner="West contextual tree"
  var row:Dictionary=rows[token];row.owners[owner]=int(row.owners.get(owner,0))+1
  var key=str(source)+":"+owner;row.contexts[key]=int(row.contexts.get(key,0))+1;sums[owner]=int(sums.get(owner,0))+1
 for path in sources:
  if FileAccess.get_sha256("res://"+path)!=sources[path]:failures.append("Source changed "+path)
 var report={"scope":"Read-only source placement/current higher-priority owner predicates. Proposed late fallback never certifies an existing owner's visual. Legacy map owners and contextual tree owners stay authoritative.","candidate_ids":240,"native_object_placements":input.placements.size(),"owner_counts":sums,"graphics":rows,"sources":sources,"catalog_sha256":input.catalog_sha256,"failures":failures}
 var f=FileAccess.open(OUT+"ownership-census.json",FileAccess.WRITE);f.store_string(JSON.stringify(report,"  "));f.close()
 print("EAST_NATURE_OWNER_CENSUS ",JSON.stringify(sums)," failures=",failures.size());quit(failures.size())
