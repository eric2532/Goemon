extends RefCounted
## Native fixed rooms and the recovered sixteen-floor random tower contract.
const Data=preload("res://assets/maps/falan/falken/data.gd")
const ROOM=23001
const BOSS_CELL=Vector2i(23,20)
const SLAIN=&"falken_route_slain"
const ANCIENT_CELLS=[Vector2i(579,275),Vector2i(514,337),Vector2i(593,332)]
const ANCIENT=Vector2(540,350)*3.0 # Preserved compatibility return point; source entry actors use ANCIENT_CELLS.
const FLOORS=[30201,30202,30203,30204,30205,30206,30207,30208,30209,30210,30211,30212,30213,30214,30215,30216]
const SCROLL=&"falken_uncurse_scroll"
const Imur=preload("res://scripts/forest/forest_imur_maze.gd")
const TITLES={3300:"沒落的村莊",3301:"連接時空的房間",23000:"古代帝都 · 勇者里雍",23003:"帝都地下 · 羅連斯研究塔入口",23001:"法爾肯的結界",23002:"法爾肯 · 解放的宮殿"}
const LINKS={
 3300:[[Vector2i(40,39),3301,Vector2i(4,4),"連接時空的房間"]],
 3301:[[Vector2i(4,3),3300,Vector2i(40,38),"沒落的村莊"],
       [Vector2i(12,10),23000,Vector2i(21,20),"時空石盤 · 勇者里雍"]],
 23000:[[Vector2i(21,21),3301,Vector2i(12,12),"返回時空石盤"],
        [Vector2i(35,21),23003,Vector2i(40,21),"反抗軍 · 通往羅連斯研究塔"]],
 23003:[[Vector2i(40,21),23000,Vector2i(34,21),"反抗軍 · 返回里雍"]],
 23001:[[Vector2i(25,27),ROOM,Vector2i(23,23),"巫師耶卡 · 解開結界"],
        [Vector2i(23,24),ROOM,Vector2i(25,26),"返回巫師耶卡"]],
 23002:[],
}
static var mazes={}
static func owns(id:int)->bool:return Data.ROOMS.has(id) or id in FLOORS
static func title(id:int)->String:return "羅連斯研究塔 · %d樓"%(FLOORS.find(id)+1) if id in FLOORS else TITLES[id]
static func shuffled(values:Array,rng:RandomNumberGenerator)->Array:
 var bag=values.duplicate()
 for i in range(bag.size()-1,0,-1):
  var j=rng.randi_range(0,i);var a=bag[i];bag[i]=bag[j];bag[j]=a
 return bag
static func rng_for(id:int,seed_:int)->RandomNumberGenerator:
 var rng=RandomNumberGenerator.new();rng.seed=hash(Vector2i(id,seed_));return rng
static func floor_info(id:int)->Array:
 if Data.ROOMS.has(id):return Data.ROOMS[id]
 var sizes=shuffled(range(40,81),rng_for(id,0));var size=Vector2i(sizes[0],sizes[1])
 return [size,-Vector2(size)*1.5,"00".repeat((size.x*size.y+7)>>3)]
static func point(id:int,cell:Vector2i)->Vector2:return floor_info(id)[1]+Vector2(cell)*3.0
static func maze(id:int,run_seed:int)->Dictionary:
 if mazes.has(id) and mazes[id].seed==run_seed:return mazes[id]
 var size:Vector2i=floor_info(id)[0];var rng=rng_for(id,run_seed)
 var bits=PackedByteArray();bits.resize((size.x*size.y+7)>>3)
 var centers=[];var radii=shuffled([2,3,4],rng);var order=shuffled(range(16),rng)
 for z in 4:
  for x in 4:
   var center=Vector2i((x+.5)*size.x/4,(z+.5)*size.y/4);centers.append(center)
   var radius:int=mini(radii[(x+z*4)%3],mini(mini(center.x-2,center.y-2),mini(size.x-center.x-3,size.y-center.y-3)))
   for row in range(center.y-radius,center.y+radius+1):Imur.carve(bits,size,Vector2i(center.x-radius,row),Vector2i(center.x+radius,row))
 var stack=[order[0]];var seen={order[0]:true}
 while not stack.is_empty():
  var current:int=stack.back();var choices=[]
  for step:Vector2i in shuffled(Array(Imur.DIRECTIONS),rng):
   var next=Vector2i(current%4,current/4)+step;var index=next.x+next.y*4
   if not Rect2i(0,0,4,4).has_point(next) or seen.has(index):continue
   choices.append(index)
  if choices.is_empty():stack.pop_back();continue
  var next:int=choices.pop_back();Imur.carve(bits,size,centers[current],centers[next]);seen[next]=true;stack.append(next)
 var stairs=[centers[order[0]],centers[order[8]]]
 var posts=[];var species=shuffled([1,2],rng);var levels=shuffled([22,23,24,25],rng)
 for i in centers.size():
  for offset:Vector2i in [Vector2i(-1,-1),Vector2i(1,-1),Vector2i(-1,1),Vector2i(1,1),Vector2i(0,2),Vector2i(2,0)]:
   var cell:Vector2i=centers[i]+offset
   if cell.distance_to(stairs[0])<2.5 or cell.distance_to(stairs[1])<2.5:continue
   posts.append([point(id,cell),species[posts.size()%2],levels[posts.size()%4]])
 mazes[id]={"seed":run_seed,"bits":bits,"stairs":stairs,"posts":posts};return mazes[id]
