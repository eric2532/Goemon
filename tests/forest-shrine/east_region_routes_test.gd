extends SceneTree
const Region=preload("res://scripts/forest/forest_east_region.gd")
const Maps=preload("res://scripts/forest/forest_original_maps.gd")
const Tour=preload("res://scripts/forest/forest_falan_tour.gd")
const REPORT="res://build/Other Files/Asset Toolkit/East Gate Region/route-matrix.json"
var checks=0
var failures=[]
var report={"maps":[],"fixed":[],"generated":[],"scripted":[],"blockers":[],"inferred":[]}
class StubGame extends Node:
 var FalanTour=preload("res://scripts/forest/forest_falan_tour.gd")
 var model={"seed_value":1701}

func _initialize():call_deferred("run")

func check(value:bool,label:String):
 checks+=1
 if not value:failures.append(label)

func reachable(row:Dictionary,start:Vector2i,finish:Vector2i)->bool:
 var pending=[start];var seen={start:true};var at=0
 while at<pending.size():
  var cell:Vector2i=pending[at];at+=1
  if cell==finish:return true
  for step in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
   var next=cell+step
   if not seen.has(next) and Maps.open(row.bits,row.size,next):seen[next]=true;pending.append(next)
 return false

func run():
 var source:Dictionary=Region.data();var generated=Maps.generated();var game=StubGame.new();root.add_child(game)
 set_meta("falan_venture",{"falan_areas":{"city":{}}})
 for original in source.fixed_maps:
  var id:int=Maps.runtime_id(int(original));var available:bool=Maps.owns(id) or Tour.Indoor.Data.FLOORS.has(id) or Tour.Regions.Sites.ROOMS.has(id) or int(original) in [2000,2400]
  report.maps.append({"source":int(original),"runtime":id,"available":available,"owner":"original_maps" if Maps.owns(id) else "existing_joined_village" if int(original) in [2000,2400] else "existing_native_interior"})
  check(available,"Missing current map owner %d"%int(original))
  if Maps.owns(id):
   var state:Dictionary=Maps.state(id,1701)
   check(state.size.x>0 and state.size.y>0,"Empty source map %d"%int(original))
  if report.maps.size()%50==0:print("EAST_ROUTE_MATRIX maps=",report.maps.size())
 for row in source.fixed:
  var source_id=int(row[0]);var target=int(row[3]);var cell=Vector2i(row[1],row[2]);var landing=Vector2i(row[4],row[5])
  var valid=Region.can_travel_source(game,target,landing)
  var record={"source":source_id,"cell":[cell.x,cell.y],"target":target,"landing":[landing.x,landing.y],"destination_valid":valid}
  report.fixed.append(record)
  if not valid:report.blockers.append(record.merged({"kind":"fixed_destination","reason":"Original landing has no current owner or no walkable source cell within2.1tiles."}))
  check(valid,"Unusable fixed arrival %s"%str(row))
 for row in source.event_links:
  var landing=row.get("landing",[])
  if landing==null or landing.size()!=2:continue
  var valid=Region.can_travel_source(game,int(row.target),Vector2i(landing[0],landing[1]))
  var source_blocked:bool=int(row.target) in [59702,59721] or int(row.target)==33000 and Vector2i(landing[0],landing[1])==Vector2i(754,319)
  var record={"source":int(row.source),"actor":row.get("actor"),"kind":row.kind,"target":int(row.target),"landing":landing,"destination_valid":valid,"script":row.get("script",""),"line":row.get("line",0)}
  report.scripted.append(record)
  if not valid:report.blockers.append(record.merged({"blocker_kind":"boundary_unavailable" if int(row.target) in [59702,59721] else "source_coordinate_conflict" if source_blocked else "script_destination","reason":"Separately owned island destination unavailable." if int(row.target) in [59702,59721] else "Original reward script targets754,319 (45tilesfromcurrentland); retain its separate574,318 branch without guessing." if source_blocked else "Source script remains gated; original landing has no usable current destination."}))
  check(valid or source_blocked,"Unusable scripted destination %s"%str(record))
 for key in generated.SPECS:
  var spec:Dictionary=generated.SPECS[key]
  if not spec.get("east",false):continue
  var entry:Vector2i=Region.prepare_field_entry(key,1701)
  check(entry.x>=mini(spec.entry_rect[0],spec.entry_rect[2]) and entry.y>=mini(spec.entry_rect[1],spec.entry_rect[3]) and entry.x<=maxi(spec.entry_rect[0],spec.entry_rect[2]) and entry.y<=maxi(spec.entry_rect[1],spec.entry_rect[3]),"Generated entry outside original rectangle "+key)
  check(entry==generated.entry_cell(key,1701),"Generated return lost chosen entry "+key)
  var entry_links=Region.links_source(int(spec.entry[0]),1701,Region.source_area(100,entry) if spec.entry[0]==100 else "")
  check(entry_links.any(func(link):return link.get("east_generator","")==key),"Missing generated entrance "+key)
  var floors=generated.count(key,1701);var branch={"config":spec.config,"entry":[entry.x,entry.y],"floors":floors,"floor_checks":[],"end":spec.end}
  check(floors>=spec.minimum and floors<=spec.maximum,"Generated count outside original range "+key)
  for n in range(1,floors+1):
   var id:int=generated.floor_id(key,n);var state:Dictionary=Maps.state(id,1701);var gates:Array=generated.doors(id,1701)
   var connected=reachable(state,gates[0],gates[1]);var links:Array=generated.links(id,1701)
   branch.floor_checks.append({"floor":n,"runtime":id,"stairs_connected":connected,"doors":links.size()})
   check(connected,"Disconnected generated stair path %s floor%d"%[key,n])
   check(links.size()==(1 if n==floors and spec.end.is_empty() else 2),"Wrong generated progression/return "+key)
   Maps.states.erase(Vector2i(id,1701))
  if not spec.end.is_empty():
   var end_links=Region.links_source(int(spec.end[0]),1701)
   check(end_links.any(func(link):return link.get("east_generator_return","")==key),"Missing dungeon endpoint reverse "+key)
  elif int(spec.terminal_enemy)>0:report.blockers.append({"kind":"terminal_contract","config":spec.config,"reason":spec.blocked_end,"source_actor":spec.terminal_enemy,"raw_count_field":spec.terminal_enemy_count})
  else:branch.ending="Source configuration has no fixed endpoint or terminal actor; the last floor returns through its original stair chain."
  if not spec.actor_ids.is_empty():report.blockers.append({"kind":"template_placement","config":spec.config,"actors":spec.actor_ids,"reason":"Original random NPC-template floor/cell placement contract is not available; no placement invented."})
  report.generated.append(branch)
  print("EAST_ROUTE_MATRIX config=",spec.config," floors=",floors)
 var model={"falan_area":"east_gate","falan_floor":0,"seed_value":1701}
 var merged=Region.merge_links(model,[{"at":Vector2.ZERO,"to":"city"},{"at":Vector2.ONE,"to":"freyja_site","site":410}])
 check(merged.any(func(link):return link.to=="city"),"Normal East Gate owner was removed")
 check(not merged.any(func(link):return link.get("site",-1)==410),"Synthetic direct Zombie entrance survived")
 for phase in 4:
  var selected=[]
  for warp in source.inline_warps:
   if int(warp.source)==100 and int(warp.cell[0])==665 and (int(warp.time_mask)&(1<<phase))!=0:selected.append(int(warp.target))
  check(selected==[11016 if phase<2 else 11017],"Day/night Minotaur entrance mismatch")
 report.checks=checks;report.failures=failures
 report.source_hashes={}
 for path in ["res://scripts/forest/forest_east_region.gd","res://scripts/forest/forest_original_dungeons.gd","res://assets/maps/falan/east_region/routes.json","res://assets/maps/falan/east_region/dungeon_specs.gd","res://assets/maps/original_crossgate/east/catalog.json"]:report.source_hashes[path]=FileAccess.get_sha256(path)
 report.inferred=["Generated floor realization and terminal80023 position use the shared seeded generator; original random layout/terminal placement unavailable."]
 var file=FileAccess.open(REPORT,FileAccess.WRITE);file.store_string(JSON.stringify(report," ")+"\n");file.close()
 print("EAST_ROUTE_MATRIX_RESULT maps=",report.maps.size()," static=",report.fixed.size()," scripted=",report.scripted.size()," configs=",report.generated.size()," checks=",checks," failures=",failures.size()," source_blockers=",report.blockers.size())
 for failure in failures:push_error(failure)
 quit(0 if failures.is_empty() else 1)
