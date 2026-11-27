extends RefCounted
## Source-family candidate renderer. Enrollment remains with the existing East map owner.
const Art=preload("res://scripts/forest/forest_east_region_art.gd")
const Fort=preload("res://scripts/forest/forest_stone_fort.gd")
const Relief=preload("res://scripts/forest/forest_elsa_scenery.gd")
const Meadow=preload("res://scripts/forest/forest_wind_meadow_assets.gd")
const Crags=preload("res://scripts/forest/forest_east_field_cliffs.gd")
const Paint=preload("res://scripts/forest/forest_coastal_mesh.gd")
const ROOT="res://assets/maps/falan/east_region/stone_families/"
static var catalogs:Dictionary={}
static var meshes:Dictionary={}
static var textures:Dictionary={}
static var images:Dictionary={}
static var materials:Dictionary={}

static func data(folder:String=ROOT)->Dictionary:
 if not catalogs.has(folder):catalogs[folder]=JSON.parse_string(FileAccess.get_file_as_string(folder+"data.json"))
 return catalogs[folder]

static func owns(serial:int,folder:String=ROOT)->bool:
 var rows:Dictionary=data(folder).graphics
 return rows.has(str(serial)) and not rows[str(serial)].only_legacy_contexts

static func texture(serial:int,folder:String)->Texture2D:
 var key=[folder,serial]
 if not textures.has(key):
  images[key]=Image.load_from_file(folder+str(serial)+"-front.png");textures[key]=ImageTexture.create_from_image(images[key])
 return textures[key]

static func back_material(spec:Dictionary)->Material:
 var rgb:Array=spec.get("inferred_back_rgb",[.45,.45,.40]);var key=str(rgb)
 if not materials.has(key):materials[key]=Fort.material(Color(rgb[0],rgb[1],rgb[2]),false).duplicate()
 return materials[key]

static func source_volume(serial:int,g:Dictionary,spec:Dictionary,folder:String)->Mesh:
 if spec.has("reuse_asset"):return reused_volume(spec)
 var shape:Dictionary=spec.duplicate(true);shape.material="stone"
 var result:Mesh=Art.source_rock(g,shape,texture(serial,folder))
 # The prepared native front is separate from fixed-scale hidden stone grain.
 for surface in result.get_surface_count():
  if surface>0:result.surface_set_material(surface,back_material(spec))
 return result

static func reused_volume(spec:Dictionary)->Mesh:
 # Reuse compatible complete boulders before constructing another source-profile shell.
 var parts:Array=Meadow.source(spec.reuse_asset);var original=AABB();var first=true
 for part in parts:
  var box:AABB=part.transform*part.mesh.get_aabb()
  original=box if first else original.merge(box);first=false
 var low=Vector3(INF,INF,INF);var high=Vector3(-INF,-INF,-INF)
 for p in spec.profile.vertices+[spec.profile.crown]:
  var point=Vector3(p[0],p[1],p[2]);low=low.min(point);high=high.max(point)
 var scale_=(high-low)/original.size;var pose=Transform3D(Basis.IDENTITY.scaled(scale_),low-original.position*scale_);var pieces=[]
 for part in parts:pieces.append(Art.transformed_existing(part.mesh,pose*part.transform,back_material(spec)))
 var result=Art.combine(pieces);result.set_meta("east_reused_whole_asset",spec.reuse_asset)
 return result

