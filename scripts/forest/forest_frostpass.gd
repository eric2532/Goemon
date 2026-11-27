extends RefCounted
## The western road continues from Falan to the snowy towns and the mountain.
const Recovered=preload("res://scripts/forest/forest_original_maps.gd")
const Maze=preload("res://scripts/forest/forest_falken_route.gd")
const Imur=preload("res://scripts/forest/forest_imur_maze.gd")
const Decree=preload("res://scripts/forest/forest_holy_decree.gd")
const SLAIN="frostpass_slain"
const TRAIL=51008
const SNOW_CAVE=51009
const ICE_VAULT=51010
const SNOW_FLOORS=[SNOW_CAVE,ICE_VAULT]
const SNOW_CREATURE_KEYS=["original:2823","original:2821"]
const SNOW_PATROLS=36
const ABANIS=51011
const UNIVERSITY=51012
const ABANIS_HALL=51013
const STUDY_HALL=51014
const COAST_ROAD=51015
const WORKSHOP=51016
const GLASSHOUSE=51017
const ABANIS_HOSPITAL=51018
const AUDITORIUM=51019
const ROOF_GARDEN=51020
const ROOF_STAIRS={STUDY_HALL:Vector2(6,-9),AUDITORIUM:Vector2(15,9)}
const ROOF_LANDINGS={STUDY_HALL:Vector2(-15,12),AUDITORIUM:Vector2(15,12)}
const MAIN_ROUTE=[51001,51002,51003,51004,51005,ABANIS,TRAIL,SNOW_CAVE,ICE_VAULT]
const LEVELS={51001:Vector2i(36,38),51002:Vector2i(39,41),51003:Vector2i(42,44),
 SNOW_CAVE:Vector2i(39,42),ICE_VAULT:Vector2i(39,42)}
const TRAIL_GRADE={"ax":0,"az":7,"bx":0,"bz":-7,"width":7,"h0":0,"h1":12.6}
const MARKET=51006
const HALL=51007
const MAIN_LOT=2
const TOWN_BUILDINGS={51004:MARKET,51005:HALL,ABANIS:ABANIS_HALL,UNIVERSITY:STUDY_HALL}
const VILLAGE_ROOMS={MAIN_LOT:ABANIS_HALL,5:ABANIS_HOSPITAL}
const CAMPUS_ROOMS={0:WORKSHOP,1:GLASSHOUSE,MAIN_LOT:STUDY_HALL,3:AUDITORIUM}
const COAST_PATH=[Vector2i(26,23),Vector2i(26,17),Vector2i(18,17),Vector2i(18,12),
 Vector2i(11,10),Vector2i(9,6),Vector2i(9,3)]
const ABANIS_STREETS=[Rect2i(6,21,21,3),Rect2i(4,3,3,19),Rect2i(6,14,21,2),
 Rect2i(26,12,2,10),Rect2i(6,8,15,2),Rect2i(17,9,3,6)]
const UNIVERSITY_WALKS=[Rect2i(14,10,6,13),Rect2i(9,16,17,3),Rect2i(23,17,3,7),
 Rect2i(10,12,4,2),Rect2i(20,13,4,2),Rect2i(9,18,3,4)]
