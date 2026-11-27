extends "res://tests/forest-shrine/east_source100_tree_volume_close.gd"
const Whole=preload("res://tests/forest-shrine/east_source100_whole_canopy_candidate.gd")
func selected_graphics()->Array:return [10074]
func output_path()->String:return Whole.ROOT
func candidate_mesh(serial:int)->Mesh:return Whole.mesh(serial)
func candidate_caption(serial:int)->String:return "Native "+str(serial)+" reference | Whole Meadow canopy; inferred leaves, source wood/anchor/palette"
func extra_sources()->Array:return ["res://tests/forest-shrine/east_source100_whole_canopy_candidate.gd","res://assets/models/environments/wind_meadow/crossgate_flora/cg_woodland.glb","res://assets/models/environments/wind_meadow/crossgate_flora/cg_woodland_cg_woodland.png","res://scripts/forest/wind_meadow_foliage.gdshader"]
func candidate_metrics(mesh:Mesh)->Dictionary:return {"whole_master_uniform_scale":mesh.get_meta("whole_master_uniform_scale"),"source_width_world":mesh.get_meta("source_width_world"),"source_junction_pixel":var_to_str(mesh.get_meta("source_junction_pixel")),"wood_junction_world":var_to_str(mesh.get_meta("wood_junction_world")),"inferred_canopy_overlap":mesh.get_meta("inferred_canopy_overlap"),"world_canopy_no_extra_y_scale":true,"height_frames":mesh.get_meta("height_frames")}