static func source_cap(serial:int,g:Dictionary,spec:Dictionary,folder:String)->Mesh:
 var pieces=[];var box:Array=spec.visible_box
 var native_height=maxf(.15,-(float(g.origin[1])+(float(box[1])+float(box[3]))*.5)*.045)
 if spec.has("inferred_support_graphic"):
  var support_id=int(spec.inferred_support_graphic);var support:Dictionary=data(folder).graphics[str(support_id)]
  var support_mesh=mesh(support_id,{},folder);var source_arrays:Array=support_mesh.get_meta("east_cpu_arrays")
  var scale_=Vector3(float(g.footprint[0])/float(support.source_graphic.footprint[0]),native_height/float(support.profile.height),float(g.footprint[1])/float(support.source_graphic.footprint[1]))
  var closed=ArrayMesh.new();var retained=[]
  # Reuse only the closed support body; its front photograph belongs to its own tile.
  for surface in range(1,source_arrays.size()):
   var arrays_:Array=source_arrays[surface].duplicate(true);var vertices:PackedVector3Array=arrays_[Mesh.ARRAY_VERTEX];var normals:PackedVector3Array=arrays_[Mesh.ARRAY_NORMAL]
   for i in vertices.size():vertices[i]*=scale_;normals[i]=(normals[i]/scale_).normalized()
   arrays_[Mesh.ARRAY_VERTEX]=vertices;arrays_[Mesh.ARRAY_NORMAL]=normals
   closed.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays_);closed.surface_set_material(closed.get_surface_count()-1,back_material(spec));retained.append(arrays_)
  closed.set_meta("east_cpu_arrays",retained);pieces.append(closed)
 texture(serial,folder)
 var image:Image=images[[folder,serial]].get_region(Rect2i(box[0],box[1],box[2]-box[0],box[3]-box[1]))
 var paint=ImageTexture.create_from_image(image);var row:Dictionary=g.duplicate(true)
 row.rect=[0,0,image.get_width(),image.get_height()];row.origin=[g.origin[0]+box[0],g.origin[1]+box[1]];row.cut=[serial];row.depth=.12
 # A source cap remains at its original elevated ground plane; black void never becomes its silhouette.
 var cap:Mesh=Relief.relief_shape(row,paint,paint,spec.get("cap_outline",[]),Vector2(0,native_height/.045),1.)
 pieces.append(cap)
 var result=Art.combine(pieces);result.set_meta("east_inferred_cave_support",spec.get("inferred_support_graphic",0));result.set_meta("east_native_cap_height",native_height)
 return result

static func pixel(point:Vector3,g:Dictionary,height:float)->Vector2:
 return Vector2((point.x+point.z)*32./3.-g.origin[0],(point.z-point.x)*8.-point.y/height-g.origin[1])

static func tablet_point(source:Vector2,g:Dictionary,height:float,depth:float)->Vector3:
 var across=(source.x+g.origin[0])*3./32.
 return Vector3((across-depth)*.5,(depth*8.-g.origin[1]-source.y)*height,(across+depth)*.5)

static func projected_front_depth(point:Vector2,triangles:Array,g:Dictionary,height:float)->float:
 var nearest=-INF
 for triangle:Array in triangles:
  var a=pixel(triangle[0],g,height);var b=pixel(triangle[1],g,height);var c=pixel(triangle[2],g,height)
  var divisor=(b-a).cross(c-a)
  if absf(divisor)<.00001:continue
  var wb=(point-a).cross(c-a)/divisor;var wc=(b-a).cross(point-a)/divisor;var wa=1.-wb-wc
  if minf(wa,minf(wb,wc))<-.0001:continue
  var at:Vector3=triangle[0]*wa+triangle[1]*wb+triangle[2]*wc
  nearest=maxf(nearest,at.z-at.x)
 return nearest

