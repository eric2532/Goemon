extends "res://tests/forest-shrine/east_root_core_asset_review.gd"
const Sculpt=preload("res://scripts/forest/forest_east_root_sculpt_prototype.gd")
func review_path()->String:return "res://build/Other Files/Asset Toolkit/East Gate Region/Visual Landmarks/Ancient Root Rounded Source Contour/"
func root_mesh()->Mesh:return Sculpt.mesh()
func input_path()->String:return "res://scripts/forest/forest_east_root_sculpt_prototype.gd"
func input_paths()->Array:
 return super.input_paths()+[Sculpt.ROOT+"data.json",Sculpt.ROOT+"independent-back.png","res://scripts/forest/forest_east_root_compounds.gd"]
