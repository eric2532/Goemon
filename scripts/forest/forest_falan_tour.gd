extends RefCounted
const Winter=preload("res://scripts/forest/forest_frostpass.gd")
const Elsa=preload("res://scripts/forest/forest_elsa_route.gd")
const Falken=preload("res://scripts/forest/forest_falken_route.gd")
const Prayer=preload("res://scripts/forest/forest_black_prayer.gd")
## Saved outdoor links and archived interior doorways share the existing map loader.
const Frontier=preload("res://scripts/forest/forest_falan_frontier.gd")
const Regions=Frontier.Regions
const Document=preload("res://scripts/forest/forest_map_document.gd")
const Architecture=preload("res://scripts/forest/forest_falan_architecture.gd")
const Houses=preload("res://scripts/forest/forest_falan_houses.gd")
const TITLES={
 "freyja":"Freyja West Gate - Test",
 "east_gate":"Freyja East Gate - Test",
 "south_gate":"Freyja South Gate - Test",
 "city":"Falan City - Test",
 "castle":"Falan Castle - Test"
}
const Indoor=preload("res://scripts/forest/forest_falan_interior.gd")
const Dungeons=Indoor.Dungeons
const Captain=preload("res://scripts/forest/crowd/captain_sprites.gd")
const Grave=preload("res://scripts/forest/crowd/grave_sprites.gd")
const Ruby=preload("res://scripts/forest/crowd/ruby_boss_sprites.gd")
const RubyEvents=preload("res://scripts/forest/forest_black_prayer_events.gd")
const Habitable=["falan_townhouse","falan_shop","falan_chapel","falan_royal_keep"]
const NPCS=preload("res://assets/maps/falan/npc_data.gd")
const VillageNPCs=preload("res://assets/maps/falan/freyja_npc_data.gd")
const VillageAtlas=preload("res://assets/maps/falan/freyja_npc_atlas.png")
const SouthPopulation=preload("res://scripts/forest/forest_south_kili_population.gd")
const SnowPopulation=preload("res://scripts/forest/crowd/snow_region_sprites.gd")
const ATLAS=preload("res://assets/maps/falan/npc_atlas.png")
static var university_population:Dictionary={}
static var elsa_population:Dictionary={}
const WALK_IN_RADIUS=2.1
const LINKS={
 "freyja":[{"at":Vector2(3,153),"to":"city","arrival":Frontier.CITY_ARRIVAL.freyja,"yaw":0.0,"facing":Vector3.FORWARD}],
 "east_gate":[{"at":Vector2(3,159),"to":"city","arrival":Frontier.CITY_ARRIVAL.east_gate,"yaw":PI,"facing":Vector3.BACK}],
 "south_gate":[{"at":Vector2(3,153),"to":"city","arrival":Frontier.CITY_ARRIVAL.south_gate,"yaw":PI*.5,"facing":Vector3.LEFT}],
 "city":[{"at":Vector2(-138,393),"to":"freyja","arrival":Frontier.OUTSIDE_ARRIVAL.freyja,"yaw":PI,"facing":Vector3.BACK},
         {"at":Vector2(-138,-384),"to":"east_gate","arrival":Frontier.OUTSIDE_ARRIVAL.east_gate,"yaw":PI,"facing":Vector3.BACK},
         {"at":Vector2(321,0),"to":"south_gate","arrival":Frontier.OUTSIDE_ARRIVAL.south_gate,"yaw":PI,"facing":Vector3.BACK},
         {"at":Vector2(-102,0),"to":"castle","arrival":Vector2(105,0),"yaw":PI*.5},
         {"at":Vector2(-138,-36),"to":"castle","arrival":Vector2(-9,-54),"yaw":PI},
         {"at":Vector2(-138,36),"to":"castle","arrival":Vector2(-9,54),"yaw":0.0},
         {"at":Vector2(-192,0),"to":"castle","arrival":Vector2(-117,0),"yaw":-PI*.5}],
 "castle":[{"at":Vector2(126,0),"to":"city","arrival":Vector2(-93,0),"yaw":-PI*.5},
           {"at":Vector2(-9,-72),"to":"city","arrival":Vector2(-138,-51),"yaw":0.0},
           {"at":Vector2(-9,72),"to":"city","arrival":Vector2(-138,45),"yaw":PI},
           {"at":Vector2(-126,0),"to":"city","arrival":Vector2(-198,0),"yaw":PI*.5}]
}
# Face the first corridor when a cave doorway lands close to a wall.
const CAVE_FACING={
 11000:{Vector2(-30,-78):-PI*.5,Vector2(-30,57):-PI*.5,Vector2(-66,-90):-PI*.5,Vector2(-60,-87):PI*.5,Vector2(-45,-72):-PI*.5},
 11001:{Vector2(-18,-108):PI*.5,Vector2(-48,93):PI*.5},
 11002:{Vector2(-12,72):PI*.5,Vector2(15,-90):PI*.5,Vector2(-60,57):-PI*.5},
 11022:{Vector2(33,-72):PI*.5,Vector2(45,39):PI*.5},
 13001:{Vector2(-171,-57):PI*.5,Vector2(174,3):PI*.5},
 15003:{Vector2(57,48):0.0},
 15004:{Vector2(27,-36):PI,Vector2(-12,57):PI*.5},
 15005:{Vector2(-15,-60):PI},
 11003:{Vector2(-48,36):-PI*.5,Vector2(48,-51):PI},
 11004:{Vector2(66,45):PI*.5,Vector2(-72,-117):PI},
 11005:{Vector2(15,-63):PI*.5,Vector2(-12,42):0.0},
 15592:{Vector2(51,-36):PI,Vector2(-54,-36):PI},
 15593:{Vector2(135,12):PI*.5,Vector2(-129,-36):PI},
 15594:{Vector2(-24,-63):PI,Vector2(30,33):PI},
 410:{Vector2(39,33):PI*.5},
 15505:{Vector2(45,-57):PI},
 47017:{Vector2(-54,111):PI*.5},
 16500:{Vector2(0,30):0.0,Vector2(0,-21):PI},
 16501:{Vector2(42,27):PI*.5},
 16502:{Vector2(42,27):PI*.5,Vector2(-42,-54):PI},
 16503:{Vector2(27,48):PI*.5,Vector2(-9,-12):PI},
 16504:{Vector2(-9,-3):0.0},
 16505:{Vector2(-9,3):0.0,Vector2(-15,-12):PI},
 16516:{Vector2(-84,69):-PI*.5,Vector2(18,-78):PI*.5,Vector2(66,24):PI*.5},
 16517:{Vector2(36,-6):PI,Vector2(-9,-105):PI,Vector2(99,21):PI*.5,Vector2(-9,-108):PI},
 16518:{Vector2(-9,-108):PI,Vector2(99,21):PI*.5,Vector2(-9,57):0.0},
 16519:{Vector2(-9,57):0.0,Vector2(-75,-129):PI*.5},
}
const STARTS={"freyja":Vector2i(0,28),"east_gate":Vector2i(0,29),"south_gate":Vector2i(0,28),"city":Vector2i(-39,-18),"castle":Vector2i(17,0)}

static func area(model)->String:
 return "freyja" if model.terrain_detail==Document.Model.FreyjaTerrain.ID else model.falan_area

