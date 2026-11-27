extends RefCounted
## Bake existing scenery into one north-up map image when the area's layout changes.
const Native=preload("res://scripts/forest/forest_original_maps.gd")
const Houses=preload("res://assets/maps/falan/city_architecture.gd")
const HouseAtlas=preload("res://assets/maps/falan/city_architecture.png")
const Arena=preload("res://scripts/forest/forest_arena.gd")

static func prepare(chart,model)->ImageTexture:
 var image:Image=chart.texture.get_meta("source_cpu_image").duplicate() if chart.texture.has_meta("source_cpu_image") else chart.texture.get_image()
 var detail=mini(4,maxi(1,2048/maxi(image.get_width(),image.get_height())))
 image.resize(image.get_width()*detail,image.get_height()*detail,Image.INTERPOLATE_NEAREST)
 var pixels=Vector2(image.get_size())/chart.bounds.size
 var state:Dictionary={};var pages={};var aliases:Dictionary={}
 if model.falan_area=="city":
  paving(image,preload("res://assets/maps/falan/city_paving_index.png").get_image(),preload("res://assets/maps/falan/city_paving_atlas.png").get_image(),detail)
 elif model.falan_area=="castle":
  var paint=preload("res://assets/maps/falan/castle_courtyard_paving.png").get_image()
  paint.resize(image.get_width(),image.get_height(),Image.INTERPOLATE_LANCZOS)
  image.blend_rect(paint,Rect2i(Vector2i.ZERO,paint.get_size()),Vector2i.ZERO)
 elif model.falan_area=="interior" and Native.owns(model.falan_floor):
  state=Native.state(model.falan_floor,model.seed_value)
  aliases=Native.Art.data().maps.get(Native.path_for(model.falan_floor,model.seed_value),{}).get("graphic_aliases",{})
  var tiles={}
  for i in state.size.x*state.size.y:
   var serial=state.raw.decode_u16(20+i*2)
   if serial<1000:continue
   serial=int(aliases.get(str(serial),serial))
   var graphic:Dictionary=Native.Art.data().graphics[str(serial)];var r=graphic.rect
   if int(r[2])!=64 or int(r[3]) not in [47,48]:continue
   if not tiles.has(serial):
    var page=int(graphic.page)
    if not pages.has(page):pages[page]=Native.Art.page_image(page)
    var tile=Image.create_empty(detail,detail,false,Image.FORMAT_RGBA8)
    for y in detail:
     for x in detail:
      var u=(x+.5)/detail-.5;var v=(y+.5)/detail-.5
      tile.set_pixel(x,y,pages[page].get_pixel(int(r[0])+int(32+31*(u+v)),int(r[1])+int(23.5+22*(v-u))))
    tiles[serial]=tile
   image.blend_rect(tiles[serial],Rect2i(0,0,detail,detail),Vector2i(i%state.size.x,i/state.size.x)*detail)
 # Actual collision footprints keep walls, bridges and custom scenery aligned with the world.
 for box:AABB in model.scenery_obstacles.values():
  var footprint=Rect2(Vector2(box.position.x,box.position.z),Vector2(box.size.x,box.size.z))
  var mapped:Rect2=chart.map_frame*footprint
  var rect=Rect2i((mapped.position-chart.bounds.position)*pixels,mapped.size*pixels)
  rect=rect.intersection(Rect2i(Vector2i.ZERO,image.get_size()))
  if not rect.has_area():continue
  image.fill_rect(rect,Color("596456"))
  if rect.size.x>2 and rect.size.y>2:image.fill_rect(rect.grow(-1),Color("a9a28b"))
 if model.falan_area!="interior":
  var graphic:Dictionary=Native.Art.data().graphics["10088"]
  var atlas:Image=Native.Art.page_image(int(graphic.page))
  var r=graphic.rect;var tree=atlas.get_region(Rect2i(r[0],r[1],r[2],r[3]))
  tree.resize(maxi(5,roundi(8*pixels.x)),maxi(6,roundi(10*pixels.y)),Image.INTERPOLATE_LANCZOS)
  for anchor in model.trees:
   var point:Vector3=model.scenery_point(anchor)
   stamp(image,tree,(chart.map_frame*Vector2(point.x,point.z)-chart.bounds.position)*pixels)
  for row in model.falan_frontier_plan:
   if row[0] not in ["tree","pine"]:continue
   var point:Vector3=row[1].origin
   stamp(image,tree,(chart.map_frame*Vector2(point.x,point.z)-chart.bounds.position)*pixels)
 if model.falan_area=="city":
  var atlas=HouseAtlas.get_image();var icons={}
  for row in Houses.BINDINGS.values():house(image,row,atlas,icons,chart,pixels)
  for row in Houses.UNMARKED:house(image,row,atlas,icons,chart,pixels)
 elif model.falan_area=="interior" and Native.owns(model.falan_floor):
  var count=state.size.x*state.size.y;var icons={};var placements=[]
  for i in count:
   var serial=state.raw.decode_u16(20+(count+i)*2)
   if serial<1000:continue
   serial=int(aliases.get(str(serial),serial))
   var graphic:Dictionary=Native.Art.data().graphics[str(serial)]
   if graphic.ground or graphic.family=="void":continue
   # Small furnishings stay in the floor plan; recognizable silhouettes get original artwork.
   if int(graphic.footprint[0])*int(graphic.footprint[1])<4 and serial not in range(10050,10100) and serial not in range(11600,11625):continue
   var at=state.origin+Vector2(i%state.size.x,i/state.size.x)*3.0
   placements.append([at,serial])
  placements.sort_custom(func(a,b):return a[0].y<b[0].y)
  for row in placements:
   var serial:int=row[1];var graphic:Dictionary=Native.Art.data().graphics[str(serial)]
   if not icons.has(serial):
    var page=int(graphic.page)
    if not pages.has(page):pages[page]=Native.Art.page_image(page)
    var rect=graphic.rect
    var icon:Image=pages[page].get_region(Rect2i(rect[0],rect[1],rect[2],rect[3]))
    var width=maxi(5,roundi(maxf(6.0,(int(graphic.footprint[0])+int(graphic.footprint[1]))*1.5)*pixels.x))
    icon.resize(width,maxi(4,roundi(width*float(rect[3])/rect[2])),Image.INTERPOLATE_LANCZOS)
    icons[serial]=icon
   var center:Vector2=row[0]+Vector2(int(graphic.footprint[0])-1,1-int(graphic.footprint[1]))*1.5
   stamp(image,icons[serial],(center-chart.bounds.position)*pixels)
 return ImageTexture.create_from_image(image)

