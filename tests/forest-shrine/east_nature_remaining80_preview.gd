extends "res://tests/forest-shrine/east_nature_preview.gd"
## Complete the exact missing visual subset; no map owner or source asset edits.
const REMAINING="res://build/Other Files/Asset Toolkit/East Gate Region/Visual Landmarks/Nature/Owned240/unreviewed80.json"
func review_path()->String:return "res://build/Other Files/Asset Toolkit/East Gate Region/Visual Landmarks/Nature/Remaining80/"
func selected_ids()->Array:return JSON.parse_string(FileAccess.get_file_as_string(REMAINING)).graphics
func additional_input_paths()->Array:return [REMAINING,"res://scripts/forest/forest_east_round_cactus.gd",Nature.Cactus.ROOT+"data.json"]
