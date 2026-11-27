extends RefCounted
## Freyja's outer regions share the source grid, while each gate keeps its city alignment.
const Data=preload("res://assets/maps/falan/freyja_outlying_data.gd")
const Sites=preload("res://assets/maps/falan/freyja_destinations_data.gd")
const Sokia=preload("res://scripts/forest/forest_sokia_scenery.gd")
const GATE_FRAMES={
 "freyja":Transform2D(Vector2.DOWN,Vector2.LEFT,Vector2(1287,582)),
 "east_gate":Transform2D(Vector2.UP,Vector2.RIGHT,Vector2(1251,591)),
 "south_gate":Transform2D(Vector2.RIGHT,Vector2.DOWN,Vector2(1269,606)),
}
const GATE_NAMES={"freyja":"West Gate","east_gate":"East Gate","south_gate":"South Gate"}
# The two views overlap along the same Freyja trail. Separate edges leave room to turn back.
const GATE_TRAIL_CENTER=1530.0
const GATE_TRAIL_WIDTH=30.0
const GATE_TRAIL={
 "east_gate":{"to":"south_gate","edge":744.0,"direction":1.0,
  "signs":[Vector2(0,195),Vector2(-30,231),Vector2(-66,249),Vector2(-99,288),Vector2(-133,276)]},
 "south_gate":{"to":"east_gate","edge":735.0,"direction":-1.0,
  "signs":[Vector2(33,199),Vector2(76,216),Vector2(108,198),Vector2(132,171),Vector2(174,154),Vector2(215,170),Vector2(253,155)]},
}
const VENOA_TO_ROAD=Vector2(-222,63)
const VENOA_GATE=Vector2(51,-9)
const IL_TO_ROAD=Vector2(102,330)
const IL_GATE=Vector2(0,-87)
const TOMATO_PLOT=Rect2(97.5,244.5,12,12)
const TOMATO_LAND=["tomato_road","tomato_farm"]
const LARUKA_TO_ROAD=Vector2(-189,129)
const LARUKA_GATE=Vector2(21,-18)
const ALYUT_SOUTH_GATE=Vector2(49.5,42)
const ALYUT_NORTH_GATE=Vector2(25.5,-57)
const ALYUT_TO_ROAD=Vector2(-165,-123)
const ROAD_DESTINATIONS={"south_lakes":"Venoa Village","east_coast":"Il Village","west_lakes":"Saint Laruka"}
const ROAD_GATES={"venoa":[VENOA_GATE,VENOA_TO_ROAD],"il_village":[IL_GATE,IL_TO_ROAD],"laruka":[LARUKA_GATE,LARUKA_TO_ROAD]}
const CONNECTED_VILLAGES={"east_gate":"il_village","north_coast":"alyut"}
static var private_source_context:Script=null
static var joined_masks={}
static var source_field:Dictionary={}
static var source_field_tree_visuals:Dictionary={}
const KILI_GATE=Vector2(-48,-90)
const KILI_EAST_GATE=Vector2(12,3)
const KILI_TO_ROAD=Vector2(96,132)
# Checkpoints follow the existing dry trail, including its bends around the cliffs.
const HABARU_TRAIL={
 "east_coast":[Vector2(117,213),Vector2(96,150),Vector2(21,90),Vector2(39,42),Vector2(63,-24),Vector2(84,-93)],
 "north_coast":[Vector2(-81,-108),Vector2(-27,-114),Vector2(33,-54),Vector2(78,21),Vector2(135,84),Vector2(165,174)],
}

static func frame(area:String)->Transform2D:
 if GATE_FRAMES.has(area):return GATE_FRAMES[area]
 if area=="kili":return Transform2D(0.0,Data.REGIONS.sokia_coast[1]+KILI_TO_ROAD)
 return Transform2D(0.0,Data.REGIONS[area][1])

static func canonical_area(area:String)->String:
 if area in ["east_coast","il_village"]:return "east_gate"
 return "north_coast" if area=="alyut" else area

static func village_transform(village:String)->Transform2D:
 if village=="il_village":return frame("east_gate").inverse()*frame("east_coast")*Transform2D(0.0,IL_TO_ROAD)
 return Transform2D(0.0,ALYUT_TO_ROAD)

static func village_bounds(village:String)->Rect2:
 return Rect2(Sites.VILLAGES[village][2],Sites.VILLAGES[village][3].get_size()*3.0)

static func village_mask(village:String)->Texture2D:
 if village=="il_village":return load("res://scripts/forest/forest_east_il_source_completion.gd").mask()
 if village=="alyut":
  var complete=load("res://scripts/forest/forest_east_alyut_source_completion.gd")
  if complete.enabled():return complete.mask()
 return Sites.VILLAGES[village][3]

