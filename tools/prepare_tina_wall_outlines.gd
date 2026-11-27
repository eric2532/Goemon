extends SceneTree
## Prepare source contours without reading textures back from the GPU at map entry.
const Art=preload("res://scripts/forest/forest_original_map_art.gd")
const Street=preload("res://scripts/forest/forest_tina_street_details.gd")
const OUTPUT="res://assets/maps/falan/tina/wall-outlines.json"
func _initialize():
 var result={"schema":1,"graphics":{},"graves":{}};var pages={}
 for serial in Street.WALLS:
  var g:Dictionary=Art.data().graphics[str(serial)]
  if not pages.has(g.page):pages[g.page]=Image.load_from_file(Art.ROOT+Art.data().pages[int(g.page)])
  var image:Image=pages[g.page].get_region(Rect2i(g.rect[0],g.rect[1],g.rect[2],g.rect[3]));image.convert(Image.FORMAT_RGBA8)
  var hash_=HashingContext.new();hash_.start(HashingContext.HASH_SHA256);hash_.update(image.get_data())
  var digest=hash_.finish().hex_encode()
  if digest!=g.rgba_sha256:printerr("Original wall pixels differ: ",serial);quit(1);return
  var mask=BitMap.new();mask.create(image.get_size())
  for y in image.get_height():
   for x in image.get_width():
    var pixel=image.get_pixel(x,y)
    var shadow=is_equal_approx(pixel.r,71.0/255) and is_equal_approx(pixel.g,pixel.r) and is_equal_approx(pixel.b,pixel.r)
    mask.set_bit(x,y,pixel.a>.8 and pixel.g>.01 and not shadow)
  mask.grow_mask(1,Rect2i(Vector2i.ZERO,image.get_size()));mask.grow_mask(-1,Rect2i(Vector2i.ZERO,image.get_size()))
  var outline=PackedVector2Array();var largest=0.0
  for polygon:PackedVector2Array in mask.opaque_to_polygons(Rect2i(Vector2i.ZERO,image.get_size()),2.0):
   var area=0.0
   for i in polygon.size():area+=polygon[i].cross(polygon[(i+1)%polygon.size()])
   if absf(area)>largest:largest=absf(area);outline=polygon
  if Geometry2D.triangulate_polygon(outline).is_empty():printerr("Invalid native wall contour: ",serial);quit(1);return
  var points=[]
  for pixel in outline:points.append([pixel.x,pixel.y])
  result.graphics[str(serial)]={"source_rgba_sha256":digest,"outline":points}
 for serial in Street.TOMBS:
  var g:Dictionary=Art.data().graphics[str(serial)]
  if not pages.has(g.page):pages[g.page]=Image.load_from_file(Art.ROOT+Art.data().pages[int(g.page)])
  var image:Image=pages[g.page].get_region(Rect2i(g.rect[0],g.rect[1],g.rect[2],g.rect[3]));image.convert(Image.FORMAT_RGBA8)
  var hash_=HashingContext.new();hash_.start(HashingContext.HASH_SHA256);hash_.update(image.get_data())
  var digest=hash_.finish().hex_encode()
  if digest!=g.rgba_sha256:printerr("Original grave pixels differ: ",serial);quit(1);return
  var mask=BitMap.new();mask.create(image.get_size());var samples=[];var mean=Vector3.ZERO
  for y in image.get_height():
   for x in image.get_width():
    var pixel=image.get_pixel(x,y)
    var shadow=is_equal_approx(pixel.r,71.0/255) and pixel.r==pixel.g and pixel.g==pixel.b
    var solid=pixel.a>.8 and not shadow
    mask.set_bit(x,y,solid)
    if solid and x>image.get_width()*.3 and x<image.get_width()*.65 and y>image.get_height()*.25 and y<image.get_height()*.55:
     var rgb=Vector3(pixel.r,pixel.g,pixel.b);samples.append([Vector2(x+.5,y+.5),rgb]);mean+=rgb
  if samples.is_empty():printerr("Missing original stone pigment: ",serial);quit(1);return
  mean/=samples.size();var edge=Vector2.ZERO;var closest=INF
  for sample in samples:
   var error:float=sample[1].distance_squared_to(mean)
   if error<closest:closest=error;edge=sample[0]
  mask.grow_mask(1,Rect2i(Vector2i.ZERO,image.get_size()));mask.grow_mask(-1,Rect2i(Vector2i.ZERO,image.get_size()))
  var outlines=[]
  for polygon:PackedVector2Array in mask.opaque_to_polygons(Rect2i(Vector2i.ZERO,image.get_size()),.7):
   if polygon.size()<3 or Geometry2D.triangulate_polygon(polygon).is_empty():continue
   var points=[]
   for pixel in polygon:points.append([pixel.x,pixel.y])
   outlines.append(points)
  if outlines.is_empty():printerr("Invalid original grave contour: ",serial);quit(1);return
  var parts=[]
  for outline in outlines:
   if serial!=11062:parts.append({"points":outline,"flat":serial==11050});continue
   var width=float(image.get_width());var height=float(image.get_height())
   var clips=[PackedVector2Array([Vector2(-1,-1),Vector2(width+1,-1),Vector2(width+1,.75*(width+1)+21.25),Vector2(-1,20.5)]),PackedVector2Array([Vector2(-1,20.5),Vector2(width+1,.75*(width+1)+21.25),Vector2(width+1,height+1),Vector2(-1,height+1)])]
   var polygon=PackedVector2Array()
   for pixel in outline:polygon.append(Vector2(pixel[0],pixel[1]))
   for plane in 2:
    for piece in Geometry2D.intersect_polygons(polygon,clips[plane]):
     if piece.size()<3 or Geometry2D.triangulate_polygon(piece).is_empty():continue
     var points=[]
     for pixel in piece:points.append([pixel.x,pixel.y])
     parts.append({"points":points,"flat":plane==1})
  result.graves[str(serial)]={"source_rgba_sha256":digest,"outlines":outlines,"parts":parts,"edge_pixel":[edge.x,edge.y]}
 if "--check" in OS.get_cmdline_user_args():
  var old=JSON.parse_string(FileAccess.get_file_as_string(OUTPUT))
  if old!=JSON.parse_string(JSON.stringify(result)):
   printerr("Prepared native wall contours do not reproduce");quit(1);return
 else:
  var file=FileAccess.open(OUTPUT,FileAccess.WRITE);file.store_string(JSON.stringify(result,"  ")+"\n")
 print("TINA_WALL_OUTLINES_RESULT graphics=",result.graphics.size()," graves=",result.graves.size()," source hashes and simple contours verified")
 quit()
