extends "res://tests/forest-shrine/east_hourglass_roof_maps_review.gd"
## Focus the unresolved gold pair without repeating the accepted copper/silver sites.
func review_path()->String:return "res://build/Other Files/Asset Toolkit/East Gate Region/Hourglass Studies/Gold Actual/"
func source_census_path()->String:return "res://build/Other Files/Asset Toolkit/East Gate Region/Hourglass Studies/Actual Maps/native-placements.json"
func fixture_scope()->String:return "Focused gold-hourglass camera retry using source-valid nearby stands of the opposite cell parity; unchanged23placement/9map raw census retained. No camera-distance guard or production camera change. Copper/silver and roof evidence stay in the original four-site report."
func fixture_sites()->Array:
 return[[43826,1235180,Vector2i(69,50),"gold-ceremonial-hourglass",Vector2i(68,51),Vector2i(70,49)]]
