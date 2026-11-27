extends "res://tests/forest-shrine/east_nature_preview.gd"
func review_path()->String:return "res://build/Other Files/Asset Toolkit/East Gate Region/Visual Landmarks/Tree Families/Crown Profiles/"
func selected_ids()->Array:return ["1233070","1233071","1233072","1233073","1233074","1233075","1233076","1233077","1233078","1233079","1233210"]
func asset_mesh(serial:int)->Mesh:return Nature.Base.mesh(0,serial,Nature.Base.Art.data().graphics[str(serial)])
