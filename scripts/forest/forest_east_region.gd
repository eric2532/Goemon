extends RefCounted
const ContextRegions=preload("res://scripts/forest/forest_freyja_regions.gd")
const SOURCE_VILLAGES={2100:"venoa",2300:"laruka",3000:"ghana",3200:"kili"}
## Eastern Freyja and both continental branches use the established Explore owners.
static var routes:Dictionary={}
static var population:Dictionary={}
static var field_entries:Dictionary={}
static var field_arrivals:Dictionary={}
static var doors_by_source:Dictionary={}
static var actors_by_source:Dictionary={}
static var automatic_by_source:Dictionary={}
static var source_actors:Dictionary={}
static var wind_payload:Dictionary={}
static var dragon_payload:Dictionary={}

static func dragon_events()->Dictionary:
 if dragon_payload.is_empty():dragon_payload=JSON.parse_string(FileAccess.get_file_as_string("res://assets/maps/original_crossgate/sokia_dragon_summit/events/data.json"))
 return dragon_payload

static func wind_events()->Dictionary:
 if wind_payload.is_empty():wind_payload=JSON.parse_string(FileAccess.get_file_as_string("res://assets/maps/original_crossgate/sokia_wind_tower/events/data.json"))
 return wind_payload

static func data()->Dictionary:
 if routes.is_empty():
  routes=JSON.parse_string(FileAccess.get_file_as_string("res://assets/maps/falan/east_region/routes.json"))
  routes.fixed_maps=routes.fixed_maps.map(func(value):return int(value))
  routes.boundaries=routes.boundaries.map(func(value):return int(value))
  routes.automatic.append_array(wind_events().automatic)
  var explore=load("res://scripts/forest/forest_explore_routes.gd");explore.data()
  routes.automatic.append_array(explore.catalog.get("source_events",{}).get("automatic",[]))
  var recovered:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/maps/original_crossgate/explore_recovered/events/data.json"))
  for actor in recovered.actors.values():
   if actor.type!="StandEnemy":continue
   routes.automatic.append({"actor":str(actor.id),"source":actor.source,"type":actor.type,"bounds":[actor.cell[0],actor.cell[1],actor.cell[0],actor.cell[1]],"cooldown_ms":60000,"source_line":actor.source_line})
  for door in routes.fixed:
   var source=int(door[0])
   if not doors_by_source.has(source):doors_by_source[source]=[]
   doors_by_source[source].append(door)
  for actor in routes.get("automatic",[]):
   var source=int(actor.source)
   if not automatic_by_source.has(source):automatic_by_source[source]={}
   var bounds:Array=actor.bounds
   for y in range(floori(float(bounds[1]-1)/8.),floori(float(bounds[3]+1)/8.)+1):
    for x in range(floori(float(bounds[0]-1)/8.),floori(float(bounds[2]+1)/8.)+1):
     var bucket=Vector2i(x,y)
     if not automatic_by_source[source].has(bucket):automatic_by_source[source][bucket]=[]
     automatic_by_source[source][bucket].append(actor)
 return routes

