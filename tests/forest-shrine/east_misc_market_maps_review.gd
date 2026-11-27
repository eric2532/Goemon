extends "res://tests/forest-shrine/east_casework_maps_review.gd"
## Existing census/batch/walk proof, scoped to the16visually accepted forms.
const Misc=preload("res://scripts/forest/forest_east_misc_furniture.gd")
const Market=preload("res://scripts/forest/forest_east_market_goods.gd")
const PUBLISHED=[11575,11576,11580,16818,16852,16853,16854,16855,16864,16865,16866,10053,10054,10056,10057,10098]
func review_path()->String:return "res://build/Other Files/Asset Toolkit/East Gate Region/Misc Furniture/Actual Maps/"
func source_census_path()->String:return review_path()+"native-placements.json"
func site_owned(_source:int,serial:int)->bool:return serial in PUBLISHED
func site_mesh(_source:int,serial:int,g:Dictionary)->Mesh:return Market.mesh(serial,g)if Market.owns(serial)else Misc.mesh(serial,g)
func site_visible(serial:int,_g:Dictionary)->Array:return (Market.data()if Market.owns(serial)else Misc.data()).graphics[str(serial)].bounds
func fixture_source_paths()->Array:
 var paths=super.fixture_source_paths()+[get_script().resource_path,"scripts/forest/forest_east_misc_furniture.gd","scripts/forest/forest_east_market_goods.gd",Misc.ROOT+"data.json",Market.ROOT+"data.json"]
 for serial in PUBLISHED:paths.append((Market.ROOT if Market.owns(serial)else Misc.ROOT)+str(serial)+"-front.png")
 return paths
func fixture_scope()->String:return "16published source appearances,48original OBJECT placements in28fixedmaps. Seven actual source sites check immutable batches and unchanged walk/connections; normal/reachable second/native-axis captures need separate visual judgment. Four rejected wheelbarrow/crate candidates remain private. No shop service, inventory or quest behavior changed."
func fixture_sites()->Array:
 return [
  [43720,10053,Vector2i(24,15),"native-produce-and-fish-stalls",Vector2i(22,17),Vector2i(25,17)],
  [43165,10056,Vector2i(10,26),"goral-produce-display",Vector2i(9,28),Vector2i(12,28)],
  [33200,11576,Vector2i(224,198),"akelufa-rounded-mailbox",Vector2i(222,200),Vector2i(226,200)],
  [32108,16852,Vector2i(9,7),"native-food-plinths",Vector2i(8,9),Vector2i(11,9)],
  [43910,16866,Vector2i(8,4),"native-cloth-display",Vector2i(7,7),Vector2i(10,7)],
  [31917,16818,Vector2i(26,13),"source-open-wicker-basket",Vector2i(24,15),Vector2i(28,15)],
  [37004,10098,Vector2i(21,18),"native-vented-crate",Vector2i(19,20),Vector2i(23,20)],
 ]
