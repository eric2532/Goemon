extends "res://tests/forest-shrine/east_display_maps_review.gd"
func review_path()->String:return "res://build/Other Files/Asset Toolkit/East Gate Region/Display Furniture/Near Actual/"
func source_census_path()->String:return "res://build/Other Files/Asset Toolkit/East Gate Region/Display Furniture/Actual Maps/native-placements.json"
func fixture_scope()->String:return "Focused retry of the three unresolved stamp/drawer camera pairs, including immediate adjacent source cells. All52sourceplacements/15map census retained. No productioncamera, physics or80percent/sightline guard change. Other two representative sites remain in119/5historicalreport."
func fixture_sites()->Array:
 return[
  [31900,16824,Vector2i(24,3),"stamp-on-native-pedestal",Vector2i(23,5),Vector2i(26,5)],
  [31900,16825,Vector2i(25,3),"native-card-drawers",Vector2i(26,5),Vector2i(24,5)],
  [43900,16828,Vector2i(46,11),"reversed-native-card-drawers",Vector2i(45,13),Vector2i(48,13)],
 ]