static func paving(image:Image,index:Image,atlas:Image,detail:int):
 var patches={}
 for y in index.get_height():
  for x in index.get_width():
   var pixel=index.get_pixel(x,y)
   if pixel.a<.5:continue
   var tile=Vector2i(roundi(pixel.r*255),roundi(pixel.g*255))
   if not patches.has(tile):
    var patch=atlas.get_region(Rect2i(tile*36+Vector2i(2,2),Vector2i(32,32)))
    patch.convert(Image.FORMAT_RGBA8);patch.resize(detail,detail,Image.INTERPOLATE_LANCZOS);patches[tile]=patch
   image.blit_rect(patches[tile],Rect2i(0,0,detail,detail),Vector2i(x,y)*detail)

static func house(image:Image,row:Array,atlas:Image,icons:Dictionary,chart,pixels:Vector2):
 var serial:int=row[0]
 if not icons.has(serial):
  var data:Array=Houses.GRAPHICS[serial]
  var icon=atlas.get_region(Rect2i(data[0]))
  var width=maxi(6,roundi(maxf(data[9].x,data[9].y)*pixels.x))
  icon.resize(width,maxi(6,roundi(width*data[0].size.y/data[0].size.x)),Image.INTERPOLATE_LANCZOS)
  icons[serial]=icon
 stamp(image,icons[serial],(chart.map_frame*row[1]-chart.bounds.position)*pixels)

static func stamp(image:Image,icon:Image,at:Vector2):
 image.blend_rect(icon,Rect2i(Vector2i.ZERO,icon.get_size()),Vector2i(at-Vector2(icon.get_size())*.5))

static func arena(model,bounds:Rect2)->ImageTexture:
 Arena.prepare()
 var image=Image.create_empty(768,768,false,Image.FORMAT_RGBA8)
 var source=Arena.floor_image;var atlas=Arena.Room.Atlas.get_image();var patches={}
 var floor_bounds:Rect2=model.terrain.arena_bounds()
 var pixels=Vector2(image.get_size())/bounds.size
 var tile_size=Vector2i((floor_bounds.size/Vector2(source.get_size())*pixels).ceil())
 for z in source.get_height():
  for x in source.get_width():
   var pixel=source.get_pixel(x,z)
   if pixel.a<.5:continue
   var tile=Vector2i(roundi(pixel.r*255),roundi(pixel.g*255))
   if not patches.has(tile):
    var patch=atlas.get_region(Rect2i(tile*36+Vector2i(2,2),Vector2i(32,32)))
    patch.convert(Image.FORMAT_RGBA8);patch.resize(tile_size.x,tile_size.y,Image.INTERPOLATE_LANCZOS);patches[tile]=patch
   var at=(floor_bounds.position+Vector2(x,z)*floor_bounds.size/Vector2(source.get_size())-bounds.position)*pixels
   image.blit_rect(patches[tile],Rect2i(Vector2i.ZERO,tile_size),Vector2i(at))
 var inlays=preload("res://assets/maps/falan/arena_inlays_detail.png").get_image()
 for row in Arena.Room.Arena.Data.ARENA_MARKS:
  if row[0].y<90:continue
  var icon=inlays.get_region(Rect2i(row[1]*256,0,256,256))
  var span=Vector2.ONE*Arena.INLAY_SIZE*model.terrain_scale*2.0*pixels
  icon.resize(roundi(span.x),roundi(span.y),Image.INTERPOLATE_LANCZOS)
  stamp(image,icon,((Arena.SOURCE_ORIGIN+Vector2(row[0])*3.0-Arena.CENTER)*model.terrain_scale*2.0-bounds.position)*pixels)
 return ImageTexture.create_from_image(image)
