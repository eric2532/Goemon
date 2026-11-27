extends RefCounted
## Recovered geography belongs to the existing Falan exploration route.
const Art=preload("res://scripts/forest/forest_original_map_art.gd")
const Forms=preload("res://scripts/forest/forest_original_map_solids.gd")
const Solids=preload("res://scripts/forest/forest_art.gd")
const Civic=preload("res://scripts/forest/forest_falan_civic_exterior.gd")
const Meadow=preload("res://scripts/forest/forest_wind_meadow_assets.gd")
const TinaScenery=preload("res://scripts/forest/forest_tina_scenery.gd")
const TinaGround=preload("res://scripts/forest/forest_tina_ground.gd")
const JenovaVillageArt=preload("res://scripts/forest/forest_jenova_village_art.gd")
const AbanisVillageArt=preload("res://scripts/forest/forest_abanis_village_art.gd")
const TinaVillageArt=preload("res://scripts/forest/forest_tina_village_art.gd")
const WestScenery=preload("res://scripts/forest/forest_west_route_scenery.gd")
const UniversityRouteArt=preload("res://scripts/forest/forest_university_route_art.gd")
static var EastArt:Script
static var EastArchitecture:Script
static var EastCasework:Script
static var EastCounters:Script
static var EastNativeTrees:Script
static var EastMounted:Script
static var EastMisc:Script
static var EastMarket:Script
static var EastHourglasses:Script
static var EastLektalRoof:Script
static var EastDisplays:Script
static var EastCounterSegments:Script
static var EastMouseStatue:Script
static var EastNature:Script
static var EastMousePiers:Script
static var EastCarvedPier:Script
const Beast=preload("res://scripts/forest/forest_beast_maps.gd")
const SHALENA_SOUTH=51031
const SHALENA_NORTH=51032
const ALIASES={51001:15000,51002:15001,51003:15002,51004:4000,51005:4200,51006:4020,51007:4212,51008:402,
 51011:4300,51012:4400,51013:4313,51014:4410,51016:4411,51017:4400,
 51015:402,51018:4310,51019:4418,51020:4400,51021:4320,51022:4331,51023:4333,51024:402,
 SHALENA_SOUTH:400,SHALENA_NORTH:402}
const REVERSE={15000:51001,15001:51002,15002:51003,4000:51004,4200:51005,
 4020:51006,4212:51007,4300:51011,4400:51012,4313:51013,4410:51014,4411:51016,4310:51018,4418:51019,
 4320:51021,4331:51022,4333:51023,400:SHALENA_SOUTH,402:SHALENA_NORTH}
const OUTDOORS=[400,401,402,4000,4100,4200,4201,4300,4400,4409,15522,32181]
const GUARD_CELLS=preload("res://assets/maps/original_crossgate/maze_encounters.gd").SEALS
const NEXT_LANDINGS=[Vector2i(24,26),Vector2i(27,2),Vector2i(16,19),Vector2i(24,23),Vector2i(23,4)]
const DECREE_POST_LANDINGS=[Vector2i(22,15),Vector2i(25,17),Vector2i(20,20),Vector2i(16,18),Vector2i(22,15),Vector2i(23,19)]
static var states:Dictionary={}
static var regional_dungeons:Script
const EastIndex=preload("res://assets/maps/falan/east_region/map_index.gd")
const GROUND_CHUNK=96.0
const EastGround=preload("res://scripts/forest/forest_east_ground_cache.gd")
const EastRuins=preload("res://scripts/forest/forest_east_ruin_sections.gd")
const EastColumns=preload("res://scripts/forest/forest_east_room_columns.gd")
const EastAnnexes=preload("res://scripts/forest/forest_east_lektal_annexes.gd")
const EastFurniture=preload("res://scripts/forest/forest_east_room_furniture.gd")
const EastCastle=preload("res://scripts/forest/forest_east_castle_compound.gd")
const EastGroundMotifs=preload("res://scripts/forest/forest_east_ground_motifs.gd")
const WaterCamera=preload("res://scripts/forest/forest_original_water_camera.gd")

static func generated()->Script:
 if regional_dungeons==null:regional_dungeons=load("res://scripts/forest/forest_original_dungeons.gd")
 return regional_dungeons

static func floor_number(id:int)->int:
 if id>=51025 and id<=51030:return (id-51024)*10
 var n=id-51100
 return n if n>0 and n<60 and n%10!=0 else 0

static func floor_id(n:int)->int:return 51024+n/10 if n%10==0 else 51100+n

static func source_id(id:int)->int:
 if EastIndex.REVERSE_ALIASES.has(id):return EastIndex.REVERSE_ALIASES[id]
 var n=floor_number(id)
 return 24008+n if n>0 else ALIASES.get(id,id)

static func path_for(id:int,seed_:int=0)->String:
 if source_id(id) in Art.EXPLORE_RECOVERED_IDS:Art.load_explore_recovered()
 if id in [3354,5011]:Art.load_black_prayer()
 if source_id(id) in EastIndex.FIXED:Art.load_east()
 if source_id(id) in Art.SOKIA_SERVER_IDS:Art.load_sokia_server()
 if source_id(id)>=13500 and source_id(id)<=13515:Art.load_sokia_water()
 if source_id(id) in Art.FREYJA_TRIAL_IDS:Art.load_freyja_trial()
 if source_id(id) in Art.SOKIA_WIND_IDS:Art.load_sokia_wind()
 if source_id(id) in Art.SOKIA_DESERT_TEMPLE_IDS:Art.load_sokia_desert_temple()
 if source_id(id) in Art.SOKIA_DRAGON_SUMMIT_IDS:Art.load_sokia_dragon_summit()
 if source_id(id) in Art.SOKIA_CAPE_ACCESS_IDS:Art.load_sokia_cape_access()
 if id>=59500 and id<59800:Art.load_elsa()
 return Beast.template(id,seed_).path if Beast.owns(id) else "BlueCrossgate/map/0/%d.dat"%source_id(id)

static func owns(id:int)->bool:
 if generated().owns(id) or Beast.owns(id):return true
 var path=path_for(id)
 if not (ALIASES.has(id) or id<700000 or EastIndex.REVERSE_ALIASES.has(id)) or not Art.data().maps.has(path):return false
 var row:Dictionary=Art.data().maps[path]
 var complete_explore=source_id(id) in Art.FREYJA_TRIAL_IDS+Art.SOKIA_WIND_IDS+Art.SOKIA_DESERT_TEMPLE_IDS+Art.SOKIA_DRAGON_SUMMIT_IDS+Art.EXPLORE_SERVER_IDS+Art.SOKIA_CAPE_ACCESS_IDS and row.get("layout_complete",false)
 return (not row.get("sokia_visual_only",false) or complete_explore) and not row.get("east_existing_owner",false)

static func outdoor(id:int)->bool:return source_id(id) in OUTDOORS or generated().branch(id)=="mountain" or generated().owns(id) and generated().SPECS[generated().branch(id)].get("outdoor",false) or id in [59500,59501,59510,59520] or owns(id) and Art.data().maps.get(path_for(id),{}).get("outdoor",false)
static func cave(id:int)->bool:return owns(id) and not outdoor(id) and not (id>=59500 and id<59800) and not Art.data().maps.get(path_for(id),{}).get("inferred_roofless",false)

static func ceiling_height(id:int)->float:
 if source_id(id)==33608:
  if EastMouseStatue==null:EastMouseStatue=load("res://scripts/forest/forest_east_mouse_statue.gd")
  # The native giant proves indoor headroom above its reconstructed source-sized body.
  return maxf(8.5,EastMouseStatue.mesh().get_meta("statue_bounds").end.y+1.5)
 if generated().owns(id):return 15.0
 if source_id(id) not in preload("res://assets/maps/falan/university_region/dungeon_specs.gd").FIXED:return 8.5
 var row=state(id);var cells:int=row.size.x*row.size.y;var high=8.5
 for i in cells:
  var serial:int=row.raw.decode_u16(20+(cells+i)*2)
  if serial<1000:continue
  var graphic:Dictionary=Art.data().graphics.get(str(serial),{})
  if graphic.is_empty():continue
  if Forms.kind(serial,false,graphic) in ["room_wall","wall","university_ice_panel","university_ice_column"]:
   high=maxf(high,Forms.source_height(graphic)+.15)
 return high

