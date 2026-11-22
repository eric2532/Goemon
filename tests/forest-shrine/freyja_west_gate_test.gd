extends SceneTree

const Document=preload("res://scripts/forest/forest_map_document.gd")
const Tour=preload("res://scripts/forest/forest_falan_tour.gd")
const PatrolData=preload("res://assets/maps/falan/freyja_patrol_data.gd")
const Fixture="res://tests/forest-shrine/reference/maps/forest_freyja_west_gate.json"
var failures=0

func _initialize():
 run.call_deferred()

func check(ok:bool,message:String):
 if not ok:
  failures+=1
  printerr(message)

func run():
 var doc=Document.new(false)
 var error=doc.read_file(Fixture)
 check(error.is_empty(),error)
 if failures:quit(1);return
 check(doc.play_error().is_empty(),"Freyja's saved approach can be explored")
 var round_trip=Document.new(false)
 check(round_trip.decode(doc.encode()).is_empty() and round_trip.data==doc.data,"Freyja must survive save/load")
 var model=Document.Model.new()
 model.reset(42,{},doc.data,false)
 check_survival(model)
 check_open_arches(model)
 check_frontier(model,"freyja",[Vector2(3,165),Vector2(-9,174),Vector2(-15,177),Vector2(-30,174)])
 check_road_arrivals(model,Vector3(-120,6,246))
 var terrain=model.terrain
 for z in range(63,151):
  var center=Vector3(3,6,z)
  check(terrain.height(3,z)==6.0 and terrain.disk_clear(center,.7),"Bridge support is missing at %d" % z)
 var moat=Vector3(-24,0,105)
 check(terrain.submerged(moat) and not terrain.disk_clear(moat,.7),"Moat must not support land units")
 check(terrain.submerged(Vector3(42,1,222)),"The archived west landing is cut off by water")
 check(terrain.submerged(Vector3(3,1,240)),"The original inlet stays open where the causeway was removed")
 var chart=preload("res://scripts/forest/forest_falan_chart.gd").new()
 chart.refresh(model)
 var bridge_pixel=Vector2i((Vector2(3,105)-chart.bounds.position)/3.0)
 check(chart.texture.get_image().get_pixelv(bridge_pixel).is_equal_approx(chart.STONE),"The map shows the walkable deck over the moat")
 var resized=doc.data.duplicate(true)
 resized.map_expansion=1.5
 check(not Document.validate(resized).is_empty(),"A terrain detail cannot be stretched")
 var standard=Document.new(false)
 check(standard.load_wind_meadow().is_empty() and not standard.data.has("terrain_detail"),"Wind Meadow still loads its regular terrain")
 var venture=doc.data.duplicate(true)
 venture.falan_areas={}
 for area in ["city","castle","east_gate","south_gate"]:
  var test_map=Document.new(false)
  var prefix="freyja_" if area.ends_with("_gate") else "falan_"
  error=test_map.read_file("res://tests/forest-shrine/reference/maps/forest_"+prefix+area+".json")
  check(error.is_empty(),error)
  if not error.is_empty():continue
  venture.falan_areas[area]=test_map.data
  check(test_map.data.falan_area==area and test_map.play_error().is_empty(),"Falan area survives the normal map loader")
  model.reset(42,{},test_map.data,false)
  check_survival(model)
  if area.ends_with("_gate"):check_open_arches(model)
  if area=="east_gate":
   check(model.terrain.contains(42,222),"The archived east landing continues on land")
   check_frontier(model,area,Tour.Frontier.Gates.EXTERIORS[area].route)
   check_route(model,area,[Vector2(3,163),Vector2(3,171),Vector2(-3,183),Vector2(-3,195),
    Vector2(-9,207),Vector2(-30,231),Vector2(-54,249),Vector2(-66,249),Vector2(-87,285),
    Vector2(-99,288),Vector2(-123,282),Vector2(-135,276),Vector2(-159,276)])
   check_road_arrivals(model,Vector3(3,6,246))
  if area=="south_gate":
   check(model.terrain.submerged(Vector3(-33,1,177)) and model.terrain.contains(39,198),
    "The South Gate road curves inland around the archived inlet")
   check_frontier(model,area,[Vector2(3,165),Vector2(3,171),Vector2(12,183),Vector2(24,195),Vector2(36,204),
    Vector2(48,210),Vector2(60,216),Vector2(108,216),Vector2(120,222),Vector2(132,228),Vector2(144,237),
    Vector2(141,249),Vector2(135,261),Vector2(135,309),Vector2(141,321),Vector2(138,333),
    Vector2(126,345),Vector2(54,417),Vector2(45,426),Vector2(54,435)])
   check_route(model,area,[Vector2(258,123),Vector2(258,144),Vector2(255,156),Vector2(243,159),
    Vector2(219,171),Vector2(195,165),Vector2(183,156),Vector2(147,153),
    Vector2(135,159),Vector2(126,183),Vector2(90,207),Vector2(78,219)])
   check_road_arrivals(model,Vector3(84,6,254))
  if area=="city":
   var paving:Texture2D=load("res://assets/maps/falan/city_paving_index.png")
   check(paving.get_size()==model.terrain.mask_texture().get_size(),"City paving matches the archived terrain grid")
   var street_art=preload("res://scripts/forest/forest_falan_streets.gd")
   check(street_art.Data.FOUNTAINS.size()==2 and not street_art.Data.PARAPETS.is_empty(),"City restores both fountains and canal parapets")
   var forts=Document.Model.CityFortifications
   var blocks=forts.obstacles()
   var raw_city=JSON.parse_string(FileAccess.get_file_as_string(test_map.path))
   var garden=model.falan_garden_plan
   var garden_data=Document.Model.CityGardens.Data
   var market=preload("res://scripts/forest/forest_falan_shopfronts.gd")
   var shops=market.match_shops(model,Tour.links(model,self)).values()
   var civic=Document.Model.CivicExterior
   var civic_boxes:Array[AABB]=[]
   for anchor in civic.SHELLS:
    var spec=civic.shell(anchor,model.props[anchor])
    check(not spec.is_empty(),"The civic shell replaces the matching archived placeholder")
    civic_boxes.append(model.scenery_obstacles[anchor])
   check(civic_boxes.size()==9 and civic_boxes[0].size.x>35.0 and civic_boxes[3].get_center().x==36.0
    and civic_boxes[4].get_center().x==-67.5 and civic_boxes[5].get_center().x==7.5 and civic_boxes[6].get_center().x==-231.0 and civic_boxes[7].get_center().x==-252.0 and civic_boxes[8].get_center().x==66.0,
    "The cathedral, hospitals, mansion, bank, inn, guild hall, employment office and oval arena use their archived plots")
   check(shops.size()==12 and market.PROFILES.keys().all(func(id):return id in shops),
    "Archive shop signs stay attached to the buildings with matching indoor doors")
   check(garden_data.MARKET_GOODS.filter(func(row):return row[1] in [10053,10056,10057]).size()==4,
    "Keep the source produce displays at both market corners")
   check(not blocks.is_empty() and model.props.size()+forts.Data.LEGACY_FORTS.size()+garden_data.LEGACY_SHRUBS.size()==raw_city.props.size(),
    "City replaces only the old fort and garden placeholders")
   check(model.trees.size()+garden_data.LEGACY_TREES.size()==raw_city.trees.size()
    and garden.trees.size()>340 and garden.hedges.size()>420 and garden.rails.size()>850,
    "City gardens restore the mixed canopy, hedges and iron fences")
   check(garden.statues.any(func(item):return item[1]==10462)
    and garden.ornaments.any(func(item):return item[1] in [17237,17238,17239,17240]),
    "City parks retain the mounted statue and crescent ornaments")
   for at:Vector2 in garden_data.LILY_TILES:
    check(model.terrain.submerged(Vector3(at.x,0,at.y)),"Original lily tiles are covered by the garden pond")
   var bed:PackedFloat32Array=model.terrain.mesh_heights()
   for deck:Rect2 in forts.BRIDGES:
    var at=deck.get_center()
    var tile=Vector2i(model.terrain.coordinate(at.x,at.y).round())
    check(bed[tile.y*model.terrain.width+tile.x]<model.terrain.WATER_HEIGHT
     and model.terrain.bridge_at(at.x,at.y) and model.terrain.disk_clear(Vector3(at.x,6,at.y),.7),
     "City bridge leaves water below the traversable deck at "+str(at))
   for entry in Tour.NPCS.AREAS.city+Tour.Indoor.Data.DOORS[1000]:
    var at:Vector2=entry[0]
    var standing=Vector3(at.x,6.5,at.y)
    check(not blocks.any(func(box):return box.grow(.5).has_point(standing))
     and not garden.obstacles.any(func(row):return row[0].grow(.5).has_point(standing))
     and not civic_boxes.any(func(box):return box.grow(.5).has_point(standing)),
     "City scenery leaves the original NPCs and building entrances clear at "+str(at))
  if area=="castle":
   var court=Document.Model.Courtyard
   check(court.Data.ANNEXES.size()==7 and court.FOUNTAINS.size()==2,"Castle courtyard restores all seven annexes and both fountains")
   for npc in Tour.NPCS.AREAS.castle:
    var at:Vector2=npc[0]
    var point=Vector3(at.x,6.5,at.y)
    check(not court.obstacles().any(func(box):return box.has_point(point)),"Keep the castle NPC's original position clear: "+npc[2])
  var spawn=model.cell_of(Tour.spawn(model,Vector2i(0,3))/model.falan_scale)
  for link in Tour.LINKS[area]:
   var threshold=model.cell_of(Vector3(link.at.x,0,link.at.y))
   check(not model.route(spawn,threshold).is_empty(),"Falan passage must be reachable: "+str(link.at))
  var expected=78 if area=="city" else 19 if area=="castle" else 0
  check(Tour.NPCS.AREAS.get(area,[]).size()==expected,"Keep all Magic Power NPC placements in "+area)
 var encoded_venture=JSON.stringify(venture)
 check_outlying(venture)
 var parsed_venture=JSON.parse_string(encoded_venture)
 check(round_trip.decode(encoded_venture).is_empty() and round_trip.data.get("falan_areas")==parsed_venture.falan_areas,"One save retains all four linked layouts")
 var broken=venture.duplicate(true)
 broken.falan_areas.city.falan_area="castle"
 check(not Document.validate(broken).is_empty(),"A linked area cannot load the wrong destination")
 var npc_count=0
 for npcs in Tour.NPCS.AREAS.values():npc_count+=npcs.size()
 check(npc_count==373,"Keep the full archived NPC roster in its original areas")
 check(Tour.Indoor.Data.DOORS[1000].size()==50,"Keep the archived city building entrances")
 for id in Tour.Indoor.Data.FLOORS:
  var layout=Tour.Indoor.layout(id)
  check(Document.validate(layout).is_empty(),"Indoor layout must load: "+str(id))
  var p=Tour.Indoor.safe_point(id,Vector2.ZERO)
  var floor_=Tour.Indoor.floor_info(id)
  var grid=Vector2i((p-floor_[1])/3.0)
  check(Tour.Indoor.open_cell(floor_[2].hex_decode(),floor_[0],grid.x,grid.y),"Indoor spawn must be walkable: "+str(id))
  var size:Vector2i=floor_[0]
  var tiles=Tour.Indoor.RoomArt.floor_tiles(id,size)
  check(tiles.size()==size.x*size.y*2 and tiles.decode_u16((grid.y*size.x+grid.x)*2)>0,"Recovered floor tiles match room dimensions: "+str(id))
  var walls=Tour.Indoor.RoomArt.wall_tiles(id,size)
  var bits:PackedByteArray=floor_[2].hex_decode()
  check(walls.size()==size.x*size.y*2,"Archived wall tiles match room dimensions: "+str(id))
  for index in range(0,walls.size(),2):
   var tile=walls.decode_u16(index)
   check(tile<=Tour.Indoor.RoomArt.Data.WALL_HEIGHTS.size(),"Archived wall face belongs to its atlas")
   if tile!=0:
    var cell=index/2
    check(not Tour.Indoor.open_cell(bits,size,cell%size.x,cell/size.x),"Archived walls stay outside walkable cells")
  for fixture in Tour.Indoor.RoomArt.Data.FIXTURES.get(id,[]):
   for z in fixture[1].y:
    for x in fixture[1].x:
     check(not Tour.Indoor.open_cell(bits,size,fixture[0].x+x,fixture[0].y+z),"Furniture leaves the archived walkable cells clear: "+str(id))
 var throne=Tour.Indoor.RoomArt.Data.FIXTURES[1511]
 var civic_rooms=Tour.Indoor.RoomArt.Data.FIXTURES
 check(civic_rooms[1101].any(func(row):return row[3]==17018)
  and civic_rooms[1103].filter(func(row):return row[2]=="inn_counter").size()==50,
  "The bar and lottery room retain their original counter runs")
 for id in [1104,1105]:
  check(civic_rooms[id].any(func(row):return row[2]=="bed" and row[3]==16040),
   "Both inn side rooms retain their original bed placement")
 check(Tour.Indoor.Data.DOORS[1101].filter(func(row):return row[1]==1102).size()==2
  and Tour.Indoor.Data.DOORS[1102].size()==5,"The inn retains both hall passages and three room doors")
 check(civic_rooms[1091].filter(func(row):return row[2]=="bank_counter").size()==12
  and civic_rooms[1091].filter(func(row):return row[2]=="bank_desk").size()==2
  and Tour.NPCS.AREAS["1091"].size()==8,
  "The employment office keeps its counters, ledgers and original NPCs")
 var guild=Tour.Indoor.RoomArt.Guild
 check(civic_rooms[1092].filter(func(row):return row[2]=="guild_counter").size()==12
  and civic_rooms[1092].filter(func(row):return row[2]=="bank_desk").size()==2
  and guild.Data.GUILD_DETAILS.filter(func(row):return row[1]==17534).size()==5
  and Tour.NPCS.AREAS["1092"].size()==6,
  "The guild keeps its marble counter, office desks, stools and original NPCs")
 var bank=Tour.Indoor.RoomArt.Bank
 check(civic_rooms[1121].filter(func(row):return row[2]=="bank_counter").size()==9
  and bank.Data.BANK_DETAILS.filter(func(row):return row[1]==17641).size()==14
  and civic_rooms[1121].any(func(row):return row[2]=="bank_vault")
  and Tour.NPCS.AREAS["1121"].size()==2,
  "The bank keeps its original teller line, grilles, vault and two NPCs")
 var mansion=Tour.Indoor.RoomArt.Mansion
 check(mansion.Data.MANSION_SETTEES[1301].size()==28 and mansion.Data.MANSION_SETTEES[1302].size()==12,
  "Both recital halls retain the archived audience seating")
 check(civic_rooms[1302].any(func(row):return row[2]=="mansion_piano")
  and civic_rooms[1303].filter(func(row):return row[2]=="mansion_stair").size()==3
  and civic_rooms[1304].any(func(row):return row[2]=="mansion_desk")
  and civic_rooms[1305].any(func(row):return row[2]=="mansion_desk"),
  "The recital room, gallery and both studies retain their distinct fixtures")
 for id in mansion.STAGES:
  model.reset(42,{},Tour.Indoor.layout(id),false)
  var at=Vector2(-86,0) if id==1301 else Vector2(-31,1.5)
  check(model.surface_height(at.x,at.y)>.8 and model.surface_height(0,0)==0,
   "The raised recital stage shares its height with the room floor")
 await check_mansion_stairs()
 var arena=Tour.Indoor.RoomArt.Arena
 check(arena.Data.ARENA_MARKS.size()==6 and arena.Data.ARENA_STAIRS[1401].size()>150
  and arena.Data.ARENA_FLOWERS.size()>50,"The arena keeps the colored inlays, stair runs and garden borders")
 model.reset(42,{},Tour.Indoor.layout(1401),false)
 check(is_equal_approx(model.surface_height(3,123),2.72) and is_equal_approx(model.surface_height(3,-129),1.44),
  "The two arena floors have separate raised platforms")
 check(Tour.links(model,self).any(func(link):return link.at==arena.MAIN_LINK and link.arrival==arena.SIDE_LINK)
  and Tour.Indoor.safe_point(1401,arena.SIDE_LINK)==arena.SIDE_LINK,
  "The side ring is reachable with a walkable arrival")
 for id in arena.ANNEX_RETURNS:
  model.reset(42,{},Tour.Indoor.layout(id),false)
  check(Tour.links(model,self).any(func(link):return link.get("floor")==1424 and link.get("exit",false)),
   "Arena annex has a return route to its corridor")
 check(civic_rooms[1202].filter(func(row):return row[2]=="civic_pew").size()==37
  and civic_rooms[1202].filter(func(row):return row[2]=="civic_reredos").size()==2,
  "The cathedral nave retains its original rows and both altar screens")
 check(civic_rooms[1111].filter(func(row):return row[2]=="bed").size()==7
  and civic_rooms[1112].filter(func(row):return row[2]=="bed").size()==5
  and (civic_rooms[1111]+civic_rooms[1112]).filter(func(row):return row[2]=="civic_screen").size()==3,
  "The hospitals retain all 12 beds and three privacy screens")
 check(throne.filter(func(row):return row[2]=="royal_stool").size()==5,"Throne dais retains its five original stools")
 model.reset(42,{},Tour.Indoor.layout(1511),false)
 check(is_equal_approx(model.surface_height(-6,0),.675) and is_equal_approx(model.surface_height(-18,0),1.35),"Throne floor height follows the stair and dais")
 set_meta("falan_exit",{"to":"castle","arrival":Vector2(-18,0),"yaw":0.0,"at":Vector2(45,3),"entry_floor":1520})
 model.reset(42,{},Tour.Indoor.layout(1521),false)
 var upstairs=Tour.links(model,self)
 check(upstairs.any(func(link):return link.at==Vector2(90,3) and link.floor==1520 and link.to=="interior"),"Upper landing returns to the entry hall")
 check(not upstairs.any(func(link):return link.get("exit",false)),"Upper landing has no shortcut to the courtyard")
 remove_meta("falan_exit")
 var room_art=Tour.Indoor.RoomArt
 for id in [1522,1530,1531]:
  var floor_=Tour.Indoor.floor_info(id)
  var bits:PackedByteArray=floor_[2].hex_decode()
  check(not room_art.Data.CELLAR_STAIRS[id].is_empty(),"Recover stair markers from underground map "+str(id))
  for row in room_art.Data.CELLAR_STAIRS[id]:
   check(Tour.Indoor.open_cell(bits,floor_[0],row[0].x,row[0].y),"A recovered step stays on the original walkable route")
 check(room_art.Data.FIXTURES[1530].filter(func(row):return row[2]=="moon").size()==3,"Cellar retains all three crescent monuments")
 model.reset(42,{},Tour.Indoor.layout(1530),false)
 check_survival(model)
 check(is_equal_approx(model.surface_height(-12,0),1.12) and is_zero_approx(model.surface_height(0,0)),"Cellar shrine is raised above its passage")
 model.reset(42,{},Tour.Indoor.layout(1522),false)
 check(is_zero_approx(model.surface_height(36,0)) and is_equal_approx(model.surface_height(18,0),.96),"Lower gallery retains its recessed floor")
 print("FREYJA_WEST_GATE_RESULT failures=",failures)
 quit(1 if failures else 0)

