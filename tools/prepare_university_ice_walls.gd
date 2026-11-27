extends SceneTree
## Reuse the route-wall contour workflow for native ice panels; no map-entry texture readback.
const Art=preload("res://scripts/forest/forest_original_map_art.gd")
const OUT="res://assets/maps/falan/university_region/ice_walls.json"
const PANELS=[10047,10048,10315,11054,11055,11060,11061,11587,11588,11589,11590,16134,16137,16235,17603,13901,13902,13903,13905,13906,13907,13909,13911,17250,17251,17266,17268,17270,17272,17274,17276,17278,17280,17281,17282,17284,17286,17287,17288,17294,17295,17296,17297,17298,17299,17300,17301,17302,17303,17304,17305,17306,17346,17347,17348,17349,17350,17351,17352,17353,17354,17355,17356,17357]
const ALONG_X=[10047,10048,10315,11054,11055,11060,11061,11589,11590,16134,16137,16235,13901,13902,13903,13909,17250,17266,17268,17276,17278,17282,17294,17295,17296,17300,17301,17302,17306,17346,17347,17352,17354,17355]
const PAINTED_BACKS={13903:13901,13905:13907,13909:13901,13911:13907,17268:17266,17270:17272,17274:17272,17276:17266,17312:17316,17314:17310}
const WIND_WALLS={17310:true,17316:false,17362:false,17364:true,17312:false,17314:true,17360:true,17366:false}

func _initialize():
 Art.load_sokia_wind()
 var result={};var pages={}
 for serial in PANELS+WIND_WALLS.keys():
  if not Art.data().graphics.has(str(serial)):continue
  var paint_serial:int=PAINTED_BACKS.get(serial,serial)
  var graphic:Dictionary=Art.data().graphics[str(paint_serial)]
  if not pages.has(graphic.page):pages[graphic.page]=Image.load_from_file(Art.ROOT+Art.data().pages[int(graphic.page)])
  var pixels:Image=pages[graphic.page].get_region(Rect2i(graphic.rect[0],graphic.rect[1],graphic.rect[2],graphic.rect[3]));pixels.convert(Image.FORMAT_RGBA8)
  var hash_=HashingContext.new();hash_.start(HashingContext.HASH_SHA256);hash_.update(pixels.get_data())
  assert(hash_.finish().hex_encode()==graphic.rgba_sha256,"The source wall crop changed")
  var mask=BitMap.new();mask.create(pixels.get_size())
  for y in pixels.get_height():
   for x in pixels.get_width():
    var c=pixels.get_pixel(x,y)
    # Wind's brown paint is darker than the ice cutoff; only its uniform grey encodes occlusion.
    var occluder=is_equal_approx(c.r,20./255.)and is_equal_approx(c.g,20./255.)and is_equal_approx(c.b,20./255.)
    mask.set_bit(x,y,c.a>.8 and (not occluder if WIND_WALLS.has(serial) else maxf(c.r,maxf(c.g,c.b))>45./255.))
  mask.grow_mask(1,Rect2i(Vector2i.ZERO,pixels.get_size()));mask.grow_mask(-1,Rect2i(Vector2i.ZERO,pixels.get_size()))
  var outlines=[]
  for polygon in mask.opaque_to_polygons(Rect2i(Vector2i.ZERO,pixels.get_size()),2. if WIND_WALLS.has(serial) else .8):
   var value=0.
   for i in polygon.size():value+=polygon[i].cross(polygon[(i+1)%polygon.size()])
   if absf(value)<8.:continue
   assert(not Geometry2D.triangulate_polygon(polygon).is_empty(),"Ice panel contour needs a closed silhouette")
   var points=[]
   for point in polygon:points.append([point.x,point.y])
   outlines.append(points)
  assert(not outlines.is_empty())
  result[str(serial)]={"paint":paint_serial,"source_rgba_sha256":graphic.rgba_sha256,"along_x":WIND_WALLS.get(serial,serial in ALONG_X),"outlines":outlines,
   "hanging":WIND_WALLS.has(serial) or serial in range(17346,17358) or serial in [16134,16137,16235,17603],"depth":1.2 if serial in [10047,10048,10315] else .48}
 if "--check" in OS.get_cmdline_user_args():assert(JSON.parse_string(FileAccess.get_file_as_string(OUT))==JSON.parse_string(JSON.stringify(result)))
 else:
  var file=FileAccess.open(OUT,FileAccess.WRITE);file.store_string(JSON.stringify(result,"  ")+"\n");file.close()
 print("UNIVERSITY_ICE_WALLS_RESULT contours=",result.size());quit()
