extends SceneTree
const Candidate=preload("res://tests/forest-shrine/east_source100_display_handoff_candidate.gd")
const Model=preload("res://scripts/forest/forest_model.gd")
const Army=preload("res://scripts/forest/crowd/army_runtime.gd")
const OUT="res://build/Other Files/Asset Toolkit/East Gate Region/Runtime Audit/Source100 Missing13/Display Handoff Proposal/"
func _initialize():run.call_deferred()
func run():
 var paths=[get_script().resource_path,"res://tests/forest-shrine/east_source100_display_handoff_candidate.gd","res://scripts/forest/forest_freyja_regions.gd","res://scripts/forest/forest_freyja_terrain.gd","res://scripts/forest/forest_east_road.gd","res://scripts/forest/forest_model.gd","res://scripts/forest/crowd/army_runtime.gd"];var pins={};var checks=0;var failures=[];var records=[]
 for path in paths:pins[path]=FileAccess.get_sha256(path)
 for area in ["east_gate","south_gate"]:
  var model=Model.new();model.reset(42,{},Candidate.Regions.layout(area),false);var frame:Transform2D=Candidate.Regions.frame(area);var nav=Army.navigation_data(model,true);nav.obstacle_min=nav.friendly_obstacle_min;nav.obstacle_max=nav.friendly_obstacle_max;nav.friendly_navigation=false;var native=ClassDB.instantiate("GoemonCrowdRuntime");native.set_navigation(nav);var samples=[]
  for dy in [-.65,-.325,0.,.325,.65]:
   for dx in [-1.5,-.75,0.,.75,1.5]:
    var source=Vector2(Candidate.EDGE+dx,Candidate.CENTER+dy);var p=frame.inverse()*source;var at=model.world_point(p)
    for radius in [.25,.35,.55,.8]:
     var clear:bool=native.ally_ground_clear(at,radius*model.falan_scale);checks+=1
     if not clear:failures.append({"area":area,"source_float":var_to_str(source/3.),"radius":radius,"reason":"existing Native disk is not clear"})
     samples.append({"source_float":var_to_str(source/3.),"radius":radius,"height":model.surface_height(p.x,p.y),"native_clear":clear})
   var sign_=-1. if area=="east_gate"else 1.;var from=Vector2(Candidate.EDGE-sign_*.75,Candidate.CENTER+dy);var to=Vector2(Candidate.EDGE+sign_*.75,Candidate.CENTER+dy);var a=frame.inverse()*from;var b=frame.inverse()*to;var crossing=Candidate.crossing(area,a,b,true);checks+=1
   if crossing.is_empty()or (Candidate.Regions.frame(crossing.area)*crossing.arrival).distance_to(to)>.0002:failures.append({"area":area,"reason":"handoff moved original source coordinates"})
   checks+=1
   if not Candidate.crossing(area,a,b).is_empty():failures.append({"area":area,"reason":"default-unready interface must remain disabled"})
   for radius in [.25,.35,.55,.8]:
    checks+=1
    if not native.can_reach(model.world_point(a),model.world_point(b),radius*model.falan_scale):failures.append({"area":area,"dy":dy,"radius":radius,"reason":"existing Native edge is blocked"})
  for dy in [-.66,.66,3.]:
   checks+=1;var a=frame.inverse()*Vector2(Candidate.EDGE+1,Candidate.CENTER+dy);var b=frame.inverse()*Vector2(Candidate.EDGE-1,Candidate.CENTER+dy)
   if not Candidate.crossing(area,a,b,true).is_empty():failures.append({"area":area,"dy":dy,"reason":"outside confirmed span transferred"})
  records.append({"area":area,"samples":samples});native=null
 var changed=[]
 for path in pins:
  if FileAccess.get_sha256(path)!=pins[path]:changed.append(path)
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT));var file=FileAccess.open(OUT+"contract.json",FileAccess.WRITE);file.store_string(JSON.stringify({"checks":checks,"failures":failures,"source_changed":changed,"source_hashes":pins,"contexts":records,"scope":"PRIVATE CPU proposal only; no scene transfer, rendered terrain, player/pet test or shared publication. Original same-map coordinates retained. Technical display handoff, not original warp."},"  "));file.close();print("EAST100_DISPLAY_HANDOFF checks=",checks," failures=",failures.size()," changed=",changed);quit(failures.size()+changed.size())