const TITLES={
 51001:"莎蓮娜海底洞窟 · 地下1樓",
 51002:"莎蓮娜海底洞窟 · 地下2樓",
 51003:"莎蓮娜海底洞窟 · 地下1樓（莎蓮娜側）",
 51004:"傑諾瓦鎮",
 51005:"蒂娜村",
 MARKET:"Snowpine Market",
 HALL:"Ridgewatch Hall",
 TRAIL:"雪山山路 · Snow Mountain Trail",
 SNOW_CAVE:"雪山 · Glacier Cavern",
 ICE_VAULT:"雪山深處 · Ice Vault",
 ABANIS:"阿巴尼斯村 · Abanis",
 UNIVERSITY:"魔法大學 · Magic University",
 ABANIS_HALL:"阿巴尼斯村 · Village Hall",
 STUDY_HALL:"魔法大學 · Study Hall",
 COAST_ROAD:"莎蓮娜海岸 · University Road",
 WORKSHOP:"魔法大學 · 技術室",
 GLASSHOUSE:"魔法大學 · 溫室",
 ABANIS_HOSPITAL:"阿巴尼斯村 · 醫院",
 AUDITORIUM:"魔法大學 · 禮堂",
 ROOF_GARDEN:"魔法大學 · 屋頂花園",
}
const TRAILHEAD=Vector2(33,-45)
const SIZE=Vector2i(33,27)
const ORIGIN=Vector2(-48,-39)
const ROOMS={
 51001:[Rect2i(5,18,9,7),Rect2i(7,15,5,5),Rect2i(3,8,13,10),Rect2i(13,10,12,5),
  Rect2i(19,5,11,14),Rect2i(23,1,5,7),Rect2i(6,4,8,6),Rect2i(11,5,10,4)],
 51002:[Rect2i(21,1,8,7),Rect2i(19,5,7,17),Rect2i(6,16,23,7),Rect2i(1,20,8,5),
  Rect2i(3,4,10,17),Rect2i(10,5,13,5),Rect2i(10,12,12,5)],
 51003:[Rect2i(1,19,8,6),Rect2i(5,16,16,6),Rect2i(13,7,16,14),Rect2i(23,1,6,9),
  Rect2i(4,3,8,13),Rect2i(8,5,16,6),Rect2i(6,13,10,6),Rect2i(24,19,7,5)],
 51004:[Rect2i(3,2,28,23)],
 51005:[Rect2i(2,2,29,23)],
 ABANIS:[Rect2i(3,2,27,23)],
 UNIVERSITY:[Rect2i(2,2,29,23)],
 COAST_ROAD:[Rect2i(23,16,6,9),Rect2i(17,15,12,5),Rect2i(15,10,6,10),
  Rect2i(9,8,12,6),Rect2i(6,2,7,10)],
 TRAIL:[Rect2i(14,21,5,4),Rect2i(10,19,9,4),Rect2i(10,13,5,8),Rect2i(10,12,13,4),
  Rect2i(19,6,4,9),Rect2i(13,5,10,4),Rect2i(13,1,5,6)],
}
const ROCKS={
 51001:[Rect2i(6,11,4,3),Rect2i(23,9,3,5)],
 51002:[Rect2i(7,9,3,5),Rect2i(16,18,4,2),Rect2i(21,10,2,4)],
 51003:[Rect2i(18,11,5,5),Rect2i(8,8,2,3),Rect2i(25,15,2,2)],
}
## House footprints are removed from the same mask the player and army use.
const HOUSES={
 51004:[Rect2i(5,6,4,3),Rect2i(13,6,4,3),Rect2i(21,7,5,4),Rect2i(6,16,4,3),
  Rect2i(15,16,4,3),Rect2i(24,16,4,3)],
 51005:[Rect2i(4,12,4,4),Rect2i(10,5,4,4),Rect2i(13,13,6,4),Rect2i(20,5,4,4),
  Rect2i(23,16,5,4),Rect2i(25,10,4,3)],
 ABANIS:[Rect2i(8,4,4,4),Rect2i(21,7,5,5),Rect2i(10,10,6,4),
  Rect2i(7,16,4,3),Rect2i(15,16,4,4),Rect2i(20,17,5,3)],
 UNIVERSITY:[Rect2i(5,9,5,6),Rect2i(24,9,5,5),Rect2i(12,5,9,5),
  Rect2i(5,18,5,3),Rect2i(25,17,4,3)],
}
const HALL_PLAN={"size":Vector2i(11,9),"origin":Vector2(-15,-12),"fixtures":{
 "hearth":Rect2i(4,0,3,1),"left_table":Rect2i(1,3,2,3),"right_table":Rect2i(8,3,2,3),"records":Rect2i(9,0,2,1),
 "provisions":Rect2i(10,7,1,2)}}
