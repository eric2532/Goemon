extends SceneTree
## Data-owner inspection only: no world, actor, combat or map scene is instantiated.
const Original = preload("res://scripts/forest/forest_original_maps.gd")
const IndoorData = preload("res://assets/maps/falan/interior_data.gd")
const Sites = preload("res://assets/maps/falan/freyja_destinations_data.gd")
const Falken = preload("res://scripts/forest/forest_falken_route.gd")
const Prayer = preload("res://scripts/forest/forest_black_prayer.gd")
const Indoor = preload("res://scripts/forest/forest_falan_interior.gd")
const INPUT = "res://build/Other Files/Asset Toolkit/Sokia Venoa Coverage/coverage.json"
const OUTPUT = "res://build/Other Files/Asset Toolkit/Sokia Venoa Coverage/runtime-map-inventory.json"
const CLIENT = "/Users/eric/Desktop/Projects_Codex/Magic Power/data/crossgate/source/BlueCrossgate/map/0/"
const OUTDOORS = {100:["freyja", "east_gate", "south_gate", "west_lakes", "east_coast", "north_coast", "south_lakes"],
 300:["sokia_coast", "sokia_desert", "ghana_road", "ghana_north_road"]}

func _initialize():
 inventory.call_deferred()

func inspect(source: int) -> Dictionary:
 var runtime: int = Original.runtime_id(source)
 var owners: Array = []
 var generated: Script = Original.generated()
 var original_owned: bool = Original.owns(runtime)
 var path: String = Original.path_for(runtime)
 if generated.owns(runtime):
  owners.append({"kind":"generated", "owner":"forest_original_dungeons.gd", "runtime_id":runtime, "branch":generated.branch(runtime)})
 elif original_owned:
  owners.append({"kind":"original", "owner":"forest_original_maps.gd", "runtime_id":runtime, "source_path":path})
 if IndoorData.FLOORS.has(runtime):
  owners.append({"kind":"legacy_interior", "owner":"assets/maps/falan/interior_data.gd", "runtime_id":runtime})
 if Sites.ROOMS.has(runtime):
  owners.append({"kind":"legacy_room", "owner":"assets/maps/falan/freyja_destinations_data.gd", "runtime_id":runtime})
 for area in Sites.VILLAGES:
  if int(Sites.VILLAGES[area][0]) == source:
   owners.append({"kind":"village", "owner":"assets/maps/falan/freyja_destinations_data.gd", "area":area, "runtime_id":0})
 if Falken.owns(runtime):
  owners.append({"kind":"falken_generated" if runtime in Falken.FLOORS else "falken_fixed", "owner":"forest_falken_route.gd", "runtime_id":runtime})
 if Prayer.owns(runtime):
  owners.append({"kind":"prayer_generated" if runtime in Prayer.FLOORS else "prayer_entry", "owner":"forest_black_prayer.gd", "runtime_id":runtime})
 if runtime==Indoor.RoomArt.RubySource.POST and not Indoor.RoomArt.RubySource.post_info().is_empty():
  owners.append({"kind":"source_legacy_interior", "owner":"forest_falan_interior.gd / forest_black_prayer_events.gd", "runtime_id":runtime,
   "source_layout":"client-known plus pinned server-unrecorded16509; separate from16508"})
 if OUTDOORS.has(source):
  owners.append({"kind":"regional_outdoor_crops", "owner":"forest_freyja_regions.gd / forest_freyja_terrain.gd", "areas":OUTDOORS[source], "complete_source_coverage_verified":false})
 var client_file: String = CLIENT + str(source) + ".dat"
 var catalog: Dictionary = Original.Art.data().maps.get(path, {})
 if not catalog.is_empty() and catalog.get("sokia_visual_only",false):
  owners.append({"kind":"prepared_source_catalog_gated", "owner":"forest_original_map_art.gd", "source_path":path, "runtime_id":runtime, "playable_dispatch_enabled":false})
 return {"map":source, "resolved_runtime_id":runtime, "data_owners":owners,
  "owner_status":"no_identified_current_data_owner" if owners.is_empty() else "existing_data_owner_identified",
  "actually_playable_verified":false, "original_client_file":client_file,
  "original_client_file_present":FileAccess.file_exists(client_file),
  "runtime_catalog_source_path":path, "runtime_catalog_entry_present":not catalog.is_empty(),
  "runtime_catalog_visual_only":catalog.get("sokia_visual_only",false),
  "runtime_catalog_existing_owner":catalog.get("east_existing_owner",false)}

func inventory():
 var coverage = JSON.parse_string(FileAccess.get_file_as_string(INPUT))
 assert(coverage is Dictionary and coverage.get("maps") is Array, "Regional coverage input is required")
 var rows: Array = []
 var seen: Dictionary = {}
 var statuses: Dictionary = {}
 var kinds: Dictionary = {}
 var client_count: int = 0
 for candidate in coverage.maps:
  var source: int = int(candidate.map)
  assert(not seen.has(source), "Duplicate source map ID")
  seen[source] = true
  var row: Dictionary = inspect(source)
  row["source_coverage_qualification"] = candidate.get("regional_assignment", "Source candidate; regional membership/release and runtime traversal remain unverified")
  row["source_roster_verified"] = candidate.get("floor_roster_verified", false)
  rows.append(row)
  statuses[row.owner_status] = int(statuses.get(row.owner_status,0)) + 1
  if row.original_client_file_present: client_count += 1
  for owner in row.data_owners:
   kinds[owner.kind] = int(kinds.get(owner.kind,0)) + 1
 var generated_rows: Array = []
 for candidate in coverage.get("runtime_generated_floors", []):
  var row: Dictionary = inspect(int(candidate.runtime_floor))
  row["original_map_identity_verified"] = false
  row["source_qualification"] = candidate
  generated_rows.append(row)
 var result = {"schema":1, "valid_metadata_inventory":true, "complete":false,
  "method":"Godot static data-owner and prepared review-only catalog queries; no world or map scene instantiated",
  "engine":Engine.get_version_info(), "painterly_requested":"--painterly-preview" in OS.get_cmdline_user_args(),
  "coverage_sha256":FileAccess.get_sha256(INPUT), "fixture_sha256":FileAccess.get_sha256(get_script().resource_path),
  "maps":rows, "runtime_generated_floors":generated_rows,
  "summary":{"source_candidates":rows.size(), "original_client_files_present":client_count, "owner_statuses":statuses, "owner_kind_occurrences":kinds},
  "source_authority":coverage.get("source_authority", "Unverified original server execution"),
  "source_graph_qualification":coverage.get("source_graph", {}),
  "limitations":["An existing data owner does not prove a map is reachable, playable, visually complete or has the original encounter roster.",
   "A source client file is distinct from runtime ownership and matching server/release evidence.",
   "Multiple owner entries describe available data; actual routing and dispatch precedence require transition verification.",
   "Outdoor crop ownership does not certify all original cells or scenery.",
   "Generated runtime floor IDs are not authenticated original fixed-map identities."]}
 assert(rows.size() == coverage.maps.size(), "Every source candidate must be inspected")
 var file = FileAccess.open(OUTPUT, FileAccess.WRITE)
 assert(file != null, "Cannot write runtime map inventory")
 file.store_string(JSON.stringify(result, "  ") + "\n")
 file.close()
 print("SOKIA_VENOA_RUNTIME_INVENTORY_RESULT maps=", rows.size(), " statuses=", statuses, " source_files=", client_count)
 quit(0)
