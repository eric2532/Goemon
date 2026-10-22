extends SceneTree
const Model=preload("res://scripts/forest/forest_model.gd")
const Document=preload("res://scripts/forest/forest_map_document.gd")
class CountedModel extends "res://scripts/forest/forest_model.gd":
 var placement_queries=0
 func placement_error(kind:String,cell:Vector2i,rotation:int)->String:
  placement_queries+=1
  return super.placement_error(kind,cell,rotation)
var checks=0
var failures=0
func _initialize():run.call_deferred()
func check(ok:bool,label_:String):
 checks+=1
 if not ok:failures+=1;printerr("FAIL: "+label_)
func fresh(map_name:String="forest_blood_gulch"):
 var m=Model.new();m.reset(42,{},JSON.parse_string(FileAccess.get_file_as_string("res://assets/maps/%s.json"%map_name)),false)
 return m
func run():
 var m=fresh()
 check(m.placement_error("tower",Vector2i(-24,-24),0).is_empty(),"A supported gentle Blood Gulch shoulder accepts a tower")
 var built=m.build("tower",Vector2i(-24,-24),0)
 check(not built.is_empty(),"The gentle-ground preview can be committed as a real building")
 var captured=Document.new(false);captured.capture(m)
 check(Document.validate(captured.data).is_empty(),"A tower on gentle ground remains valid after capture for saving")
 var loaded=Document.new(false);check(loaded.decode(captured.encode()).is_empty(),"Gentle-ground structures reload through the real map document")
 check(not m.placement_error("tower",Vector2i(-24,-24),0).is_empty(),"A second tower cannot overlap the newly placed tower")
 var kai=fresh("forest_kai_highway")
 check(kai.placement_error("tower",Vector2i(-13,-2),0).is_empty(),"Kai's shallow castle shoulder accepts a supported tower")
 check(not kai.placement_error("tower",Vector2i(-34,-34),0).is_empty(),"Unsupported terrain cannot accept a building")
 check(not m.placement_error("wall",Vector2i(-27,0),0).is_empty(),"A long wall cannot bridge the steep canyon side")
 var ramparts=fresh("forest_twin_ramparts")
 check(not ramparts.placement_error("wall",Vector2i(0,9),0).is_empty(),"The authored ramp entrance stays reserved")
 var portal=m.portals.front()
 check(not m.placement_error("tower",Vector2i(portal.x,portal.z),0).is_empty(),"Spawn portal and exit ground remain reserved")
 check(not m.placement_error("tower",Vector2i(0,7),0).is_empty(),"Buildings cannot replace the castle's occupied gate")
 check(m.placement_error("tower",Vector2i(0,2),0).is_empty(),"Clear land at the original hero point can be used for construction")
 check(not m.placement_error("tower",Vector2i(28,0),0).is_empty(),"The unsupported canyon edge remains unbuildable")
 var outer=fresh()
 check(outer.placement_error("tower",Vector2i(-16,-30),0).is_empty(),"Reachable supported canyon ground beyond the old castle boundary accepts a tower")
 check(not outer.build("tower",Vector2i(-16,-30),0).is_empty(),"An outer canyon site commits through the real purchase path")
 var outer_map=Document.new(false);outer_map.capture(outer)
 check(Document.validate(outer_map.data).is_empty() and Document.new(false).decode(outer_map.encode()).is_empty(),"Expanded native building sites survive map validation and reload")
 check(kai.placement_error("tower",Vector2i(-11,-30),0).is_empty(),"Reachable native Kai ground also uses the map's full build region")
 check(not outer.placement_error("tower",Vector2i(-47,-47),0).is_empty(),"Unsupported outer canyon edges remain unbuildable")
 check(ramparts.placement_error("tower",Vector2i(28,0),0).is_empty(),"Authored raised-wall maps also allow clear land beyond the old settlement boundary")
 var road=fresh("forest_shrine_original")
 road.roads[Vector2i(3,-3)]=true
 check(road.placement_error("tower",Vector2i(3,-3),0).is_empty(),"An ordinary painted road does not reserve extra empty building ground")
 var ground=Model.KaiTerrain.new()
 ground.width=161;ground.spacing=3.0
 ground.heights.resize(161*161);ground.heights.fill(0.0)
 ground.covered.resize(161*161);ground.covered.fill(1)
 if ground.has_method("building_error"):
  check(ground.building_error([Vector2i.ZERO]).is_empty(),"A complete level terrain patch supports construction")
  check(ground.has_method("foundation_depth"),"Supported native ground exposes a foundation depth to close downhill gaps")
  if ground.has_method("foundation_depth"):
   check(is_equal_approx(ground.foundation_depth([Vector2i.ZERO],.6),.6),"A foundation reaches from the unchanged anchor height down to the terrain minimum")
   check(is_zero_approx(ground.foundation_depth([Vector2i.ZERO],-.6)),"An anchor below supported ground never creates a negative foundation")
  ground.covered[80*161+80]=0;ground.building_ground_cache.clear()
  check(not ground.building_error([Vector2i.ZERO]).is_empty(),"A hole between footprint edges cannot be hidden by supported corners")
  ground.covered[80*161+80]=1
  for z in range(79,83):
   for x in range(79,93):ground.heights[z*161+x]=(x-79)*.11
  ground.building_ground_cache.clear()
  check(ground.building_error([Vector2i(0,0),Vector2i(1,0),Vector2i(2,0),Vector2i(3,0),Vector2i(4,0),Vector2i(5,0)]).is_empty(),"A long wall accepts continuously supported gentle ground regardless of total rise")
 if not m.has_method("resolve_placement"):
  check(false,"Placement resolves a nearby legal footprint without requiring precise pixel hunting")
 else:
  var base=fresh("forest_shrine_original")
  var before_gold=base.gold;var before_revision=base.revision;var before_buildings=base.buildings.size()
  var exact=base.resolve_placement("tower",Vector2i(3,-3),0)
  check(exact.error.is_empty() and exact.cell==Vector2i(3,-3) and not exact.adjusted,"An exact legal target never moves")
  var adjacent=base.resolve_placement("tower",Vector2i(1,-2),0)
  check(adjacent.error.is_empty() and adjacent.cell.distance_squared_to(Vector2i(1,-2))<=2 and adjacent.adjusted,"An invalid footprint gently snaps to a valid adjacent anchor")
  check(base.placement_error("tower",adjacent.cell,adjacent.rotation).is_empty(),"Every resolved target passes the authoritative placement rules")
  check(base.gold==before_gold and base.revision==before_revision and base.buildings.size()==before_buildings,"Finding a nearby site never spends gold or mutates the settlement")
  var blocked=base.resolve_placement("tower",Vector2i(0,0),0)
  check(not blocked.error.is_empty() and blocked.cell==Vector2i(0,0),"Blocked targets do not teleport across a large structure")
  base.phase="wave"
  check(not base.resolve_placement("tower",Vector2i(3,-3),0).error.is_empty(),"Nearby snapping cannot bypass the preparation phase")
  var counted=CountedModel.new();counted.reset(42,{},JSON.parse_string(FileAccess.get_file_as_string(Document.ORIGINAL_PATH)),false)
  var shrine_route=counted.route(Vector2i(0,8),Vector2i(0,2))
  counted.resolve_placement("tower",Vector2i(0,0),0)
  check(counted.placement_queries<=9,"A default nearby search has a fixed small placement-query budget")
  check(counted.route(Vector2i(0,8),Vector2i(0,2))==shrine_route,"Rejected preview searches preserve the real gate route")
 print("BUILDING_PLACEMENT_EASE_RESULT checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)
