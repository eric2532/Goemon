extends "res://tests/forest-shrine/east_landmark_review.gd"
## One source placement of each living form; ordinary follow camera plus reachable reverse.
func review_path()->String:return "res://build/Other Files/Asset Toolkit/East Gate Region/Visual Landmarks/Living Family Final/"
func sites()->Array:return [
 [33200,1230039,Vector2i(226,137),"blue-cut-tree-house",Vector2i(220,144),Vector2i(233,132)],
 [33200,1230064,Vector2i(156,138),"bamboo-tree-house",Vector2i(150,145),Vector2i(164,131)],
 [33200,1230062,Vector2i(116,136),"joined-cut-tree-houses",Vector2i(104,148),Vector2i(127,128)],
 [33200,1230063,Vector2i(140,162),"terrace-tree-houses",Vector2i(129,173),Vector2i(137,153)],
 [33200,1230065,Vector2i(140,142),"paired-blue-tree-houses",Vector2i(130,130),Vector2i(150,133)],
 [33200,1230066,Vector2i(191,142),"leafy-blue-tree-houses",Vector2i(182,130),Vector2i(203,133)],
 [33200,1230040,Vector2i(178,100),"rooted-tree-shrine",Vector2i(167,114),Vector2i(190,93)],
]

func ordinary_pitch()->float:return .32 # Default review pitch; adjusted orbit captures are supplementary.

func landmark(site_row:Array):
 await super.landmark(site_row)
 var features:Node3D=game.world.map_features
 var rids:Array=features.get_meta(Maps.WaterCamera.ROOT_RIDS,[])
 check(rids.size()==430,"Actual33200 AuthoredMapFeatures retains430 pure-water camera exclusions")
 check(game.camera_rig.water_camera.probe.exclude.size()==rids.size(),"Actual camera bound root water RIDs without a child traversal")
 observations.append({"source":33200,"actual_map_features_water_exclusions":rids.size(),"camera_exclusion_count":game.camera_rig.water_camera.probe.exclude.size(),"ordinary_pitch":ordinary_pitch()})
 if int(site_row[1])==1230062:
  var start=Maps.point(33200,walk_cell(33200,Vector2i(104,148)))
  var target=Maps.point(33200,Vector2i(116,136))
  var query=PhysicsRayQueryParameters3D.create(game.model.world_point(start,2.),game.model.world_point(target,2.),1)
  query.exclude=game.camera_rig.water_camera.probe.exclude
  var hit=game.world.get_world_3d().direct_space_state.intersect_ray(query)
  check(not hit.is_empty() and not hit.collider.get_meta(Maps.WaterCamera.WATER_BOUNDARY,false) and not hit.collider.get_meta("original_map_ground",false),"Camera still stops at the visible living-house navigation proxy")
  observations.append({"actual_visible_house_proxy_hit":{} if hit.is_empty() else {"position":var_to_str(hit.position),"collider":str(hit.collider.get_path())}})