static func residents()->Dictionary:
 if population.is_empty():
  population=JSON.parse_string(FileAccess.get_file_as_string("res://assets/maps/falan/east_region/population.json"))
  var wind=wind_events();var offset:int=population.atlas_paths.size()
  population.atlas_paths.append_array(wind.atlas_paths)
  for record in wind.actors:population.actors.append(record)
  population.npcs.append_array(wind.npcs)
  for key in wind.art:
   assert(not population.art.has(key),"Wind NPC art retains its own source token")
   var art:Dictionary=wind.art[key].duplicate(true);art.atlas+=offset;population.art[key]=art
  for key in wind.scripts:
   assert(not population.scripts.has(key)or population.scripts[key]==wind.scripts[key],"Original event payload must retain its source")
   population.scripts[key]=wind.scripts[key]
  var dragon=dragon_events()
  for id in dragon.invisible_actor_ids:
   var record:Dictionary=dragon.actors[id]
   assert(not population.actors.any(func(a):return str(a.id)==str(record.id)),"Dragon invisible Event retains one manual owner")
   population.actors.append(record)
   assert(not population.scripts.has(record.script)or population.scripts[record.script]==dragon.scripts[record.script],"Dragon invisible event preserves its original script")
   population.scripts[record.script]=dragon.scripts[record.script]
  var recovered:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/maps/original_crossgate/explore_recovered/events/data.json"))
  for record in recovered.actors.values():
   assert(not population.actors.any(func(a):return str(a.id)==str(record.id)),"Recovered manual source actor retains one owner")
   population.actors.append(record)
  for key in recovered.scripts:
   assert(not population.scripts.has(key)or population.scripts[key]==recovered.scripts[key],"Recovered scripts preserve source identity")
   population.scripts[key]=recovered.scripts[key]
  var explore=load("res://scripts/forest/forest_explore_routes.gd");explore.data()
  var required:Dictionary=explore.catalog.get("source_events",{})
  for record in required.get("actors",{}).values():
   if not record.get("explore_fight",false)and not record.get("explore_npc",false):continue
   assert(not population.actors.any(func(a):return str(a.id)==str(record.id)),"Required original event retains one owner")
   population.actors.append(record)
   if record.get("explore_npc",false):
    var art:Dictionary=population.art[record.art_reuse]
    assert(art.rgba_sha256==record.art_rgba_sha256,"Required original NPC reuses its exact source graphic")
    if not population.art.has(record.token):population.art[record.token]=art.duplicate()
    population.npcs.append(record)
  for key in required.get("scripts",{}):
   assert(not population.scripts.has(key)or population.scripts[key]==required.scripts[key],"Required original script preserves its source")
   population.scripts[key]=required.scripts[key]
  for record in population.actors:source_actors[str(record.id)]=record
  for record in population.npcs:
   var source=int(record.source)
   if not actors_by_source.has(source):actors_by_source[source]=[]
   actors_by_source[source].append(record)
 return population

static func source_area(source:int,cell:Vector2i)->String:
 if SOURCE_VILLAGES.has(source):return SOURCE_VILLAGES[source]
 if source==300:return "ghana_road"if cell.x>=550 else"sokia_coast"
 if source==2000:return "il_village"
 if source==2400:return "alyut"
 if source!=100:return "interior"
 return "north_coast" if cell.y<100 and cell.x>510 or cell.x>670 and cell.y<210 else "east_gate"

static func source_point(source:int,cell:Vector2i,area:String="")->Vector2:
 var context=ContextRegions.private_source_context
 if context!=null and source in [2000,2400]:return context.source_point(source,cell)
 var tour=load("res://scripts/forest/forest_falan_tour.gd");var maps=tour.Winter.Recovered
 if source==100:
  return tour.Regions.frame(source_area(source,cell) if area.is_empty() else area).inverse()*(Vector2(cell)*3.)
 if source==300:
  var south=load("res://scripts/forest/forest_south_kili_population.gd")
  return tour.Regions.frame(area if area in south.SOKIA_AREAS else source_area(source,cell)).inverse()*(Vector2(cell)*3.)
 if source in [2000,2400]:
  var village="il_village" if source==2000 else "alyut"
  return tour.Regions.village_transform(village)*(tour.Regions.Sites.VILLAGES[village][2]+Vector2(cell)*3.)
 if source==1000:return Vector2(cell.y-134,153-cell.x)*3.
 if source==1500:return Vector2(cell.y-56,41-cell.x)*3.
 if SOURCE_VILLAGES.has(source):return tour.Regions.Sites.VILLAGES[SOURCE_VILLAGES[source]][2]+Vector2(cell)*3.
 var id:int=maps.runtime_id(source)
 return maps.source_point(id,cell) if maps.owns(id) else tour.Indoor.floor_info(id)[1]+Vector2(cell)*3.

