extends RefCounted
## Private source-sized pier study; OriginalMaps still owns all placements.
const Art=preload("res://scripts/forest/forest_original_map_art.gd")
const Source=preload("res://scripts/forest/forest_coastal_mesh.gd")
const East=preload("res://scripts/forest/forest_east_region_art.gd")
const Furniture=preload("res://scripts/forest/forest_falan_interior_furniture.gd")
const Reuse=preload("res://scripts/forest/forest_east_room_furniture.gd")
const Profiles=preload("res://scripts/forest/forest_east_fallback_families.gd")
const Fort=preload("res://scripts/forest/forest_stone_fort.gd")
const ROOT="res://assets/maps/falan/east_region/mouse_room_piers/"
static var catalog:Dictionary={}
static var meshes:Dictionary={}
const SOURCE_VIEW=Vector3(-1./16.,.045,1./16.)
static func data()->Dictionary:
 if catalog.is_empty():catalog=JSON.parse_string(FileAccess.get_file_as_string(ROOT+"data.json"))
 return catalog
static func ball_paint(skin,arrays:Array,region:Rect2,crop:Array,rect:Array):
 var ids:PackedInt32Array=arrays[Mesh.ARRAY_INDEX]
 for i in range(0,ids.size(),3):
  var polygon=[]
  for j in 3:
   var index=ids[i+j];polygon.append([arrays[Mesh.ARRAY_VERTEX][index],arrays[Mesh.ARRAY_NORMAL][index]])
  var clipped=[];var prior:Array=polygon[-1];var prior_side:float=prior[1].dot(SOURCE_VIEW)
  for vertex:Array in polygon:
   var side:float=vertex[1].dot(SOURCE_VIEW)
   if (side>=0.)!=(prior_side>=0.):
    var t=prior_side/(prior_side-side);clipped.append([prior[0].lerp(vertex[0],t),prior[1].lerp(vertex[1],t).normalized()])
   if side>=0.:clipped.append(vertex)
   prior=vertex;prior_side=side
  # Clip the observed hemisphere continuously through crossing triangles;
  # selecting whole triangle faces leaves a sawtooth material seam.
  for corner in range(1,clipped.size()-1):
   for vertex:Array in[clipped[0],clipped[corner],clipped[corner+1]]:
    var p:Vector3=vertex[0];var normal:Vector3=vertex[1]
    var pixel=Vector2((p.x+p.z)*32./3.,(p.z-p.x)*8.-p.y/.045)
    var native=Vector2(crop[0],crop[1])+(pixel-region.position)/region.size*Vector2(crop[2]-crop[0],crop[3]-crop[1])
    skin.surface.set_normal(normal);skin.surface.set_uv((Vector2(rect[0],rect[1])+native.clamp(Vector2(crop[0]+.5,crop[1]+.5),Vector2(crop[2]-.5,crop[3]-.5)))/skin.texture.get_size());skin.surface.add_vertex(p+normal*.003)
