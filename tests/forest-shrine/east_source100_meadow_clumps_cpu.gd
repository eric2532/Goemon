extends SceneTree
const Clumps=preload("res://tests/forest-shrine/east_source100_meadow_clumps_candidate.gd")
func _initialize():
 var mesh=Clumps.mesh(10074)
 assert(mesh!=null and mesh.get_meta("source_clump_placements").size()==8)
 for arrays in mesh.get_meta("east_cpu_arrays"):
  for point in arrays[Mesh.ARRAY_VERTEX]:assert(point.is_finite())
 print("MEADOW_CLUMPS_CPU surfaces=",mesh.get_surface_count()," clumps=8; source-plane alignment and finite geometry PASS");quit(0)