static func spawn(model,default_:Vector2i)->Vector3:
 if model.falan_area=="interior":
  var p=Indoor.safe_point(model.falan_floor,Vector2.ZERO,model.seed_value)
  return model.world_point(p,.15)
 if Regions.has_land(model.falan_area):
  var p=Regions.entry_point(model.falan_area)
  return model.world_point(p,.15)
 return model.point(STARTS.get(area(model),default_))*model.falan_scale+Vector3.UP*.15

static func links(model,tree:SceneTree)->Array:
 var current=area(model)
 var result=LINKS.get(current,[]).duplicate(true)
 result.append_array(load("res://scripts/forest/forest_sokia_scenery.gd").branch_links(model))
 result.append_array(Elsa.stone_links(current,model.falan_floor))
 result.append_array(Falken.links(current,model.falan_floor,Regions.frame("sokia_desert"),model.seed_value))
 if current=="city":
  for stone in preload("res://assets/maps/falan/travel_stone_data.gd").STONES:
   result.append({"at":stone[2],"to":"city_stone","caption":"E · "+stone[0]})
 if tree!=null and tree.has_meta("falan_venture"):
  var winter_links=Winter.links(current,model.falan_floor,model.seed_value)
  if model.falan_floor==Winter.Decree.PAST and tree.get_meta(Winter.Decree.BLADE,false):
   winter_links=winter_links.filter(func(link):return link.to!="decree_blade")
  result.append_array(winter_links)
  result.append_array(Regions.site_links(current).filter(func(site):return site.site not in [2000,2400]))
  var joined=model.get_meta("joined_village") if model.has_meta("joined_village") else null
  if joined!=null:
   var placement=Regions.village_transform(joined.falan_area)
   for original in links(joined,tree):
    if original.to!="freyja_door":continue
    var door=original.duplicate()
    door.at=placement*original.at
    door.village=joined.falan_area
    result.append(door)
  var return_site:Dictionary=tree.get_meta("freyja_site_return",{})
  if not Indoor.Original.owns(model.falan_floor) and current not in ["alyut","kili","ghana"] and not Regions.Sites.CAVE_EXITS.has(model.falan_floor) and not Dungeons.EXITS.has(model.falan_floor) and return_site.get("room","")==current and (current!="interior" or return_site.get("floor",-1)==model.falan_floor):
   var caption="Back to South Road" if current=="venoa" else "Back to Freyja"
   var exit_at:Vector2=return_site.inside
   if Regions.ROAD_GATES.has(current):
    exit_at=village_door(model,Regions.ROAD_GATES[current][0]+(Vector2(0,1.5) if current=="laruka" else Vector2.ZERO))
   result.push_front({"at":exit_at,"to":"freyja_return","caption":caption,"door":true})
 var map_id=1000 if current=="city" else 1500 if current=="castle" else model.falan_floor if current=="interior" else -1
 if tree!=null and tree.has_meta("falan_venture"):
  if Regions.Sites.VILLAGES.has(current):map_id=Regions.Sites.VILLAGES[current][0]
  for row in ([] if Indoor.Original.owns(map_id) and Indoor.Original.source_id(map_id) in Indoor.Original.EastIndex.FIXED else Regions.Sites.DOORS.get(map_id,[])):
   var target:int=row[1]
   if map_id==15003 and target==Ruby.ROOM:continue # Source6302 owns the candle/solo transfer.
   if map_id==Ruby.ROOM and target in [15003,3350,3351,3353]:continue
   if map_id==3350 and target==3352 or map_id==3351 and target==3350:continue # Source6306/6310 supply the guarded/original destinations.
   if map_id==Indoor.Ladder.CHAMBER and target==Indoor.Ladder.BASEMENT:continue
   if Dungeons.EXITS.has(map_id) and target not in [Ruby.ROOM,Captain.MEMORIAL]:continue
   var point:Vector2=row[0] if current=="interior" else village_door(model,row[0])
   var title:String=Dungeons.TITLES.get(target,Regions.Sites.TITLES.get(target,"Back to Village"))
   if map_id==11000 and target==11000:title="Miners' Gate"
   var diamond=(map_id==15003 and target==Ruby.ROOM) or (map_id==Ruby.ROOM and target==15003)
   if map_id==15003 and target==Ruby.ROOM:title="Suspicious Rock · Black Prayer"
   var arrival:Vector2=row[2]
   if map_id==15003 and target==Ruby.ROOM:
    target=Prayer.ENTRY
    arrival=Vector2(-9,-15)
   result.append({"at":point,"to":"freyja_door","floor":target,"arrival":arrival,
    "caption":""+title,"door":true,"diamond":diamond})
  result.append_array(Prayer.links(map_id,model.seed_value))
  if current=="alyut":
   for row in Regions.Sites.ALYUT_EXITS:
    var at=Regions.ALYUT_SOUTH_GATE if row[0].y>0 else Regions.ALYUT_NORTH_GATE
    result.append({"at":village_door(model,at),"to":"freyja_outside",
     "area":"north_coast","arrival":Regions.frame("north_coast").inverse()*row[1],
     "caption":"Back to North Coast","door":true})
  if current=="kili":
   for i in Regions.Sites.KILI_EXITS.size():
    var row:Array=Regions.Sites.KILI_EXITS[i]
    result.append({"at":village_door(model,row[0]),"to":"freyja_outside",
     "area":"sokia_coast","arrival":Regions.frame("sokia_coast").inverse()*row[1],
     "crossing":true,
     "caption":"West Gate" if i==0 else "East Gate","door":true})
  if current=="ghana":
   for row in Regions.Sites.GHANA_EXITS:
    result.append({"at":village_door(model,row[0]),"to":"freyja_outside","area":row[1],
     "arrival":Regions.frame(row[1]).inverse()*row[2],"caption":""+row[3]+" · Sokia","door":true})
  var east_owned:bool=Indoor.Original.owns(map_id) and Indoor.Original.source_id(map_id) in Indoor.Original.EastIndex.FIXED
  var exits:Array=[] if east_owned else Dungeons.EXITS.get(map_id,[])
  if exits.is_empty() and not east_owned and Regions.Sites.CAVE_EXITS.has(map_id):
   exits=[[map_id,Regions.Sites.CAVE_EXITS[map_id][0]]]
  for row in exits:
   var exit_id:int=row[0]
   var exit:Array=Regions.Sites.CAVE_EXITS[exit_id]
   var caption="Road to Kili" if map_id==13001 else "Sokia Coast" if exit[1]=="sokia_coast" else "Back to Freyja"
   if exit[1]=="ghana_north_road":caption="Return to Ghana's Graves"
   if map_id==3350:caption="Back to Sokia"
   if exit_id in [11000,11002,11003,11005,15005,15592,15594]:caption=""+Regions.Sites.TITLES[exit_id].get_slice(", ",1)
   result.append({"at":row[1],"to":"freyja_outside","area":exit[1],"exit_id":exit_id,
    "arrival":Regions.frame(exit[1]).inverse()*exit[2],"caption":caption,"door":true,"diamond":exit[3]})
  if map_id==13001:
   var east:Array=Regions.Sites.GREAT_WIND_EAST
   result.append({"at":east[0],"to":"freyja_outside","area":"sokia_desert",
    "arrival":Regions.frame("sokia_desert").inverse()*east[1],"caption":"Road to Ghana","door":true})
 for row in Indoor.Data.DOORS.get(map_id,[]):
  var target:int=row[1]
  var destination="city" if target==1000 else "castle" if target==1500 else "interior"
  var marker={"at":row[0],"to":destination,"floor":target,"arrival":row[2],"yaw":0.0,"door":true}
  if map_id==1500:marker.caption="Palace Interior" if target==1520 else "Castle Cellar"
  result.append(marker)
 if current=="city" or current=="castle" or current in ["freyja","east_gate","south_gate"]:
  var used={}
  var authored_count=result.size()
  for anchor in model.props:
   var item:Dictionary=model.props[anchor]
   if item.kind not in Habitable:continue
   if current=="city" and model.CitySpecial.retired(model,anchor):continue
   if current=="castle" and model.Courtyard.replaces_saved_scenery(item.kind,Vector2(Document.Scenery.cell(anchor))*6.0):continue
   if current=="city" and not model.CivicExterior.shell(anchor,item).is_empty():continue
   var center:Vector3=model.scenery_point(anchor)
   var centered=Houses.source_centered(model,anchor)
   if centered:
    var expected=Architecture.collision(Architecture.Data.BINDINGS[anchor][0])
    expected.position+=model.scenery_point(anchor)+Houses.offset(model,anchor)
    centered=model.scenery_obstacles[anchor].is_equal_approx(expected)
   if centered:center+=Houses.offset(model,anchor)
   var p=Vector2(center.x,center.z)
   var claimed=-1
   var best=576.0 if item.kind=="falan_royal_keep" else 225.0
   for i in authored_count:
    if used.has(i) or not result[i].get("door",false):continue
    var dist=p.distance_squared_to(result[i].at)
    if dist<best:best=dist;claimed=i
   if claimed>=0:
    used[claimed]=true
    if centered:
     result[claimed].visual_entry_graphic=Architecture.Data.BINDINGS[anchor][0]
     result[claimed].visual_entry_anchor=anchor
    continue
   var bounds:Vector3=model.scenery_obstacles[anchor].size if centered else Document.Scenery.CATALOG[item.kind].box.size*item.scale
   var angle=0.0 if centered else -deg_to_rad(item.rotation)
   var door=p+Vector2(0,bounds.z*.5+2.0).rotated(angle)
   var preferred=[]
   var graphic=0
   if centered:
    graphic=Architecture.Data.BINDINGS[anchor][0]
    var opening:Dictionary=Architecture.entry(graphic)
    for distance in [1.0,1.5,2.0,3.0,4.0]:preferred.append(opening.at+opening.direction*distance)
   var aligned=false
   var candidates=preferred+[Vector2(0,bounds.z*.5+2.0),Vector2(bounds.x*.5+2.0,0),Vector2(-bounds.x*.5-2.0,0),Vector2(0,-bounds.z*.5-2.0)]
   for offset in candidates:
    var candidate=p+offset.rotated(angle)
    if centered and model.CityGardens.Data.PLANTERS.any(func(row):return row[0].distance_squared_to(candidate)<2.60*2.60):continue
    var floor=Vector3(candidate.x,model.surface_height(candidate.x,candidate.y)+.5,candidate.y)
    if not model.terrain.disk_clear(floor,.55):continue
    if model.scenery_obstacles.values().any(func(box):return box.grow(.45).has_point(floor)):continue
    door=candidate
    aligned=preferred.has(offset)
    break
   var house={"at":door,"to":"interior","floor":0,"arrival":Vector2(0,6),"yaw":0.0,"door":true,"house_anchor":anchor}
   if centered:house.visual_entry_graphic=graphic;house.visual_entry_aligned=aligned
   result.append(house)
 if current=="interior":
  var arena=Indoor.RoomArt.Arena
  if map_id==1401:
   # The second ring shares the archived floor but has no physical connecting hall.
   result.append({"at":arena.MAIN_LINK,"to":"interior","floor":1401,"arrival":arena.SIDE_LINK,"yaw":PI,"door":true})
   result.append({"at":arena.SIDE_LINK,"to":"interior","floor":1401,"arrival":arena.MAIN_LINK,"yaw":0.0,"door":true})
  elif arena.ANNEX_RETURNS.has(map_id):
   var route:Array=arena.ANNEX_RETURNS[map_id]
   result.append({"at":Indoor.safe_point(map_id,route[0]),"to":"interior","floor":1424,"arrival":route[1],"yaw":0.0,"door":true,"exit":true})
  var outside:Dictionary=tree.get_meta("falan_exit",{})
  if outside.get("entry_floor",-1)==model.falan_floor:
   var at:Vector2=outside.at
   result=result.filter(func(link):return link.to!=outside.to or at.distance_squared_to(link.at)>=25.0)
   var exit_link=outside.duplicate()
   exit_link.at=at
   exit_link.exit=true
   result.push_front(exit_link)
 return load("res://scripts/forest/forest_east_region.gd").merge_links(model,result)