static func can_travel_source(game,source:int,cell:Vector2i)->bool:
 var context=ContextRegions.private_source_context
 if context!=null and source in [100,2000,2400]:return context.can_travel(source,cell)
 var tour=game.FalanTour;var maps=tour.Winter.Recovered
 if source==300:
  var terrain=game.model.FreyjaTerrain.new();terrain.variant=source_area(source,cell)
  var at=source_point(source,cell);var image:Image=terrain.mask_image();var pixel=Vector2i(((at-terrain.mask_origin())/3.).round())
  if not Rect2i(Vector2i.ZERO,image.get_size()).has_point(pixel):return false
  var color=image.get_pixelv(pixel);return color.a>=.5 and color.r<.5 and color.b<.98
 if source==100:
  cell=field_arrival(cell)
  var area=source_area(source,cell)
  var origin=Vector2(-675,-204) if area=="east_gate" else Vector2(-480,-480)
  var image:Image=load("res://assets/maps/falan/east_region/"+area+"-surface.png").get_image()
  var pixel=Vector2i(((source_point(source,cell,area)-origin)/3.).round())
  return Rect2i(Vector2i.ZERO,image.get_size()).has_point(pixel) and image.get_pixelv(pixel).a>=.5 and image.get_pixelv(pixel).r<.5
 if source in [2000,2400]or SOURCE_VILLAGES.has(source):
  var village=SOURCE_VILLAGES.get(source,"il_village" if source==2000 else "alyut")
  var mask:Texture2D=tour.Regions.village_mask(village)
  var image:Image=mask.get_meta("source_cpu_image")if mask.has_meta("source_cpu_image")else mask.get_image()
  return Rect2i(Vector2i.ZERO,image.get_size()).has_point(cell) and image.get_pixelv(cell).a>=.5 and image.get_pixelv(cell).r<.5
 if source in [1000,1500]:return game.get_tree().get_meta("falan_venture",{}).get("falan_areas",{}).has("city" if source==1000 else "castle")
 var id:int=maps.runtime_id(source)
 if id==tour.Indoor.RoomArt.RubySource.POST:return true
 if maps.owns(id):
  var local=cell-maps.crop(id).position
  var row:Dictionary=maps.state(id,game.model.seed_value)
  if not Rect2i(Vector2i.ZERO,row.size).has_point(local):return false
  if maps.open(row.bits,row.size,local):return true
  for y in range(-2,3):
   for x in range(-2,3):
    if x*x+y*y<=4.41 and maps.open(row.bits,row.size,local+Vector2i(x,y)):return true
  return false
 return tour.Indoor.Data.FLOORS.has(id) or tour.Regions.Sites.ROOMS.has(id) or tour.Winter.TITLES.has(id) or tour.Winter.Decree.owns(id) or tour.Falken.owns(id) or tour.Prayer.owns(id)

static func travel_source(game,source:int,cell:Vector2i,preserve_checkpoint:bool=false)->bool:
 if not can_travel_source(game,source,cell):
  var blockers:Dictionary=game.get_tree().get_meta("east_route_blockers",{})
  blockers["%d:%d:%d"%[source,cell.x,cell.y]]={"map":source,"cell":cell,"reason":"No current owner supplies this original destination."}
  game.get_tree().set_meta("east_route_blockers",blockers);game.toast("原始目的地尚待恢復");return false
 var tour=game.FalanTour;var maps=tour.Winter.Recovered
 if source==100:cell=field_arrival(cell)
 var area=source_area(source,cell);var layout:Dictionary
 if source in [100,300]:layout=tour.Regions.layout(area)
 elif source in [2000,2400]:layout=tour.Regions.private_source_context.layout(source,cell) if tour.Regions.private_source_context!=null else tour.Regions.layout("east_gate" if source==2000 else "north_coast")
 elif source in [1000,1500]:layout=game.get_tree().get_meta("falan_venture").falan_areas["city" if source==1000 else "castle"]
 elif SOURCE_VILLAGES.has(source):layout=tour.Regions.layout(SOURCE_VILLAGES[source])
 else:layout=tour.Indoor.layout(maps.runtime_id(source))
 var arrival=source_point(source,cell,area)
 if source not in [100,300,2000,2400,1000,1500]and not SOURCE_VILLAGES.has(source)and maps.owns(maps.runtime_id(source)):arrival=maps.source_point(maps.runtime_id(source),cell,game.model.seed_value)
 if source not in [100,300,2000,2400,1000,1500]and not SOURCE_VILLAGES.has(source):arrival=tour.Indoor.safe_point(maps.runtime_id(source),arrival,game.model.seed_value)
 if game.get_tree().has_meta("falan_exit"):game.get_tree().remove_meta("falan_exit")
 game.transitioning=true
 var yaw:float=tour.Regions.private_source_context.arrival_yaw(game,source) if tour.Regions.private_source_context!=null else game.camera_rig.yaw
 tour.travel.call_deferred(game,layout,{"arrival":arrival,"yaw":yaw,"velocity":Vector3.ZERO,"preserve_checkpoint":preserve_checkpoint})
 return true

