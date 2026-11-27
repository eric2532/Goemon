extends SceneTree
## Direct cached Host preflight. No activation, native army, player or pet movement.
const Host=preload("res://scripts/forest/forest_east_host_source_context.gd")
const Context=preload("res://scripts/forest/forest_east_source_context_review.gd")
const Regions=preload("res://scripts/forest/forest_freyja_regions.gd")
const Fresh=preload("res://tests/forest-shrine/east_review_sources.gd")
const RADII=[.25,.35,.4967896938,.60]
const EDGES=[[[474,73],[474,74]],[[474,74],[474,75]],[[474,74],[475,74]],[[474,75],[474,76]],[[474,76],[474,77]],[[474,76],[475,76]],[[474,77],[474,78]],[[474,77],[475,77]]]
class Model:
 extends RefCounted
 var falan_area="north_coast"
 var falan_scale=1.3
 var terrain
var checks=0
var failures=[]
var edge_cases=[]
var handoff_cases=[]
func _initialize():call_deferred("run")
func check(okay:bool,label:String):
 checks+=1
 if not okay:failures.append(label);push_error(label)
func point(cell:Vector2,area:String)->Vector2:return Regions.frame(area).inverse()*(cell*3.)
func run():
 var manifest:Dictionary=Host.manifest();var inputs_valid=manifest.has("areas")
 for area_:String in ["north_coast","east_gate"]:
  if not manifest.get("areas",{}).has(area_):inputs_valid=false;continue
  var row:Dictionary=manifest.areas[area_]
  inputs_valid=inputs_valid and FileAccess.get_sha256(row.path)==row.sha256
 if not inputs_valid:
  printerr("HANDOFF_PREFLIGHT_NOT_RUN: both atomically prepared field products must match their manifest; no source/technical blocker is inferred")
  quit(1);return
 var paths=[get_script().resource_path,"scripts/forest/forest_east_host_source_context.gd","scripts/forest/forest_east_host_source_field.gd","scripts/forest/forest_east_source_context_review.gd","scripts/forest/forest_freyja_regions.gd",Host.ROOT+"manifest.json",Context.ROOT+"field100-restore.json",Context.ROOT+"100.dat",Context.ROOT+"same-source-handoff.patch",Context.ROOT+"handoff-shadow/scripts/forest/forest_falan_tour.gd"]
 for area_:String in ["north_coast","east_gate"]:
  var row:Dictionary=manifest.areas[area_];paths.append(row.path);paths.append(Host.data(area_).mask_path)
 var before=Fresh.snapshot(paths);var north=Host.terrain_for("north_coast");var east=Host.terrain_for("east_gate");var model=Model.new();model.terrain=north
 check(Regions.private_source_context==null,"Direct preflight leaves the shared context disabled")
 check(Host.domains.north_coast==Rect2(-480,-480,957,957),"North handoff uses the actual sampled-grid/navigation intersection[-480,477], not padded visual bounds")
 var proposal:Dictionary=east.proposal;var bounds:Rect2=east.mask_bounds();var low=Vector2i((bounds.position/6.).floor());var region=Rect2i(low,Vector2i((bounds.end/6.).ceil())-low)
 var navigation=Rect2(Vector2(region.position)*6.-Vector2.ONE*3.,Vector2(region.size)*6.);var grid=Rect2(Vector2(proposal.origin[0],proposal.origin[1]),Vector2.ONE*(east.width-1)*east.spacing)
 check(Host.domains.east_gate==navigation.intersection(grid),"East handoff domain matches its sampled grid intersected with the existing model navigation formula")
 # The five sourceX474anchors lose thirteen represented directions in North;
 # four radius assertions per direction produced the historical52failures.
 # Test all eight represented edges BOTH ways, separately from that subset.
 for edge:Array in EDGES:
  for reverse in 2:
   var a=Vector2(edge[reverse][0],edge[reverse][1]);var b=Vector2(edge[1-reverse][0],edge[1-reverse][1])
   for world_radius in RADII:
    var clear=true;var radius=world_radius/model.falan_scale
    for sample in 21:clear=clear and Host.original_disk(east,point(a.lerp(b,sample/20.),"east_gate"),radius,model.falan_scale)
    check(clear,"Cached opposite-frame original disk covers represented source edge "+str(a)+"→"+str(b)+" radius"+str(world_radius));edge_cases.append({"a":[a.x,a.y],"b":[b.x,b.y],"world_radius":world_radius,"samples":21,"clear":clear})
 check(edge_cases.size()==64,"Eight represented edges are checked bidirectionally at four exact world radii (64cases, distinct from historical52assertions)")
 for y in [73,75,76,77]:
  for world_radius in RADII:
   var clear=true
   for sample in 21:clear=clear and Host.original_disk(east,point(Vector2(474,y).lerp(Vector2(473,y),sample/20.),"east_gate"),world_radius/model.falan_scale,model.falan_scale)
   check(clear,"Separate original-open west edge beyond North's grid remains preflight-clear in East "+str(y)+" radius"+str(world_radius))
 # A real original-open approach enters the guard before the full disk can
 # reach the North minimum column. Its position is deliberately noninteger.
 var source_at=Vector2(474.9,74.07);var at=point(source_at,"north_coast");var previous=point(Vector2(475.2,74.07),"north_coast")
 for world_radius in RADII:
  var radius=world_radius/model.falan_scale;var handoff:Dictionary=Host.scene_handoff(model,previous,at,radius)
  check(not handoff.is_empty() and handoff.get("area","")=="east_gate","Outward handoff fires before North's whole-disk edge for radius"+str(world_radius))
  if handoff.is_empty():continue
  var reconstructed:Vector2=Regions.frame(handoff.area)*handoff.arrival/3.
  check(reconstructed.distance_to(source_at)<.00001,"Handoff retains exact fractional source position without nudge radius"+str(world_radius))
  check(Host.domains.north_coast.has_point(at) and at.x-Host.domains.north_coast.position.x>radius,"Handoff fires while the actual complete body still fits before the native clamp")
  var expected_rotation=Regions.frame("east_gate").get_rotation()-Regions.frame("north_coast").get_rotation()
  var yaw=.73;var velocity=Vector3(2.3,0,-1.1);var next_yaw=yaw+float(handoff.rotation);var next_velocity=velocity.rotated(Vector3.UP,float(handoff.rotation))
  check(is_equal_approx(float(handoff.rotation),expected_rotation) and is_equal_approx(next_yaw-expected_rotation,yaw) and next_velocity.rotated(Vector3.UP,-expected_rotation).distance_to(velocity)<.00001,"Existing Tour frame yaw/velocity conversion is exactly reversible")
  model.falan_area="east_gate";model.terrain=east
  check(Host.scene_handoff(model,handoff.arrival,handoff.arrival,radius).is_empty(),"Stationary exact arrival in the other scene does not bounce")
  model.falan_area="north_coast";model.terrain=north
  check(Host.scene_handoff(model,at,at,radius).is_empty(),"Stationary near-edge source point does not hand off")
  check(Host.scene_handoff(model,at-Vector2(0,.1),at,radius).is_empty(),"Parallel near-edge motion does not hand off")
  check(Host.scene_handoff(model,at-Vector2(.1,0),at,radius).is_empty(),"Inward near-edge motion does not hand off")
  var closed_at=point(Vector2(474.9,73),"north_coast")
  check(not east.source_open(Vector2i(475,73)) and Host.scene_handoff(model,closed_at+Vector2(.1,0),closed_at,radius).is_empty(),"Original-closed target cannot become a free handoff")
  handoff_cases.append({"world_radius":world_radius,"source_float":var_to_str(source_at),"handoff":var_to_str(handoff)})
 var tour=FileAccess.get_file_as_string(Context.ROOT+"handoff-shadow/scripts/forest/forest_falan_tour.gd")
 var doors=tour.find("if not door.is_empty():");var original=tour.find("var crossing=Regions.crossings");var call=tour.find("source_context.scene_handoff(game,before,at)");var outlying=tour.find("if outlying:return false",original)
 check(doors>=0 and doors<original and original<call and call<outlying and tour.substr(call-115,115).contains("if source_context!=null:"),"Staged Tour retains original door/crossing priority and a null guard before the optional handoff")
 var changed=Fresh.changed(before);check(changed.is_empty(),"Direct handoff inputs remained current")
 check(Regions.private_source_context==null,"Direct handoff proof never activates a private scene")
 Host.reset();var report={"checks":checks,"failures":failures,"represented_edges":edge_cases,"handoffs":handoff_cases,"source_hashes":before,"source_changed_during_run":changed,"historical_assertions":{"cells":5,"undirected_edges":8,"directions":13,"radii":4,"assertions":52},"scope":"PRIVATE direct cached Host geometry/preflight only, tested without Host.ready or any context activation. It does not certify Native outside/bridge parity, original crossing actual execution, full source100 routes, player/pet locomotion or visible scene quality. All actual movement/seam and end-to-end source gates remain unfinished."}
 var file=FileAccess.open(Context.ROOT+"handoff-preflight-contracts.json",FileAccess.WRITE);file.store_string(JSON.stringify(report," "));file.close();print("EAST_SOURCE_HANDOFF_PREFLIGHT checks=",checks," failures=",failures.size());quit(failures.size())
