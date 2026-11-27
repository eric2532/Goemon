extends RefCounted
## Private wall-embedded variants. No canonical scenery dispatch.
const Base=preload("res://scripts/forest/forest_east_carved_pier_study.gd")
const IDS=[1230052,1230054,1230055,1230056]
const INFERRED_FRONT54="res://assets/maps/falan/east_region/carved_pier_study/inferred-1230054-front-v1.png"
static var meshes:Dictionary={}

static func relief(image:Image,g:Dictionary,p:Vector3,tag:Vector2,face:int)->float:
 if face not in[0,1,2]:return 0.
 var damp=clampf((tag.x-.9)/.35,0,1)*clampf((5.7-tag.x)/.35,0,1)*clampf(tag.y/.12,0,1)*clampf((1.-tag.y)/.12,0,1)
 if damp==0:return 0.
 var pixel=-Vector2(g.origin[0],g.origin[1])+Vector2((p.x+p.z)*32./3.,(p.z-p.x)*8.-p.y/.045)
 var color=Base.sample(image,pixel,false)
 if color.a<.5:return 0.
 # The saturated plain infill stays planar. Pale carved strokes acquire depth;
 # this is inferred relief from the observed shading, not recovered geometry.
 return clampf((color.get_luminance()-.25)*.28,0,.15)*(1.-smoothstep(.3,.6,color.s))*damp

static func sculpt(serial:int,model:Mesh,g:Dictionary,graphic:Dictionary)->Mesh:
 var cpu:Image=load(Base.NATIVE_CPU);var rect:Array=graphic.rect
 var image=cpu.get_region(Rect2i(rect[0],rect[1],rect[2],rect[3]));image.convert(Image.FORMAT_RGBA8)
 var digest=HashingContext.new();digest.start(HashingContext.HASH_SHA256);digest.update(image.get_data());assert(digest.finish().hex_encode()==g.source_rgba_sha256,"Embedded relief uses exact native reference pixels")
 var arrays:Array=model.get_meta("east_cpu_arrays")[0].duplicate(true)
 var points:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX];var normals:PackedVector3Array=arrays[Mesh.ARRAY_NORMAL];var tags:PackedVector2Array=arrays[Mesh.ARRAY_TEX_UV2];var faces:PackedVector2Array=arrays[Mesh.ARRAY_TEX_UV]
 var flat=points.duplicate();var vertical=6.7/model.get_aabb().size.y;var scale_=model.get_aabb().size.x/2.8;var epsilon=.03
 for i in points.size():
  var face=roundi(faces[i].x);var p=points[i];var tag=tags[i];var depth=relief(image,g,p,tag,face)
  if depth==0:continue
  var corners=ring(serial,tag.x)
  var along=corners[(face+1)%8]-corners[face]
  # Shared row vertices need one displacement direction, independent of the
  # neighboring bands' different shading normals; otherwise relief opens cracks.
  var direction=Vector3(-along.z,0,along.x).normalized();var tangent=Vector3(-direction.z,0,direction.x)
  var du=epsilon/maxf(.01,corners[face].distance_to(corners[(face+1)%8])*scale_)
  var across=(relief(image,g,p+tangent*epsilon,tag-Vector2(0,du),face)-relief(image,g,p-tangent*epsilon,tag+Vector2(0,du),face))/(2.*epsilon)
  var up=(relief(image,g,p+Vector3.UP*epsilon,tag+Vector2(epsilon*vertical,0),face)-relief(image,g,p-Vector3.UP*epsilon,tag-Vector2(epsilon*vertical,0),face))/(2.*epsilon)
  points[i]=p+direction*depth;normals[i]=(normals[i]-tangent*across-Vector3.UP*up).normalized()
 arrays[Mesh.ARRAY_VERTEX]=points;arrays[Mesh.ARRAY_NORMAL]=normals
 var result=ArrayMesh.new();result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays);result.surface_set_material(0,Base.stone_surface());result.set_meta("east_cpu_arrays",[arrays]);result.set_meta("source_flat_points",flat);return result

static func ring(serial:int,y:float)->Array[Vector3]:
 var row=Base.extent(Base.ROWS,y)
 var points=Base.Profiles.ring(Vector2(row.x,row.z),y,Vector3.ZERO,.2)
 var outer=Base.Profiles.ring(Vector2(1.4,1.4),y,Vector3.ZERO,.2)
 # Native52 has a planar left infill;54/55 a planar right infill;
 #56 retains both planes around its narrower observed carved corner.
 var fixed=[0,7]if serial==1230052 else [3,4]
 if serial==1230056:fixed=[0,7,3,4]
 for corner in fixed:points[corner]=outer[corner]
 return points

