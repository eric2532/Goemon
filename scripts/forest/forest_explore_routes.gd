extends RefCounted
## Explicit Explore transfers bypass requirements without running quest scripts.
static var catalog:Dictionary={}
static var fields:Dictionary={}
# Restore removed field links and the cliff-obstructed Imur stair using complete existing destinations.
const RESTORED_FIELD_SITES=[410,16501,47010]
const ACTIONS={
 "beast_entry":[16510,25,20],"beast_grayson":[16511,26,65],
 "beast_monk_room":[16514,12,17],"beast_witch_room":[16515,10,17],"beast_witch_exit":[16512,39,52],
 "east_priest":[14003,9,42],"ice_entrance":[15536,15,15],"abyss_approach":[15531,49,32],
 "doctor_ghoul":[15531,29,51],"doctor_bars":[15531,22,35],
 "prison_flag":[20001,26,32],"altar_priest":[401,26,186],
 "azure_wall":[4403,31,38],"book_research":[4402,21,13],"music_secret":[4432,24,12],
 "curse_password":[15006,31,22],"curse_master_entry":[15012,10,19],
 "astia_entry":[14010,7,34],"four_beast_memory":[32183,26,33],
 "decree_cellar":[4331,7,3],"decree_past":[4332,10,5],"decree_present":[4335,14,7],
 "decree_shanti":[5014,8,6],"decree_shanti_return":[24074,20,26],
 "cabin_return":[402,81,191],"ruby_reward":[20508,45,47],"prison_complete":[1530,15,6],
 "abanis_teleport":[1522,37,4],"jenova_teleport":[1522,15,4],
 "tina_child_return":[4200,38,46],"decree_return":[402,53,162],
}
const ALTERNATIVES={"white_messenger":[[1530,15,6],[15522,40,8]],"black_messenger":[[1530,15,6],[15531,46,28]],"curse_master_entry":[[15012,10,19],[15011,10,19]]}
static func data()->Dictionary:
 if catalog.is_empty():catalog=JSON.parse_string(FileAccess.get_file_as_string("res://assets/maps/falan/explore-access.json"))
 return catalog.routes

static func field_cell_clear(source:int,cell:Vector2i)->bool:
 var region=load("res://scripts/forest/forest_east_region.gd");region.data()
 var buckets:Dictionary=region.automatic_by_source.get(source,{})
 var bucket=Vector2i(floori(float(cell.x)/8.),floori(float(cell.y)/8.))
 for y in range(-1,2):
  for x in range(-1,2):
   for trigger in buckets.get(bucket+Vector2i(x,y),[]):
    if trigger.type!="Warp"or not trigger.has("bounds"):continue
    var b:Array=trigger.bounds
    if Rect2i(b[0],b[1],b[2]-b[0]+1,b[3]-b[1]+1).grow(1).has_point(cell):return false
 return true

static func field_destination(source:int,cell:Vector2i)->Dictionary:
 var tour=load("res://scripts/forest/forest_falan_tour.gd");var region=load("res://scripts/forest/forest_east_region.gd")
 if source==100:cell=region.field_arrival(cell)
 var areas=[region.source_area(source,cell)]
 areas.append_array(["east_gate","north_coast","freyja","south_gate","west_lakes","south_lakes","east_coast"]if source==100 else["sokia_coast","sokia_desert","ghana_road","ghana_north_road"])
 for area in areas:
  if not fields.has(area):
   var layout:Dictionary=tour.Regions.layout(area)
   var terrain=load("res://scripts/forest/forest_model.gd").create_terrain(layout.terrain_source,float(layout.get("terrain_scale",1.)),float(layout.get("map_expansion",1.)),bool(layout.get("raised_castle",false)),str(layout.get("terrain_detail","")),area)
   terrain.configure(layout.get("ramparts",[]))
   fields[area]={"image":terrain.mask_image(),"origin":terrain.mask_origin(),"terrain":terrain}
  var row:Dictionary=fields[area];var at:Vector2=tour.Regions.frame(area).inverse()*(Vector2(cell)*3.)
  if source==300 and tour.Regions.Sokia.Data.BLOCKS[area].any(func(rect):return rect.has_point(cell)):continue
  var candidates=[at]
  for radius in [1.5,3.,4.5,6.]:
   for direction in 16:candidates.append(at+Vector2.from_angle(direction*TAU/16.)*radius)
  for point in candidates:
   var arrival_cell=Vector2i(((tour.Regions.frame(area)*point)/3.).round())
   if not field_cell_clear(source,arrival_cell):continue
   if source==300:
    var source_cell=Vector2i(((tour.Regions.frame(area)*point)/3.).round())
    if tour.Regions.Sokia.Data.BLOCKS[area].any(func(rect):return rect.has_point(source_cell)):continue
   var pixel=Vector2i(((point-row.origin)/3.).round())
   if not Rect2i(Vector2i.ZERO,row.image.get_size()).has_point(pixel):continue
   var color:Color=row.image.get_pixelv(pixel)
   if color.a<.5 or color.r>=.5 or color.b>=.98:continue
   if not row.terrain.disk_clear(Vector3(point.x,0,point.y),.65):continue
   return {"area":area,"arrival":point}
 return {}

