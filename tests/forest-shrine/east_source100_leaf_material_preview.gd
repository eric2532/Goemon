extends "res://tests/forest-shrine/east_source100_tree_volume_close.gd"
const Leaf=preload("res://tests/forest-shrine/east_source100_leaf_material_candidate.gd")
func selected_graphics()->Array:return [10074]
func output_path()->String:return Leaf.ROOT
func candidate_mesh(serial:int)->Mesh:return Leaf.mesh(serial)
func candidate_caption(serial:int)->String:return "Native10074 | One unchanged whole canopy; native leaf-edge material/alpha trial"
func extra_sources()->Array:return ["res://tests/forest-shrine/east_source100_leaf_material_candidate.gd","res://tests/forest-shrine/east_source100_whole_canopy_candidate.gd",Leaf.ROOT+"native-leaf-edge-32.png","res://assets/models/environments/wind_meadow/crossgate_flora/cg_woodland.glb","res://assets/models/environments/wind_meadow/crossgate_flora/cg_woodland_cg_woodland.png","res://scripts/forest/wind_meadow_foliage.gdshader"]
func candidate_metrics(mesh:Mesh)->Dictionary:return {"material_only":true,"whole_master_uniform_scale":mesh.get_meta("whole_master_uniform_scale"),"leaf_crop":mesh.get_meta("leaf_crop"),"leaf_alpha_coverage":mesh.get_meta("leaf_alpha_coverage"),"tint":var_to_str(mesh.get_meta("native_leaf_tint")),"wood_junction_world":var_to_str(mesh.get_meta("wood_junction_world")),"world_canopy_no_extra_y_scale":true}