func check_mansion_stairs():
 for id in [1301,1303]:
  var room=Node3D.new()
  root.add_child(room)
  Tour.Indoor.build(room,id)
  await physics_frame
  await physics_frame
  var space=room.get_world_3d().direct_space_state
  var shift=Vector3(21,0,-15) if id==1301 else Vector3.ZERO
  var entrance=PhysicsRayQueryParameters3D.create(Vector3(24,1,-2.7)+shift,Vector3(21.5,1,-2.7)+shift,1)
  check(space.intersect_ray(entrance).is_empty(),"The archive wall leaves the stair entrance clear")
  for sample:Vector3 in [Vector3(18,1.4,-2.7),Vector3(13.6,2.8,-2.7),Vector3(10.5,2.8,-2.7),Vector3(10.5,2.8,-7.52),Vector3(10.5,5.05,-15.3)]:
   var point=sample+shift
   var ray=PhysicsRayQueryParameters3D.create(point+Vector3.UP*.2,point-Vector3.UP*.2,1)
   var hit=space.intersect_ray(ray)
   check(not hit.is_empty() and absf(hit.position.y-point.y)<.06,"The staircase supports walking at "+str(point))
  room.free()

func check_outlying(venture:Dictionary):
 var regions=Tour.Regions
 var models={}
 for area in ["freyja","east_gate","south_gate"]+regions.Data.REGIONS.keys():
  var layout:Dictionary
  if area=="freyja":layout=venture
  elif regions.Data.REGIONS.has(area):layout=regions.layout(area)
  else:layout=venture.falan_areas[area]
  var error=Document.validate(layout)
  check(error.is_empty(),"Invalid Freyja region "+area+": "+error)
  var model=Document.Model.new()
  model.reset(42,{},layout,false)
  models[area]=model
  if regions.Data.REGIONS.has(area) and area not in ["sokia_desert","ghana_road","ghana_north_road"]:
   var minimum=1 if area=="sokia_coast" else 41
   check(model.falan_frontier_plan.size()>=minimum,"Archived foliage loads in "+area)
  if area in ["west_lakes","east_coast","south_lakes"]:
   model.start_wave()
   fill_patrols(model,Vector3.ZERO)
   var skins=patrol_skins(model)
   var expected:Dictionary={"west_lakes":[0,1,2,5],"east_coast":[0,1,2,3,4,11,16,17,24,27],"south_lakes":[0,1,2,11,12,17,18,24]}
   check(skins.size()==expected[area].size() and expected[area].all(func(skin):return skins.has(skin)),
    "The far fields use their local encounter groups: "+area)
 for link in regions.Data.LINKS:
  var axis:int=link[2]
  var step=Vector2.ZERO
  step[axis]=link[3]
  for outward in [true,false]:
   var source:String=link[0] if outward else link[1]
   var destination:String=link[1] if outward else link[0]
   var center=Vector2.ZERO
   center[axis]=link[4] if outward else link[4]-link[3]*9.0
   center[1-axis]=link[5]
   var direction=step if outward else -step
   var inverse:Transform2D=regions.frame(source).inverse()
   var before=inverse*(center-direction)
   var after=inverse*(center+direction)
   var crossing=regions.crossings(source,before,after)
   check(crossing.get("area","")==destination,"Outlying road joins "+source+" to "+destination)
   if crossing.is_empty():continue
   check_route(models[source],source,[before,after])
   var arrival:Vector2=crossing.arrival
   var mapped:Vector2=regions.frame(destination).inverse()*(center+direction*4.0)
   check_route(models[destination],destination,[arrival,mapped])
   check(absf(models[source].surface_height(after.x,after.y)-models[destination].surface_height(arrival.x,arrival.y))<.1,
    "The road height matches where "+source+" meets "+destination)
 check_freyja_sites(models)

