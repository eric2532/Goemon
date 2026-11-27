extends SceneTree
## Pixel/field preservation only; this is not a rendered performance check.
const Residual=preload("res://assets/maps/falan/freyja_residual/data.gd")
const Regions=preload("res://scripts/forest/forest_freyja_regions.gd")
const Road=preload("res://scripts/forest/forest_east_road.gd")
const Terrain=preload("res://scripts/forest/forest_freyja_terrain.gd")
const Illustration=preload("res://scripts/forest/forest_map_illustration.gd")
const OUT="res://build/Other Files/Asset Toolkit/East Gate Region/Runtime Audit/cpu-mask-preservation.json"
var checks=0
var failures=[]
var observations=[]
func _initialize():run.call_deferred()
func check(ok:bool,label:String):
 checks+=1
 if not ok:failures.append(label);push_error(label)
func digest(bytes:PackedByteArray)->String:
 var context=HashingContext.new();context.start(HashingContext.HASH_SHA256);context.update(bytes);return context.finish().hex_encode()
func same_image(a:Image,b:Image,label:String):
 check(a.get_size()==b.get_size(),label+" dimensions")
 check(a.get_format()==b.get_format(),label+" format")
 check(a.has_mipmaps()==b.has_mipmaps(),label+" mip levels")
 check(a.get_data()==b.get_data(),label+" allRGBA bytes including transparent RGB")
 observations.append({"image":label,"dimensions":[a.get_width(),a.get_height()],"format":a.get_format(),"rgba_sha256":digest(a.get_data())})

func source_residual(area:String)->Image:
 # The active owner now loads prepared whole-source CPU Images. Compare them
 # with independently decoded source PNG bytes and the preparer's pinned hash.
 var full=preload("res://assets/maps/falan/freyja_residual/full/data.gd")
 var image=Image.load_from_file("res://assets/maps/falan/freyja_residual/full/"+area+"-surface.png")
 image.convert(Image.FORMAT_RGBA8)
 check(digest(image.get_data())==full.MASK_RGBA[area],"Prepared source PNG matches declared RGBA "+area)
 return image

func old_joined(area:String,base:Image,origin:Vector2)->Image:
 var image:Image=base.duplicate();var village:String=Regions.CONNECTED_VILLAGES[area]
 # The reference painting algorithm uses the currently selected source mask.
 # Unknown-only village completion intentionally changes its input pixels.
 var selected:Texture2D=Regions.village_mask(village)
 var mask:Image=selected.get_meta("source_cpu_image")if selected.has_meta("source_cpu_image")else selected.get_image()
 var placement=Regions.village_transform(village)
 for z in mask.get_height():
  for x in mask.get_width():
   var paint=mask.get_pixel(x,z)
   if paint.a<.5:continue
   var cell=Vector2i(((placement*(Regions.Sites.VILLAGES[village][2]+Vector2(x,z)*3.)-origin)/3.).round())
   if not Rect2i(Vector2i.ZERO,image.get_size()).has_point(cell):continue
   if paint.r<.5 or image.get_pixelv(cell).a<.5:image.set_pixelv(cell,paint)
 return image

func old_east_field(image:Image)->Dictionary:
 var width=maxi(image.get_width(),image.get_height());var heights=PackedFloat32Array();heights.resize(width*width)
 var bed=heights.duplicate();var covered=PackedByteArray();covered.resize(heights.size());var bridges=covered.duplicate()
 var frame=Regions.frame("east_gate")
 for z in image.get_height():
  for x in image.get_width():
   var tile=image.get_pixel(x,z)
   if tile.a<.5:continue
   var i=z*width+x;var at=Road.ORIGIN+Vector2(x,z)*Road.STEP;var source=frame*at;var bank=6.0
   if at.y>244:bank+=(3*sin(at.x*.023+at.y*.016)+2*cos(at.y*.027-at.x*.011))*smoothstep(244,326,at.y)
   bank=lerpf(bank,6.,smoothstep(105,140,-at.x))
   bank=lerpf(bank,Regions.land_height(source),smoothstep(370,405,at.y))
   bank=Regions.village_bank("east_gate",at,bank)
   heights[i]=bank*(1-tile.r);bed[i]=heights[i];covered[i]=int(tile.r<.5)
   if Road.CITY_BRIDGE.has_point(at) or Road.CANAL.has_point(source):heights[i]=6.;bed[i]=0.;covered[i]=1;bridges[i]=1
 return {"width":width,"spacing":Road.STEP,"heights":heights,"bed":bed,"covered":covered,"bridges":bridges}

