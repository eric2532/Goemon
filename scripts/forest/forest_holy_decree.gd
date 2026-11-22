extends RefCounted

const Recovered=preload("res://scripts/forest/forest_original_maps.gd")
const Corridors=preload("res://assets/maps/falan/holy_decree_corridors.gd")
const Encounters=preload("res://assets/maps/original_crossgate/maze_encounters.gd")
const HOUSE=51021
const CELLAR=51022
const PAST=51023
const WEST_ROAD=51024
const GUARDIAN_FLOORS=[51025,51026,51027,51028,51029,51030]
const CORRIDOR_BASE=51100
const FLOOR_COUNT=60
const TITLES={
 HOUSE:"阿巴尼斯村 · 歷史學家民家",CELLAR:"民家地下 · 時空石盤",PAST:"過去的阿巴尼斯 · 刀刃的碎片",
 WEST_ROAD:"莎蓮娜西路 · 鼓動的石盤",
 51025:"詛咒的迷宮 · 納帕",51026:"詛咒的迷宮 · 德爾麥",51027:"詛咒的迷宮 · 瑟貝塔",
 51028:"詛咒的迷宮 · 亞爾法",51029:"詛咒的迷宮 · 馬帝亞",51030:"詛咒的迷宮 · 雙王",
}
const HOUSE_LOT=0
const ABANIS_WEST_GATE=Vector2(-39,-3)
const BLADE="holy_decree_blade"
const COMPLETE="holy_decree_complete"
const SIZE=Vector2i(23,24)
const ORIGIN=Vector2(-33,-33)
const ROOM_EXIT=Vector2(0,12)
const ROOM_STAIRS=Vector2(-12,-9)
const RELIC=Vector2(0,-9)
const LOWER_DOOR=Vector2(0,33)
const UPPER_DOOR=Vector2(0,-27)
const ROAD_DISC=Vector2(-15,-18)
const LANDING=Vector2(0,27)
const UPPER_LANDING=Vector2(0,-21)
const LEVELS=Encounters.LEVELS
const PALETTES=["678775","947550","73938e","9a7c66","71678c","ae825a"]
const PATROLS=Encounters.PATROLS
const GUARDIANS=Encounters.GUARDIANS
const HOUSE_FURNITURE=[Vector2i(8,7),Vector2i(9,7),Vector2i(14,7),Vector2i(15,7),Vector2i(7,12),Vector2i(15,12)]
static var generated_floors={}

static func point(cell:Vector2i,id:int=0)->Vector2:
 return Recovered.point(id,cell) if Recovered.owns(id) else ORIGIN+Vector2(cell)*3.0

static func floor_number(id:int)->int:
 var guardian=GUARDIAN_FLOORS.find(id)
 if guardian>=0:return (guardian+1)*10
 var number=id-CORRIDOR_BASE
 return number if number>0 and number<FLOOR_COUNT and number%10!=0 else 0

static func floor_id(number:int)->int:
 assert(number>=1 and number<=FLOOR_COUNT)
 return GUARDIAN_FLOORS[number/10-1] if number%10==0 else CORRIDOR_BASE+number

static func section_index(id:int)->int:
 var number=floor_number(id)
 return (number-1)/10 if number>0 else -1

static func owns(id:int)->bool:
 return TITLES.has(id) or floor_number(id)>0

static func title(id:int)->String:
 var number=floor_number(id)
 if number==0:return TITLES.get(id,"")
 var label="詛咒的迷宮 · %dF"%number
 return label+" · "+TITLES[id].get_slice(" · ",1) if id in GUARDIAN_FLOORS else label

