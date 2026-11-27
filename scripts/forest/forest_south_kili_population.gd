extends RefCounted
## Source records for the existing Explore NPC and native encounter owners.
const Snow=preload("res://scripts/forest/crowd/snow_region_sprites.gd")
const Regions=preload("res://scripts/forest/forest_freyja_regions.gd")
const Sites=preload("res://assets/maps/falan/freyja_destinations_data.gd")
const Prayer=preload("res://scripts/forest/forest_black_prayer.gd")
const ServerArt=preload("res://scripts/forest/forest_original_map_art.gd")
const SOKIA_AREAS=["sokia_coast","sokia_desert","ghana_road","ghana_north_road"]
const FREYJA_AREAS=["freyja","east_gate","south_gate","west_lakes","north_coast","south_lakes","east_coast"]
const WATER_CAVE=[13500,13501,13502]
const GORGE_CORRIDOR=15526
const CAVES=[11000,11001,11002,15005,15003,15004]
const VENOA_UNDERSEA=[15592,15593,15594]
const SERVER_ENCOUNTERS=[13509,13512]
const WATER_ENCOUNTERS=[13507,13508,13509,13511,13512,13513,13515]
static var population:Dictionary={}
static var scopes:Dictionary={}
static var coast_population:Dictionary={}
static var cape_population:Dictionary={}
static var server_population:Dictionary={}
static var server_residents:Dictionary={}
static var freyja_population:Dictionary={}
static var water_population:Dictionary={}
static var water_residents:Dictionary={}
static var trial_residents:Dictionary={}
static var desert_temple_residents:Dictionary={}
static var dragon_summit_residents:Dictionary={}
static var explore_residents:Dictionary={}
static func freyja_data()->Dictionary:
 if freyja_population.is_empty():
  freyja_population=JSON.parse_string(FileAccess.get_file_as_string("res://assets/maps/falan/freyja_residual/encounters.json"))
  assert(freyja_population.active,"Freyja source encounter publication must be coherent")
 return freyja_population
static func server_events(floor_:int=-1)->Dictionary:
 if floor_ in ServerArt.EXPLORE_RECOVERED_IDS:
  if explore_residents.is_empty():explore_residents=JSON.parse_string(FileAccess.get_file_as_string("res://assets/maps/original_crossgate/explore_recovered/events/data.json"))
  return explore_residents
 if floor_ in ServerArt.SOKIA_DRAGON_SUMMIT_IDS:
  if dragon_summit_residents.is_empty():dragon_summit_residents=JSON.parse_string(FileAccess.get_file_as_string("res://assets/maps/original_crossgate/sokia_dragon_summit/events/data.json"))
  return dragon_summit_residents
 if floor_ in ServerArt.SOKIA_DESERT_TEMPLE_IDS:
  if desert_temple_residents.is_empty():desert_temple_residents=JSON.parse_string(FileAccess.get_file_as_string("res://assets/maps/original_crossgate/sokia_desert_temple/events/data.json"))
  return desert_temple_residents
 if floor_ in ServerArt.FREYJA_TRIAL_IDS:
  if trial_residents.is_empty():trial_residents=JSON.parse_string(FileAccess.get_file_as_string("res://assets/maps/original_crossgate/freyja_trial/events/data.json"))
  return trial_residents
 if floor_ in ServerArt.SOKIA_WATER_IDS:
  if water_residents.is_empty():water_residents=JSON.parse_string(FileAccess.get_file_as_string("res://assets/maps/original_crossgate/sokia_server/water/events/data.json"))
  return water_residents
 if server_residents.is_empty():server_residents=JSON.parse_string(FileAccess.get_file_as_string("res://assets/maps/original_crossgate/sokia_server/events/data.json"))
 return server_residents
