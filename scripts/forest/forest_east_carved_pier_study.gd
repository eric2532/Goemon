extends RefCounted
## Source1230051continuous pier: original observed paint, inferred hidden masonry.
const Measurements=preload("res://scripts/forest/forest_east_mouse_room_piers.gd")
const Source=preload("res://scripts/forest/forest_coastal_mesh.gd")
const Art=preload("res://scripts/forest/forest_original_map_art.gd")
const East=preload("res://scripts/forest/forest_east_region_art.gd")
const Reuse=preload("res://scripts/forest/forest_east_room_furniture.gd")
const Profiles=preload("res://scripts/forest/forest_east_fallback_families.gd")
const Fort=preload("res://scripts/forest/forest_stone_fort.gd")
const MASONRY="res://assets/maps/falan/east_region/carved_pier_study/inferred-masonry-albedo-v1.png"
const MASONRY_CPU="res://assets/maps/falan/east_region/carved_pier_study/inferred-masonry-albedo-v1.res"
const NATIVE_CPU="res://assets/maps/original_crossgate/east/carved-cpu-pages/east-atlas-13.res"
const TEXTURE_PITCH=4.8
const ROWS:Array[Vector3]=[Vector3(1.40,0,1.40),Vector3(1.40,.18,1.40),Vector3(1.25,.30,1.25),Vector3(1.18,.47,1.18),Vector3(.94,.65,.94),Vector3(.94,.90,.94),Vector3(1.02,1.4,1.02),Vector3(1.12,2.1,1.12),Vector3(1.12,2.8,1.12),Vector3(1.12,3.4,1.12),Vector3(1.12,4.1,1.12),Vector3(1.12,4.8,1.12),Vector3(1.12,5.7,1.12),Vector3(1.13,6.1,1.13),Vector3(1.27,6.3,1.27),Vector3(1.40,6.42,1.40),Vector3(1.40,6.70,1.40)]
static var meshes:Dictionary={}
static var stone_material:ShaderMaterial
static var native_image:Image
static var masonry_image:Image

static func stone_surface()->ShaderMaterial:
 if stone_material==null:
  stone_material=Source.material(load(MASONRY)).duplicate()
  stone_material.set_shader_parameter("original_palette",false);stone_material.set_shader_parameter("alpha_cutout",false);stone_material.set_shader_parameter("base_color",Color("e5e1d1"))
 return stone_material

static func extent(rows:Array[Vector3],y:float)->Vector3:
 for i in range(1,rows.size()):
  if y<=rows[i].y:return rows[i-1].lerp(rows[i],inverse_lerp(rows[i-1].y,rows[i].y,y))
 return rows[-1]

static func dense_profile(rows:Array[Vector3])->Mesh:
 var level_set={}
 for row:Vector3 in rows:level_set[roundi(row.y*1000)]=row.y
 for i in range(5,29):level_set[i*200]=i*.2
 var levels=level_set.values()
 levels.sort()
 var tool=SurfaceTool.new();tool.begin(Mesh.PRIMITIVE_TRIANGLES)
 for band in range(1,levels.size()):
  var low=extent(rows,levels[band-1]);var high=extent(rows,levels[band])
  var below=Profiles.ring(Vector2(low.x,low.z),low.y,Vector3.ZERO,.2)
  var above=Profiles.ring(Vector2(high.x,high.z),high.y,Vector3.ZERO,.2)
  for face in 8:
   var next=(face+1)%8;var steps=12 if face%2==0 else 2
   for i in steps:
    var u0=float(i)/steps;var u1=float(i+1)/steps
    var a=below[face] if i==0 else below[face].lerp(below[next],u0)
    var b=above[face] if i==0 else above[face].lerp(above[next],u0)
    var c=above[next] if i+1==steps else above[face].lerp(above[next],u1)
    var d=below[next] if i+1==steps else below[face].lerp(below[next],u1)
    var normal=(c-a).cross(b-a).normalized()
    for vertex in [[a,u0],[b,u0],[c,u1],[a,u0],[c,u1],[d,u1]]:
     var point:Vector3=vertex[0];tool.set_normal(normal);tool.set_uv(Vector2(face,0));tool.set_uv2(Vector2(point.y,vertex[1]));tool.add_vertex(point)
 for top in [false,true]:
  var row:Vector3=rows[-1] if top else rows[0];var corners=Profiles.ring(Vector2(row.x,row.z),row.y,Vector3.ZERO,.2);var center=Vector3.UP*row.y;var ring:Array[Vector3]=[]
  for face in 8:
   var steps=12 if face%2==0 else 2
   for i in steps:ring.append(corners[face] if i==0 else corners[face].lerp(corners[(face+1)%8],float(i)/steps))
  for i in ring.size():
   var next=(i+1)%ring.size()
   for point:Vector3 in ([center,ring[next],ring[i]] if top else [center,ring[i],ring[next]]):
    tool.set_normal(Vector3.UP if top else Vector3.DOWN);tool.set_uv(Vector2(8 if top else 9,0));tool.set_uv2(Vector2(row.y,0));tool.add_vertex(point)
 tool.index();var arrays=tool.commit_to_arrays();var model=tool.commit();model.surface_set_material(0,stone_surface());model.set_meta("east_cpu_arrays",[Source.committed_arrays(arrays)]);return model

