extends RefCounted
## Freyja's outer regions share the source grid, while each gate keeps its city alignment.
const Data=preload("res://assets/maps/falan/freyja_outlying_data.gd")
const Sites=preload("res://assets/maps/falan/freyja_destinations_data.gd")
const GATE_FRAMES={
 "freyja":Transform2D(Vector2.DOWN,Vector2.LEFT,Vector2(1287,582)),
 "east_gate":Transform2D(Vector2.UP,Vector2.RIGHT,Vector2(1251,591)),
 "south_gate":Transform2D(Vector2.RIGHT,Vector2.DOWN,Vector2(1269,606)),
}
const GATE_NAMES={"freyja":"West Gate","east_gate":"East Gate","south_gate":"South Gate"}
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
static var joined_masks={}
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

static func village_contains(area:String,at:Vector2)->bool:
 if not CONNECTED_VILLAGES.has(area):return false
 var village:String=CONNECTED_VILLAGES[area]
 return village_bounds(village).has_point(village_transform(village).inverse()*at)

static func village_bank(area:String,at:Vector2,bank:float)->float:
 if not CONNECTED_VILLAGES.has(area):return bank
 var village:String=CONNECTED_VILLAGES[area]
 var p=village_transform(village).inverse()*at
 var bounds=village_bounds(village)
 var distance_=(p-p.clamp(bounds.position,bounds.end)).length()
 return lerpf(6.0,bank,smoothstep(0.0,18.0,distance_))

static func joined_mask(area:String,source:Texture2D,origin:Vector2)->Texture2D:
 if not CONNECTED_VILLAGES.has(area):return source
 if joined_masks.has(area):return joined_masks[area]
 var village:String=CONNECTED_VILLAGES[area]
 var mask:Image=Sites.VILLAGES[village][3].get_image()
 var image=source.get_image()
 var placement=village_transform(village)
 for z in mask.get_height():
  for x in mask.get_width():
   var paint=mask.get_pixel(x,z)
   if paint.a<.5:continue
   var at=Vector2i(((placement*(Sites.VILLAGES[village][2]+Vector2(x,z)*3.0)-origin)/3.0).round())
   if not Rect2i(Vector2i.ZERO,image.get_size()).has_point(at):continue
   if paint.r<.5 or image.get_pixelv(at).a<.5:image.set_pixelv(at,paint)
 joined_masks[area]=ImageTexture.create_from_image(image)
 return joined_masks[area]

static func coast_to_gate(at:Vector2)->Vector2:
 return frame("east_gate").inverse()*frame("east_coast")*at

static func has_land(area:String)->bool:
 return Data.REGIONS.has(area) or Sites.VILLAGES.has(area)

static func site_links(area:String)->Array:
 if not GATE_FRAMES.has(area) and not Data.REGIONS.has(area):return []
 var result=[]
 var inverse=frame(area).inverse()
 for row in Sites.SITES:
  if row[0]!=area and not (area=="east_gate" and row[0]=="east_coast"):continue
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
 return {"format":"forest_shrine_map","schema":1,"title":title,
  "terrain_source":"wind_meadow","terrain_scale":2.0,"falan_area":area,
  "buildings":[],"trees":[],"deposits":[],"props":[],"portals":[],"roads":[]}

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
 if area in ["sokia_coast","kili"]:
  var village=area=="kili"
  for i in 2:
   var gate=(KILI_GATE if i==0 else KILI_EAST_GATE)+(Vector2.ZERO if village else KILI_TO_ROAD)
   var axis=1 if i==0 else 0
   var direction=(-1.0 if i==0 else 1.0)*(1.0 if village else -1.0)
   if absf(at[1-axis]-gate[1-axis])<=4.5 and (before[axis]-gate[axis])*direction<0 and (at[axis]-gate[axis])*direction>=0:
    return {"area":"sokia_coast" if village else "kili","arrival":at+(KILI_TO_ROAD if village else -KILI_TO_ROAD),"rotation":0.0}
  if village:return {}
 var source=frame(area)
 var previous=source*before
 var next=source*at
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
 return {}

static func signs(area:String)->Array:
 var result=[]
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