static func village_door(model,at:Vector2)->Vector2:
 var best=at
 var distance=INF
 for x in range(-3,4):
  for z in range(-3,4):
   var p=at+Vector2(x,z)*1.5
   var d=p.distance_squared_to(at)
   if d>=distance:continue
   var pos=Vector3(p.x,model.surface_height(p.x,p.y)+.5,p.y)
   if not model.terrain.disk_clear(pos,.55):continue
   if model.scenery_obstacles.values().any(func(box):return box.grow(.45).has_point(pos)):continue
   best=p;distance=d
 return best

static func build_markers(root:Node3D,model):
 if Regions.private_source_context!=null:Regions.private_source_context.build_host(root,model)
 preload("res://scripts/forest/forest_south_kili_art.gd").finish(root,model)
 preload("res://scripts/forest/forest_ruby_region_art.gd").finish(root,model)
 if area(model)=="city":load("res://scripts/forest/forest_travel_stones.gd").build(root,model)
 var private_source=Regions.private_source_context!=null and Regions.private_source_context.source_id(model)>0
 var npc_area="" if private_source else str(model.falan_floor) if model.falan_area=="interior" else model.falan_area
 var snow_rows=snow_npcs(model.falan_floor) if model.falan_area=="interior" else []
 var south_rows=[] if private_source else SouthPopulation.npcs(model)
 if not south_rows.is_empty():build_npcs(root,model,south_rows,load("res://assets/maps/falan/south_kili_route/npc-atlas.png"))
 elif not snow_rows.is_empty():build_npcs(root,model,snow_rows,load("res://assets/maps/falan/snow_region/npc-atlas.png"))
 elif NPCS.AREAS.has(npc_area):build_npcs(root,model,NPCS.AREAS[npc_area].filter(func(row):return not RubyEvents.replaces(model,row[0])),ATLAS)
 else:
  var villagers:Array=VillageNPCs.AREAS.get(npc_area,[]).duplicate()
  for source in Dungeons.NPCS.get(model.falan_floor,{}):
   var positions:Array=Dungeons.NPCS[model.falan_floor][source]
   var archived:Array=VillageNPCs.AREAS[str(source)]
   for i in positions.size():villagers.append([positions[i],archived[i][1],archived[i][2]])
  villagers=villagers.filter(func(row):return not RubyEvents.replaces(model,row[0]))
  if not villagers.is_empty():build_npcs(root,model,villagers,VillageAtlas)
 var ruby_rows=RubyEvents.rows(model)
 if not ruby_rows.is_empty():build_npcs(root,model,ruby_rows,load(RubyEvents.ROOT+"npc-atlas.png"))
 var cape_rows=load("res://scripts/forest/forest_sokia_cape.gd").npcs(model)
 if not cape_rows.is_empty():build_npcs(root,model,cape_rows,load("res://assets/maps/falan/sokia/cape/access/events/npc-atlas.png"))
 var coast_rows=SouthPopulation.sokia_npcs(model)
 if not coast_rows.is_empty():build_npcs(root,model,coast_rows,load("res://assets/maps/falan/sokia/npc-atlas.png"))
 var server_rows=SouthPopulation.server_npcs(model)
 if not server_rows.is_empty():build_npcs(root,model,server_rows,load(SouthPopulation.server_events(model.falan_floor).get("atlas_path","res://assets/maps/original_crossgate/sokia_server/"+("water/"if model.falan_floor in Winter.Recovered.Art.SOKIA_WATER_IDS else"")+"events/npc-atlas.png")))
 if model.falan_area=="interior":
  var regional_rows=university_npcs(model.falan_floor)
  if not regional_rows.is_empty():build_npcs(root,model,regional_rows,load("res://assets/maps/falan/university_region/npc-atlas.png"))
  var island_rows=elsa_npcs(model.falan_floor)
  if not island_rows.is_empty():build_npcs(root,model,island_rows,load("res://assets/maps/falan/elsa/npc-atlas.png"))
 load("res://scripts/forest/forest_east_region.gd").build_npcs(root,model)
 load("res://scripts/forest/forest_east_harbor.gd").build(root,model)
 var markers=links(model,root.get_tree())
 var current=area(model)
 var combined:Dictionary=root.get_tree().get_meta("falan_venture",{})
 if combined.has("falan_areas"):
  for link in markers:
   link.walk_in=is_walk_in(current,link)
   if model.falan_floor in Prayer.FLOORS:
    link.habaru_stair=17974 if link.at==Prayer.point(Prayer.stairs(model.falan_floor,model.seed_value)[0]) else 17975
    link.stair_uphill=Vector2.DOWN
   elif model.falan_floor in Dungeons.HABARU_FLOORS+Dungeons.VENOA_FLOORS:
    link.habaru_stair=cave_stair_at(model.falan_floor,link.at)
   elif model.falan_floor in Dungeons.UNDERSEA_FLOORS:
    link.undersea_stair=cave_stair_at(model.falan_floor,link.at)
 model.set_meta("falan_links",markers)
 if combined.has("falan_areas"):
  if Regions.GATE_FRAMES.has(current) or Regions.Data.REGIONS.has(current) or current in ["il_village","alyut"]:
   markers=markers+Regions.signs(current)
   if current=="freyja":
    markers=markers+[{"at":Regions.frame(current).inverse()*Vector2(894,444),"caption":"Sacred Tree"}]
 var island_labels={}
 for link in markers:
  # Wind's adjacent original trigger tiles share one visible mouth/caption.
  if model.falan_area=="interior" and model.falan_floor>=59500 and model.falan_floor<59800 or Regions.Sokia.owns(model.falan_area) and int(link.get("site",-1))==15564:
   var label_key=str(link.get("to",""))+":"+str(link.get("floor",0))+":"+str(link.get("caption",""))
   var shown:Array=island_labels.get(label_key,[])
   if shown.any(func(at):return at.distance_squared_to(link.at)<18.1*18.1):continue
   shown.append(link.at);island_labels[label_key]=shown
  var diamond:bool=link.get("diamond",false) or link.get("kind","")=="diamond"
  if diamond:
   var point:Vector2=link.at
   build_diamond(root,Vector3(point.x,model.surface_height(point.x,point.y),point.y))
  var label=Label3D.new()
  if link.get("to","")=="decree_blade":label.name="DecreeBladeMarker"
  label.text=Regions.Sites.TITLES.get(link.get("floor",-1),"Passage")
  if link.has("caption"):label.text=link.caption
  elif link.get("exit",false):label.text="Exit"
  elif not link.get("door",false):
   label.text=TITLES[link.to].get_slice(" - ",0)
  label.font_size=36
  label.pixel_size=.018
  label.billboard=BaseMaterial3D.BILLBOARD_ENABLED
  label.visibility_range_end=18.0 if link.get("door",false) else 35.0
  if Dungeons.roofed(model.falan_floor):
   label.pixel_size=.012
   label.visibility_range_begin=3.5
  label.modulate=Color("f5db9d")
  var height=2.7 if link.get("door",false) else 4.4
  if link.get("to","")=="city_stone":
   label.font_size=24;label.pixel_size=.012;label.visibility_range_end=12.0;height=6.7
  elif link.get("site",-1) in [11003,11005]:
   label.name="HabaruCaveLandmark"
   label.text="HABARU CAVE\n"+("To Alyut Village" if link.site==11003 else "To Il Village")
   label.font_size=48
   label.pixel_size=.022
   label.visibility_range_end=150.0
   height=8.2
  elif link.get("habaru_trail",false):
   label.name="HabaruTrailLabel_%d_%d"%[link.at.x,link.at.y]
   label.pixel_size=.014
   label.visibility_range_end=50.0
   height=3.3
  elif link.get("gate_trail",false):
   label.name="GateTrailSign_%d_%d"%[link.at.x,link.at.y]
   label.pixel_size=.014
   label.visibility_range_end=58.0
   height=3.3
  if not link.get("gate_trail",false) and SouthPopulation.owns(model) and (current in ["interior","kili"] or SouthPopulation.encounter_scope(model,link.at)):
   label.pixel_size=minf(label.pixel_size,.008)
   label.visibility_range_begin=maxf(label.visibility_range_begin,4.0)
   label.visibility_range_end=minf(label.visibility_range_end,28.0)
  if diamond:height=.7 if current=="interior" else 4.8
  var label_at:Vector2=link.at
  if link.get("site",-1) in [11002,15592]:label_at.y+=1.5
  if link.get("site",-1) in [11003,11005]:label_at-=Regions.frame(current).inverse().basis_xform(Vector2.RIGHT)*2.1
  label.position=Vector3(label_at.x,model.surface_height(label_at.x,label_at.y)+height,label_at.y)
  root.add_child(label)

