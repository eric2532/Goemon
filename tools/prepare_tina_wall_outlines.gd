extends SceneTree
## Prepare source contours without reading textures back from the GPU at map entry.
const Art=preload("res://scripts/forest/forest_original_map_art.gd")
const Street=preload("res://scripts/forest/forest_tina_street_details.gd")
const OUTPUT="res://assets/maps/falan/tina/wall-outlines.json"
func _initialize():
 var result={"schema":1,"graphics":{}};var pages={}
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
 if "--check" in OS.get_cmdline_user_args():
  var old=JSON.parse_string(FileAccess.get_file_as_string(OUTPUT))
  if old!=JSON.parse_string(JSON.stringify(result)):
   printerr("Prepared native wall contours do not reproduce");quit(1);return
 else:
  var file=FileAccess.open(OUTPUT,FileAccess.WRITE);file.store_string(JSON.stringify(result,"  ")+"\n")
 print("TINA_WALL_OUTLINES_RESULT graphics=",result.graphics.size()," source hashes and simple contours verified")
 quit()