static func maze(id:int,run_seed:int)->Dictionary:
 if generated_floors.has(id):
  var cached:Dictionary=generated_floors[id].duplicate();cached.seed=run_seed
  return cached
 var row=Recovered.state(id,run_seed)
 var number=floor_number(id)
 var previous=Recovered.SHALENA_NORTH if number==1 else floor_id(number-1)
 var entries=Recovered.links(previous,run_seed).filter(func(link):return link.get("floor")==id)
 assert(not entries.is_empty(),"Recovered maze floor needs its original approach")
 var start=Vector2i(((entries[0].arrival-row.origin)/3.0).round())
 var starts=[start]
 for link in Recovered.links(id,run_seed):starts.append(Vector2i(((link.at-row.origin)/3.0).round()))
 var seen={};var eligible=[];var components=[];var approaches=[]
 for landing:Vector2i in starts:
  if seen.has(landing):continue
  assert(Recovered.open(row.bits,row.size,landing),"Maze approach must retain original open ground")
  var queue=[landing];var cells=[];var region=components.size();seen[landing]=region
  for cell:Vector2i in queue:
   for direction in [Vector2i.UP,Vector2i.DOWN,Vector2i.LEFT,Vector2i.RIGHT]:
    var next:Vector2i=cell+direction
    if not seen.has(next) and Recovered.open(row.bits,row.size,next):seen[next]=region;queue.append(next)
   if [Vector2i.UP,Vector2i.DOWN,Vector2i.LEFT,Vector2i.RIGHT].all(func(d):return Recovered.open(row.bits,row.size,cell+d)):cells.append(cell)
  components.append(cells);approaches.append(landing);eligible.append_array(cells)
 var count_=PATROLS[section_index(id)].size()*3
 assert(eligible.size()>=count_,"Recovered approach must contain its patrol population")
 var posts=[]
 if id not in GUARDIAN_FLOORS:
  for cells in components:
   var local_count=mini(count_,cells.size());local_count-=local_count%PATROLS[section_index(id)].size()
   # Tiny stair vestibules stay clear; populate complete rosters where bodies fit.
   for i in local_count:posts.append(cells[(i*cells.size()+cells.size()/2)/local_count])
 var result={"seed":run_seed,"bits":row.bits,"posts":posts,"eligible":eligible,"components":components,"approaches":approaches,"regions":seen}
 generated_floors[id]=result
 return result

static func floor_info(id:int,run_seed:int=0)->Array:
 return Recovered.floor_info(id,run_seed)

static func creature_keys(id:int)->Array:
 var index=section_index(id)
 if index<0:return []
 var rows:Array=PATROLS[index]+GUARDIANS[index] if id in GUARDIAN_FLOORS else PATROLS[index]
 return rows.map(func(row):return row[0])

static func encounters(id:int,run_seed:int=0)->Array:
 var index=section_index(id)
 if index<0:return []
 var rows=[]
 var guardian=id in GUARDIAN_FLOORS
 var floor_=maze(id,run_seed)
 var cells:Array=floor_.posts
 for i in cells.size():
  var data:Array=PATROLS[index][i%PATROLS[index].size()]
  rows.append([cells[i],data[0],data[1],LEVELS[index]+(i/PATROLS[index].size())%3,false,i])
 if not guardian:return rows
 var seal=Recovered.links(id,run_seed).filter(func(link):return link.get("decree_guardians",false))[0]
 var seal_cell=Vector2i(((seal.at-Recovered.state(id,run_seed).origin)/3.0).round())
 var candidates:Array=floor_.components[floor_.regions[seal_cell]]
 var used={}
 var place=func(target:Vector2i)->Vector2i:
  var best=Vector2i.ZERO;var distance=INF
  for candidate:Vector2i in candidates:
   if used.has(candidate):continue
   var d=Vector2(candidate-target).length_squared()
   if d<distance:best=candidate;distance=d
  assert(is_finite(distance),"Guardian formation needs distinct reachable cells")
  used[best]=true;return best
 var bosses=[]
 for i in GUARDIANS[index].size():
  var data:Array=GUARDIANS[index][i]
  var center:Vector2i=Recovered.GUARD_CELLS[index]
  var cell:Vector2i=place.call(center+Vector2i(i*4-2 if index==5 else 0,0))
  # Keep historical boss death slots 7/8 when restoring the reference retinues.
  bosses.append([cell,data[0],data[1],70 if index==5 else 65,true,7+i])
 if index<5:
  for i in 9:
   var front=i>=4;var column=i-4 if front else i+int(i>=2)
   var data:Array=PATROLS[index][int(front)]
   var at:Vector2i=place.call(Recovered.GUARD_CELLS[index]+Vector2i((column-2)*2,3 if front else 0))
   rows.append([at,data[0],data[1],LEVELS[index]+2,false,i if i<7 else i+1])
 rows.append_array(bosses)
 return rows

static func cleared(slain:Dictionary,id:int,run_seed:int)->bool:
 var rows=encounters(id,run_seed)
 for slot in rows.size():
  if rows[slot][4] and not slain.has(Vector2i(id,rows[slot][5])):return false
 return true

static func door(at:Vector2,target:int,arrival:Vector2,caption:String="")->Dictionary:
 return {"at":at,"to":"freyja_door","floor":target,"arrival":arrival,
  "caption":title(target) if caption.is_empty() else caption,"door":true}

static func links(id:int,abanis:int,_house_door:Vector2)->Array:
 return Recovered.links(id if id!=abanis else 51011)
