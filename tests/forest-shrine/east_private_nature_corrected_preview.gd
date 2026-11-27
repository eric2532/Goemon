extends "res://tests/forest-shrine/east_private_nature_final_preview.gd"
## Retain the rejected gallery; this revision has closed crown overlap and ribs.
const Kanabella=preload("res://scripts/forest/forest_east_kanabella_bg.gd")
func review_path()->String:return "res://build/Other Files/Asset Toolkit/East Gate Region/Visual Landmarks/Private Nature Corrected Assets/"
func selected_ids()->Array:return super.selected_ids()+["9999999"]
func asset_mesh(serial:int)->Mesh:return Kanabella.mesh() if serial==9999999 else super.asset_mesh(serial)
func additional_input_paths()->Array:
 var paths=super.additional_input_paths()
 for token in Cactus.data().graphics:
  for name in Cactus.data().graphics[token].derived_rgba_sha256:paths.append(Cactus.ROOT+name)
 paths.append("res://scripts/forest/forest_east_kanabella_bg.gd");paths.append(Kanabella.ROOT+"prototype.json");paths.append(Kanabella.ROOT+"data.json")
 for part in Kanabella.data().derivatives:paths.append(Kanabella.ROOT+Kanabella.data().model+"-"+part+".png")
 return paths
