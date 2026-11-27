extends "res://tests/forest-shrine/east_root_core_asset_review.gd"
const Volume=preload("res://scripts/forest/forest_east_root_volume_prototype.gd")
func review_path()->String:return "res://build/Other Files/Asset Toolkit/East Gate Region/Visual Landmarks/Ancient Root Continuous Volume/"
func root_mesh()->Mesh:return Volume.mesh()
func input_path()->String:return "res://scripts/forest/forest_east_root_volume_prototype.gd"