func check_freyja_sites(models:Dictionary):
 var regions=Tour.Regions
 var villages={}
 for area in regions.Sites.VILLAGES:
  var layout=regions.layout(area)
  check(Document.validate(layout).is_empty(),"Valid recovered village "+area)
  var model=Document.Model.new()
  model.reset(42,{},layout,false)
  villages[area]=model
  check(model.falan_frontier_plan.size()>10,"Village retains its buildings and trees: "+area)
 var count=0
 for area in models:
  for site in regions.site_links(area):
   count+=1
   var here:Vector2=site.at
   check_route(models[area],area,[here,here-site.direction])
   var village=regions.village_area(site.site)
   var arrival:Vector2=site.arrival
   if not village.is_empty():
    check_route(villages[village],village,[arrival,arrival])
   else:
    check(Document.validate(Tour.Indoor.layout(site.site)).is_empty()
     and Tour.Indoor.safe_point(site.site,arrival)==arrival,"Cached destination entrance is open: "+site.title)
 check(count==35,"Freyja entrances, both Kili and Ghana gates, and the Black Prayer and graveyard routes are present")

func check_frontier(model,area:String,route:Array):
 var frontier=Tour.Frontier
 var seam=Vector2(3,frontier.INNER_EDGE[area])
 var city=frontier.to_city(area,seam)
 check(frontier.from_city(area,city).is_equal_approx(seam),"The gate frame round trips: "+area)
 check(frontier.OUTSIDE_ARRIVAL[area].y>seam.y and frontier.from_city(area,frontier.CITY_ARRIVAL[area]).y<frontier.OUTER_EDGE[area],
  "The archived landings clear both crossing triggers: "+area)
 check(model.falan_frontier_plan.size()>25,"Countryside scenery fits on dry ground: "+area)
 check_route(model,area,route)

