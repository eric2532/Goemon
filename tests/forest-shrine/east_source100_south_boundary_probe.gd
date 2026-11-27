extends SceneTree
const Model=preload("res://scripts/forest/forest_model.gd")
const Regions=preload("res://scripts/forest/forest_freyja_regions.gd")
const Frontier=preload("res://scripts/forest/forest_falan_frontier.gd")
const Army=preload("res://scripts/forest/crowd/army_runtime.gd")
const DEST="res://build/Other Files/Asset Toolkit/East Gate Region/Runtime Audit/Source100 Missing13/Remote Views/"
func _initialize():run.call_deferred()
func run():
 var paths=[get_script().resource_path,"res://scripts/forest/forest_model.gd","res://scripts/forest/forest_freyja_regions.gd","res://scripts/forest/forest_freyja_terrain.gd","res://scripts/forest/forest_east_road.gd","res://scripts/forest/forest_falan_tour.gd","res://scripts/forest/forest_falan_frontier.gd","res://scripts/forest/crowd/army_runtime.gd","res://assets/maps/falan/venoa_field/data.gd","res://assets/maps/falan/freyja_outlying_data.gd"];var pins={}
 for path in paths:pins[path]=FileAccess.get_sha256(path)
 pins[DEST+"crop-open-frontiers.json"]=FileAccess.get_sha256(DEST+"crop-open-frontiers.json")
 var records=[];var continuation=[];var frontier_records=[];var outlier_records=[];var connection_records=[];var route=JSON.parse_string(FileAccess.get_file_as_string(DEST+"crop-open-frontiers.json"));var route_corners=[]
 for row:Dictionary in route.rock_continuation.targets:
  if row.target=="SouthGate-to-SouthLakes":route_corners=row.path_turns
 var route_cells=[]
 for index in route_corners.size()-1:
  var from=Vector2i(route_corners[index][0],route_corners[index][1]);var to=Vector2i(route_corners[index+1][0],route_corners[index+1][1]);var step=(to-from).sign();var at=from
  while at!=to:route_cells.append(at);at+=step
 route_cells.append(Vector2i(route_corners[-1][0],route_corners[-1][1]))
 for area in ["east_gate","south_gate","south_lakes","freyja"]:
  var model=Model.new();model.reset(42,{},Regions.layout(area),false);var frame:Transform2D=Regions.frame(area);var nav=Army.navigation_data(model,true);nav.obstacle_min=nav.friendly_obstacle_min;nav.obstacle_max=nav.friendly_obstacle_max;nav.friendly_navigation=false;var native=ClassDB.instantiate("GoemonCrowdRuntime");native.set_navigation(nav);var points=[];var edges=[]
  for x in [495,496,497]:
   var world=[];var clears=[]
   for y in [359,360]:
    var p:Vector2=frame.inverse()*(Vector2(x,y)*3.);var at=model.world_point(p);var mask:Image=model.terrain.mask_image();var pixel=Vector2i(((p-model.terrain.mask_origin())/3.).round());var rgba:Color=mask.get_pixelv(pixel)if Rect2i(Vector2i.ZERO,mask.get_size()).has_point(pixel)else Color.TRANSPARENT;var radii=[]
    for radius in [.25,.35,.55,.8]:radii.append({"radius":radius,"terrain_disk":model.terrain.disk_clear(Vector3(p.x,0,p.y),radius),"native_friendly_clear":native.ally_ground_clear(at,radius*model.falan_scale)})
    points.append({"source_cell":[x,y],"local_point":var_to_str(p),"world_point":var_to_str(at),"height":model.surface_height(p.x,p.y),"contains":model.terrain.contains(p.x,p.y),"mask_pixel":[pixel.x,pixel.y],"mask_rgba":[rgba.r,rgba.g,rgba.b,rgba.a],"radii":radii});world.append(at);clears.append(bool(radii[1].native_friendly_clear))
   var before:Vector2=frame.inverse()*(Vector2(x,359)*3.);var after:Vector2=frame.inverse()*(Vector2(x,360)*3.);var crossing=Regions.crossings(area,before,after)
   var trail=false
   if area=="east_gate":trail=before.x>Frontier.EAST_TRAIL_EDGE and after.x<=Frontier.EAST_TRAIL_EDGE and absf(after.y-279.)<=15.
   elif area=="south_gate":trail=before.y>Frontier.SOUTH_TRAIL_EDGE and after.y<=Frontier.SOUTH_TRAIL_EDGE and absf(after.x-261.)<=15.
   edges.append({"source_from":[x,359],"source_to":[x,360],"native_endpoints_clear":clears,"native_can_reach":bool(clears[0]and clears[1]and native.can_reach(world[0],world[1],.35*model.falan_scale)),"existing_region_handoff":var_to_str(crossing),"existing_east_south_trail_handoff":trail})
  var samples=[];var steps=[];var last:Variant=null
  for cell:Vector2i in route_cells:
   var p:Vector2=frame.inverse()*(Vector2(cell)*3.);var at=model.world_point(p);var clear=native.ally_ground_clear(at,.35*model.falan_scale)
   samples.append({"source_cell":[cell.x,cell.y],"height":model.surface_height(p.x,p.y),"contains":model.terrain.contains(p.x,p.y),"terrain_disk":model.terrain.disk_clear(Vector3(p.x,0,p.y),.35),"native_clear":clear})
   if last!=null:steps.append({"source_from":last.cell,"source_to":[cell.x,cell.y],"native_edge_clear":bool(last.clear and clear and native.can_reach(last.at,at,.35*model.falan_scale)),"existing_region_handoff":var_to_str(Regions.crossings(area,last.p,p))})
   last={"cell":[cell.x,cell.y],"clear":clear,"at":at,"p":p}
  continuation.append({"area":area,"radius":.35,"samples":samples,"steps":steps})
  var frontier=[]
  for row:Dictionary in route.compiler_open_frontiers:
   var local=[];var positions=[];var clear=[]
   for cell:Array in [row.source_from,row.source_to]:
    var p:Vector2=frame.inverse()*(Vector2(cell[0],cell[1])*3.);var at=model.world_point(p);local.append(p);positions.append(at);clear.append(native.ally_ground_clear(at,.35*model.falan_scale))
   var trail=false
   if area=="east_gate":trail=local[0].x>Frontier.EAST_TRAIL_EDGE and local[1].x<=Frontier.EAST_TRAIL_EDGE and absf(local[1].y-279.)<=15.
   elif area=="south_gate":trail=local[0].y>Frontier.SOUTH_TRAIL_EDGE and local[1].y<=Frontier.SOUTH_TRAIL_EDGE and absf(local[1].x-261.)<=15.
   var radii=[]
   for radius in [.25,.35,.55,.8]:
    var a=native.ally_ground_clear(positions[0],radius*model.falan_scale);var b=native.ally_ground_clear(positions[1],radius*model.falan_scale)
    radii.append({"radius":radius,"endpoints_clear":[a,b],"edge_clear":bool(a and b and native.can_reach(positions[0],positions[1],radius*model.falan_scale))})
   frontier.append({"source_from":row.source_from,"source_to":row.source_to,"native_endpoints_clear":clear,"native_edge_clear":bool(clear[0]and clear[1]and native.can_reach(positions[0],positions[1],.35*model.falan_scale)),"all_radii":radii,"region_handoff":var_to_str(Regions.crossings(area,local[0],local[1])),"trail_handoff":trail})
  frontier_records.append({"area":area,"radius":.35,"edges":frontier})
  var outliers=[]
  for row:Dictionary in route.outliers:
   var cell:Array=row.cell;var p:Vector2=frame.inverse()*(Vector2(cell[0],cell[1])*3.);var at=model.world_point(p);var radii=[]
   for radius in [.25,.35,.55,.8]:radii.append({"radius":radius,"native_clear":native.ally_ground_clear(at,radius*model.falan_scale)})
   outliers.append({"source_cell":cell,"height":model.surface_height(p.x,p.y),"contains":model.terrain.contains(p.x,p.y),"native_radii":radii})
  outlier_records.append({"area":area,"outliers":outliers})
  var directed=[]
  for row:Array in [["East-to-South-trail",[510,247],[510,248]],["South-to-East-trail",[510,246],[510,245]],["SouthGate-to-SouthLakes",[441,350],[441,351]],["SouthLakes-to-SouthGate",[441,349],[441,348]]]:
   var a:Vector2=frame.inverse()*(Vector2(row[1][0],row[1][1])*3.);var b:Vector2=frame.inverse()*(Vector2(row[2][0],row[2][1])*3.);var wa=model.world_point(a);var wb=model.world_point(b);var ca=native.ally_ground_clear(wa,.35*model.falan_scale);var cb=native.ally_ground_clear(wb,.35*model.falan_scale)
   directed.append({"label":row[0],"source_from":row[1],"source_to":row[2],"native_endpoints_clear":[ca,cb],"native_edge_clear":bool(ca and cb and native.can_reach(wa,wb,.35*model.falan_scale)),"region_handoff":var_to_str(Regions.crossings(area,a,b))})
  connection_records.append({"area":area,"directed_crossings":directed})
  records.append({"area":area,"terrain_owner":model.terrain.get_script().resource_path,"sampler":"FreyjaTerrain/KaiCPU + existing GoemonCrowdRuntime actual-friendly export","source_frame":var_to_str(frame),"nav_origin":var_to_str(nav.origin),"nav_bounds":[var_to_str(nav.bounds_min),var_to_str(nav.bounds_max)],"nav_spacing":nav.spacing,"points":points,"edges":edges});native=null
 var connections=[]
 for row:Array in Regions.Data.LINKS:
  if row[0]!="south_gate"or row[1]!="south_lakes":continue
  var at=Vector2(row[5],row[4]);var back=at;back[row[2]]-=row[3]*9.;connections.append({"from":row[0],"to":row[1],"outward_source_cell":[at.x/3.,at.y/3.],"return_source_cell":[back.x/3.,back.y/3.],"from_local":var_to_str(Regions.frame(row[0]).inverse()*at),"to_local":var_to_str(Regions.frame(row[1]).inverse()*at),"handoff_width_m":30.})
 connections.append({"from":"east_gate","to":"south_gate","outward_source_cell":[510.,(591.-Frontier.EAST_TRAIL_EDGE)/3.],"return_source_cell":[510.,(Frontier.SOUTH_TRAIL_EDGE+606.)/3.],"source_horizontal_span":[505.,515.],"meaning":"Existing presentation trail; not the y360rock boundary."})
 var changed=[]
 for path in pins:
  if pins[path]!=FileAccess.get_sha256(path):changed.append(path)
 var file=FileAccess.open(DEST+"south-boundary-current.json",FileAccess.WRITE);file.store_string(JSON.stringify({"source_hashes":pins,"source_changed":changed,"contexts":records,"rock_to_existing_road":continuation,"compiler_frontier_samplers":frontier_records,"outlier_samplers":outlier_records,"existing_directed_crossing_samplers":connection_records,"existing_connections":connections,"scope":"READONLYcurrentCPU/Nativefriendlysamplers and existing crossing code. No new handoff, terrain, source, collider or scene was created; y360is not treated as a regional wall. Dynamic city/protected-context transfers are not synthesized by these field probes."},"  "));file.close();print("EAST100_SOUTH_BOUNDARY contexts=",records.size()," continuation_cells=",route_cells.size()," frontier_edges=",route.compiler_open_frontiers.size()," outliers=",route.outliers.size()," changed=",changed);quit(0 if changed.is_empty()else 1)
