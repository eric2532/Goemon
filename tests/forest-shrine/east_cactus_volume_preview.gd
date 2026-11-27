extends "res://tests/forest-shrine/east_nature_preview.gd"
const Volume=preload("res://scripts/forest/forest_east_cactus_volume_prototype.gd")
func review_path()->String:return "res://build/Other Files/Asset Toolkit/East Gate Region/Visual Landmarks/Nature/Cactus Volume Prototype/"
func selected_ids()->Array:return ["11178"]
func page_capacity()->int:return 1
func additional_input_paths()->Array:return ["res://scripts/forest/forest_east_cactus_volume_prototype.gd",Volume.ROOT+"data.json"]
func asset_mesh(serial:int)->Mesh:return Volume.mesh(serial,Nature.Base.Art.data().graphics[str(serial)])
