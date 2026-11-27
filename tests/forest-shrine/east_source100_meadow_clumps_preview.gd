extends "res://tests/forest-shrine/east_source100_tree_volume_close.gd"
const Clumps=preload("res://tests/forest-shrine/east_source100_meadow_clumps_candidate.gd")
func selected_graphics()->Array:return [10074]
func output_path()->String:return Clumps.ROOT
func candidate_mesh(serial:int)->Mesh:return Clumps.mesh(serial)
func extra_sources()->Array:return ["res://tests/forest-shrine/east_source100_meadow_clumps_candidate.gd","res://tests/forest-shrine/east_source100_cluster_tree_candidate.gd","res://assets/models/environments/wind_meadow/crossgate_flora/cg_woodland.glb","res://assets/models/environments/wind_meadow/crossgate_flora/cg_woodland_cg_woodland.png","res://scripts/forest/wind_meadow_foliage.gdshader"]
func candidate_metrics(mesh:Mesh)->Dictionary:return {"clump_placements":mesh.get_meta("source_clump_placements"),"native_palette_gain":var_to_str(mesh.get_meta("native_palette_gain")),"existing_leaf_master":mesh.get_meta("existing_leaf_master"),"no_native_photo_skin":true}
