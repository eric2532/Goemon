extends RefCounted
## Randomize the passages around the archived laboratory, once per run.
const ROOM=15505
const LAB=Rect2i(8,10,28,18)
const GRID=Vector2i(6,6)
const ORIGIN=Vector2i(4,4)
const SPACING=8
const Imur=preload("res://scripts/forest/forest_imur_maze.gd")

static func nodes()->Array[Vector2i]:
 var result:Array[Vector2i]=[]
 for z in GRID.y:
  for x in GRID.x:
   var cell=ORIGIN+Vector2i(x,z)*SPACING
   if not LAB.grow(2).has_point(cell):result.append(cell)
 return result

static func walk_mask(size:Vector2i,source:PackedByteArray,run_seed:int)->PackedByteArray:
 var rng=RandomNumberGenerator.new()
 rng.seed=hash(Vector2i(run_seed,ROOM))
 var bits=PackedByteArray()
 bits.resize(source.size())
 var available=nodes()
 var stack:Array[Vector2i]=[available[0]]
 var visited={stack[0]:true}
 while not stack.is_empty():
  var cell:Vector2i=stack.back()
  var choices:Array[Vector2i]=[]
  for direction:Vector2i in Imur.DIRECTIONS:
   var next=cell+direction*SPACING
   if next in available and not visited.has(next):choices.append(next)
  if choices.is_empty():
   stack.pop_back()
   continue
  var next=choices[rng.randi_range(0,choices.size()-1)]
  Imur.carve(bits,size,cell,next)
  visited[next]=true
  stack.append(next)
 # Keep the original diamond and the laboratory's southern doorway.
 Imur.carve(bits,size,Vector2i(40,6),Vector2i(44,6))
 Imur.carve(bits,size,Vector2i(44,6),Vector2i(44,4))
 Imur.carve(bits,size,Vector2i(4,8),Vector2i(44,8))
 for x in [8,14,34]:Imur.carve(bits,size,Vector2i(x,8),Vector2i(x,9))
 Imur.carve(bits,size,Vector2i(4,13),Vector2i(7,13))
 Imur.carve(bits,size,Vector2i(36,13),Vector2i(44,13))
 Imur.carve(bits,size,Vector2i(21,28),Vector2i(21,36))
 Imur.carve(bits,size,Vector2i(21,36),Vector2i(20,36))
 for z in range(LAB.position.y,LAB.end.y):
  for x in range(LAB.position.x,LAB.end.x):
   var i=z*size.x+x
   if source[i>>3] & (1<<(i&7)):bits[i>>3]|=1<<(i&7)
   else:bits[i>>3]&=~(1<<(i&7))
 return bits

static func patrol_point(index:int,run_seed:int)->Vector2:
 var points=nodes()
 points.erase(Vector2i(44,4))
 var rng=RandomNumberGenerator.new()
 rng.seed=hash(Vector2i(run_seed,ROOM+1))
 for i in range(points.size()-1,0,-1):
  var j=rng.randi_range(0,i)
  var swap=points[i]
  points[i]=points[j]
  points[j]=swap
 return Vector2(points[index%points.size()])*3.0-Vector2(75,75)
