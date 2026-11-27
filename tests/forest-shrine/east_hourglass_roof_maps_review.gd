extends "res://tests/forest-shrine/east_casework_maps_review.gd"
const Hours=preload("res://scripts/forest/forest_east_hourglasses.gd")
const Roof=preload("res://scripts/forest/forest_east_lektal_roof.gd")
func review_path()->String:return "res://build/Other Files/Asset Toolkit/East Gate Region/Hourglass Studies/Actual Maps/"
func source_census_path()->String:return review_path()+"native-placements.json"
func site_owned(source:int,serial:int)->bool:return Hours.owns(serial)or source in[43000,43700]and Roof.owns(serial)
func site_mesh(_source:int,serial:int,g:Dictionary)->Mesh:return Hours.mesh(serial,g)if Hours.owns(serial)else Roof.mesh(serial,g)
func site_visible(serial:int,g:Dictionary)->Array:return Hours.data().graphics[str(serial)].bounds if Hours.owns(serial)else[0,0,g.rect[2],g.rect[3]]
func fixture_source_paths()->Array:
 var paths=super.fixture_source_paths()+[get_script().resource_path,"scripts/forest/forest_east_hourglasses.gd","scripts/forest/forest_east_lektal_roof.gd",Hours.ROOT+"data.json",Roof.ROOT+"data.json","scripts/forest/forest_east_hourglass_front.gdshader","scripts/forest/forest_east_hourglass_back.gdshader"]
 for serial in Hours.IDS:paths.append(Hours.ROOT+str(serial)+"-front.png")
 for name in["house-atlas.png","depth-mask.png","surfaces.png","chimney-front.png"]:paths.append(Roof.ROOT+name)
 return paths
func fixture_scope()->String:return "Exact four-appearance OBJECT source census(three small hourglasses and3255house roof), unchanged walk/connections, immutable mesh batch checks and normal/second reachable views. Giant hourglass BG compounds remain private. Source village/field gameplay and other art are separately recorded."
func fixture_sites()->Array:
 return[
  [43826,1235180,Vector2i(69,50),"gold-ceremonial-hourglass",Vector2i(67,53),Vector2i(72,53)],
  [44000,1235181,Vector2i(100,80),"copper-ceremonial-hourglass",Vector2i(98,83),Vector2i(103,83)],
  [51100,1235182,Vector2i(16,20),"silver-ceremonial-hourglass",Vector2i(14,23),Vector2i(19,23)],
  [43700,1233255,Vector2i(71,34),"lektal-log-house-roof",Vector2i(68,40),Vector2i(78,40)],
 ]