static func door(id:int,cell:Vector2i,target:int,arrival:Vector2,caption:String)->Dictionary:
 return {"at":point(id,cell),"to":"freyja_door","floor":target,"arrival":arrival,"caption":caption,"door":true}
static func links(area:String,id:int,frame:Transform2D,run_seed:int=0)->Array:
 var rows=[]
 if area in ["sokia_coast","sokia_desert","ghana_road","ghana_north_road"]:
  var regions=load("res://scripts/forest/forest_freyja_regions.gd")
  var scenery=load("res://scripts/forest/forest_sokia_scenery.gd")
  for cell in ANCIENT_CELLS:
   var at=regions.frame(area).inverse()*(Vector2(cell)*3.)
   if not scenery.bounds(area).has_point(at):continue
   rows.append({"at":at,"to":"freyja_site","site":3300,"kind":"cave",
    "arrival":point(3300,Vector2i(20,28)),"yaw":0.0,"caption":"古代人民 · 法爾肯之路（夜晚）","door":true,"falken_route":true})
 if not owns(id):return rows
 if id in FLOORS:
  var index=FLOORS.find(id);var stairs:Array=maze(id,run_seed).stairs
  rows.append(door(id,stairs[0],23003 if index==0 else FLOORS[index-1],point(23003,Vector2i(41,21)) if index==0 else point(FLOORS[index-1],maze(FLOORS[index-1],run_seed).stairs[1]+Vector2i.LEFT),"下樓"))
  rows.append(door(id,stairs[1],ROOM if index==15 else FLOORS[index+1],point(ROOM,Vector2i(23,45)) if index==15 else point(FLOORS[index+1],maze(FLOORS[index+1],run_seed).stairs[0]+Vector2i.RIGHT),"巫師耶卡 · 頂樓" if index==15 else "上樓 · "+title(FLOORS[index+1])))
  return rows
 for row in LINKS[id]:
  rows.append({"at":point(id,row[0]),"to":"freyja_door","floor":row[1],
   "arrival":point(row[1],row[2]),"caption":row[3],"door":true})
 if id==23000:rows.append({"at":point(id,Vector2i(21,18)),"to":"falken_scroll","caption":"勇者里雍 · 領取解咒之法","door":true})
 if id==23003:rows.append(door(id,Vector2i(42,21),FLOORS[0],point(FLOORS[0],maze(FLOORS[0],run_seed).stairs[0]+Vector2i.RIGHT),title(FLOORS[0])))
 if id==ROOM:
  rows.append(door(id,Vector2i(23,45),FLOORS.back(),point(FLOORS.back(),maze(FLOORS.back(),run_seed).stairs[1]+Vector2i.LEFT),"返回羅連斯研究塔16樓"))
  rows.append(door(id,Vector2i(23,17),23002,point(23002,Vector2i(23,20)),"法爾肯已敗 · 天書與出口"))
 if id==23002:rows.append({"at":point(id,Vector2i(37,11)),"to":"freyja_outside","area":"sokia_desert","arrival":frame.inverse()*(ANCIENT+Vector2(-9,0)),"caption":"連接時空的石盤 · 返回沙漠","door":true})
 if id==3300:
  rows.append({"at":point(id,Vector2i(11,26)),"to":"freyja_outside","area":"sokia_desert",
   "arrival":frame.inverse()*(ANCIENT+Vector2(-9,0)),"caption":"返回索奇亞沙漠","door":true})
 return rows
static func patrols(id:int,run_seed:int=0)->Array:
 if id in FLOORS:return maze(id,run_seed).posts
 var info:Array=Data.ROOMS[id];var size:Vector2i=info[0];var bits:String=info[2]
 var mask=bits.hex_decode();var rows=[]
 if id in [3301,23003,23002]:return rows
 var entry=Vector2i(11,26) if id==3300 else Vector2i(21,20) if id==23000 else Vector2i(23,20)
 var connected={entry:true};var queue=[entry]
 for cell:Vector2i in queue:
  for direction:Vector2i in [Vector2i.UP,Vector2i.RIGHT,Vector2i.DOWN,Vector2i.LEFT]:
   var next=cell+direction
   if connected.has(next) or not Rect2i(Vector2i.ZERO,size).has_point(next):continue
   var i=next.y*size.x+next.x
   if (mask[i>>3] & (1<<(i&7)))==0:continue
   connected[next]=true;queue.append(next)
 for z in range(4,size.y-3,4):
  for x in range(4,size.x-3,4):
   var cell=Vector2i(x,z)
   if not connected.has(cell):continue
   var clear=true
   for dz in range(-1,2):
    for dx in range(-1,2):
     var i=(z+dz)*size.x+x+dx
     if (mask[i>>3] & (1<<(i&7)))==0:clear=false
   if not clear:continue
   if LINKS[id].any(func(row):return cell.distance_to(row[0])<4.0):continue
   if id==ROOM and (cell.distance_to(Vector2i(23,20))<8.0 or cell.y<15):continue
   rows.append([point(id,cell),1+rows.size()%2])
   if rows.size()==32:return rows
 return rows