func check_route(model,area:String,route:Array):
 for i in range(1,route.size()):
  var start:Vector2=route[i-1]
  var end:Vector2=route[i]
  var steps=maxi(1,ceili(start.distance_to(end)/2))
  for j in range(steps+1):
   var p=start.lerp(end,float(j)/steps)
   var at=Vector3(p.x,model.surface_height(p.x,p.y)+.1,p.y)
   check(model.terrain.disk_clear(at,.6) and not model.scenery_obstacles.values().any(func(box):return box.grow(.6).has_point(at)),
    "Main countryside road is walkable: "+area+" "+str(p))

func check_road_arrivals(model,outside:Vector3):
 var frontier=Tour.Frontier
 var area:String=model.falan_road
 model.waves.tick(60.0,Vector3(3,6,170)*model.falan_scale)
 check(model.enemies.is_empty(),"Waiting at the gate does not spawn enemies: "+area)
 model.waves.tick(.9,outside*model.falan_scale)
 check(model.enemies.is_empty(),"The road gives the player time before the first arrival: "+area)
 model.waves.tick(.2,outside*model.falan_scale)
 check(model.enemies.size()==(3 if area=="east_gate" else 1),"The road releases its configured patrol pack: "+area)
 check(model.enemies.values().all(func(enemy):return enemy.skin in [0,1,24] and enemy.pos.z>frontier.COMBAT_EDGE*model.falan_scale),"First arrivals use beginner creatures beyond the safe gate approach: "+area)
 fill_patrols(model,outside)
 var skins=patrol_skins(model)
 check(skins.has(0) and skins.has(1),"Bats and goblins remain on each city approach: "+area)

