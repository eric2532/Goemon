extends RefCounted

const Maze=preload("res://scripts/forest/forest_falken_route.gd")
const LOWER_LANDING=Rect2i(9,20,5,3)
const UPPER_LANDING=Rect2i(9,2,5,3)
const GUARDIAN_ARENA=Rect2i(4,2,15,7)
# Counts from the floor references: rubble, orbs, candles, reliefs and grilles.
const SCENERY={
 1: [8,0,0,3,1],
 2: [4,3,0,3,1],
 3: [6,0,2,6,0],
 4: [5,0,3,1,1],
 5: [5,2,0,1,1],
 6: [1,1,0,2,1],
 7: [5,1,0,0,1],
 8: [8,0,0,0,1],
 9: [3,0,2,1,1],
 11: [5,0,2,0,1],
 12: [7,0,0,0,1],
 13: [7,0,0,0,2],
 14: [6,0,0,0,1],
 15: [6,0,0,0,3],
 16: [3,0,0,0,2],
 17: [6,0,0,0,1],
 18: [4,0,4,0,2],
 19: [4,0,0,0,1],
 21: [0,0,0,0,1],
 22: [0,0,0,0,4],
 23: [0,0,0,0,1],
 24: [0,0,0,0,2],
 25: [0,0,0,0,1],
 26: [0,0,0,0,4],
 27: [0,0,0,0,4],
 28: [0,0,0,0,1],
 29: [0,0,0,0,0],
 31: [0,0,0,3,4],
 32: [0,0,0,3,1],
 33: [0,0,0,2,4],
 34: [0,0,0,2,1],
 35: [0,0,0,9,4],
 36: [0,0,0,5,1],
 37: [0,0,0,4,3],
 38: [0,0,0,5,2],
 39: [0,0,0,9,1],
 41: [0,0,0,0,1],
 42: [0,0,0,0,1],
 43: [0,0,0,1,1],
 44: [0,0,0,0,1],
 45: [0,0,0,0,1],
 46: [0,0,0,0,1],
 47: [0,0,0,0,1],
 48: [0,0,0,0,0],
 49: [0,0,0,0,0],
 51: [0,0,0,0,4],
 52: [0,0,0,0,3],
 53: [0,0,0,0,4],
 54: [0,0,0,0,4],
 55: [0,0,0,0,0],
 56: [0,0,0,0,4],
 57: [0,0,0,0,4],
 58: [0,0,0,0,4],
 59: [0,0,0,0,1],
}

static func generate(number:int,run_seed:int,size:Vector2i)->Dictionary:
 var rng=Maze.rng_for(number+24008,run_seed)
 var has_guardian=number%10==0
 var rooms:Array[Rect2i]=[LOWER_LANDING,GUARDIAN_ARENA if has_guardian else UPPER_LANDING]
 var grid_rows=2 if has_guardian else 3
 var centers:Array[Vector2i]=[]
 var links:Array[Vector2i]=[]
 var across=Maze.shuffled([-1,0,1],rng)
 var row_shift=Maze.shuffled([-1,0,1],rng)
 var widths=Maze.shuffled([1,1,1,2,2,2,2,2,2],rng)
 var depths=Maze.shuffled([1,1,2,2,2,2,2,2,2],rng)
 var floor_bounds=Rect2i(2,9 if has_guardian else 3,19,13 if has_guardian else 19)
 for row in grid_rows:
  for col in 3:
   var index=row*3+col
   var mid=Vector2i(4+col*7+across[col],(12 if has_guardian else 5)+row*7+row_shift[row])
   centers.append(mid)
   var radius=Vector2i(widths[index],depths[index])
   rooms.append(Rect2i(mid-radius,2*radius+Vector2i.ONE).intersection(floor_bounds))
   if col<2:links.append(Vector2i(index,index+1))
   if row<grid_rows-1:links.append(Vector2i(index,index+3))
 # A shuffled spanning tree guarantees a route. A small cycle budget keeps some alternate paths.
 var groups=range(centers.size())
 var cycles:int=Maze.shuffled([0,1,1,2],rng)[0]
 for link:Vector2i in Maze.shuffled(links,rng):
  var a:int=groups[link.x]
  var b:int=groups[link.y]
  if a==b:
   if cycles==0:continue
   cycles-=1
  else:
   for i in groups.size():
    if groups[i]==b:groups[i]=a
  passage(rooms,centers[link.x],centers[link.y])
 var gates=Maze.shuffled(range(3),rng)
 var bottom=centers[(grid_rows-1)*3+gates[0]]
 var top=centers[gates[1]]
 connect_landing(rooms,Vector2i(11,22),20,bottom)
 if has_guardian:
  var join=Vector2i(clampi(top.x,5,17),9)
  passage(rooms,top,Vector2i(join.x,top.y))
  passage(rooms,Vector2i(join.x,top.y),Vector2i(join.x,8))
 else:
  connect_landing(rooms,Vector2i(11,2),4,top)

 var bits=PackedByteArray()
 bits.resize((size.x*size.y+7)>>3)
 for room:Rect2i in rooms:
  for y in range(room.position.y,room.end.y):
   for x in range(room.position.x,room.end.x):
    var index=y*size.x+x
    bits[index>>3]|=1<<(index&7)
 var patrol_rooms=centers.filter(func(cell):
  return cell.distance_squared_to(Vector2i(11,20))>=9 and cell.distance_squared_to(Vector2i(11,4))>=9)
 var posts=Maze.shuffled(patrol_rooms,rng).slice(0,5 if has_guardian else 3)
 if has_guardian:posts.append_array([Vector2i(5,7),Vector2i(17,7)])
 return {"seed":run_seed,"bits":bits,"posts":posts}

static func connect_landing(rooms:Array[Rect2i],door:Vector2i,row:int,center:Vector2i):
 var turn=Vector2i(door.x,row)
 passage(rooms,door,turn)
 passage(rooms,turn,Vector2i(center.x,row))
 passage(rooms,Vector2i(center.x,row),center)

static func passage(rooms:Array[Rect2i],from:Vector2i,to:Vector2i):
 if from==to:return
 # Keep three tiles of clearance for the six-metre native navigation cells.
 if from.x==to.x:
  rooms.append(Rect2i(from.x-1,mini(from.y,to.y),3,absi(from.y-to.y)+1))
 else:
  rooms.append(Rect2i(mini(from.x,to.x),from.y-1,absi(from.x-to.x)+1,3))