static func sample(image:Image,pixel:Vector2,repeat_:bool)->Color:
 var size_=image.get_size()
 if not repeat_:pixel=pixel.clamp(Vector2.ZERO,Vector2(size_)-Vector2.ONE)
 var low=Vector2i(pixel.floor());var blend=pixel-Vector2(low);var high=low+Vector2i.ONE
 if repeat_:
  low=Vector2i(posmod(low.x,size_.x),posmod(low.y,size_.y));high=Vector2i(posmod(high.x,size_.x),posmod(high.y,size_.y))
 else:high=high.min(size_-Vector2i.ONE)
 return image.get_pixelv(low).lerp(image.get_pixel(high.x,low.y),blend.x).lerp(image.get_pixel(low.x,high.y).lerp(image.get_pixelv(high),blend.x),blend.y)

static func material_uv(point:Vector3,tag:Vector2,face:int,scale_:float)->Vector2:
 if face>=8:return Vector2(point.x,point.z)/TEXTURE_PITCH
 var span=2.*(extent(ROWS,tag.x).x-.2)*scale_;var bevel=.2*sqrt(2.)*scale_
 var along=int(face/2)*(span+bevel)+(span if face%2 else 0.)+tag.y*(bevel if face%2 else span)
 # Keep the unwrap seam underneath the observed opaque corner paint.
 along=fposmod(along-span-bevel*.5,4.*(span+bevel))
 return Vector2(along,point.y)/TEXTURE_PITCH

static func relief(point:Vector3,normal:Vector3,tag:Vector2,g:Dictionary,face:int,scale_:float)->float:
 var damp=clampf((tag.x-.9)/.35,0,1)*clampf((5.7-tag.x)/.35,0,1)*clampf(tag.y/.12,0,1)*clampf((1.-tag.y)/.12,0,1)
 if damp==0:return 0.
 var light=0.
 if normal.dot(Vector3(-1,0,1))>.15:
  var pixel=-Vector2(g.origin[0],g.origin[1])+Vector2((point.x+point.z)*32./3.,(point.z-point.x)*8.-point.y/.045)
  var color=sample(native_image,pixel,false)
  if color.a<.5:return 0.
  light=color.get_luminance()*(2. if normal.z>.7 else 1.)
 else:
  light=sample(masonry_image,material_uv(point,tag,face,scale_)*Vector2(masonry_image.get_size()),true).get_luminance()
 return clampf((light-.25)*.18,0,.09)*damp

static func sculpt(model:Mesh,g:Dictionary)->Mesh:
 var arrays:Array=model.get_meta("east_cpu_arrays")[0].duplicate(true);var points:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX];var normals:PackedVector3Array=arrays[Mesh.ARRAY_NORMAL];var tags:PackedVector2Array=arrays[Mesh.ARRAY_TEX_UV2];var faces:PackedVector2Array=arrays[Mesh.ARRAY_TEX_UV]
 var vertical=6.7/model.get_aabb().size.y;var epsilon=.03;var scale_=model.get_aabb().size.x/2.8
 var outward=[Vector3.LEFT,Vector3(-1,0,1).normalized(),Vector3.BACK,Vector3(1,0,1).normalized(),Vector3.RIGHT,Vector3(1,0,-1).normalized(),Vector3.FORWARD,Vector3(-1,0,-1).normalized()]
 for i in points.size():
  var face=roundi(faces[i].x)
  if face>=8:continue
  var point=points[i];var normal=normals[i];var direction:Vector3=outward[face];var tag=tags[i];var height=relief(point,direction,tag,g,face,scale_)
  if height==0:continue
  var axis=Vector3(-direction.z,0,direction.x)
  var span=(.2*sqrt(2.) if face%2 else 2.*(extent(ROWS,tag.x).x-.2))*scale_;var horizontal_tag=Vector2(0,-epsilon/span)
  var horizontal=(relief(point+axis*epsilon,direction,tag+horizontal_tag,g,face,scale_)-relief(point-axis*epsilon,direction,tag-horizontal_tag,g,face,scale_))/(2.*epsilon)
  var up=(relief(point+Vector3.UP*epsilon,direction,tag+Vector2(epsilon*vertical,0),g,face,scale_)-relief(point-Vector3.UP*epsilon,direction,tag-Vector2(epsilon*vertical,0),g,face,scale_))/(2.*epsilon)
  points[i]=point+direction*height;normals[i]=(normal-axis*horizontal-Vector3.UP*up).normalized()
 arrays[Mesh.ARRAY_VERTEX]=points;arrays[Mesh.ARRAY_NORMAL]=normals
 var result=ArrayMesh.new();result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays);result.surface_set_material(0,stone_surface());result.set_meta("east_cpu_arrays",[Source.committed_arrays(arrays)]);return result

