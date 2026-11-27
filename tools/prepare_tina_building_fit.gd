extends SceneTree
## Measure existing native-painted models against the original source camera.
const Original=preload("res://scripts/forest/forest_original_maps.gd")
func _initialize():
 var fits={}
 for serial in [11409,11410,11414,11407,11416,11451,11462,11463]:
  var g:Dictionary=Original.Art.data().graphics[str(serial)]
  var mesh=Original.Forms.mesh(serial,"logs" if serial in [11462,11463] else "building",g,Original.Art.solid_texture(int(g.page)))
  var image=Image.load_from_file(Original.Art.ROOT+Original.Art.data().pages[int(g.page)]).get_region(Rect2i(g.rect[0],g.rect[1],g.rect[2],g.rect[3]))
  var source_low=Vector2.INF;var source_high=-Vector2.INF
  for y in image.get_height():
   for x in image.get_width():
    var color=image.get_pixel(x,y)
    if color.a<.99 or is_equal_approx(color.r,71.0/255) and color.r==color.g and color.g==color.b:continue
    source_low=source_low.min(Vector2(x,y));source_high=source_high.max(Vector2(x+1,y+1))
  source_low+=Vector2(g.origin[0],g.origin[1]);source_high+=Vector2(g.origin[0],g.origin[1])
  var vertices=PackedVector3Array()
  for slot in mesh.get_surface_count():vertices.append_array(mesh.surface_get_arrays(slot)[Mesh.ARRAY_VERTEX])
  var low=Vector2.INF;var high=-Vector2.INF
  for p:Vector3 in vertices:
   var pixel=Vector2((p.x+p.z)*32/3,(p.z-p.x)*8-p.y*10)
   low=low.min(pixel);high=high.max(pixel)
  var scale=(source_high.x-source_low.x)/(high.x-low.x)
  var lower=.1;var upper=4.0
  for i in 24:
   var sy=(lower+upper)*.5;var top=INF;var bottom=-INF
   for p:Vector3 in vertices:
    var y=(p.z-p.x)*8*scale-p.y*10*sy
    top=minf(top,y);bottom=maxf(bottom,y)
   if bottom-top<source_high.y-source_low.y:lower=sy
   else:upper=sy
  var sy=(lower+upper)*.5;var top=INF
  for p:Vector3 in vertices:top=minf(top,(p.z-p.x)*8*scale-p.y*10*sy)
  var u=source_low.x-low.x*scale;var v=source_low.y-top
  fits[str(serial)]={"scale":[scale,sy,scale],"offset":[(u*3/32-v/8)*.5,0,(u*3/32+v/8)*.5],"source_rgba_sha256":g.rgba_sha256,"source_outline_bounds":[source_low.x,source_low.y,source_high.x,source_high.y]}
 var file=FileAccess.open("res://assets/maps/falan/tina/building-fits.json",FileAccess.WRITE);file.store_string(JSON.stringify(fits,"  ")+"\n")
 print("TINA_BUILDING_FITS ",JSON.stringify(fits))
 quit()