const INTERIORS={
 MARKET:{"size":Vector2i(9,8),"origin":Vector2(-12,-12),"fixtures":{
  "produce":Rect2i(1,1,2,1),"counter":Rect2i(5,2,3,1),"cupboard":Rect2i(6,0,2,1),"stock":Rect2i(0,5,1,2),
  "sundries":Rect2i(0,3,1,1),"display":Rect2i(7,5,1,1)}},
 HALL:HALL_PLAN,ABANIS_HALL:HALL_PLAN,STUDY_HALL:HALL_PLAN,
 WORKSHOP:{"size":Vector2i(11,9),"origin":Vector2(-15,-12),"fixtures":{
  "bench":Rect2i(1,2,2,4),"cases":Rect2i(8,2,2,4),"cabinet":Rect2i(4,0,3,1)}},
 GLASSHOUSE:{"size":Vector2i(11,9),"origin":Vector2(-15,-12),"fixtures":{
  "west_bed":Rect2i(1,2,2,4),"east_bed":Rect2i(8,2,2,4),"potting":Rect2i(4,0,3,1)}},
 ABANIS_HOSPITAL:{"size":Vector2i(11,9),"origin":Vector2(-15,-12),"fixtures":{
  "ward":Rect2i(1,2,2,4),"counter":Rect2i(8,3,2,3),"cabinet":Rect2i(4,0,3,1)}},
 AUDITORIUM:{"size":Vector2i(13,10),"origin":Vector2(-18,-15),"fixtures":{
  "stage":Rect2i(2,0,9,2),"west_seats":Rect2i(1,3,4,4),"east_seats":Rect2i(8,3,4,4)}},
 ROOF_GARDEN:{"size":Vector2i(15,11),"origin":Vector2(-21,-15),"fixtures":{
  "west_flowers":Rect2i(2,2,3,3),"east_melons":Rect2i(10,2,3,3),
  "west_herbs":Rect2i(3,6,2,2),"east_vines":Rect2i(10,6,2,2),
  "west_stair":Rect2i(2,10,1,1),"east_stair":Rect2i(12,10,1,1)}},
}
const DOORS={
 51001:[Vector2i(8,23),Vector2i(25,2)],
 51002:[Vector2i(25,2),Vector2i(4,23)],
 51003:[Vector2i(4,23),Vector2i(25,2)],
 51004:[Vector2i(10,23),Vector2i(24,3)],
 51005:[Vector2i(16,23),Vector2i(16,3)],
 ABANIS:[Vector2i(24,23),Vector2i(8,23),Vector2i(5,3)],
 UNIVERSITY:[Vector2i(24,23)],
 COAST_ROAD:[Vector2i(26,23),Vector2i(9,3)],
 TRAIL:[Vector2i(16,24),Vector2i(15,2)],
 SNOW_CAVE:[Vector2i(15,23),Vector2i(25,2)],
 ICE_VAULT:[Vector2i(25,2),Vector2i(15,23)],
}
const ARRIVALS={
 51001:[Vector2i(8,21),Vector2i(25,4)],
 51002:[Vector2i(25,4),Vector2i(4,21)],
 51003:[Vector2i(4,21),Vector2i(25,4)],
 51004:[Vector2i(11,21),Vector2i(24,5)],
 51005:[Vector2i(16,21),Vector2i(16,5)],
 ABANIS:[Vector2i(24,21),Vector2i(8,21),Vector2i(5,5)],
 UNIVERSITY:[Vector2i(24,21)],
 COAST_ROAD:[Vector2i(26,21),Vector2i(9,5)],
 TRAIL:[Vector2i(16,22),Vector2i(15,4)],
 SNOW_CAVE:[Vector2i(15,21),Vector2i(25,4)],
 ICE_VAULT:[Vector2i(25,4)],
}
static var snow_mazes={}

static func point(cell:Vector2i,id:int=0)->Vector2:
 return Recovered.point(id,cell) if Recovered.owns(id) else ORIGIN+Vector2(cell)*3.0

static func creature_keys(id:int)->Array:
 if id==Recovered.Beast.BOSS_ROOM or Recovered.Beast.owns(id):return Recovered.Beast.creature_keys(id)
 if Recovered.generated().branch(id)=="mountain":return SNOW_CREATURE_KEYS
 return SNOW_CREATURE_KEYS if id in SNOW_FLOORS else Decree.creature_keys(id)

static func trail_height(z:float)->float:
 return remap(z,TRAIL_GRADE.az*6.0,TRAIL_GRADE.bz*6.0,TRAIL_GRADE.h0,TRAIL_GRADE.h1)

static func floor_info(id:int,run_seed:int=0)->Array:
 if Recovered.owns(id):return Recovered.floor_info(id,run_seed)
 return legacy_floor_info(id)

static func legacy_floor_info(id:int)->Array:
 if id in SNOW_FLOORS:return [SIZE,ORIGIN,"00".repeat((SIZE.x*SIZE.y+7)>>3)]
 var interior:Dictionary=INTERIORS.get(id,{})
 var size:Vector2i=interior.get("size",SIZE)
 var origin:Vector2=interior.get("origin",ORIGIN)
 var rooms:Array=ROOMS.get(id,[Rect2i(Vector2i.ZERO,size)])
 var blocked:Array=ROCKS.get(id,HOUSES.get(id,interior.get("fixtures",{}).values()))
 var bits=PackedByteArray()
 bits.resize((size.x*size.y+7)>>3)
 for z in size.y:
  for x in size.x:
   var cell=Vector2i(x,z)
   if not rooms.any(func(room):return room.has_point(cell)):continue
   if blocked.any(func(rect):return rect.has_point(cell)):continue
   var index=z*size.x+x
   bits[index>>3]|=1<<(index&7)
 return [size,origin,bits.hex_encode()]