static func mesh(serial:int,graphic:Dictionary)->Mesh:
 assert(serial==1230127,"Review the ball-capped pier before extending to carved/figurine variants")
 if meshes.has(serial):return meshes[serial]
 var g:Dictionary=data().graphics[str(serial)]
 assert(g.source_rgba_sha256==graphic.rgba_sha256,"Regenerate original pier measurements")
 Furniture.Parts.prepare_primitives()
 var stone=Furniture.tool()
 # Reuse the closed moulding profile without adding a second shape owner.
 var base=Source.new([],null,.045);base.tiles={"stone":Vector2.ZERO,"gold":Vector2.ZERO,"cap":Vector2.ZERO}
 var unused_front=Source.new([Rect2(0,0,1,1),Vector2.ZERO,Vector2.ONE,0],Art.page_texture(int(graphic.page)),.045)
 Profiles.profile(base,unused_front,[Vector3(1.05,0,1.05),Vector3(1.05,.60,1.05),Vector3(.88,.73,.88),Vector3(.73,.87,.73),Vector3(.73,3.07,.73),Vector3(.78,3.17,.78),Vector3(.78,3.37,.78),Vector3(.69,3.45,.69)],Vector3.ZERO,.05)
 for y in[1.08,1.46,1.84,2.22,2.60,2.98]:Furniture.rounded_block(stone,Vector3.UP*y,Vector3(1.53,.075,1.53),.02)
 var masonry=base.surface.commit();masonry.surface_set_material(0,Fort.material(Color("72523c"),false))
 var bands=stone.commit();bands.surface_set_material(0,Fort.material(Color("8c6849"),false))
 var grain=StandardMaterial3D.new();grain.albedo_texture=Fort.ROCK;grain.texture_repeat=true;grain.roughness=.95;grain.uv1_triplanar=true
 grain.uv1_scale=Vector3.ONE/float(g.hidden_surface_source.pitch_m)
 var tint:Array=g.hidden_surface_source.tint_srgb;grain.albedo_color=Color(tint[0],tint[1],tint[2])
 var sphere=SphereMesh.new();sphere.radius=.7;sphere.height=1.60;sphere.radial_segments=32;sphere.rings=16;sphere.material=grain
 var orb=East.transformed_existing(sphere,Transform3D(Basis.IDENTITY,Vector3.UP*4.25))
 # Fit the complete connected master once; separate screen fits move parts in XZ.
 var model=Reuse.fitted(East.combine([masonry,bands,orb]),g)
 var rect=graphic.rect
 var skin=Source.new([Rect2(rect[0],rect[1],rect[2],rect[3]),-Vector2(g.origin[0],g.origin[1]),Vector2.ONE,0],Art.page_texture(int(graphic.page)),.045)
 var ball_skin=Source.new(skin.graphic,skin.texture,.045)
 var orb_bounds=Rect2();var first=true
 var orb_arrays:Array=model.get_meta("east_cpu_arrays")[2]
 for p:Vector3 in orb_arrays[Mesh.ARRAY_VERTEX]:
  var pixel=Vector2((p.x+p.z)*32./3.,(p.z-p.x)*8.-p.y/.045)
  orb_bounds=Rect2(pixel,Vector2.ZERO)if first else orb_bounds.expand(pixel);first=false
 for slot in model.get_surface_count():
  var arrays:Array=model.get_meta("east_cpu_arrays")[slot]
  if slot==2:
   ball_paint(ball_skin,arrays,orb_bounds,g.ball_front_crop,rect);continue
  var ids:Variant=arrays[Mesh.ARRAY_INDEX];var indexed=ids is PackedInt32Array and not ids.is_empty();var count_:int=ids.size()if indexed else arrays[Mesh.ARRAY_VERTEX].size()
  for i in range(0,count_,3):
   var vertices=[ids[i],ids[i+1],ids[i+2]]if indexed else[i,i+1,i+2]
   var normal:Vector3=(arrays[Mesh.ARRAY_NORMAL][vertices[0]]+arrays[Mesh.ARRAY_NORMAL][vertices[1]]+arrays[Mesh.ARRAY_NORMAL][vertices[2]]).normalized()
   if normal.dot(Vector3(-1,0,1))<.15 or normal.y>.7:continue
   for index:int in vertices:
    var p:Vector3=arrays[Mesh.ARRAY_VERTEX][index]
    skin.projected_vertex(p+normal*.003,normal,p)
 var result=East.combine([model,skin.finish(true),ball_skin.finish(true)])
 result.set_meta("source_ball_paint_surface",result.get_surface_count()-1)
 result.set_meta("source_mouse_room_pier",serial);result.set_meta("source_rgba_sha256",g.source_rgba_sha256);result.set_meta("inferred_closed_reverse",true)
 meshes[serial]=result
 return result
