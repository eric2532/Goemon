extends SceneTree
## Actual C ABI of an isolated copied extension; canonical classes stay loaded.
const STAGE="res://build/Other Files/Asset Toolkit/East Gate Region/Il Source Completion/Low Source Candidate/Host/Original100 Candidate/Diagonal Contract/"
const OUT="res://build/Other Files/Asset Toolkit/East Gate Region/Village Props/Cliff Audit/Source Context Audit/Prototype/Native Failure Triage/Actual Binding Proof/"
const Kai=preload(STAGE+"candidate/scripts/forest/forest_kai_terrain.gd")
const BeforeKai=preload(STAGE+"before/scripts/forest/forest_kai_terrain.gd")
const Army=preload(STAGE+"candidate/scripts/forest/crowd/army_runtime.gd")
const BeforeArmy=preload(STAGE+"before/scripts/forest/crowd/army_runtime.gd")
const Fresh=preload("res://tests/forest-shrine/east_review_sources.gd")
const REGIONS=preload("res://scripts/forest/forest_freyja_regions.gd")
const CLASS="GoemonEastDiagonalProofCrowd"
class Model extends RefCounted:
 var terrain:RefCounted
 var falan_area="north_coast"
 var falan_floor=0
 var falan_scale=1.3
 var navigation_region=Rect2i(-80,-80,160,160)
var checks=0
var failures=[]
var expected_errors=0
var observations=[]

func _initialize():
 create_timer(90,true,false,true).timeout.connect(func():printerr("DIAGONAL_BINDING_TIMEOUT");quit(2))
 run.call_deferred()
func check(okay:bool,label:String):
 checks+=1
 if not okay:failures.append(label);if failures.size()<=16:printerr("DIAGONAL_BINDING_FAIL ",label)
func bytes_sha(bytes:PackedByteArray)->String:
 var context=HashingContext.new();context.start(HashingContext.HASH_SHA256);context.update(bytes);return context.finish().hex_encode()
func surface(values:PackedFloat32Array,mask:Variant=null)->Resource:
 var resource=Resource.new()
 for row:Array in [["width",3],["spacing",3.],["heights",values],["covered",PackedByteArray([1,1,1,1,1,1,1,1,1])],["bridges",PackedByteArray([0,0,0,0,0,0,0,0,0])]]:resource.set_meta(row[0],row[1])
 if mask!=null:resource.set_meta("diagonal_flips",mask)
 return resource
func setup(values:PackedFloat32Array,mask:Variant=null):
 Kai.field=surface(values,mask)
 var terrain=Kai.new();terrain.configure([]);return terrain
func model(terrain)->Model:
 var result=Model.new();result.terrain=terrain;return result
func world(local:Vector2,height:float,scale:float=1.3)->Vector3:
 return Vector3(-240.+local.x,height,-240.+local.y)*scale
func runtime(nav:Dictionary):
 var result=ClassDB.instantiate(CLASS);result.set_navigation(nav);return result
func default_payload():
 var values=PackedFloat32Array([0,2,5,3,9,11,6,12,13])
 BeforeKai.field=surface(values);var original=BeforeKai.new();original.configure([])
 var candidate=setup(values);var old_model=model(original);var new_model=model(candidate)
 for scale:float in [1.,1.3]:
  old_model.falan_scale=scale;new_model.falan_scale=scale
  var before:Dictionary=BeforeArmy.navigation_data(old_model,false);var after:Dictionary=Army.navigation_data(new_model,false)
  check(var_to_bytes(before)==var_to_bytes(after),"Empty-default entire production payload is bit-identical at scale"+str(scale))
  check(not after.has("diagonal_flips"),"Default production dictionary keeps optional key absent")
  observations.append({"case":"empty_default","scale":scale,"bytes":var_to_bytes(after).size(),"sha256":bytes_sha(var_to_bytes(after))})
func valid_frames():
 var source=PackedFloat32Array([0,2,5,3,9,11,6,12,13]);var rotated=PackedFloat32Array([6,3,0,12,9,2,13,11,5]);var mask=PackedByteArray([1,1,0,1,1,0,0,0,0])
 var north=setup(source);var east=setup(rotated,mask)
 var north_nav:Dictionary=Army.navigation_data(model(north),false);var east_nav:Dictionary=Army.navigation_data(model(east),false)
 check(not north_nav.has("diagonal_flips"),"North default remains absent")
 check(east_nav.get("diagonal_flips")==mask,"Actual production preserves mask bytes without scale")
 var n=runtime(north_nav);var e=runtime(east_nav)
 var differs=0
 for sz:float in [.75,1.5,2.25,3.75,4.5,5.25]:
  for sx:float in [.75,1.5,2.25,3.75,4.5,5.25]:
   var local_n=Vector2(sx,sz);var local_e=Vector2(6.-sz,sx)
   var hn:float=north.height(local_n.x-240.,local_n.y-240.);var he:float=east.height(local_e.x-240.,local_e.y-240.)
   check(absf(hn-he)<.000001,"Quarter-turned source points have one GD height")
   var np=world(local_n,hn);var ep=world(local_e,he)
   check(n.ally_ground_clear(np,0.) and e.ally_ground_clear(ep,0.),"Actual C ABI chooses intended source triangle height")
   for radius:float in [.25,.35,.38,.4967896938,.60]:
    check(n.ally_ground_clear(np,radius)==e.ally_ground_clear(ep,radius),"Actual C ABI rotated body decisions agree at radius"+str(radius))
   var before_model=model(east);var wrong:Dictionary=BeforeArmy.navigation_data(before_model,false)
   var legacy=runtime(wrong)
   if not legacy.ally_ground_clear(ep,0.):differs+=1
   legacy=null
 check(differs>0,"Binding height proof distinguishes forgotten-mask old Army producer")
 observations.append({"case":"rotated_nonplanar","source_points":36,"old_producer_distinguished_points":differs,"mask_sha256":bytes_sha(mask)})
 n=null;e=null
 var flat=setup(PackedFloat32Array([0,0,0,0,0,0,0,0,0]),mask);var flat_nav:Dictionary=Army.navigation_data(model(flat),false);var actual=runtime(flat_nav)
 for radius:float in [.25,.35,.38,.4967896938,.60]:check(actual.ally_ground_clear(world(Vector2(3,3),0.),radius),"Valid flat flipped mask retains all body radii")
 actual=null