static func snow_maze(id:int,run_seed:int)->Dictionary:
 if snow_mazes.has(id) and snow_mazes[id].seed==run_seed:return snow_mazes[id]
 var generated=grid_maze(id,run_seed,SIZE,DOORS[id],SNOW_PATROLS)
 snow_mazes[id]=generated
 return generated

static func grid_maze(id:int,run_seed:int,size_:Vector2i,doors_:Array,count_:int)->Dictionary:
 var rng=Maze.rng_for(id,run_seed)
 var bits=PackedByteArray()
 bits.resize((size_.x*size_.y+7)>>3)
 var rooms:Array[Vector2i]=[]
 var widths=Maze.shuffled([3,4,4,4,4,4,4,4,4],rng)
 var heights=Maze.shuffled([2,3,3,3,3,3,3,3,3],rng)
 var x_shift:int=Maze.shuffled([-1,0,1],rng)[0]
 var z_shift:int=Maze.shuffled([-1,0,1],rng)[0]
 var links:Array[Vector2i]=[]
 for z in 3:
  for x in 3:
   var index=z*3+x
   var center=Vector2i(Vector2(6+x*10+x_shift,5+z*8+z_shift)*Vector2(size_)/Vector2(SIZE))
   rooms.append(center)
   var radius=Vector2i(Vector2(widths[index],heights[index])*Vector2(size_)/Vector2(SIZE))
   for row in range(center.y-radius.y,center.y+radius.y+1):
    for col in range(center.x-radius.x,center.x+radius.x+1):
     var cell=row*size_.x+col
     bits[cell>>3]|=1<<(cell&7)
   if x<2:links.append(Vector2i(index,index+1))
   if z<2:links.append(Vector2i(index,index+3))
 # Join all chambers and keep one loop so a branch can reconnect.
 var groups=range(9)
 var has_loop=false
 for link:Vector2i in Maze.shuffled(links,rng):
  var first:int=groups[link.x]
  var last:int=groups[link.y]
  if first==last:
   if has_loop:continue
   has_loop=true
  else:
   for i in groups.size():
    if groups[i]==last:groups[i]=first
  Imur.carve(bits,size_,rooms[link.x],rooms[link.y])
 for door_cell:Vector2i in doors_:
  var room=rooms[2 if door_cell.y<9 else 7]
  var bend=Vector2i(door_cell.x,room.y)
  Imur.carve(bits,size_,door_cell,bend)
  Imur.carve(bits,size_,bend,room)
 var rocks:Array[Rect2i]=[]
 var islands=Maze.shuffled([0,1,3,4,5,6,8],rng)
 var footprints=Maze.shuffled([Vector2i(2,2),Vector2i(3,2),Vector2i(2,3)],rng)
 for i in footprints.size():
  # Each island leaves a continuous walking ring inside its chamber.
  var rock=Rect2i(rooms[islands[i]]-Vector2i.ONE,footprints[i])
  rocks.append(rock)
  for z in range(rock.position.y,rock.end.y):
   for x in range(rock.position.x,rock.end.x):
    var cell=z*size_.x+x
    bits[cell>>3]&=255^(1<<(cell&7))
 var posts:Array[Vector2i]=[]
 for stride in [2,1]:
  var eligible=patrol_grid(bits,size_,doors_,stride)
  for cell:Vector2i in Maze.shuffled(eligible,rng):
   if cell not in posts:posts.append(cell)
   if posts.size()==count_:break
  if posts.size()==count_:break
 var generated={"seed":run_seed,"bits":bits,"rocks":rocks,"posts":posts}
 return generated

static func building_door(town:int,lot_index:int=MAIN_LOT)->Vector2:
 var lot:Rect2i=HOUSES[town][lot_index]
 return point(Vector2i(lot.position.x,lot.end.y))+Vector2((lot.size.x-1)*1.5,0)

static func building_exit(id:int)->Vector2:
 return Vector2(0,INTERIORS[id].origin.y+(INTERIORS[id].size.y-1)*3.0)

