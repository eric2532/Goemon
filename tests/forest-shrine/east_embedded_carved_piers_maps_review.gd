extends "res://tests/forest-shrine/east_casework_maps_review.gd"
## Private assembly of original wall variants; source navigation remains authoritative.
const Piers=preload("res://scripts/forest/forest_east_embedded_carved_piers.gd")
var swapped=false
var subject=Vector2i(53,32)
func review_path()->String:return "res://build/Other Files/Asset Toolkit/East Gate Region/Mouse Room Piers/Embedded Four Private Actual/"
func source_census_path()->String:return review_path()+"native-placements.json"
func site_owned(_source:int,serial:int)->bool:return serial in Piers.IDS or serial==1230051
func site_mesh(_source:int,serial:int,g:Dictionary)->Mesh:return Piers.Base.mesh(serial,g)if serial==1230051 else Piers.mesh(serial,g)
func site_visible(serial:int,_g:Dictionary)->Array:return Piers.Base.Measurements.data().graphics[str(serial)].bounds
func fixture_source_paths()->Array:
 return super.fixture_source_paths()+[get_script().resource_path,"scripts/forest/forest_east_embedded_carved_piers.gd","scripts/forest/forest_east_carved_pier_study.gd","scripts/forest/forest_east_mouse_room_piers.gd",Piers.Base.Measurements.ROOT+"data.json",Piers.Base.MASONRY,Piers.Base.MASONRY_CPU,Piers.Base.NATIVE_CPU]
func fixture_scope()->String:return "Private four embedded wall variants plus canonical51:4627fixed placements/ten-map census; swap318original33608wall instances only. Original walk/links/Native/scenery obstacles preserved. Profile/assembly study, no new Mainhook, relief or whole-room acceptance."
func fixture_sites()->Array:return [[33608,1230051,Vector2i(53,32),"embedded-wall-junction",Vector2i(51,32),Vector2i(54,34)],[33608,1230054,Vector2i(89,54),"embedded-carved-emblem",Vector2i(87,54),Vector2i(90,54)]]
func landmark(site:Array):
 subject=site[2]
 await super.landmark(site)
func camera_view(id:int,wanted:Vector2i,center:Vector2,height:float,second:bool,target_bounds:AABB)->Dictionary:
 if not swapped:
  var runtime=load("res://scripts/forest/crowd/army_runtime.gd");var navigation=var_to_bytes(runtime.navigation_data(game.model));var obstacles=game.model.scenery_obstacles.duplicate(true);var count_=0
  for node:MultiMeshInstance3D in game.world.map_features.find_children("*","MultiMeshInstance3D",true,false):
   var serial=int(node.get_meta("source_graphic",-1))
   if serial not in Piers.IDS:continue
   node.multimesh.mesh=Piers.mesh(serial,Maps.Art.data().graphics[str(serial)]);count_+=node.multimesh.instance_count
  check(count_==318,"All original wall variants use private shared meshes without changing transforms")
  check(var_to_bytes(runtime.navigation_data(game.model))==navigation and game.model.scenery_obstacles==obstacles,"Private assembly retains the complete Native payload and source obstacles")
  check(game.FalanTour.Regions.private_source_context==null,"Private field context remains default-off")
  observations.append({"private_swapped_wall_instances":count_,"published51_unchanged":true,"native_payload_unchanged":true});swapped=true
 var at=Maps.point(id,subject);var scale_:float=game.model.falan_scale
 var physical=AABB(game.model.world_point(at)+Vector3(-1.5,0,-1.5)*scale_,Vector3(3.,target_bounds.size.y/scale_,3.)*scale_)
 return await super.camera_view(id,wanted,center,height,second,physical)
