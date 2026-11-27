extends SceneTree
## Isolated scaled/translated comparison; source and live candidate files stay unchanged.
const Field=preload("res://scripts/forest/forest_east_il_water_terrain.gd")
const Floors=preload("res://scripts/forest/forest_east_il_water_walk.gd")
const Shore=preload("res://scripts/forest/forest_east_il_bank_closure.gd")
const Fresh=preload("res://tests/forest-shrine/east_review_sources.gd")
const OUT="res://build/Other Files/Asset Toolkit/East Gate Region/Il Source Completion/Water Walk Candidate/"
const SHORE="res://build/Other Files/Asset Toolkit/East Gate Region/Il Source Completion/Whole Shore Candidate/banks.json"
const SCALE=1.3
const OFFSET=Vector3(-682.5,0,1029.6)
func _initialize():
 create_timer(180,true,false,true).timeout.connect(func():quit(2));run.call_deferred()
func world(at:Vector3)->Vector3:return at*SCALE+OFFSET
func run():
 var before=Fresh.snapshot([get_script().resource_path,"scripts/forest/forest_east_il_water_terrain.gd","scripts/forest/forest_east_il_water_walk.gd","scripts/forest/forest_east_bank_caps.gd","scripts/forest/forest_ramparts.gd","scripts/forest/forest_kai_terrain.gd","native/terrain_math/bin/libgoemon_terrain_math.macos.universal.dylib",OUT+"data.json",SHORE])
 var proposal:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(OUT+"data.json"));var reports=[]
 for entry_height in [2.15,2.10,2.0]:
  var data=proposal.duplicate(true)
  for ramp:Dictionary in data.ramps:ramp.h0=entry_height
  var terrain=Field.new();terrain.variant="il_village";terrain.horizontal_scale=2.;terrain.configure([]);terrain.apply_grade(data)
  Shore.append_supports(terrain,Floors.bank_rows(SHORE,data));Floors.append_supports(terrain,data)
  var nav={"width":terrain.width,"spacing":terrain.spacing*SCALE,"route_spacing":3.*SCALE,"origin":world(Vector3(-480,0,-480)),"bounds_min":world(Vector3(-481.5,0,-481.5)),"bounds_max":world(Vector3(481.5,0,481.5)),"heights":terrain.heights.duplicate(),"covered":terrain.covered,"pieces":PackedFloat32Array(),"obstacle_min":PackedVector3Array(),"obstacle_max":PackedVector3Array()}
  for i in nav.heights.size():nav.heights[i]*=SCALE
  for piece:Dictionary in terrain.pieces:
   var a=world(Vector3(piece.a.x,0,piece.a.y));nav.pieces.append_array(PackedFloat32Array([a.x,a.z,piece.along.x,piece.along.y,piece.half*SCALE,piece.length*SCALE,piece.start*SCALE,piece.end*SCALE,piece.h0*SCALE,piece.h1*SCALE]))
  for rect:Array in proposal.isolated_probe_original_blocked_rectangles:
   var a=(Vector2(rect[0],rect[1])-Vector2(45,60))*3.-Vector2.ONE*1.5;var b=a+Vector2(rect[2],rect[3])*3.
   nav.obstacle_min.append(world(Vector3(a.x,-10,a.y)));nav.obstacle_max.append(world(Vector3(b.x,40,b.y)))
  var native=ClassDB.instantiate("GoemonCrowdRuntime");native.set_navigation(nav);var rows=[]
  for radius in [.25,.35,.4967896938,.60]:
   var reached=0;var entry_pairs=[]
   for ramp:Dictionary in data.ramps:
    var bank=Vector2(ramp.source_bank_cell[0]-45,ramp.source_bank_cell[1]-60)*3.;var water=Vector2(ramp.source_water_cell[0]-45,ramp.source_water_cell[1]-60)*3.
    entry_pairs.append(native.can_reach(world(Vector3(bank.x,entry_height,bank.y)),world(Vector3(water.x,2.,water.y)),radius))
   for water:Dictionary in data.water_rows:
    var target=world(Vector3(water.anchor[0],2.,water.anchor[1]));var found=false
    for ramp:Dictionary in data.ramps:
     if native.can_reach(world(Vector3(ramp.b[0],6.,ramp.b[1])),target,radius):found=true;break
    reached+=int(found)
   rows.append({"radius":radius,"reachable":reached,"bank_to_water_pairs":entry_pairs})
  reports.append({"entry_height_local":entry_height,"world_jump":(entry_height-2.)*SCALE,"radii":rows})
 var f=FileAccess.open(OUT+"scaled-entry-diagnosis.json",FileAccess.WRITE);f.store_string(JSON.stringify({"scale":SCALE,"offset":str(OFFSET),"variants":reports,"source_hashes":before,"source_changed":Fresh.changed(before),"scope":"Private isolated diagnosis with original blocked cells; source/candidate files unmodified. This does not establish actual player/pet or scene obstacle acceptance."},"  "));f.close();print("IL_SCALED_ENTRY ",reports);quit()