static func village_ground_index(village:String)->Texture2D:
 if village=="il_village":return load("res://scripts/forest/forest_east_il_source_completion.gd").ground_index()
 if village=="alyut":
  var complete=load("res://scripts/forest/forest_east_alyut_source_completion.gd")
  if complete.enabled():return complete.ground_index()
 return load("res://assets/maps/falan/"+village+"_ground_index.png")

static func village_ground_atlas(village:String)->Texture2D:
 if village=="alyut":
  var complete=load("res://scripts/forest/forest_east_alyut_source_completion.gd")
  if complete.enabled():return complete.ground_atlas()
 return load("res://assets/maps/falan/"+village+"_ground_atlas.png")

static func village_contains(area:String,at:Vector2)->bool:
 if private_source_context!=null and private_source_context.suppress_joined(area):return false
 if not CONNECTED_VILLAGES.has(area):return false
 var village:String=CONNECTED_VILLAGES[area]
 return village_bounds(village).has_point(village_transform(village).inverse()*at)

static func village_bank(area:String,at:Vector2,bank:float)->float:
 if private_source_context!=null and private_source_context.suppress_joined(area):return bank
 if not CONNECTED_VILLAGES.has(area):return bank
 var village:String=CONNECTED_VILLAGES[area]
 var p=village_transform(village).inverse()*at
 var bounds=village_bounds(village)
 var distance_=(p-p.clamp(bounds.position,bounds.end)).length()
 return lerpf(6.0,bank,smoothstep(0.0,18.0,distance_))

static func joined_mask(area:String,source:Texture2D,origin:Vector2)->Texture2D:
 if private_source_context!=null and private_source_context.suppress_joined(area):return source
 if not CONNECTED_VILLAGES.has(area):return source
 if joined_masks.has(area):return joined_masks[area]
 if area=="east_gate":source=preload("res://assets/maps/falan/freyja_residual/data.gd").surface("east_gate")
 elif area=="north_coast":source=preload("res://assets/maps/falan/east_region/north_coast-surface.png")
 var village:String=CONNECTED_VILLAGES[area]
 var mask:Image=village_mask(village).get_image()
 var image:Image=source.get_meta("source_cpu_image").duplicate() if source.has_meta("source_cpu_image") else source.get_image()
 var placement=village_transform(village)
 for z in mask.get_height():
  for x in mask.get_width():
   var paint=mask.get_pixel(x,z)
   if paint.a<.5:continue
   var at=Vector2i(((placement*(Sites.VILLAGES[village][2]+Vector2(x,z)*3.0)-origin)/3.0).round())
   if not Rect2i(Vector2i.ZERO,image.get_size()).has_point(at):continue
   if paint.r<.5 or image.get_pixelv(at).a<.5:image.set_pixelv(at,paint)
 joined_masks[area]=ImageTexture.create_from_image(image)
 joined_masks[area].set_meta("source_cpu_image",image)
 return joined_masks[area]

static func field_source()->Dictionary:
 if source_field.is_empty():
  source_field=JSON.parse_string(FileAccess.get_file_as_string("res://assets/maps/falan/east_region/field-scenery.json"))
  var assets=load("res://scripts/forest/forest_wind_meadow_assets.gd")
  for area in source_field:
   for row in source_field[area].trees:source_field_tree_visuals[Vector2(row[0],row[1])]=assets.crossgate_tree(int(row[2]))
 return source_field

static func field_tree_visual(source:Vector2,fallback:String)->String:
 field_source()
 return source_field_tree_visuals.get(source,fallback)

static func field_ridges(area:String)->Array:
 if area not in ["east_gate","north_coast"]:return []
 var result=[]
 for row in field_source()[area].ridges:
  var at:Vector2=frame(area).inverse()*(Vector2(row[0],row[1])*3.)
  if village_contains(area,at):continue
  var extent=Vector2(row[4],row[3]) if area=="east_gate" else Vector2(row[3],row[4])
  result.append([at,int(row[2]),extent,float(row[5]),bool(row[6])])
 return result

static func field_details(area:String)->Array:
 if area not in ["east_gate","north_coast"]:return []
 var result=[]
 for row in field_source()[area].details:result.append([Vector2(row[0],row[1]),int(row[2]),str(row[3]),float(row[4])])
 return result

