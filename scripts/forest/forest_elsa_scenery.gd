extends RefCounted
## Source paint on shared tree forms and fitted landmark geometry.
const Source=preload("res://scripts/forest/forest_coastal_mesh.gd")
const Meadow=preload("res://scripts/forest/forest_wind_meadow_assets.gd")
const Fit=preload("res://scripts/forest/forest_falan_proportions.gd")
const TrialEntrance=preload("res://scripts/forest/forest_elsa_trial_entrance.gd")
const ROOT="res://assets/maps/falan/elsa/scenery/"
const PIXEL_HEIGHT=.045
const TOWER_MASTERS=[300780,300781,300782,300783,300784,300785,300787]
const SKY_DEPTH=-120.
static var catalog:Dictionary={}
static var meshes:Dictionary={}
static var effects:Dictionary={}
static var profiles:Dictionary={}
static var tree_materials:Dictionary={}
static var props:Dictionary={}
static var prop_textures:Dictionary={}
static var terrain:Dictionary={}
static var source_surfaces:Dictionary={}
static var stone_frames:SpriteFrames
static var stone_data:Dictionary={}

static func return_stone()->AnimatedSprite3D:
 if stone_frames==null:
  stone_data=JSON.parse_string(FileAccess.get_file_as_string(ROOT+"return-stone/data.json"))
  var atlas:Texture2D=load(ROOT+"return-stone/atlas.png")
  stone_frames=SpriteFrames.new();stone_frames.clear(&"default")
  stone_frames.set_animation_speed(&"default",1000.*stone_data.frames/stone_data.duration)
  for i in int(stone_data.frames):
   var frame=AtlasTexture.new();frame.atlas=atlas;frame.filter_clip=true
   frame.region=Rect2(i*stone_data.size[0],0,stone_data.size[0],stone_data.size[1]);stone_frames.add_frame(&"default",frame)
 var sprite=AnimatedSprite3D.new();sprite.name="OriginalElsaReturnStone";sprite.sprite_frames=stone_frames
 sprite.pixel_size=.043;sprite.billboard=BaseMaterial3D.BILLBOARD_ENABLED;sprite.texture_filter=BaseMaterial3D.TEXTURE_FILTER_NEAREST
 sprite.alpha_cut=SpriteBase3D.ALPHA_CUT_DISCARD;sprite.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;sprite.visibility_range_end=85.
 sprite.offset=Vector2(stone_data.origin[0]+stone_data.size[0]*.5,-stone_data.origin[1]-stone_data.size[1]*.5)
 sprite.play();return sprite

static func data()->Dictionary:
 if catalog.is_empty():catalog=JSON.parse_string(FileAccess.get_file_as_string(ROOT+"data.json"))
 return catalog

static func central_steps_mesh(row:Dictionary,paints:Dictionary)->Mesh:
 var key="central-steps:"+str(row.geometry_sha256)+":"+str(row.paint_sha256)
 if meshes.has(key):return meshes[key]
 var skins={}
 var used={}
 for face in row.surfaces:used[face.paint]=true
 for name in used:
  var texture:Texture2D=paints[name]
  var origin=Vector2(row.native_origin[0],row.native_origin[1]) if name in ["native","floor"] else Vector2.ZERO
  skins[name]=Source.new([Rect2(Vector2.ZERO,texture.get_size()),-origin,Vector2.ONE,0],texture,1./Fit.VERTICAL)
 for face in row.surfaces:
  var points:PackedVector3Array=[];var polygon=PackedVector2Array()
  for p in face.points:points.append(Vector3(p[0],p[1],p[2]));polygon.append(Vector2(p[0],p[2]))
  var indices=PackedInt32Array([0,1,2]) if points.size()==3 else PackedInt32Array([0,1,2,0,2,3]) if points.size()==4 else Geometry2D.triangulate_polygon(polygon)
  assert(not indices.is_empty(),"Source floor polygon must triangulate: "+face.role)
  var normal=(points[indices[2]]-points[indices[0]]).cross(points[indices[1]]-points[indices[0]])
  if normal.length_squared()<.00000001:continue
  normal=normal.normalized()
  var origin=Vector2(row.native_origin[0],row.native_origin[1]) if face.paint in ["native","floor"] else Vector2.ZERO
  for i in indices:
   var uv=Vector2(face.uv[i][0],face.uv[i][1])+origin
   var sample=Vector3(uv.x*3./64.-uv.y/16.,0.,uv.x*3./64.+uv.y/16.)
   skins[face.paint].projected_vertex(points[i],normal,sample)
 var mesh=ArrayMesh.new();var retained=[];var names=[]
 for name in skins:
  var piece:Mesh=skins[name].finish(true);var arrays:Array=piece.get_meta("source_surface_arrays")
  mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays);mesh.surface_set_material(mesh.get_surface_count()-1,piece.surface_get_material(0))
  retained.append(arrays);names.append(name)
 mesh.set_meta("source_all_surface_arrays",retained);mesh.set_meta("source_paint_names",names)
 meshes[key]=mesh;return mesh

static func tower_piece(id:int,g:Dictionary)->bool:
 return id==59520 and g.has("cut") and int(g.cut[0]) in TOWER_MASTERS

static func pixel_point(pixel:Vector2)->Vector3:
 return Vector3(pixel.x*3./64.,-pixel.y*PIXEL_HEIGHT,pixel.x*3./64.)

static func relief_point(pixel:Vector2,foot:Vector2,vertical:float=0.)->Vector3:
 var ground=pixel.x*foot.x+foot.y+pixel.y*vertical
 return Vector3(pixel.x*3./64.-ground/16.,(ground-pixel.y)*PIXEL_HEIGHT,pixel.x*3./64.+ground/16.)

static func sky_point(pixel:Vector2)->Vector3:
 var shift=SKY_DEPTH*Fit.VERTICAL/16.
 return Vector3(pixel.x*3./64.-pixel.y/16.-shift,SKY_DEPTH,pixel.x*3./64.+pixel.y/16.+shift)

static func sky_material(texture:Texture2D)->Material:
 var key="sky:"+texture.resource_path
 if not effects.has(key):
  var material=ShaderMaterial.new();material.shader=preload("res://scripts/forest/forest_elsa_scenery.gdshader")
  material.set_shader_parameter("atlas",texture);effects[key]=material
 return effects[key]

static func shore_floor(tool:SurfaceTool,at:Vector3,g:Dictionary,atlas_size:Vector2,index:int)->bool:
 var sea:Dictionary=data().get("shore",{})
 if not sea.get("placements",{}).has(str(index)):return false
 var profile:Dictionary=sea.profiles[sea.placements[str(index)]]
 for row in profile.quads:
  var pixels=[Vector2(row[0],row[1]),Vector2(row[0]+row[2],row[1]),Vector2(row[0]+row[2],row[1]+row[3]),Vector2(row[0],row[1]+row[3])]
  var points=[]
  for i in 4:
   var native:Vector2=pixels[i]+Vector2(g.origin[0],g.origin[1])
   points.append(at+Vector3(native.x*3./64.-native.y/16.,lerpf(.012,float(sea.depth),row[4+i]),native.x*3./64.+native.y/16.))
  var normal:Vector3=(points[2]-points[0]).cross(points[1]-points[0]).normalized()
  for i in [0,1,2,0,2,3]:
   tool.set_normal(normal);tool.set_uv((Vector2(g.rect[0],g.rect[1])+pixels[i].clamp(Vector2.ONE*.5,Vector2(g.rect[2],g.rect[3])-Vector2.ONE*.5))/atlas_size)
   tool.add_vertex(points[i])
 return true

static func terrain_floor(tool:SurfaceTool,id:int,at:Vector3,g:Dictionary,atlas_size:Vector2,index:int,map_origin:Vector2)->bool:
 if not terrain.has(id):
  var path=ROOT+"terrain/%d.json"%id
  var record:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(path)) if FileAccess.file_exists(path) else {}
  var key:String=record.get("template",str(id))
  if record.has("template"):
   if not terrain.has(key):terrain[key]=JSON.parse_string(FileAccess.get_file_as_string(ROOT+"terrain/"+key))
   terrain[id]=terrain[key]
  else:terrain[id]=record
 var shapes:Dictionary=terrain[id]
 if not shapes.get("placements",{}).has(str(index)):return false
 var fit_entrance=TrialEntrance.owns(id);var map_offset=Vector3(map_origin.x,0,map_origin.y)
 for row in shapes.profiles[shapes.placements[str(index)]].quads:
  var pixels=[Vector2(row[0],row[1]),Vector2(row[0]+row[2],row[1]),Vector2(row[0]+row[2],row[1]+row[3]),Vector2(row[0],row[1]+row[3])]
  var points=[]
  for i in 4:
   var p:Vector2=pixels[i]+Vector2(g.origin[0],g.origin[1]);var drop=float(row[4+i])
   var point=at+Vector3(p.x*3./64.-p.y/16.-drop/16.,.012+drop/Fit.VERTICAL,p.x*3./64.+p.y/16.+drop/16.)
   if fit_entrance:point=TrialEntrance.fitted(point-map_offset,Vector2.ZERO)+map_offset
   points.append(point)
  var normal:Vector3=(points[2]-points[0]).cross(points[1]-points[0]).normalized()
  for i in [0,1,2,0,2,3]:
   tool.set_normal(normal);tool.set_uv((Vector2(g.rect[0],g.rect[1])+pixels[i].clamp(Vector2.ONE*.5,Vector2(g.rect[2],g.rect[3])-Vector2.ONE*.5))/atlas_size);tool.add_vertex(points[i])
 return true

