extends RefCounted
const Winter=preload("res://scripts/forest/forest_frostpass.gd")
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
const Habitable=["falan_townhouse","falan_shop","falan_chapel","falan_royal_keep"]
const NPCS=preload("res://assets/maps/falan/npc_data.gd")
const VillageNPCs=preload("res://assets/maps/falan/freyja_npc_data.gd")
const VillageAtlas=preload("res://assets/maps/falan/freyja_npc_atlas.png")
const ATLAS=preload("res://assets/maps/falan/npc_atlas.png")
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
  for row in Regions.Sites.DOORS.get(map_id,[]):
   var target:int=row[1]
   if map_id==Ruby.ROOM and target==15003:continue
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
  if map_id==Ruby.ROOM:
   for side in [-1,1]:
    result.append({"at":Vector2(-3,18+3*side),"to":"ruby_gate","arrival":Vector2(-3,18-3*side),
     "caption":"Pass the Gate","door":true})
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
  var exits:Array=Dungeons.EXITS.get(map_id,[])
  if exits.is_empty() and Regions.Sites.CAVE_EXITS.has(map_id):
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
    continue
   var bounds:Vector3=model.scenery_obstacles[anchor].size if centered else Document.Scenery.CATALOG[item.kind].box.size*item.scale
   var angle=0.0 if centered else -deg_to_rad(item.rotation)
   var door=p+Vector2(0,bounds.z*.5+2.0).rotated(angle)
   for offset in [Vector2(0,bounds.z*.5+2.0),Vector2(bounds.x*.5+2.0,0),Vector2(-bounds.x*.5-2.0,0),Vector2(0,-bounds.z*.5-2.0)]:
    var candidate=p+offset.rotated(angle)
    if centered and model.CityGardens.Data.PLANTERS.any(func(row):return row[0].distance_squared_to(candidate)<2.60*2.60):continue
    var floor=Vector3(candidate.x,model.surface_height(candidate.x,candidate.y)+.5,candidate.y)
    if not model.terrain.disk_clear(floor,.55):continue
    if model.scenery_obstacles.values().any(func(box):return box.grow(.45).has_point(floor)):continue
    door=candidate
    break
   result.append({"at":door,"to":"interior","floor":0,"arrival":Vector2(0,6),"yaw":0.0,"door":true,"house_anchor":anchor})
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
 return result

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
 if area(model)=="city":load("res://scripts/forest/forest_travel_stones.gd").build(root,model)
 var npc_area=str(model.falan_floor) if model.falan_area=="interior" else model.falan_area
 if NPCS.AREAS.has(npc_area):build_npcs(root,model,NPCS.AREAS[npc_area],ATLAS)
 else:
  var villagers:Array=VillageNPCs.AREAS.get(npc_area,[]).duplicate()
  for source in Dungeons.NPCS.get(model.falan_floor,{}):
   var positions:Array=Dungeons.NPCS[model.falan_floor][source]
   var archived:Array=VillageNPCs.AREAS[str(source)]
   for i in positions.size():villagers.append([positions[i],archived[i][1],archived[i][2]])
  if not villagers.is_empty():build_npcs(root,model,villagers,VillageAtlas)
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
  if current=="west_lakes":Indoor.WinterArt.trailhead(root,model)
  if current=="east_gate":
   markers=markers+[{"at":Vector2(-99,288),"caption":"Trail to South Gate"}]
  elif current=="south_gate":
   markers=markers+[{"at":Vector2(138,180),"caption":"Trail to East Gate"}]
  if Regions.GATE_FRAMES.has(current) or Regions.Data.REGIONS.has(current) or current in ["il_village","alyut"]:
   markers=markers+Regions.signs(current)
   if current=="freyja":
    markers=markers+[{"at":Regions.frame(current).inverse()*Vector2(894,444),"caption":"Sacred Tree"}]
 for link in markers:
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
  if diamond:height=.7 if current=="interior" else 4.8
  var label_at:Vector2=link.at
  if link.get("site",-1) in [11002,15592]:label_at.y+=1.5
  if link.get("site",-1) in [11003,11005]:label_at-=Regions.frame(current).inverse().basis_xform(Vector2.RIGHT)*2.1
  label.position=Vector3(label_at.x,model.surface_height(label_at.x,label_at.y)+height,label_at.y)
  root.add_child(label)