static func title(id:int)->String:
 if id==4100:return "阿斯提亞鎮 · 區域邊界"
 if id==SHALENA_SOUTH:return "莎蓮娜 · 傑諾瓦與蒂娜道路"
 if id in [SHALENA_NORTH,51024]:return "莎蓮娜 · 阿巴尼斯雪原"
 if id in [51009,51010]:return "積雪的山路 · %dF"%(1 if id==51009 else 2)
 if generated().owns(id):return "%s · %dF"%[generated().SPECS[generated().branch(id)].title,generated().number(id)]
 if Beast.owns(id):return "貝茲雷姆的迷宮 · %dF"%(id-Beast.FIRST+1)
 return Art.data().maps[path_for(id)].title

static func crop(id:int,seed_:int=0)->Rect2i:
 if id==4100:return Rect2i(45,115,33,25)
 if generated().owns(id):return Rect2i(Vector2i.ZERO,generated().dimensions(id,seed_))
 if source_id(id)==400:return Rect2i(110,170,510,310)
 var row:Dictionary=Art.data().maps[path_for(id,seed_)]
 return Rect2i(Vector2i.ZERO,Vector2i(row.size[0],row.size[1]))

static func state(id:int,seed_:int=0)->Dictionary:
 var key=Vector2i(id,seed_ if generated().owns(id) or Beast.owns(id) else 0)
 if states.has(key):return states[key]
 if Beast.owns(id):
  for stored:Vector2i in states.keys():
   if Beast.owns(stored.x) and stored.y!=seed_:states.erase(stored)
 if generated().owns(id):
  if generated().branch(id) in preload("res://assets/maps/falan/explore-dungeon-specs.gd").SPECS:Art.load_explore_recovered()
  for stored:Vector2i in states.keys():
   if generated().owns(stored.x) and stored.y!=seed_:states.erase(stored)
  var maze:Dictionary=generated().make(id,seed_);states[key]=maze
  return maze
 var source=Art.raw_map(path_for(id,seed_));var full_width=source.decode_u32(12);var full_cells=full_width*source.decode_u32(16)
 var cut=crop(id,seed_);var size_=cut.size;var cells=size_.x*size_.y
 var raw=PackedByteArray();raw.resize(20+cells*6)
 for i in 20:raw[i]=source[i]
 raw.encode_u32(12,size_.x);raw.encode_u32(16,size_.y)
 var original=Art.data().maps[path_for(id,seed_)]
 var bits_full=Marshalls.base64_to_raw(original.walk).decompress((full_cells+7)>>3,FileAccess.COMPRESSION_DEFLATE)
 var bits=PackedByteArray();bits.resize((cells+7)>>3)
 for z in size_.y:
  for x in size_.x:
   var i=z*size_.x+x;var j=(z+cut.position.y)*full_width+x+cut.position.x
   for plane in 3:raw.encode_u16(20+(plane*cells+i)*2,source.decode_u16(20+(plane*full_cells+j)*2))
   if bits_full[j>>3]&(1<<(j&7)):bits[i>>3]|=1<<(i&7)
 var result={"size":size_,"origin":-Vector2(size_/2)*3.0,"raw":raw,"bits":bits,"seed":seed_}
 states[key]=result
 return result

static func floor_info(id:int,seed_:int=0)->Array:
 var row=state(id,seed_)
 return [row.size,row.origin,row.bits.hex_encode()]

static func layout(id:int)->Dictionary:
 return {"format":"forest_shrine_map","schema":1,"title":title(id),"falan_area":"interior","falan_floor":id,"buildings":[],"trees":[],"deposits":[]}

static func point(id:int,cell:Vector2i,seed_:int=0)->Vector2:
 var origin=state(id,seed_).origin
 return origin+Vector2(cell)*3.0
static func source_point(id:int,cell:Vector2i)->Vector2:return point(id,cell-crop(id).position)

static func open(bits:PackedByteArray,size_:Vector2i,cell:Vector2i)->bool:
 if not Rect2i(Vector2i.ZERO,size_).has_point(cell):return false
 var i=cell.y*size_.x+cell.x
 return (bits[i>>3]&(1<<(i&7)))!=0

static func safe_cell(id:int,preferred:Vector2i,seed_:int=0)->Vector2i:
 var row=state(id,seed_);var best=Vector2i.ZERO;var distance=INF
 for z in row.size.y:
  for x in row.size.x:
   var c=Vector2i(x,z)
   if not open(row.bits,row.size,c):continue
   var d=Vector2(c-preferred).length_squared()
   if d<distance:best=c;distance=d
 return best

static func patrols(id:int,seed_:int,count_:int)->Array:
 var row=state(id,seed_);var candidates=[]
 for z in range(2,row.size.y-2):
  for x in range(2,row.size.x-2):
   var c=Vector2i(x,z)
   if [Vector2i.ZERO,Vector2i.UP,Vector2i.DOWN,Vector2i.LEFT,Vector2i.RIGHT].all(func(d):return open(row.bits,row.size,c+d)):
    candidates.append(c)
 var result=[]
 for i in mini(count_,candidates.size()):result.append(candidates[(i*candidates.size()+candidates.size()/2)/count_])
 return result

static func runtime_id(source:int)->int:
 if EastIndex.RUNTIME_ALIASES.has(source):return EastIndex.RUNTIME_ALIASES[source]
 if source>=24009 and source<=24068:return floor_id(source-24008)
 return REVERSE.get(source,source)

static func door(at:Vector2,target:int,arrival:Vector2,caption:String="")->Dictionary:
 return {"at":at,"to":"freyja_door","floor":target,"arrival":arrival,"caption":title(target) if caption.is_empty() else caption,"door":true}

