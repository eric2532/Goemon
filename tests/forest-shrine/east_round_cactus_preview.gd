extends "res://tests/forest-shrine/east_nature_preview.gd"
const RoundCactus=preload("res://scripts/forest/forest_east_round_cactus.gd")
func review_path()->String:return "res://build/Other Files/Asset Toolkit/East Gate Region/Visual Landmarks/Nature/Round Prototype4 Attached/"
func selected_ids()->Array:return RoundCactus.data().graphics.keys()
func additional_input_paths()->Array:return ["res://scripts/forest/forest_east_round_cactus.gd",RoundCactus.ROOT+"data.json"]
func asset_mesh(serial:int)->Mesh:return RoundCactus.mesh(serial,Nature.Base.Art.data().graphics[str(serial)])