func fill_patrols(model,outside:Vector3):
 for i in model.waves.patrol_posts.size()+1:model.waves.tick(12.0,outside*model.falan_scale)
 print("FALAN_PATROL_COUNT ",model.terrain.variant," ",model.enemies.size())
 check(model.enemies.size()>=floori(mini(model.waves.patrol_posts.size(),model.waves.ACTIVE_CAP)*.75) and model.enemies.size()<=mini(model.waves.patrol_posts.size(),model.waves.ACTIVE_CAP),
  "Patrols fill separated land posts up to the area cap")
 check(model.enemies.values().all(func(enemy):return enemy.level>=1 and enemy.hp==enemy.max_hp and is_equal_approx(enemy.hp,model.waves.Patrols.STATS.hp*enemy.health_scale)),
  "Outdoor patrols spawn at their species and area level with matching native HP scaling")
 var roles=model.waves.Patrols.Roles
 check(model.waves.role_stats(roles.SLIME).damage==30.0,"The native patrol profile uses 30 base damage")
 var frame=Tour.Regions.frame(model.terrain.variant)
 var image:Image=model.terrain.mask_texture().get_image()
 var origin:Vector2=model.terrain.mask_origin()
 var bandits_clear=true
 for post:Vector4i in model.waves.patrol_posts:
  var cell=Vector2i(post.x,post.y)
  var source:Array=model.waves.MapEncounters.ZONES[post.w]
  check(source[0].has_point(cell) and (int(source[1]) & (1<<post.z))!=0,"Post is inside its reference zone and uses an original encounter member")
  if post.z!=2:continue
  var local:Vector2=frame.inverse()*(Vector2(cell)*3)
  var pixel=Vector2i(((local-origin)/3).round())
  for z in range(-12,13):
   for x in range(-12,13):
    var at=pixel+Vector2i(x,z)
    if x*x+z*z<169 and Rect2i(Vector2i.ZERO,image.get_size()).has_point(at) and image.get_pixelv(at).g>=.56:
     bandits_clear=false
 check(bandits_clear,"Bandit posts have at least 39 metres of clearance from painted roads")
 if model.terrain.variant=="east_coast":
  for anchor in [Vector4i(562,220,4,1022),Vector4i(690,285,3,1026)]:
   check(model.enemies.values().any(func(row):
    return row.skin==anchor.z and (frame*(Vector2(row.pos.x,row.pos.z)/model.falan_scale)).distance_to(Vector2(anchor.x,anchor.y)*3)<.1),
    "A patrol spawns beside the reported Blue CG shoreline tile "+str(Vector2i(anchor.x,anchor.y+1)))

func patrol_skins(model)->Dictionary:
 var skins={}
 for enemy in model.enemies.values():skins[enemy.skin]=true
 return skins

func check_survival(model):
 check(model.survival_run and model.shrine().is_empty() and not model.occupancy.has(Vector2i.ZERO),"Falan loads without a shrine or its footprint")
 check(model.start_wave(),"Play starts without a shrine")
 model.damage_building(1,1000000.0)
 check(model.phase=="wave","The retired shrine ID cannot end the run")

func check_open_arches(model):
 var arches=model.buildings.values().filter(func(building):return building.kind=="gate")
 check(arches.size()==2,"Both ends of each Freyja crossing retain a stone entrance")
 for building in arches:
  check(building.get("freyja_arch",false) and building.get("door_removed",false),"Crossings stay permanently open")
  check(not model.close_repaired_gate(building.id),"Open stone entrances have no door to repair")
  var visual=Tour.Indoor.Art.building(building)
  check(visual.find_child("GateDoor",true,false)==null,"Freyja stone entrance has no moving leaf")
  visual.free()
