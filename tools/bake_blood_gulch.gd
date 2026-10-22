extends SceneTree
## Bake shared adapted ground; native boundary cliffs never enter nav metadata.
func _initialize():
 var path=""
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--input="):path=arg.trim_prefix("--input=")
 assert(not path.is_empty())
 var data=JSON.parse_string(FileAccess.get_file_as_string(path))
 var mesh=_mesh(data.groups,false)
 assert(ResourceSaver.save(mesh,"res://assets/maps/blood_gulch/terrain.res",ResourceSaver.FLAG_COMPRESS)==OK)
 var collision=mesh.create_trimesh_shape();collision.backface_collision=true
 assert(ResourceSaver.save(collision,"res://assets/maps/blood_gulch/collision.res",ResourceSaver.FLAG_COMPRESS)==OK)
 var cliffs=_mesh(data.cliffs,true)
 assert(ResourceSaver.save(cliffs,"res://assets/maps/blood_gulch/cliffs.res",ResourceSaver.FLAG_COMPRESS)==OK)
 var field=Resource.new()
 field.set_meta("width",int(data.width));field.set_meta("spacing",float(data.spacing));field.set_meta("origin",Vector2(data.origin[0],data.origin[1]))
 field.set_meta("heights",PackedFloat32Array(data.heights));field.set_meta("covered",PackedByteArray(data.covered));field.set_meta("bridges",PackedByteArray(data.bridges))
 assert(ResourceSaver.save(field,"res://assets/maps/blood_gulch/surface.res",ResourceSaver.FLAG_COMPRESS)==OK)
 print("BLOOD_GULCH_TERRAIN_RESOURCES_BAKED ground_surfaces=",mesh.get_surface_count()," cliff_surfaces=",cliffs.get_surface_count());quit()

func _mesh(groups:Array,is_cliff:bool)->ArrayMesh:
 var mesh=ArrayMesh.new()
 for group in groups:
  var vertices=PackedVector3Array();var uvs=PackedVector2Array();var normals=PackedVector3Array()
  for i in group.points.size():
   var p=group.points[i];vertices.append(Vector3(p[0],p[1],p[2]));var uv=group.uv[i];uvs.append(Vector2(uv[0],uv[1]));normals.append(Vector3.ZERO)
  # Smooth only coincident native/source points, preserving intended geometric
  # shapes. Face winding is clockwise in both original Xbox BSP and grid.
  var sums={}
  for at in range(0,vertices.size(),3):
   var normal=-(vertices[at+1]-vertices[at]).cross(vertices[at+2]-vertices[at]).normalized()
   for offset in 3:
    var key=vertices[at+offset].snapped(Vector3(.0001,.0001,.0001));sums[key]=sums.get(key,Vector3.ZERO)+normal
  for i in vertices.size():normals[i]=sums[vertices[i].snapped(Vector3(.0001,.0001,.0001))].normalized()
  var arrays=[];arrays.resize(Mesh.ARRAY_MAX);arrays[Mesh.ARRAY_VERTEX]=vertices;arrays[Mesh.ARRAY_TEX_UV]=uvs;arrays[Mesh.ARRAY_NORMAL]=normals
  mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
  var mat=ShaderMaterial.new();mat.shader=load("res://scripts/forest/blood_gulch_surface.gdshader")
  assert(mat.shader!=null)
  mat.set_shader_parameter("albedo_texture",load("res://assets/maps/blood_gulch/"+group.image));mat.set_shader_parameter("is_cliff",is_cliff)
  if group.get("detail_image"):
   mat.set_shader_parameter("detail_texture",load("res://assets/maps/blood_gulch/"+group.detail_image));mat.set_shader_parameter("use_detail",true);mat.set_shader_parameter("detail_scale",float(group.detail_scale))
  if group.get("grass_image"):
   mat.set_shader_parameter("grass_texture",load("res://assets/maps/blood_gulch/"+group.grass_image));mat.set_shader_parameter("use_ground_blend",true);mat.set_shader_parameter("grass_scale",float(group.grass_scale))
  mesh.surface_set_material(mesh.get_surface_count()-1,mat)
 return mesh
