extends SceneTree
const Sampler=preload("res://scripts/forest/forest_east_il_host_shore_sampler.gd")
const Fresh=preload("res://tests/forest-shrine/east_review_sources.gd")
const OUT="res://build/Other Files/Asset Toolkit/East Gate Region/Il Source Completion/Low Source Candidate/Host/Sampler/"
var checks=0
var errors=[]
func _initialize():
 create_timer(180,true,false,true).timeout.connect(func():printerr("HOST_SHORE_CONTRACT_TIMEOUT");quit(2));run.call_deferred()
func check(okay:bool,label:String):
 checks+=1
 if not okay:errors.append(label);if errors.size()<=15:printerr("HOST_SHORE_FAIL ",label)
func run():
 var paths=[get_script().resource_path,"scripts/forest/forest_east_il_host_shore_sampler.gd","scripts/forest/forest_kai_terrain.gd","scripts/forest/forest_ramparts.gd",OUT+"sampler-data.json",OUT+"native-proof.json","native/terrain_math/bin/libgoemon_terrain_math.macos.universal.dylib"]
 var before=Fresh.snapshot(paths);var data:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(OUT+"sampler-data.json"))
 var terrain=Sampler.new();terrain.setup(data);var native=ClassDB.instantiate("GoemonCrowdRuntime");native.set_navigation(terrain.native_data())
 check(terrain.spacing==1.5 and terrain.width==int(data.width),"Private finer terrain grid retains original3mroute spacing")
 check(terrain.pieces.size()==data.source_water.size(),"Only prepared original-open water controls receive2mfloor pieces")
 var opened=0;var closed=0;var water=0;var dry=0
 for row:Array in data.source_cells:
  var at=Sampler.point(Vector2(row[0],row[1]),row[4]);var yes=bool(row[3])
  if yes:
   opened+=1
   if int(row[2])==252:water+=1
   else:dry+=1
   check(absf(terrain._covered_height(at.x,at.z)-row[4])<.001,"Kai original-open center datum "+str(row.slice(0,2)))
  else:closed+=1
  for radius in [.25,.35,.4967896938,.60]:
   check(native.ally_ground_clear(at*1.3,radius)==yes,"Actual binding original source disk %s/%s"%[row.slice(0,2),radius])
   if yes:check(terrain.disk_clear(at,radius/1.3),"Kai original-open disk parity %s/%s"%[row.slice(0,2),radius])
 var faces=terrain.physical_faces();check(faces.size()==dry*24+water*6,"Physics faces cover only original-open dry quartercells or flat2mwatercells")
 check(Array(faces).all(func(p:Vector3):return p.is_finite()),"Every proposed physics vertex is finite")
 var changed=Fresh.changed(before);check(changed.is_empty(),"Private host binding/Kai proof stayed source-current")
 var report={"checks":checks,"failures":errors.size(),"failed":errors,"source_hashes":before,"source_changed":changed,"source_open":opened,"source_closed":closed,"water_controls":water,"dry_bank_cells":dry,"physics_vertices":faces.size(),"scope":"Private host micro-window+3cellcollar helper/actualNativebinding/Kai/physics-array parity. No actualplayer/pet, renderedSource100context, whole2559coast or canonical migration acceptance."}
 var file=FileAccess.open(OUT+"helper-contract.json",FileAccess.WRITE);file.store_string(JSON.stringify(report,"  "));file.close();print("IL_HOST_SHORE_HELPER checks=",checks," failures=",errors.size());quit(1 if not errors.is_empty() else 0)
