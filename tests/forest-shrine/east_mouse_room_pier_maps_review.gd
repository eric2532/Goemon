extends "res://tests/forest-shrine/east_casework_maps_review.gd"
## Candidate-scene mesh swap only; original map/collision/event owners stay live.
const Piers=preload("res://scripts/forest/forest_east_mouse_room_piers.gd")
var swapped=false
func candidate_swap_enabled()->bool:return true
func review_path()->String:return "res://build/Other Files/Asset Toolkit/East Gate Region/Mouse Room Piers/Private Actual/"
func source_census_path()->String:return review_path()+"native-placements.json"
func site_owned(_source:int,serial:int)->bool:return serial==1230127
func site_mesh(_source:int,serial:int,g:Dictionary)->Mesh:return Piers.mesh(serial,g)
func site_visible(serial:int,_g:Dictionary)->Array:return Piers.data().graphics[str(serial)].bounds
func fixture_source_paths()->Array:return super.fixture_source_paths()+[get_script().resource_path,"tests/forest-shrine/east_mouse_room_pier_maps_review.gd","scripts/forest/forest_east_mouse_room_piers.gd",Piers.ROOT+"data.json","assets/textures/edo/rock.png","scripts/forest/forest_east_mouse_statue.gd"]
func fixture_scope()->String:return "Private candidate-scene1230127swap on original33608only; all625placements retain original transforms/counts and unchanged original walk/links. Independent754placement/8map source census. One gameplay-view pair and diagnostic; no canonical hook, other10piers or room completion."
func fixture_sites()->Array:return [[33608,1230127,Vector2i(40,27),"mouse-room-ball-capped-pier",Vector2i(39,26),Vector2i(39,28)]]
func camera_view(id:int,wanted:Vector2i,center:Vector2,height:float,second:bool,target_bounds:AABB)->Dictionary:
 if not swapped:
  var row:Dictionary=Maps.state(id);var cell=Vector2i(40,27);var cells:int=row.size.x*row.size.y
  var native=row.raw.decode_u16(20+(cells+cell.y*row.size.x+cell.x)*2)
  var aliases:Dictionary=Maps.Art.data().maps[Maps.path_for(id)].get("graphic_aliases",{})
  check(not Maps.open(row.bits,row.size,cell) and int(aliases.get(str(native),native))==1230127,"Camera subject remains the exact original closed1×1pier cell")
  var count_=0
  for batch:MultiMeshInstance3D in game.world.map_features.find_children("*","MultiMeshInstance3D",true,false):
   if int(batch.get_meta("source_graphic",-1))!=1230127:continue
   var wanted_mesh=Piers.mesh(1230127,Maps.Art.data().graphics["1230127"])
   if candidate_swap_enabled():batch.multimesh.mesh=wanted_mesh
   else:check(batch.multimesh.mesh==wanted_mesh,"Canonical map installs the reviewed immutable pier without candidate override")
   count_+=batch.multimesh.instance_count
  check(count_==625,"All625source pier transforms/placements remain")
  observations.append({"private_candidate_mesh_swap":candidate_swap_enabled(),"source":33608,"placements":count_,"collision_navigation_and_events_unchanged":true})
  swapped=true
 # The original closed cell's collision is3mwide, versus2.26mvisible masonry.
 # Recognize only this subject cell's physical volume, never the earlier piers
 # that correctly blocked the first interior-target study.
 var anchor=Maps.point(id,Vector2i(40,27));var scale_=game.model.falan_scale
 var source_footprint=AABB(game.model.world_point(anchor)+Vector3(-1.5,0,-1.5)*scale_,Vector3(3.,target_bounds.size.y/scale_,3.)*scale_)
 var view=await super.camera_view(id,wanted,center,height,second,target_bounds.merge(source_footprint))
 if not view.is_empty():observations.append({"subject_source_cell":[40,27],"subject_original_closed":not Maps.open(Maps.state(id).bits,Maps.state(id).size,Vector2i(40,27)),"subject_visible_bounds":var_to_str(target_bounds),"subject_physical_footprint":var_to_str(source_footprint),"source_footprint_guard_only":true,"gameplay_camera_collision_unchanged":true})
 return view
