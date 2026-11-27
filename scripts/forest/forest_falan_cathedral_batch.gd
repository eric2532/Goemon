extends RefCounted
## Setup-only batches; the cathedral's authored pieces remain the editable source.
static var batches:Array=[]
static var box_points:Array=[]
static var source_nodes=0

static func restore(root:Node3D)->bool:
 if batches.is_empty():return false
 root.set_meta("source_box_points",box_points)
 root.set_meta("falan_batched_source_nodes",source_nodes)
 for row in batches:
  var node=Geo.mesh(root,row.mesh,Vector3.ZERO,row.material)
  node.name="CathedralMaterialBatch"
  node.cast_shadow=row.shadow
  if not row.feature.is_empty():node.set_meta("falan_source_feature",row.feature)
 return true

static func prepare(root:Node3D):
 assert(batches.is_empty(),"Prepare each immutable cathedral batch once")
 box_points=root.get_meta("source_box_points",[])
 var groups={};var inverse=root.global_transform.affine_inverse()
 for child in root.find_children("*","GeometryInstance3D",true,false):
  if child is MeshInstance3D:
   source_nodes+=1
   append(groups,child.mesh,child.material_override,child,inverse*child.global_transform)
  elif child is MultiMeshInstance3D:
   var multi:MultiMesh=child.multimesh
   assert(not multi.use_colors and not multi.use_custom_data,"Cathedral stone uses immutable transforms")
   for i in multi.instance_count:append(groups,multi.mesh,child.material_override,child,inverse*child.global_transform*multi.get_instance_transform(i))
 for row in groups.values():
  row.tool.index()
  batches.append({"mesh":row.tool.commit(),"material":row.material,"shadow":row.shadow,"feature":row.feature})
 for child in root.get_children():root.remove_child(child);child.queue_free()
 restore(root)

static func append(groups:Dictionary,mesh:Mesh,override:Material,owner:GeometryInstance3D,pose:Transform3D):
 for part in mesh.get_surface_count():
  var material:Material=override
  if material==null and owner is MeshInstance3D:material=owner.get_surface_override_material(part)
  if material==null:material=mesh.surface_get_material(part)
  var key=[material,owner.cast_shadow]
  if not groups.has(key):
   var tool=SurfaceTool.new();tool.begin(Mesh.PRIMITIVE_TRIANGLES)
   groups[key]={"tool":tool,"material":material,"shadow":owner.cast_shadow,"feature":""}
  var row:Dictionary=groups[key];var tool:SurfaceTool=row.tool
  if owner.has_meta("falan_source_feature"):row.feature=owner.get_meta("falan_source_feature")
  var arrays=mesh.surface_get_arrays(part)
  var points:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX];var normals:PackedVector3Array=arrays[Mesh.ARRAY_NORMAL]
  var indices=arrays[Mesh.ARRAY_INDEX];var uv=arrays[Mesh.ARRAY_TEX_UV];var uv2=arrays[Mesh.ARRAY_TEX_UV2];var colors=arrays[Mesh.ARRAY_COLOR]
  assert(normals.size()==points.size(),"Authored cathedral pieces need shading normals")
  var normal=pose.basis.inverse().transposed()
  for i in (indices if indices!=null and not indices.is_empty() else range(points.size())):
   tool.set_normal((normal*normals[i]).normalized())
   tool.set_uv(uv[i] if uv!=null and not uv.is_empty() else Vector2.ZERO)
   tool.set_uv2(uv2[i] if uv2!=null and not uv2.is_empty() else Vector2.ZERO)
   tool.set_color(colors[i] if colors!=null and not colors.is_empty() else Color.WHITE)
   tool.add_vertex(pose*points[i])