static func server_npcs(model)->Array:
 if model.falan_area!="interior" or model.falan_floor not in ServerArt.SOKIA_SERVER_IDS and model.falan_floor not in ServerArt.SOKIA_WATER_IDS and model.falan_floor not in ServerArt.FREYJA_TRIAL_IDS and model.falan_floor not in ServerArt.SOKIA_DESERT_TEMPLE_IDS and model.falan_floor not in ServerArt.SOKIA_DRAGON_SUMMIT_IDS and model.falan_floor not in ServerArt.EXPLORE_RECOVERED_IDS:return []
 var result=[];var source=server_events(model.falan_floor)
 var origin:Vector2=load("res://scripts/forest/forest_original_maps.gd").floor_info(model.falan_floor)[1]
 for original in source.actors.values():
  if int(original.source)!=model.falan_floor:continue
  if original.get("invisible",false):continue
  var record:Dictionary=original.duplicate(true);var art:Dictionary=source.art[record.token];var r:Array=art.rect;var o:Array=art.origin
  var offset=Vector2(float(o[0])+float(r[2])*.5,-float(o[1])-float(r[3])*.5)
  if art.has("body_foot"):offset.y=float(art.body_foot)-float(r[3])*.5
  result.append([origin+Vector2(record.cell[0],record.cell[1])*3.,Rect2(r[0],r[1],r[2],r[3]),record.name,offset,record])
 return result
static func server_data()->Dictionary:
 if server_population.is_empty():server_population=JSON.parse_string(FileAccess.get_file_as_string("res://assets/maps/original_crossgate/sokia_server/encounters.json"))
 return server_population
static func water_data()->Dictionary:
 if water_population.is_empty():water_population=JSON.parse_string(FileAccess.get_file_as_string("res://assets/maps/original_crossgate/sokia_server/water/encounters.json"))
 return water_population
static func server_room(id:int)->bool:
 if id not in ServerArt.SOKIA_SERVER_IDS and id not in ServerArt.SOKIA_WATER_IDS and id not in ServerArt.FREYJA_TRIAL_IDS:return false
 if id in ServerArt.SOKIA_WATER_IDS:ServerArt.load_sokia_water()
 if id in ServerArt.FREYJA_TRIAL_IDS:ServerArt.load_freyja_trial()
 return not ServerArt.data().maps.get("BlueCrossgate/map/0/%d.dat"%id,{}).get("sokia_visual_only",true)
static func cape_data()->Dictionary:
 if cape_population.is_empty():
  cape_population=JSON.parse_string(FileAccess.get_file_as_string("res://assets/maps/falan/sokia/cape/encounters.json"))
  var access:Dictionary=load("res://scripts/forest/forest_sokia_cape.gd").access()
  var additions:Dictionary=access.battle_additions
  assert(cape_population.battles.species.size()==int(additions.species_offset),"Cape access preserves all existing species indices")
  cape_population.battles.species.append_array(additions.species)
  cape_population.battles.groups.merge(additions.groups,false);cape_population.battles.bosses.merge(additions.bosses,false)
  cape_population.actors.merge(access.actors,false);cape_population.runtime_scripts.merge(access.scripts,false)
 return cape_population
static func cape(id:int)->bool:
 var generated=load("res://scripts/forest/forest_original_maps.gd").generated()
 return generated.owns(id) and generated.SPECS[generated.branch(id)].get("sokia",false)
static func coast_data()->Dictionary:
 if coast_population.is_empty():coast_population=JSON.parse_string(FileAccess.get_file_as_string("res://assets/maps/falan/sokia/population.json"))
 return coast_population