static func is_walk_in(current:String,link:Dictionary)->bool:
 if link.has("elsa_stone") or link.has("elsa_event"):return false
 return link.get("door",false) or link.get("exit",false) or link.to in ["freyja_site","freyja_door","freyja_outside","freyja_return","ruby_gate","castle","interior"] or (link.to=="city" and current=="castle")

static func cave_stair_at(id:int,at:Vector2)->int:
 if id not in Dungeons.HABARU_FLOORS+Dungeons.UNDERSEA_FLOORS+Dungeons.VENOA_FLOORS:return 0
 var origin:Vector2=Indoor.floor_info(id)[1]
 for row in Indoor.RoomArt.Data.FREYJA_STAIRS.get(id,[]):
  if origin+Vector2(row[0])*3.0==at:return row[1]
 return 0

static func build_diamond(root:Node3D,point:Vector3):
 var atlas=preload("res://assets/maps/falan/freyja_yellow_diamond.png")
 var frames=SpriteFrames.new()
 frames.set_animation_speed(&"default",10.0)
 for i in 8:
  var frame=AtlasTexture.new()
  frame.atlas=atlas
  frame.region=Rect2(i*58,0,58,64)
  frames.add_frame(&"default",frame)
 var sprite=AnimatedSprite3D.new()
 sprite.name="BlueCGYellowDiamond"
 sprite.sprite_frames=frames
 sprite.billboard=BaseMaterial3D.BILLBOARD_ENABLED
 sprite.texture_filter=BaseMaterial3D.TEXTURE_FILTER_NEAREST
 sprite.pixel_size=.038
 sprite.position=point+Vector3.UP*2.68
 root.add_child(sprite)
 sprite.play()
 var glow=OmniLight3D.new()
 glow.light_color=Color("ffcf55")
 glow.light_energy=.7
 glow.omni_range=6.5
 sprite.add_child(glow)

