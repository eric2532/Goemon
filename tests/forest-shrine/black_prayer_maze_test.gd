extends SceneTree
const Prayer=preload("res://scripts/forest/forest_black_prayer.gd")
var failures=0
var checks=0
func check(ok:bool,message:String):
 checks+=1
 if not ok:
  failures+=1
  printerr("BLACK_PRAYER_FAIL ",message)
func _initialize():run.call_deferred()
func open_cell(bits:PackedByteArray,size:Vector2i,x:int,z:int)->bool:
 if x<0 or z<0 or x>=size.x or z>=size.y:return false
 var i=z*size.x+x
 return (bits[i>>3]&(1<<(i&7)))!=0
func clear(bits:PackedByteArray,cell:Vector2i)->bool:
 for z in range(cell.y-1,cell.y+2):
  for x in range(cell.x-1,cell.x+2):
   if not open_cell(bits,Prayer.SIZE,x,z):return false
 return true
func run():
 var masks={}
 for seed_ in 32:
  var floor_masks={}
  for id:int in Prayer.FLOORS:
   var warp=Prayer.stairs(id,seed_)
   var bits=Prayer.walk_mask(id,seed_)
   check(bits==Prayer.walk_mask(id,seed_),"Backtracking preserves the floor")
   masks[bits]=true
   floor_masks[bits]=true
   var queue:Array[Vector2i]=[warp[0]]
   var seen={warp[0]:true}
   var i=0
   while i<queue.size():
    var at=queue[i]
    i+=1
    for direction:Vector2i in Prayer.DIRECTIONS:
     var next=at+direction
     if not seen.has(next) and clear(bits,next):
      seen[next]=true
      queue.append(next)
   check(seen.has(warp[1]),"Both stairs connect with three-tile-wide clearance")
   var open_count=0
   var connected={warp[0]:true}
   var cells:Array[Vector2i]=[warp[0]]
   i=0
   while i<cells.size():
    var at=cells[i];i+=1
    for d:Vector2i in Prayer.DIRECTIONS:
     var next=at+d
     if not connected.has(next) and open_cell(bits,Prayer.SIZE,next.x,next.y):
      connected[next]=true;cells.append(next)
   for z in Prayer.SIZE.y:
    for x in Prayer.SIZE.x:
     var opened=open_cell(bits,Prayer.SIZE,x,z)
     if opened:open_count+=1
     if x==0 or z==0 or x==Prayer.SIZE.x-1 or z==Prayer.SIZE.y-1:check(not opened,"The perimeter is sealed")
   check(connected.size()==open_count,"Every open cell is connected")
   var points={}
   var patrols=Prayer.patrols(id,seed_)
   check(patrols.size()==Prayer.PATROL_COUNT and patrols==Prayer.patrols(id,seed_),"All 96 enemy stations persist when revisiting a floor")
   var old_rng=Prayer.rng_for(id,seed_+641)
   for slot in 32:
    var center=Prayer.room_center(Vector2i((slot/2)%4,slot/8))
    var old=[Prayer.point(center+Vector2i(-1 if slot%2==0 else 1,0)),old_rng.randi_range(1,2),old_rng.randi_range(20,23)]
    check(patrols[slot]==old,"Existing death-ledger slots retain their position, species and level")
   for row in patrols:
    var cell=Vector2i((row[0]-Prayer.ORIGIN)/3.0)
    check(seen.has(cell) and row[1] in [1,2] and row[2]>=20 and row[2]<=23,"Native escorts spawn in reachable clear rooms at reference levels")
    check(not points.has(cell),"Enemy stations do not overlap")
    check(clear(bits,cell) and cell.distance_to(warp[0])>=3 and cell.distance_to(warp[1])>=3,"Enemy stations leave the stairs clear")
    points[cell]=true
   var links=Prayer.links(id,seed_)
   check(links.size()==2 and links[0].floor==(Prayer.ENTRY if id==Prayer.FLOORS[0] else id-1),"Upstairs returns to the preceding floor")
   check(links[1].floor==(Prayer.BOSS if id==Prayer.FLOORS.back() else id+1),"Downstairs advances exactly one floor")
  check(floor_masks.size()==6,"Each floor has its own layout")
 check(masks.size()==32*6,"All sampled floor seeds produce distinct layouts")
 check(not Prayer.owns(Prayer.BOSS),"The fixed original palace is independent of maze generation")
 print("BLACK_PRAYER_MAZE_RESULT seeds=32 floors=6 unique=",masks.size()," checks=",checks," failures=",failures)
 for frame in 2:await process_frame
 quit(1 if failures else 0)
