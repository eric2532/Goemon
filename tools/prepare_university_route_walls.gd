extends SceneTree
## Offline native silhouette preparation; no texture readback during map entry.
const Art=preload("res://scripts/forest/forest_original_map_art.gd")
const OUT="res://assets/maps/falan/university_route/walls.json"
func _initialize():
 var result={};var pages={}
 var serials=range(11317,11333);serials.append_array([10466,10467])
 for serial in serials:
  var g:Dictionary=Art.data().graphics[str(serial)]
  if not pages.has(g.page):pages[g.page]=Image.load_from_file(Art.ROOT+Art.data().pages[int(g.page)])
  var image:Image=pages[g.page].get_region(Rect2i(g.rect[0],g.rect[1],g.rect[2],g.rect[3]));image.convert(Image.FORMAT_RGBA8)
  var hash_=HashingContext.new();hash_.start(HashingContext.HASH_SHA256);hash_.update(image.get_data())
  assert(hash_.finish().hex_encode()==g.rgba_sha256)
  var mask=BitMap.new();mask.create(image.get_size())
  for y in image.get_height():
   for x in image.get_width():
    var c=image.get_pixel(x,y)
    mask.set_bit(x,y,c.a>.8 and maxf(c.r,maxf(c.g,c.b))>45.0/255 and not(c.r==c.g and c.g==c.b and absf(c.r-71.0/255)<.001))
  mask.grow_mask(1,Rect2i(Vector2i.ZERO,image.get_size()));mask.grow_mask(-1,Rect2i(Vector2i.ZERO,image.get_size()))
  var best=PackedVector2Array();var area=0.0
  for polygon in mask.opaque_to_polygons(Rect2i(Vector2i.ZERO,image.get_size()),.8):
   var value=0.0
   for i in polygon.size():value+=polygon[i].cross(polygon[(i+1)%polygon.size()])
   if absf(value)>area:area=absf(value);best=polygon
  assert(not Geometry2D.triangulate_polygon(best).is_empty())
  var points=[]
  for p in best:points.append([p.x,p.y])
  result[str(serial)]={"outline":points,"source_rgba_sha256":g.rgba_sha256,"along_x":serial in range(11324,11331) or serial in [11332,10466]}
 if "--check" in OS.get_cmdline_user_args():assert(JSON.parse_string(FileAccess.get_file_as_string(OUT))==JSON.parse_string(JSON.stringify(result)))
 else:
  var file=FileAccess.open(OUT,FileAccess.WRITE);file.store_string(JSON.stringify(result,"  ")+"\n")
 print("UNIVERSITY_ROUTE_WALLS_RESULT verified=",result.size());quit()