static func field_arrival(cell:Vector2i)->Vector2i:
 if field_arrivals.is_empty():field_arrivals=JSON.parse_string(FileAccess.get_file_as_string("res://assets/maps/falan/east_region/field-arrivals.json"))
 var arrival:Array=field_arrivals.get("%d,%d"%[cell.x,cell.y],[cell.x,cell.y])
 return Vector2i(arrival[0],arrival[1])

static func destination_link(at:Vector2,target:int,landing:Vector2i)->Dictionary:
 var tour=load("res://scripts/forest/forest_falan_tour.gd");var maps=tour.Winter.Recovered
 if target in [100,300,2000,2400,1000,1500]or SOURCE_VILLAGES.has(target):
  var caption="返回 "+str(tour.Regions.Sites.VILLAGES[SOURCE_VILLAGES[target]][1])if SOURCE_VILLAGES.has(target)else "芙蕾雅" if target==100 else "索奇亞"if target==300 else "返回村莊" if target in [2000,2400] else "里謝里雅堡" if target==1500 else "法蘭城"
  return {"at":at,"to":"east_source","east_source_return":{"map":target,"cell":landing},"caption":caption,"door":true,"walk_in":true,"east_original":true}
 var runtime:int=maps.runtime_id(target)
 if not maps.owns(runtime) and not tour.Indoor.Data.FLOORS.has(runtime) and not tour.Regions.Sites.ROOMS.has(runtime):return {}
 var caption:String=maps.title(runtime) if maps.owns(runtime) else tour.Regions.Sites.TITLES.get(runtime,"通道")
 return maps.door(at,runtime,source_point(target,landing),caption).merged({"walk_in":true,"east_original":true})

static func prepare_field_entry(key:String,seed_:int)->Vector2i:
 var maps=load("res://scripts/forest/forest_original_maps.gd");var generated=maps.generated();var spec:Dictionary=generated.SPECS[key]
 if int(spec.entry[0])!=100:return generated.entry_cell(key,seed_)
 if field_entries.is_empty():field_entries=JSON.parse_string(FileAccess.get_file_as_string("res://assets/maps/falan/east_region/field-entries.json"))
 var candidates:Array=field_entries.get(str(spec.config),[])
 assert(not candidates.is_empty(),"An eastern field dungeon needs recorded reachable source cells")
 var maze=load("res://scripts/forest/forest_frostpass.gd").Maze
 for chosen:Array in maze.shuffled(candidates,maze.rng_for(spec.first,seed_)):
  var cell=Vector2i(chosen[0],chosen[1])
  var placement=load("res://scripts/forest/forest_explore_routes.gd").field_destination(100,cell)
  if placement.is_empty():continue
  var actual=ContextRegions.frame(placement.area)*placement.arrival/3.
  if actual.distance_squared_to(Vector2(cell))>.01:continue
  generated.set_entry_cell(key,seed_,cell)
  return cell
 assert(false,"An eastern field dungeon needs a currently walkable published source entrance")
 return Vector2i(spec.entry[1],spec.entry[2])

static func links_source(source:int,seed_:int,area:String="")->Array:
 data()
 var maps=load("res://scripts/forest/forest_original_maps.gd");var generated=maps.generated();var result=[]
 for row in doors_by_source.get(source,[]):
  var target=int(row[3]);var cell=Vector2i(row[1],row[2]);var landing=Vector2i(row[4],row[5])
  # Normal city exits and the continuous joined villages retain their existing crossing owner.
  if source==100 and target==1000:continue
  if ContextRegions.private_source_context==null and (source==100 and target in [2000,2400] or source in [2000,2400] and target==100):continue
  if source==100 and not area.is_empty() and source_area(source,cell)!=area:continue
  var link=destination_link(source_point(source,cell,area),target,landing)
  if not link.is_empty():result.append(link)
 for key in generated.SPECS:
  var spec:Dictionary=generated.SPECS[key]
  if not spec.get("east",false):continue
  if int(spec.entry[0])==source:
   var cell=prepare_field_entry(key,seed_)
   if source==100 and not area.is_empty():
    var placement=load("res://scripts/forest/forest_explore_routes.gd").field_destination(source,cell)
    if placement.is_empty()or placement.area!=area:continue
   var first:int=generated.floor_id(key,1)
   result.append(maps.door(source_point(source,cell,area),first,generated.landing(first,seed_,true),spec.title).merged({"walk_in":true,"east_original":true,"east_generator":key,"diamond":int(spec.get("source_fixed_markers",[0,0])[0])==103012}))
  if not spec.end.is_empty() and int(spec.end[0])==source:
   var last:int=generated.floor_id(key,generated.count(key,seed_))
   result.append(maps.door(source_point(source,Vector2i(spec.end[1],spec.end[2]),area),last,generated.landing(last,seed_,false),spec.title).merged({"walk_in":true,"east_original":true,"east_generator_return":key,"diamond":int(spec.get("source_fixed_markers",[0,0])[1])==103012,"explore_gate_only":source==47017}))
 return result