static func data()->Dictionary:
 if population.is_empty():
  population=JSON.parse_string(FileAccess.get_file_as_string("res://assets/maps/falan/south_kili_route/population.json"))
  var coast=coast_data()
  assert(population.species.size()==int(coast.base_species_count),"Sokia member indices require the preserved base roster")
  population.species.append_array(coast.extra_species)
  var server=server_data()
  assert(population.species.size()==int(server.species_offset),"Server encounter additions preserve all existing member indices")
  population.species.append_array(server.species)
  var prayer=Prayer.source()
  assert(population.species.size()==int(prayer.species_offset),"Prayer source additions preserve all previous member indices")
  population.species.append_array(prayer.species)
  var existing={}
  for zone in population.zones:existing[int(zone.id)]=true
  for zone in coast.zones:
   if not existing.has(int(zone.id)):population.zones.append(zone)
  for key in coast.groups:
   if not population.groups.has(key):population.groups[key]=coast.groups[key]
  for zone in server.zones:
   assert(not population.zones.any(func(old):return int(old.id)==int(zone.id)),"A source encounter zone must have one owner")
   population.zones.append(zone)
  population.groups.merge(server.groups,false)
  for zone in water_data().zones:
   assert(not population.zones.any(func(old):return int(old.id)==int(zone.id)),"A Water Cave source zone must have one owner")
   population.zones.append(zone)
  for key in water_data().groups:
   assert(not population.groups.has(key),"A Water Cave rare group must have one source owner")
   population.groups[key]=water_data().groups[key]
  population.groups.merge(cape_data().groups,false)
  population.groups.merge(prayer.groups,false)
  var freyja=freyja_data()
  assert(population.species.slice(0,int(freyja.base_species_count))==freyja.species,"Freyja source members preserve every existing index")
  population.zones=population.zones.filter(func(zone):return int(zone.map)!=100)
  population.zones.append_array(freyja.zones)
  population.groups.merge(freyja.groups,true)
  population.outdoor_scope.merge(freyja.outdoor_scope,true)
  for area in population.outdoor_scope:
   var rows={}
   for span in population.outdoor_scope[area]:
    if not rows.has(int(span[0])):rows[int(span[0])]=[]
    rows[int(span[0])].append(Vector2i(span[1],span[2]))
   scopes[area]=rows
  for area in coast.outdoor_bounds:
   var b:Array=coast.outdoor_bounds[area]
   scopes[area]={}
   for y in range(int(b[1]),int(b[1]+b[3])):scopes[area][y]=[Vector2i(b[0],b[0]+b[2]-1)]
 return population
static func mountain(id:int)->bool:return id>=13002 and id<=13014
static func fixed_room(id:int)->bool:return mountain(id) or server_room(id) or id in [5001,5002,5003,23600,15564,13015,15525,15527,15530,GORGE_CORRIDOR] or id in WATER_CAVE or id in ServerArt.SOKIA_CAPE_ACCESS_IDS
static func encounters_own(model)->bool:return (model.falan_area in FREYJA_AREAS or model.falan_area in SOKIA_AREAS) or model.falan_area=="interior" and (model.falan_floor in Prayer.FLOORS or server_room(model.falan_floor) or model.falan_floor in CAVES or model.falan_floor in VENOA_UNDERSEA or model.falan_floor in [13001,15525,GORGE_CORRIDOR] or model.falan_floor in ServerArt.SOKIA_CAPE_ACCESS_IDS or mountain(model.falan_floor) or model.falan_floor in WATER_CAVE or cape(model.falan_floor))
static func in_scope(area:String,cell:Vector2i)->bool:
 data()
 return scopes.has(area) and scopes[area].has(cell.y) and scopes[area][cell.y].any(func(span):return cell.x>=span.x and cell.x<=span.y)
static func source_cell(model,at:Vector2)->Vector2i:
 if model.falan_area=="interior" and model.falan_floor in Prayer.FLOORS:return Vector2i(((at-Prayer.ORIGIN)/3.).round())
 if model.falan_area=="ghana":return Vector2i(((at-Sites.VILLAGES.ghana[2])/3.).round())
 if model.falan_area=="kili":return Vector2i(((at-Sites.VILLAGES.kili[2])/3.).round())
 if model.falan_area=="interior" and (fixed_room(model.falan_floor) or cape(model.falan_floor) or model.falan_floor in ServerArt.SOKIA_DESERT_TEMPLE_IDS or model.falan_floor in ServerArt.SOKIA_DRAGON_SUMMIT_IDS):return Vector2i(((at-load("res://scripts/forest/forest_original_maps.gd").floor_info(model.falan_floor,model.seed_value)[1])/3.).round())
 return Vector2i(((at-Sites.ROOMS[model.falan_floor][1])/3.).round()) if model.falan_area=="interior" else Vector2i(((Regions.frame(model.falan_area)*at)/3.).round())
