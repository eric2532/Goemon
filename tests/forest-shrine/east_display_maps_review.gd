extends "res://tests/forest-shrine/east_casework_maps_review.gd"
## Five reviewed minor display/storage forms; seven other candidates stay private.
const Displays=preload("res://scripts/forest/forest_east_display_furniture.gd")
const ACCEPTED=[16824,16825,16828,17183,17528]
func review_path()->String:return "res://build/Other Files/Asset Toolkit/East Gate Region/Display Furniture/Actual Maps/"
func source_census_path()->String:return review_path()+"native-placements.json"
func site_owned(_source:int,serial:int)->bool:return serial in ACCEPTED
func site_mesh(_source:int,serial:int,g:Dictionary)->Mesh:return Displays.mesh(serial,g)
func site_visible(serial:int,_g:Dictionary)->Array:return Displays.data().graphics[str(serial)].bounds
func fixture_source_paths()->Array:
 var paths=super.fixture_source_paths()+[get_script().resource_path,"scripts/forest/forest_east_display_furniture.gd","scripts/forest/forest_east_misc_furniture.gd",Displays.ROOT+"data.json"]
 for serial in ACCEPTED:paths.append(Displays.ROOT+str(serial)+"-front.png")
 return paths
func fixture_scope()->String:return "Exact52source OBJECT placements in15maps for five asset-reviewed display/storage forms. Runtime mesh counts, unchanged original walk/connections and five readable gameplay-view pairs are checked separately. Seven other display candidates remain private. No service/container interaction change."
func fixture_sites()->Array:
 return[
  [31900,16824,Vector2i(24,3),"stamp-on-native-pedestal",Vector2i(23,6),Vector2i(27,6)],
  [31900,16825,Vector2i(25,3),"native-card-drawers",Vector2i(24,7),Vector2i(28,7)],
  [43900,16828,Vector2i(46,11),"reversed-native-card-drawers",Vector2i(44,14),Vector2i(49,14)],
  [33210,17183,Vector2i(16,15),"native-green-display-bed",Vector2i(14,18),Vector2i(19,18)],
  [32284,17528,Vector2i(11,12),"native-capped-crate-row",Vector2i(10,15),Vector2i(14,15)],
 ]
