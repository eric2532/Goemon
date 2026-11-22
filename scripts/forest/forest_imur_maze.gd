extends RefCounted

const FLOORS=[47040,47041,47042,47043]
const GRID=Vector2i(5,4)
const DIRECTIONS=[Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]
const ENTRY=Vector2i(5,19)
const EXIT=Vector2i(24,7)

static func walk_mask(size:Vector2i,id:int,run_seed:int)->PackedByteArray:
 var rng=RandomNumberGenerator.new()
 rng.seed=hash(Vector2i(run_seed,id))
 var bits=PackedByteArray()
 bits.resize((size.x*size.y+7)>>3)
 var visited={}
 var stack:Array[Vector2i]=[Vector2i(0,3)]
 visited[stack[0]]=true
 carve(bits,size,ENTRY,Vector2i(4,19))
 carve(bits,size,Vector2i(24,9),EXIT)
 # A spanning tree keeps the exit reachable and gives the extra branches dead ends.
 while not stack.is_empty():
  var cell:Vector2i=stack.back()
  var options:Array[Vector2i]=[]
  for direction:Vector2i in DIRECTIONS:
   var next=cell+direction
   if next.x>=0 and next.y>=0 and next.x<GRID.x and next.y<GRID.y and not visited.has(next):
    options.append(next)
  if options.is_empty():
   stack.pop_back()
   continue
  var next=options[rng.randi_range(0,options.size()-1)]
  carve(bits,size,Vector2i(4,4)+cell*5,Vector2i(4,4)+next*5)
  visited[next]=true
  stack.append(next)
 return bits

static func carve(bits:PackedByteArray,size:Vector2i,from:Vector2i,to:Vector2i):
 for z in range(mini(from.y,to.y)-1,maxi(from.y,to.y)+2):
  for x in range(mini(from.x,to.x)-1,maxi(from.x,to.x)+2):
   var i=z*size.x+x
   bits[i>>3]|=1<<(i&7)
