extends "res://tests/forest-shrine/east_living_family_review.gd"
## Current caller-selected bark on all seven; closer shrine stands retain the real camera.
var reviewing_shrine=false
func review_path()->String:return "res://build/Other Files/Asset Toolkit/East Gate Region/Visual Landmarks/Living Rooted Final/"
func sites()->Array:
 var result:Array=super.sites()
 result[1][4]=Vector2i(150,138);result[4][4]=Vector2i(146,139)
 result[-1][4]=Vector2i(182,107);result[-1][5]=Vector2i(176,101)
 return result
func landmark(row:Array):
 reviewing_shrine=int(row[1])==1230040
 await super.landmark(row)
func camera_view(id:int,wanted:Vector2i,center:Vector2,height:float,second:bool,target_bounds:AABB)->Dictionary:
 if not reviewing_shrine:return await super.camera_view(id,wanted,center,height,second,target_bounds)
 var state:Dictionary=Maps.state(id);var cell=Vector2i(((center-state.origin)/3.).round());var seeds=[wanted]
 for radius in [6,8,10,12]:
  for direction in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN,Vector2i(-1,-1),Vector2i(1,-1),Vector2i(-1,1),Vector2i(1,1)]:seeds.append(cell+direction*radius)
 var attempts=[];var best={};var best_score=-INF
 for seed:Vector2i in seeds:
  var view:Dictionary=await super.camera_view(id,seed,center,height,second,target_bounds)
  if view.is_empty():continue
  var away=Maps.point(id,view.cell).distance_to(center);var camera:Camera3D=game.camera_rig.camera
  var top=target_bounds.position+Vector3(target_bounds.size.x*.5,target_bounds.size.y*.90,target_bounds.size.z*.5)
  var height_framed=camera.is_position_in_frustum(top)
  attempts.append({"seed":[seed.x,seed.y],"chosen_cell":[view.cell.x,view.cell.y],"clear":view.clear,"framed":view.framed,"distance_ok":view.distance_ok,"top_in_frustum":height_framed,"stand_distance_native_m":away,"pitch":game.camera_rig.pitch})
  if view.clear and view.framed and view.distance_ok and height_framed and away<=42.:
   observations.append({"shrine_bounded_stand_sweep":attempts,"ordinary_pitch":ordinary_pitch(),"second":second})
   return view
  var score=(30. if view.clear and view.framed else 0.)+(20. if view.distance_ok else 0.)+(10. if height_framed else 0.)-away*.2
  if score>best_score:best=view;best_score=score
 observations.append({"shrine_bounded_stand_sweep":attempts,"no_fully_clear_nearby_view":true,"second":second})
 check(false,"Shrine needs a clearer source stand; do not accept the gateway/neighbor foliage as the target")
 return {} if best.is_empty() else await super.camera_view(id,best.cell,center,height,second,target_bounds)