func run():
 var paths=["assets/maps/falan/freyja_residual/data.gd","tools/prepare_freyja_residual_surface.py","scripts/forest/forest_freyja_regions.gd","scripts/forest/forest_east_road.gd","scripts/forest/forest_freyja_terrain.gd","scripts/forest/forest_falan_chart.gd","scripts/forest/forest_map_illustration.gd"]
 for source in [Residual.BASES,Residual.EXCEPTIONS,Residual.SURFACES]:
  for texture:Texture2D in source.values():paths.append(texture.resource_path)
 paths.append(Regions.Sites.VILLAGES.il_village[3].resource_path);paths.append(Regions.Sites.VILLAGES.alyut[3].resource_path);paths.append("assets/maps/falan/east_region/north_coast-surface.png")
 paths.append("scripts/forest/forest_east_il_source_completion.gd");paths.append("assets/maps/falan/east_region/il_source_completion/data.json");paths.append("assets/maps/falan/east_region/il_source_completion/mask.png")
 paths.append("assets/maps/falan/freyja_residual/full/data.gd")
 for area in ["freyja","east_gate"]:
  paths.append("assets/maps/falan/freyja_residual/full/"+area+"-surface.png")
  paths.append("assets/maps/falan/freyja_residual/full/cpu-masks/"+area+".res")
 var pins={}
 for path:String in paths:pins[path]=FileAccess.get_sha256(path if path.begins_with("res://") else "res://"+path)
 var residuals={}
 for area in ["freyja","east_gate"]:
  var expected=source_residual(area);var actual:Texture2D=Residual.surface(area)
  check(actual.has_meta("source_cpu_image"),area+" residual retainsCPU source")
  var image:Image=actual.get_meta("source_cpu_image");same_image(expected,image,area+" residual")
  residuals[area]=image
 var residual_hash=digest(residuals.east_gate.get_data())
 var joined_expected=old_joined("east_gate",source_residual("east_gate"),Road.ORIGIN)
 var joined:Texture2D=Road.mask();var joined_image:Image=joined.get_meta("source_cpu_image")
 same_image(joined_expected,joined_image,"East Gate village merge")
 check(digest(residuals.east_gate.get_data())==residual_hash,"Village merge duplicates its residual input beforepainting")
 var north:Texture2D=load("res://assets/maps/falan/east_region/north_coast-surface.png");var north_origin=-(north.get_size()-Vector2.ONE)*1.5
 var north_expected=old_joined("north_coast",north.get_image(),north_origin)
 var north_actual:Texture2D=Regions.joined_mask("north_coast",north,north_origin)
 same_image(north_expected,north_actual.get_meta("source_cpu_image"),"North Coast village merge")
 var terrain=Terrain.new();terrain.variant="east_gate"
 check(terrain.mask_image()==joined_image and terrain.mask_image()==terrain.mask_image(),"Freyja mask_image returns existing cached image object")
 var before=digest(joined_image.get_data());var expected_field=old_east_field(joined_expected);var actual_field:Resource=Road.field()
 check(actual_field.get_meta("width")==expected_field.width and actual_field.get_meta("spacing")==expected_field.spacing,"EastRoad field dimensions/spacing")
 for field in ["heights","bed","covered","bridges"]:
  var old=expected_field[field];var actual=actual_field.get_meta(field)
  var old_bytes:PackedByteArray=old if old is PackedByteArray else old.to_byte_array()
  var actual_bytes:PackedByteArray=actual if actual is PackedByteArray else actual.to_byte_array()
  check(old_bytes==actual_bytes,"EastRoad exact prior "+field+" array")
  observations.append({"field":field,"bytes":actual_bytes.size(),"sha256":digest(actual_bytes)})
 check(digest(joined_image.get_data())==before,"Terrain field andmask_image consumers leave cached pixels unchanged")
 var chart_image=Image.create_empty(19,13,false,Image.FORMAT_RGBA8)
 for y in 13:
  for x in 19:chart_image.set_pixel(x,y,Color8((x*17)%255,(y*23)%255,113,0 if (x+y)%3==0 else 255))
 var chart_texture=ImageTexture.create_from_image(chart_image);chart_texture.set_meta("source_cpu_image",chart_image)
 var chart={"texture":chart_texture,"bounds":Rect2(0,0,19,13),"map_frame":Transform2D.IDENTITY}
 var model={"falan_area":"interior","falan_floor":9999999,"scenery_obstacles":{"test":AABB(Vector3(3,0,4),Vector3(4,2,3))}}
 var original_bytes=chart_image.get_data();var illustrated:Texture2D=Illustration.prepare(chart,model)
 check(chart_image.get_size()==Vector2i(19,13) and chart_image.get_data()==original_bytes,"Illustration duplicates chart before resizing/painting")
 check(illustrated.get_width()==76 and illustrated.get_height()==52,"Illustration stillproduces expected4x detail")
 var expected_chart=chart_image.duplicate();expected_chart.resize(76,52,Image.INTERPOLATE_NEAREST);expected_chart.fill_rect(Rect2i(12,16,16,12),Color("596456"));expected_chart.fill_rect(Rect2i(13,17,14,10),Color("a9a28b"))
 same_image(expected_chart,illustrated.get_image(),"Illustrated chart prior resize/obstaclepaint")
 for path:String in pins:check(pins[path]==FileAccess.get_sha256(path if path.begins_with("res://") else "res://"+path),"Unchanged source "+path)
 var f=FileAccess.open(OUT,FileAccess.WRITE);f.store_string(JSON.stringify({"checks":checks,"failures":failures,"source_hashes":pins,"observations":observations,"scope":"Headless exact existingCPU image/field/copy preservation only. Imported firstreads remain; no render performance ornormal EastGate route acceptance."},"  "));f.close()
 print("EAST_CPU_MASK_RESULT checks=",checks," failures=",failures.size());quit(failures.size())
