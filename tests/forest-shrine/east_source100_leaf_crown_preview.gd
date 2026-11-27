extends "res://tests/forest-shrine/east_source100_tree_volume_close.gd"
const Leaves=preload("res://tests/forest-shrine/east_source100_leaf_crown_candidate.gd")
func selected_graphics()->Array:return [10074]
func output_path()->String:return Leaves.ROOT
func candidate_mesh(serial:int)->Mesh:return Leaves.mesh(serial)
func extra_sources()->Array:return ["res://tests/forest-shrine/east_source100_leaf_crown_candidate.gd",Leaves.ROOT+"leaf-paint.png"]
func candidate_metrics(mesh:Mesh)->Dictionary:return {"source_leaf_samples":mesh.get_meta("source_leaf_samples"),"reused_leaf_quads":mesh.get_meta("reused_leaf_quads"),"leaf_sample_projection_error":mesh.get_meta("leaf_sample_projection_error"),"no_source_photo_overlay":true,"uv_and_index_preserved":true,"leaf_only_bottom":235}
