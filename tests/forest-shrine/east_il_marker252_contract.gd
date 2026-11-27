extends SceneTree
## Read-only current terrain measurements for the242 non-bank source controls.
const Terrain=preload("res://scripts/forest/forest_freyja_terrain.gd")
const Il=preload("res://scripts/forest/forest_east_il_source_completion.gd")
const Fresh=preload("res://tests/forest-shrine/east_review_sources.gd")
const OUT="res://build/Other Files/Asset Toolkit/East Gate Region/Il Source Completion/Whole Shore Candidate/"
class Context extends RefCounted:
 var falan_area="il_village"
 var terrain

func _initialize():run.call_deferred()
func run():
 var before=Fresh.snapshot([get_script().resource_path,"scripts/forest/forest_freyja_terrain.gd","scripts/forest/forest_kai_terrain.gd","scripts/forest/forest_ramparts.gd","scripts/forest/forest_east_il_source_completion.gd",Il.ROOT+"hybrid-map.bin",Il.ROOT+"mask.png",OUT+"252-source-contract.json"])
 var context=Context.new();context.terrain=Terrain.new();context.terrain.variant="il_village";context.terrain.horizontal_scale=2.;context.terrain.configure([]);Il.install(context)
 var terrain=context.terrain;var field=terrain.terrain_field();var bed:PackedFloat32Array=field.get_meta("bed")
 var source:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(OUT+"252-source-contract.json"));var rows=[];var stats={"source_attribute_open":0,"terrain_contains":0,"disk_clear_025":0,"disk_clear_035":0,"disk_clear_060":0,"mask_wet":0,"below_water":0}
 for record:Dictionary in source.all242controls:
  var cell=Vector2i(record.cell[0],record.cell[1]);var point=(Vector2(cell)-Vector2(45,60))*3.;var uv=terrain.coordinate(point.x,point.y);var at=roundi(uv.y)*terrain.width+roundi(uv.x)
  var row=record.duplicate(true);row.source_attribute_open=Il.source_open(cell);row.mask_rgba=var_to_str(terrain.mask_image().get_pixelv(cell));row.terrain_height=terrain.height(point.x,point.y);row.bed_vertex_height=bed[at];row.covered_vertex=int(terrain.covered[at]);row.terrain_contains=terrain.contains(point.x,point.y)
  row.disk_clear_025=terrain.disk_clear(Vector3(point.x,0,point.y),.25);row.disk_clear_035=terrain.disk_clear(Vector3(point.x,0,point.y),.35);row.disk_clear_060=terrain.disk_clear(Vector3(point.x,0,point.y),.60)
  row.has_explicit_piece=not is_nan(terrain.piece_height(point.x,point.y))
  stats.source_attribute_open+=int(row.source_attribute_open);stats.terrain_contains+=int(row.terrain_contains);stats.disk_clear_025+=int(row.disk_clear_025);stats.disk_clear_035+=int(row.disk_clear_035);stats.disk_clear_060+=int(row.disk_clear_060);stats.mask_wet+=int(terrain.mask_image().get_pixelv(cell).r>.5);stats.below_water+=int(row.terrain_height<terrain.WATER_HEIGHT)
  rows.append(row)
 var changed=Fresh.changed(before)
 var result={"source":2000,"controls":rows.size(),"stats":stats,"rows":rows,"source_hashes":before,"source_changed_during_run":changed,"scope":"Read-only current local Il terrain/Kai measurements after the existing six source supports. No support/height/mask/source bytes changed. These242 source controls are not native bank graphics. This is not a live player/native-army route test or proof of original executable behavior."}
 var file=FileAccess.open(OUT+"252-current-terrain.json",FileAccess.WRITE);file.store_string(JSON.stringify(result,"  "));file.close()
 print("EAST_IL_MARKER252_CURRENT ",JSON.stringify(stats)," source_changed=",changed)
 quit(0 if changed.is_empty() and rows.size()==242 else 1)