static func encounter_scope(model,at:Vector2)->bool:
 if model.falan_area=="interior" and server_room(model.falan_floor):return not zone_at(model.falan_floor,source_cell(model,at)).is_empty()
 if model.falan_area=="interior":return model.falan_floor in Prayer.FLOORS or model.falan_floor in CAVES or model.falan_floor in VENOA_UNDERSEA or model.falan_floor in [13001,GORGE_CORRIDOR] or mountain(model.falan_floor) or model.falan_floor in WATER_CAVE or cape(model.falan_floor)
 if model.falan_area in FREYJA_AREAS:
  if not model.FalanFrontier.enemy_exposed(model,at):return false
  var state:Dictionary=model.waves.route_state;var cell=Vector2i(((at-state.origin)/3.).round())
  if not Rect2i(Vector2i.ZERO,state.size).has_point(cell):return false
  var index=cell.y*int(state.size.x)+cell.x
  if (state.bits[index>>3]&(1<<(index&7)))==0:return false
 return in_scope(model.falan_area,source_cell(model,at)) and not Regions.village_contains(model.falan_area,at)
static func bank(model)->Script:
 if model.falan_floor in Prayer.FLOORS:return preload("res://scripts/forest/crowd/ruby_boss_sprites.gd")
 if model.falan_floor in WATER_ENCOUNTERS and server_room(model.falan_floor):
  var prepared=preload("res://scripts/forest/crowd/east_region_sprites.gd")
  # The existing page owner fast-returns for the same selection, and restores
  # these pages after another East map has selected a different shared table.
  var pages={};var motions:Dictionary=prepared.motions()
  for row in server_data().species:
   for page in motions.skin_pages[int(row.skin)]:pages[int(page)]=true
  prepared.make_mesh()
  preload("res://scripts/forest/crowd/hound_sprites.gd").prepare_pages(prepared.ROOT,motions,pages.keys())
  return prepared
 if cape(model.falan_floor) and load("res://scripts/forest/forest_original_maps.gd").generated().branch(model.falan_floor)=="cape_descent":return preload("res://scripts/forest/crowd/sokia_region_sprites.gd")
 if mountain(model.falan_floor) or server_room(model.falan_floor) or model.falan_floor in WATER_CAVE or model.falan_floor in [15525,GORGE_CORRIDOR] or model.falan_floor in ServerArt.SOKIA_CAPE_ACCESS_IDS:return preload("res://scripts/forest/crowd/sokia_region_sprites.gd")
 if model.falan_floor in [11000,11001,11002]:return preload("res://scripts/forest/crowd/venoa_route_sprites.gd")
 if model.falan_floor in [15003,15004,15005] or model.falan_floor in VENOA_UNDERSEA:return preload("res://scripts/forest/crowd/undersea_sprites.gd")
 return preload("res://scripts/forest/crowd/falan_frontier_sprites.gd")
static func state(model)->Dictionary:
 if model.falan_area=="interior":
  if model.falan_floor in Prayer.FLOORS:return {"size":Prayer.SIZE,"origin":Prayer.ORIGIN,"bits":Prayer.walk_mask(model.falan_floor,model.seed_value)}
  var original=load("res://scripts/forest/forest_original_maps.gd")
  if fixed_room(model.falan_floor) or cape(model.falan_floor):
   var row=original.state(model.falan_floor,model.seed_value)
   return {"size":row.size,"origin":row.origin,"bits":row.bits}
  var f=Sites.ROOMS[model.falan_floor]
  return {"size":f[0],"origin":f[1],"bits":f[2].hex_decode()}
 var image:Image=model.terrain.mask_image();var bits=PackedByteArray();bits.resize((image.get_width()*image.get_height()+7)/8)
 for y in image.get_height():
  for x in image.get_width():
   var c=image.get_pixel(x,y);var n=y*image.get_width()+x
   if c.r<.5 and c.b<.98 and (model.falan_area not in FREYJA_AREAS or c.a>=.5):bits[n>>3]|=1<<(n&7)
 if model.falan_area in SOKIA_AREAS:
  var zero=Vector2i((Regions.frame(model.falan_area)*model.terrain.mask_origin()/3.).round())
  for rect:Rect2i in load("res://scripts/forest/forest_sokia_scenery.gd").Data.BLOCKS[model.falan_area]:
   for y in range(rect.position.y,rect.end.y):
    for x in range(rect.position.x,rect.end.x):
     var c=Vector2i(x,y)-zero;var i=c.y*image.get_width()+c.x
     bits[i>>3]&=~(1<<(i&7))
 return {"size":image.get_size(),"origin":model.terrain.mask_origin(),"bits":bits}
