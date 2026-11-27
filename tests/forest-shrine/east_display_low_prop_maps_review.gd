extends "res://tests/forest-shrine/east_display_maps_review.gd"
## Default production owner; no private collider or camera mutation.
func review_path()->String:return "res://build/Other Files/Asset Toolkit/East Gate Region/Display Furniture/Low Prop Camera/Actual Maps/"
func source_census_path()->String:return "res://build/Other Files/Asset Toolkit/East Gate Region/Display Furniture/Actual Maps/native-placements.json"
func fixture_scope()->String:return "Default live source31900low-prop camera refinement with complete unchanged player/native barrier. Only drawer pair replayed; other52sourceplacements/15map census retained. No private camera/collider mutation and no source43900cliff-wall exemption."
func fixture_source_paths()->Array:return super.fixture_source_paths()+["scripts/forest/forest_east_prop_camera.gd","scripts/forest/forest_original_water_camera.gd"]
func fixture_sites()->Array:return [[31900,16825,Vector2i(25,3),"native-card-drawers-live-low-prop",Vector2i(24,6),Vector2i(23,4)]]