static func links(id:int,seed_:int)->Array:
 var maps=load("res://scripts/forest/forest_original_maps.gd")
 return links_source(maps.source_id(id),seed_)

static func links_model(model)->Array:
 var context=ContextRegions.private_source_context
 if context!=null and context.source_id(model)>0:return context.links_model(model)
 var maps=load("res://scripts/forest/forest_original_maps.gd");var area:String=model.falan_area;var result=[]
 if area in ["east_gate","north_coast"]:
  result=links_source(100,model.seed_value,area)
  result.append_array(links_source(2000 if area=="east_gate" else 2400,model.seed_value))
 elif area=="interior" and maps.source_id(model.falan_floor) in data().fixed_maps and not maps.owns(model.falan_floor):
  result=links(model.falan_floor,model.seed_value)
 return result

static func merge_links(model,legacy:Array)->Array:
 var context=ContextRegions.private_source_context
 if context!=null:legacy=context.merge_links(model,legacy)
 var maps=load("res://scripts/forest/forest_original_maps.gd");var additions=links_model(model)
 var area:String=model.falan_area;var source:int=maps.source_id(model.falan_floor)
 if area=="interior" and source in data().fixed_maps and not maps.owns(model.falan_floor):
  legacy=legacy.filter(func(link):return not (link.to=="freyja_door" and maps.source_id(int(link.get("floor",-1))) in data().fixed_maps or link.to in ["freyja_outside","freyja_return","city","castle","interior"]))
 elif area in ["east_gate","north_coast"]:
  var replaced=[410,16501]
  for row in doors_by_source.get(100,[]):
   if int(row[3]) not in [1000,2000,2400]:replaced.append(int(row[3]))
  legacy=legacy.filter(func(link):return not (link.to=="freyja_site" and int(link.get("site",-1)) in replaced))
 for link in additions:
  if legacy.any(func(old):return old.at.distance_squared_to(link.at)<.01 and int(old.get("floor",-1))==int(link.get("floor",-1)) and old.get("east_source_return",{})==link.get("east_source_return",{})):continue
  legacy.append(link)
 return legacy

static func current_source(model,at:Vector2)->int:
 var context=ContextRegions.private_source_context
 if context!=null and context.source_id(model)>0:return context.source_id(model)
 var tour=load("res://scripts/forest/forest_falan_tour.gd")
 if model.falan_area=="interior":return 777 if tour.Winter.Recovered.generated().owns(model.falan_floor) else tour.Winter.Recovered.source_id(model.falan_floor)
 if model.falan_area in load("res://scripts/forest/forest_south_kili_population.gd").SOKIA_AREAS:return 300
 if model.falan_area not in ["east_gate","north_coast"]:return -1
 if tour.Regions.village_contains(model.falan_area,at):
  if model.falan_area=="north_coast":
   var full=load("res://scripts/forest/forest_east_alyut_source_completion.gd")
   var local:Vector2=tour.Regions.village_transform("alyut").affine_inverse()*at
   var cell=Vector2i(((local-tour.Regions.Sites.VILLAGES.alyut[2])/3.).round())
   if full.field_handoff(cell) or full.field_overlap(cell):return 100
  return 2000 if model.falan_area=="east_gate" else 2400
 return 100

