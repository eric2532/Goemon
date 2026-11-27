extends SceneTree
const Whole=preload("res://tests/forest-shrine/east_source100_whole_canopy_candidate.gd")
func _initialize():
 var mesh=Whole.mesh(10074)
 assert(mesh!=null and mesh.get_meta("world_canopy_no_extra_y_scale"))
 for arrays in mesh.get_meta("east_cpu_arrays"):
  for point in arrays[Mesh.ARRAY_VERTEX]:assert(point.is_finite())
 print("WHOLE_CANOPY_CPU surfaces=",mesh.get_surface_count()," uniform_scale=",mesh.get_meta("whole_master_uniform_scale")," junction=",mesh.get_meta("wood_junction_world"));quit(0)