static func complete_field_plan(model,plan:Array)->Array:
 var area:String=model.terrain.variant
 if area not in ["east_gate","north_coast"]:return plan
 var frontier=load("res://scripts/forest/forest_falan_frontier.gd");var scenery=frontier.Scenery
 var result=[]
 for row in plan:
  var replace:bool=row[0] is String and (scenery.is_tree(row[0]) or row[0]=="archive_cliff")
  if replace:
   var point:Vector3=row[2].get_center() if row[0]=="archive_cliff" else row[1].origin
   var source:Vector2=frame(area)*Vector2(point.x,point.z)/3.
   replace=source.x>=440 and source.y<360
  if not replace:result.append(row)
 var trees=[]
 for row in field_source()[area].trees:
  var at:Vector2=frame(area).inverse()*(Vector2(row[0],row[1])*3.)
  if village_contains(area,at):continue
  trees.append([str(row[3]),at,float(row[4]),fposmod(at.x*4.+at.y*11.,360.)])
 result.append_array(frontier.scenery_plan(model,trees))
 frontier.add_cliff_obstacles(model,field_ridges(area),result)
 return result

static func coast_to_gate(at:Vector2)->Vector2:
 return frame("east_gate").inverse()*frame("east_coast")*at

static func has_land(area:String)->bool:
 return Data.REGIONS.has(area) or Sites.VILLAGES.has(area)

static func site_links(area:String)->Array:
 if not GATE_FRAMES.has(area) and not Data.REGIONS.has(area):return []
 var result=[]
 var inverse=frame(area).inverse()
 for row in Sites.SITES:
  if row[0]!=area and not (area=="east_gate" and row[0]=="east_coast") and not (Sokia.owns(area) and Sokia.owns(row[0])):continue
  if Sokia.owns(area) and not Sokia.bounds(area).has_point(inverse*row[4]):continue
  var caption=row[1]
  if row[2]==16501:caption+="\nHold Shift while entering · Low Tide"
  if row[2]==3200:caption+=" · West Gate" if row[6].x<0 else " · East Gate"
  result.append({"at":inverse*row[4],"to":"freyja_site","caption":caption,
   "site":row[2],"kind":row[3],"arrival":row[6],"yaw":0.0,"door":true,
   "crossing":row[2]==3200,
   "trail_sign":inverse*row[7],"title":row[1],
   "direction":inverse.basis_xform(row[5]).normalized()})
 return result

static func village_area(id:int)->String:
 for area in Sites.VILLAGES:
  if Sites.VILLAGES[area][0]==id:return area
 return ""

static func land_height(at:Vector2)->float:
 return 6.0+sin(at.x*.014+at.y*.008)*1.6+cos(at.y*.018-at.x*.008)*1.1

static func layout(area:String)->Dictionary:
 var title:String=Sites.VILLAGES[area][1] if Sites.VILLAGES.has(area) else GATE_NAMES[area] if GATE_NAMES.has(area) else Data.REGIONS[area][0]
 var result={"format":"forest_shrine_map","schema":1,"title":title,
  "terrain_source":"wind_meadow","terrain_scale":2.0,"falan_area":area,
  "buildings":[],"trees":[],"deposits":[],"props":[],"portals":[],"roads":[]}
 var expansion_:float=load("res://scripts/forest/forest_sokia_scenery.gd").expansion(area)
 if area=="south_lakes":expansion_=preload("res://assets/maps/falan/venoa_field/data.gd").EXPANSION
 if expansion_>1.:result.map_expansion=expansion_
 return result

static func entry_point(area:String)->Vector2:
 if Sites.VILLAGES.has(area):return Sites.VILLAGES[area][4]
 if area=="ghana_north_road":return frame(area).inverse()*Data.GHANA_NORTH_GATE
 for row in Data.LINKS:
  if row[1]!=area:continue
  var point=Vector2.ZERO
  point[row[2]]=row[4]+row[3]*6.0
  point[1-row[2]]=row[5]
  return frame(area).inverse()*point
 return Vector2.ZERO