static func terminal_record(model)->Dictionary:
 var maps=load("res://scripts/forest/forest_original_maps.gd");var generated=maps.generated();var key:String=generated.branch(model.falan_floor)
 if key.is_empty() or not generated.SPECS[key].get("east",false) or generated.number(model.falan_floor)!=generated.count(key,model.seed_value):return {}
 var spec:Dictionary=generated.SPECS[key]
 if int(spec.terminal_enemy)<=0 and int(spec.terminal_npc)<=0:return {}
 residents()
 var id=str(spec.terminal_enemy if int(spec.terminal_enemy)>0 else spec.terminal_npc)
 var record:Dictionary=source_actors.get(id,{}).duplicate(true)
 if record.is_empty():return {}
 var cell:Vector2i=generated.doors(model.falan_floor,model.seed_value)[1]
 record.render_at=maps.point(model.falan_floor,maps.safe_cell(model.falan_floor,cell+Vector2i.DOWN,model.seed_value),model.seed_value)
 record.terminal_template=true;record.placement_inferred=true
 return record

static func manual_anchors(sources:Array,area:String)->Array:
 residents()
 var result=[]
 for original in population.actors:
  var source:int=original.source;var kind:String=str(original.type).to_lower()
  if source not in sources or original.get("generated_by")!=null or not original.get("invisible",false):continue
  if kind not in ["event","housemaster"] and (not population.scripts.has(original.script) or kind in ["watchevent","watchex","watch","warp","standenemy"]):continue
  var cell=Vector2i(original.cell[0],original.cell[1])
  if source==100 and source_area(source,cell)!=area:continue
  if source==300 and source_area(source,cell)!=area:continue
  var record:Dictionary=original.duplicate(true)
  record.scenery=false;record.transparent_source_anchor=true
  if source==41029:
   record.name="風浪";record.messages=["暴風把你捲向遠方。"]
   record.technical_cutscene_anchor=true;record.placeholder_dialogue=true
  elif str(record.name).strip_edges().is_empty():record.name="調查"
  record.render_at=source_point(source,cell,area if source==100 else "")
  result.append(record)
 return result

static func build_manual_anchors(root:Node3D,model,sources:Array)->Array:
 var tour=load("res://scripts/forest/forest_falan_tour.gd");var rows=[];var registered=[]
 for record in manual_anchors(sources,model.falan_area):
  var action:String=record.quest_action;var found=false
  for sprite in root.find_children("*","Sprite3D",true,false):
   if sprite.get_meta("npc_record",{}).get("quest_action","")==action:found=true;break
  if found:continue
  rows.append([record.render_at,Rect2(0,0,1,1),record.name,Vector2.ZERO,record]);registered.append(str(record.id))
 if not rows.is_empty():tour.build_npcs(root,model,rows,null)
 return registered

static func automatic_candidate_ready(actor:Dictionary,context:Dictionary)->bool:
 if str(actor.type).to_lower() not in ["watchevent","watchex"]:return true
 residents()
 var events=load("res://scripts/forest/forest_east_events.gd")
 var probe:Dictionary=events.begin_context(actor,population.scripts.get(actor.script,{}),context)
 return probe.status!="done" or probe.context!=probe.initial