static func links(id:int,seed_:int=0)->Array:
 var src=source_id(id);var result=[]
 if src in EastIndex.FIXED and not Art.data().maps.get(path_for(id),{}).get("east_existing_owner",false):
  return load("res://scripts/forest/forest_east_region.gd").links(id,seed_)
 for values in Art.data().warps:
  if id in [51009,51010] or int(values[0])!=src:continue
  # Superseded warp-table version: the client and reciprocal Abanis exits put this entrance on402 (182–184,161).
  if src==400 and int(values[3])==4300:continue
  var target=runtime_id(int(values[3]))
  if src in Art.EXPLORE_RECOVERED_IDS and target in [100,300]:
   var exterior=load("res://scripts/forest/forest_east_region.gd").destination_link(source_point(id,Vector2i(values[1],values[2])),target,Vector2i(values[4],values[5]))
   if not exterior.is_empty():result.append(exterior)
   continue
  # This fixed-warp reference describes priest6331's keyed F transfer, not a walk-through entrance.
  if src==400 and target==16510:continue
  if src==5005 and target==3000:
   var ghana:Vector2=preload("res://assets/maps/falan/freyja_destinations_data.gd").VILLAGES.ghana[2]
   result.append(door(source_point(id,Vector2i(values[1],values[2])),3000,ghana+Vector2(values[4],values[5])*3.,"迦納村"));continue
  if src in Art.SOKIA_CAPE_ACCESS_IDS and target==300:
   var regions=load("res://scripts/forest/forest_freyja_regions.gd");var area="ghana_road" if int(values[4])>=550 else "sokia_coast"
   result.append({"at":source_point(id,Vector2i(values[1],values[2])),"to":"freyja_outside","area":area,"arrival":regions.frame(area).inverse()*(Vector2(values[4],values[5])*3.),"caption":"索奇亞","door":true});continue
  if src in Art.FREYJA_TRIAL_IDS and target==100:
   var regions=load("res://scripts/forest/forest_freyja_regions.gd")
   result.append({"at":source_point(id,Vector2i(values[1],values[2])),"to":"freyja_outside","area":"freyja","arrival":regions.frame("freyja").inverse()*(Vector2(values[4],values[5])*3.),"caption":"Back to Freyja","door":true});continue
  if src in Art.SOKIA_WIND_IDS and target==300:
   var regions=load("res://scripts/forest/forest_freyja_regions.gd")
   result.append({"at":source_point(id,Vector2i(values[1],values[2])),"to":"freyja_outside","area":"sokia_coast","arrival":regions.frame("sokia_coast").inverse()*(Vector2(values[4],values[5])*3.),"caption":"索奇亞","door":true});continue
  if not owns(target):continue
  var a=Vector2i(values[1],values[2]);var b=Vector2i(values[4],values[5])
  if target in [59716,59752] and not load("res://scripts/forest/forest_elsa_route.gd").owned_cell(target,b):continue
  if not crop(id).has_point(a) or not crop(target).has_point(b):continue
  if src>=59500 and src<59800:
   var current=state(id,seed_);var landing=state(target,seed_)
   # CUT-map caches explicitly mark superseded bridge tiles as blocked; do not move those warps onto the live crossing.
   if not open(current.bits,current.size,a-crop(id).position) or not open(landing.bits,landing.size,b-crop(target).position):continue
  var arrival=source_point(target,b);var destination=state(target,seed_)
  var cell=b-crop(target).position
  if not open(destination.bits,destination.size,cell):
   var safe=safe_cell(target,cell,seed_)
   if Vector2(safe-cell).length()<=2.1:arrival=point(target,safe,seed_)
  var crossing=door(source_point(id,a),target,arrival).merged({"source_arrival":source_point(target,b)})
  if int(values[3])==4418 and src in [4400,4410,4419,4420]:crossing.region_hall_variant=true
  result.append(crossing)
 if src in [400,4200,4201]:
  for values in Art.data().warps:
   if int(values[3])!=src or int(values[0]) not in [400,4200,4201,4206]:continue
   if Art.data().warps.any(func(w):return int(w[0])==src and int(w[1])==int(values[4]) and int(w[2])==int(values[5])):continue
   var a=Vector2i(values[4],values[5]);var b=Vector2i(values[1],values[2])
   if not crop(id).has_point(a):continue
   var target=runtime_id(int(values[0]))
   if not owns(target):continue
   var landing=safe_cell(target,b-crop(target).position)
   result.append(door(source_point(id,a),target,point(target,landing)))
 if id==51001:
  result.append({"at":source_point(id,Vector2i(22,33)),"to":"freyja_outside","area":"west_lakes","arrival":Vector2(33,-45),"caption":"芙蕾雅 · 法蘭西門","door":true})
 if id==16510:
  result.append(door(source_point(id,Vector2i(25,7)),Beast.FIRST,stair_landing(Beast.FIRST,seed_,true),"貝茲雷姆的迷宮"))
 if Beast.owns(id):
  var previous=16510 if id==Beast.FIRST else id-1
  var next=16511 if id==Beast.FIRST+Beast.COUNT-1 else id+1
  var back=source_point(16510,Vector2i(25,8)) if previous==16510 else stair_landing(previous,seed_,false)
  var ahead=source_point(16511,Vector2i(26,72)) if next==16511 else stair_landing(next,seed_,true)
  result=[door(point(id,Beast.stair(id,seed_,true),seed_),previous,back),door(point(id,Beast.stair(id,seed_,false),seed_),next,ahead)]
 if id==16511:
  result.append(door(source_point(id,Vector2i(26,72)),Beast.FIRST+Beast.COUNT-1,stair_landing(Beast.FIRST+Beast.COUNT-1,seed_,false)))
  # Grayson's item-gated transfer belongs to his F interaction, not a free walk-through portal.
  result.append(door(source_point(id,Beast.BOSS_CELL),16512,source_point(16512,Vector2i(26,26)),"神獸的封印").merged({"beast_guardian":true}))
 # The two job side rooms and Gina's return are NPC transfers with original profession gates.
 if id==16513:
  # The stone occupies an isolated pedestal; interact from its original aisle.
  result.append(door(source_point(id,Vector2i(14,8)),SHALENA_SOUTH,source_point(SHALENA_SOUTH,Vector2i(136,336)),"魔法傳送石 · 返回莎蓮娜").merged({"source_gate":source_point(id,Vector2i(14,6))}))
 if src==402:
  result.append(door(source_point(id,Vector2i(84,193)),51009,generated().landing(51009,seed_,true),"積雪的山路"))
  result.append(door(source_point(id,Vector2i(54,162)),24008,source_point(24008,Vector2i(8,7)),"鼓動的石盤 · 詛咒迷宮").merged({"decree_needs_blade":true}))
 if generated().owns(id):result=generated().links(id,seed_)
 for branch_ in generated().SPECS:
  var spec:Dictionary=generated().SPECS[branch_]
  if src==spec.entry[0] and branch_!="mountain":
   var first:int=generated().floor_id(branch_,1)
   result.append(door(source_point(id,generated().entry_cell(branch_,seed_)),first,generated().landing(first,seed_,true),spec.title).merged({"region_needs":"moon_hoe" if branch_=="tunnel" else ""}))
  if branch_!="scientist" and not spec.end.is_empty() and src==spec.end[0]:
   var last:int=generated().floor_id(branch_,generated().count(branch_,seed_))
   result.append(door(source_point(id,Vector2i(spec.end[1],spec.end[2])),last,generated().landing(last,seed_,false)))
 if id==51022:
  result.append(door(source_point(id,Vector2i(7,3)),51021,source_point(51021,Vector2i(9,5))))
 if src==4419:
  result.append(door(source_point(id,Vector2i(13,8)),59752,source_point(59752,Vector2i(100,112)),"希爾弗的試煉").merged({"region_stamps":5}))
 if src==59752:
  for cell in [Vector2i(104,116),Vector2i(136,148)]:result.append(door(source_point(id,cell),4419,source_point(4419,Vector2i(12,9))))
 var number=floor_number(id)
 if number>0 and number%10==0:
  var index=number/10-1
  var boss=source_point(id,GUARD_CELLS[index])
  var target=24069+index
  result.append(door(boss,target,source_point(target,DECREE_POST_LANDINGS[index]),"封印石 · 解放之間" if number==60 else "聖詔 · 難關後").merged({"decree_guardians":true}))
 var accessible=[]
 if src>=59500 and src<59800:
  var elsa=load("res://scripts/forest/forest_elsa_route.gd")
  result.append_array(elsa.room_returns(id,result));result.append_array(elsa.event_links(id))
 elif src in [4400,4410,4417,4418,4419,4420,4430,4431,4432,4451,4454,4455]:
  # Only recorded campus door pairs. Dungeon returns and guardian/event seals keep their own owners.
  result.append_array(load("res://scripts/forest/forest_elsa_route.gd").room_returns(id,result,true))
 for link in result:
  if src in [4400,4410,4419,4420] and source_id(int(link.get("floor",-1))) in [4418,32269]:
   link.floor=runtime_id(4418);link.region_hall_variant=true
  var cell=Vector2i(((link.at-state(id,seed_).origin)/3.0).round())
  if not open(state(id,seed_).bits,state(id,seed_).size,cell):
   var safe=safe_cell(id,cell,seed_)
   if Vector2(safe-cell).length()>2.1:continue
   link.source_gate=link.at
   link.at=point(id,safe,seed_)
  if src>=59520 and src<59800 and not load("res://scripts/forest/forest_elsa_route.gd").owned_cell(id,Vector2i(((link.at-state(id,seed_).origin)/3.0).round())):continue
  accessible.append(link)
 return accessible

static func stair_landing(id:int,seed_:int,up:bool)->Vector2:
 var row=state(id,seed_);var cell=Beast.stair(id,seed_,up)
 return interior_stair_landing(id,cell,Beast.stair(id,seed_,not up),seed_)

