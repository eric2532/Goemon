extends "res://tests/forest-shrine/east_root_core_asset_review.gd"
const House=preload("res://scripts/forest/forest_east_kanabella_bg.gd")
func review_path()->String:return "res://build/Other Files/Asset Toolkit/East Gate Region/Visual Landmarks/Kanabella Gold Gable Support/"
func root_mesh()->Mesh:return House.mesh()
func input_path()->String:return "res://scripts/forest/forest_east_kanabella_bg.gd"
func input_paths()->Array:
 var result=[input_path(),House.ROOT+"data.json",House.ROOT+"prototype.json"];var spec=House.data()
 for name in spec.material_files:result.append(House.ROOT+name)
 for part in spec.derivatives:result.append(House.ROOT+spec.model+"-"+part+".png")
 return result
func stage_target()->Vector3:return Vector3(6.6,6.5,19.6)
func camera_size()->float:return 24.
func reverse_direction()->Vector3:return Vector3(1,.4,-1).normalized()
