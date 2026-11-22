extends RefCounted
## Setup-only source-camera calibration. Existing scenery owns placement and navigation.
# shortcut: Native bounds do not determine every roof contour or hidden depth; refine them when additional source views are available.
const Source=preload("res://scripts/forest/forest_coastal_mesh.gd")
const References=preload("res://assets/maps/falan/city_proportion_references.gd")
const Data=preload("res://assets/maps/falan/city_proportion_fit.gd")
const HORIZONTAL=32.0/3.0
const FLOOR=8.0
const VERTICAL=sqrt(2.0*(HORIZONTAL*HORIZONTAL-FLOOR*FLOOR))
static var enabled=true

static func project(p:Vector3)->Vector2:return Vector2((p.x-p.z)*HORIZONTAL,(p.x+p.z)*FLOOR-p.y*VERTICAL)

static func mesh_points(mesh:Mesh,pose:Transform3D=Transform3D.IDENTITY)->Array[Vector3]:
 var result:Array[Vector3]=[]
 for part in mesh.get_surface_count():
  for p:Vector3 in mesh.surface_get_arrays(part)[Mesh.ARRAY_VERTEX]:result.append(pose*p)
 return result

static func node_points(root:Node3D)->Array[Vector3]:
 var result:Array[Vector3]=[]
 var owners:Array[Node]=[root];owners.append_array(root.find_children("*","Node3D",true,false))
 for owner in owners:
  var box_pose:Transform3D=root.global_transform.affine_inverse()*owner.global_transform*owner.get_meta("source_box_fit",Transform3D.IDENTITY)
  for p:Vector3 in owner.get_meta("source_box_points",[]):result.append(box_pose*p)
 for child in root.find_children("*","MeshInstance3D",true,false):result.append_array(mesh_points(child.mesh,root.global_transform.affine_inverse()*child.global_transform))
 return result

static func projected_bounds(points:Array[Vector3],pose:Transform3D=Transform3D.IDENTITY)->Rect2:
 assert(not points.is_empty())
 var rect=Rect2(project(pose*points[0]),Vector2.ZERO)
 for p in points:rect=rect.expand(project(pose*p))
 return rect

static func measure(points:Array[Vector3],key:String,turn:Basis,target:Rect2=Rect2())->Transform3D:
 var world:Array[Vector3]=[]
 for p in points:world.append(turn*p)
 var before=projected_bounds(world)
 if target.size==Vector2.ZERO:target=References.RECTS[key]
 assert(before.size.x>0 and target.size.x>0 and target.size.y>0,"Source dimensions must be positive")
 var scale_xz=target.size.x/before.size.x
 var dx=target.get_center().x-before.get_center().x*scale_xz
 var lines:Array[Vector2]=[]
 for p in world:lines.append(Vector2((p.x+p.z)*FLOOR*scale_xz,p.y*VERTICAL))
 var minimum_y=INF;var maximum_y=-INF
 for p in world:minimum_y=minf(minimum_y,p.y);maximum_y=maxf(maximum_y,p.y)
 assert(maximum_y-minimum_y>.001,"A building must have vertical volume")
 var low=0.0;var high=1.0
 while vertical_bounds(lines,high).y-vertical_bounds(lines,high).x<target.size.y:
  high*=2
  assert(high<1024,"Source proportions exceed the supported city scale")
 for i in 48:
  var middle=(low+high)*.5;var bounds=vertical_bounds(lines,middle)
  if bounds.y-bounds.x<target.size.y:low=middle
  else:high=middle
 var scale_y=(low+high)*.5
 var dy=target.position.y-vertical_bounds(lines,scale_y).x
 var shift=Vector3(dx/(2*HORIZONTAL)+dy/(2*FLOOR),0,-dx/(2*HORIZONTAL)+dy/(2*FLOOR))
 assert(scale_y>0 and is_finite(scale_y),"A measured building must have positive physical height")
 return Transform3D(Basis.IDENTITY.scaled(Vector3(scale_xz,scale_y,scale_xz)),turn.inverse()*shift)

static func vertical_bounds(lines:Array[Vector2],scale_y:float)->Vector2:
 var minimum=INF;var maximum=-INF
 for line in lines:
  var y=line.x-line.y*scale_y;minimum=minf(minimum,y);maximum=maxf(maximum,y)
 return Vector2(minimum,maximum)

static func fitted(mesh:Mesh,key:String)->Mesh:
 if not enabled or not Data.FITS.has(key):return mesh
 var pose:Transform3D=Data.FITS[key];var result=ArrayMesh.new();var normal=pose.basis.inverse().transposed()
 for part in mesh.get_surface_count():
  var arrays=mesh.surface_get_arrays(part);var vertices:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX];var normals:PackedVector3Array=arrays[Mesh.ARRAY_NORMAL]
  for i in vertices.size():vertices[i]=pose*vertices[i];normals[i]=(normal*normals[i]).normalized()
  arrays[Mesh.ARRAY_VERTEX]=vertices;arrays[Mesh.ARRAY_NORMAL]=normals
  result.add_surface_from_arrays(mesh.surface_get_primitive_type(part),arrays);result.surface_set_material(part,mesh.surface_get_material(part))
 return result

static func apply(root:Node3D,key:String):
 root.set_meta("source_proportion_key",key)
 if not enabled or not Data.FITS.has(key):return
 var pose:Transform3D=Data.FITS[key]
 root.set_meta("source_box_fit",pose)
 for child in root.get_children():
  if child is Node3D:child.transform=pose*child.transform

static func height(key:String,fallback:float)->float:return Data.HEIGHTS.get(key,fallback) if enabled else fallback

static func material(key:String,frame:Transform3D,local:bool,atlas:Texture2D,rect:Rect2,mask:Texture2D=null,fallback:Color=Color("bcb095"),original:ShaderMaterial=null,reference:Rect2=Rect2())->ShaderMaterial:
 var paint:ShaderMaterial=Source.material(atlas).duplicate() if original==null else original.duplicate()
 paint.set_shader_parameter("falan_source_texture",atlas)
 paint.set_shader_parameter("falan_source_restore_uv",original!=null)
 paint.set_shader_parameter("falan_source_mask",References.MASK if mask==null else mask)
 paint.set_shader_parameter("falan_source_fallback",fallback)
 paint.set_shader_parameter("falan_source_projection",true);paint.set_shader_parameter("falan_source_local",local)
 paint.set_shader_parameter("falan_source_frame",frame)
 if reference.size==Vector2.ZERO:reference=References.RECTS[key]
 paint.set_shader_parameter("falan_source_rect",Vector4(reference.position.x,reference.position.y,reference.size.x,reference.size.y))
 paint.set_shader_parameter("falan_source_paint",Vector4(rect.position.x,rect.position.y,rect.size.x,rect.size.y))
 paint.set_shader_parameter("alpha_cutout",false);paint.set_shader_parameter("original_palette",false)
 return paint

static func matches(mesh:Mesh,key:String,yaw:float)->bool:
 var actual=projected_bounds(mesh_points(mesh),Transform3D(Basis(Vector3.UP,yaw),Vector3.ZERO))
 var target:Rect2=References.RECTS[key]
 return actual.position.distance_to(target.position)<.05 and actual.size.distance_to(target.size)<.05
