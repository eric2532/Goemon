extends "res://tests/forest-shrine/east_ancient_root_final_review.gd"
## Original brown crown branches use timber geometry, not a flat wood patch.
func review_path()->String:return "res://build/Other Files/Asset Toolkit/East Gate Region/Visual Landmarks/Ancient Root Branches/"
func review_source_paths()->Array:return super.review_source_paths()+["tests/forest-shrine/east_ancient_root_final_review.gd"]