static func interior_stair_landing(id:int,cell:Vector2i,other:Vector2i,seed_:int)->Vector2:
 var row=state(id,seed_)
 # Choose the interior side of the arrival stair. A cul-de-sac on its far side bounces the player back.
 var seen={other:0};var queue=[other];var cursor=0
 while cursor<queue.size():
  var at:Vector2i=queue[cursor];cursor+=1
  for step in [Vector2i.DOWN,Vector2i.RIGHT,Vector2i.UP,Vector2i.LEFT]:
   var next=at+step
   if next==cell or seen.has(next) or not open(row.bits,row.size,next):continue
   seen[next]=int(seen[at])+1;queue.append(next)
 var chosen=cell;var distance=2147483647
 for direction in [Vector2i.DOWN,Vector2i.RIGHT,Vector2i.UP,Vector2i.LEFT]:
  var next=cell+direction
  if seen.has(next) and int(seen[next])<distance:chosen=next;distance=int(seen[next])
 if chosen!=cell:return point(id,chosen,seed_)
 assert(false,"Source stair requires an interior landing that does not cross its own return warp")
 return point(id,cell,seed_)

static func porch_floors(placements:Array,raw:PackedByteArray,size_:Vector2i)->Array:
 # shortcut: Fill only missing bay-house ground visually until original floor cells are recovered.
 var fills=[];var covered={};var cells=size_.x*size_.y
 for placement in placements:
  if placement[4]<cells or placement[3] not in [11407,11408]:continue
  var g:Dictionary=Art.data().graphics[str(placement[3])]
  for z in int(g.footprint[1]):
   for x in int(g.footprint[0]):
    var cell:Vector2i=placement[5]+Vector2i(x,-z)
    if cell.x<0 or cell.y<0 or cell.x>=size_.x or cell.y>=size_.y or covered.has(cell):continue
    var index=cell.y*size_.x+cell.x
    if raw.decode_u16(20+index*2)!=0:continue
    var best=INF;var serial=0
    for dy in range(-8,9):
     for dx in range(-8,9):
      var other=cell+Vector2i(dx,dy);var distance=dx*dx+dy*dy
      if distance>=best or other.x<0 or other.y<0 or other.x>=size_.x or other.y>=size_.y:continue
      var candidate=raw.decode_u16(20+(other.y*size_.x+other.x)*2)
      if candidate<1000 or candidate in range(5000,5009):continue
      var graphic:Dictionary=Art.data().graphics[str(candidate)]
      if graphic.family=="void" or int(graphic.footprint[0])!=1 or int(graphic.footprint[1])!=1:continue
      serial=candidate;best=distance
    if serial==0:continue
    covered[cell]=true;fills.append([0,0,Vector2.ZERO,serial,index,cell])
 return fills

