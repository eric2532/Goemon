extends SceneTree
const Civic=preload("res://scripts/forest/forest_falan_civic_exterior.gd")
const OUT="res://build/Other Files/Asset Toolkit/Falan City Reconstruction/Visual Continuation/"
func _initialize():
 create_timer(180).timeout.connect(func():printerr("FALAN_CATHEDRAL_BATCH_TIMEOUT");quit(1))
 run.call_deferred()
func run():
 var holder=Node3D.new();root.add_child(holder)
 var spec:Array=Civic.SHELLS[Vector2i(-52,2)]
 var authored=Civic.build(holder,Vector3.ZERO,spec)
 var batched=Civic.build(holder,Vector3.ZERO,spec,true)
 var a=signature(authored);var b=signature(batched)
 var maximum=[0.0,0.0,0.0,0.0,0.0];var vertices=0
 assert(a.size()==b.size(),"Preserve every material and shadow setting")
 for key in a:
  assert(b.has(key),"Preserve original material instances")
  var first:Array=a[key];var second:Array=b[key]
  assert(first[0].size()==second[0].size(),"Preserve every oriented triangle")
  vertices+=first[0].size()
  for field in 5:
   for i in first[field].size():
    var error=first[field][i].distance_to(second[field][i]) if field<4 else absf(first[field][i].r-second[field][i].r)+absf(first[field][i].g-second[field][i].g)+absf(first[field][i].b-second[field][i].b)+absf(first[field][i].a-second[field][i].a)
    maximum[field]=maxf(maximum[field],error)
 print("BATCH_MAXIMUM_ERRORS position/normal/uv/uv2/color=",maximum)
 # ArrayMesh packs normals; compare values rather than hashes near rounding boundaries.
 if maximum[0]>.001 or maximum[1]>.001 or maximum[2]>.0001 or maximum[3]>.0001 or maximum[4]>.0001:
  printerr("FALAN_CATHEDRAL_BATCH_GEOMETRY_FAIL");quit(1);return
 var before=authored.find_children("*","GeometryInstance3D",true,false).size()
 var after=batched.find_children("*","GeometryInstance3D",true,false).size()
 assert(after<before/10,"Cathedral should retain detail with fewer render nodes")
 var again=Civic.build(holder,Vector3.ZERO,spec,true)
 var first=batched.find_children("*","MeshInstance3D",true,false)
 var second=again.find_children("*","MeshInstance3D",true,false)
 assert(first.size()==second.size())
 for i in first.size():assert(is_same(first[i].mesh,second[i].mesh),"City returns reuse immutable cathedral meshes")
 var data={"authoring_render_nodes":before,"batched_render_nodes":after,"oriented_triangles":vertices/3,"maximum_errors":maximum,"geometry_normals_uv_materials_preserved":true,"repeated_meshes_reused":true}
 var file=FileAccess.open(OUT+"cathedral-batch.json",FileAccess.WRITE);file.store_string(JSON.stringify(data,"  "));file.close()
 print("FALAN_CATHEDRAL_BATCH_RESULT ",JSON.stringify(data))
 holder.queue_free();await process_frame;quit()
func signature(model:Node3D)->Dictionary:
 var result={};var inverse=model.global_transform.affine_inverse()
 for node in model.find_children("*","GeometryInstance3D",true,false):
  if node is MeshInstance3D:add(result,node.mesh,node.material_override,node,inverse*node.global_transform)
  elif node is MultiMeshInstance3D:
   for i in node.multimesh.instance_count:add(result,node.multimesh.mesh,node.material_override,node,inverse*node.global_transform*node.multimesh.get_instance_transform(i))
 return result
func add(result:Dictionary,mesh:Mesh,override:Material,owner:GeometryInstance3D,pose:Transform3D):
 for part in mesh.get_surface_count():
  var material:Material=override
  if material==null and owner is MeshInstance3D:material=owner.get_surface_override_material(part)
  if material==null:material=mesh.surface_get_material(part)
  var key=[material.get_instance_id(),owner.cast_shadow]
  var row:Array=result.get(key,[PackedVector3Array(),PackedVector3Array(),PackedVector2Array(),PackedVector2Array(),PackedColorArray()])
  var points:PackedVector3Array=row[0];var normals:PackedVector3Array=row[1];var uvs:PackedVector2Array=row[2];var uv2s:PackedVector2Array=row[3];var colors:PackedColorArray=row[4]
  var a=mesh.surface_get_arrays(part);var vertices:PackedVector3Array=a[Mesh.ARRAY_VERTEX];var indices=a[Mesh.ARRAY_INDEX]
  var order=indices if indices!=null and not indices.is_empty() else range(vertices.size())
  var normal=pose.basis.inverse().transposed()
  for k in order:
   points.append(pose*vertices[k]);normals.append((normal*a[Mesh.ARRAY_NORMAL][k]).normalized())
   uvs.append(Vector2.ZERO if a[Mesh.ARRAY_TEX_UV]==null or a[Mesh.ARRAY_TEX_UV].is_empty() else a[Mesh.ARRAY_TEX_UV][k])
   uv2s.append(Vector2.ZERO if a[Mesh.ARRAY_TEX_UV2]==null or a[Mesh.ARRAY_TEX_UV2].is_empty() else a[Mesh.ARRAY_TEX_UV2][k])
   colors.append(Color.WHITE if a[Mesh.ARRAY_COLOR]==null or a[Mesh.ARRAY_COLOR].is_empty() else a[Mesh.ARRAY_COLOR][k])
  result[key]=[points,normals,uvs,uv2s,colors]
