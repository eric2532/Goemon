extends SceneTree
const Closed=preload("res://tests/forest-shrine/east_source100_closed_crown_candidate.gd")
func _initialize():
 var mesh=Closed.mesh(10074)
 assert(mesh!=null and mesh.get_meta("closed_rim_edges")>0)
 for arrays in mesh.get_meta("east_cpu_arrays"):
  for point in arrays[Mesh.ARRAY_VERTEX]:assert(point.is_finite())
 print("CLOSED_CROWN_CPU surfaces=",mesh.get_surface_count()," source_points=",mesh.get_meta("source_points")," rim=",mesh.get_meta("closed_rim_edges"));quit(0)
