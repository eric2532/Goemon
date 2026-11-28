extends SceneTree
## Source/mask eligibility only. A passing entry still needs actual walk/F/enter/leave proof.
const Maps=preload("res://scripts/forest/forest_original_maps.gd")
const Routes=preload("res://scripts/forest/forest_explore_routes.gd")
const OUT="res://build/Other Files/Asset Toolkit/Explore Access/"
class SeedModel:
 extends RefCounted
 var seed_value=20261127
class LandingContext:
 extends RefCounted
 const FalanTour=preload("res://scripts/forest/forest_falan_tour.gd")
 var model=SeedModel.new()
 func get_tree()->SceneTree:return Engine.get_main_loop()as SceneTree
func _initialize():
 create_timer(120.).timeout.connect(func():printerr("EXPLORE_LANDING_INVENTORY_TIMEOUT");quit(1))
 run.call_deferred()
func run():
 var inventory=JSON.parse_string(FileAccess.get_file_as_string(OUT+"runtime-inventory.json"))
 var available={}
 for map_ in inventory.maps:
  if map_.available_source:available[int(map_.source)]=true
 set_meta("falan_venture",{"falan_areas":{"city":{},"castle":{}}})
 var context=LandingContext.new();var report={"qualification":"Source/mask eligibility via the production Explore travel preflight. Native hubs/fields and generated terminal templates still require their separate owners and actual player-route checks. Entrance crop gaps require frontage review; they do not by themselves prove an NPC unreachable.","checked_original_landings":0,"script_landing_blockers":[],"script_entrance_crop_gaps":[]}
 Routes.data()
 assert(Routes.can_travel(context,4100,Vector2i(113,96)),"Full Astia includes the original tunnel arrival")
 assert(Maps.source_point(4100,Vector2i(61,130))==Vector2(0,9),"Old Astia boundary coordinates are preserved")
 assert(not Routes.field_cell_clear(100,Vector2i(665,184)),"Original day/night cave triggers are excluded from Explore arrivals")
 var outside=Routes.field_destination(100,Vector2i(665,184))
 assert(not outside.is_empty(),"Original minotaur victory exit still has nearby legal field ground")
 var arrival_cell=Vector2i(((context.FalanTour.Regions.frame(outside.area)*outside.arrival)/3.).round())
 assert(Routes.field_cell_clear(100,arrival_cell)and Vector2(arrival_cell-Vector2i(665,184)).length()<=3.,"Explore exit remains beside its original entrance without re-entering its automatic Warp")
 for rows in Routes.data().values():
  for route in rows:
   var source=int(route.source);var target=int(route.target)
   if not available.has(source):continue
   var origin=Maps.runtime_id(source)
   if Maps.owns(origin)and not Maps.crop(origin).has_point(Vector2i(route.cell[0],route.cell[1])):
    report.script_entrance_crop_gaps.append(route)
   if target in[100,300,1000,1500,2000,2100,2300,2400,3000,3200]or not Maps.owns(Maps.runtime_id(target)):continue
   report.checked_original_landings+=1
   if Routes.can_travel(context,target,Vector2i(route.landing[0],route.landing[1])):continue
   var entry:Dictionary=route.duplicate(true)
   entry.reason="Incomplete original layout"if not Routes.complete_destination(target)else"The production travel preflight cannot supply this original landing inside the active map"
   report.script_landing_blockers.append(entry)
 var file=FileAccess.open(OUT+"landing-access-gaps.json",FileAccess.WRITE);file.store_string(JSON.stringify(report,"  "));file.close()
 print("EXPLORE_LANDING_INVENTORY checked=",report.checked_original_landings," blocked_landings=",report.script_landing_blockers.size()," source_crop_reviews=",report.script_entrance_crop_gaps.size())
 quit()
