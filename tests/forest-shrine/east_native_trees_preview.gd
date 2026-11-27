extends "res://tests/forest-shrine/east_nature_preview.gd"
const NativeTrees=preload("res://scripts/forest/forest_east_native_trees.gd")
func review_path()->String:return "res://build/Other Files/Asset Toolkit/East Gate Region/Visual Landmarks/Tree Families/Typed27/Asset Preview/"
func selected_ids()->Array:return NativeTrees.data().graphics.keys()
func additional_input_paths()->Array:
 var paths=["res://scripts/forest/forest_east_native_trees.gd",NativeTrees.ROOT+"data.json","res://scripts/forest/forest_wind_meadow_assets.gd","res://scripts/forest/wind_meadow_foliage.gdshader","res://scripts/forest/forest_falan_proportions.gd"]
 for master:Dictionary in NativeTrees.data().masters.values():
  for path:String in master.source_pins:paths.append("res://"+path)
 return paths
func asset_mesh(serial:int)->Mesh:return NativeTrees.mesh(serial,Nature.Base.Art.data().graphics[str(serial)])