static func build(root:Node3D,id:int,seed_:int=0)->Array[AABB]:
 var row=state(id,seed_)
 var mouse_statue=null
 if source_id(id)==33608:
  if EastMouseStatue==null:EastMouseStatue=load("res://scripts/forest/forest_east_mouse_statue.gd")
  mouse_statue=EastMouseStatue
 var floor_art=load("res://scripts/forest/forest_elsa_landmark_floor.gd")
 var elsa_floor=floor_art if floor_art.available(source_id(id)) else null
 var branch_key:String=generated().branch(id) if generated().owns(id) else ""
 var eastern=source_id(id) in EastIndex.FIXED or not branch_key.is_empty() and generated().SPECS[branch_key].get("east",false)
 var chunk_ground=eastern and row.size.x*row.size.y>262144
 if eastern and EastArt==null:EastArt=load("res://scripts/forest/forest_east_region_art.gd")
 var cliff_art=load("res://scripts/forest/forest_original_cliffs.gd")
 var cave_entrances=load("res://scripts/forest/forest_original_cave_entrance.gd");var size_:Vector2i=row.size;var origin:Vector2=row.origin
 var prepared_ground:Node3D=EastGround.instantiate(source_id(id)) if eastern else null
 var art=Art.new();art.load_map("generated:region" if generated().owns(id) else path_for(id,seed_),row.raw,size_,prepared_ground!=null)
 var surfaces={};var groups={};var trees={};var shrubs=[];var flowers=[];var cells=size_.x*size_.y;var total=0
 var floor_arrays={};var floor_placements=0
 var prayer_fixtures=load("res://scripts/forest/forest_black_prayer_room_fixtures.gd") if id in [3354,5011] else null
 if prepared_ground!=null:
  root.add_child(prepared_ground);floor_placements=int(prepared_ground.get_meta("plane0_floor_placements"));total=floor_placements
 var snow=false
 var regional_floor=generated().owns(id)
 var frost=load("res://scripts/forest/forest_frostpass_art.gd") if snow or regional_floor else null
 var winter=load("res://scripts/forest/forest_frostpass.gd") if snow else null
 var source_count=int(prepared_ground.get_meta("source_placements")) if prepared_ground!=null else art.placements.size()
 var sokia=load("res://scripts/forest/forest_sokia_scenery.gd")
 var sokia_fixed:Dictionary=sokia.fixed_map(source_id(id))
 var sokia_cave=source_id(id) in [13003,13005,13007,13011,13012,13013,15564,15524,15525,15526]
 var sokia_upland=not sokia_fixed.is_empty() and sokia_fixed.outdoor
 var cliff_mass=source_id(id) in cliff_art.MAPS
 var scoped_cliffs:Dictionary=Art.data().sokia_water_cliffs if source_id(id)>=13500 and source_id(id)<=13515 else Art.data().freyja_trial_cliffs if source_id(id) in Art.FREYJA_TRIAL_IDS else{}
 var porch_fills=porch_floors(art.placements,row.raw,size_)
 art.placements.append_array(porch_fills)
 var cut_floor={}
 for placement in art.placements:
  if placement[4]<cells or placement[3] not in Forms.CUT_FLOOR:continue
  var g:Dictionary=Art.data().graphics[str(placement[3])]
  for z in maxi(1,int(g.footprint[1])):
   for x in maxi(1,int(g.footprint[0])):cut_floor[placement[5]+Vector2i(x,-z)]=true
 for placement in art.placements:
  var serial:int=placement[3];var g:Dictionary=Art.data().graphics[str(serial)]
  var cell:Vector2i=placement[5];var pos=Vector3(origin.x+cell.x*3,0,origin.y+cell.y*3)
  if mouse_statue!=null and placement[4]<cells and mouse_statue.replaces_background(cell+crop(id).position,serial):
   total+=1;continue
  if id==31954 and EastCastle.skip(31954,int(placement[4]>=cells),cell+crop(id).position,serial):
   total+=1;continue
  if g.has("cut") and g.get("animated",false) and id>=59500 and id<59800:
   pos+=load("res://scripts/forest/forest_elsa_scenery.gd").effect_shift(source_id(id),placement[4]%cells)
  if id in [59716,59752] and not load("res://scripts/forest/forest_elsa_route.gd").visible_cell(id,cell):continue
  if g.has("cut") and load("res://scripts/forest/forest_elsa_scenery.gd").tower_piece(source_id(id),g):continue
  if g.has("cut") and load("res://scripts/forest/forest_elsa_scenery.gd").grouped(source_id(id),g):continue
  if source_id(id)==59535 and placement[4]<cells:continue # The hall's original BG is recomposed with its raised enclosure.
  if source_id(id)==400 and (serial==10011 or placement[4]<cells and serial>=1600 and serial<=1692):continue
  if source_id(id)==15526 and (placement[4]<cells and serial==100 or placement[4]>=cells and serial==17954):
   total+=1;continue # Cache void and the native stair are interpreted by this corridor's existing solid owners.
  if (source_id(id) in [15525,5011] or source_id(id) in Art.SOKIA_SERVER_IDS or source_id(id) in Art.SOKIA_CAPE_ACCESS_IDS) and placement[4]<cells and serial==100:total+=1;continue
  if not scoped_cliffs.is_empty()and(placement[4]<cells and serial==100 or placement[4]>=cells and(serial in scoped_cliffs.void_source_fragments or cliff_art.continuous(serial,false,scoped_cliffs))):total+=1;continue
  if placement[4]<cells and cut_floor.has(cell):continue
  var family=Forms.kind(serial,placement[4]<cells,g)
  if prayer_fixtures!=null and placement[4]>=cells and serial in range(10504,10510) and prayer_fixtures.owns(id,serial):family="book"
  if g.has("cut") and family=="floor":
   if elsa_floor!=null and placement[4]<cells:g=elsa_floor.graphic(placement[4],g,source_id(id))
   var page=int(g.page);var sky=int(g.cut[0])==300342;var batch=-1000-page if sky else page
   if not surfaces.has(batch):
    var tool=SurfaceTool.new();tool.begin(Mesh.PRIMITIVE_TRIANGLES);surfaces[batch]=tool
   var size_pixels=Vector2(g.rect[2],g.rect[3]);var corners=[Vector2.ZERO,Vector2(size_pixels.x,0),size_pixels,Vector2(0,size_pixels.y)]
   var native_origin=Vector2(g.origin[0],g.origin[1]);var atlas_size:Vector2=(elsa_floor.texture(page,source_id(id)) if elsa_floor!=null and page>=elsa_floor.PAGE_OFFSET else art.textures[page]).get_size()
   if source_id(id)==59520 and load("res://scripts/forest/forest_elsa_scenery.gd").shore_floor(surfaces[batch],pos,g,atlas_size,placement[4]):
    total+=1;continue
   if id>=59500 and id<59800 and not sky and load("res://scripts/forest/forest_elsa_scenery.gd").terrain_floor(surfaces[batch],source_id(id),pos,g,atlas_size,placement[4],origin):
    total+=1;continue
   for corner in [0,1,2,0,2,3]:
    var pixel:Vector2=corners[corner];var native:Vector2=pixel+native_origin
    surfaces[batch].set_normal(Vector3.UP)
    surfaces[batch].set_uv((Vector2(g.rect[0],g.rect[1])+pixel.clamp(Vector2.ONE*.5,size_pixels-Vector2.ONE*.5))/atlas_size)
    surfaces[batch].add_vertex(pos+(load("res://scripts/forest/forest_elsa_scenery.gd").sky_point(native) if sky else Vector3(native.x*3./64.-native.y/16.,.012,native.x*3./64.+native.y/16.)))
   total+=1;continue
  if source_id(id)==5003 and g.family=="plant":family="plant"
  if source_id(id)==23600 and serial in range(13152,13216):family="room_wall"
  if not sokia_fixed.is_empty() and g.family=="plant":family="plant"
  if not sokia_fixed.is_empty() and serial in [11214,11217,11219,11220,11221,11222]:family="detail_flat_panel"
  if sokia_cave and (serial in range(13080,13116) or serial in range(17840,17876)):
   total+=1;continue
  if sokia_upland and (serial in range(12675,12685) or serial in range(12926,12938)):
   total+=1;continue
  if not sokia_fixed.is_empty() and family=="rock" and serial in sokia_fixed.void_cliffs:
   total+=1;continue
  var source_cell=cell+crop(id).position
  if placement[4]>=cells and eastern and serial==10075:
   # This native drawing is the complete purple Magic Shop, not a tree.
   if EastArchitecture==null:EastArchitecture=load("res://scripts/forest/forest_east_classic_architecture.gd")
   var key=Vector2i(serial,11)
   if not groups.has(key):groups[key]=[EastArchitecture.mesh(serial,g),[]]
   groups[key][1].append(Transform3D(Basis.IDENTITY,pos));total+=1
   continue
  if placement[4]>=cells and eastern and EastAnnexes.owns(serial):
   var key=Vector2i(serial,8)
   if not groups.has(key):groups[key]=[EastAnnexes.mesh(serial,g),[]]
   groups[key][1].append(Transform3D(Basis.IDENTITY,pos));total+=1
   continue
  if placement[4]>=cells and eastern and EastColumns.owns(serial):
   var key=Vector2i(serial,7)
   if not groups.has(key):groups[key]=[EastColumns.mesh(serial,g),[]]
   groups[key][1].append(Transform3D(Basis.IDENTITY,pos));total+=1
   continue
  if placement[4]>=cells and eastern and EastRuins.owns(serial):
   var key=Vector2i(serial,6)
   if not groups.has(key):groups[key]=[EastRuins.mesh(serial,g),[]]
   groups[key][1].append(Transform3D(Basis.IDENTITY,pos));total+=1
   continue
  if placement[4]>=cells and eastern and source_id(id) in [43000,43700] and serial==1233255:
   if EastLektalRoof==null:EastLektalRoof=load("res://scripts/forest/forest_east_lektal_roof.gd")
   var key=Vector2i(serial,19)
   if not groups.has(key):groups[key]=[EastLektalRoof.mesh(serial,g),[]]
   groups[key][1].append(Transform3D(Basis.IDENTITY,pos));total+=1
   continue
  if placement[4]>=cells and eastern and EastArt.owns(source_id(id),serial):
   var east_mesh:Mesh=EastArt.mesh(source_id(id),serial,g)
   if east_mesh!=null:
    var key=Vector2i(serial,5)
    if not groups.has(key):groups[key]=[east_mesh,[]]
    groups[key][1].append(Transform3D(Basis.IDENTITY,pos));total+=1
    continue
  if placement[4]>=cells and AbanisVillageArt.owns(source_id(id),serial):
   var key=Vector2i(serial,4)
   if not groups.has(key):groups[key]=[AbanisVillageArt.mesh(serial,g),[]]
   groups[key][1].append(Transform3D(Basis.IDENTITY,pos));total+=1
   continue
  if placement[4]>=cells and not JenovaVillageArt.owns(source_id(id),serial,source_cell) and UniversityRouteArt.owns(source_id(id),serial,source_cell):
   var route_mesh:Mesh=UniversityRouteArt.mesh(source_id(id),serial,g)
   if route_mesh!=null:
    var key=Vector2i(serial,3)
    if not groups.has(key):groups[key]=[route_mesh,[]]
    groups[key][1].append(Transform3D(Basis.IDENTITY,pos));total+=1
   continue
  if cliff_mass and family=="rock" and cliff_art.continuous(serial):
   total+=1;continue
  if family in ["detail_aquatic","detail_boat"] and row.raw.decode_u16(20+(cell.y*size_.x+cell.x)*2) in range(5000,5009):pos.y=-2.1
  if family=="void":continue
  if source_id(id) in Art.SOKIA_SERVER_IDS and placement[4]>=cells and serial==11290:
   var centre=pos+Vector3((float(g.footprint[0])-1.)*1.5,0,(1.-float(g.footprint[1]))*1.5)
   var index=root.get_child_count();sokia.Details.Shapes.build(root,centre,serial)
   var house=root.get_child(index);house.set_meta("sokia_server_native_house",true);house.set_meta("source_anchor",source_cell)
   total+=1;continue
  if JenovaVillageArt.owns(source_id(id),serial,source_cell):
   var key=Vector2i(serial,2)
   if not groups.has(key):groups[key]=[JenovaVillageArt.mesh(serial,g),[]]
   groups[key][1].append(Transform3D(Basis.IDENTITY,pos));total+=1
   continue
  if TinaVillageArt.owns(source_id(id),serial,cell):
   var key=Vector2i(serial,1)
   if not groups.has(key):groups[key]=[TinaVillageArt.mesh(serial,g),[]]
   groups[key][1].append(Transform3D(Basis.IDENTITY,pos));total+=1
   continue
  if TinaScenery.owns(source_id(id),serial):
   if not groups.has(serial):groups[serial]=[TinaScenery.mesh(serial,g),[]]
   groups[serial][1].append(Transform3D(Basis.IDENTITY,pos));total+=1
   continue
  if placement[4]>=cells and eastern and serial in [10430,10431,10438,10440,10492,10567,16014,16016,16017,16020,16021,17008,17010,17011,17542,17547]:
   if EastCasework==null:EastCasework=load("res://scripts/forest/forest_east_room_casework.gd")
   var key=Vector2i(serial,12)
   if not groups.has(key):groups[key]=[EastCasework.mesh(serial,g),[]]
   groups[key][1].append(Transform3D(Basis.IDENTITY,pos));total+=1
   continue
  if placement[4]>=cells and eastern and serial in [16876,16878,16879,16881,16882,16883,16884]:
   if EastCounters==null:EastCounters=load("res://scripts/forest/forest_east_room_counters.gd")
   var key=Vector2i(serial,13)
   if not groups.has(key):groups[key]=[EastCounters.mesh(serial,g),[]]
   groups[key][1].append(Transform3D(Basis.IDENTITY,pos));total+=1
   continue
  if placement[4]>=cells and eastern and EastFurniture.owns(serial):
   var key=Vector2i(serial,9)
   if not groups.has(key):groups[key]=[EastFurniture.mesh(serial,g),[]]
   groups[key][1].append(Transform3D(Basis.IDENTITY,pos));total+=1
   continue
  if placement[4]>=cells and eastern and EastGroundMotifs.owns(serial):
   var key=Vector2i(serial,10)
   if not groups.has(key):groups[key]=[EastGroundMotifs.mesh(serial,g),[]]
   groups[key][1].append(Transform3D(Basis.IDENTITY,pos));total+=1
   continue
  if placement[4]>=cells and eastern and (serial in range(10058,10075) or serial in range(10085,10095)) and sokia_fixed.is_empty() and not UniversityRouteArt.contains(source_id(id),source_cell) and not WestScenery.contains(str(source_id(id)),Vector2(source_cell)):
   # Exact per-ID source tiers/branch gaps; contextual village/route owners above retain priority.
   if EastNativeTrees==null:EastNativeTrees=load("res://scripts/forest/forest_east_native_trees.gd")
   var key=Vector2i(serial,14)
   if not groups.has(key):groups[key]=[EastNativeTrees.mesh(serial,g),[]]
   groups[key][1].append(Transform3D(Basis.IDENTITY,pos));total+=1
   continue
  if placement[4]>=cells and eastern and serial in [10526,10547,10550,10551,10569,10582,11113,11114,11119,11122,16139,16236,16237,16238,16239,16240,16241,16242,16243,16565,16645,17521,17522,17523,17560,17563,11059,17674,14529,14536]:
   if EastMounted==null:EastMounted=load("res://scripts/forest/forest_east_mounted_details.gd")
   var key=Vector2i(serial,15)
   if not groups.has(key):groups[key]=[EastMounted.mesh(serial,g),[]]
   groups[key][1].append(Transform3D(Basis.IDENTITY,pos));total+=1
   continue
  if placement[4]>=cells and eastern and serial in [11575,11576,11580,16818,16852,16853,16854,16855,16864,16865,16866]:
   if EastMisc==null:EastMisc=load("res://scripts/forest/forest_east_misc_furniture.gd")
   var key=Vector2i(serial,16)
   if not groups.has(key):groups[key]=[EastMisc.mesh(serial,g),[]]
   groups[key][1].append(Transform3D(Basis.IDENTITY,pos));total+=1
   continue
  if placement[4]>=cells and eastern and serial in [10053,10054,10056,10057,10098]:
   if EastMarket==null:EastMarket=load("res://scripts/forest/forest_east_market_goods.gd")
   var key=Vector2i(serial,17)
   if not groups.has(key):groups[key]=[EastMarket.mesh(serial,g),[]]
   groups[key][1].append(Transform3D(Basis.IDENTITY,pos));total+=1
   continue
  if placement[4]>=cells and eastern and serial in [1235180,1235181,1235182]:
   if EastHourglasses==null:EastHourglasses=load("res://scripts/forest/forest_east_hourglasses.gd")
   var key=Vector2i(serial,18)
   if not groups.has(key):groups[key]=[EastHourglasses.mesh(serial,g),[]]
   groups[key][1].append(Transform3D(Basis.IDENTITY,pos));total+=1
   continue
  if placement[4]>=cells and eastern and serial in [16824,16825,16828,17183,17528]:
   if EastDisplays==null:EastDisplays=load("res://scripts/forest/forest_east_display_furniture.gd")
   var key=Vector2i(serial,20)
   if not groups.has(key):groups[key]=[EastDisplays.mesh(serial,g),[]]
   groups[key][1].append(Transform3D(Basis.IDENTITY,pos));total+=1
   continue
  if placement[4]>=cells and eastern and serial in range(17196,17205):
   if EastCounterSegments==null:EastCounterSegments=load("res://scripts/forest/forest_east_counter_segments.gd")
   var key=Vector2i(serial,21)
   if not groups.has(key):groups[key]=[EastCounterSegments.mesh(serial,g),[]]
   groups[key][1].append(Transform3D(Basis.IDENTITY,pos));total+=1
   continue
  if placement[4]>=cells and source_id(id) in EastIndex.FIXED:
   if EastNature==null:EastNature=load("res://scripts/forest/forest_east_nature.gd")
   if EastNature.owns(serial):
    var key=Vector2i(serial,22)
    if not groups.has(key):groups[key]=[EastNature.mesh(serial,g),[]]
    groups[key][1].append(Transform3D(Basis.IDENTITY,pos));total+=1
    continue
  if placement[4]>=cells and source_id(id) in EastIndex.FIXED and serial==1230127:
   if EastMousePiers==null:EastMousePiers=load("res://scripts/forest/forest_east_mouse_room_piers.gd")
   var key=Vector2i(serial,23)
   if not groups.has(key):groups[key]=[EastMousePiers.mesh(serial,g),[]]
   groups[key][1].append(Transform3D(Basis.IDENTITY,pos));total+=1
   continue
  if placement[4]>=cells and source_id(id) in EastIndex.FIXED and serial==1230051:
   if EastCarvedPier==null:EastCarvedPier=load("res://scripts/forest/forest_east_carved_pier_study.gd")
   var key=Vector2i(serial,24)
   if not groups.has(key):groups[key]=[EastCarvedPier.mesh(serial,g),[]]
   groups[key][1].append(Transform3D(Basis.IDENTITY,pos));total+=1
   continue
  if family=="flowers":
   flowers.append(Transform3D(Basis.IDENTITY.scaled(Vector3.ONE*.65),pos));total+=1
   continue
  if serial==10604:
   var index=root.get_child_count()
   Civic.build(root,Vector3.ZERO,[1092,"falan_townhouse",0,Vector2.ZERO,Vector3.ONE])
   var model:Node3D=root.get_child(index)
   var w=maxi(1,int(g.footprint[0]))*3.0;var d=maxi(1,int(g.footprint[1]))*3.0
   var height=Forms.source_height(g)
   model.position=pos+Vector3((w-3)*.5,0,(3-d)*.5);model.rotation.y=0
   model.scale=Vector3(w/17.9,height/15.5,d/14.35)
   model.name="RecoveredUniversityGuild_10604";total+=1
   continue
  if family=="tree":
   if not sokia_fixed.is_empty():
    var key=Vector2i(serial,3)
    if not trees.has(key):trees[key]=[]
    trees[key].append(Transform3D(Basis.IDENTITY,pos)*sokia.tree_fit(source_id(id),serial));total+=1
    continue
   if UniversityRouteArt.contains(source_id(id),source_cell):continue
   if WestScenery.contains(str(source_id(id)),Vector2(cell+crop(id).position)):continue
   var evergreen=serial in range(10050,10074) or (serial in range(11600,11622))
   var tree_source=10058 if evergreen else 10088
   var snowy=source_id(id) in [402,4300,4400,15522] or id in [51009,51010] or serial>=11600
   var key=Vector2i(tree_source,int(snowy))
   if not trees.has(key):trees[key]=[]
   if snow or regional_floor and row.frozen:
    for step in [Vector2i.UP,Vector2i.DOWN,Vector2i.LEFT,Vector2i.RIGHT]:
     if not open(row.bits,size_,cell+step):continue
     var edge=Vector2(pos.x,pos.z)+Vector2(step)*1.5
     pos.y=frost.wall_column(edge,winter.LEVELS.keys().find(id) if snow else 4,row.bits,size_,origin)[8].y-.6
     break
   var height=clampf(float(-g.origin[1])*.031,2.0,12.0)
   if snow and serial in range(11622,11625):
    var sapling_key=Vector2i(serial,2)
    if not groups.has(sapling_key):groups[sapling_key]=[WestScenery.sapling(serial,true),[]]
    groups[sapling_key][1].append(Transform3D(Basis.IDENTITY,pos));total+=1
    continue
   trees[key].append(Transform3D(Basis.IDENTITY.scaled(Vector3.ONE*height/8.5),pos))
   continue
  if family=="planter":
   var high=maxf(.35,Forms.source_height(g)*.68)
   shrubs.append(Transform3D(Basis.IDENTITY.scaled(Vector3(.75,.40,.75)),pos+Vector3.UP*high*.72))
  if prepared_ground!=null and family in ["floor","water","detail_flat_panel"]:
   floor_placements+=1;total+=1;continue
  var route_cliff=source_id(id) in [15000,15001,15002]
  var native_cliff=family=="rock" and (cliff_art.owns(serial) and serial not in range(12536,12566) and (serial not in range(13000,13036) or route_cliff) or serial in cave_entrances.IDS)
  var texture=art.textures[int(g.page)] if family in ["floor","water","detail_flat_panel"] or native_cliff else Art.solid_texture(int(g.page))
  if family=="rock" and not native_cliff or family=="wall" and serial in Forms.WALLS:texture=Art.surface_texture(int(g.surfaces[0]))
  var tina_terrain=source_id(id) in [4200,4201]
  var tina_floor=tina_terrain and placement[4]<cells and family in ["floor","water"]
  var tina_bank=tina_terrain and placement[4]>=cells and TinaGround.shore(serial)
  var jenova_floor=placement[4]<cells and family=="floor" and JenovaVillageArt.floor_owns(source_id(id),cell)
  var snow_floor=placement[4]<cells and family=="floor" and not jenova_floor and AbanisVillageArt.floor_owns(source_id(id),serial,source_cell,snow)
  var sokia_house=load("res://scripts/forest/forest_sokia_house_art.gd") if not sokia_fixed.is_empty() else null
  var owned_house=sokia_house!=null and sokia_house.owns(serial,family)
  var local_graphic=g.duplicate() if owned_house else g
  if owned_house:local_graphic.family=family
  var native_palm=not sokia_fixed.is_empty() and sokia.Details.Data.PALMS.has(serial)
  var native_cap:Dictionary=sokia_fixed.get("wall_caps",{}).get(str(serial),{})
  var mesh=prayer_fixtures.mesh(serial,g,texture) if prayer_fixtures!=null and placement[4]>=cells and prayer_fixtures.owns(id,serial) else sokia.Details.palm(serial) if native_palm else sokia_house.mesh(serial,local_graphic,art.textures[int(g.page)],native_cap) if owned_house else JenovaVillageArt.floor_mesh(serial,g) if jenova_floor else AbanisVillageArt.floor_mesh(serial,g,texture) if snow_floor else TinaGround.floor_mesh(serial,g) if tina_floor else TinaGround.bank_mesh(serial,g) if tina_bank else Forms.mesh(serial,family,g,texture,route_cliff,eastern and placement[4]>=cells and (Forms.east_fallback_owned(serial) or family=="prop" and EastArt.minor_prop_allowed(serial,g)))
  if not sokia_fixed.is_empty() and serial not in [17562,17563,17565] and family not in ["floor","water","detail_flat_panel"] and mesh.get_aabb().size.y>.001:
   mesh=sokia.interior_mesh(serial,mesh,source_id(id),owned_house,family=="room_wall",not native_cap.is_empty() or serial in [10047,10048,16134])
  if family in ["floor","water","detail_flat_panel"] and not tina_bank:
   var page=-2 if jenova_floor else -3 if snow_floor else -1 if tina_floor else int(g.page)
   var batch_key:Variant=Vector3i(page,floori(pos.x/GROUND_CHUNK),floori(pos.z/GROUND_CHUNK)) if chunk_ground else page
   var chunk_origin=Vector3(batch_key.y*GROUND_CHUNK,0,batch_key.z*GROUND_CHUNK) if chunk_ground else Vector3.ZERO
   if not surfaces.has(batch_key):
    var tool=SurfaceTool.new();tool.begin(Mesh.PRIMITIVE_TRIANGLES);surfaces[batch_key]=tool
   var mesh_id=mesh.get_instance_id()
   if not floor_arrays.has(mesh_id):
    # Original flat meshes already hold these immutable arrays; avoid a GPU readback at map setup.
    var prepared_arrays:Variant=mesh.get_meta("source_surface_arrays") if mesh.has_meta("source_surface_arrays") else null
    floor_arrays[mesh_id]=prepared_arrays if prepared_arrays is Array else mesh.surface_get_arrays(0)
   var arrays:Array=floor_arrays[mesh_id]
   floor_placements+=1
   for i in arrays[Mesh.ARRAY_VERTEX].size():
    surfaces[batch_key].set_uv(arrays[Mesh.ARRAY_TEX_UV][i]);surfaces[batch_key].set_normal(arrays[Mesh.ARRAY_NORMAL][i]);surfaces[batch_key].add_vertex(pos-chunk_origin+arrays[Mesh.ARRAY_VERTEX][i])
  else:
   if not groups.has(serial):groups[serial]=[mesh,[]]
   groups[serial][1].append(Transform3D(Basis.IDENTITY,pos))
  total+=1
 if cliff_mass:cliff_art.build(root,art.placements,size_,row.bits,origin,source_id(id),crop(id).position)
 if not scoped_cliffs.is_empty():
  var context:Dictionary=scoped_cliffs.duplicate(true);context.texture=Art.page_texture(int(context.texture_page))
  var counts={}
  for p in art.placements:
   if p[4]>=cells and context.wall_tiles.has(str(p[3])):counts[str(p[3])]=int(counts.get(str(p[3]),0))+1
  if not counts.is_empty():
   var dominant=counts.keys()[0]
   for key in counts:
    if int(counts[key])>int(counts[dominant]):dominant=key
   for key in context.cap_paint:context.cap_paint[key]=context.wall_tiles[dominant]
  var visual=Node3D.new();visual.name="TrialCaveSourceCliffs"if source_id(id) in Art.FREYJA_TRIAL_IDS else"WaterCaveSourceCliffs";root.add_child(visual)
  cliff_art.build(visual,art.placements,size_,row.bits,origin,source_id(id),crop(id).position,context)
  for collider in visual.find_children("*","CollisionObject3D",true,false):collider.get_parent().remove_child(collider);collider.free()
  visual.set_meta("source_profile_count",context.profiles.size());visual.set_meta("source_flags_preserved",true)
 if source_id(id)==15526:load("res://scripts/forest/forest_sokia_gorge_art.gd").build(root,art.placements,row)
 elif source_id(id)==15525:load("res://scripts/forest/forest_sokia_cape_art.gd").build(root,art.placements,row)
 elif sokia_cave or sokia_upland:load("res://scripts/forest/forest_ruby_region_art.gd").build_cave_walls(root,source_id(id))
 if source_id(id) in [4200,4201]:TinaGround.water_backing(root,row)
 var ground_materials={}
 if prepared_ground!=null:assert(floor_placements==int(prepared_ground.get_meta("source_floor_placements")),"Prepared continental ground no longer matches the source placements")
 for batch_key in surfaces:
  var page:int=batch_key.x if batch_key is Vector3i else int(batch_key)
  var mesh=surfaces[batch_key].commit()
  if mesh==null:continue
  if not ground_materials.has(page):
   var material:Material
   if elsa_floor!=null and page>=elsa_floor.PAGE_OFFSET:material=Forms.Source.material(elsa_floor.texture(page,source_id(id)))
   elif page<=-1000:material=load("res://scripts/forest/forest_elsa_scenery.gd").sky_material(art.textures[-1000-page])
   elif page==-2:material=JenovaVillageArt.floor_material()
   elif page==-3:material=AbanisVillageArt.ground_material(AbanisVillageArt.GROUND)
   elif page==-1:material=TinaGround.floor_material(source_id(id),origin)
   else:
    material=Forms.Source.material(TinaGround.texture if page==-1 else art.textures[page])
    if not sokia_fixed.is_empty():material=material.duplicate();material.set_shader_parameter("original_palette",true)
   ground_materials[page]=material
  var chunk_origin=Vector3(batch_key.y*GROUND_CHUNK,0,batch_key.z*GROUND_CHUNK) if batch_key is Vector3i else Vector3.ZERO
  var ground_batch=Geo.mesh(root,mesh,chunk_origin,ground_materials[page]);ground_batch.name="RecoveredShalenaGround"
  ground_batch.set_meta("original_ground_batch",true)
 for key in groups:
  var serial:int=key.x if key is Vector2i else key
  var chunks={};var span=Forms.Boxes.CHUNK_SIZE
  for pose:Transform3D in groups[key][1]:
   var chunk=Vector2i(floori(pose.origin.x/span),floori(pose.origin.z/span))
   if not chunks.has(chunk):chunks[chunk]=[]
   chunks[chunk].append(pose)
  for chunk in chunks:
   var node=MultiMeshInstance3D.new();node.name="RecoveredShalenaSolid_%d_%d_%d"%[serial,chunk.x,chunk.y]
   node.position=Vector3(chunk.x*span,0,chunk.y*span);node.set_meta("source_graphic",serial)
   node.multimesh=MultiMesh.new();node.multimesh.transform_format=MultiMesh.TRANSFORM_3D;node.multimesh.mesh=groups[key][0];node.multimesh.instance_count=chunks[chunk].size()
   for i in chunks[chunk].size():
    var pose:Transform3D=chunks[chunk][i];pose.origin-=node.position
    node.multimesh.set_instance_transform(i,pose)
   root.add_child(node)
 Meadow.batch(root,"leafy_shrub",shrubs,true)
 Meadow.batch(root,"flowers_ivory",flowers,true)
 for key:Vector2i in trees:
  if key.y==1:load("res://scripts/forest/forest_frostpass_art.gd").snowy_grove(root,trees[key],key.x,"RecoveredShalenaTrees")
  elif key.y==3:Meadow.batch(root,Meadow.crossgate_tree(key.x),trees[key],true,0.,sokia.tree_color(key.x))
  else:Meadow.batch(root,Meadow.crossgate_tree(key.x),trees[key],true)
 WestScenery.build(root,str(source_id(id)),null,func(cell):return UniversityRouteArt.contains(source_id(id),Vector2i(cell)))
 UniversityRouteArt.build(root,source_id(id),crop(id).position,origin,size_,row.bits,art.placements)
 if id>=59500 and id<59800:load("res://scripts/forest/forest_elsa_scenery.gd").build(root,id,origin)
 if source_id(id) in [4000,400,402,4300,4400,14000,14001,14002,15522]:AbanisVillageArt.cliff_finish(root)
 if source_id(id)==400:
  var at=source_point(id,Vector2i(135,333))
  load("res://scripts/forest/forest_beast_castle.gd").build(root,Vector3(at.x,0,at.y))
 if id==16513:
  var at=source_point(id,Vector2i(14,6))
  var stone=load("res://scripts/forest/forest_travel_stone_art.gd").crystal(root,Vector3(at.x,0,at.y))
  stone.name="BeastReturnStone";stone.set_meta("source_appearance",103011)
 if source_id(id)==43700:EastAnnexes.build_supports(root,source_id(id),row)
 if id==31954:EastCastle.build(root,31954,row)
 if mouse_statue!=null:
  var statue=MeshInstance3D.new();statue.name="RecoveredSourceMouseStatue";statue.mesh=mouse_statue.mesh()
  var at=source_point(id,Vector2i(224,55));statue.position=Vector3(at.x,0,at.y);root.add_child(statue)
  statue.set_meta("source_mouse_statue",33608);statue.set_meta("replaced_unique_bg_tuples",186)
 root.set_meta("recovered_source_map",source_id(id));root.set_meta("recovered_source_placements",source_count);root.set_meta("recovered_solid_placements",total)
 root.set_meta("recovered_floor_placements",floor_placements);root.set_meta("recovered_floor_array_reads",floor_arrays.size())
 root.set_meta("recovered_floor_batches",surfaces.size()+(prepared_ground.get_child_count() if prepared_ground!=null else 0))
 root.set_meta("recovered_floor_cache",prepared_ground!=null)
 root.set_meta("recovered_source_path",row.get("native_path","generated:region") if generated().owns(id) else path_for(id,seed_))
 root.set_meta("recovered_floor_openings",cut_floor.keys())
 root.set_meta("recovered_porch_floor_patches",porch_fills.map(func(p):return [p[5],p[3]]))
 var center=origin+(Vector2(size_)-Vector2.ONE)*1.5
 if snow:
  var bed=Node3D.new();bed.name="RecoveredSnowBed";root.add_child(bed)
  var boxes=Forms.Boxes.new();var material=load("res://scripts/forest/forest_stone_fort.gd").material(Color("deebf2"),false)
  for z in size_.y:
   var start=-1
   for x in range(size_.x+1):
    if x<size_.x and not cut_floor.has(Vector2i(x,z)):
     if start<0:start=x
     continue
    if start<0:continue
    boxes.add(Vector3(origin.x+(start+x-1)*1.5,-.13,origin.y+z*3),Vector3((x-start)*3,.20,3),material);start=-1
  boxes.build(bed)
  frost.cave_walls(root,id,row.bits)
  frost.cave_mass(root,id,row.bits,winter.snow_maze(id,seed_).rocks)
 if regional_floor and not row.get("native_template",false) and row.branch!="scientist" and not generated().SPECS[row.branch].get("outdoor",false):
  var context={"size":size_,"origin":origin,"doors":row.doors,"stage":4 if row.frozen else 2,"frozen":row.frozen,"snow_cover":.8 if row.frozen else 0.0}
  frost.cave_walls(root,id,row.bits,context)
  frost.cave_mass(root,id,row.bits,row.rocks,context)
  if generated().SPECS[row.branch].get("sokia",false):load("res://scripts/forest/forest_sokia_cape_art.gd").generated_paint(root)
 var steps=preload("res://scripts/forest/forest_elsa_hall_steps.gd")
 var entry_steps=source_id(id)==59530 and steps.owns(59530)
 if entry_steps:steps.entry_ground(root,origin,size_)
 else:
  var ground=Solids.solid(root,Vector3(center.x,-1,center.y),Vector3(size_.x*3,2,size_.y*3),1,"stone")
  ground.set_meta("original_map_ground",true);ground.name="RecoveredShalenaPhysicalGround"
 var bottom=float(steps.data(59530).steps.grid.heights.min())-2. if entry_steps else 0.
 var boundary_top=maxf(8.5,float(steps.data(59530).steps.grid.heights.max())+8.5) if entry_steps else 8.5
 var collisions=boundaries(root,row.bits,size_,origin,row.raw,bottom,boundary_top)
 if source_id(id)==31900:load("res://scripts/forest/forest_east_prop_camera.gd").apply(root,31900,row)
 Art.finish_page_uploads()
 return collisions

