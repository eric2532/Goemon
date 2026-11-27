extends "res://tests/forest-shrine/east_source100_tree_volume_close.gd"
const Cluster=preload("res://tests/forest-shrine/east_source100_cluster_tree_candidate.gd")
func selected_graphics()->Array:return [10074]
func output_path()->String:return Cluster.ROOT
func candidate_mesh(serial:int)->Mesh:return Cluster.mesh(serial)
func extra_sources()->Array:return ["res://tests/forest-shrine/east_source100_cluster_tree_candidate.gd",Cluster.ROOT+"10074-leaves.png"]
func candidate_metrics(mesh:Mesh)->Dictionary:return {"source_lobe_rectangles":mesh.get_meta("source_lobe_rectangles"),"native_front_triangles":mesh.get_meta("native_front_triangles"),"leaf_only_bottom":mesh.get_meta("leaf_only_bottom"),"inferred_lobe_partition":true,"natural_master_depth_retained":true,"no_whole_front_leaf_plane":true}
