extends SceneTree
## Runtime helper/binding parity. Direct segments are the separate CPP proof.
const Low=preload("res://scripts/forest/forest_east_il_low_source.gd")
const Canonical=preload("res://scripts/forest/forest_freyja_terrain.gd")
const Fresh=preload("res://tests/forest-shrine/east_review_sources.gd")
const OUT="res://build/Other Files/Asset Toolkit/East Gate Region/Il Source Completion/Low Source Candidate/"
var checks=0
var errors=[]
func _initialize():
 create_timer(180,true,false,true).timeout.connect(func():printerr("LOW_IL_CONTRACT_TIMEOUT");quit(2));run.call_deferred()
func check(okay:bool,label:String):
 checks+=1
 if not okay:errors.append(label);if errors.size()<=10:printerr("LOW_IL_FAIL ",label)
func run():
 var paths=[get_script().resource_path,"scripts/forest/forest_east_il_low_source.gd","scripts/forest/forest_freyja_terrain.gd","scripts/forest/forest_kai_terrain.gd","scripts/forest/forest_ramparts.gd","scripts/forest/forest_east_bank_caps.gd",OUT+"data.json","assets/maps/falan/east_region/il_source_completion/hybrid-map.bin","assets/maps/falan/east_region/il_source_completion/mask.png","native/terrain_math/bin/libgoemon_terrain_math.macos.universal.dylib"]
 var before=Fresh.snapshot(paths);var data:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(OUT+"data.json"))
 var canonical=Canonical.new();canonical.variant="il_village";canonical.horizontal_scale=2.;canonical.configure([])
 var old_heights=canonical.heights.duplicate();var old_covered=canonical.covered.duplicate()
 var terrain=Low.new();terrain.setup(data);var nav=terrain.native_data();var native=ClassDB.instantiate("GoemonCrowdRuntime");native.set_navigation(nav)
 check(terrain.pieces.size()==282 and terrain.width==122,"Prepared source-sized helper uses282mergedfloors and padded122grid")
 check(terrain.mask_bounds()==Rect2(-136.5,-181.5,270,360),"Original90x120physical/visual bounds retained")
 var open_count=0;var closed_count=0
 for row:Array in data.cells:
  var at=Vector2((row[0]-45)*3.,(row[1]-60)*3.);var opened=bool(row[5]);var high=2. if int(row[3])==252 else 2.1
  if opened:
   open_count+=1;check(absf(terrain.height(at.x,at.y)-high)<.001,"Runtime helper original-open height "+str(row.slice(0,2)))
  else:closed_count+=1
  var world=Vector3(at.x,high,at.y)*1.3
  for radius in [.25,.35,.4967896938,.60]:
   check(native.ally_ground_clear(world,radius)==opened,"Actual binding source center clearance %s/%s"%[row.slice(0,2),radius])
   if opened:check(terrain.disk_clear(Vector3(at.x,high,at.y),radius/1.3),"Kai helper original-open disk parity "+str(row.slice(0,2)))
 check(open_count==2718 and closed_count==8082,"Every original source cell was checked")
 var faces=terrain.collision().get_faces();check(faces.size()==282*6,"Collision contains exactly the source-open mergedfloor tops")
 check(Array(faces).all(func(p:Vector3):return p.is_finite() and (absf(p.y-2.)<.001 or absf(p.y-2.1)<.001)),"All source-floor physics vertices are finite at their two recorded heights")
 var mesh=terrain.mesh();var arrays:Array=mesh.get_meta("source_surface_arrays")
 check(Array(arrays[Mesh.ARRAY_VERTEX]).all(func(p:Vector3):return p.is_finite() and absf(p.y-2.1)<.001),"Visual dry BG uses the samelow2.10m datum; no water/void ramp triangles")
 check(canonical.heights==old_heights and canonical.covered==old_covered,"CanonicalIl6mfield and covered bytes remain unchanged")
 var changed=Fresh.changed(before);check(changed.is_empty(),"Low helper/binding proof stayed source-current")
 var file=FileAccess.open(OUT+"helper-contract.json",FileAccess.WRITE);file.store_string(JSON.stringify({"checks":checks,"failures":errors.size(),"failed":errors,"source_hashes":before,"source_changed":changed,"source_counts":data.counts,"scope":"Private helper/actualNativebinding/Kaiheight-disk parity for sourcecenters and exactfloor geometry. StandaloneCPPdirect143edge proof is separate; no actualplayer/pet/context/art acceptance or shared migration."},"  "));file.close();print("IL_LOW_HELPER checks=",checks," failures=",errors.size());quit(1 if not errors.is_empty() else 0)
