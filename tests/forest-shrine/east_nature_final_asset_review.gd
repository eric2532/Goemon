extends "res://tests/forest-shrine/east_nature_preview.gd"
## Current76exact IDs: all27traced trees, all44cacti, all5large skeletons.
const NativeTrees=preload("res://scripts/forest/forest_east_native_trees.gd")
func review_path()->String:return "res://build/Other Files/Asset Toolkit/East Gate Region/Visual Landmarks/Nature/Final76/"
func selected_ids()->Array:
 var result:Array=NativeTrees.data().graphics.keys()
 for token in Nature.data().graphics:
  var row:Dictionary=Nature.data().graphics[token]
  if row.kind=="source_skeleton" or row.kind=="rounded_native_contour" and int(token) not in [11165,11167]:result.append(token)
 assert(result.size()==76)
 return result
func asset_mesh(serial:int)->Mesh:
 return NativeTrees.mesh(serial,Nature.Base.Art.data().graphics[str(serial)]) if NativeTrees.owns(serial) else Nature.mesh(serial,Nature.Base.Art.data().graphics[str(serial)])
func additional_input_paths()->Array:return ["res://scripts/forest/forest_east_native_trees.gd",NativeTrees.ROOT+"data.json"]
