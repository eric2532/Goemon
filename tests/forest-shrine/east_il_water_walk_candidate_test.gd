extends SceneTree
## Isolated copied terrain/geometry/native proof; no live Map/Model/Army hooks.
const Field=preload("res://scripts/forest/forest_east_il_water_terrain.gd")
const Floors=preload("res://scripts/forest/forest_east_il_water_walk.gd")
const Closure=preload("res://scripts/forest/forest_east_il_bank_closure.gd")
const Fresh=preload("res://tests/forest-shrine/east_review_sources.gd")
const OUT="res://build/Other Files/Asset Toolkit/East Gate Region/Il Source Completion/Water Walk Candidate/"
const SHORE="res://build/Other Files/Asset Toolkit/East Gate Region/Il Source Completion/Whole Shore Candidate/banks.json"
var checks=0
var failures=0
var failed=[]
func _initialize():
 create_timer(180,true,false,true).timeout.connect(func():printerr("IL_WATER_WALK_PROOF_TIMEOUT");quit(2))
 run.call_deferred()
func check(okay:bool,label:String):
 checks+=1
 if not okay:
  failures+=1;failed.append(label)
  if failures<=10:printerr("IL_WATER_WALK_FAIL ",label)
func run():
 var paths=[get_script().resource_path,"scripts/forest/forest_east_il_water_terrain.gd","scripts/forest/forest_east_il_water_walk.gd","scripts/forest/forest_east_il_bank_closure.gd","scripts/forest/forest_east_bank_caps.gd","scripts/forest/forest_freyja_terrain.gd","scripts/forest/forest_kai_terrain.gd","scripts/forest/forest_ramparts.gd","native/terrain_math/bin/libgoemon_terrain_math.macos.universal.dylib","assets/maps/falan/east_region/bank_caps/data.json",OUT+"data.json",SHORE]
 var before=Fresh.snapshot(paths);var proposal:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(OUT+"data.json"))
 var terrain=Field.new();terrain.variant="il_village";terrain.horizontal_scale=2.;terrain.configure([])
 var source_field=terrain.terrain_field();var original_heights:PackedFloat32Array=source_field.get_meta("heights").duplicate();var original_bed:PackedFloat32Array=source_field.get_meta("bed").duplicate();var original_covered=terrain.covered.duplicate()
 var changes=terrain.apply_grade(proposal);var rows=Floors.bank_rows(SHORE,proposal);Closure.append_supports(terrain,rows);Floors.append_supports(terrain,proposal)
 check(source_field.get_meta("heights")==original_heights and source_field.get_meta("bed")==original_bed,"Shared source field remains byte-identical")
 check(terrain.covered==original_covered,"Covered mask is unchanged; only explicit source supports cross void")
 var actual_changes=[]
 for index in terrain.heights.size():
  if terrain.heights[index]!=original_heights[index]:actual_changes.append(index)
 check(actual_changes.size()==proposal.counts.local_height_vertices,"Every affected local height vertex is recorded; joined-only bank cut stays excluded")
 var data={"width":terrain.width,"spacing":terrain.spacing,"route_spacing":3.0,"origin":Vector3(-480,0,-480),"bounds_min":Vector3(-481.5,0,-481.5),"bounds_max":Vector3(481.5,0,481.5),"heights":terrain.heights,"covered":terrain.covered,"pieces":PackedFloat32Array(),"obstacle_min":PackedVector3Array(),"obstacle_max":PackedVector3Array()}
 for piece:Dictionary in terrain.pieces:data.pieces.append_array(PackedFloat32Array([piece.a.x,piece.a.y,piece.along.x,piece.along.y,piece.half,piece.length,piece.start,piece.end,piece.h0,piece.h1]))
 for rect:Array in proposal.isolated_probe_original_blocked_rectangles:
  var a=(Vector2(rect[0],rect[1])-Vector2(45,60))*3.-Vector2.ONE*1.5;var b=a+Vector2(rect[2],rect[3])*3.
  data.obstacle_min.append(Vector3(a.x,-10,a.y));data.obstacle_max.append(Vector3(b.x,40,b.y))
 var native=ClassDB.instantiate("GoemonCrowdRuntime");native.set_navigation(data)
 var radius_rows=[]
 var ramp_only="--ramp-only" in OS.get_cmdline_user_args()
 for radius in ([] if ramp_only else [.25,.35,.4967896938,.60]):
  var cleared=0;var reached=0
  for row:Dictionary in proposal.water_rows:
   var point=Vector3(row.anchor[0],2.,row.anchor[1])
   check(absf(terrain.height(point.x,point.z)-2.)<.001,"Source252 floor lies on visible2m water "+str(row.source_cell))
   var clear=terrain.disk_clear(point,radius) and native.ally_ground_clear(point,radius);cleared+=int(clear)
   check(clear,"Player/native source252 center clears radius%s cell%s"%[radius,row.source_cell])
   var reachable=false
   for ramp:Dictionary in proposal.ramps:
    var start=Vector3(ramp.b[0],6.,ramp.b[1])
    if native.can_reach(start,point,radius):reachable=true;break
   reached+=int(reachable);check(reachable,"Source252 is reachable from original dry entry radius%s cell%s"%[radius,row.source_cell])
  radius_rows.append({"radius":radius,"source_water_cells":242,"cleared_centers":cleared,"reachable_from_dry":reached})
 var ramp_rows=[]
 for row:Dictionary in proposal.ramps:
  var a=Vector2(row.a[0],row.a[1]);var b=Vector2(row.landing_end[0],row.landing_end[1]);var bad=[]
  for step in range(31):
   var p=a.lerp(b,step/30.);var point=Vector3(p.x,terrain.height(p.x,p.y),p.y)
   for radius in [.25,.35,.4967896938,.60]:
    var kai_ok=terrain.disk_clear(point,radius);var native_ok=native.ally_ground_clear(point,radius)
    if not kai_ok or not native_ok:
     var heights=[];var support_owners=[]
     for axis:Vector2 in terrain.DISK_AXES:
      var sample=p+axis*radius;heights.append(terrain._covered_height(sample.x,sample.y))
      if bad.is_empty():
       var owners=[]
       for piece:Dictionary in terrain.pieces:
        var delta=sample-piece.a;var along=delta.dot(piece.along)
        if along>=piece.start-.001 and along<=piece.end+.001 and absf(delta.dot(piece.side))<=piece.half+.001:
         owners.append({"cell":str(piece.get("source_cell",Vector2i(-1,-1))),"h0":piece.h0,"h1":piece.h1,"water":piece.get("source_water_walk",false)})
       support_owners.append(owners)
     bad.append({"step":step,"radius":radius,"center_y":point.y,"kai":kai_ok,"native":native_ok,"nine_height_samples":heights,"first_failure_support_owners":support_owners})
  check(bad.is_empty(),"Entire inferred bank grade/landing clears all four radii "+str(row.source_bank_cell)+" failed samples="+str(bad.size()))
  ramp_rows.append({"bank_cell":row.source_bank_cell,"sample_failures":bad,"inferred_grade":row.grade})
 var root3d=Node3D.new();root.add_child(root3d);Floors.build_floors(root3d,proposal)
 check(root3d.get_child_count()==248,"Exactly242water floors,3original-open entry ramps and3upper landings are prepared")
 for body:StaticBody3D in root3d.get_children():check(body.collision_layer==1 and body.collision_mask==0,"Existing Palace static floor layer contract retained")
 var changed=Fresh.changed(before);check(changed.is_empty(),"Private source/height/native proof stayed current")
 var file=FileAccess.open(OUT+("ramp-debug.json" if ramp_only else "isolated-proof.json"),FileAccess.WRITE);file.store_string(JSON.stringify({"checks":checks,"failures":failures,"failed":failed,"source_hashes":before,"source_changed_during_run":changed,"height_changes":changes,"route_spacing":data.route_spacing,"radii":radius_rows,"ramps":ramp_rows,"scope":"PRIVATE technical-only prototype using explicit original3mroute spacing, exact original blocked rectangles, copied height/bed grid and unchanged covered bytes. No actual player/pet/normal-camera acceptance, no live integration and no claim of all143contact parity. Outdoor canonical route data currently omits this3mspacing and needs a bounded hook before publication."},"  "));file.close()
 print("EAST_IL_WATER_WALK_PROOF checks=",checks," failures=",failures);quit(1 if failures else 0)