static func shape(serial:int)->Mesh:
 var raw=Base.dense_profile(Base.ROWS)
 var arrays:Array=raw.get_meta("east_cpu_arrays")[0]
 var points:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX].duplicate()
 var tags:PackedVector2Array=arrays[Mesh.ARRAY_TEX_UV2]
 var faces:PackedVector2Array=arrays[Mesh.ARRAY_TEX_UV]
 for i in points.size():
  var face=roundi(faces[i].x)
  if face>=8:continue
  var corners=ring(serial,tags[i].x)
  var u=tags[i].y
  points[i]=corners[face]if u==0. else corners[(face+1)%8]if u==1. else corners[face].lerp(corners[(face+1)%8],u)
 var tool=SurfaceTool.new();tool.begin(Mesh.PRIMITIVE_TRIANGLES)
 var ids:PackedInt32Array=arrays[Mesh.ARRAY_INDEX]
 for i in range(0,ids.size(),3):
  var a=points[ids[i]];var b=points[ids[i+1]];var c=points[ids[i+2]]
  var normal=(c-a).cross(b-a).normalized()
  for j in 3:
   var at=ids[i+j];tool.set_normal(normal);tool.set_uv(faces[at]);tool.set_uv2(tags[at]);tool.add_vertex(points[at])
 tool.index();var committed=tool.commit_to_arrays();var result=tool.commit()
 result.surface_set_material(0,Base.stone_surface());result.set_meta("east_cpu_arrays",[Base.Source.committed_arrays(committed)])
 return result

static func mesh(serial:int,graphic:Dictionary)->Mesh:
 assert(serial in IDS,"Unowned embedded pier variant")
 if meshes.has(serial):return meshes[serial]
 var g:Dictionary=Base.Measurements.data().graphics[str(serial)]
 assert(g.source_rgba_sha256==graphic.rgba_sha256,"Native variant measurements remain exact")
 var model=sculpt(serial,Base.Reuse.fitted(shape(serial),g),g,graphic)
 var arrays:Array=model.get_meta("east_cpu_arrays")[0].duplicate(true)
 var points:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX];var normals:PackedVector3Array=arrays[Mesh.ARRAY_NORMAL]
 var faces:PackedVector2Array=arrays[Mesh.ARRAY_TEX_UV];var ids:PackedInt32Array=arrays[Mesh.ARRAY_INDEX]
 var r:Array=graphic.rect
 var front=Base.Source.new([Rect2(r[0],r[1],r[2],r[3]),-Vector2(g.origin[0],g.origin[1]),Vector2.ONE,0],Base.Art.page_texture(int(graphic.page)),.045)
 for i in range(0,ids.size(),3):
  if roundi(faces[ids[i]].x)not in[0,1,2,8]:continue
  for j in 3:
   var at=ids[i+j];front.projected_vertex(points[at]+normals[at]*.003,normals[at],model.get_meta("source_flat_points")[at])
 var uv=PackedVector2Array();uv.resize(points.size())
 for i in points.size():
  var p=points[i];var n=normals[i]
  uv[i]=(Vector2(p.x,p.z)if absf(n.y)>.7 else Vector2(p.z,p.y)if absf(n.x)>=absf(n.z)else Vector2(p.x,p.y))/Base.TEXTURE_PITCH
 arrays[Mesh.ARRAY_TEX_UV]=uv;arrays[Mesh.ARRAY_TEX_UV2]=null
 var body=ArrayMesh.new();body.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays);body.surface_set_material(0,Base.stone_surface());body.set_meta("east_cpu_arrays",[arrays])
 var skin=front.finish(true);skin.set_meta("east_cpu_arrays",[skin.get_meta("source_surface_arrays")])
 var paint:ShaderMaterial=skin.surface_get_material(0).duplicate();paint.set_shader_parameter("original_palette",false);skin.surface_set_material(0,paint)
 if serial==1230054:
  var texture:Texture2D=load(INFERRED_FRONT54);var inferred:Array=skin.get_meta("east_cpu_arrays")[0].duplicate(true);var coordinates:PackedVector2Array=inferred[Mesh.ARRAY_TEX_UV]
  var page_size=Vector2(Base.Art.page_texture(int(graphic.page)).get_size());var native_origin=Vector2(r[0],r[1]);var native_size=Vector2(r[2],r[3])
  for i in coordinates.size():coordinates[i]=(coordinates[i]*page_size-native_origin)/native_size*Vector2(757,2055)/Vector2(texture.get_size())
  inferred[Mesh.ARRAY_TEX_UV]=coordinates
  var replacement=ArrayMesh.new();replacement.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,inferred)
  paint=Base.Source.material(texture).duplicate();paint.set_shader_parameter("original_palette",false);replacement.surface_set_material(0,paint);replacement.set_meta("east_cpu_arrays",[inferred]);skin=replacement
 var result=Base.East.combine([body,skin]);result.set_meta("source_rgba_sha256",g.source_rgba_sha256);result.set_meta("private_embedded_pier",serial)
 result.set_meta("inferred_details",["Unseen wall depth, hidden masonry and shallow carving up to0.15source units are inferred from original references.","Original observed paint remains unchanged on an owned lit material; plain infill stays planar. No canonical dispatch or whole-room acceptance."])
 if serial==1230054:
  result.set_meta("inferred_front_paint",INFERRED_FRONT54)
  result.set_meta("inferred_details",["The1230054visible front uses a new inferred higher-resolution paint derivative, with unchanged original source pixels retained as reference; added grain and interpreted ornament are not recovered original art or verified writing.","Source footprint/projection and source-guided shallow geometry remain unchanged. Hidden masonry and relief depth are inferred; no canonical dispatch or whole-room acceptance."])
 meshes[serial]=result;return result