static func links(area:String,id:int,run_seed:int=0)->Array:
 if area=="west_lakes":
  return [Recovered.door(TRAILHEAD,51001,Recovered.source_point(51001,Vector2i(22,32)),"莎蓮娜海底洞窟 · 通往莎蓮娜")]
 if area=="interior" and Recovered.owns(id):return Recovered.links(id,run_seed)
 if area=="interior" and Decree.owns(id):
  return Decree.links(id,ABANIS,building_door(ABANIS,Decree.HOUSE_LOT))
 if area!="interior" or not TITLES.has(id):return []
 if id==ROOF_GARDEN:
  var stairs=[]
  for hall:int in ROOF_LANDINGS:
   stairs.append({"at":ROOF_LANDINGS[hall],"to":"freyja_door","floor":hall,
    "arrival":ROOF_STAIRS[hall]+Vector2(0,3),"caption":TITLES[hall],"door":true})
  return stairs
 if INTERIORS.has(id):
  var town:int
  var index:int=MAIN_LOT
  if CAMPUS_ROOMS.values().has(id):
   town=UNIVERSITY
   index=CAMPUS_ROOMS.find_key(id)
  elif VILLAGE_ROOMS.values().has(id):
   town=ABANIS
   index=VILLAGE_ROOMS.find_key(id)
  else:town=TOWN_BUILDINGS.find_key(id)
  var rows=[{"at":building_exit(id),"to":"freyja_door","floor":town,"arrival":building_door(town,index)+Vector2(0,3),
   "caption":TITLES[town],"door":true}]
  if ROOF_STAIRS.has(id):
   rows.append({"at":ROOF_STAIRS[id],"to":"freyja_door","floor":ROOF_GARDEN,
    "arrival":ROOF_LANDINGS[id]-Vector2(0,3),"caption":TITLES[ROOF_GARDEN],"door":true})
  return rows
 if id==COAST_ROAD:
  return [door(point(DOORS[id][0]),ABANIS,2,TITLES[ABANIS]),
   door(point(DOORS[id][1]),UNIVERSITY,0,TITLES[UNIVERSITY])]
 var index=MAIN_ROUTE.find(id)
 var back=point(DOORS[id][0])
 var rows=[]
 if id==51001:
  rows.append({"at":back,"to":"freyja_outside","area":"west_lakes","arrival":TRAILHEAD+Vector2(0,9),
   "caption":"Western Lakes","door":true})
 elif id==UNIVERSITY:
  rows.append(door(back,COAST_ROAD,1,TITLES[COAST_ROAD]))
 else:
  var previous:int=MAIN_ROUTE[index-1]
  rows.append(door(back,previous,1,TITLES[previous]))
 if index>=0 and index+1<MAIN_ROUTE.size():
  var next:int=MAIN_ROUTE[index+1]
  rows.append(door(point(DOORS[id][1]),next,0,TITLES[next]))
 if id==ABANIS:
  rows.append(door(point(DOORS[id][2]),COAST_ROAD,0,TITLES[COAST_ROAD]))
  rows.append_array(Decree.links(id,ABANIS,building_door(ABANIS,Decree.HOUSE_LOT)))
 if TOWN_BUILDINGS.has(id):
  var buildings:Dictionary=CAMPUS_ROOMS if id==UNIVERSITY else VILLAGE_ROOMS if id==ABANIS else {MAIN_LOT:TOWN_BUILDINGS[id]}
  for lot_index:int in buildings:
   var inside:int=buildings[lot_index]
   rows.append({"at":building_door(id,lot_index),"to":"freyja_door","floor":inside,"arrival":building_exit(inside)-Vector2(0,3),
    "caption":TITLES[inside],"door":true})
 return rows

static func door(at:Vector2,target:int,side:int,caption:String)->Dictionary:
 return {"at":at,"to":"freyja_door","floor":target,"arrival":point(ARRIVALS[target][side]),
  "caption":caption,"door":true}

static func patrols(id:int,run_seed:int=0)->Array[Vector2i]:
 if Recovered.generated().owns(id):
  var posts:Array[Vector2i]=[];posts.assign(Recovered.patrols(id,run_seed,SNOW_PATROLS));return posts
 if Recovered.owns(id):
  var posts:Array[Vector2i]=[]
  posts.assign(Recovered.patrols(id,run_seed,patrol_cells(id,legacy_floor_info(id)[2].hex_decode(),3).size()))
  return posts
 return patrol_cells(id,floor_info(id)[2].hex_decode(),3)

static func patrol_cells(id:int,bits:PackedByteArray,stride:int)->Array[Vector2i]:
 return patrol_grid(bits,SIZE,DOORS[id],stride)

static func patrol_grid(bits:PackedByteArray,size_:Vector2i,doors_:Array,stride:int)->Array[Vector2i]:
 var result:Array[Vector2i]=[]
 for z in range(3,size_.y-2,stride):
  for x in range(3,size_.x-2,stride):
   var cell=Vector2i(x,z)
   if doors_.any(func(entry):return Vector2(cell-entry).length_squared()<18.0):continue
   var center=z*size_.x+x
   var open=true
   for i in [center,center-1,center+1,center-size_.x,center+size_.x]:
    if (bits[i>>3] & (1<<(i&7)))==0:
     open=false
     break
   if open:result.append(cell)
 return result