static func fitted_model(asset:String,g:Dictionary,visible:Rect2)->Mesh:
 var parts:Array=Meadow.source(asset);var bounds=AABB();var first=true
 for part in parts:
  var box:AABB=part.transform*part.mesh.get_aabb()
  bounds=box if first else bounds.merge(box);first=false
 var height=maxf(1.,(visible.size.y-visible.size.x*.24)*PIXEL_HEIGHT)
 var width=maxf(.6,visible.size.x*.050)
 var fit=Vector3(width/maxf(.01,bounds.size.x),height/maxf(.01,bounds.size.y),width/maxf(.01,bounds.size.z))
 var center=bounds.get_center();center.y=bounds.position.y
 var foot=Vector2(g.origin[0],g.origin[1])+Vector2(visible.get_center().x,visible.end.y-8.)
 var at=Vector3(foot.x*3./64.-foot.y/16.,0,foot.x*3./64.+foot.y/16.)
 var pose=Transform3D(Basis.IDENTITY.scaled(fit),at-center*fit)
 var result=ArrayMesh.new()
 for part in parts:
  var transform_:Transform3D=pose*part.transform
  for slot in part.mesh.get_surface_count():
   var tool=SurfaceTool.new();tool.begin(Mesh.PRIMITIVE_TRIANGLES);tool.append_from(part.mesh,slot,transform_)
   var mesh:Mesh=tool.commit();var index=result.get_surface_count()
   result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,mesh.surface_get_arrays(0))
   var material:Material=part.material if part.material!=null else part.mesh.surface_get_material(slot)
   if part.name=="Canopy" and material is StandardMaterial3D and material.albedo_texture!=null:
    var yellow=int(g.cut[0]) in [300799,300801];var key=[asset,yellow]
    if not tree_materials.has(key):
     var paint=ShaderMaterial.new();paint.shader=Meadow.WIND
     paint.set_shader_parameter("tree",true);paint.set_shader_parameter("canopy",true);paint.set_shader_parameter("strength",.025)
     paint.set_shader_parameter("use_source_paint",true);paint.set_shader_parameter("source_paint",material.albedo_texture)
     paint.set_shader_parameter("foliage_tint",Vector3(1.8,1.1,.6) if yellow else Vector3.ONE)
     tree_materials[key]=paint
    material=tree_materials[key]
   result.surface_set_material(index,material)
 var target=Rect2(Vector2(g.origin[0],g.origin[1])+visible.position,visible.size)
 return Fit.transformed(result,Fit.measure(Fit.mesh_points(result),"",Basis(Vector3.UP,PI*.5),target))

static func fitted_rock(g:Dictionary,texture:Texture2D,shape:Dictionary)->Mesh:
 var tool=SurfaceTool.new();tool.begin(Mesh.PRIMITIVE_TRIANGLES)
 for box in shape.parts:tool.append_from(rock_part(g,texture,shape.model,box,shape.get("below",false)),0,Transform3D.IDENTITY)
 var result=tool.commit();result.surface_set_material(0,Source.material(texture));return result

static func small_props(g:Dictionary,textures:Array,row:Dictionary)->Mesh:
 var front_texture:Texture2D=load(row.floor_paint.path) if row.has("floor_paint") else textures[0]
 var fronts=SurfaceTool.new();fronts.begin(Mesh.PRIMITIVE_TRIANGLES)
 var edges=SurfaceTool.new();edges.begin(Mesh.PRIMITIVE_TRIANGLES)
 var solids=SurfaceTool.new();solids.begin(Mesh.PRIMITIVE_TRIANGLES)
 for shape in row.get("columns",[]):solids.append_from(column(g,textures[1],shape),0,Transform3D.IDENTITY)
 for shape in row.get("grounded",[])+row.get("wall_parts",[]):
  var box:Array=shape.box;var part={"rect":[g.rect[0]+box[0],g.rect[1]+box[1],box[2]-box[0],box[3]-box[1]],"origin":[g.origin[0]+box[0],g.origin[1]+box[1]],"cut":g.cut}
  if shape.has("depth"):part.depth=shape.depth
  if shape.flat:
   var points=[];var size_=Vector2(part.rect[2],part.rect[3]);var origin=Vector2(part.origin[0],part.origin[1])
   var corners=[Vector2.ZERO,Vector2(size_.x,0),size_,Vector2(0,size_.y)]
   for pixel in corners:
    var p:Vector2=origin+pixel;points.append(Vector3(p.x*3./64.-p.y/16.,.04,p.x*3./64.+p.y/16.))
   for i in [0,1,2,0,2,3]:
    var tile=Vector2(part.rect[0],part.rect[1])-(Vector2(g.rect[0],g.rect[1]) if row.has("floor_paint") else Vector2.ZERO)
    fronts.set_normal(Vector3.UP);fronts.set_uv((tile+corners[i])/front_texture.get_size());fronts.add_vertex(points[i])
  else:
   var mesh=relief_shape(part,textures[0],textures[1],shape.edges,Vector2(shape.foot[0],shape.foot[1]))
   fronts.append_from(mesh,0,Transform3D.IDENTITY);edges.append_from(mesh,1,Transform3D.IDENTITY)
 var result:ArrayMesh=ArrayMesh.new()
 for surface in [[fronts,front_texture],[solids,textures[1]],[edges,textures[1]]]:
  var piece:Mesh=surface[0].commit()
  if piece!=null and piece.get_surface_count()>0:
   var index=result.get_surface_count();result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,piece.surface_get_arrays(0));result.surface_set_material(index,Source.material(surface[1]))
 return result

static func source_surface_spec(path:String,id:int)->Dictionary:
 if not source_surfaces.has(path):source_surfaces[path]=JSON.parse_string(FileAccess.get_file_as_string(path))
 var spec:Dictionary=source_surfaces[path]
 if not spec.has("variants"):return spec
 assert(spec.map_templates.has(str(id)),"Prepared FG surface needs this map's original BG fit")
 var variant:Dictionary=spec.variants[spec.map_templates[str(id)]]
 if spec.has("entrance"):
  variant=variant.duplicate();variant.entrance=spec.entrance
 return variant

static func source_surface(g:Dictionary,texture:Texture2D,spec:Dictionary)->Mesh:
 # Match the original BG depth before applying its reviewed entrance front fit.
 var tool=SurfaceTool.new();tool.begin(Mesh.PRIMITIVE_TRIANGLES)
 var origin=Vector2(g.origin[0],g.origin[1]);var tile=Vector2(g.rect[0],g.rect[1])
 for row in spec.quads:
  var pixels=[Vector2(row[0],row[1]),Vector2(row[0]+row[2],row[1]),Vector2(row[0]+row[2],row[1]+row[3]),Vector2(row[0],row[1]+row[3])]
  var points=[]
  for i in 4:
   var p:Vector2=origin+pixels[i];var drop=float(row[4+i])
   var point=Vector3(p.x*3./64.-p.y/16.-drop/16.,.012+drop/Fit.VERTICAL,p.x*3./64.+p.y/16.+drop/16.)
   if spec.has("entrance"):point=TrialEntrance.fitted(point,Vector2(TrialEntrance.data().anchor[0],TrialEntrance.data().anchor[1]))
   points.append(point)
  var normal:Vector3=(points[2]-points[0]).cross(points[1]-points[0]).normalized()
  for i in [0,1,2,0,2,3]:
   tool.set_normal(normal);tool.set_uv((tile+pixels[i])/texture.get_size());tool.add_vertex(points[i]+normal*.03)
 var result:Mesh=tool.commit();result.surface_set_material(0,Source.material(texture));return result

static func rock_part(g:Dictionary,texture:Texture2D,model:String,box:Array,below:bool)->Mesh:
 var parts:Array=Meadow.source(model);var points:Array[Vector3]=[]
 var orientation=Transform3D(Basis(Vector3(1,0,1).normalized(),PI) if below else Basis.IDENTITY,Vector3.ZERO)
 for part in parts:
  points.append_array(Fit.mesh_points(part.mesh,orientation*part.transform))
 var base_y=-INF if below else INF
 for point in points:base_y=maxf(base_y,point.y) if below else minf(base_y,point.y)
 orientation.origin.y-=base_y
 for i in points.size():points[i].y-=base_y
 var width=float(box[2]-box[0]);var height=float(box[3]-box[1])
 var turn=Basis(Vector3.UP,PI*.5);var depth=1.;var ground:Array[Vector3]=[]
 for point in points:ground.append(Vector3(point.x,0,point.z))
 var bounds=Fit.projected_bounds(ground,Transform3D(turn,Vector3.ZERO))
 while bounds.size.y*width/bounds.size.x>=height*.85:
  depth*=.85;ground.clear()
  for point in points:
   var across=(point.x+point.z)*.5;var deep=(point.z-point.x)*.5*depth
   ground.append(Vector3(across-deep,0,across+deep))
  bounds=Fit.projected_bounds(ground,Transform3D(turn,Vector3.ZERO))
 var flatten=Basis(Vector3((1.+depth)*.5,0,(1.-depth)*.5),Vector3.UP,Vector3((1.-depth)*.5,0,(1.+depth)*.5))
 for i in points.size():points[i]=flatten*points[i]
 var target=Rect2(g.origin[0]+box[0],g.origin[1]+box[1],width,height)
 var fit=Fit.measure(points,"",turn,target);var pose=fit*Transform3D(flatten,Vector3.ZERO)*orientation
 var at=pose.origin
 var measured=Fit.projected_bounds(points,Transform3D(turn,Vector3.ZERO)*fit)
 assert(measured.position.distance_to(target.position)<.05 and measured.size.distance_to(target.size)<.05,"Rock fit must preserve its native source bounds")
 var skin=Source.new([Rect2(g.rect[0]+box[0],g.rect[1]+box[1],width,height),-Vector2(g.origin[0]+box[0],g.origin[1]+box[1]),Vector2.ONE,0],texture,1./Fit.VERTICAL)
 skin.projection_center=at
 for part in parts:
  var transform_:Transform3D=pose*part.transform;var normals=transform_.basis.inverse().transposed()
  for slot in part.mesh.get_surface_count():
   var arrays:Array=part.mesh.surface_get_arrays(slot);var vertices:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX];var indices:PackedInt32Array=arrays[Mesh.ARRAY_INDEX]
   for i in (indices.size() if not indices.is_empty() else vertices.size()):
    var index:int=indices[i] if not indices.is_empty() else i
    var point:Vector3=transform_*vertices[index];var local=point-at
    var across=(local.x+local.z)*.70710678;var sample_depth=absf(local.z-local.x)*.70710678
    var sample=at+Vector3((across-sample_depth)*.70710678,local.y,(across+sample_depth)*.70710678)
    skin.projected_vertex(point,(normals*arrays[Mesh.ARRAY_NORMAL][index]).normalized(),sample)
 return skin.finish()

static func effect(g:Dictionary)->Mesh:
 var serial=str(int(g.cut[0]));var clip:Dictionary=data().animations[serial]
 if not effects.has(serial):
  var material=ShaderMaterial.new()
  # Native bit8 is LIGHT_THROUGH: black effect paint must not occlude scenery.
  material.shader=preload("res://scripts/forest/forest_elsa_light_through.gdshader") if int(clip.get("flags",0))&8 else preload("res://scripts/forest/forest_elsa_scenery.gdshader")
  material.set_shader_parameter("atlas",load(ROOT+serial+".png"))
  material.set_shader_parameter("grid",Vector2(clip.columns,clip.rows))
  material.set_shader_parameter("frames",float(clip.frames))
  material.set_shader_parameter("duration",float(clip.duration)/1000.)
  material.set_shader_parameter("opacity",float(clip.opacity)/255.)
  effects[serial]=material
 var origin=Vector2(clip.origin[0]+g.cut[6],clip.origin[1]+g.cut[7]);var size_=Vector2(clip.size[0],clip.size[1])
 var tool=SurfaceTool.new();tool.begin(Mesh.PRIMITIVE_TRIANGLES)
 var corners=[origin,origin+Vector2(size_.x,0),origin+size_,origin+Vector2(0,size_.y)]
 var uv=[Vector2.ZERO,Vector2.RIGHT,Vector2.ONE,Vector2.DOWN]
 for i in [0,1,2,0,2,3]:
  tool.set_uv(uv[i]);tool.set_normal(Vector3(-1,0,1).normalized());tool.add_vertex(pixel_point(corners[i]))
 var mesh=tool.commit();mesh.surface_set_material(0,effects[serial]);return mesh