static func footprint(member:int)->float:
 var row:Dictionary=data().species[member]
 if row.family=="black_prayer":return .63
 if row.family=="undersea" and int(row.skin)==0:return 1.12
 if row.family=="east_region":return preload("res://scripts/forest/crowd/east_region_sprites.gd").FOOTPRINT
 if row.family=="sokia_region":return .85
 if row.family=="venoa_route":return 1.2 if row.skin==4 else .70
 if row.family=="undersea":return .82
 return 1.18 if preload("res://scripts/forest/crowd/falan_frontier_sprites.gd").tree(int(row.skin)) else .85
static func owns(model)->bool:return (model.falan_area in ["south_gate","south_lakes","kili"] or model.falan_area in SOKIA_AREAS) or model.falan_area=="interior" and (model.falan_floor in CAVES or fixed_room(model.falan_floor))
static func npcs(model)->Array:
 if not owns(model):return []
 var result=[]
 var tour=load("res://scripts/forest/forest_falan_tour.gd")
 for original in data().npcs:
  var record:Dictionary=original.duplicate(true)
  if record.area!=model.falan_area or model.falan_area=="interior" and int(record.floor)!=model.falan_floor:continue
  if record.id=="6302":load("res://scripts/forest/forest_black_prayer_events.gd").decorate(record)
  var at=Vector2(record.cell[0],record.cell[1])*3.
  if model.falan_area=="interior":at+=tour.Indoor.floor_info(model.falan_floor)[1]
  elif model.falan_area=="kili":at+=tour.Regions.Sites.VILLAGES.kili[2]
  else:at=tour.Regions.frame(model.falan_area).inverse()*at
  var previous:Array=tour.VillageNPCs.AREAS.get(str(model.falan_floor) if model.falan_area=="interior" else model.falan_area,[]).filter(func(row):return row[0].distance_squared_to(at)<.01)
  record.existing_placement=not previous.is_empty()
  var g:Dictionary=data().art[record.token];var r:Array=g.rect;var o:Array=g.origin
  result.append([at,Rect2(r[0],r[1],r[2],r[3]),record.name,Vector2(float(o[0])+r[2]*.5,-float(o[1])-r[3]*.5),record])
 return result
static func sokia_npcs(model)->Array:
 if model.falan_area not in SOKIA_AREAS and model.falan_area not in ["interior","ghana"]:return []
 var result=[];var source=coast_data()
 for original in source.npcs:
  var record:Dictionary=original.duplicate(true)
  var outdoor:bool=model.falan_area in SOKIA_AREAS
  if str(record.id) in ["5239","6117"]:load("res://scripts/forest/forest_sokia_cape.gd").decorate(record)
  if outdoor and record.source!=300 or not outdoor and (record.area!=model.falan_area or int(record.floor)!=model.falan_floor):continue
  var cell=Vector2(record.cell[0],record.cell[1])
  var at=Regions.frame(model.falan_area).inverse()*(cell*3.) if outdoor else Sites.VILLAGES.ghana[2]+cell*3. if model.falan_area=="ghana" else load("res://scripts/forest/forest_falan_interior.gd").floor_info(model.falan_floor)[1]+cell*3.
  if outdoor and not in_scope(model.falan_area,Vector2i(cell)):continue
  var previous:Array=load("res://scripts/forest/forest_falan_tour.gd").VillageNPCs.AREAS.get(model.falan_area,[])
  if outdoor and previous.any(func(row):return row[0].distance_squared_to(at)<.01):continue
  var art:Dictionary=source.art[record.token];var r:Array=art.rect;var o:Array=art.origin
  var offset=Vector2(float(o[0])+r[2]*.5,-float(o[1])-r[3]*.5)
  if record.has("map_body_foot_row"):offset.y=float(record.map_body_foot_row)-float(r[3])*.5
  result.append([at,Rect2(r[0],r[1],r[2],r[3]),record.name,offset,record])
 return result
