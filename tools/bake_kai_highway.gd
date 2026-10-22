extends SceneTree
func _initialize():
 var path=""
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--input="):path=arg.trim_prefix("--input=")
 assert(not path.is_empty())
 var data=JSON.parse_string(FileAccess.get_file_as_string(path));var mesh=ArrayMesh.new()
 for group in data.groups:
  var vertices=PackedVector3Array();var uvs=PackedVector2Array();var normals=PackedVector3Array()
  for i in group.points.size():
   var p=group.points[i];vertices.append(Vector3(p[0],p[1],p[2]));var uv=group.uv[i];uvs.append(Vector2(uv[0],uv[1]));normals.append(Vector3.UP)
  var arrays=[];arrays.resize(Mesh.ARRAY_MAX);arrays[Mesh.ARRAY_VERTEX]=vertices;arrays[Mesh.ARRAY_TEX_UV]=uvs;arrays[Mesh.ARRAY_NORMAL]=normals
  mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
  var mat=ShaderMaterial.new();mat.shader=load("res://scripts/forest/kai_highway_surface.gdshader")
  mat.set_shader_parameter("albedo_texture",load("res://assets/maps/kai_highway/"+group.image));mesh.surface_set_material(mesh.get_surface_count()-1,mat)
 assert(ResourceSaver.save(mesh,"res://assets/maps/kai_highway/terrain.res",ResourceSaver.FLAG_COMPRESS)==OK)
 var collision=mesh.create_trimesh_shape();collision.backface_collision=true
 assert(ResourceSaver.save(collision,"res://assets/maps/kai_highway/collision.res",ResourceSaver.FLAG_COMPRESS)==OK)
 var field=Resource.new();field.set_meta("width",int(data.width));field.set_meta("spacing",float(data.spacing));field.set_meta("heights",PackedFloat32Array(data.heights));field.set_meta("covered",PackedByteArray(data.covered));field.set_meta("bridges",PackedByteArray(data.bridges))
 assert(ResourceSaver.save(field,"res://assets/maps/kai_highway/surface.res",ResourceSaver.FLAG_COMPRESS)==OK)
 print("KAI_TERRAIN_RESOURCES_BAKED");quit()
