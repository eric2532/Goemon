extends "res://tests/forest-shrine/east_nature_preview.gd"
## One bounded desktop job; each private form gets its own larger source/reverse pair.
const RootTree=preload("res://scripts/forest/forest_east_root_compounds.gd")
const Cactus=preload("res://scripts/forest/forest_east_round_cactus.gd")
const Shrine=preload("res://scripts/forest/forest_east_living_paint_prototype.gd")
func review_path()->String:return "res://build/Other Files/Asset Toolkit/East Gate Region/Visual Landmarks/Private Nature Final Assets/"
func page_capacity()->int:return 1
func selected_ids()->Array:return ["11699","11746","11782","11785","11786","1230040"]
func additional_input_paths()->Array:return [
 "res://scripts/forest/forest_east_root_compounds.gd",RootTree.ROOT+"data.json",
 "res://scripts/forest/forest_east_round_cactus.gd",Cactus.ROOT+"data.json",
 "res://scripts/forest/forest_east_living_paint_prototype.gd",Shrine.ROOT+"data.json",
]
func asset_mesh(serial:int)->Mesh:
 if serial==11699:return RootTree.mesh()
 if serial==1230040:return Shrine.mesh()
 return Cactus.mesh(serial,Nature.Base.Art.data().graphics[str(serial)])