static func crossings(area:String,before:Vector2,at:Vector2)->Dictionary:
 if area in ["sokia_coast","kili"] or Sokia.owns(area):
  var village=area=="kili"
  var coast=Transform2D.IDENTITY if village else frame("sokia_coast").inverse()*frame(area)
  var gate_before=coast*before;var gate_at=coast*at
  for i in 2:
   var gate=(KILI_GATE if i==0 else KILI_EAST_GATE)+(Vector2.ZERO if village else KILI_TO_ROAD)
   var axis=1 if i==0 else 0
   var direction=(-1.0 if i==0 else 1.0)*(1.0 if village else -1.0)
   if absf(gate_at[1-axis]-gate[1-axis])<=4.5 and (gate_before[axis]-gate[axis])*direction<0 and (gate_at[axis]-gate[axis])*direction>=0:
    return {"area":"sokia_coast" if village else "kili","arrival":gate_at+(KILI_TO_ROAD if village else -KILI_TO_ROAD),"rotation":0.0}
  if village:return {}
 var source=frame(area)
 var previous=source*before
 var next=source*at
 if GATE_TRAIL.has(area):
  var trail:Dictionary=GATE_TRAIL[area]
  var edge:float=trail.edge
  var direction:float=trail.direction
  if (previous.y-edge)*direction<0.0 and (next.y-edge)*direction>=0.0:
   var across=lerpf(previous.x,next.x,inverse_lerp(previous.y,next.y,edge))
   if absf(across-GATE_TRAIL_CENTER)<=GATE_TRAIL_WIDTH*.5:
    var target=frame(trail.to)
    return {"area":trail.to,"arrival":target.inverse()*next,"rotation":target.get_rotation()-source.get_rotation()}
 for row in Data.LINKS:
  if row[0]=="east_gate" and row[1]=="east_coast":continue
  var outward=area==row[0]
  if area=="east_gate" and row[0]=="east_coast":outward=true
  if not outward and area!=row[1]:continue
  var axis:int=row[2]
  var direction:float=row[3] if outward else -row[3]
  var edge:float=row[4] if outward else row[4]-row[3]*9.0
  if absf(next[1-axis]-row[5])>15.0:continue
  if (previous[axis]-edge)*direction>=0 or (next[axis]-edge)*direction<0:continue
  var destination:String=row[1] if outward else row[0]
  var target=frame(destination)
  return {"area":destination,"arrival":target.inverse()*next,"rotation":target.get_rotation()-source.get_rotation()}
 return Sokia.crossing(area,previous,next) if Sokia.owns(area) else {}

static func signs(area:String)->Array:
 var result=[]
 if GATE_TRAIL.has(area):
  var trail:Dictionary=GATE_TRAIL[area]
  for point:Vector2 in trail.signs:
   result.append({"at":point,"caption":"Trail to "+GATE_NAMES[trail.to],"gate_trail":true})
 if area=="sokia_desert":
  for at:Vector2 in preload("res://scripts/forest/forest_falken_route.gd").Data.DESERT_TRAIL:
   result.append({"at":frame(area).inverse()*at,"caption":"法爾肯之路 → 古代人民","habaru_trail":true})
 if area=="east_gate":
  for at:Vector2 in HABARU_TRAIL.east_coast:
   result.append({"at":coast_to_gate(at+Vector2(3,0)),"caption":"Habaru Cave","habaru_trail":true})
 for at:Vector2 in HABARU_TRAIL.get(area,[]):
  result.append({"at":at+Vector2(3,0),"caption":"Habaru Cave","habaru_trail":true})
 if area=="il_village":return [{"at":IL_GATE+Vector2(4,12),"caption":"Habaru Cave · Beyond the gate"}]
 if area=="alyut":return [{"at":ALYUT_SOUTH_GATE+Vector2(-5,-12),"caption":"Habaru Cave · South gate"}]
 if area=="east_gate":result.append({"at":Vector2(-100,308),"caption":"Road to Il Village"})
 if area=="north_coast":
  result.append({"at":frame(area).inverse()*Vector2(2064,525),"caption":"Road to Alyut Village"})
  result.append({"at":frame(area).inverse()*Vector2(1863,210),"caption":"Alyut Village"})
 if area=="south_lakes":
  result.append({"at":frame(area).inverse()*Vector2(1323,1068),"caption":"Venoa Cave · Village Side"})
  for point in [Vector2(1257,1149),Vector2(1038,1320)]:
   result.append({"at":frame(area).inverse()*point,"caption":"Road to Venoa Village"})
 if area=="sokia_coast":
  result.append({"at":frame(area).inverse()*(Data.KILI_TRAILHEAD-Vector2(12,6)),"caption":"Road to Kili Village"})
 if area=="east_coast":result.append({"at":Vector2(3,87),"caption":"Habaru Cave · Road to Alyut"})
 for site in site_links(area):
  if site.trail_sign.distance_to(site.at)>8.0:
   result.append({"at":site.trail_sign,"caption":site.title})
 var source=frame(area).inverse()
 for row in Data.LINKS:
  var outward=area==row[0]
  if not outward and area!=row[1]:continue
  var destination:String=row[1] if outward else row[0]
  var title:String=GATE_NAMES[destination] if GATE_NAMES.has(destination) else Data.REGIONS[destination][0]
  if outward and ROAD_DESTINATIONS.has(destination):title="Road to "+ROAD_DESTINATIONS[destination]
  var point=Vector2.ZERO
  point[row[2]]=row[4]+row[3]*(-9.0 if outward else 3.0)
  point[1-row[2]]=row[5]
  result.append({"at":source*point,"caption":title})
 return result
