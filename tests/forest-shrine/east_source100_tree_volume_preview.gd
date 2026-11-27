extends "res://tests/forest-shrine/east_native_trees_preview.gd"
const Prototype=preload("res://tests/forest-shrine/east_source100_tree_volume_candidate.gd")
func review_path()->String:return "res://build/Other Files/Asset Toolkit/East Gate Region/Runtime Audit/Source100 Missing13/Tree Crown Volume Candidate/"
func selected_ids()->Array:return [10074]
func additional_input_paths()->Array:return super.additional_input_paths()+["res://tests/forest-shrine/east_source100_tree_volume_candidate.gd",NativeTrees.ROOT+"10074-foliage.png",NativeTrees.ROOT+"10074-branches.png"]
func asset_mesh(serial:int)->Mesh:return Prototype.mesh(serial)
