extends "res://tests/forest-shrine/east_root_core_asset_review.gd"
const Master=preload("res://scripts/forest/forest_east_root_master_study.gd")
func review_path()->String:return "res://build/Other Files/Asset Toolkit/East Gate Region/Visual Landmarks/Ancient Root Whole Master/"
func root_mesh()->Mesh:return Master.mesh()
func input_path()->String:return "res://scripts/forest/forest_east_root_master_study.gd"
