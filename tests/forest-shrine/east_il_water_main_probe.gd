extends SceneTree
## Read-only actual-model navigation diagnosis, with the private water proposal.
const Model=preload("res://scripts/forest/forest_model.gd")
const Regions=preload("res://scripts/forest/forest_freyja_regions.gd")
const Army=preload("res://scripts/forest/crowd/army_runtime.gd")
const Field=preload("res://scripts/forest/forest_east_il_water_terrain.gd")
const Floors=preload("res://scripts/forest/forest_east_il_water_walk.gd")
const Shore=preload("res://scripts/forest/forest_east_il_bank_closure.gd")
const Fresh=preload("res://tests/forest-shrine/east_review_sources.gd")
const OUT="res://build/Other Files/Asset Toolkit/East Gate Region/Il Source Completion/Water Walk Candidate/"
const SHORE="res://build/Other Files/Asset Toolkit/East Gate Region/Il Source Completion/Whole Shore Candidate/banks.json"
func _initialize():
 create_timer(180,true,false,true).timeout.connect(func():printerr("IL_MAIN_PROBE_TIMEOUT");quit(2))
 run.call_deferred()
func run():
 var before=Fresh.snapshot([get_script().resource_path,"scripts/forest/forest_model.gd","scripts/forest/crowd/army_runtime.gd","scripts/forest/forest_falan_frontier.gd","scripts/forest/forest_freyja_regions.gd","scripts/forest/forest_east_il_water_terrain.gd","scripts/forest/forest_east_il_water_walk.gd",OUT+"data.json",SHORE])
 var model=Model.new();model.reset(42,{},Regions.layout("east_gate"),false)
 var proposal:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(OUT+"data.json"));var frame=Regions.village_transform("il_village")
 var old=model.terrain;var terrain=Field.new();terrain.variant=old.variant;terrain.horizontal_scale=old.horizontal_scale;terrain.expansion=old.expansion;terrain.configure([])
 terrain.pieces=old.pieces.duplicate(true);terrain.height_buckets=old.height_buckets.duplicate(true)
 for key in old.get_meta_list():terrain.set_meta(key,old.get_meta(key))
 terrain.apply_grade(proposal,frame);Shore.append_supports(terrain,Floors.bank_rows(SHORE,proposal,frame));Floors.append_supports(terrain,proposal,frame);model.terrain=terrain
 var nav=Army.navigation_data(model,true);nav.route_spacing=3.*model.falan_scale
 nav.obstacle_min=nav.friendly_obstacle_min;nav.obstacle_max=nav.friendly_obstacle_max;nav.friendly_navigation=false
 var report={"scale":model.falan_scale,"navigation_region":str(model.navigation_region),"nav":{},"variants":[],"ramps":[]}
 for key in ["origin","bounds_min","bounds_max","width","spacing","route_spacing"]:report.nav[key]=str(nav[key])
 var pose=Transform3D(Basis(Vector3.UP,-frame.get_rotation()),Vector3(frame.origin.x,0,frame.origin.y));var scale3=Transform3D(Basis.from_scale(Vector3.ONE*model.falan_scale),Vector3.ZERO)
 for kind in ["actual-friendly","no-obstacles","exact-native-blocks"]:
  var data=nav.duplicate()
  if kind!="actual-friendly":data.obstacle_min=PackedVector3Array();data.obstacle_max=PackedVector3Array()
  if kind=="exact-native-blocks":
   for rect:Array in proposal.isolated_probe_original_blocked_rectangles:
    var a=(Vector2(rect[0],rect[1])-Vector2(45,60))*3.-Vector2.ONE*1.5;var box=scale3*(pose*AABB(Vector3(a.x,-10,a.y),Vector3(rect[2]*3.,50,rect[3]*3.)))
    data.obstacle_min.append(box.position);data.obstacle_max.append(box.end)
  var native=ClassDB.instantiate("GoemonCrowdRuntime");native.set_navigation(data);var reached=[];var starts=[];var radii=[]
  for ramp:Dictionary in proposal.ramps:
   var end:Vector2=frame*Vector2(ramp.landing_end[0],ramp.landing_end[1]);var at=model.world_point(end);starts.append({"point":str(at),"clear":native.ally_ground_clear(at,.35)})
  for radius in ([.25,.35,.4967896938,.60] if kind=="actual-friendly" else [.35]):
   reached=[]
   for row:Dictionary in proposal.water_rows:
    var at=frame*Vector2(row.anchor[0],row.anchor[1]);var target=model.world_point(at);var found=false
    for ramp:Dictionary in proposal.ramps:
     var end=frame*Vector2(ramp.landing_end[0],ramp.landing_end[1])
     if native.can_reach(model.world_point(end),target,radius):found=true;break
    if found:reached.append(row.source_cell)
   radii.append({"radius":radius,"reachable":reached.size()})
  report.variants.append({"kind":kind,"obstacles":data.obstacle_min.size(),"reachable":reached.size(),"reached_cells":reached,"radii":radii,"starts":starts})
 for ramp:Dictionary in proposal.ramps:
  var samples=[];var a=Vector2(ramp.a[0],ramp.a[1]);var b=Vector2(ramp.landing_end[0],ramp.landing_end[1])
  for step in range(31):
   var local=a.lerp(b,step/30.);var at=frame*local;var point=model.world_point(at);var nearby=[]
   for cell in model.scenery_obstacles:
    var box:AABB=model.scenery_obstacles[cell]
    if box.grow(.6).has_point(point/model.falan_scale):
     var owner="unmapped"
     if cell is Vector3i:
      var index=-1-cell.z
      if index<model.falan_frontier_plan.size():owner=str(model.falan_frontier_plan[index][0])
      elif model.has_meta("joined_village"):
       var plan=model.get_meta("joined_village").falan_frontier_plan;index-=model.falan_frontier_plan.size()
       if index>=0 and index<plan.size():owner=str(plan[index][0])
     nearby.append({"key":str(cell),"owner":owner,"bounds":str(box)})
   samples.append({"step":step,"source_point":str(local/3.+Vector2(45,60)),"world":str(point),"nearby_obstacles":nearby})
  report.ramps.append({"bank":ramp.source_bank_cell,"samples":samples})
 report.source_hashes=before;report.source_changed=Fresh.changed(before)
 var f=FileAccess.open(OUT+"main-model-diagnosis.json",FileAccess.WRITE);f.store_string(JSON.stringify(report,"  "));f.close()
 print("IL_MAIN_PROBE ",report.variants.map(func(v):return {"kind":v.kind,"radii":v.radii}));quit()
