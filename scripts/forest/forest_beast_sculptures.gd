extends RefCounted
## Rounded, closed sculptures retain their native pixel coordinates.
# shortcut: relief and hidden depth are inferred; replace them if matching original geometry is recovered.
const Data=preload("res://assets/maps/original_crossgate/beast-sculptures.gd")
const Source=preload("res://scripts/forest/forest_coastal_mesh.gd")
const Fit=preload("res://scripts/forest/forest_falan_proportions.gd")
const Parts=preload("res://scripts/forest/forest_falan_lamps.gd")
static var meshes:Dictionary={}
static var prepared_core:Mesh

static func point(pixel:Vector2,row:Array,depth:float,offset:float)->Vector3:
 var across=(pixel.x+row[1].x)*3.0/32.0
 var along=(float(row[3])+row[1].y)/8.0+(depth+offset)*sqrt(2.0)
 return Vector3((across-along)*.5,(float(row[3])-pixel.y+offset*sqrt(2.0)*8.0)/Fit.VERTICAL,(across+along)*.5)

static func plate(image:Image,rect:Rect2i,p:Vector2i)->int:
 return roundi(image.get_pixelv(rect.position+p).r*255) if Rect2i(Vector2i.ZERO,rect.size).has_point(p) else 0

static func quad(tool:SurfaceTool,points:Array,uvs:Array):
 for triangle in [[0,1,2],[0,2,3]]:
  var normal=(points[triangle[2]]-points[triangle[0]]).cross(points[triangle[1]]-points[triangle[0]])
  if normal.length_squared()<.000000000001:continue
  normal=normal.normalized()
  for i in triangle:tool.set_normal(normal);tool.set_uv(uvs[i]);tool.add_vertex(points[i])

static func core()->Mesh:
 if prepared_core!=null:return prepared_core
 var bytes=Marshalls.base64_to_raw(Data.CORE_FACES).decompress(int(Data.CORE.bytes),FileAccess.COMPRESSION_DEFLATE)
 var origin=Vector3(Data.CORE.origin[0],Data.CORE.origin[1],Data.CORE.origin[2]);var step:float=Data.CORE.step
 var directions=[Vector3.RIGHT,Vector3.LEFT,Vector3.UP,Vector3.DOWN,Vector3.BACK,Vector3.FORWARD]
 var faces=[
  [Vector3(1,0,0),Vector3(1,1,0),Vector3(1,1,1),Vector3(1,0,1)],
  [Vector3(0,0,1),Vector3(0,1,1),Vector3(0,1,0),Vector3(0,0,0)],
  [Vector3(0,1,0),Vector3(0,1,1),Vector3(1,1,1),Vector3(1,1,0)],
  [Vector3(0,0,1),Vector3(0,0,0),Vector3(1,0,0),Vector3(1,0,1)],
  [Vector3(1,0,1),Vector3(1,1,1),Vector3(0,1,1),Vector3(0,0,1)],
  [Vector3(0,0,0),Vector3(0,1,0),Vector3(1,1,0),Vector3(1,0,0)]]
 var sums={};var counts={}
 for i in range(0,bytes.size(),4):
  var at=Vector3i(bytes[i],bytes[i+1],bytes[i+2]);var face:int=bytes[i+3]
  var center=Vector3(at)+Vector3.ONE*.5+directions[face]*.5
  for corner:Vector3 in faces[face]:
   var key=at+Vector3i(corner)
   sums[key]=sums.get(key,Vector3.ZERO)+center;counts[key]=counts.get(key,0)+1
 var tool=SurfaceTool.new();tool.begin(Mesh.PRIMITIVE_TRIANGLES)
 for i in range(0,bytes.size(),4):
  var at=Vector3i(bytes[i],bytes[i+1],bytes[i+2]);var face:int=bytes[i+3]
  var normal:Vector3=directions[face];var points=[];var uvs=[]
  var corners:Array=faces[face].duplicate()
  if (corners[2]-corners[0]).cross(corners[1]-corners[0]).dot(normal)<0:corners.reverse()
  for corner:Vector3 in corners:
   var key=at+Vector3i(corner)
   points.append(origin+(Vector3(key)*.25+sums[key]/counts[key]*.75)*step)
   uvs.append(Vector2.ZERO)
  quad(tool,points,uvs)
 prepared_core=tool.commit()
 return prepared_core