static func mesh(serial:int,g:Dictionary,texture:Texture2D)->Mesh:
 if meshes.has(serial):return meshes[serial]
 if g.animated:meshes[serial]=Fit.transformed(effect(g),Fit.native_coastal_frame());return meshes[serial]
 meshes[serial]=Fit.transformed(relief(serial,g,texture),Fit.native_coastal_frame())
 return meshes[serial]

static func relief(serial:int,g:Dictionary,texture:Texture2D)->Mesh:
 if profiles.is_empty():profiles=JSON.parse_string(FileAccess.get_file_as_string(ROOT+"profiles.json"))
 var art=load("res://scripts/forest/forest_original_map_art.gd")
 return relief_shape(g,texture,art.solid_texture(int(g.page)),profiles.get(str(serial),[]))

static func relief_shape(g:Dictionary,texture:Texture2D,solid:Texture2D,outline:Array,foot:Vector2=Vector2.ZERO,vertical:float=0.)->Mesh:
 var rect=Rect2(g.rect[0],g.rect[1],g.rect[2],g.rect[3])
 var origin=Vector2(g.origin[0],g.origin[1]);var size_=rect.size
 var points=[relief_point(origin,foot,vertical),relief_point(origin+Vector2(size_.x,0),foot,vertical),relief_point(origin+size_,foot,vertical),relief_point(origin+Vector2(0,size_.y),foot,vertical)]
 var master=int(g.cut[0]);var depth=.12 if master in range(300793,300806) else 1.2 if master in range(300806,300816) else clampf(size_.x*.005,.2,2.)
 if master in [300066,300774,300777,300778,300779,300786]:depth=.08
 if master==300790:depth=.20
 depth=float(g.get("depth",depth))
 var direction=Vector3(3./64.-foot.x/16.,foot.x*PIXEL_HEIGHT,3./64.+foot.x/16.)
 var normal=Vector3(-vertical/16.,(vertical-1.)*PIXEL_HEIGHT,vertical/16.).cross(direction).normalized();var offset=normal*depth
 if g.get("source_depth",false):offset=Vector3(-1./16.,PIXEL_HEIGHT,1./16.)/Vector3(-1./16.,1./Fit.VERTICAL,1./16.).length()*depth
 var tool=SurfaceTool.new();tool.begin(Mesh.PRIMITIVE_TRIANGLES)
 var uv=[Vector2.ZERO,Vector2.RIGHT,Vector2.ONE,Vector2.DOWN]
 for side in [-1,1]:
  for i in ([0,1,2,0,2,3] if side==1 else [3,2,0,2,1,0]):
   tool.set_normal(normal*side);tool.set_uv((rect.position+uv[i]*size_)/texture.get_size());tool.add_vertex(points[i] if side==1 else points[i]-offset)
 var result:ArrayMesh=tool.commit();result.surface_set_material(0,Source.material(texture))
 var edges=Source.new([rect,-origin,Vector2.ONE,0],solid,PIXEL_HEIGHT)
 for edge in outline:
  var a=relief_point(origin+Vector2(edge[0],edge[1]),foot,vertical);var b=relief_point(origin+Vector2(edge[2],edge[3]),foot,vertical)
  var sample=relief_point(origin+Vector2(edge[4],edge[5]),foot,vertical);var vertices=[a,b,b-offset,a-offset]
  var face_normal:Vector3=(vertices[1]-vertices[0]).cross(vertices[2]-vertices[0]).normalized()
  for i in [0,3,2,0,2,1]:edges.projected_vertex(vertices[i],face_normal,sample)
 var sides:Mesh=edges.finish()
 result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,sides.surface_get_arrays(0));result.surface_set_material(1,sides.surface_get_material(0))
 result.set_meta("source_relief",true);result.set_meta("inferred_depth",depth)
 return result

static func tower_shell_point(pixel:Vector2,fit:Dictionary)->Vector3:
 var shell:Dictionary=fit.shell;var row=pixel.y/float(shell.step)
 var a:int=clampi(int(row),0,shell.sections.size()-1);var b=mini(a+1,shell.sections.size()-1)
 var center=lerpf(shell.sections[a][0],shell.sections[b][0],fposmod(row,1.))
 var radius=lerpf(shell.sections[a][1],shell.sections[b][1],fposmod(row,1.))
 var local=pixel-(Vector2(fit.anchor[0],fit.anchor[1])-Vector2(fit.rect[0],fit.rect[1]))
 var depth=sqrt(maxf(0.,radius*radius-pow(local.x-center,2)))*shell.depth_ratio
 return relief_point(local,Vector2(0,depth))

static func tower_shell(fit:Dictionary,texture:Texture2D)->Mesh:
 var tool=SurfaceTool.new();tool.begin(Mesh.PRIMITIVE_TRIANGLES)
 for row in fit.shell.quads:
  var pixels=[Vector2(row[0],row[1]),Vector2(row[0]+row[2],row[1]),Vector2(row[0]+row[2],row[1]+row[3]),Vector2(row[0],row[1]+row[3])]
  var front:Array[Vector3]=[];var back:Array[Vector3]=[]
  for pixel in pixels:
   var p=tower_shell_point(pixel,fit);front.append(p);back.append(Vector3(p.z,p.y,p.x))
  for side in [0,1]:
   var points:Array[Vector3]=front if side==0 else back
   var normal=(points[2]-points[0]).cross(points[1]-points[0]).normalized()
   for i in ([0,1,2,0,2,3] if side==0 else [3,2,0,2,1,0]):
    tool.set_normal(normal if side==0 else -normal);tool.set_uv(pixels[i]/texture.get_size());tool.add_vertex(points[i])
 # Front and rear meet at zero depth along the outer silhouette. Alpha holes
 # left by foreground supports must not become long walls through the shaft.
 var mesh:Mesh=tool.commit();mesh.surface_set_material(0,Source.material(texture));return mesh

static func tower_terraces(fit:Dictionary)->Mesh:
 var result=ArrayMesh.new()
 # Each band samples its own original surface art. Projecting a whole garden
 # photograph around a cylinder puts flower beds on vertical masonry faces.
 var bands=[[17.5,17.5,0.,2.9,"stone-lower"],[17.5,15.5,2.9,2.9,"flowers"],
            [15.5,15.5,2.9,5.8,"stone-upper"],[15.5,12.5,5.8,5.8,"flowers"]]
 for band in bands:
  var tool=SurfaceTool.new();tool.begin(Mesh.PRIMITIVE_TRIANGLES)
  var texture:Texture2D=load(ROOT+"tower-"+band[4]+".png")
  for i in fit.terrace_radial.size():
   var j=(i+1)%fit.terrace_radial.size();var a=Vector3(fit.terrace_radial[i][0],0,fit.terrace_radial[i][1])/18.;var b=Vector3(fit.terrace_radial[j][0],0,fit.terrace_radial[j][1])/18.
   var points=[a*band[0]+Vector3.UP*band[2],b*band[0]+Vector3.UP*band[2],b*band[1]+Vector3.UP*band[3],a*band[1]+Vector3.UP*band[3]]
   var normal=(points[2]-points[0]).cross(points[1]-points[0]).normalized()
   var uv:Array[Vector2]=[]
   for k in 4:
    var p:Vector3=points[k]
    uv.append(Vector2((i+(1 if k in [1,2] else 0))*11./fit.radial.size(),1 if k<2 else 0) if band[4]!="flowers" else Vector2(p.x,p.z)*.25)
   for k in [0,1,2,0,2,3]:tool.set_normal(normal);tool.set_uv(uv[k]);tool.add_vertex(points[k])
  var mesh:Mesh=tool.commit();var index=result.get_surface_count();result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,mesh.surface_get_arrays(0));result.surface_set_material(index,Source.material(texture))
 return result

static func tower_fences(fit:Dictionary)->Mesh:
 var texture:Texture2D=load(ROOT+"tower-fence.png");var tool=SurfaceTool.new();tool.begin(Mesh.PRIMITIVE_TRIANGLES)
 var perimeter=0.
 for i in fit.terrace_radial.size():
  var a=Vector2(fit.terrace_radial[i][0],fit.terrace_radial[i][1]);var b=Vector2(fit.terrace_radial[(i+1)%fit.terrace_radial.size()][0],fit.terrace_radial[(i+1)%fit.terrace_radial.size()][1]);perimeter+=a.distance_to(b)
 for band in [[17.5,2.9],[15.5,5.8]]:
  var length=perimeter*band[0]/18.;var turns=roundf(length*(32./3.*sqrt(2.))/texture.get_width());var height=texture.get_height()*PIXEL_HEIGHT;var covered=0.
  for i in fit.terrace_radial.size():
   var j=(i+1)%fit.terrace_radial.size();var a=Vector3(fit.terrace_radial[i][0],0,fit.terrace_radial[i][1])*band[0]/18.+Vector3.UP*band[1];var b=Vector3(fit.terrace_radial[j][0],0,fit.terrace_radial[j][1])*band[0]/18.+Vector3.UP*band[1]
   var points=[a,b,b+Vector3.UP*height,a+Vector3.UP*height];var normal=(points[2]-points[0]).cross(points[1]-points[0]).normalized()
   var u=covered/length*turns;covered+=a.distance_to(b);var v=covered/length*turns;var uv=[Vector2(u,1),Vector2(v,1),Vector2(v,0),Vector2(u,0)]
   for side in [-1,1]:
    for k in ([0,1,2,0,2,3] if side==1 else [3,2,0,2,1,0]):tool.set_normal(normal*side);tool.set_uv(uv[k]);tool.add_vertex(points[k])
 var mesh:Mesh=tool.commit();mesh.surface_set_material(0,Source.material(texture));return mesh