static func cross_on_foot(game)->bool:
 var current=area(game.model)
 if current.is_empty():return false
 var position=game.player.position
 var at=Vector2(position.x,position.z)/game.model.falan_scale
 var before:Vector2=game.falan_crossing_position
 game.falan_crossing_position=at
 if game.transitioning or game.player.hp<=0 or not before.is_finite() or before.distance_squared_to(at)>64.0 or before.is_equal_approx(at):return false
 var venture:Dictionary=game.get_tree().get_meta("falan_venture",{})
 if venture.is_empty():return false
 var door:Dictionary={}
 var closest=INF
 for link in game.model.get_meta("falan_links",[]):
  if not link.get("walk_in",false) or link.get("crossing",false):continue
  # This generated entrance overlaps the original grave formation; Explore uses its explicit Cross Gate.
  if link.get("explore_gate_only",false)and is_instance_valid(game.get("explore_access"))and game.explore_access.enabled():continue
  # Use the midpoint where the original entrance has two warp tiles.
  var center:Vector2=link.at
  if link.get("site")==2100:center.y-=1.5
  elif link.get("site")==2300:center.y+=1.5
  elif link.get("site")==2400:center.x-=1.5*signf(link.arrival.y)
  elif link.get("site") in [11003,11005]:
   var back=Regions.frame(current).inverse().basis_xform(Vector2.RIGHT).normalized()
   var across=Vector2(back.y,-back.x)
   center+=across*clampf((at-center).dot(across),-3.6,3.6)
  var radius=WALK_IN_RADIUS
  var stair:int=link.get("habaru_stair",link.get("undersea_stair",0))
  if stair in [17953,17955,13269,17975] or link.get("site") in [11003,11005,15004,15005,15592,15594]:radius=.92
  elif stair>0:
   var uphill:Vector2=link.get("stair_uphill",Indoor.RoomArt.HabaruStairs.uphill(stair))
   var approach=before-center
   if approach.dot(uphill)<-absf(approach.cross(uphill))*.60:radius=.92
  var radius_sq=radius*radius
  if before.distance_squared_to(center)<=radius_sq:continue
  if Geometry2D.get_closest_point_to_segment(center,before,at).distance_squared_to(center)>radius_sq:continue
  var height:float=game.model.world_height(center.x*game.model.falan_scale,center.y*game.model.falan_scale)
  if absf(position.y-height)>2.5*game.model.falan_scale:continue
  var distance=before.distance_squared_to(center)
  if distance<closest:
   closest=distance
   door=link
 if not door.is_empty():
  if door.get("site")==16501 and Input.is_key_pressed(KEY_SHIFT):
   door=door.duplicate();door.site=16502
  return enter_link(game,current,door,at)
 var outlying=Regions.Data.REGIONS.has(current) or current=="kili"
 if current!="city" and not Frontier.FRAMES.has(current) and not outlying:return false
 var gate=current
 var arrival:Vector2
 var destination:String
 var rotation:float
 var crossing=Regions.crossings(current,before,at) if current!="city" else {}
 if not crossing.is_empty():
  return walk_into(game,venture,crossing.area,crossing.arrival,crossing.rotation)
 var source_context=Regions.private_source_context
 if source_context!=null:
  var handoff:Dictionary=source_context.scene_handoff(game,before,at)
  if not handoff.is_empty():return walk_into(game,venture,handoff.area,handoff.arrival,handoff.rotation)
 if outlying:return false
 if current=="city":
  gate=""
  for candidate in Frontier.FRAMES:
   var local=Frontier.from_city(candidate,at)
   var edge:float=Frontier.OUTER_EDGE[candidate]
   if absf(local.x-3.0)>7.0 or local.y<edge:continue
   if Frontier.from_city(candidate,before).y>=edge:continue
   gate=candidate
   arrival=local
   break
  if gate.is_empty():return false
  destination=gate
  rotation=Frontier.FRAMES[gate].get_rotation()
 else:
  var edge:float=Frontier.INNER_EDGE[gate]
  if absf(at.x-3.0)>7.0 or before.y<=edge or at.y>edge:return false
  arrival=Frontier.to_city(gate,at)
  destination="city"
  rotation=-Frontier.FRAMES[gate].get_rotation()
 return walk_into(game,venture,destination,arrival,rotation)

static func outdoor_layout(venture:Dictionary,destination:String)->Dictionary:
 if destination=="freyja":return venture
 if Regions.has_land(destination):return Regions.layout(destination)
 return venture.falan_areas[destination]

static func walk_into(game,venture:Dictionary,destination:String,arrival:Vector2,rotation:float)->bool:
 var layout=outdoor_layout(venture,destination)
 game.transitioning=true
 game.get_tree().remove_meta("falan_exit")
 var current=area(game.model)
 var link={"arrival":arrival,"yaw":game.camera_rig.yaw+rotation,
  "velocity":game.player.velocity.rotated(Vector3.UP,rotation)}
 if Regions.GATE_TRAIL.has(current) and Regions.GATE_TRAIL[current].to==destination:
  link.facing=game.player.facing.rotated(Vector3.UP,rotation)
 if current=="city" and Frontier.FRAMES.has(destination) or destination=="city" and Frontier.FRAMES.has(current):
  var exit_city=destination!="city"
  var facing:Vector3=Vector3.BACK if exit_city else Frontier.CITY_INWARD[current]
  link.arrival=Frontier.OUTSIDE_ARRIVAL[destination] if exit_city else Frontier.CITY_ARRIVAL[current]
  link.yaw=atan2(-facing.x,-facing.z)
  link.facing=facing
  link.velocity=facing*absf(link.velocity.dot(facing))
 travel.call_deferred(game,layout,link)
 return true

