extends SceneTree
const Maps=preload("res://scripts/forest/forest_original_maps.gd")
const Region=preload("res://scripts/forest/forest_east_region.gd")
var failures=[]
var checks=0
func _initialize():call_deferred("run")
func check(value:bool,label:String):
 checks+=1
 if not value:failures.append(label)
func run():
 var generated=Maps.generated();var branches=[]
 for key in generated.SPECS:
  var spec:Dictionary=generated.SPECS[key]
  if not spec.get("east",false):continue
  var count_=generated.count(key,1701);var samples=[1,count_]
  if count_>2:samples.append(2)
  for n in samples:
   var id:int=generated.floor_id(key,n);var state:Dictionary=Maps.state(id,1701);var stairs=generated.stair_serials(id,1701)
   var expected=[spec.source_entrance_graphics[0] if n==1 else spec.stairs[0],spec.source_entrance_graphics[1] if n==count_ else spec.stairs[1]]
   check(stairs==expected,"First/last source stair variant mismatch "+key)
   var gates=generated.doors(id,1701);var cells:int=state.size.x*state.size.y
   for side in 2:
    var serial:int=state.raw.decode_u16(20+(cells+gates[side].y*state.size.x+gates[side].x)*2)
    check(serial==(int(stairs[side]) if int(stairs[side])<65536 else 0),"Animated stair truncated into staticu16 "+key)
   var links=generated.links(id,1701)
   check(links[0].get("diamond",false)==(int(stairs[0])==103012),"Back marker lacks original animation "+key)
   if links.size()>1:check(links[1].get("diamond",false)==(int(stairs[1])==103012),"Forward marker lacks original animation "+key)
  var entry=Region.prepare_field_entry(key,1701)
  var links=Region.links_source(int(spec.entry[0]),1701,Region.source_area(100,entry) if int(spec.entry[0])==100 else "")
  var entrance=links.filter(func(link):return link.get("east_generator","")==key)
  check(entrance.size()==1,"Fixed entry marker missing "+key)
  if not entrance.is_empty():check(entrance[0].get("diamond",false)==(int(spec.source_fixed_markers[0])==103012),"Fixed source entry marker mismatch "+key)
  if not spec.end.is_empty():
   var endpoints=Region.links_source(int(spec.end[0]),1701).filter(func(link):return link.get("east_generator_return","")==key)
   check(endpoints.size()==1,"Fixed endpoint marker missing "+key)
   if not endpoints.is_empty():check(endpoints[0].get("diamond",false)==(int(spec.source_fixed_markers[1])==103012),"Fixed source endpoint marker mismatch "+key)
  branches.append({"config":spec.config,"source_fixed_markers":spec.source_fixed_markers,"first_last_stairs":spec.source_entrance_graphics,"normal_stairs":spec.stairs})
 var sources={}
 for path in ["res://scripts/forest/forest_original_dungeons.gd","res://scripts/forest/forest_east_region.gd","res://assets/maps/falan/east_region/dungeon_specs.gd"]:sources[path]=FileAccess.get_sha256(path)
 var file=FileAccess.open("res://build/Other Files/Asset Toolkit/East Gate Region/generated-marker-matrix.json",FileAccess.WRITE);file.store_string(JSON.stringify({"checks":checks,"failures":failures,"branches":branches,"source_hashes":sources}," ")+"\n");file.close()
 print("EAST_MARKERS_RESULT configs=",branches.size()," checks=",checks," failures=",failures.size())
 for failure in failures:push_error(failure)
 quit(0 if failures.is_empty() else 1)