static func tick(game,delta:float):
 if not game.playing or game.paused or game.ordinary_pause or game.transitioning or game.model.phase!="wave" or game.player.hp<=0 or is_instance_valid(game.dialogue):return
 var elapsed:float=float(game.get_meta("east_auto_elapsed",0.))+delta
 if elapsed<.15:game.set_meta("east_auto_elapsed",elapsed);return
 game.set_meta("east_auto_elapsed",0.)
 var university=load("res://scripts/forest/forest_university_region.gd")
 if not university.active(game.get_tree(),game.model.falan_floor,game.model.falan_area).is_empty():return
 data();residents()
 var at=Vector2(game.player.position.x,game.player.position.z)/game.model.falan_scale
 var source=current_source(game.model,at)
 # Preserved unmatched Falan houses use room 0, which has no original source cell.
 if source<=0:return
 var events=load("res://scripts/forest/forest_east_events.gd");var context:Dictionary
 var private_context=ContextRegions.private_source_context
 var previous_auto:Dictionary={}
 var candidates=[];var terminal=terminal_record(game.model)
 if not terminal.is_empty() and at.distance_squared_to(terminal.render_at)<=9.:
  candidates.append({"actor":str(terminal.id),"type":terminal.type,"cooldown_ms":60000})
 elif source!=777:
  context=events.game_context(game,{"source":source})
  var cell:Vector2i=context.cell;var bucket=Vector2i(floori(float(cell.x)/8.),floori(float(cell.y)/8.))
  if private_context!=null and source==100:previous_auto=private_context.automatic_previous(game,source,cell)
  candidates=automatic_by_source.get(source,{}).get(bucket,[])
 var now:int=Time.get_ticks_msec();var cooldown:Dictionary=game.get_meta("east_auto_cooldown",{})
 for trigger in candidates:
  var actor:Dictionary=source_actors.get(str(trigger.actor),{})
  if actor.is_empty():continue
  var access=game.get("explore_access")
  if is_instance_valid(access)and access.enabled()and (trigger.type=="StandEnemy"or actor.get("explore_fight",false)):
   if game.get_tree().has_meta("university_victory")or access.source_boss_cleared(str(trigger.actor))or not preload("res://scripts/forest/forest_university_region.gd").active(game.get_tree(),game.model.falan_floor,game.model.falan_area).is_empty():continue
  if context.is_empty():context=events.game_context(game,actor)
  var token="%d:%s:%s:%d"%[game.model.seed_value,trigger.actor,game.model.falan_area,game.model.falan_floor]
  if now<int(cooldown.get(token,0)):continue
  if trigger.has("time_mask") and (int(trigger.time_mask)&(1<<int(context.nowtime)))==0:continue
  if trigger.has("bounds"):
   var b:Array=trigger.bounds;var bounds=Rect2i(b[0],b[1],b[2]-b[0]+1,b[3]-b[1]+1)
   if not bounds.grow(1 if trigger.type=="StandEnemy" else 0).has_point(context.cell):continue
  if private_context!=null and source==100 and trigger.type=="Warp" and not private_context.automatic_entered(previous_auto,source,context.cell,trigger.bounds):continue
  # Broad source bounds must not consume a trap/entrance cooldown before its exact conditions match.
  if not automatic_candidate_ready(actor,context):continue
  cooldown[token]=now+int(trigger.cooldown_ms);game.set_meta("east_auto_cooldown",cooldown)
  events.action(game,"east_event:"+str(actor.id))
  return

static func build_npcs(root:Node3D,model):
 var tour=load("res://scripts/forest/forest_falan_tour.gd");var maps=tour.Winter.Recovered
 var source:int=maps.source_id(model.falan_floor) if model.falan_area=="interior" else 100
 var sources=[source]
 if model.falan_area=="east_gate":sources.append(2000)
 elif model.falan_area=="north_coast":sources.append(2400)
 elif model.falan_area in load("res://scripts/forest/forest_south_kili_population.gd").SOKIA_AREAS:sources=[300]
 elif model.falan_area!="interior" and (ContextRegions.private_source_context==null or ContextRegions.private_source_context.source_id(model)<=0):return
 var context=ContextRegions.private_source_context
 if context!=null and context.source_id(model)>0:sources=context.npc_sources(model)
 residents()
 var records=[]
 for current in sources:records.append_array(actors_by_source.get(current,[]))
 var terminal=terminal_record(model)
 if not terminal.is_empty():records.append(terminal)
 var batches={}
 for original in records:
  var is_terminal:bool=original.get("terminal_template",false)
  if original.get("native_enemy",false) and not is_terminal or original.get("invisible",false) or original.get("generated_by")!=null and not is_terminal or original.get("art_missing",false):continue
  var current:int=original.source;var cell=Vector2i(original.cell[0],original.cell[1])
  var at:Vector2=original.render_at if is_terminal else source_point(current,cell,model.falan_area if current==100 else "")
  if current==100:
   var bounds:Rect2=model.terrain.mask_bounds()
   if not bounds.has_point(at):continue
  var record:Dictionary=original.duplicate(true)
  var found=false
  for sprite in root.find_children("*","Sprite3D",true,false):
   var local:Vector3=root.global_transform.affine_inverse()*sprite.global_position
   if Vector2(local.x,local.z).distance_squared_to(at)>.04:continue
   if not sprite.has_meta("npc_record"):sprite.set_meta("npc_record",record)
   found=true;break
  if found:continue
  if not population.art.has(record.token):continue
  var art:Dictionary=population.art[record.token];var r:Array=art.rect;var o:Array=art.origin;var page=int(art.atlas)
  if not batches.has(page):batches[page]=[]
  batches[page].append([at,Rect2(r[0],r[1],r[2],r[3]),record.name,Vector2(float(o[0])+r[2]*.5,-float(o[1])-r[3]*.5),record])
 for page in batches:tour.build_npcs(root,model,batches[page],load(population.atlas_paths[page]))
 build_manual_anchors(root,model,sources)