static func boundaries(root:Node3D,bits:PackedByteArray,size_:Vector2i,origin:Vector2,raw:PackedByteArray=PackedByteArray(),bottom:float=0.,top:float=8.5)->Array[AABB]:
 var walls:Array[AABB]=[]
 for along_x in [true,false]:
  var rows=size_.y if along_x else size_.x;var columns=size_.x if along_x else size_.y
  for row in range(rows+1):
   var start=-1
   for column in range(columns+1):
    var edge=false
    if column<columns:
     var a=Vector2i(column,row-1) if along_x else Vector2i(row-1,column)
     var b=Vector2i(column,row) if along_x else Vector2i(row,column)
     edge=open(bits,size_,a)!=open(bits,size_,b)
    if edge and start<0:start=column
    if edge or start<0:continue
    var p=origin+(Vector2((start+column-1)*1.5,row*3-1.5) if along_x else Vector2(row*3-1.5,(start+column-1)*1.5))
    var extent=Vector3((column-start)*3,top-bottom,.04) if along_x else Vector3(.04,top-bottom,(column-start)*3)
    var center=Vector3(p.x,(top+bottom)*.5,p.y)
    var body=Solids.solid(root,center,extent,1,"stone");body.name="RecoveredShalenaBoundary_%d"%walls.size()
    WaterCamera.record(root,body,raw,bits,size_,along_x,row,start,column)
    walls.append(AABB(center-extent*.5,extent));start=-1
 return walls
