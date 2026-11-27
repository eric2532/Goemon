extends SceneTree
const Leaf=preload("res://tests/forest-shrine/east_source100_leaf_material_candidate.gd")
func _initialize():
 var original:Mesh=Leaf.Whole.mesh(10074);var candidate:Mesh=Leaf.mesh(10074)
 assert(original!=candidate and candidate.get_surface_count()==original.get_surface_count())
 assert(candidate.get_aabb()==original.get_aabb())
 var a:Array=original.get_meta("east_cpu_arrays");var b:Array=candidate.get_meta("east_cpu_arrays")
 for i in a.size():
  for channel in Mesh.ARRAY_MAX:assert(a[i][channel]==b[i][channel])
  if i<a.size()-1:assert(original.surface_get_material(i)==candidate.surface_get_material(i))
 var paint:ShaderMaterial=candidate.surface_get_material(candidate.get_surface_count()-1)
 assert(paint!=original.surface_get_material(original.get_surface_count()-1))
 assert(paint.shader==original.surface_get_material(original.get_surface_count()-1).shader)
 assert(paint.get_shader_parameter("source_cutout")==true)
 print("LEAF_MATERIAL_CPU exact_geometry_uv_channels=",a.size()*Mesh.ARRAY_MAX," unchanged_wood_surfaces=",a.size()-1," alpha=",candidate.get_meta("leaf_alpha_coverage"));quit(0)