static func enter_link(game,current:String,link:Dictionary,p:Vector2)->bool:
 if link.has("east_source_return"):
  var target:Dictionary=link.east_source_return
  if target.map in[100,300]and is_instance_valid(game.get("explore_access"))and game.explore_access.enabled():return preload("res://scripts/forest/forest_explore_routes.gd").travel(game,int(target.map),target.cell)
  load("res://scripts/forest/forest_east_region.gd").travel_source(game,int(target.map),target.cell)
  return true
 if link.has("elsa_stone"):return Elsa.interact(game,current,link,p)
 if link.has("elsa_event"):return Elsa.open(game)
 var tree:SceneTree=game.get_tree()
 if link.get("region_hall_variant",false) and load("res://scripts/forest/forest_university_region.gd").romance_eligible(tree):
  # Source32269 is the same30×40 auditorium footprint; keep each original landing and return door.
  link=link.duplicate();link.floor=32269
 if link.has("region_battle") and not tree.get_meta("university_battles",{}).get(link.region_battle,{}).get("complete",false):
  game.toast("擊敗迪次郎才能通過坑道深層");return true
 if link.has("region_stamps") and int(tree.get_meta("university_quest_items",{}).get("signed_stamps",0))<int(link.region_stamps):
  game.toast("需要帶有五個印記的信");return true
 var regional_target:int=link.get("floor",-1)
 if regional_target>0 and Winter.Recovered.owns(regional_target) and Winter.Recovered.source_id(regional_target) in preload("res://assets/maps/falan/university_region/dungeon_specs.gd").FIXED and link.has("arrival"):
  var target_state=Winter.Recovered.state(regional_target,game.model.seed_value)
  var target_cell=Vector2i(((link.arrival-target_state.origin)/3.).round())
  if not Winter.Recovered.open(target_state.bits,target_state.size,target_cell):game.toast("出口暫時無法通行");return true
 var regional_requirement:String=link.get("region_needs","")
 if not regional_requirement.is_empty() and not tree.get_meta("university_quest_items",{}).get(regional_requirement,false):
  game.toast("這條道路需要："+{"world_heart":"世界之心","god_eye":"神眼","moon_hoe":"月之鋤頭"}.get(regional_requirement,regional_requirement))
  return true
 if link.to=="decree_blade":
  if not tree.get_meta(Winter.Decree.BLADE,false):
   tree.set_meta(Winter.Decree.BLADE,true)
   game.toast("獲得刀刃的碎片 · 前往阿巴尼斯西路的鼓動石盤")
   for name_ in ["DecreeBladeFragment","DecreeBladeMarker"]:
    var node=game.world.find_child(name_,true,false)
    if node!=null:node.hide()
   game.model.get_meta("falan_links",[]).erase(link)
  return true
 if link.get("decree_needs_blade",false) and not tree.get_meta(Winter.Decree.BLADE,false):
  game.toast("鼓動的石盤需要刀刃的碎片 · 調查阿巴尼斯村歷史學家民家")
  return true
 if link.get("decree_needs_blade",false):tree.set_meta(Winter.Decree.BLADE,false)
 if link.get("decree_guardians",false):
  if not Winter.Decree.cleared(tree.get_meta(Winter.SLAIN,{}),game.model.falan_floor,game.model.seed_value):
   game.toast("擊敗本層守護者才能解除封印")
   return true
 if link.get("beast_guardian",false) and not tree.get_meta(Winter.SLAIN,{}).has(Vector2i(Winter.Recovered.Beast.BOSS_ROOM,0)):
  game.toast("擊敗神獸史雷普尼爾才能解除封印")
  return true
 if link.get("falken_route",false) and not game.explorer_clock.night():
  game.toast("古代人民只在夜晚出現");return true
 if link.to=="falken_scroll":
  if not tree.get_meta(Falken.SCROLL,false):
   tree.set_meta(Falken.SCROLL,true);game.toast("勇者里雍：獲得解咒之法 · 從反抗軍前往羅連斯研究塔")
  return true
 if game.model.falan_floor==23000 and link.get("floor",-1)==23003 and not tree.get_meta(Falken.SCROLL,false):
  game.toast("反抗軍：先向勇者里雍（21,18）領取解咒之法");return true
 if game.model.falan_floor==Falken.ROOM and link.get("floor",-1)==23002 and not tree.get_meta(Falken.SLAIN,{}).has(Vector2i(Falken.ROOM,0)):
  game.toast("擊敗法爾肯才能進入解放的宮殿");return true
 if game.model.falan_floor==Falken.ROOM and link.get("floor",-1)==Falken.ROOM and link.at==Falken.point(Falken.ROOM,Vector2i(25,27)) and not tree.get_meta(Falken.SCROLL,false):
  game.toast("巫師耶卡：請帶來勇者里雍的解咒之法");return true
 if link.to=="ruby_gate":
  if game.model.falan_floor==Ruby.ROOM:RubyEvents.action(game,"black_prayer:6305")
  return true
 if link.to in ["freyja_site","freyja_return","freyja_door","freyja_outside"]:
  return enter_site(game,current,link,p)
 var layout:Dictionary
 if link.to=="interior":
  link=link.duplicate()
  link.arrival=Indoor.safe_point(link.floor,link.arrival,game.model.seed_value)
  if current!="interior":
   tree.set_meta("falan_exit",{"to":current,"arrival":p,"yaw":game.camera_rig.yaw,"at":link.arrival,"entry_floor":link.floor})
  layout=Indoor.layout(link.floor)
 else:
  var venture:Dictionary=tree.get_meta("falan_venture",{})
  if not venture.is_empty():
   layout=venture if link.to=="freyja" else venture.falan_areas[link.to]
  else:
   var target=Document.new(false)
   var error=target.read_file(Document.MAP_FOLDER.path_join(Document.saved_filename(TITLES[link.to])))
   if not error.is_empty():
    game.toast(error)
    return true
   layout=target.data
  tree.remove_meta("falan_exit")
 game.transitioning=true
 if link.get("walk_in",false):link=link.merged({"velocity":Vector3.ZERO})
 travel.call_deferred(game,layout,link)
 return true