static func zone_at(floor_:int,cell:Vector2i)->Dictionary:
 if floor_ in Prayer.FLOORS:return Prayer.encounter_zone(floor_)
 if cape(floor_):
  var generated=load("res://scripts/forest/forest_original_maps.gd").generated()
  var zone:Dictionary=cape_data().generated[generated.branch(floor_)].duplicate(true)
  zone.id=floor_;zone.map=floor_;zone.levels=generated.encounter_levels(floor_,0)
  return zone
 var result={}
 for z in data().zones:
  var b:Array=z.bounds
  if int(z.map)!=floor_ or cell.x<b[0] or cell.x>b[2] or cell.y<b[1] or cell.y>b[3]:continue
  if result.is_empty() or int(z.priority)>int(result.priority) or int(z.priority)==int(result.priority) and int(z.id)>int(result.id):result=z
 return result
static func eligible_groups(zone:Dictionary,items:Dictionary,source_groups:Variant=null)->Array:
 var groups:Dictionary=data().groups if source_groups==null else source_groups
 var result=[]
 for choice in zone.groups:
  var raw:Array=groups[choice[0]].raw
  var required=int(raw[3]);var forbidden=int(raw[4])
  if required>0 and int(items.get("source_item_%d"%required,0))<=0:continue
  if forbidden>0 and int(items.get("source_item_%d"%forbidden,0))>0:continue
  result.append(choice)
 return result
static func group(zone:Dictionary,bags:Dictionary,rng:RandomNumberGenerator,items:Dictionary={})->Array:
 if zone.is_empty() or zone.groups.is_empty() or int(zone.maximum)<=0:return []
 return group_from_data(zone,bags,rng,data().groups,items)
static func group_from_data(zone:Dictionary,bags:Dictionary,rng:RandomNumberGenerator,source_groups:Dictionary,items:Dictionary={})->Array:
 if zone.is_empty() or zone.groups.is_empty() or int(zone.maximum)<=0:return []
 var allowed=eligible_groups(zone,items,source_groups)
 if allowed.is_empty():return []
 # Inventory changes must not draw an obsolete ticket from the previous gate.
 var key="south-group:%s"%zone.id
 if allowed!=zone.groups:key+=":"+JSON.stringify(allowed)
 var id=Snow.weighted(bags,key,allowed,rng);var g:Dictionary=source_groups[id]
 var choices=[]
 for i in g.members.size():choices.append([i,g.members[i][3]])
 var selected=[];var source:Array=g.get("source_members",[])
 if source.is_empty():
  var count_=int(Snow.draw(bags,"south-count:%s"%zone.id,range(1,int(zone.maximum)+1),rng))
  for i in count_:selected.append(Snow.weighted(bags,"south-member:"+id,choices,rng))
 else:
  var counts=[]
  for i in source.size():
   counts.append(int(source[i].count[0]) if source[i].mandatory else 0)
   for j in counts[i]:selected.append(i)
  assert(selected.size()<=int(zone.maximum),"Mandatory source party exceeds encounter maximum")
  # shortcut: uniform valid party sizes; original server count weights are unverified.
  var minimum=maxi(selected.size(),int(zone.get("minimum",selected.size())))
  assert(minimum<=int(zone.maximum),"Native source party minimum exceeds its maximum")
  var count_=int(Snow.draw(bags,"south-count:%s:%s"%[zone.id,id],range(minimum,int(zone.maximum)+1),rng))
  while selected.size()<count_:
   var available=choices.filter(func(row):return counts[int(row[0])]<int(source[int(row[0])].count[1]))
   if available.is_empty():break
   var member=int(Snow.weighted(bags,"south-member:%s:%s"%[id,JSON.stringify(available)],available,rng))
   selected.append(member);counts[member]+=1
 var result=[]
 for index in selected:
  var m:Array=g.members[index]
  var levels:Array=zone.get("levels",[m[1],m[2]])
  var level=int(Snow.draw(bags,"south-level:%s:%s:%s:%s"%[id,m[0],levels[0],levels[1]],range(int(levels[0]),int(levels[1])+1),rng))
  var member=[int(m[0]),level]
  if not source.is_empty():member.append_array([source[index].enemy_id,id])
  elif g.has("details"):member.append_array([g.details[index].enemy_id,id])
  result.append(member)
 return result
