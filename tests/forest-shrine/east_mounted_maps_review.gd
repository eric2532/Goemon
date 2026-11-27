extends "res://tests/forest-shrine/east_casework_maps_review.gd"
## Reuse the native census/batch/walk proof with five actual mounted-detail sites.
const Mounted=preload("res://scripts/forest/forest_east_mounted_details.gd")
func review_path()->String:return "res://build/Other Files/Asset Toolkit/East Gate Region/Mounted Details/Actual Maps/"
func source_census_path()->String:return "res://build/Other Files/Asset Toolkit/East Gate Region/Mounted Details/native-placements.json"
func site_owned(_source:int,serial:int)->bool:return serial!=10567 and Mounted.owns(serial)
func site_mesh(_source:int,serial:int,g:Dictionary)->Mesh:return Mounted.mesh(serial,g)
func site_visible(serial:int,_g:Dictionary)->Array:return Mounted.data().graphics[str(serial)].bounds
func fixture_source_paths()->Array:
 var paths=super.fixture_source_paths()+[get_script().resource_path,"assets/maps/falan/east_region/mounted_details/data.json"]
 for serial in Mounted.IDS:
  paths.append(Mounted.ROOT+str(serial)+"-front.png");paths.append(Mounted.ROOT+str(serial)+"-back.png")
 return paths
func fixture_scope()->String:return "Raw source census for30exact mounted details:226placements/115fixedmaps, excluding3legacy-owner placements. Five actual source sites with unchanged walk/connections and immutable batch checks; independent prior75/0asset gallery and60/0source-plane proof. Adjacent wall quality and other quest behavior are separate."
func fixture_sites()->Array:
 return [
  [43140,10526,Vector2i(32,2),"goral-accessory-sign",Vector2i(31,5),Vector2i(34,5)],
  [43730,16236,Vector2i(9,11),"lektal-mounted-painting",Vector2i(9,13),Vector2i(12,13)],
  [2801,16645,Vector2i(14,3),"native-hanging-pans",Vector2i(13,6),Vector2i(17,6)],
  [46011,14536,Vector2i(26,18),"source-static-figure",Vector2i(26,21),Vector2i(29,21)],
  [32275,17560,Vector2i(47,24),"native-ship-pennant",Vector2i(45,26),Vector2i(49,26)],
 ]
