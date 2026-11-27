extends SceneTree
## Read-only composed terrain/cap/source-owner diagnosis, without spawning gameplay.
const Full=preload("res://scripts/forest/forest_east_alyut_source_completion.gd")
const Region=preload("res://scripts/forest/forest_east_region.gd")
const Terrain=preload("res://scripts/forest/forest_freyja_terrain.gd")
const Caps=preload("res://scripts/forest/forest_east_bank_caps.gd")
const Buildings=preload("res://scripts/forest/forest_east_village_buildings.gd")
const Fresh=preload("res://tests/forest-shrine/east_review_sources.gd")
const OUT="res://build/Other Files/Asset Toolkit/East Gate Region/Village Props/Cliff Audit/Source Context Audit/"
const SHIFT=Vector2(-165,-123)
const RADII=[.25/1.3,.49679/1.3,.60/1.3]
class FieldView:
 extends RefCounted
 var falan_area="north_coast"
class LocalView:
 extends RefCounted
 var terrain
 func surface_height(x:float,z:float)->float:return terrain.height(x-165.,z-123.)
func _initialize():call_deferred("run")
func point(cell:Array)->Vector2:return Full.local_point(Vector2(cell[0]-529,cell[1]-20))+SHIFT
func supported(terrain,at:Vector2)->Array:
 var height_=terrain.height(at.x,at.y);var result=[]
 for radius in RADII:result.append(terrain.disk_clear(Vector3(at.x,height_,at.y),radius))
 return result
func closed_by_plan(plan:Array,at:Vector2,height_:float,radius:float)->bool:
 var local=at-SHIFT
 for row:Array in plan:
  var box:AABB=row[2]
  if height_+.1<box.position.y or height_>box.end.y+.1:continue
  var nearest=local.clamp(Vector2(box.position.x,box.position.z),Vector2(box.end.x,box.end.z))
  if nearest.distance_squared_to(local)<radius*radius:return true
 return false
func edge_probe(terrain,edge:Array,plan:Array)->Dictionary:
 var a=point(edge[0]);var b=point(edge[1]);var okay=[true,true,true];var with_plan=[true,true,true];var missing=[0,0,0];var samples=0;var previous=NAN;var max_step=0.
 for index in 21:
  var at=a.lerp(b,index/20.);var height_=terrain.height(at.x,at.y);var clear=supported(terrain,at)
  for r in RADII.size():
   okay[r]=okay[r] and clear[r]
   if not clear[r]:missing[r]+=1
   with_plan[r]=with_plan[r] and clear[r] and not closed_by_plan(plan,at,height_,RADII[r])
  if not is_nan(previous):max_step=maxf(max_step,absf(height_-previous))
  previous=height_;samples+=1
 return {"a":edge[0],"b":edge[1],"terrain_caps_disk_clear_all_samples":okay,"terrain_caps_plus_published_village_plan_clear":with_plan,"failed_disk_samples":missing,"samples":samples,"max_height_delta_per_015_source_m":max_step}
func run():
 var input:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(OUT+"probe-input.json"))
 var paths:Array=input.source_hashes.keys()
 paths.append_array(["scripts/forest/forest_east_alyut_source_completion.gd","scripts/forest/forest_east_region.gd","scripts/forest/forest_freyja_regions.gd","scripts/forest/forest_freyja_terrain.gd","scripts/forest/forest_wind_meadow_terrain.gd","scripts/forest/forest_kai_terrain.gd","scripts/forest/forest_ramparts.gd","scripts/forest/forest_east_bank_caps.gd","scripts/forest/forest_east_village_buildings.gd","assets/maps/falan/east_region/bank_caps/data.json","assets/maps/falan/east_region/north_coast-surface.png","assets/maps/falan/east_region/village_buildings/data.json","assets/maps/wind_meadow/castles/surface.res","tests/forest-shrine/east_alyut_shore_context_probe.gd"])
 for path:String in input.source_hashes:
  assert(FileAccess.get_sha256("res://"+path)==input.source_hashes[path],"Regenerate the native shoreline audit after changing "+path)
 var before=Fresh.snapshot(paths)
 var terrain=Terrain.new();terrain.variant="north_coast";terrain.horizontal_scale=2.;terrain.configure([])
 var baseline={}
 for row:Dictionary in input.rows:baseline[str(row.field_cell)]=supported(terrain,point(row.field_cell))
 Caps.append_pieces(terrain,Full.bank_rows(true))
 var local=LocalView.new();local.terrain=terrain
 var plan:Array=Full.plan(local,Buildings.alyut_plan(local,[]));var field_view=FieldView.new()
 var mask:Image=terrain.mask_image();var origin=terrain.mask_origin();var rows=[]
 for source:Dictionary in input.rows:
  var row=source.duplicate(true);var at=point(row.field_cell);var height_=terrain.height(at.x,at.y);var grid=Vector2i(((at-origin)/3.).round());var pixel=mask.get_pixelv(grid)
  row.joined_anchor=[at.x,at.y];row.current_source=Region.current_source(field_view,at);row.height=height_;row.contains=terrain.contains(at.x,at.y)
  row.joined_mask_rgba=[pixel.r,pixel.g,pixel.b,pixel.a];row.terrain_only_clear=baseline[str(row.field_cell)];row.terrain_caps_clear=supported(terrain,at)
  row.published_village_plan_blocked=[]
  for radius in RADII:row.published_village_plan_blocked.append(closed_by_plan(plan,at,height_,radius))
  rows.append(row)
 var incident=[];var perimeter=[];var bank_edges=[]
 for edge:Array in input.incident_edges:incident.append(edge_probe(terrain,edge,plan))
 for edge:Array in input.perimeter_edges:perimeter.append(edge_probe(terrain,edge,plan))
 for edge:Array in input.bank_edges:bank_edges.append(edge_probe(terrain,edge,plan))
 var changed=Fresh.changed(before)
 var report={"source_audit_sha256":input.source_audit_sha256,"source_snapshot":before,"source_changed_during_run":changed,"rows":rows,"incident_original100_open_edges":incident,"rectangle_perimeter_edges":perimeter,"published_bank_directed_edges":bank_edges,"gameplay_radii":[.25,.49679,.60],"world_scale":1.3,"native_frame_radii":RADII,"published_village_plan_rows":plan.size(),"scope":"Read-only current Terrain+117 published Caps support, Region.current_source, and published Full.plan/building AABB footprint exclusions. Twenty-one samples per adjacency. No source, masks, routes, colliders or canonical assets changed. This is not full native navigation/army/player movement or visual acceptance; field scenery obstacles and native slope/path decisions are not simulated."}
 var file=FileAccess.open(OUT+"runtime-shore-context.json",FileAccess.WRITE);file.store_string(JSON.stringify(report," "));file.close()
 print("EAST_ALYUT_SHORE_CONTEXT rows=",rows.size()," incident=",incident.size()," perimeter=",perimeter.size()," source_changed=",changed)
 quit(0 if changed.is_empty() else 1)
