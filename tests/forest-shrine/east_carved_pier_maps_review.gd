extends "res://tests/forest-shrine/east_casework_maps_review.gd"
## Private scene-only swap of one source appearance; no map or collision hook.
const Carved=preload("res://scripts/forest/forest_east_carved_pier_study.gd")
var swapped=false
func review_path()->String:return "res://build/Other Files/Asset Toolkit/East Gate Region/Mouse Room Piers/Carved Private Actual/"
func source_census_path()->String:return review_path()+"native-placements.json"
func site_owned(_source:int,serial:int)->bool:return serial==1230051
func site_mesh(_source:int,serial:int,g:Dictionary)->Mesh:
 var cached=Carved.meshes.has(serial);var started=Time.get_ticks_usec();var result=Carved.mesh(serial,g)
 if not cached:metrics.append({"private_carved_mesh_setup_ms":(Time.get_ticks_usec()-started)/1000.,"surfaces":result.get_surface_count(),"scope":"One-time source/material/mesh preparation, separate from first draw and warm frames."})
 return result
func site_visible(serial:int,_g:Dictionary)->Array:return Carved.Measurements.data().graphics[str(serial)].bounds
func fixture_source_paths()->Array:
 return super.fixture_source_paths()+[get_script().resource_path,"scripts/forest/forest_east_carved_pier_study.gd","scripts/forest/forest_east_mouse_room_piers.gd",Carved.Measurements.ROOT+"data.json","scripts/forest/forest_east_fallback_families.gd","scripts/forest/forest_east_room_furniture.gd","scripts/forest/forest_wind_meadow_art.gd","scripts/forest/crowd/army_runtime.gd","assets/materials/forest_stone.gdshader",Carved.MASONRY,Carved.MASONRY_CPU,Carved.NATIVE_CPU,"assets/maps/original_crossgate/east/carved-cpu-pages/provenance.json","assets/maps/falan/east_region/carved_pier_study/provenance.json","assets/maps/falan/east_region/carved_pier_study/cpu-provenance.json"]
func fixture_scope()->String:return "Full178placement/10fixed-map census for1230051; private scene swap remains all six original33608placements only. One pair of reachable gameplay views plus a separately labeled native-axis ceiling diagnostic. No canonical hook, other appearances or room/quest completion claim."
func fixture_sites()->Array:return [[33608,1230051,Vector2i(53,32),"mouse-room-embedded-stone-pier",Vector2i(51,32),Vector2i(54,34)]]
func use_camera_component(id:int,start:Vector2i):
 super.use_camera_component(id,start)
 check(camera_component.has(Vector2i(8,59)),"Camera floor component includes the original33607→33608stair arrival")
func pipeline_counts()->Dictionary:
 return {"mesh":Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_MESH),"surface":Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_SURFACE),"draw":Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_DRAW),"specialization":Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_SPECIALIZATION)}
func camera_view(id:int,wanted:Vector2i,center:Vector2,height:float,second:bool,target_bounds:AABB)->Dictionary:
 if not swapped:
  var state:Dictionary=Maps.state(id);var cell=Vector2i(53,32);var count_:int=state.size.x*state.size.y
  var native=state.raw.decode_u16(20+(count_+cell.y*state.size.x+cell.x)*2);var aliases:Dictionary=Maps.Art.data().maps[Maps.path_for(id)].get("graphic_aliases",{})
  check(not Maps.open(state.bits,state.size,cell) and int(aliases.get(str(native),native))==1230051,"Subject remains the exact original closed source pier cell")
  var runtime=load("res://scripts/forest/crowd/army_runtime.gd");var navigation=var_to_bytes(runtime.navigation_data(game.model));var obstacles=game.model.scenery_obstacles.duplicate(true)
  var pipeline_before=pipeline_counts();var total=0
  for node:MultiMeshInstance3D in game.world.map_features.find_children("*","MultiMeshInstance3D",true,false):
   if int(node.get_meta("source_graphic",-1))!=1230051:continue
   node.multimesh.mesh=Carved.mesh(1230051,Maps.Art.data().graphics["1230051"]);total+=node.multimesh.instance_count
  check(total==6,"Six original source transforms retained in the private scene")
  check(var_to_bytes(runtime.navigation_data(game.model))==navigation and game.model.scenery_obstacles==obstacles,"Private mesh swaps preserve the complete Native payload and physical obstacles")
  var samples=[];var slow_frames=[];var focused=0
  for frame in 120:
   var started=Time.get_ticks_usec();await process_frame;var elapsed=(Time.get_ticks_usec()-started)/1000.;samples.append(elapsed)
   if DisplayServer.window_is_focused():focused+=1
   if elapsed>50.:slow_frames.append({"frame":frame,"ms":elapsed,"pipelines":pipeline_counts(),"focused":DisplayServer.window_is_focused()})
  var ordered=samples.duplicate();var warm=samples.slice(30);warm.sort();samples.sort();var pipeline_after=pipeline_counts()
  metrics.append({"private_after_mesh_swap":true,"source":33608,"sample_count":120,"median_ms":samples[60],"p95_ms":samples[114],"max_ms":samples[-1],"ordered_frame_ms":ordered,"warm_frames_30_through_119":{"median_ms":warm[45],"p95_ms":warm[85],"max_ms":warm[-1]},"slow_frames":slow_frames,"pipeline_before":pipeline_before,"pipeline_after":pipeline_after,"focused_frames":focused,"vsync":DisplayServer.window_get_vsync_mode(),"engine_max_fps":Engine.max_fps,"scope":"Includes cold first draw and separately labeled warm static-room sample; not a whole-army, long-session or global performance claim."})
  observations.append({"private_candidate_mesh_swap":true,"source":33608,"graphic":1230051,"placements":total,"source_cells_and_physical_owners_unchanged":true});swapped=true
 # The source collision is one3mcell. Only this exact subject's barrier may
 # satisfy the ray guard; neighboring piers and walls remain real obstructions.
 var anchor=Maps.point(id,Vector2i(53,32));var scale_:float=game.model.falan_scale
 var physical=AABB(game.model.world_point(anchor)+Vector3(-1.5,0,-1.5)*scale_,Vector3(3.,target_bounds.size.y/scale_,3.)*scale_)
 var view=await super.camera_view(id,wanted,center,height,second,physical)
 if not view.is_empty():observations.append({"subject_visible_bounds":var_to_str(target_bounds),"subject_original_physical_volume":var_to_str(physical),"guard_uses_only_subject_source_cell":true,"camera_collision_and_distance_unchanged":true})
 return view
