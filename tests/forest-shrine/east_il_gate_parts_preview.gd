extends "res://tests/forest-shrine/east_nature_preview.gd"
const Gate=preload("res://scripts/forest/forest_east_il_gate_parts.gd")
func review_path()->String:return "res://build/Other Files/Asset Toolkit/East Gate Region/Il Gate Parts/Closed Cap Asset Review/"
func selected_ids()->Array:return ["11077","11078"]
func page_capacity()->int:return 1
func additional_input_paths()->Array:return ["res://scripts/forest/forest_east_il_gate_parts.gd",Gate.ROOT+"data.json"]
func asset_mesh(serial:int)->Mesh:return Gate.mesh(serial)