static func bg_stair(root:Node3D,origin:Vector2):
 if not meshes.has("temple-bg-stair"):
  var folder=ROOT+"temple-bg-stair/";var row=source_surface_spec(folder+"mesh.json",59530);var paints={}
  for name in ["native","body","cap","stone","stone_shadow","charcoal","gold"]:paints[name]=load(folder+("native-paint.png" if name=="native" else name+".png"))
  meshes["temple-bg-stair"]=central_steps_mesh(row,paints)
 var node=MeshInstance3D.new();node.name="ElsaOriginalBGStair";node.mesh=meshes["temple-bg-stair"]
 node.position=Vector3(origin.x,0.,origin.y);node.set_meta("source_layer",0);node.set_meta("source_map",59530)
 node.set_meta("inferred_height_and_hidden_geometry",true);root.add_child(node)

static func build(root:Node3D,id:int,origin:Vector2):
 build_props(root,id,origin)
 var entry_path=ROOT+"entry-pedestals/data.json"
 var steps=preload("res://scripts/forest/forest_elsa_hall_steps.gd")
 if id==59530 and (not steps.owns(id) or steps.data(id).steps.get("external_visual",false)) and FileAccess.file_exists(entry_path):entry_pedestals(root,origin,source_surface_spec(entry_path,id))
 if id==59530 and preload("res://scripts/forest/forest_elsa_hall_steps.gd").owns(id):preload("res://scripts/forest/forest_elsa_hall_steps.gd").build(root,origin,id)
 if id==59530:bg_stair(root,origin)
 if id==59535:inner_hall(root,origin)
 if id!=59520:return
 load("res://scripts/forest/forest_elsa_landmark_floor.gd").build(root,origin)
 load("res://scripts/forest/forest_elsa_gate.gd").build(root,origin)
 var row:Dictionary=data().tower;var native:Vector2=Vector2(row.anchor[0],row.anchor[1])
 var at=Vector3(origin.x+native.x*3./64.-native.y/16.,0,origin.y+native.x*3./64.+native.y/16.)
 if not meshes.has("tower"):
  var result:ArrayMesh=tower_terraces(row);var blue:Mesh=tower_shell(row,load(ROOT+"tower-body.png"))
  for part in [blue,tower_fences(row)]:
   var index=result.get_surface_count();result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,part.surface_get_arrays(0));result.surface_set_material(index,part.surface_get_material(0))
  meshes["tower"]=result
 var node=MeshInstance3D.new();node.name="ElsaSourceTower";node.mesh=meshes["tower"];node.position=at;node.scale.y=Fit.native_coastal_frame().basis.y.y
 node.set_meta("source_pieces",row.source_pieces);node.set_meta("inferred_depth",true);root.add_child(node)
 for i in row.roots.size():
  var key="tower-root-%d"%i;var part:Dictionary=row.roots[i]
  if not meshes.has(key):
   var paint:Texture2D=load(ROOT+"tower-root-%d.png"%i);var solid:Texture2D=load(ROOT+"tower-root-%d-solid.png"%i)
   var g={"rect":[0,0,paint.get_width(),paint.get_height()],"origin":part.origin,"cut":[300780],"depth":.8,"source_depth":true}
   meshes[key]=relief_shape(g,paint,solid,part.edges,Vector2(part.foot[0],part.foot[1]),part.vertical)
  var gold=MeshInstance3D.new();gold.name="ElsaOriginalGoldRoot_%d"%i;gold.mesh=meshes[key];gold.position=at;gold.scale.y=Fit.native_coastal_frame().basis.y.y
  gold.set_meta("source_component",part.rect);root.add_child(gold)
 temple(root,origin)

static func grouped(id:int,g:Dictionary)->bool:
 return id>=59500 and id<59800 and g.has("cut") and not g.ground and not g.animated

static func effect_shift(id:int,index:int)->Vector3:
 if props.is_empty():props=JSON.parse_string(FileAccess.get_file_as_string("res://assets/maps/falan/elsa/props/data.json"))
 var foot=float(props.get("effect_feet",{}).get(str(id),{}).get(str(index),0.))
 return Vector3(-foot/16.,foot/Fit.VERTICAL,foot/16.)

static func bridge_point(pixel:Vector2,origin:Vector2,shape:Dictionary)->Vector3:
 var edge=Vector2(shape.edge[0],shape.edge[1]);var native=pixel+origin
 var ground=minf(native.y+shape.height_pixels,origin.y+(pixel.x-shape.footer)/edge.x)
 return relief_point(native,Vector2(0,ground))

static func bridge(g:Dictionary,texture:Texture2D,shape:Dictionary)->Mesh:
 var tool=SurfaceTool.new();tool.begin(Mesh.PRIMITIVE_TRIANGLES)
 var origin=Vector2(g.origin[0],g.origin[1])
 var inward=Vector3(-shape.depth_pixels*3./64.,0,-shape.depth_pixels*3./64.)
 for row in shape.quads:
  var pixels=[Vector2(row[0],row[1]),Vector2(row[0]+row[2],row[1]),Vector2(row[0]+row[2],row[1]+row[3]),Vector2(row[0],row[1]+row[3])]
  var points:Array[Vector3]=[]
  for pixel in pixels:points.append(bridge_point(pixel,origin,shape))
  var normal=(points[2]-points[0]).cross(points[1]-points[0]).normalized()
  for i in [0,1,2,0,2,3]:
   tool.set_normal(normal);tool.set_uv((Vector2(g.rect[0],g.rect[1])+pixels[i])/texture.get_size());tool.add_vertex(points[i])
  if not shape.has("inner") and points.any(func(point):return point.y<shape.height_pixels*PIXEL_HEIGHT-.001):
   for i in [3,2,0,2,1,0]:
    tool.set_normal(-normal);tool.set_uv((Vector2(g.rect[0],g.rect[1])+pixels[i])/texture.get_size());tool.add_vertex(points[i]+inward)
 for edge in g.edges:
  if shape.has("inner"):continue
  var a=bridge_point(Vector2(edge[0],edge[1]),origin,shape);var b=bridge_point(Vector2(edge[2],edge[3]),origin,shape)
  if a.y>=shape.height_pixels*PIXEL_HEIGHT-.001 and b.y>=shape.height_pixels*PIXEL_HEIGHT-.001:continue
  var points=[a,b,b+inward,a+inward];var normal=(points[2]-points[0]).cross(points[1]-points[0]).normalized()
  var uv=(Vector2(g.rect[0]+edge[4],g.rect[1]+edge[5]))/texture.get_size()
  for i in [0,1,2,0,2,3]:tool.set_normal(normal);tool.set_uv(uv);tool.add_vertex(points[i])
 var result=tool.commit();result.surface_set_material(0,Source.material(texture))
 if shape.has("inner"):
  var inner_texture:Texture2D=load(shape.inner)
  var inner=SurfaceTool.new();inner.begin(Mesh.PRIMITIVE_TRIANGLES)
  var interval:Array=shape.get("interval",[4.,float(g.rect[3])-4.])
  var slope=float(shape.edge[0]);var first=float(shape.edge[1])+slope*float(interval[0]);var last=float(shape.edge[1])+slope*float(interval[1])
  var a=bridge_point(Vector2(first,(first-shape.footer)/slope),origin,shape)+inward
  var b=bridge_point(Vector2(last,(last-shape.footer)/slope),origin,shape)+inward
  var corners=[b,a,a+Vector3.UP*shape.height_pixels*PIXEL_HEIGHT,b+Vector3.UP*shape.height_pixels*PIXEL_HEIGHT]
  var up=Vector3.UP*shape.height_pixels*PIXEL_HEIGHT
  var backing=inward.normalized()*.005
  var outside=[a-inward+backing,b-inward+backing,b-inward+backing+up,a-inward+backing+up]
  # CUT fragment holes are covered by background paint, not extruded internal walls.
  for face in [corners,outside,[a,a-inward,a-inward+up,a+up],[b-inward,b,b+up,b-inward+up]]:
   var normal:Vector3=(face[2]-face[0]).cross(face[1]-face[0]).normalized()
   for i in [0,1,2,0,2,3]:
    var point:Vector3=face[i]
    inner.set_normal(normal);inner.set_uv(Vector2((point.x+point.z)*32./3./inner_texture.get_width(),-point.y/PIXEL_HEIGHT/inner_texture.get_height()));inner.add_vertex(point)
  var wall:Mesh=inner.commit();result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,wall.surface_get_arrays(0));result.surface_set_material(1,Source.material(inner_texture))
 return result

static func painted_rod(skin,a:Vector3,b:Vector3,radius:float):
 var parts=load("res://scripts/forest/forest_falan_lamps.gd");parts.prepare_primitives()
 var tool=SurfaceTool.new();tool.begin(Mesh.PRIMITIVE_TRIANGLES);parts.rod(tool,a,b,radius)
 var arrays:Array=tool.commit().surface_get_arrays(0);var vertices:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX];var normals:PackedVector3Array=arrays[Mesh.ARRAY_NORMAL];var indices:PackedInt32Array=arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX]!=null else PackedInt32Array()
 for i in indices.size() if not indices.is_empty() else vertices.size():
  var index=int(indices[i]) if not indices.is_empty() else i;skin.vertex(vertices[index],normals[index])