static func sealed_tablet(serial:int,g:Dictionary,spec:Dictionary,folder:String)->Mesh:
 var reused:Mesh=Crags.mesh(int(spec.body_reuse_candidate));var source_arrays:Array=reused.get_meta("east_cpu_arrays")
 var family:Dictionary=Crags.StoneRelief.data().graphics[str(int(spec.body_reuse_candidate))];var height=float(family.pixel_height)
 var center=Vector3((g.footprint[0]-1)*1.5,0,-(g.footprint[1]-1)*1.5);var triangles=[];var local=[]
 for source:Array in source_arrays:
  var arrays_:Array=source.duplicate(true);var vertices:PackedVector3Array=arrays_[Mesh.ARRAY_VERTEX];var ids:PackedInt32Array=arrays_[Mesh.ARRAY_INDEX]
  for i in vertices.size():vertices[i]+=center
  arrays_[Mesh.ARRAY_VERTEX]=vertices;local.append(arrays_)
  for triangle in ids.size()/3:triangles.append([vertices[ids[triangle*3]],vertices[ids[triangle*3+1]],vertices[ids[triangle*3+2]]])
 var depths=[]
 for probe in [Vector2(80,270),Vector2(60,300),Vector2(82,320)]:
  var depth=projected_front_depth(probe,triangles,g,height)
  if is_finite(depth):depths.append(depth)
 assert(not depths.is_empty(),"The original sealed tablet must meet its reused native crag")
 depths.sort();var plane=float(depths[depths.size()/2]);var outline=PackedVector2Array()
 for p in spec.sealed_door_outline:outline.append(Vector2(p[0],p[1]))
 var body=ArrayMesh.new();var retained=[];var native_material:ShaderMaterial=Paint.material(texture(serial,folder)).duplicate()
 native_material.shader=load(Crags.StoneRelief.ROOT+"front.gdshader");native_material.set_shader_parameter("original_palette",false)
 var volume_material:ShaderMaterial
 if String(family.get("format",""))=="ECR4":
  volume_material=reused.surface_get_material(0).duplicate();volume_material.set_shader_parameter("native_paint",texture(serial,folder))
 for surface in local.size():
  var arrays_:Array=local[surface];var vertices:PackedVector3Array=arrays_[Mesh.ARRAY_VERTEX]
  for i in vertices.size():
   var uv=pixel(vertices[i],g,height);var depth=vertices[i].z-vertices[i].x
   if depth>plane-.06 and Geometry2D.is_point_in_polygon(uv,outline):vertices[i]+=Vector3(-1,16.*height,1)*((plane-.06-depth)*.5)
  arrays_[Mesh.ARRAY_VERTEX]=vertices;retained.append(arrays_);body.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays_)
  body.surface_set_material(surface,volume_material if volume_material!=null else native_material if surface==1 else reused.surface_get_material(surface))
 body.set_meta("east_cpu_arrays",retained)
 var indices=Geometry2D.triangulate_polygon(outline);var face=SurfaceTool.new();face.begin(Mesh.PRIMITIVE_TRIANGLES)
 var rim=SurfaceTool.new();rim.begin(Mesh.PRIMITIVE_TRIANGLES);var front=[];var back=[];var normal=Vector3(-1,0,1).normalized()
 for p in outline:front.append(tablet_point(p,g,height,plane+.02));back.append(tablet_point(p,g,height,plane-.24))
 for index in indices:
  face.set_normal(normal);face.set_uv(outline[index]/Vector2(g.rect[2],g.rect[3]));face.add_vertex(front[index])
 for i in outline.size():
  var next=(i+1)%outline.size();var a:Vector3=front[i];var b:Vector3=front[next];var c:Vector3=back[next];var d:Vector3=back[i];var n=(c-a).cross(b-a).normalized()
  for p in [a,b,c,a,c,d]:rim.set_normal(n);rim.add_vertex(p)
 var panel=ArrayMesh.new();var panel_arrays=face.commit_to_arrays();panel.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,panel_arrays);panel.surface_set_material(0,native_material)
 var rim_arrays=rim.commit_to_arrays();panel.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,rim_arrays);var edge_spec:Dictionary=spec.duplicate();edge_spec.inferred_back_rgb=spec.tablet_edge_rgb;panel.surface_set_material(1,back_material(edge_spec));panel.set_meta("east_cpu_arrays",[panel_arrays,rim_arrays])
 var result=Art.combine([body,panel]);result.set_meta("east_sealed_source_tablet",true);result.set_meta("east_reused_crag",int(spec.body_reuse_candidate));result.set_meta("east_tablet_depth",.26)
 result.set_meta("east_source_gate","32286(74,21),actor1102513: original Encount victory only ->32287; no opening or free route added")
 return result

static func mesh(serial:int,graphic:Dictionary={},folder:String=ROOT)->Mesh:
 var key=[folder,serial]
 if meshes.has(key):return meshes[key]
 var spec:Dictionary=data(folder).graphics[str(serial)];var g:Dictionary=spec.source_graphic.duplicate(true) if graphic.is_empty() else graphic.duplicate(true)
 var result:Mesh
 match String(spec.kind):
  "source_rock_volume","painted_modular_cave_wall","lava_face_patch":result=source_volume(serial,g,spec,folder)
  "sparse_cave_cap_or_edge":result=source_cap(serial,g,spec,folder)
  "sealed_carved_door_crag":result=sealed_tablet(serial,g,spec,folder)
 assert(result!=null,"Unaccounted source stone family")
 result.set_meta("east_source_stone",serial);result.set_meta("east_source_kind",spec.kind);result.set_meta("east_source_footprint",g.footprint);result.set_meta("east_visual_inference",true)
 meshes[key]=result
 return result
