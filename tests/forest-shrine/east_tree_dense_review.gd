extends "res://tests/forest-shrine/east_tree_families_review.gd"
## More original walk stands; inherited physics/canopy/distance guards are unchanged.
func review_path()->String:return "res://build/Other Files/Asset Toolkit/East Gate Region/Visual Landmarks/Tree Families/Dense Normal Recheck/"
func sites()->Array:return [
 [43700,1233210,Vector2i(90,68),"lektal-sparse-conifer",Vector2i(93,68),Vector2i(93,68)],
 [43800,1233070,Vector2i(123,98),"cape-source-fruit-tree",Vector2i(126,102),Vector2i(127,95)],
]
func camera_view(id:int,wanted:Vector2i,center:Vector2,height:float,second:bool,target_bounds:AABB)->Dictionary:
 if second:return await super.camera_view(id,wanted,center,height,second,target_bounds)
 var state:Dictionary=Maps.state(id);var target_cell=Vector2i(((center-state.origin)/3.).round())
 var seeds=[wanted]
 for radius in [4,6,8]:
  for direction in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN,Vector2i(-1,-1),Vector2i(1,-1),Vector2i(-1,1),Vector2i(1,1)]:seeds.append(target_cell+direction*radius)
 var maximum_stand_distance=maxf(18.,target_bounds.size.y/game.model.falan_scale*2.)
 var attempted=[];var best={};var best_score=-INF
 for seed:Vector2i in seeds:
  var view:Dictionary=await super.camera_view(id,seed,center,height,false,target_bounds)
  if view.is_empty():continue
  var away=Maps.point(id,view.cell).distance_to(center)
  attempted.append({"seed":[seed.x,seed.y],"chosen_cell":[view.cell.x,view.cell.y],"clear":view.clear,"framed":view.framed,"distance_ok":view.distance_ok,"distance_to_target_native_m":away,"actual_camera_distance":game.camera_rig.current_distance})
  if view.clear and view.framed and view.distance_ok and away<=maximum_stand_distance:
   observations.append({"dense_original_stand_sweep":id,"attempts":attempted,"default_pitch":ordinary_pitch(),"maximum_stand_distance_native_m":maximum_stand_distance})
   return view
  var score=(30. if view.clear and view.framed else 0.)+(20. if view.distance_ok else 0.)-away*.1
  if score>best_score:best=view;best_score=score
 observations.append({"dense_original_stand_sweep":id,"attempts":attempted,"default_pitch":ordinary_pitch(),"maximum_stand_distance_native_m":maximum_stand_distance,"no_clear_nearby_full_distance_view":true})
 check(false,"No nearby clear default tree camera after bounded original-stand sweep "+str(id))
 return {} if best.is_empty() else await super.camera_view(id,best.cell,center,height,false,target_bounds)
