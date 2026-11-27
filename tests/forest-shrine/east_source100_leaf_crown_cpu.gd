extends SceneTree
const Leaves=preload("res://tests/forest-shrine/east_source100_leaf_crown_candidate.gd")
func _initialize():
 var mesh=Leaves.mesh(10074)
 if mesh==null:push_error("Leaf crown construction failed");quit(1);return
 print("LEAF_CROWN_CPU surfaces=",mesh.get_surface_count()," quads=",mesh.get_meta("reused_leaf_quads")," projection_error=",mesh.get_meta("leaf_sample_projection_error"));quit(0)
