extends SceneTree
## CPU source-coordinate coverage; no map scene, import pass or rendering.
const Shrine=preload("res://scripts/forest/forest_east_living_paint_prototype.gd")
var rows=[]
func _initialize():run.call_deferred()
func run():
 Shrine.Base.Art.load_east();var g:Dictionary=Shrine.Base.Art.data().graphics["1230040"]
 var data:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(Shrine.ROOT+"data.json"));var failures=0
 for index in data.root_hubs.size():
  var hub:Dictionary=data.root_hubs[index].duplicate(true);hub.material="living_bark";hub.profile=[[0,1.05],[.16,1.08],[.4,.97],[.67,.76],[.85,.60],[1.,.45]]
  var shape:Mesh=Shrine.Base.round_body(g,hub);var arrays:Array=shape.get_meta("east_cpu_arrays")[0];var uv:PackedVector2Array=arrays[Mesh.ARRAY_TEX_UV];var triangles=[]
  for start in range(0,uv.size(),3):
   var p=[];var bounds:Rect2
   for corner in 3:
    var pixel=uv[start+corner]*Shrine.Base.texture(g).get_size()-Vector2(g.rect[0],g.rect[1]);p.append(pixel);bounds=Rect2(pixel,Vector2.ZERO)if corner==0 else bounds.expand(pixel)
   triangles.append([p,bounds])
  var image=Image.load_from_file(ProjectSettings.globalize_path(Shrine.ROOT+data.houses[index].feature_file));var required=0;var covered=0;var missing=[]
  for y in image.get_height():
   for x in image.get_width():
    if image.get_pixel(x,y).a<.5:continue
    required+=1;var p=Vector2(x+.5,y+.5);var found=false
    for triangle:Array in triangles:
     if triangle[1].grow(.6).has_point(p) and Geometry2D.point_is_inside_triangle(p,triangle[0][0],triangle[0][1],triangle[0][2]):found=true;break
    if found:covered+=1
    elif missing.size()<20:missing.append([x,y])
  var ratio=float(covered)/required;rows.append({"house":index,"source_pixels":required,"covered_pixels":covered,"coverage":ratio,"missing_sample":missing,"hub":hub});failures+=int(ratio<.98)
 var file=FileAccess.open("res://build/Other Files/Asset Toolkit/East Gate Region/Visual Landmarks/Living Paint Prototype/hub-source-coverage.json",FileAccess.WRITE);file.store_string(JSON.stringify({"rows":rows,"failures":failures,"scope":"Original doorway/window paint coverage by source-projected root hub surfaces; not rendered acceptance."},"  "));file.close()
 print("EAST_SHRINE_HUB_COVERAGE ",JSON.stringify(rows)," failures=",failures);quit(failures)