static func furniture(g:Dictionary,textures:Array,shape:Dictionary)->Mesh:
 var origin=Vector2(g.origin[0],g.origin[1]);var height=float(shape.height_pixels)*PIXEL_HEIGHT
 var body_texture:Texture2D=load(shape.wood.path) if shape.has("wood") else textures[1]
 var body_rect=Rect2(Vector2.ZERO,body_texture.get_size()) if shape.has("wood") else Rect2(g.rect[0],g.rect[1],g.rect[2],g.rect[3])
 var skin=Source.new([body_rect,-origin,Vector2.ONE,0],body_texture,PIXEL_HEIGHT);skin.reflection_threshold=2.
 var gold_texture:Texture2D=load(shape.gold.path);var gold_g=g.duplicate();gold_g.rect=[0,0,g.rect[2],g.rect[3]]
 var metal=Source.new([Rect2(Vector2.ZERO,gold_texture.get_size()),-origin,Vector2.ONE,0],gold_texture,PIXEL_HEIGHT);metal.reflection_threshold=2.
 var top:Array[Vector3]=[]
 for foot in shape.feet:
  var point=relief_point(origin+Vector2(foot[0],foot[1]),Vector2(0,origin.y+foot[1]));top.append(point+Vector3.UP*height)
 skin.quad(top[0],top[3],top[2],top[1])
 skin.quad(top[0]-Vector3.UP*PIXEL_HEIGHT*2.,top[1]-Vector3.UP*PIXEL_HEIGHT*2.,top[2]-Vector3.UP*PIXEL_HEIGHT*2.,top[3]-Vector3.UP*PIXEL_HEIGHT*2.)
 for i in 4:
  var a:Vector3=top[i];var b:Vector3=top[(i+1)%4];skin.quad(a,b,b-Vector3.UP*PIXEL_HEIGHT*2.,a-Vector3.UP*PIXEL_HEIGHT*2.)
  if shape.kind=="bench":painted_rod(metal,a,b,.055)
 if shape.has("back"):
  var back:Dictionary=shape.back;var a:Vector3=top[int(back.indices[0])]-Vector3.UP*height;var b:Vector3=top[int(back.indices[1])]-Vector3.UP*height
  var low_a=a+Vector3.UP*float(back.bottom)*PIXEL_HEIGHT;var low_b=b+Vector3.UP*float(back.bottom)*PIXEL_HEIGHT
  var high_a=a+Vector3.UP*float(back.top[0])*PIXEL_HEIGHT;var high_b=b+Vector3.UP*float(back.top[1])*PIXEL_HEIGHT
  var normal=(high_b-low_a).cross(high_a-low_a).normalized()*.04
  for side in 2:
   var face=[low_a+normal,high_a+normal,high_b+normal,low_b+normal] if side==0 else [low_b-normal,high_b-normal,high_a-normal,low_a-normal]
   var facing:Vector3=(face[2]-face[0]).cross(face[1]-face[0]).normalized()
   for i in [0,1,2,0,2,3]:
    var painted:Array=back.paint[i if side==0 else 3-i]
    skin.projected_vertex(face[i],facing,pixel_point(origin+Vector2(painted[0],painted[1])))
  skin.quad(high_a+normal,high_a-normal,high_b-normal,high_b+normal)
  painted_rod(metal,a+Vector3.UP*float(shape.leg_heights[int(back.indices[0])])*PIXEL_HEIGHT,b+Vector3.UP*float(shape.leg_heights[int(back.indices[1])])*PIXEL_HEIGHT,.055)
 for brace in shape.get("braces",[]):
  var a=Vector2(brace[0][0],brace[0][1])+origin;var b=Vector2(brace[1][0],brace[1][1])+origin
  painted_rod(metal,relief_point(a,Vector2(0,a.y)),relief_point(b,Vector2(0,b.y)),.055)
 var tool=SurfaceTool.new();tool.begin(Mesh.PRIMITIVE_TRIANGLES);tool.append_from(skin.finish(),0,Transform3D.IDENTITY)
 var frame=SurfaceTool.new();frame.begin(Mesh.PRIMITIVE_TRIANGLES)
 if shape.has("back"):frame.append_from(metal.finish(),0,Transform3D.IDENTITY)
 for i in shape.feet.size():
  var foot:Array=shape.feet[i];var painted:Array=shape.feet[int(shape.paint_sources[i])]
  var x=float(painted[0]);var y=float(painted[1])
  var high=float(shape.leg_heights[i]) if shape.has("leg_heights") else float(shape.height_pixels);var width=float(shape.leg_width)
  var leg={"foot":painted,"profile":[[x,y,width],[x,y-3.,width+1.],[x+1.,y-high+4.,maxf(1.,width-1.)],[x,y-high,width+1.]],"sides":8,"paint_rows":true}
  var shift=relief_point(origin+Vector2(foot[0],foot[1]),Vector2(0,origin.y+foot[1]))-relief_point(origin+Vector2(x,y),Vector2(0,origin.y+y))
  frame.append_from(column(gold_g,gold_texture,leg),0,Transform3D(Basis.IDENTITY,shift))
 var mesh:Mesh=tool.commit();mesh.surface_set_material(0,Source.material(body_texture))
 var gold:Mesh=frame.commit();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,gold.surface_get_arrays(0));mesh.surface_set_material(1,Source.material(gold_texture))
 return mesh

static func ground_infill(root:Node3D,id:int,origin:Vector2):
 var row:Dictionary=props.get("floor_infills",{}).get(str(id),{})
 if row.is_empty():return
 var key="floor_infill:"+str(id)
 if not meshes.has(key):
  var texture:Texture2D=load(row.path);var tool=SurfaceTool.new();tool.begin(Mesh.PRIMITIVE_TRIANGLES)
  var corners=[Vector2.ZERO,Vector2(texture.get_width(),0),texture.get_size(),Vector2(0,texture.get_height())]
  for i in [0,1,2,0,2,3]:
   var native:Vector2=corners[i]+Vector2(row.origin[0],row.origin[1]);var point=relief_point(native,Vector2(0,native.y));point.y=.02
   tool.set_normal(Vector3.UP);tool.set_uv(corners[i]/texture.get_size());tool.add_vertex(point)
  var mesh:Mesh=tool.commit();mesh.surface_set_material(0,Source.material(texture));meshes[key]=mesh
 var node=MeshInstance3D.new();node.name="ElsaOccludedFloor_"+str(id);node.mesh=meshes[key];node.position=Vector3(origin.x,0,origin.y);node.set_meta("inferred_occluded_paving",true);root.add_child(node)

static func banyan_trunk(g:Dictionary,shape:Dictionary,parts:Array)->Mesh:
 var texture:Texture2D=load(shape.bark.path);var origin=Vector2(g.origin[0],g.origin[1]);var root_pixel=Vector2(shape.root_pixel[0],shape.root_pixel[1])+origin
 var at=Vector3(root_pixel.x*3./64.-root_pixel.y/16.,0,root_pixel.x*3./64.+root_pixel.y/16.)
 var height=(float(shape.root_pixel[1])-float(shape.top[1]))/Fit.VERTICAL
 var target_width=float(shape.top[2]);var wanted_lean=(float(shape.top[0])-float(shape.root_pixel[0]))*3./64.
 var skin=Source.new([Rect2(Vector2.ZERO,texture.get_size()),-origin,Vector2.ONE,0],texture,1./Fit.VERTICAL);skin.reflection_threshold=2.
 for part in parts:
  if part.name!="Body":continue
  for surface in part.mesh.get_surface_count():
   var arrays:Array=part.mesh.surface_get_arrays(surface);var vertices:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX];var indices:PackedInt32Array=arrays[Mesh.ARRAY_INDEX]
   var root_box=AABB();var lower_box=AABB();var top_box=AABB();var root_first=true;var lower_first=true;var top_first=true
   for vertex in vertices:
    var p:Vector3=part.transform*vertex
    if p.y<.6:root_box=AABB(p,Vector3.ZERO) if root_first else root_box.expand(p);root_first=false
    if absf(p.y)<.05 and Vector2(p.x,p.z).length()<.45:lower_box=AABB(p,Vector3.ZERO) if lower_first else lower_box.expand(p);lower_first=false
    if p.y>2.8 and p.y<float(shape.core_limit):top_box=AABB(p,Vector3.ZERO) if top_first else top_box.expand(p);top_first=false
   assert(not root_first and not lower_first and not top_first)
   var scale_=Vector3(float(shape.root_cells[0])*3./root_box.size.x,height/top_box.get_center().y,float(shape.root_cells[1])*3./root_box.size.z)
   var lower=lower_box.get_center();var upper=top_box.get_center();var root_center=root_box.get_center()
   var projected_top_width=sqrt(pow(top_box.size.x*scale_.x,2)+pow(top_box.size.z*scale_.z,2))*Fit.HORIZONTAL
   var top_growth=target_width/projected_top_width
   for i in range(0,indices.size(),3):
    var source_points:Array[Vector3]=[]
    for j in range(3):source_points.append(part.transform*vertices[indices[i+j]])
    if source_points.any(func(p):return p.y>float(shape.core_limit)):continue
    var points:Array[Vector3]=[]
    for p in source_points:
     var fraction=clampf(p.y/top_box.get_center().y,0.,1.);var center=lower.lerp(upper,fraction)
     var radial=Vector2(p.x,p.z).length()<.45
     var dx=(p.x-(center.x if radial else root_center.x))*scale_.x
     var dz=(p.z-(center.z if radial else root_center.z))*scale_.z
     if radial:
      var growth=lerpf(1.8,top_growth,fraction);dx*=growth;dz*=growth
     if p.y<.1:
      for toe in shape.toes:
       var end=Vector3(toe.model[0],toe.model[1],toe.model[2])
       if Vector2(p.x-end.x,p.z-end.z).length()>float(toe.radius)+.0001:continue
       var native=origin+Vector2(toe.pixel[0],toe.pixel[1]);var target=Vector3(native.x*3./64.-native.y/16.,0,native.x*3./64.+native.y/16.)-at
       var end_fraction=clampf(end.y/top_box.get_center().y,0.,1.)
       dx+=target.x-(end.x-root_center.x)*scale_.x-wanted_lean*end_fraction
       dz+=target.z-(end.z-root_center.z)*scale_.z-wanted_lean*end_fraction
       break
     points.append(at+Vector3(dx+wanted_lean*fraction,maxf(0.,p.y)*scale_.y,dz+wanted_lean*fraction))
    var normal:Vector3=(points[2]-points[0]).cross(points[1]-points[0]).normalized()
    for p in points:
     var sample=p
     if normal.dot(Vector3(-1./16.,1./Fit.VERTICAL,1./16.))<0.:
      var depth=(p.z-p.x)-(at.z-at.x);sample.x+=depth;sample.z-=depth
     skin.projected_vertex(p,normal,sample)
 return skin.finish()

