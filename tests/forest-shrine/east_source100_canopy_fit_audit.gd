extends SceneTree
const Clumps=preload("res://tests/forest-shrine/east_source100_meadow_clumps_candidate.gd")
const Base=Clumps.Base
func stats(points:Array)->Dictionary:
 var right=Vector3(1,0,1).normalized();var eye=Vector3(-1,.72,1).normalized();var up=eye.cross(right).normalized()
 var screen=Rect2(Vector2(points[0].dot(right),points[0].dot(up)),Vector2.ZERO);var depth=Vector2(INF,-INF);var low:Vector3=points[0];var high:Vector3=points[0]
 for p:Vector3 in points:
  screen=screen.expand(Vector2(p.dot(right),p.dot(up)));depth.x=minf(depth.x,p.dot(eye));depth.y=maxf(depth.y,p.dot(eye));low=low.min(p);high=high.max(p)
 return {"world_aabb_size":var_to_str(high-low),"source_owner_axis_width":screen.size.x,"source_owner_axis_height":screen.size.y,"source_owner_axis_aspect":screen.size.x/screen.size.y,"source_owner_axis_depth":depth.y-depth.x}
func _initialize():
 var mesh=Clumps.mesh(10074);var leaf_points=[];var all_points=[];var arrays:Array=mesh.get_meta("east_cpu_arrays")
 for i in arrays.size():
  for p:Vector3 in arrays[i][Mesh.ARRAY_VERTEX]:
   all_points.append(p)
   if i>=3:leaf_points.append(p)
 var original=[];var framed=[]
 for part:Dictionary in Base.Meadow.source("crossgate_flora/cg_woodland"):
  if part.name!="Canopy":continue
  var source:Mesh=Base.transformed_existing(part.mesh,part.transform,part.material)
  for row:Array in source.get_meta("east_cpu_arrays"):
   for p:Vector3 in row[Mesh.ARRAY_VERTEX]:original.append(p);framed.append(Vector3(p.x,p.y*Base.OWNER_Y_SCALE,p.z))
 var result={"scope":"Read-only CPU fit audit, not rendered or world acceptance.","native_crown_pixel_extent":[228,235],"native_crown_bitmap_aspect":228./235.,"legacy_owner_y_scale":Base.OWNER_Y_SCALE,"legacy_owner_pixels_to_height":Base.OWNER_HEIGHT_PER_PIXEL,"eight_copy_candidate_foliage":stats(leaf_points),"eight_copy_candidate_all":stats(all_points),"intact_whole_canopy":stats(original),"whole_canopy_after_owner_y_only":stats(framed)}
 var file=FileAccess.open(Clumps.ROOT+"fit-audit.json",FileAccess.WRITE);file.store_string(JSON.stringify(result,"  "));file.close();print("CANOPY_FIT_AUDIT ",JSON.stringify(result));quit(0)