static func armor(serial:int)->Mesh:
 if meshes.has(serial):return meshes[serial]
 var row:Array=Data.ARMOR[serial];var rect:Rect2i=row[0]
 var crest_offset:float=Data.CORE.crest_anchors[str(serial)].offset
 var grip_offset:float=Data.CORE.grip_anchors[str(serial)].offset
 var depth=Data.DEPTH.get_image()
 var parts=Data.PARTS.get_image()
 var tool=SurfaceTool.new();tool.begin(Mesh.PRIMITIVE_TRIANGLES)
 var shell=SurfaceTool.new();shell.begin(Mesh.PRIMITIVE_TRIANGLES)
 for y in rect.size.y:
  for x in rect.size.x:
   var pixel=Vector2i(x,y)
   var part=plate(parts,rect,pixel)
   if part==0:continue
   # The four-view solid owns the suit; a flat torso relief obscures it from the normal camera.
   if part not in [2,7]:continue
   tool.set_color(Color(1,1,1,1 if part>=3 else 0));shell.set_color(Color(1,1,1,1 if part>=3 else 0))
   var offset:float=crest_offset if part==2 else (grip_offset if part in [1,7] else Data.OFFSETS[part])
   var front=[];var back=[];var uv=[];var rear_uv=[]
   for corner in [Vector2i.ZERO,Vector2i.RIGHT,Vector2i.ONE,Vector2i.DOWN]:
    var p=Vector2(pixel+corner);var amount=0.0;var samples=0;var interior=Vector2.ZERO
    for neighbor_offset in [Vector2i.ZERO,Vector2i.LEFT,Vector2i.UP,Vector2i(-1,-1)]:
     var at=Vector2i(p)+neighbor_offset
     if plate(parts,rect,at)==part:
      amount+=depth.get_pixelv(rect.position+at).r;samples+=1;interior+=Vector2(at)+Vector2.ONE*.5
    amount=amount/4.0*1.5
    if part>=3 and part!=7:amount*=.08
    if samples<4:
     var inward=interior/maxi(1,samples)-p
     if inward.length_squared()<.0001:inward=Vector2(pixel)+Vector2.ONE*.5-p
     p+=inward*.1
    front.append(point(p,row,amount,offset));back.append(point(p,row,-amount,offset))
    uv.append((Vector2(rect.position)+p+Vector2(0,amount*sqrt(2.0)*8.0))/Data.ATLAS.get_size())
    rear_uv.append((Vector2(rect.position)+p)/Data.ATLAS.get_size())
   quad(tool,front,uv)
   quad(shell,[back[3],back[2],back[1],back[0]],[rear_uv[3],rear_uv[2],rear_uv[1],rear_uv[0]])
   for edge in 4:
    var direction:Vector2i=[Vector2i.UP,Vector2i.RIGHT,Vector2i.DOWN,Vector2i.LEFT][edge]
    var neighbor=pixel+direction
    if plate(parts,rect,neighbor)==part:continue
    var next=(edge+1)%4
    quad(shell,[front[edge],back[edge],back[next],front[next]],[uv[edge],uv[edge],uv[next],uv[next]])
 # A shared round primitive keeps the recovered thin shaft visible from side views.
 var lance:Dictionary=Data.LANCES[str(serial)]
 var a=point(Vector2(lance.top[0],lance.top[1]),row,0,grip_offset)
 var b=point(Vector2(lance.bottom[0],lance.bottom[1]),row,0,grip_offset)
 Parts.prepare_primitives()
 var rod=SurfaceTool.new();rod.begin(Mesh.PRIMITIVE_TRIANGLES);Parts.rod(rod,a,b,lance.radius)
 var rod_arrays=rod.commit().surface_get_arrays(0);var indices=rod_arrays[Mesh.ARRAY_INDEX]
 for i in (indices if indices!=null and not indices.is_empty() else range(rod_arrays[Mesh.ARRAY_VERTEX].size())):
  var p:Vector3=rod_arrays[Mesh.ARRAY_VERTEX][i]
  var t=clampf((p-a).dot(b-a)/(b-a).length_squared(),0,1)
  var paint_pixel=Vector2(lance.paint_top[0],lance.paint_top[1]).lerp(Vector2(lance.paint_bottom[0],lance.paint_bottom[1]),t)
  shell.set_color(Color(1,1,1,0));shell.set_normal(rod_arrays[Mesh.ARRAY_NORMAL][i])
  shell.set_uv((Vector2(rect.position)+paint_pixel)/Data.ATLAS.get_size());shell.add_vertex(p)
 var raw=tool.commit();var shell_raw=shell.commit()
 var core_turn=Transform3D(Basis(Vector3.UP,float(Data.CORE.views[str(serial)])),Vector3.ZERO)
 var bounds=raw.get_aabb().merge(shell_raw.get_aabb()).merge(core_turn*core().get_aabb());var fit=float(row[5])/bounds.size.y
 var pose=Transform3D(Basis.IDENTITY.scaled(Vector3.ONE*fit),Vector3.DOWN*bounds.position.y*fit)
 var fitted=SurfaceTool.new();fitted.begin(Mesh.PRIMITIVE_TRIANGLES)
 fitted.append_from(raw,0,pose)
 meshes[serial]=fitted.commit();meshes[serial].surface_set_material(0,Source.material(Data.ATLAS))
 var sides=SurfaceTool.new();sides.begin(Mesh.PRIMITIVE_TRIANGLES)
 sides.append_from(shell_raw,0,pose)
 meshes[serial].add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,sides.commit().surface_get_arrays(0))
 var paint:ShaderMaterial=Source.material(Data.SOLID).duplicate();paint.set_shader_parameter("alpha_cutout",false)
 meshes[serial].surface_set_material(1,paint)
 var core_pose=pose*core_turn
 var body=SurfaceTool.new();body.begin(Mesh.PRIMITIVE_TRIANGLES);body.append_from(core(),0,core_pose)
 meshes[serial].add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,body.commit().surface_get_arrays(0))
 var body_paint:ShaderMaterial=paint.duplicate()
 body_paint.set_shader_parameter("armor_source_views",true)
 body_paint.set_shader_parameter("armor_source_texture",Data.SOLID)
 body_paint.set_shader_parameter("armor_source_frame",core_pose.affine_inverse())
 body_paint.set_meta("armor_source_frame",core_pose.affine_inverse())
 var records=PackedVector4Array();var origins=PackedVector2Array()
 for view in [16193,16194,16195,16196]:
  var source_row:Array=Data.ARMOR[view];var source_rect:Rect2i=source_row[0]
  records.append(Vector4(source_rect.position.x,source_rect.position.y,source_rect.size.x,source_rect.size.y));origins.append(source_row[1])
 body_paint.set_shader_parameter("armor_source_rects",records);body_paint.set_shader_parameter("armor_source_origins",origins)
 meshes[serial].surface_set_material(2,body_paint)
 var shell_paint:ShaderMaterial=body_paint.duplicate();shell_paint.set_shader_parameter("armor_source_parts",true)
 meshes[serial].surface_set_material(1,shell_paint)
 meshes[serial].set_meta("sculpture_fit",pose)
 return meshes[serial]
