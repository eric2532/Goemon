extends "res://tests/forest-shrine/east_private_compounds_actual_review.gd"
## Retain the rejected cage/ceiling trial; only current source-root owners here.
func review_path()->String:return "res://build/Other Files/Asset Toolkit/East Gate Region/Visual Landmarks/Private Compounds Actual Root Hubs/"
func review_source_paths()->Array:
 var paths=super.review_source_paths()+["tests/forest-shrine/east_private_compounds_actual_review.gd","scripts/forest/forest_east_nature.gd","assets/maps/falan/east_region/nature/data.json","assets/maps/falan/east_region/nature/11699-front.png","assets/maps/falan/east_region/nature/11699-back.png"]
 for folder in [RootTree.ROOT,Shrine.ROOT]:
  for name in DirAccess.get_files_at(folder):
   if name.ends_with(".png"):paths.append(folder+name)
 return paths
