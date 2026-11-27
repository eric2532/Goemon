extends SceneTree
## Every source-configured East/Akelufa/Goral floor, without the legacy roster.
const Gen=preload("res://scripts/forest/forest_original_dungeons.gd")
const OUT="res://build/Other Files/Asset Toolkit/East Gate Region/Verification/dungeon-contracts.json"
var checks=0
var failures=0
var floors=0
var records=[]
func _initialize():run.call_deferred()
func check(ok:bool,message:String):
 checks+=1
 if not ok:failures+=1;printerr("EAST_DUNGEON_FAIL "+message)
func open(bits:PackedByteArray,size_:Vector2i,cell:Vector2i)->bool:
 if cell.x<0 or cell.y<0 or cell.x>=size_.x or cell.y>=size_.y:return false
 var i=cell.y*size_.x+cell.x
 return bool(bits[i>>3]&(1<<(i&7)))
func connected(row:Dictionary)->bool:
 var first:Vector2i=row.doors[0];var last:Vector2i=row.doors[1]
 var queue=[first];var seen={first:true};var head=0
 while head<queue.size():
  var at:Vector2i=queue[head];head+=1
  if at==last:return true
  for delta in [Vector2i.UP,Vector2i.DOWN,Vector2i.LEFT,Vector2i.RIGHT]:
   var next:Vector2i=at+delta
   if seen.has(next) or not open(row.bits,row.size,next):continue
   seen[next]=true;queue.append(next)
 return false
func run():
 check(Gen.SPECS.values().filter(func(spec):return spec.get("east",false)).size()==68,"All68 source configurations in the frozen closure are present")
 for key in Gen.SPECS:
  var spec:Dictionary=Gen.SPECS[key]
  if not spec.get("east",false):continue
  check(spec.first==2000000+spec.config*1000,"Stable source config floor IDs "+key)
  var count_:int=Gen.count(key,42)
  check(count_>=spec.minimum and count_<=spec.maximum,"Source floor count "+key)
  var widths={};var heights={}
  for n in int(spec.maximum):
   var id:int=Gen.floor_id(key,n+1)
   var row:Dictionary=Gen.make(id,42);floors+=1
   check(Gen.owns(id) and Gen.branch(id)==key and Gen.number(id)==n+1,"Runtime ownership "+str(id))
   check(row.size.x>=spec.size[0] and row.size.x<=spec.size[1] and row.size.y>=spec.size[2] and row.size.y<=spec.size[3],"Source dimension range "+str(id))
   var cells:int=row.size.x*row.size.y
   check(row.raw.size()==20+cells*6,"Complete original-format generated planes "+str(id))
   check(row.raw.decode_u32(12)==row.size.x and row.raw.decode_u32(16)==row.size.y,"Generated header dimensions "+str(id))
   var expected_stairs:Array=spec.stairs.duplicate()
   if n==0:expected_stairs[0]=spec.source_entrance_graphics[0]
   if n+1==count_:expected_stairs[1]=spec.source_entrance_graphics[1]
   check(row.source_stairs==expected_stairs,"Exact source normal and first/last stair identities retained "+str(id))
   check(connected(row),"Both stair thresholds share the generated walking corridor "+str(id))
   for i in 2:
    var cell:Vector2i=row.doors[i]
    var serial:int=row.raw.decode_u16(20+(cells+cell.y*row.size.x+cell.x)*2)
    check(serial==(int(expected_stairs[i]) if expected_stairs[i]<65536 else 0),"Animated stairs never truncate into unrelated graphics "+str(id))
   if n<spec.size[1]-spec.size[0]+1:check(not widths.has(row.size.x),"Width bag draws without replacement "+str(id))
   if n<spec.size[3]-spec.size[2]+1:check(not heights.has(row.size.y),"Height bag draws without replacement "+str(id))
   widths[row.size.x]=true;heights[row.size.y]=true
   if spec.outdoor:
    var ground_complete=true;var trees=0;var boundary_count=0;var original_only=true;var original_edges=[]
    for decoration in spec.source_decorations:
     if int(decoration[1])>0 and (int(decoration[0]) in range(10050,10100) or int(decoration[0]) in range(11600,11631) or int(decoration[0]) in range(15067,15082) or int(decoration[0]) in range(15012,15021)):original_edges.append(int(decoration[0]))
    for j in cells:
     ground_complete=ground_complete and row.raw.decode_u16(20+j*2)==spec.ground
     var serial:int=row.raw.decode_u16(20+(cells+j)*2)
     if serial in original_edges:trees+=1
     if serial!=0 and j not in [row.doors[0].y*row.size.x+row.doors[0].x,row.doors[1].y*row.size.x+row.doors[1].x]:
      boundary_count+=1;original_only=original_only and serial in original_edges
    check(ground_complete and original_only and (boundary_count==0 if original_edges.is_empty() else trees>0),"Outdoor floors retain native ground and source-only weighted boundary art (including configured empty decoration sets) "+str(id))
  records.append({"config":spec.config,"possible_floors":spec.maximum,"selected_floors":count_,"blocked_end":spec.blocked_end,"outdoor":spec.outdoor,"outdoor_inferred":spec.get("outdoor_inferred",false),"return_only":spec.get("return_only",false)})
 check(floors==725,"All725 possible source floors in the frozen closure were generated")
 # A later run retains only that run's East dimension/count/entry cache.
 var one="east_2";Gen.dimensions(Gen.floor_id(one,1),43)
 check(Gen.sizes.keys().filter(func(token):return token is Vector2i and token.x>=2000000).size()==Gen.SPECS[one].maximum,"East floor dimensions do not accumulate across runs")
 Gen.set_entry_cell("east_102",43,Vector2i(650,140))
 check(Gen.entry_cell("east_102",43)==Vector2i(650,140),"Existing Freyja owner supplies the chosen original entrance cell")
 var file=FileAccess.open(OUT,FileAccess.WRITE)
 file.store_string(JSON.stringify({"checks":checks,"failures":failures,"floors":floors,"branches":records,"scope":"Source contracts, seeded graph connectivity, shuffle bags and bounded caches. Does not certify original random topology, rendering, gameplay combat or every live transition."},"  "));file.close()
 print("EAST_DUNGEON_CONTRACT_RESULT checks=",checks," failures=",failures," floors=",floors)
 quit(1 if failures else 0)