static func banyan(g:Dictionary,shape:Dictionary)->Mesh:
 var body_texture:Texture2D=load(shape.body.path);var solid:Texture2D=load(shape.body_solid.path);var leaf:Texture2D=load(shape.leaf.path)
 var body_g=g.duplicate();body_g.rect=[0,0,g.rect[2],g.rect[3]]
 var result:Mesh=Fit.transformed(small_props(body_g,[body_texture,solid],{"grounded":shape.body_parts}),Fit.native_coastal_frame())
 var parts:Array=Meadow.source(shape.model);var origin=Vector2(g.origin[0],g.origin[1]);var projection_size=2.*Fit.HORIZONTAL*Fit.HORIZONTAL
 for trunk in shape.get("trunks",[]):
  var mesh:Mesh=banyan_trunk(g,trunk,parts);var index=result.get_surface_count()
  result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,mesh.surface_get_arrays(0));result.surface_set_material(index,mesh.surface_get_material(0))
 var paint=ShaderMaterial.new();paint.shader=Meadow.WIND;paint.set_shader_parameter("tree",true);paint.set_shader_parameter("canopy",true)
 paint.set_shader_parameter("strength",.025);paint.set_shader_parameter("use_source_paint",true);paint.set_shader_parameter("source_paint",leaf)
 for crown in shape.crowns:
  var point_index=0;var foot:Array=shape.body_parts[int(crown.part)].foot
  var source_center=Vector2(crown.center[0],crown.center[1]);var native_center=origin+source_center
  var ground=float(foot[0])*native_center.x+float(foot[1])
  var anchor=Vector3(native_center.x*3./64.-ground/16.,(ground-native_center.y)/Fit.VERTICAL,native_center.x*3./64.+ground/16.)
  for part in parts:
   if part.name!="Canopy":continue
   for surface in part.mesh.get_surface_count():
    var arrays:Array=part.mesh.surface_get_arrays(surface);var vertices:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX];var normals:PackedVector3Array=arrays[Mesh.ARRAY_NORMAL];var indices:PackedInt32Array=arrays[Mesh.ARRAY_INDEX]
    var normal_matrix:Basis=part.transform.basis.inverse().transposed()
    for i in range(0,indices.size(),6):
     var ids:Array[int]=[]
     for j in range(i,i+6):
      if not indices[j] in ids:ids.append(indices[j])
     assert(ids.size()==4,"The imported canopy must retain independent leaf quads")
     var center=Vector3.ZERO;var bounds=Rect2();var first=true
     for id in ids:
      var p:Vector3=part.transform*vertices[id];center+=p
      var projected=Vector2((p.x+p.z)*32./3.,(p.z-p.x)*8.-p.y*Fit.VERTICAL)
      bounds=Rect2(projected,Vector2.ZERO) if first else bounds.expand(projected);first=false
     center/=4.
     var sample:Array=crown.points[point_index];point_index+=1
     var pixel=Vector2(sample[0],sample[1])-source_center;var depth=float(sample[2])
     # Project into the camera plane before adding unseen depth; vertical pixels also encode floor depth.
     var target=anchor+Vector3(pixel.x*3./64.-pixel.y*8./projection_size,-pixel.y*Fit.VERTICAL/projection_size,pixel.x*3./64.+pixel.y*8./projection_size)+Vector3(-depth/16.,depth/Fit.VERTICAL,depth/16.)
     var scale_=float(crown.leaf_pixels)/maxf(bounds.size.x,bounds.size.y)
     for id in ids:vertices[id]=target+(part.transform*vertices[id]-center)*scale_;normals[id]=(normal_matrix*normals[id]).normalized()
    var uv=PackedVector2Array();var colors=PackedColorArray();colors.resize(vertices.size());colors.fill(Color.WHITE)
    for p in vertices:uv.append((Vector2((p.x+p.z)*32./3.,(p.z-p.x)*8.-p.y*Fit.VERTICAL)-origin).clamp(Vector2.ONE*.5,leaf.get_size()-Vector2.ONE*.5)/leaf.get_size())
    arrays[Mesh.ARRAY_VERTEX]=vertices;arrays[Mesh.ARRAY_NORMAL]=normals;arrays[Mesh.ARRAY_TEX_UV]=uv;arrays[Mesh.ARRAY_COLOR]=colors
    var index=result.get_surface_count();result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays);result.surface_set_material(index,paint)
  assert(point_index==crown.points.size())
 return result

static func build_props(root:Node3D,id:int,origin:Vector2):
 if props.is_empty():props=JSON.parse_string(FileAccess.get_file_as_string("res://assets/maps/falan/elsa/props/data.json"))
 TrialEntrance.build(root,id,origin)
 ground_infill(root,id,origin)
 var batches={};var floors={};var span=48.
 var placements:Array=props.maps.get(str(id),[]).filter(func(p):return not p.get("empty_cut",false) and not props.groups[p.group].get("floor_only",false))
 if id==59535:placements=placements.filter(func(p):return int(props.groups[p.group].master) not in [301052,301053])
 if id==59520:
  var hidden={}
  for spire in props.get("spires",[]):
   for member in spire.members:hidden[[member.group,member.anchor]]=true
  placements=placements.filter(func(p):return not hidden.has([p.group,p.anchor]) and not load("res://scripts/forest/forest_elsa_gate.gd").replaces(p) and not load("res://scripts/forest/forest_elsa_temple.gd").replaces(p))+props.get("spires",[])
 for placement in placements:
  if id in [59716,59752] and not placement.cells.any(func(cell):return load("res://scripts/forest/forest_elsa_route.gd").visible_cell(id,Vector2i(cell[0],cell[1]))):continue
  var token:String=placement.group;var u=float(placement.anchor[0]);var v=float(placement.anchor[1])
  var at=Vector3(origin.x+u*3./64.-v/16.,0,origin.y+u*3./64.+v/16.)
  var chunk=Vector2i(floori(at.x/span),floori(at.z/span));var key=[token,chunk]
  if not batches.has(key):batches[key]=[]
  batches[key].append(at)
 for key in batches:
  var token:String=key[0];var cache="prop:"+token;var row:Dictionary=props.groups[token]
  var surface:Dictionary={}
  if row.has("source_surface"):
   surface=source_surface_spec(row.source_surface.path,id);cache+=":"+str(surface.get("background_template",""))
  if not meshes.has(cache):
   var page=int(row.page)
   if not prop_textures.has(page):prop_textures[page]=[load("res://assets/maps/falan/elsa/props/atlas-%d.png"%page),load("res://assets/maps/falan/elsa/props/solid-%d.png"%page)]
   var g={"rect":row.rect,"origin":row.origin,"cut":[row.master],"edges":row.edges}
   if row.has("tree"):
    var model=ArrayMesh.new()
    for box in row.tree.boxes:
     var piece=fitted_model(row.tree.model,g,Rect2(box[0],box[1],box[2]-box[0],box[3]-box[1]))
     for slot in piece.get_surface_count():
      var index=model.get_surface_count();model.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,piece.surface_get_arrays(slot));model.surface_set_material(index,piece.surface_get_material(slot))
    meshes[cache]=model
   elif row.has("banyan"):meshes[cache]=banyan(g,row.banyan)
   elif row.has("pedestal"):meshes[cache]=crystal_pedestal(g,source_surface_spec(row.pedestal.path,id))
   elif row.has("furniture"):meshes[cache]=Fit.transformed(furniture(g,prop_textures[page],row.furniture),Fit.native_coastal_frame())
   elif row.has("rock"):meshes[cache]=fitted_rock(g,prop_textures[page][1],row.rock)
   elif row.has("bridge"):meshes[cache]=Fit.transformed(bridge(g,prop_textures[page][0],row.bridge),Fit.native_coastal_frame())
   elif row.has("source_surface"):meshes[cache]=source_surface(g,prop_textures[page][0],surface)
   elif row.has("grounded") or row.has("columns") or row.has("wall_parts"):meshes[cache]=Fit.transformed(small_props(g,prop_textures[page],row),Fit.native_coastal_frame())
   else:meshes[cache]=Fit.transformed(column(g,prop_textures[page][1],row.column) if row.has("column") else relief_shape(g,prop_textures[page][0],prop_textures[page][1],row.edges,Vector2(row.wall.foot[0],row.wall.foot[1]) if row.has("wall") else Vector2.ZERO),Fit.native_coastal_frame())
  var chunk:Vector2i=key[1];var at=Vector3(chunk.x*span,0,chunk.y*span)
  var node=MultiMeshInstance3D.new();node.name="ElsaOriginalObject_"+token;node.position=at
  node.multimesh=MultiMesh.new();node.multimesh.transform_format=MultiMesh.TRANSFORM_3D;node.multimesh.mesh=meshes[cache];node.multimesh.instance_count=batches[key].size()
  for i in batches[key].size():node.multimesh.set_instance_transform(i,Transform3D(Basis.IDENTITY,batches[key][i]-at))
  node.set_meta("source_graphic",int(row.master));root.add_child(node)
 for placement in props.maps.get(str(id),[]):
  if not placement.has("ground_cells"):continue
  var row:Dictionary=props.groups[placement.group];var page=int(row.page)
  if not prop_textures.has(page):prop_textures[page]=[load("res://assets/maps/falan/elsa/props/atlas-%d.png"%page),load("res://assets/maps/falan/elsa/props/solid-%d.png"%page)]
  if not floors.has(page):
   floors[page]=SurfaceTool.new();floors[page].begin(Mesh.PRIMITIVE_TRIANGLES)
  architecture_ground(floors[page],id,origin,placement,row,prop_textures[page][0].get_size())
 for page in floors:
  var node=MeshInstance3D.new();node.name="ElsaOriginalStairGround_%d"%page;node.mesh=floors[page].commit()
  if node.mesh==null:node.free();continue
  node.mesh.surface_set_material(0,Source.material(prop_textures[page][0]));root.add_child(node)

static func architecture_ground(tool:SurfaceTool,id:int,origin:Vector2,placement:Dictionary,row:Dictionary,atlas_size:Vector2):
 var native=Vector2(placement.anchor[0]+row.origin[0],placement.anchor[1]+row.origin[1])
 var size_=Vector2(row.rect[2],row.rect[3]);var polygon=PackedVector2Array()
 for pixel in [Vector2.ZERO,Vector2(size_.x,0),size_,Vector2(0,size_.y)]:
  var p:Vector2=native+pixel;polygon.append(Vector2(p.x*3./64.-p.y/16.,p.x*3./64.+p.y/16.))
 for cell in placement.ground_cells:
  var at=Vector2(cell[0]*3.,cell[1]*3.)
  if id in [59716,59752] and not load("res://scripts/forest/forest_elsa_route.gd").owned_cell(id,Vector2i(cell[0],cell[1])):continue
  var clips=Geometry2D.intersect_polygons(polygon,PackedVector2Array([at+Vector2(-1.5,-1.5),at+Vector2(1.5,-1.5),at+Vector2(1.5,1.5),at+Vector2(-1.5,1.5)]))
  for clipped in clips:
   var triangles=Geometry2D.triangulate_polygon(clipped)
   for index in triangles:
    var p:Vector2=clipped[index]
    var pixel=Vector2((p.x+p.y)*32./3.,(p.y-p.x)*8.)-native
    tool.set_normal(Vector3.UP);tool.set_uv((Vector2(row.rect[0],row.rect[1])+pixel.clamp(Vector2.ONE*.5,size_-Vector2.ONE*.5))/atlas_size)
    tool.add_vertex(Vector3(origin.x+p.x,.034,origin.y+p.y))