static func enter_site(game,current:String,link:Dictionary,p:Vector2)->bool:
 var tree:SceneTree=game.get_tree()
 var venture:Dictionary=tree.get_meta("falan_venture",{})
 if not venture.has("falan_areas"):return false
 var layout:Dictionary
 var arrival:Vector2
 var yaw:float
 if link.to=="freyja_site":
  if int(link.site) in Indoor.Original.Art.FREYJA_TRIAL_IDS and not Indoor.Original.owns(int(link.site)):
   game.toast("Mine entrance temporarily closed.");return true
  var village=Regions.village_area(link.site)
  var room="interior" if village.is_empty() else village
  var entry:Array=Dungeons.ENTRANCES.get(link.site,[link.site,link.arrival])
  var floor_id:int=entry[0]
  arrival=Indoor.safe_point(floor_id,entry[1],game.model.seed_value) if village.is_empty() else link.arrival
  layout=Indoor.layout(floor_id) if village.is_empty() else Regions.layout(village)
  var outside=p
  if Regions.ROAD_GATES.has(village):
   var gate:Array=Regions.ROAD_GATES[village]
   outside=gate[0]+gate[1]+Vector2(3,0)
   if village=="il_village" and current=="east_gate":outside=Regions.coast_to_gate(outside)
  tree.set_meta("freyja_site_return",{"room":room,"floor":floor_id,"area":current,"inside":arrival,
   "outside":outside,"yaw":game.camera_rig.yaw})
  yaw=link.yaw
  if village=="alyut":yaw=game.camera_rig.yaw
  elif Regions.ROAD_GATES.has(village):yaw=game.camera_rig.yaw
  elif village=="kili":yaw=PI if arrival.x<0 else PI*.5
  elif village=="ghana":yaw=PI if current=="ghana_north_road" else 0.0
  if village=="il_village" and current=="east_gate":yaw+=PI*.5
 elif link.to=="freyja_door":
  if game.model.falan_floor==11004 and link.floor==11005 and Regions.canonical_area(tree.get_meta("freyja_site_return",{}).get("area",""))=="east_gate":
   if tree.get_meta("habaru_slain",{}).size()<Regions.Sites.HABARU_FORMATION.size():
    game.toast("Defeat 熊弟 and the nine bears to open the Alyut passage")
    return true
  if game.model.falan_floor==Ruby.ROOM and link.floor in [3350,3351,3353] and tree.get_meta(Ruby.SLAIN,{}).size()<Regions.Sites.RUBY_FORMATION.size():
   game.toast("Defeat Ruby and her escorts to open the way to Fengnu's House")
   return true
  if game.model.falan_floor==Captain.ROOM and link.floor==Captain.MEMORIAL and tree.get_meta(Captain.SLAIN,{}).size()<Regions.Sites.CAPTAIN_FORMATION.size():
   game.toast("Defeat the Wolf Captain and his crew to enter the memorial")
   return true
  var village=Regions.village_area(link.floor)
  layout=Indoor.layout(link.floor) if village.is_empty() else Regions.layout(village)
  arrival=Indoor.safe_point(link.floor,link.arrival,game.model.seed_value) if village.is_empty() else link.arrival
  yaw=game.camera_rig.yaw
  if link.has("village"):yaw+=Regions.village_transform(link.village).get_rotation()
  if village=="tomato_road":yaw=PI*.5 if game.model.falan_floor==1155 else -PI*.5
  elif village=="tomato_farm":yaw=PI*.25 if current=="tomato_road" else PI
  elif link.floor==Regions.Sites.TOMATO_MAPS[2]:yaw=0.0
 elif link.to=="freyja_outside":
  if link.get("exit_id")==15505 and not tree.get_meta("zombie_slain",{}).has(0):
   game.toast("Defeat the Modified Zombie to open the exit")
   return true
  if link.get("exit_id")==Grave.ROOM and not tree.get_meta(Grave.SLAIN,{}).has(3):
   game.toast("Defeat Parukes to open the exit")
   return true
  layout=outdoor_layout(venture,link.area)
  arrival=link.arrival
  yaw=0.0 if current=="interior" and link.area=="north_coast" else game.camera_rig.yaw
  if link.area=="sokia_coast":yaw=-PI*.5
  if link.area in ["sokia_desert","ghana_road"]:yaw=PI
  if link.area=="ghana_north_road":yaw=0.0
  if link.get("exit_id") in [11003,11005]:yaw=PI*.5
  tree.remove_meta("freyja_site_return")
 else:
  var exit:Dictionary=tree.get_meta("freyja_site_return",{})
  if exit.is_empty():return false
  layout=outdoor_layout(venture,exit.area)
  arrival=exit.outside
  yaw=game.camera_rig.yaw if Regions.ROAD_GATES.has(current) else exit.yaw
  if current=="il_village" and exit.area=="east_gate":yaw-=PI*.5
  tree.remove_meta("freyja_site_return")
 game.transitioning=true
 travel.call_deferred(game,layout,{"arrival":arrival,"yaw":yaw,"velocity":Vector3.ZERO})
 return true

static func travel(game,layout:Dictionary,link:Dictionary):
 var prior_checkpoint:Vector3=game.checkpoint
 if layout.get("falan_area","")=="interior":
  var phase=game.explorer_clock.phase_floor(int(layout.get("falan_floor",0)))
  if phase!=layout.get("falan_floor",0):
   layout=Indoor.layout(phase)
   link=link.duplicate();link.arrival=Indoor.safe_point(phase,link.arrival,game.model.seed_value)
 var source_area:String=layout.get("falan_area","")
 if source_area in ["il_village","alyut"] and Regions.private_source_context==null:
  var placement=Regions.village_transform(source_area)
  var host=Regions.canonical_area(source_area)
  var venture:Dictionary=game.get_tree().get_meta("falan_venture",{})
  layout=outdoor_layout(venture,host) if venture.has("falan_areas") else Regions.layout(host)
  link=link.duplicate()
  link.arrival=placement*link.arrival
  link.yaw-=placement.get_rotation()
  if link.has("velocity"):link.velocity=link.velocity.rotated(Vector3.UP,-placement.get_rotation())
 if layout.get("falan_area","")=="east_coast":
  layout=layout.duplicate(true);layout.falan_area="east_gate"
  link=link.duplicate()
  link.arrival=Regions.coast_to_gate(link.arrival)
  var rotation=Regions.frame("east_gate").get_rotation()-Regions.frame("east_coast").get_rotation()
  link.yaw+=rotation
  if link.has("velocity"):link.velocity=link.velocity.rotated(Vector3.UP,rotation)
 game.get_tree().set_meta("forest_custom_layout",layout.duplicate(true))
 var walking=link.has("velocity")
 game.preview_forest_map(layout,false,false,walking,true)
 if Regions.private_source_context!=null:Regions.private_source_context.prepare_world(game.world,game.player)
 game.falan_crossing_position=Vector2.INF
 var at:Vector2=link.arrival
 if (Regions.private_source_context==null or not Regions.private_source_context.standalone(game.model.falan_area)) and (Regions.Sites.VILLAGES.has(game.model.falan_area) or source_area in ["il_village","alyut"]):at=village_door(game.model,at)
 var stair=cave_stair_at(game.model.falan_floor,at)
 var rise=Indoor.RoomArt.HabaruStairs.RISE*.5*game.model.falan_scale if stair in [12001,17954,13268] else 0.0
 game.player.position=game.model.world_point(at,.15+rise)
 game.player.velocity=Vector3.ZERO
 game.player.reset_physics_interpolation()
 game.model.hero_position=game.player.position
 game.checkpoint=game.player.position
 if link.get("preserve_checkpoint",false):game.checkpoint=prior_checkpoint
 game.camera_rig.yaw=CAVE_FACING.get(game.model.falan_floor,{}).get(at,link.yaw)
 if link.has("facing"):
  var facing:Vector3=link.facing
  game.player.facing=facing
  game.player.model.rotation.y=atan2(-facing.x,-facing.z)
 game.transitioning=false
 if Regions.private_source_context!=null:Regions.private_source_context.arrived(game)
 game.start_wave()
 if walking:
  game.player.velocity=link.velocity
  game.camera_rig.reset_follow()


static func snow_npcs(floor_:int)->Array:
 var result=[]
 for record in SnowPopulation.data().npcs:
  if int(record.floor)!=floor_:continue
  var art:Dictionary=SnowPopulation.data().art[record.token];var r:Array=art.rect;var origin:Array=art.origin
  result.append([Winter.Recovered.source_point(floor_,Vector2i(record.cell[0],record.cell[1])),Rect2(r[0],r[1],r[2],r[3]),record.name,Vector2(float(origin[0])+float(r[2])*.5,-float(origin[1])-float(r[3])*.5),record])
 return result

