extends "res://tests/forest-shrine/east_cactus_volume_preview.gd"
func review_path()->String:return "res://build/Other Files/Asset Toolkit/East Gate Region/Visual Landmarks/Nature/Cactus Solid Parts/"
func asset_mesh(serial:int)->Mesh:return Volume.solid_mesh(serial,Nature.Base.Art.data().graphics[str(serial)])
