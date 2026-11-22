extends RefCounted
## Six seeded Black Prayer floors; the original entrance and Ruby palace are fixed rooms.
const Data=preload("res://assets/maps/falan/black_prayer/data.gd")
const Imur=preload("res://scripts/forest/forest_imur_maze.gd")
const ENTRY=16507
const BOSS=16508
# Runtime identities stay independent of the client's changing maze-cache filenames.
const FLOORS=[30101,30102,30103,30104,30105,30106]
const SIZE=Vector2i(64,64)
const ORIGIN=Vector2(-96,-96)
const SLAIN=&"black_prayer_slain"
const PATROL_COUNT=96
const DIRECTIONS=Imur.DIRECTIONS

static func owns(id:int)->bool:return id==ENTRY or id in FLOORS
static func floor_info(id:int)->Array:
 return Data.ENTRANCE if id==ENTRY else [SIZE,ORIGIN,"00".repeat((SIZE.x*SIZE.y+7)>>3)]
static func title(id:int)->String:
 return "黑色的祈禱 · Entrance" if id==ENTRY else "黑色的祈禱 · B%dF"%(FLOORS.find(id)+1)
static func point(cell:Vector2i)->Vector2:return ORIGIN+Vector2(cell)*3.0
static func room_center(cell:Vector2i)->Vector2i:return Vector2i(9,9)+cell*14
static func rng_for(id:int,run_seed:int)->RandomNumberGenerator:
 var rng=RandomNumberGenerator.new()
 rng.seed=hash(Vector2i(run_seed,id))
 return rng

static func stairs(id:int,run_seed:int)->Array[Vector2i]:
 var rng=rng_for(id,run_seed+311)
 var first=rng.randi_range(0,15)
 var last=(first+8)%16
 return [room_center(Vector2i(first%4,first/4))+Vector2i(0,4),
  room_center(Vector2i(last%4,last/4))+Vector2i(4,0)]

static func walk_mask(id:int,run_seed:int)->PackedByteArray:
 # shortcut: original server maze code is unavailable; reproduce its six-floor room and material contract.
 var rng=rng_for(id,run_seed)
 var bits=PackedByteArray()
 bits.resize((SIZE.x*SIZE.y+7)>>3)
 var stack:Array[Vector2i]=[Vector2i(0,3)]
 var seen={stack[0]:true}
 for z in 4:
  for x in 4:
   var center=room_center(Vector2i(x,z))
   var radius=Vector2i(rng.randi_range(2,4),rng.randi_range(2,4))
   for row in range(center.y-radius.y,center.y+radius.y+1):
    Imur.carve(bits,SIZE,Vector2i(center.x-radius.x,row),Vector2i(center.x+radius.x,row))
 while not stack.is_empty():
  var cell:Vector2i=stack.back()
  var choices:Array[Vector2i]=[]
  for direction:Vector2i in DIRECTIONS:
   var next=cell+direction
   if Rect2i(0,0,4,4).has_point(next) and not seen.has(next):choices.append(next)
  if choices.is_empty():
   stack.pop_back()
   continue
  var next:Vector2i=choices[rng.randi_range(0,choices.size()-1)]
  Imur.carve(bits,SIZE,room_center(cell),room_center(next))
  seen[next]=true
  stack.append(next)
 var warp=stairs(id,run_seed)
 Imur.carve(bits,SIZE,warp[0],warp[0]-Vector2i(0,4))
 Imur.carve(bits,SIZE,warp[1]-Vector2i(4,0),warp[1])
 return bits

static func patrols(id:int,run_seed:int)->Array:
 var rows=[]
 var rng=rng_for(id,run_seed+641)
 for z in 4:
  for x in 4:
   var center=room_center(Vector2i(x,z))
   for offset:Vector2i in [Vector2i(-1,0),Vector2i(1,0)]:
    rows.append([point(center+offset),rng.randi_range(1,2),rng.randi_range(20,23)])
 # Append reinforcements so existing death-ledger slots keep their original identity.
 for z in 4:
  for x in 4:
   var center=room_center(Vector2i(x,z))
   for offset:Vector2i in [Vector2i(-1,-1),Vector2i(1,-1),Vector2i(-1,1),Vector2i(1,1)]:
    rows.append([point(center+offset),rng.randi_range(1,2),rng.randi_range(20,23)])
 return rows

static func links(id:int,run_seed:int)->Array:
 if id==ENTRY:
  return [door(Vector2(-9,-18),15003,Vector2(12,-66),"Suspicious Rock"),
   door(Vector2(12,12),FLOORS[0],point(stairs(FLOORS[0],run_seed)[0]+Vector2i.UP),title(FLOORS[0]))]
 if id==BOSS:return [door(Vector2(42,-60),FLOORS.back(),point(stairs(FLOORS.back(),run_seed)[1]+Vector2i.LEFT),title(FLOORS.back()))]
 var index=FLOORS.find(id)
 if index<0:return []
 var warp=stairs(id,run_seed)
 return [door(point(warp[0]),ENTRY if index==0 else FLOORS[index-1],Vector2(12,9) if index==0 else point(stairs(FLOORS[index-1],run_seed)[1]+Vector2i.LEFT),"Up · "+("Entrance" if index==0 else title(FLOORS[index-1]))),
  door(point(warp[1]),BOSS if index==FLOORS.size()-1 else FLOORS[index+1],Vector2(42,-57) if index==FLOORS.size()-1 else point(stairs(FLOORS[index+1],run_seed)[0]+Vector2i.UP),"Down · "+("露比 · Ruby's Palace" if index==FLOORS.size()-1 else title(FLOORS[index+1])))]

static func door(at:Vector2,target:int,arrival:Vector2,caption:String)->Dictionary:
 return {"at":at,"to":"freyja_door","floor":target,"arrival":arrival,"caption":caption,"door":true}