static func column(g:Dictionary,texture:Texture2D,shape:Dictionary)->Mesh:
 var origin=Vector2(g.origin[0],g.origin[1]);var foot=origin+Vector2(shape.foot[0],shape.foot[1])
 var at=Vector3(foot.x*3./64.-foot.y/16.,0,foot.x*3./64.+foot.y/16.)
 var skin=Source.new([Rect2(g.rect[0],g.rect[1],g.rect[2],g.rect[3]),-origin,Vector2.ONE,0],texture,PIXEL_HEIGHT)
 var native_faces=shape.get("native_faces",false)
 skin.reflection_threshold=.01 if native_faces else 2.
 skin.projection_center=at
 var levels=[]
 for row in shape.profile:
  var across=(float(row[0])-float(shape.foot[0]))*.06629126
  levels.append([Vector3(across*.70710678,(float(shape.foot[1])-float(row[1]))*PIXEL_HEIGHT,across*.70710678)+at,float(row[2])/30.16989,float(row[1])])
 var count_=int(shape.get("sides",8))
 for i in levels.size()-1:
  for side in count_:
   var a=(side+.5)*TAU/count_;var b=(side+1.5)*TAU/count_
   var corners=[levels[i][0]+Vector3(cos(a),0,sin(a))*levels[i][1],levels[i][0]+Vector3(cos(b),0,sin(b))*levels[i][1],levels[i+1][0]+Vector3(cos(b),0,sin(b))*levels[i+1][1],levels[i+1][0]+Vector3(cos(a),0,sin(a))*levels[i+1][1]]
   if native_faces:
    var normal:Vector3=(corners[2]-corners[0]).cross(corners[1]-corners[0]).normalized()
    for j in [0,1,2,0,2,3]:
     var point:Vector3=corners[j];var row=float(shape.foot[1])-point.y/PIXEL_HEIGHT
     var molding:Dictionary=shape.get("molding",{})
     if not molding.is_empty() and absf(normal.y)>.1 and row>=float(molding.min_row) and row<=float(molding.max_row):
      var sample=point;sample.y=((sample.z-sample.x)*8.-origin.y-float(molding.paint_row))*PIXEL_HEIGHT
      skin.projected_vertex(point,normal,sample)
     else:skin.vertex(point,normal)
   elif shape.get("paint_rows",false):
    var normal:Vector3=(corners[2]-corners[0]).cross(corners[1]-corners[0]).normalized()
    for j in [0,1,2,0,2,3]:
     var point:Vector3=corners[j];var sample:Vector3=point
     sample.y=((point.z-point.x)*8.-origin.y-levels[i if j<2 else i+1][2])*PIXEL_HEIGHT
     skin.projected_vertex(point,normal,sample)
   else:skin.quad(corners[0],corners[1],corners[2],corners[3])
 var top:Array=levels.back()
 for side in count_:
  var a=(side+.5)*TAU/count_;var b=(side+1.5)*TAU/count_
  var p:Vector3=top[0];var r:float=top[1]
  if shape.has("cap_paint_pixel"):
   var pixel=Vector2(shape.cap_paint_pixel[0],shape.cap_paint_pixel[1])+origin
   for point in [p,p+Vector3(cos(a),0,sin(a))*r,p+Vector3(cos(b),0,sin(b))*r]:skin.projected_vertex(point,Vector3.UP,pixel_point(pixel))
  else:skin.quad(p,p+Vector3(cos(a),0,sin(a))*r,p+Vector3(cos(b),0,sin(b))*r,p)
 return skin.finish(native_faces)

static func crystal_pedestal(g:Dictionary,spec:Dictionary,body_texture:Texture2D=null,globe_texture:Texture2D=null)->Mesh:
 assert(g.origin==spec.origin and int(g.cut[0])==int(spec.master) and not spec.candidate_only,"Pedestal requires its reviewed original source sections")
 var local={"rect":[0,0,spec.size[0],spec.size[1]],"origin":g.origin}
 if body_texture==null:body_texture=load(spec.paints.body)
 if globe_texture==null:globe_texture=load(spec.paints.globe)
 var result=Fit.transformed(column(local,body_texture,spec.body),Fit.native_coastal_frame()) as ArrayMesh
 var foot=Vector2(spec.origin[0]+spec.body.foot[0],spec.origin[1]+spec.body.foot[1])
 var centre=Vector3(foot.x*3./64.-foot.y/16.,0,foot.x*3./64.+foot.y/16.)
 var du=float(spec.orb.centre[0])-float(spec.body.foot[0])
 centre+=Vector3(du*3./64.,(float(spec.body.foot[1])-float(spec.orb.centre[1]))*PIXEL_HEIGHT,du*3./64.)
 centre+=Vector3(-Fit.VERTICAL/16.,Fit.VERTICAL*PIXEL_HEIGHT,Fit.VERTICAL/16.)*float(spec.orb.source_null_lift)
 var sphere=SphereMesh.new();sphere.radius=.5;sphere.height=1.;sphere.radial_segments=24;sphere.rings=12
 var radius=float(spec.orb.radius);var scale_=Vector3(2.*radius,2.*radius*Fit.VERTICAL*PIXEL_HEIGHT,2.*radius)
 var skin=Source.new([Rect2(0,0,spec.size[0],spec.size[1]),-Vector2(spec.origin[0],spec.origin[1]),Vector2.ONE,0],globe_texture,PIXEL_HEIGHT)
 var arrays=sphere.get_mesh_arrays();var points:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX];var normals:PackedVector3Array=arrays[Mesh.ARRAY_NORMAL]
 for index in arrays[Mesh.ARRAY_INDEX]:
  var point:Vector3=points[index]*scale_+centre
  skin.projected_vertex(point,(normals[index]/scale_).normalized(),point)
 # Transform both retained CPU surfaces before combining; no GPU readback.
 var globe=Fit.transformed(skin.finish(true),Fit.native_coastal_frame())
 result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,globe.get_meta("source_surface_arrays"));result.surface_set_material(1,globe.surface_get_material(0))
 return result

static func entry_pedestals(root:Node3D,origin:Vector2,row:Dictionary,paint_overrides:Array=[]):
 assert(int(row.map)==59530)
 var spec:Dictionary=row.spec;var cache="entry-pedestal:"+str(row.body_sha256)+str(row.globe_sha256)
 if not meshes.has(cache):
  meshes[cache]=crystal_pedestal({"origin":spec.origin,"cut":[spec.master]},spec,paint_overrides[0] if not paint_overrides.is_empty() else null,paint_overrides[1] if not paint_overrides.is_empty() else null)
 var node=MeshInstance3D.new();node.name="ElsaOriginalBGPedestal";node.mesh=meshes[cache]
 var u=float(row.bg_origin[0]);var v=float(row.bg_origin[1])
 node.position=Vector3(origin.x+u*3./64.-v/16.,0,origin.y+u*3./64.+v/16.);root.add_child(node)
 node.set_meta("source_layer",0);node.set_meta("inferred_hidden_geometry",true)
 var key="entry-apron:"+str(row.infill_sha256)
 if not meshes.has(key):
  var paint:Texture2D=paint_overrides[2] if not paint_overrides.is_empty() else load(row.infill_path)
  var r:Array=row.native_rect
  var skin=Source.new([Rect2(Vector2.ZERO,paint.get_size()),-Vector2(r[0],r[1]),Vector2.ONE,0],paint,1./Fit.VERTICAL);skin.reflection_threshold=2.
  var points=[]
  for native in [Vector2(r[0],r[1]),Vector2(r[2],r[1]),Vector2(r[2],r[3]),Vector2(r[0],r[3])]:points.append(Vector3(native.x*3./64.-native.y/16.,0,native.x*3./64.+native.y/16.))
  skin.quad(points[0],points[1],points[2],points[3]);meshes[key]=skin.finish(true)
 var floor_node=MeshInstance3D.new();floor_node.name="ElsaOriginalPedestalApronRepair";floor_node.mesh=meshes[key]
 floor_node.position=Vector3(origin.x,.018,origin.y);floor_node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;root.add_child(floor_node)
 floor_node.set_meta("inferred_occluded_apron",true)
 if not meshes.has("entry-void-59530"):
  var color:Array=row.void_native_rgba;var image_=Image.create(1,1,false,Image.FORMAT_RGBA8)
  image_.fill(Color(float(color[0])/255.,float(color[1])/255.,float(color[2])/255.,float(color[3])/255.))
  # A floor plane cannot cover above-horizon rays between the native void tiles.
  var backdrop=BoxMesh.new();backdrop.size=Vector3.ONE*maxf(row.map_size[0],row.map_size[1])*3.*1.25;backdrop.flip_faces=true
  backdrop.material=Source.material(ImageTexture.create_from_image(image_));meshes["entry-void-59530"]=backdrop
 var background=MeshInstance3D.new();background.name="ElsaOriginalTempleVoid";background.mesh=meshes["entry-void-59530"]
 background.position=Vector3(origin.x+(row.map_size[0]-1)*1.5,0,origin.y+(row.map_size[1]-1)*1.5)
 background.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;root.add_child(background);background.set_meta("original_background_matte",true)

static func inner_hall_sample(rows:Array,t:float,high:bool)->Vector3:
 var index=clampf(t,0.,1.)*(rows.size()-1);var first=floori(index);var a:Array=rows[first];var b:Array=rows[mini(first+1,rows.size()-1)];var blend=index-first
 var u=lerpf(float(a[0]),float(b[0]),blend);var foot=lerpf(float(a[2]),float(b[2]),blend)
 var point=relief_point(Vector2(u,foot),Vector2(0,foot))
 if high:point.y=(foot-lerpf(float(a[1]),float(b[1]),blend))/Fit.VERTICAL
 return point