static func complete_destination(source:int)->bool:
 var maps=load("res://scripts/forest/forest_original_maps.gd");var id:int=maps.runtime_id(source)
 if not maps.owns(id)or maps.generated().owns(id)or maps.Beast.owns(id):return true
 var row:Dictionary=maps.Art.data().maps[maps.path_for(id)]
 if row.has("layout_complete"):return row.layout_complete
 if row.has("restored_raw")and row.has("completion_reference")and int(row.get("reference_compared_cells",-1))==int(row.get("recorded",-2)):return true
 return int(row.get("recorded",0))==int(row.get("cells",-1))

static func can_travel(game,source:int,cell:Vector2i)->bool:
 if not complete_destination(source):return false
 if source in [100,300]:return not field_destination(source,cell).is_empty()
 if source==15531 and cell==Vector2i(49,32):cell=load("res://scripts/forest/forest_university_region.gd").landing_cell(source,cell,Vector2i.RIGHT,game.model.seed_value)
 return load("res://scripts/forest/forest_east_region.gd").can_travel_source(game,source,cell)

static func travel(game,source:int,cell:Vector2i)->bool:
 if source==15531 and cell==Vector2i(49,32):cell=load("res://scripts/forest/forest_university_region.gd").landing_cell(source,cell,Vector2i.RIGHT,game.model.seed_value)
 if source not in [100,300]:return load("res://scripts/forest/forest_east_region.gd").travel_source(game,source,cell,true)
 var target=field_destination(source,cell)
 if target.is_empty():return false
 var tour=game.FalanTour;var layout:Dictionary=tour.outdoor_layout(game.get_tree().get_meta("falan_venture"),target.area)
 if game.get_tree().has_meta("falan_exit"):game.get_tree().remove_meta("falan_exit")
 game.transitioning=true;tour.travel.call_deferred(game,layout,{"arrival":target.arrival,"yaw":game.camera_rig.yaw,"velocity":Vector3.ZERO,"preserve_checkpoint":true})
 return true

static func destination_title(source:int)->String:
 var hubs={1000:"法蘭城",1500:"里謝里雅堡",100:"芙蕾雅",300:"索奇亞",2000:"伊爾村",2400:"亞留特村",2100:"維諾亞村",2300:"聖拉魯卡村",3200:"奇利村",3000:"迦納村",1522:"啟程之間",1530:"召喚之間",1541:"豪華屋"}
 if hubs.has(source):return hubs[source]
 var tour=load("res://scripts/forest/forest_falan_tour.gd");var maps=tour.Winter.Recovered;var id:int=maps.runtime_id(source)
 if maps.owns(id):return maps.title(id)
 var row:Dictionary=maps.Art.data().maps.get(maps.path_for(id),{})
 if not row.is_empty():return row.title
 return tour.Regions.Sites.TITLES.get(id,tour.Indoor.layout(id).get("title","通路"))

