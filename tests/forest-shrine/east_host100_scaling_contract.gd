extends SceneTree
## Isolated production ArmyRuntime scaling; no process-context activation/world.
const Field=preload("res://scripts/forest/forest_east_host_source_field.gd")
const Army=preload("res://scripts/forest/crowd/army_runtime.gd")
const Fresh=preload("res://tests/forest-shrine/east_review_sources.gd")
const ROOT="res://build/Other Files/Asset Toolkit/East Gate Region/Il Source Completion/Low Source Candidate/Host/"
const OUT=ROOT+"Original100 Candidate/Production Scaling/"
class ProbeModel extends RefCounted:
 var terrain
 var falan_area="north_coast"
 var falan_floor=0
 var falan_scale=1.3
 var navigation_region=Rect2i(-80,-80,160,160)
class FrozenField extends RefCounted:
 var width:int
 var spacing=3.
 var origin:Vector2
 var heights:PackedFloat32Array
 var covered:PackedByteArray
 var pieces=[]
 func contains(_x:float,_z:float)->bool:return false
 func coordinate(x:float,z:float)->Vector2:return (Vector2(x,z)-origin)/spacing
var checks=0
var failed=[]
func _initialize():
 create_timer(180,true,false,true).timeout.connect(func():printerr("HOST100_SCALING_TIMEOUT");quit(2));run.call_deferred()
func check(okay:bool,label:String):
 checks+=1
 if not okay:failed.append(label);if failed.size()<=12:printerr("HOST100_SCALING_FAIL ",label)
func write_json(path:String,value):
 var file=FileAccess.open(path,FileAccess.WRITE);file.store_string(JSON.stringify(value,"  "));file.close()
static func export_nav(area:String,kind:String,nav:Dictionary,destination:String=OUT)->Dictionary:
 var result={"transport_version":2,"width":nav.width,"spacing":nav.spacing,"route_spacing":nav.get("route_spacing",3.*1.3),"origin":[nav.origin.x,nav.origin.y,nav.origin.z],"bounds_min":[nav.bounds_min.x,nav.bounds_min.y,nav.bounds_min.z],"bounds_max":[nav.bounds_max.x,nav.bounds_max.y,nav.bounds_max.z],"arrays":{}}
 for key:String in ["heights","covered","pieces","obstacle_min","obstacle_max","diagonal_flips"]:
  var bytes:PackedByteArray=nav.get(key,PackedByteArray()) if key in ["covered","diagonal_flips"] else nav[key].to_byte_array()
  var path=destination+area+"-"+kind+"-"+key+".bin";var file=FileAccess.open(path,FileAccess.WRITE);file.store_buffer(bytes);file.close()
  result.arrays[key]={"path":path,"bytes":bytes.size(),"sha256":FileAccess.get_sha256(path)}
 result.spacing_float32_hex=PackedFloat32Array([nav.spacing]).to_byte_array().hex_encode()
 return result
