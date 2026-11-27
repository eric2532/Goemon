extends RefCounted
## Private standalone2400 delegate; the shared review adapter is its only dispatcher.
const Field=preload("res://scripts/forest/forest_east_il_low_source.gd")
const Full=preload("res://scripts/forest/forest_east_alyut_source_completion.gd")
const ROOT="res://build/Other Files/Asset Toolkit/East Gate Region/Village Props/Cliff Audit/Source Context Audit/Prototype/"
static var manifest:Dictionary={}
static func data()->Dictionary:
 if manifest.is_empty():manifest=JSON.parse_string(FileAccess.get_file_as_string(ROOT+"alyut2400-data.json"))
 return manifest
static func owns(model)->bool:return model.falan_area=="alyut" and model.terrain.get_meta("east_alyut_separate_source_private",false)
static func configure_model(model):
 if model.falan_area!="alyut":return
 var terrain=Field.new();terrain.setup(data());terrain.set_meta("east_alyut_separate_source_private",true);model.terrain=terrain;model.falan_road=""
 var bounds:Rect2=terrain.mask_bounds();var low=Vector2i((bounds.position/6.).floor());var high=Vector2i((bounds.end/6.).ceil())
 model.navigation_region=Rect2i(low,high-low)
static func point(cell:Vector2i)->Vector2:return Vector2(-150,-150)+Vector2(cell)*3.
static func add_navigation(nav:Dictionary,model):
 if not owns(model):return
 var exact:Dictionary=model.terrain.native_data(1.)
 for key in ["width","spacing","route_spacing","origin","bounds_min","bounds_max","heights","covered","pieces"]:nav[key]=exact[key]
 for key in ["obstacle_min","obstacle_max"]:
  nav[key].append_array(exact[key])
  if nav.has("friendly_"+key):nav["friendly_"+key].append_array(exact[key])
static func build_banks(root:Node3D,model):
 if owns(model):load("res://scripts/forest/forest_east_bank_caps.gd").build(root,Full.bank_rows())
static func prepare_world(world,player):
 if not owns(world.model):return
 var bounds:Rect2=world.model.terrain.mask_bounds();var scale_:float=world.model.falan_scale
 world.playable_bounds=Rect2(bounds.position*scale_,bounds.size*scale_).grow(2.*player.growth_multiplier())
 if world.map_features.has_meta("east_alyut_separate_boundary_runs"):return
 var maps=load("res://scripts/forest/forest_original_maps.gd");var before=world.map_features.get_child_count()
 var walls=maps.boundaries(world.map_features,Marshalls.base64_to_raw(data().walk_bits),Vector2i(100,100),Vector2(-150,-150),FileAccess.get_file_as_bytes(Full.ROOT+"hybrid-map.bin"))
 for index in range(before,world.map_features.get_child_count()):
  var node=world.map_features.get_child(index);node.set_meta("source_map",2400);node.set_meta("east_alyut_separate_boundary",true)
 world.map_features.set_meta("east_alyut_separate_boundary_runs",walls.size())