static func candidates(game)->Array:
 var region=load("res://scripts/forest/forest_east_region.gd");var tour=game.FalanTour;var maps=tour.Winter.Recovered
 var model=game.model;var source:int=maps.source_id(model.falan_floor) if model.falan_area=="interior" else {"city":1000,"castle":1500,"east_gate":100,"north_coast":100,"sokia_coast":300,"sokia_desert":300,"ghana_road":300,"ghana_north_road":300}.get(model.falan_area,-1)
 if model.falan_area in tour.SouthPopulation.FREYJA_AREAS:source=100
 if model.falan_area in region.SOURCE_VILLAGES.values():source=int(tour.Regions.Sites.VILLAGES[model.falan_area][0])
 region.data()
 var rows:Array=data().get(str(source),[]).duplicate()
 if model.falan_area in ["east_gate","north_coast"]:rows.append_array(data().get("2000" if model.falan_area=="east_gate" else "2400",[]))
 var result=[]
 if source in[100,300]:
  for site in tour.Regions.Sites.SITES:
   if int(site[2])not in RESTORED_FIELD_SITES or tour.Regions.canonical_area(site[0])!=model.falan_area:continue
   var entry:Array=[int(site[2]),site[6]]if int(site[2])in[410,47010]else tour.Dungeons.ENTRANCES[int(site[2])]
   var target=int(entry[0])
   var info=tour.Indoor.floor_info(target,model.seed_value)
   var landing=Vector2i(((entry[1]-info[1])/3.).round())
   if not can_travel(game,target,landing):continue
   var threshold:Vector2=tour.Regions.frame(model.falan_area).inverse()*site[4]
   # Imur's original stair is sealed by the cliff turn; use its verified road-side ground.
   var at:Vector2=threshold+Vector2(0,12)if int(site[2])==47010 else threshold
   result.append({"at":at,"target":target,"landing":landing,"actor":"native-arena:"+str(site[2]),"caption":destination_title(target),"exclude_trigger":Rect2(threshold-Vector2.ONE*2.15,Vector2.ONE*4.3)})
 if source in[100,300]:
  var generated=maps.generated()
  for key in generated.SPECS:
   var spec:Dictionary=generated.SPECS[key]
   if int(spec.entry[0])!=source:continue
   var cell:Vector2i=region.prepare_field_entry(key,model.seed_value)if source==100 and spec.get("east",false)else generated.entry_cell(key,model.seed_value)
   var at:Vector2=region.source_point(source,cell,model.falan_area)
   if not model.terrain.mask_bounds().has_point(at):continue
   var first:int=generated.floor_id(key,1);var row:Dictionary=maps.state(first,model.seed_value)
   var landing=Vector2i(((generated.landing(first,model.seed_value,true)-row.origin)/3.).round())
   if model.get_meta("falan_links",[]).any(func(link):return int(link.get("floor",-1))==first and link.at.distance_squared_to(at)<9.*9. and not restricted(link)):continue
   result.append({"at":at,"target":first,"landing":landing,"actor":"generated:"+key,"caption":spec.title})
 for row in rows:
  if row.get("access_owner","")=="falan_travel_stones":continue
  if row.get("victory_only",row.get("type","")=="StandEnemy"):continue
  if row.get("type","")=="Warp":
   var fields=row.script.split("|",true)
   if not row.get("explore_inline",false)and fields.size()>4 and fields[4]=="15" and region.can_travel_source(game,int(row.target),Vector2i(row.landing[0],row.landing[1])):continue
  var cell=Vector2i(row.cell[0],row.cell[1])
  var at:Vector2=region.source_point(int(row.source),cell,model.falan_area)
  if int(row.source)in[100,300]and not model.terrain.mask_bounds().has_point(at):continue
  var target=int(row.target);var landing=Vector2i(row.landing[0],row.landing[1])
  if not can_travel(game,target,landing):continue
  var runtime:int=maps.runtime_id(target)
  # Poka stands below the level-gated ledge; its upper stair cannot replace his player-side transfer.
  var below_ledge=int(row.source)==36003 and str(row.actor)=="306085"
  var expected_arrival:Vector2=region.source_point(target,landing,model.falan_area)
  if not below_ledge and model.get_meta("falan_links",[]).any(func(link):
   if int(link.get("floor",link.get("site",-1)))!=runtime or link.at.distance_squared_to(at)>=9.*9. or restricted(link):return false
   # A same-map door may return to the near side of a wall instead of crossing the quest barrier.
   return runtime!=model.falan_floor or link.get("source_arrival",link.get("arrival",Vector2.INF)).distance_squared_to(expected_arrival)<.25
  ):continue
  if below_ledge:at+=Vector2(0,6)
  var gate={"at":at,"target":target,"landing":landing,"actor":row.actor,"caption":destination_title(target)}
  if below_ledge:gate.caption+=" · 上層通道"
  var bucket=Vector2i(floori(float(cell.x)/8.),floori(float(cell.y)/8.))
  for trigger in region.automatic_by_source.get(int(row.source),{}).get(bucket,[]):
   if str(trigger.actor)!=str(row.actor)or trigger.type=="StandEnemy"or not trigger.has("bounds"):continue
   var bounds:Array=trigger.bounds
   var a:Vector2=region.source_point(int(row.source),Vector2i(bounds[0],bounds[1]),model.falan_area)
   var b:Vector2=region.source_point(int(row.source),Vector2i(bounds[2],bounds[3]),model.falan_area)
   gate.exclude_trigger=Rect2(a.min(b)-Vector2.ONE*1.5,(a-b).abs()+Vector2.ONE*3.).grow(.65)
  result.append(gate)
 for entry in game.explorer_npcs.actors:
  if not is_instance_valid(entry.get("node")):continue
  var record:Dictionary=entry.node.get_meta("npc_record",{})
  var action:String=record.get("quest_action","")
  var destinations:Array=ALTERNATIVES.get(action,[]).duplicate()
  var destination:Array=ACTIONS.get(action,[])
  if action.begins_with("ice:"):
   destination=preload("res://assets/maps/falan/university_region/ice_events.gd").EVENTS.get(action.trim_prefix("ice:"),{}).get("target",[])
  if not destination.is_empty() and destination not in destinations:destinations.append(destination)
  for transfer in destinations:
   var target=int(transfer[0]);var cell=Vector2i(transfer[1],transfer[2])
   if not can_travel(game,target,cell):continue
   var at=Vector2(entry.node.global_position.x,entry.node.global_position.z)/model.falan_scale
   result.append({"at":at,"target":target,"landing":cell,"actor":str(record.id).trim_prefix("source:"),"caption":destination_title(target)})
 if model.falan_area=="interior"and maps.source_id(model.falan_floor)==4417:
  for entry in tour.university_npcs(4431):
   var record:Dictionary=entry[4]
   if record.get("quest_action","")!="music_secret":continue
   var destination:Array=ACTIONS.music_secret;var cell=Vector2i(destination[1],destination[2])
   if can_travel(game,int(destination[0]),cell):result.append({"at":maps.source_point(model.falan_floor,Vector2i(record.cell[0],record.cell[1])),"target":int(destination[0]),"landing":cell,"actor":str(record.id),"caption":destination_title(int(destination[0]))})
 for link in model.get_meta("falan_links",[]):
  var falcon_seal=model.falan_floor==23000 and link.get("floor",-1)==23003 or model.falan_floor==tour.Falken.ROOM and link.get("floor",-1)==tour.Falken.ROOM and link.at==tour.Falken.point(tour.Falken.ROOM,Vector2i(25,27))
  if not restricted(link)and not falcon_seal:continue
  var target:int=link.get("floor",link.get("site",-1))
  if target<0 or not link.has("arrival"):continue
  var info:Array=tour.Indoor.floor_info(target,model.seed_value)
  var cell=Vector2i(((link.arrival-info[1])/3.).round())+(maps.crop(target).position if maps.owns(target)else Vector2i.ZERO)
  if not can_travel(game,maps.source_id(target),cell):continue
  # Keep the original boss/seal cell visible; the Explore bypass sits beside it.
  var frontage:Vector2=link.at+Vector2(-9.,0.)if link.get("beast_guardian",false)else link.at
  result.append({"at":frontage,"target":maps.source_id(target),"landing":cell,"actor":"restricted_door","caption":str(tour.Indoor.layout(target).get("title",destination_title(maps.source_id(target))))})
 var groups={}
 for gate in result:groups.get_or_add(str(gate.actor)+":"+str(gate.target),[]).append(gate)
 for group_ in groups.values():
  var landings=[];var low=Vector2i(2147483647,2147483647);var high=-low
  for gate in group_:
   if gate.landing not in landings:landings.append(gate.landing)
   low=low.min(gate.landing);high=high.max(gate.landing)
  if landings.size()<2:continue
  var horizontal=high.x-low.x>=high.y-low.y
  landings.sort_custom(func(a,b):return a.x<b.x if horizontal else a.y<b.y)
  for gate in group_:
   var side=landings.find(gate.landing)
   gate.caption+=" · "+("中央入口" if side>0 and side<landings.size()-1 else ("西側入口"if horizontal else"北側入口")if side==0 else("東側入口"if horizontal else"南側入口"))
 return result

static func restricted(link:Dictionary)->bool:
 for key in["region_battle","region_stamps","region_needs","decree_needs_blade","decree_guardians","beast_guardian","falken_route","elsa_blocked","explore_gate_only"]:
  if not link.has(key):continue
  var value=link[key]
  if value is String and value.is_empty():continue
  if value is bool and not value:continue
  if value is int and value<=0:continue
  return true
 return false
