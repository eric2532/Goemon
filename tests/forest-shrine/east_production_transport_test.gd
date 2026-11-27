extends SceneTree
## Exact packed production bytes; no Host products or live source context.
const Kai=preload("res://scripts/forest/forest_kai_terrain.gd")
const Army=preload("res://scripts/forest/crowd/army_runtime.gd")
const Export=preload("res://tests/forest-shrine/east_host100_scaling_contract.gd")
const Fresh=preload("res://tests/forest-shrine/east_review_sources.gd")
const Regions=preload("res://scripts/forest/forest_freyja_regions.gd")
const OUT="res://build/Other Files/Asset Toolkit/East Gate Region/Village Props/Cliff Audit/Source Context Audit/Prototype/Native Failure Triage/CGPROD02/"
class Model extends RefCounted:
 var terrain:RefCounted
 var falan_area="north_coast"
 var falan_floor=0
 var falan_scale=1.3
 var navigation_region=Rect2i(-80,-80,160,160)
var checks=0
var failed=[]
func check(okay:bool,label:String):
 checks+=1
 if not okay:failed.append(label);printerr("CGPROD02_FAIL ",label)
func _initialize():run.call_deferred()
func run():
 var paths=[get_script().resource_path,"res://tests/forest-shrine/east_host100_scaling_contract.gd","res://scripts/forest/crowd/army_runtime.gd","res://scripts/forest/forest_kai_terrain.gd","res://scripts/forest/forest_ramparts.gd","res://scripts/forest/forest_freyja_regions.gd","res://native/terrain_math/bin/libgoemon_terrain_math.macos.universal.dylib"]
 var before=Fresh.snapshot(paths);DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
 check(Regions.private_source_context==null,"Default private switch remains null")
 check(ClassDB.class_exists("GoemonCrowdRuntime"),"Canonical Native binding is loaded")
 var saved=Kai.field;var records={}
 for kind:String in ["new","old"]:
  var mask=PackedByteArray([1,0,0,0,0,0,0,0,0]) if kind=="new" else PackedByteArray()
  var surface=Resource.new()
  for row:Array in [["width",3],["spacing",3.],["heights",PackedFloat32Array([0,2,5,3,9,11,6,12,13])],["covered",PackedByteArray([1,1,1,1,1,1,1,1,1])],["bridges",PackedByteArray([0,0,0,0,0,0,0,0,0])],["diagonal_flips",mask]]:surface.set_meta(row[0],row[1])
  Kai.field=surface;var field=Kai.new();field.configure([]);var model=Model.new();model.terrain=field
  var nav:Dictionary=Army.navigation_data(model,false);nav.route_spacing=3.*model.falan_scale
  check(nav.get("diagonal_flips",PackedByteArray())==mask,"Actual production mask bytes match prepared metadata")
  var native=ClassDB.instantiate("GoemonCrowdRuntime");native.set_navigation(nav)
  var height=4.5 if kind=="new" else 2.5
  check(native.ally_ground_clear(Vector3(-238.5,height,-238.5)*1.3,0.),"Canonical Native uses exported quad orientation")
  check(not native.ally_ground_clear(Vector3(-238.5,7.-height,-238.5)*1.3,0.),"Canonical Native distinguishes opposite diagonal")
  var record:Dictionary=Export.export_nav("mask",kind,nav,OUT)
  check(FileAccess.get_file_as_bytes(record.arrays.diagonal_flips.path)==mask,"Exported mask file is byte-identical to actual navigation")
  check(record.arrays.diagonal_flips.bytes==mask.size(),"Mask count is raw bytes, never float-scaled")
  records[kind]=record;native=null
 Kai.field=saved
 var changed=Fresh.changed(before);check(changed.is_empty(),"Production export source stayed current")
 check(Regions.private_source_context==null,"No Host/world activation occurred")
 var report={"transport_version":2,"checks":checks,"failures":failed.size(),"failed":failed,"records":records,"source_hashes":before,"source_changed":changed,"scope":"Actual canonical production Army/Kai/Native optional mask bytes at scale1.3, isolated asymmetric field. No new source100 height products, world or scene activation; historic41exports unchanged."}
 var file=FileAccess.open(OUT+"export-contract.json",FileAccess.WRITE);file.store_string(JSON.stringify(report,"  "));file.close()
 print("CGPROD02_EXPORT checks=",checks," failures=",failed.size());quit(0 if failed.is_empty() else 1)
