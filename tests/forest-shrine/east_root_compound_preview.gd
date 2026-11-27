extends "res://tests/forest-shrine/east_nature_preview.gd"
const RootTree=preload("res://scripts/forest/forest_east_root_compounds.gd")
func review_path()->String:return "res://build/Other Files/Asset Toolkit/East Gate Region/Visual Landmarks/Ancient Root Compounds/Rooted Rear/"
func selected_ids()->Array:return ["11699"]
func additional_input_paths()->Array:return ["res://scripts/forest/forest_east_root_compounds.gd",RootTree.ROOT+"data.json"]
func asset_mesh(_serial:int)->Mesh:return RootTree.mesh()