static func inner_hall(root:Node3D,origin:Vector2):
 var folder=ROOT+"inner-hall/";var spec:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(folder+"data.json"))
 if not meshes.has("inner-hall"):
  var rect:Array=spec.rect;var mesh=ArrayMesh.new()
  for front in [false,true]:
   var paint:Texture2D=load(folder+("background" if front else "foreground")+"-wall.png")
   var skin=Source.new([Rect2(Vector2.ZERO,paint.get_size()),-Vector2(rect[0],rect[1]),Vector2.ONE,0],paint,1./Fit.VERTICAL);skin.reflection_threshold=2.
   var hidden_paint:Texture2D=load(folder+("foreground" if front else "background")+"-wall.png")
   var hidden=Source.new([Rect2(Vector2.ZERO,hidden_paint.get_size()),-Vector2(rect[0],rect[1]),Vector2.ONE,0],hidden_paint,1./Fit.VERTICAL);hidden.reflection_threshold=2.
   var counterpart:Array=spec.walls[1 if front else 4].rows
   for wall in spec.walls:
    if wall.front!=front:continue
    for i in wall.rows.size()-1:
     var a:Array=wall.rows[i];var b:Array=wall.rows[i+1]
     var low_a=relief_point(Vector2(a[0],a[2]),Vector2(0,a[2]));var low_b=relief_point(Vector2(b[0],b[2]),Vector2(0,b[2]))
     var high_a=low_a+Vector3.UP*(float(a[2])-float(a[1]))/Fit.VERTICAL;var high_b=low_b+Vector3.UP*(float(b[2])-float(b[1]))/Fit.VERTICAL
     var corners=[low_a,low_b,high_b,high_a];var normal=(high_b-low_a).cross(low_b-low_a).normalized()
     for j in [0,2,1,0,3,2]:skin.projected_vertex(corners[j],-normal,corners[j])
     var ta=float(i)/(wall.rows.size()-1);var tb=float(i+1)/(wall.rows.size()-1)
     var samples=[inner_hall_sample(counterpart,ta,false),inner_hall_sample(counterpart,tb,false),inner_hall_sample(counterpart,tb,true),inner_hall_sample(counterpart,ta,true)]
     for j in [0,1,2,0,2,3]:hidden.projected_vertex(corners[j]+normal*.3,normal,samples[j])
     skin.quad(high_a,high_a+normal*.3,high_b+normal*.3,high_b)
   if not front:
    # Continue the neighboring arch and its paint across the two unrecorded sides.
    for edge in spec.side_faces:
     var a:Array=spec.feet[int(edge[0])];var b:Array=spec.feet[int(edge[1])]
     var low_a=relief_point(Vector2(a[0],a[1]),Vector2(0,a[1]));var low_b=relief_point(Vector2(b[0],b[1]),Vector2(0,b[1]))
     var source_face:Array=spec.walls[0].rows
     for i in source_face.size()-1:
      var lows=[];var highs=[];var painted_lows=[];var painted_highs=[]
      for row in [source_face[i],source_face[i+1]]:
       var t=inverse_lerp(float(source_face[0][0]),float(source_face[-1][0]),float(row[0]));var high=Vector3.UP*(float(row[2])-float(row[1]))/Fit.VERTICAL
       var low=low_a.lerp(low_b,t);var sample=relief_point(Vector2(row[0],row[2]),Vector2(0,row[2]))
       lows.append(low);highs.append(low+high);painted_lows.append(sample);painted_highs.append(sample+high)
      var points=[lows[0],lows[1],highs[1],highs[0]];var samples=[painted_lows[0],painted_lows[1],painted_highs[1],painted_highs[0]]
      var normal:Vector3=(points[2]-points[0]).cross(points[1]-points[0]).normalized()
      for j in [0,2,1,0,3,2]:skin.projected_vertex(points[j],-normal,samples[j])
      var ta=float(i)/(source_face.size()-1);var tb=float(i+1)/(source_face.size()-1)
      var hidden_samples=[inner_hall_sample(counterpart,ta,false),inner_hall_sample(counterpart,tb,false),inner_hall_sample(counterpart,tb,true),inner_hall_sample(counterpart,ta,true)]
      for j in [0,1,2,0,2,3]:hidden.projected_vertex(points[j]+normal*.3,normal,hidden_samples[j])
      var caps=[highs[0],highs[0]+normal*.3,highs[1]+normal*.3,highs[1]]
      for j in [0,1,2,0,2,3]:skin.projected_vertex(caps[j],Vector3.UP,painted_highs[0 if j<2 else 1])
   var g={"rect":[0,0,paint.get_width(),paint.get_height()],"origin":[rect[0],rect[1]]}
   var column_paint:Texture2D=load(folder+("background-solid.png" if front else "foreground-columns.png"))
   var columns=SurfaceTool.new();columns.begin(Mesh.PRIMITIVE_TRIANGLES)
   for i in range(4 if front else 0,8 if front else 4):
    var shape:Dictionary=spec.columns[i];var fit:Dictionary=shape.duplicate(true);fit.foot=[shape.foot[0]-rect[0],shape.foot[1]-rect[1]]
    for row in fit.profile:row[0]-=rect[0];row[1]-=rect[1]
    columns.append_from(column(g,column_paint,fit),0,Fit.native_coastal_frame())
   var piece:Mesh=skin.finish();var index=mesh.get_surface_count();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,piece.surface_get_arrays(0));mesh.surface_set_material(index,piece.surface_get_material(0))
   var back:Mesh=hidden.finish();index=mesh.get_surface_count();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,back.surface_get_arrays(0));mesh.surface_set_material(index,back.surface_get_material(0))
   var pillars:Mesh=columns.commit();index=mesh.get_surface_count();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,pillars.surface_get_arrays(0));mesh.surface_set_material(index,Source.material(column_paint))
  var trim:Dictionary=spec.portal;var trim_paint:Texture2D=load(folder+"portal-trim.png");var trim_solid:Texture2D=load(folder+"portal-trim-solid.png")
  var trim_g={"rect":[0,0,trim.size[0],trim.size[1]],"origin":trim.origin,"cut":[301052],"depth":trim.depth,"source_depth":true}
  var frame:Transform3D=Fit.native_coastal_frame();frame.origin=Vector3(-1./16.,1./Fit.VERTICAL,1./16.).normalized()*(float(trim.depth)+.02)
  var ornament=relief_shape(trim_g,trim_paint,trim_solid,trim.edges,Vector2(trim.foot[0],trim.foot[1]))
  for surface in ornament.get_surface_count():
   var tool=SurfaceTool.new();tool.begin(Mesh.PRIMITIVE_TRIANGLES);tool.append_from(ornament,surface,frame)
   var piece:Mesh=tool.commit();var index=mesh.get_surface_count();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,piece.surface_get_arrays(0));mesh.surface_set_material(index,ornament.surface_get_material(surface))
  meshes["inner-hall"]=mesh
  var floor_texture:Texture2D=load(folder+"floor.png");var floor=Source.new([Rect2(Vector2.ZERO,floor_texture.get_size()),-Vector2(rect[0],rect[1]),Vector2.ONE,0],floor_texture,1./Fit.VERTICAL);floor.reflection_threshold=2.
  var points=[]
  for pixel in [Vector2(rect[0],rect[1]),Vector2(rect[2],rect[1]),Vector2(rect[2],rect[3]),Vector2(rect[0],rect[3])]:points.append(relief_point(pixel,Vector2(0,pixel.y))+Vector3.UP*.012)
  floor.quad(points[0],points[1],points[2],points[3]);meshes["inner-hall-floor"]=floor.finish()
 for key in ["inner-hall","inner-hall-floor"]:
  var node=MeshInstance3D.new();node.name="ElsaOriginal_"+key;node.mesh=meshes[key];node.position=Vector3(origin.x,0,origin.y)
  node.set_meta("source_map",59535);node.set_meta("inferred_hidden_surfaces",true);root.add_child(node)
 preload("res://scripts/forest/forest_elsa_hall_steps.gd").build(root,origin)
 inner_hall_room(root,origin,spec)

static func inner_hall_room(root:Node3D,origin:Vector2,spec:Dictionary):
 if not meshes.has("inner-hall-room"):
  var folder=ROOT+"inner-hall/";var rect:Array=spec.rect;var room:Dictionary=spec.room
  var paint:Texture2D=load(folder+"room-wall.png")
  var skin=Source.new([Rect2(Vector2.ZERO,paint.get_size()),-Vector2(rect[0],rect[1]),Vector2.ONE,0],paint,1./Fit.VERTICAL);skin.reflection_threshold=2.
  for wall in room.walls:
   for i in wall.rows.size()-1:
    var rows=[wall.rows[i],wall.rows[i+1]];var corners=[]
    for row in rows:
     var low=relief_point(Vector2(row[0],row[2]),Vector2(0,row[2]));corners.append(low);corners.append(low+Vector3.UP*(float(row[2])-float(row[1]))/Fit.VERTICAL)
    var a:Vector3=corners[0];var b:Vector3=corners[2];var c:Vector3=corners[3];var d:Vector3=corners[1]
    var normal=(c-a).cross(b-a).normalized()
    var points=[a,b,c,d]
    for j in [0,2,1,0,3,2]:skin.projected_vertex(points[j],-normal,points[j])
    for j in [0,1,2,0,2,3]:skin.projected_vertex(points[j]+normal*.6,normal,points[j])
    skin.quad(d,d+normal*.6,c+normal*.6,c)
  var source_rows:Array=room.walls[0].rows
  for edge in room.side_faces:
   var a:Array=room.feet[int(edge[0])];var b:Array=room.feet[int(edge[1])]
   var low_a=relief_point(Vector2(a[0],a[1]),Vector2(0,a[1]));var low_b=relief_point(Vector2(b[0],b[1]),Vector2(0,b[1]))
   var ha=float(a[1])-float(room.columns[int(edge[0])].profile[-1][1]);var hb=float(b[1])-float(room.columns[int(edge[1])].profile[-1][1])
   for i in source_rows.size()-1:
    var ta=float(i)/(source_rows.size()-1);var tb=float(i+1)/(source_rows.size()-1)
    var p=low_a.lerp(low_b,ta);var q=low_a.lerp(low_b,tb)
    var points=[p,q,q+Vector3.UP*lerpf(ha,hb,tb)/Fit.VERTICAL,p+Vector3.UP*lerpf(ha,hb,ta)/Fit.VERTICAL]
    var samples=[inner_hall_sample(source_rows,ta,false),inner_hall_sample(source_rows,tb,false),inner_hall_sample(source_rows,tb,true),inner_hall_sample(source_rows,ta,true)]
    var normal:Vector3=(points[2]-points[0]).cross(points[1]-points[0]).normalized()
    for j in [0,2,1,0,3,2]:skin.projected_vertex(points[j],-normal,samples[j])
    for j in [0,1,2,0,2,3]:skin.projected_vertex(points[j]+normal*.6,normal,samples[j])
    var caps=[points[3],points[2],points[2]+normal*.6,points[3]+normal*.6]
    for j in [0,1,2,0,2,3]:skin.projected_vertex(caps[j],Vector3.UP,samples[3 if j in [0,3] else 2])
  var mesh:ArrayMesh=skin.finish()
  var tool=SurfaceTool.new();tool.begin(Mesh.PRIMITIVE_TRIANGLES)
  var column_paint:Texture2D=load(folder+"room-columns.png")
  var g={"rect":[0,0,paint.get_width(),paint.get_height()],"origin":[rect[0],rect[1]]}
  for shape in room.columns:
   var fit:Dictionary=shape.duplicate(true);fit.foot=[shape.foot[0]-rect[0],shape.foot[1]-rect[1]]
   for row in fit.profile:row[0]-=rect[0];row[1]-=rect[1]
   tool.append_from(column(g,column_paint,fit),0,Fit.native_coastal_frame())
  var pillars:Mesh=tool.commit();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,pillars.surface_get_arrays(0));mesh.surface_set_material(1,Source.material(column_paint));meshes["inner-hall-room"]=mesh
 var node=MeshInstance3D.new();node.name="ElsaOriginalRoomWalls";node.mesh=meshes["inner-hall-room"];node.position=Vector3(origin.x,0,origin.y)
 node.set_meta("source_map",59535);node.set_meta("inferred_hidden_surfaces",true);root.add_child(node)

static func temple(root:Node3D,origin:Vector2):
 load("res://scripts/forest/forest_elsa_temple.gd").build(root,origin)
