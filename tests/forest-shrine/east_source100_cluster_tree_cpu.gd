extends SceneTree
const Candidate=preload("res://tests/forest-shrine/east_source100_cluster_tree_candidate.gd")
func _initialize():
 var mesh=Candidate.mesh(10074)
 if mesh==null:quit(1);return
 var vertices=0
 for arrays:Array in mesh.get_meta("east_cpu_arrays"):
  for p:Vector3 in arrays[Mesh.ARRAY_VERTEX]:
   if not p.is_finite():push_error("Nonfinite cluster vertex");quit(1);return
   vertices+=1
 print("CLUSTER_CPU vertices=",vertices," surfaces=",mesh.get_surface_count()," front_triangles=",mesh.get_meta("native_front_triangles"));quit(0)