static func is_walk_in(current:String,link:Dictionary)->bool:
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
 elif current=="east_gate" and before.x>Frontier.EAST_TRAIL_EDGE and at.x<=Frontier.EAST_TRAIL_EDGE and absf(at.y-279.0)<=15.0:
  destination="south_gate"
  arrival=Frontier.EAST_TO_SOUTH*at
  rotation=PI*.5
 elif current=="south_gate" and before.y>Frontier.SOUTH_TRAIL_EDGE and at.y<=Frontier.SOUTH_TRAIL_EDGE and absf(at.x-261.0)<=15.0:
  destination="east_gate"
  arrival=Frontier.EAST_TO_SOUTH.inverse()*at
  rotation=-PI*.5
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
 # shortcut: the views share coordinates; stream the next region if the rebuild becomes noticeable.
 var layout=outdoor_layout(venture,destination)
 game.transitioning=true
 game.get_tree().remove_meta("falan_exit")
 var current=area(game.model)
 var link={"arrival":arrival,"yaw":game.camera_rig.yaw+rotation,
  "velocity":game.player.velocity.rotated(Vector3.UP,rotation)}
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
 var tree:SceneTree=game.get_tree()
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
 if link.get("decree_guardians",false):
  if not Winter.Decree.cleared(tree.get_meta(Winter.SLAIN,{}),game.model.falan_floor,game.model.seed_value):
   game.toast("擊敗本層守護者才能解除封印")
   return true
  if game.model.falan_floor==Winter.Decree.GUARDIAN_FLOORS.back() and not tree.get_meta(Winter.Decree.COMPLETE,false):
   tree.set_meta(Winter.Decree.COMPLETE,true)
   game.toast("聖詔 · 雙王的封印已解除")
 if link.get("beast_guardian",false) and not tree.get_meta(Winter.SLAIN,{}).has(Vector2i(Winter.Recovered.Beast.BOSS_ROOM,0)):
  game.toast("擊敗神獸史雷普尼爾才能解除封印")
  return true
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
  game.player.global_position=game.model.world_point(link.arrival,.15)
  game.player.velocity=Vector3.ZERO
  game.falan_crossing_position=Vector2.INF
  game.player.reset_physics_interpolation()
  game.camera_rig.reset_follow()
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
 if layout.get("falan_area","")=="interior":
  var phase=game.explorer_clock.phase_floor(int(layout.get("falan_floor",0)))
  if phase!=layout.get("falan_floor",0):
   layout=Indoor.layout(phase)
   link=link.duplicate();link.arrival=Indoor.safe_point(phase,link.arrival,game.model.seed_value)
 var source_area:String=layout.get("falan_area","")
 if source_area in ["il_village","alyut"]:
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
 game.preview_forest_map(layout,false,false,walking)
 game.falan_crossing_position=Vector2.INF
 var at:Vector2=link.arrival
 if Regions.Sites.VILLAGES.has(game.model.falan_area) or source_area in ["il_village","alyut"]:at=village_door(game.model,at)
 var stair=cave_stair_at(game.model.falan_floor,at)
 var rise=Indoor.RoomArt.HabaruStairs.RISE*.5*game.model.falan_scale if stair in [12001,17954,13268] else 0.0
 game.player.position=game.model.world_point(at,.15+rise)
 game.player.velocity=Vector3.ZERO
 game.player.reset_physics_interpolation()
 game.model.hero_position=game.player.position
 game.checkpoint=game.player.position
 game.camera_rig.yaw=CAVE_FACING.get(game.model.falan_floor,{}).get(at,link.yaw)
 if link.has("facing"):
  var facing:Vector3=link.facing
  game.player.facing=facing
  game.player.model.rotation.y=atan2(-facing.x,-facing.z)
 game.transitioning=false
 game.start_wave()
 if walking:
  game.player.velocity=link.velocity
  game.camera_rig.reset_follow()


static func build_npcs(root:Node3D,model,rows:Array,atlas:Texture2D):
 var group=Node3D.new()
 group.name="OriginalFalanNPCs"
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
  group.add_child(sprite)