static func university_npcs(floor_:int)->Array:
 if university_population.is_empty():university_population=JSON.parse_string(FileAccess.get_file_as_string("res://assets/maps/falan/university_region/population.json"))
 var result=[]
 for record in university_population.npcs:
  if int(record.floor)!=floor_:continue
  var art:Dictionary=university_population.art[record.token];var r:Array=art.rect;var origin:Array=art.origin
  result.append([Winter.Recovered.source_point(floor_,Vector2i(record.cell[0],record.cell[1])),Rect2(r[0],r[1],r[2],r[3]),record.name,Vector2(float(origin[0])+float(r[2])*.5,-float(origin[1])-float(r[3])*.5),record])
 return result

static func elsa_npcs(floor_:int)->Array:
 if floor_<59500 or floor_>=59800:return []
 if elsa_population.is_empty():elsa_population=JSON.parse_string(FileAccess.get_file_as_string("res://assets/maps/falan/elsa/population.json"))
 var result=[]
 for record in elsa_population.npcs:
  if int(record.floor)!=floor_:continue
  var art:Dictionary=elsa_population.art[record.token];var r:Array=art.rect;var origin:Array=art.origin
  result.append([Winter.Recovered.source_point(floor_,Vector2i(record.cell[0],record.cell[1])),Rect2(r[0],r[1],r[2],r[3]),record.name,Vector2(float(origin[0])+float(r[2])*.5,-float(origin[1])-float(r[3])*.5),record])
 return result

static func university_quest(game,action:String):
 if RubyEvents.action(game,action):return
 if load("res://scripts/forest/forest_sokia_cape.gd").action(game,action):return
 if action.begins_with("region_boss_"):
  load("res://scripts/forest/forest_university_region.gd").begin(game,action.trim_prefix("region_boss_"),-1,true);return
 if load("res://scripts/forest/forest_university_region.gd").action(game,action):return
 var tree:SceneTree=game.get_tree();var decree=Winter.Decree;var original=Winter.Recovered
 var target=-1;var cell=Vector2i.ZERO
 if action=="decree_strawberry":
  if not load("res://scripts/forest/forest_university_region.gd").eligible(tree,2):game.toast("需要「開啟者」與王宮階級");return
  if not tree.get_meta(decree.BLADE,false):tree.set_meta(decree.STRAWBERRY,true);game.toast("獲得野草莓 · 交給樓梯前的米希安")
 elif action=="decree_cellar":
  if not tree.get_meta(decree.STRAWBERRY,false) and not tree.get_meta(decree.BLADE,false):game.toast("米希安需要野草莓 · 先與歷史學家交談");return
  tree.set_meta(decree.STRAWBERRY,false);target=decree.CELLAR;cell=Vector2i(7,3)
 elif action=="decree_past":target=decree.PAST;cell=Vector2i(10,5)
 elif action=="decree_blade":enter_link(game,"interior",{"to":"decree_blade"},Vector2.ZERO)
 elif action=="decree_present":target=4335;cell=Vector2i(14,7)
 elif action=="lake_jump":
  target=4457
  var local=Vector2(game.player.position.x,game.player.position.z)/game.model.falan_scale
  var source_cell=Vector2i(((local-original.state(4457).origin)/3).round())
  cell=Vector2i(38,52 if source_cell.y>53 else 54)
 elif action.begins_with("decree_reward_"):
  var index=int(action.trim_prefix("decree_reward_"));var rewards:Dictionary=tree.get_meta(decree.REWARDS,{})
  if not rewards.has(index):rewards[index]=true;tree.set_meta(decree.REWARDS,rewards);game.toast("獲得聖詔 · 第%d難關"%(index+1))
 elif action=="decree_return":
  if not decree.cleared(tree.get_meta(Winter.SLAIN,{}),decree.GUARDIAN_FLOORS.back(),game.model.seed_value):game.toast("雙王的封印尚未解除");return
  tree.set_meta(decree.COMPLETE,true);target=original.SHALENA_NORTH;cell=Vector2i(53,162)
  game.toast("聖詔 · 雙王的封印已解除")
 if target>0:
  var link=original.door(Vector2.ZERO,target,original.source_point(target,cell))
  enter_link(game,"interior",link,Vector2.ZERO)

static func build_npcs(root:Node3D,model,rows:Array,atlas:Texture2D):
 var group:Node3D
 for node in root.get_children():
  if node is Node3D and node.get_meta("npc_map_area","")==model.falan_area and node.get_meta("npc_map_floor",-1)==model.falan_floor:group=node;break
 if group==null:
  group=Node3D.new();group.name="OriginalFalanNPCs"
  group.set_meta("npc_map_area",model.falan_area);group.set_meta("npc_map_floor",model.falan_floor)
  root.add_child(group)
 var textures={}
 for npc in rows:
  var pos:Vector2=npc[0]
  var rect:Rect2=npc[1]
  if not textures.has(rect):
   var texture=AtlasTexture.new()
   texture.atlas=atlas
   texture.region=rect
   texture.filter_clip=true
   textures[rect]=texture
  var sprite=Sprite3D.new()
  sprite.texture=textures[rect]
  sprite.pixel_size=.043
  sprite.billboard=BaseMaterial3D.BILLBOARD_ENABLED
  sprite.texture_filter=BaseMaterial3D.TEXTURE_FILTER_NEAREST
  sprite.alpha_cut=SpriteBase3D.ALPHA_CUT_DISCARD
  sprite.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
  sprite.visibility_range_end=85.0
  sprite.position=Vector3(pos.x,model.surface_height(pos.x,pos.y)+rect.size.y*sprite.pixel_size*.5,pos.y)
  sprite.set_meta("npc_name",npc[2])
  if npc.size()>3:
   sprite.position.y=model.surface_height(pos.x,pos.y)
   sprite.offset=npc[3]
  if npc.size()>4:
   sprite.set_meta("snow_record",npc[4]);sprite.set_meta("npc_record",npc[4])
   if npc[4].scenery and npc[4].get("rendered_elsewhere",true):sprite.transparency=1.0 # Existing solid scenery remains the visible owner.
   if int(npc[4].get("source",-1))==59520 and int(npc[4].get("graphic",-1))==110500:
    sprite.add_child(load("res://scripts/forest/forest_elsa_scenery.gd").return_stone());sprite.transparency=1.0
    sprite.set_meta("elsa_return_stone",true)
   if int(npc[4].get("source",-1))==59530 and int(npc[4].get("graphic",-1))==103010:
    var crystal=preload("res://scripts/forest/forest_travel_stone_art.gd").crystal(sprite,Vector3.ZERO)
    crystal.name="ElsaTempleReturnCrystal_"+str(npc[4].id);crystal.set_meta("source_actor",npc[4].id);sprite.transparency=1.0
    sprite.set_meta("elsa_return_stone",true);sprite.set_meta("npc_hint_height",5.5)
   if int(npc[4].get("source",-1))==300 and int(npc[4].get("graphic",-1)) in Regions.Sokia.STELES:
    var body=MeshInstance3D.new();body.name="NativeSokiaStele_"+str(int(npc[4].graphic))
    body.mesh=Regions.Sokia.stele(int(npc[4].graphic))
    # Match the existing event sprite bounds at the native camera; only add depth.
    body.scale=Vector3.ONE*(sprite.pixel_size*sqrt(2.)*Regions.Sokia.Details.Shapes.Proportions.HORIZONTAL)
    body.set_meta("source_actor",npc[4].id);sprite.add_child(body);sprite.transparency=1.0
  group.add_child(sprite)
