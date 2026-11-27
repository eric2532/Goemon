extends RefCounted
## Draw the same source grid the terrain and cave navigation use.
const Tour=preload("res://scripts/forest/forest_falan_tour.gd")
const WATER=Color("285770")
const STONE=Color("95846b")
const ROAD=Color("c5a675")
const LAND=Color("536347")
const PIN=Color("e8cf86")
const DIAMOND=Color("ffe264")
const BOSS=Color("f6856b")
var key:Array=[]
var texture:ImageTexture
var illustration:ImageTexture
var bounds:=Rect2()
var map_frame:=Transform2D.IDENTITY
var title:=""
var pins:Array=[]

func refresh(model)->void:
 var area=Tour.area(model)
 var ladder=Tour.Indoor.Ladder
 var below=model.falan_floor==ladder.CHAMBER and model.hero_position.y<-ladder.DEPTH*model.falan_scale*.8
 var current=[model.get_instance_id(),area,model.falan_floor,model.seed_value,below,model.navigation_revision]
 if current==key:return
 key=current
 texture=null;illustration=null
 map_frame=Transform2D.IDENTITY
 pins.clear()
 if area.is_empty():
  if model.terrain_detail=="arena":
   title="Falan Arena"
   var span=Vector2(model.navigation_region.size)*model.CELL
   bounds=Rect2((Vector2(model.navigation_region.position)-Vector2.ONE*.5)*model.CELL,span)
   illustration=preload("res://scripts/forest/forest_map_illustration.gd").arena(model,bounds)
   texture=illustration
  return
 if area=="interior":
  var id:int=ladder.BASEMENT if below else model.falan_floor
  title=Tour.Indoor.layout(id).title
  var floor_=Tour.Indoor.floor_info(id,model.seed_value)
  var size:Vector2i=floor_[0]
  var pools=Tour.Indoor.RoomArt.pool_tiles(id,size)
  var walk=Tour.Indoor.walk_mask(id,size,floor_[2].hex_decode(),model.seed_value)
  if id==Tour.Dungeons.GRAVE and not Tour.Indoor.Original.owns(id):size.y+=Tour.Indoor.GRAVE_MAZE_SIZE.y
  bounds=Rect2(floor_[1]-Vector2.ONE*1.5,Vector2(size)*3.0)
  var image=Image.create_empty(size.x,size.y,false,Image.FORMAT_RGBA8)
  for z in size.y:
   for x in size.x:
    if Tour.Indoor.RoomArt.is_pool(pools,size,Vector2i(x,z)):image.set_pixel(x,z,WATER)
    elif Tour.Indoor.open_cell(walk,size,x,z):image.set_pixel(x,z,STONE)
  texture=ImageTexture.create_from_image(image)
  texture.set_meta("source_cpu_image",image)
  if below:
   bounds.position+=ladder.HATCH-ladder.LOWER_HATCH
   add_pin(ladder.HATCH,"Ladder Up",PIN)
   illustration=preload("res://scripts/forest/forest_map_illustration.gd").prepare(self,model)
   return
  if id==ladder.CHAMBER:add_pin(ladder.HATCH,"Basement Ladder",PIN)
 else:
  if not model.terrain.has_method("mask_bounds"):return
  title=area.capitalize()
  if Tour.TITLES.has(area):title=Tour.TITLES[area].trim_suffix(" - Test")
  elif Tour.Regions.has_land(area):title=Tour.Regions.layout(area).title
  var local_bounds:Rect2=model.terrain.mask_bounds()
  var east_gate=area=="east_gate"
  var mountain=area in Tour.Regions.TOMATO_LAND
  var east_road=east_gate or area=="east_coast"
  if east_gate:map_frame=Transform2D(Vector2.UP,Vector2.RIGHT,Vector2.ZERO)
  bounds=map_frame*local_bounds
  var mask:Image=model.terrain.mask_image()
  var bridge:Rect2=model.terrain.bridge_bounds()
  var first_cell=local_bounds.position+Vector2.ONE*1.5
  var dimensions=Vector2i(mask.get_height(),mask.get_width()) if east_gate else mask.get_size()
  var image=Image.create_empty(dimensions.x,dimensions.y,false,Image.FORMAT_RGBA8)
  for z in mask.get_height():
   for x in mask.get_width():
    var tile=mask.get_pixel(x,z)
    if tile.a<.18:continue
    if mountain and tile.r>.52:continue
    var at=first_cell+Vector2(x,z)*3.0
    var pixel=Vector2i(z,mask.get_width()-1-x) if east_gate else Vector2i(x,z)
    var paved=east_road and tile.r<.52 and tile.b>.8
    if paved or (bridge.has_area() and bridge.grow(.01).has_point(at)):image.set_pixelv(pixel,STONE)
    else:image.set_pixelv(pixel,WATER if tile.r>.52 else ROAD if tile.g>.38 else LAND)
  texture=ImageTexture.create_from_image(image)
  texture.set_meta("source_cpu_image",image)
  if east_gate:add_pin(Tour.Regions.TOMATO_PLOT.get_center(),"Tomato Plot",PIN)
  if area=="tomato_farm":add_pin(Tour.Regions.Sites.TOMATO_WELL,"Farm Well",PIN)
 for link in model.get_meta("falan_links",[]):
  var destination:String=link.to
  if area not in ["interior","castle"] and destination=="interior":continue
  var name_:String=link.get("caption",Tour.Regions.GATE_NAMES.get(destination,Tour.TITLES.get(destination,destination.capitalize())))
  name_=name_.get_slice("\n",0).trim_prefix("F  ·  ").trim_suffix(" - Test")
  var diamond:bool=link.get("diamond",false) or link.get("kind","")=="diamond"
  add_pin(link.at,name_,DIAMOND if diamond else PIN)
 if area in Tour.Regions.GATE_FRAMES or area in Tour.Regions.Data.REGIONS:
  if Tour.Regions.GATE_TRAIL.has(area):
   var trail:Dictionary=Tour.Regions.GATE_TRAIL[area]
   var edge=Vector2(Tour.Regions.GATE_TRAIL_CENTER,trail.edge)
   add_pin(Tour.Regions.frame(area).inverse()*edge,"Trail to "+Tour.Regions.GATE_NAMES[trail.to],PIN)
  for row in Tour.Regions.Data.LINKS:
   if area not in [row[0],row[1]]:continue
   var outward:bool=area==row[0]
   var target:String=row[1] if outward else row[0]
   var point=Vector2.ZERO
   point[row[2]]=row[4]+row[3]*(-6.0 if outward else 6.0)
   point[1-row[2]]=row[5]
   var title_:String=Tour.Regions.ROAD_DESTINATIONS.get(target,Tour.Regions.GATE_NAMES.get(target,target.capitalize()))
   add_pin(Tour.Regions.frame(area).inverse()*point,"Road to "+title_,PIN)

 illustration=preload("res://scripts/forest/forest_map_illustration.gd").prepare(self,model)

func add_pin(at:Vector2,name_:String,color:Color):
 if name_.is_empty() or not bounds.grow(1.5).has_point(map_frame*at):return
 if pins.any(func(p):return p.at.distance_squared_to(at)<9.0):return
 pins.append({"at":at,"label":name_,"color":color})