func run():
 var regions=load("res://scripts/forest/forest_freyja_regions.gd")
 check(regions.private_source_context==null,"No process context or live field was activated")
 var paths=[get_script().resource_path,"scripts/forest/crowd/army_runtime.gd","scripts/forest/forest_east_host_source_field.gd","scripts/forest/forest_east_host_source_context.gd","scripts/forest/forest_kai_terrain.gd","scripts/forest/forest_ramparts.gd","native/terrain_math/bin/libgoemon_terrain_math.macos.universal.dylib",ROOT+"Original100 Candidate/manifest.json"]
 for area:String in ["east_gate","north_coast"]:paths.append(ROOT+"Original100 Candidate/"+area+"-field.json");paths.append(ROOT+"Reference/"+area+"-field.json")
 var before=Fresh.snapshot(paths);var records={};DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
 var manifest:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(ROOT+"Original100 Candidate/manifest.json"))
 for area:String in ["east_gate","north_coast"]:
  var path=ROOT+"Original100 Candidate/"+area+"-field.json";check(FileAccess.get_sha256(path)==manifest.areas[area].sha256,"Both prepared fields are committed together")
  var data:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(path));var field=Field.new();field.setup(data)
  var reference:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(ROOT+"Reference/"+area+"-field.json"))
  var frozen=FrozenField.new();frozen.width=int(reference.width);frozen.origin=Vector2(reference.origin[0],reference.origin[1]);frozen.heights=PackedFloat32Array(reference.heights);frozen.covered=PackedByteArray(JSON.parse_string(reference.covered) if reference.covered is String else reference.covered)
  var model=ProbeModel.new()
  if area=="east_gate":
   var bounds:Rect2=field.mask_bounds();var low=Vector2i((bounds.position/6.).floor());model.navigation_region=Rect2i(low,Vector2i((bounds.end/6.).ceil())-low)
  model.terrain=field;var current=Army.navigation_data(model,false);current.route_spacing=3.*model.falan_scale
  # This adds exactly the Host hook's local source-closed rectangles through
  # the production vector transform, without assigning the process switch.
  var local=field.native_data();var frame=Transform3D(Basis.from_scale(Vector3.ONE*model.falan_scale),Vector3.ZERO)
  for key:String in ["obstacle_min","obstacle_max"]:current[key]=frame*local[key];current["friendly_"+key]=current[key]
  model.terrain=frozen;var old=Army.navigation_data(model,false);old.route_spacing=3.*model.falan_scale
  var native=ClassDB.instantiate("GoemonCrowdRuntime");native.set_navigation(current)
  var original=ClassDB.instantiate("GoemonCrowdRuntime");original.set_navigation(old)
  var points=[];var centers=[]
  if area=="east_gate":
   for dx in [-.25,0.,.25]:
    for dz in [-.25,0.,.25]:
     var source=Vector2(440.+dx,194.+dz);var at:Vector2=field.source_point(source);var point=Vector3(at.x,6.,at.y)*model.falan_scale
     var yes:bool=native.ally_ground_clear(point,0.);var was:bool=original.ally_ground_clear(point,0.)
     check(yes,"Actual binding supports original-open bridge source quarter "+str(source))
     points.append({"source":[source.x,source.y],"world":[point.x,point.y,point.z],"new_clear_radius0":yes,"old_clear_radius0":was})
   for radius in [.25,.35,.4967896938,.60]:
    var at:Vector2=field.source_point(Vector2(440,194));check(native.ally_ground_clear(Vector3(at.x,6.,at.y)*1.3,radius),"Actual binding bridge body "+str(radius))
   check(field.dry_floors.size()==1 and field.dry_floors.has(200*840+440),"Only the original-open paved bridge approach gets an additional dry floor")
   var floor_points:Array=field.source_floor_points(200*840+440,6.)
   check(floor_points.all(func(p:Vector3):return p.is_finite() and p.y==6. and p.x>=-10.5 and p.x<=-7.5 and p.z>=67.5 and p.z<=70.5),"Dry floor stays inside its exact3×3m source footprint")
   check(floor_points.all(func(p:Vector3):return p.x<-6.),"Extra paving is outside the unchanged whole bridge deck")
  for cell:Vector2i in [Vector2i(440,200),Vector2i(542,18),Vector2i(543,18),Vector2i(613,307)]:
   var at:Vector2=field.source_point(Vector2(cell));var point=Vector3(at.x,0,at.y)*1.3
   var domain=Rect2(Vector2(current.bounds_min.x,current.bounds_min.z),Vector2(current.bounds_max.x-current.bounds_min.x,current.bounds_max.z-current.bounds_min.z))
   if not domain.grow(-.601).has_point(Vector2(point.x,point.z)):continue
   var high:float=field._covered_height(at.x,at.y);check(is_finite(high),"Focused source-open center has terrain support "+str(cell));point.y=high*1.3
   var radii=[]
   for radius in [.25,.35,.4967896938,.60]:
    var yes:bool=native.ally_ground_clear(point,radius);check(yes,"Focused production-binding original-open disk %s/%s/%s"%[area,cell,radius]);radii.append(yes)
   centers.append({"source":[cell.x,cell.y],"world":[point.x,point.y,point.z],"source_bg":field.serial(cell,0),"source_pg1":field.serial(cell,1),"radii_clear":radii})
  records[area]={"new":export_nav(area,"new",current),"old":export_nav(area,"old",old),"bridge_quarters":points,"focused_centers":centers}
  native=null;original=null
 var changed=Fresh.changed(before);check(changed.is_empty(),"Production-scaling snapshot remained current")
 check(regions.private_source_context==null,"Default process switch remains null")
 var report={"transport_version":2,"checks":checks,"failures":failed.size(),"failed":failed,"areas":records,"source_hashes":before,"source_changed":changed,"scope":"PRIVATE exact current ArmyRuntime scalar/vector scaling and actual native binding setup only. No world/player/pet/scene/context activation or whole-field route acceptance. Baseline CPU fields are the preserved prehook reference; scenery/enemy obstacles are intentionally absent."}
 write_json(OUT+"contract.json",report);print("HOST100_PRODUCTION_SCALING checks=",checks," failures=",failed.size());quit(0 if failed.is_empty() else 1)
