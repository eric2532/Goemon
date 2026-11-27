extends "res://tests/forest-shrine/east_private_nature_corrected_preview.gd"
## Bounded follow-up only for the four ribs and rejected Kanabella attic/roof.
func review_path()->String:return "res://build/Other Files/Asset Toolkit/East Gate Region/Visual Landmarks/Private Ribs and Kanabella Roof/"
func selected_ids()->Array:return ["11746","11782","11785","11786","9999999"]
func additional_input_paths()->Array:
 var paths=super.additional_input_paths()
 for name in Kanabella.data().material_files:paths.append(Kanabella.ROOT+name)
 return paths