static func mesh(serial:int,graphic:Dictionary)->Mesh:
 assert(serial==1230051,"Review one source appearance before extending the family")
 if meshes.has(serial):return meshes[serial]
 var g:Dictionary=Measurements.data().graphics[str(serial)];assert(g.source_rgba_sha256==graphic.rgba_sha256,"Source measurements remain exact")
 var rect:Array=graphic.rect;var cpu_page:Image=load(NATIVE_CPU)
 assert(cpu_page.get_meta("source_page")==Art.ROOT+str(Art.data().pages[int(graphic.page)]),"Prepared CPU image belongs to this source atlas")
 native_image=cpu_page.get_region(Rect2i(rect[0],rect[1],rect[2],rect[3]));native_image.convert(Image.FORMAT_RGBA8)
 var hash_=HashingContext.new();hash_.start(HashingContext.HASH_SHA256);hash_.update(native_image.get_data());assert(hash_.finish().hex_encode()==g.source_rgba_sha256,"Relief reads exact original front pixels")
 masonry_image=load(MASONRY_CPU)
 var model=sculpt(Reuse.fitted(dense_profile(ROWS),g),g)
 var front=Source.new([Rect2(rect[0],rect[1],rect[2],rect[3]),-Vector2(g.origin[0],g.origin[1]),Vector2.ONE,0],Art.page_texture(int(graphic.page)),.045)
 var arrays:Array=model.get_meta("east_cpu_arrays")[0];var ids:PackedInt32Array=arrays[Mesh.ARRAY_INDEX]
 for i in range(0,ids.size(),3):
  var face=roundi(arrays[Mesh.ARRAY_TEX_UV][ids[i]].x)
  if face not in [0,1,2,8]:continue
  for j in 3:
   var index=ids[i+j];var point:Vector3=arrays[Mesh.ARRAY_VERTEX][index];var normal:Vector3=arrays[Mesh.ARRAY_NORMAL][index];front.projected_vertex(point+normal*.003,normal,point)
 var skin=front.finish(true);skin.set_meta("east_cpu_arrays",[skin.get_meta("source_surface_arrays")])
 var uv:PackedVector2Array=arrays[Mesh.ARRAY_TEX_UV].duplicate();var scale_=model.get_aabb().size.x/2.8
 for i in uv.size():uv[i]=material_uv(arrays[Mesh.ARRAY_VERTEX][i],arrays[Mesh.ARRAY_TEX_UV2][i],roundi(uv[i].x),scale_)
 arrays=arrays.duplicate(true);arrays[Mesh.ARRAY_TEX_UV]=uv;arrays[Mesh.ARRAY_TEX_UV2]=null
 var painted=ArrayMesh.new();painted.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays);painted.surface_set_material(0,stone_surface());painted.set_meta("east_cpu_arrays",[arrays]);model=painted
 var result=East.combine([model,skin]);result.set_meta("source_physical_surface_count",1);result.set_meta("source_carved_pier",serial);result.set_meta("source_rgba_sha256",g.source_rgba_sha256)
 result.set_meta("source_stone_patch_centers",[]);result.set_meta("inferred_details",["Continuous shallow relief depth is inferred; observed faces read exact original pixels and retain their complete source paint.","Unseen faces use a separately labeled generated masonry material at4.8source units per repeat, with corresponding shallow geometry. Canonical shared stone shader and all placements/physical owners are unchanged."])
 meshes[serial]=result;return result
