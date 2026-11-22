extends SceneTree
const Maze=preload("res://scripts/forest/forest_zombie_maze.gd")
const Data=preload("res://assets/maps/falan/freyja_destinations_data.gd")
var failures=0
func check(ok:bool,message:String):
 if not ok:
  failures+=1
  printerr("ZOMBIE_MAZE_FAIL ",message)
func open_cell(bits:PackedByteArray,size:Vector2i,x:int,z:int)->bool:
 if x<0 or z<0 or x>=size.x or z>=size.y:return false
 var i=z*size.x+x
 return (bits[i>>3] & (1<<(i&7)))!=0
func _initialize():
 run.call_deferred()
func run():
 var info=Data.ROOMS[Maze.ROOM]
 var size:Vector2i=info[0]
 var source:PackedByteArray=info[2].hex_decode()
 var masks={}
 for seed_ in range(100):
  var bits=Maze.walk_mask(size,source.duplicate(),seed_)
  check(bits==Maze.walk_mask(size,source.duplicate(),seed_),"Revisiting preserves seed "+str(seed_))
  masks[bits]=true
  var queue:Array[Vector2i]=[Vector2i(40,6)]
  var seen={queue[0]:true}
  var i=0
  while i<queue.size():
   var at=queue[i]
   i+=1
   for direction:Vector2i in Maze.Imur.DIRECTIONS:
    var next=at+direction
    if not seen.has(next) and open_cell(bits,size,next.x,next.y):
     seen[next]=true
     queue.append(next)
  check(seen.has(Vector2i(21,18)) and seen.has(Vector2i(21,27)),"The boss and exit are reachable")
  var unconnected=0
  for z in size.y:
   for x in size.x:
    var cell=Vector2i(x,z)
    var open=open_cell(bits,size,x,z)
    if open and not seen.has(cell):unconnected+=1
    if Maze.LAB.has_point(cell):check(open==open_cell(source,size,x,z),"The original laboratory stays intact")
    if x==0 or z==0 or x==size.x-1 or z==size.y-1:check(not open,"The cave perimeter stays closed")
  check(unconnected==0,"Every open cell connects to the entrance: "+str(unconnected))
  var patrols={}
  for slot in 9:
   var point=Maze.patrol_point(slot,seed_)
   var cell=Vector2i((point-info[1])/3.0)
   check(seen.has(cell) and not Maze.LAB.has_point(cell),"Patrols spawn in reachable passages")
   check(not patrols.has(cell),"Patrols are spread across different passages")
   patrols[cell]=true
 check(masks.size()>10,"New runs vary the passages")
 print("ZOMBIE_MAZE_RESULT seeds=100 unique=",masks.size()," failures=",failures)
 for frame in 2:await process_frame
 quit(1 if failures else 0)
