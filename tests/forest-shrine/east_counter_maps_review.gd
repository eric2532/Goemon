extends "res://tests/forest-shrine/east_casework_maps_review.gd"
const Segments=preload("res://scripts/forest/forest_east_counter_segments.gd")
func review_path()->String:return "res://build/Other Files/Asset Toolkit/East Gate Region/Counter Segments/Actual Maps/"
func source_census_path()->String:return review_path()+"native-placements.json"
func site_owned(_source:int,serial:int)->bool:return serial in Segments.IDS
func site_mesh(_source:int,serial:int,g:Dictionary)->Mesh:return Segments.mesh(serial,g)
func site_visible(_serial:int,g:Dictionary)->Array:return[0,0,g.rect[2],g.rect[3]]
func fixture_source_paths()->Array:
 var paths=super.fixture_source_paths()+[get_script().resource_path,"scripts/forest/forest_east_counter_segments.gd","scripts/forest/forest_east_counter_front.gdshader",Segments.ROOT+"data.json"]
 for serial in Segments.IDS:paths.append(Segments.ROOT+str(serial)+".png")
 return paths
func fixture_scope()->String:return "Nine exact continuous-counter appearances,185OBJECTplacements in five original East maps. Full raw census, immutable mesh batches and unchanged walk/links checked. Four actual sites in three maps review both corner joints, crystal/card counter and ship variant; no shop/container/quest behavior changed."
func fixture_sites()->Array:
 return[
  [33514,17202,Vector2i(20,9),"source-blue-counter-outer-joint",Vector2i(18,12),Vector2i(22,12)],
  [33514,17197,Vector2i(20,18),"source-blue-counter-inner-joint",Vector2i(18,17),Vector2i(22,20)],
  [33213,17200,Vector2i(24,19),"source-card-and-crystal-counter",Vector2i(22,21),Vector2i(26,20)],
  [41010,17201,Vector2i(66,29),"source-ship-counter-segment",Vector2i(64,31),Vector2i(68,31)],
 ]