func invalid_production():
 var values=PackedFloat32Array([0,2,5,3,9,11,6,12,13]);var bad=PackedByteArray([2,0,0,0,0,0,0,0,0]);var last=PackedByteArray([0,0,1,0,0,0,0,0,0])
 for input:Variant in ["invalid",PackedInt32Array([1]),PackedByteArray([1]),bad,last]:
  print("EXPECTED_BINDING_MASK_REJECTION_BEGIN");var terrain=setup(values,input);expected_errors+=1;print("EXPECTED_BINDING_MASK_REJECTION_END")
  check(not terrain.diagonal_mask_valid and is_nan(terrain.height(-238.5,-238.5)),"Malformed Kai metadata is invalid")
  var nav:Dictionary=Army.navigation_data(model(terrain),false)
  check(nav.width==0 and nav.get("diagonal_flips")==PackedByteArray([2]),"Production preserves invalid sentinel instead of flat0")
  var native=runtime(nav)
  for y:float in [0.,2.5]:
   for radius:float in [0.,.25,.35,.38,.4967896938,.60]:check(not native.ally_ground_clear(world(Vector2(1.5,1.5),y),radius),"Invalid production payload cannot expose any Native flat/piece fallback")
  native=null
func direct_binding_types():
 var flat=setup(PackedFloat32Array([0,0,0,0,0,0,0,0,0]));var base:Dictionary=Army.navigation_data(model(flat),false)
 for value:Variant in ["invalid",PackedInt32Array([1]),PackedByteArray([2]),PackedByteArray([0])]:
  var nav=base.duplicate(true);nav.diagonal_flips=value;var actual=runtime(nav)
  check(not actual.ally_ground_clear(world(Vector2(1.5,1.5),0.),0.),"Actual C ABI rejects wrongtype/shape/value mask")
  actual=null
 for value:Variant in [null,PackedByteArray()]:
  var nav=base.duplicate(true);nav.diagonal_flips=value;var actual=runtime(nav)
  check(actual.ally_ground_clear(world(Vector2(1.5,1.5),0.),.38),"Actual C ABI missing/NIL/empty compatibility")
  actual=null
func run():
 var build:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(OUT+"build-proof.json"))
 var paths:Array=[get_script().resource_path,STAGE+"source-contract.json",OUT+"build-proof.json",build.private_extension,build.private_library,"res://native/terrain_math/bin/libgoemon_terrain_math.macos.universal.dylib","res://scripts/forest/forest_freyja_regions.gd"]
 for path:String in build.source_hashes:paths.append(path)
 var before=Fresh.snapshot(paths)
 check(REGIONS.private_source_context==null,"No source context is active")
 check(not ClassDB.class_exists(CLASS),"Proof class has not replaced a project class")
 var canonical=ClassDB.class_exists("GoemonCrowdRuntime")
 var status=GDExtensionManager.load_extension(build.private_extension)
 check(ClassDB.class_exists(CLASS),"Copied proof extension loads actual C ABI")
 if ClassDB.class_exists(CLASS):default_payload();valid_frames();invalid_production();direct_binding_types()
 Kai.field=null;BeforeKai.field=null
 check(REGIONS.private_source_context==null,"Default process flag remains null")
 check(ClassDB.class_exists("GoemonCrowdRuntime")==canonical,"Canonical Native class registration remains unchanged")
 var changed=Fresh.changed(before);check(changed.is_empty(),"Actual binding proof source stays current")
 var report={"checks":checks,"failures":failures.size(),"failed":failures,"expected_push_errors":expected_errors,"extension_load_status":status,"observations":observations,"patch_sha256":build.patch_sha256,"source_hashes":before,"source_changed":changed,"scope":"Private copied current-host extension with renamed proof classes/entry; actual C ABI plus staged production Army/Kai copies. No world, Host activation, canonical library/class replacement or export. Height/Native setup proof does not establish playable scene continuity."}
 var file=FileAccess.open(OUT+"contract.json",FileAccess.WRITE);file.store_string(JSON.stringify(report,"  "));file.close()
 print("EAST_DIAGONAL_BINDING checks=",checks," failures=",failures.size()," expected_push_errors=",expected_errors)
 quit(0 if failures.is_empty() else 1)
