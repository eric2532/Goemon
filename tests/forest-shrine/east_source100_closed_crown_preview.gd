extends "res://tests/forest-shrine/east_source100_tree_volume_close.gd"
const Closed=preload("res://tests/forest-shrine/east_source100_closed_crown_candidate.gd")
func selected_graphics()->Array:return [10074]
func output_path()->String:return Closed.ROOT
func candidate_mesh(serial:int)->Mesh:return Closed.mesh(serial)
func extra_sources()->Array:return ["res://tests/forest-shrine/east_source100_closed_crown_candidate.gd",Closed.ROOT+"leaf-grain.png"]
func candidate_metrics(mesh:Mesh)->Dictionary:return {"source_points":mesh.get_meta("source_points"),"closed_rim_edges":mesh.get_meta("closed_rim_edges"),"inferred_half_depth":mesh.get_meta("max_inferred_half_depth"),"no_card_cloud":true,"no_camera_dependent_discard":true}
