extends "res://tests/forest-shrine/east_nature_preview.gd"
const Shrine=preload("res://scripts/forest/forest_east_living_paint_prototype.gd")
func review_path()->String:return "res://build/Other Files/Asset Toolkit/East Gate Region/Visual Landmarks/Living Paint Prototype/Rooted Assets/"
func selected_ids()->Array:return ["1230040"]
func additional_input_paths()->Array:return ["res://scripts/forest/forest_east_living_paint_prototype.gd",Shrine.ROOT+"data.json"]
func asset_mesh(_serial:int)->Mesh:return Shrine.mesh()
