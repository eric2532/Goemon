extends RefCounted
## Client layouts with the reference dungeon's twelve floors and original stair cells.
const Art=preload("res://scripts/forest/forest_original_map_art.gd")
const FIRST=51201
const COUNT=12
const BOSS_ROOM=16511
const BOSS_CELL=Vector2i(26,25)
const BOSS_KEY="original:2820"
static var runs:Dictionary={}
static var formations:Dictionary={}

static func owns(id:int)->bool:return id>=FIRST and id<FIRST+COUNT

static func template(id:int,seed_:int)->Dictionary:
 assert(owns(id))
 if not runs.has(seed_):
  runs.clear();formations.clear()
  # Cache numbers identify visits, not floors; draw intact layouts without replacement.
  var bag:Array=Art.data().beast_templates.duplicate()
  var rng=RandomNumberGenerator.new();rng.seed=hash(Vector2i(seed_,14400))
  for i in range(bag.size()-1,0,-1):
   var j=rng.randi_range(0,i);var swap=bag[i];bag[i]=bag[j];bag[j]=swap
  runs[seed_]=bag.slice(0,COUNT)
 return runs[seed_][id-FIRST]

static func stair(id:int,seed_:int,up:bool)->Vector2i:
 var pair:Array=template(id,seed_).up if up else template(id,seed_).down
 return Vector2i(pair[0],pair[1])

static func creature_keys(id:int)->Array:
 return [BOSS_KEY] if id==BOSS_ROOM else Art.data().beast_encounters.patrols.map(func(row):return row[0]) if owns(id) else []

static func encounters(id:int,seed_:int=0)->Array:
 if id==BOSS_ROOM:return [[BOSS_CELL,BOSS_KEY,"神獸史雷普尼爾",50,true,0]]
 if not owns(id):return []
 var key=Vector2i(id,seed_)
 if formations.has(key):return formations[key]
 var Original=load("res://scripts/forest/forest_original_maps.gd")
 var row:Dictionary=Original.state(id,seed_)
 var up=stair(id,seed_,true);var down=stair(id,seed_,false)
 var queue=[up];var seen={up:true};var eligible=[]
 for cell:Vector2i in queue:
  for direction in [Vector2i.UP,Vector2i.DOWN,Vector2i.LEFT,Vector2i.RIGHT]:
   var next=cell+direction
   if not seen.has(next) and Original.open(row.bits,row.size,next):seen[next]=true;queue.append(next)
  if Vector2(cell-up).length_squared()<16 or Vector2(cell-down).length_squared()<16:continue
  if [Vector2i.UP,Vector2i.DOWN,Vector2i.LEFT,Vector2i.RIGHT].all(func(d):return Original.open(row.bits,row.size,cell+d)):eligible.append(cell)
 var patrols:Array=Art.data().beast_encounters.patrols
 var levels:Array=Art.data().beast_encounters.levels
 var count_=mini(24,eligible.size());count_-=count_%patrols.size()
 assert(count_>0,"Original maze needs reachable encounter ground")
 var result=[]
 for i in count_:
  var species:Array=patrols[i%patrols.size()]
  result.append([eligible[(i*eligible.size()+eligible.size()/2)/count_],species[0],species[1],int(levels[0])+(i/2)%(int(levels[1])-int(levels[0])+1),false,i])
 formations[key]=result
 return result
