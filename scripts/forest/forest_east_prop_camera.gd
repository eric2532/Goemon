extends RefCounted
## Keep source walking barriers while matching this low furniture's camera height.
const Camera=preload("res://scripts/forest/forest_original_water_camera.gd")
const Solids=preload("res://scripts/forest/forest_art.gd")
const APPLIED="source_low_prop_camera_refinement"
static func apply(root:Node3D,source:int,row:Dictionary)->bool:
 if source!=31900:return false
 if root.has_meta(APPLIED):return true
 var cells:int=row.size.x*row.size.y
 for entry in[[3,3106,16824],[4,3111,0],[5,3116,17537]]:
  var cell=Vector2i(24,entry[0]);var index=cell.y*row.size.x+cell.x
  if Camera.is_open(row.bits,row.size,cell) or row.raw.decode_u16(20+index*2)!=entry[1] or row.raw.decode_u16(20+(cells+index)*2)!=entry[2]:
   root.set_meta("source_low_prop_camera_blocker","Original low furniture/floor tuple changed");return false
 var body=root.find_child("RecoveredShalenaBoundary_59",true,false) as CollisionObject3D
 if body==null:return false
 var shape=body.get_child(0) as CollisionShape3D
 if shape==null or not shape.shape is BoxShape3D:return false
 var extent:Vector3=shape.shape.size;var midpoint:Vector3=shape.position
 var expected=Vector3(row.origin.x+24.*3.-1.5,4.25,row.origin.y+12.)
 if not extent.is_equal_approx(Vector3(.04,8.5,9.)) or not midpoint.is_equal_approx(expected):
  root.set_meta("source_low_prop_camera_blocker","Original barrier extent changed");return false
 var height_=0.;var found={}
 for node:MultiMeshInstance3D in root.find_children("*","MultiMeshInstance3D",true,false):
  var serial=int(node.get_meta("source_graphic",-1))
  if serial not in[16824,17537]:continue
  # This flat map batches source props at y=0. Read the immutable mesh bounds;
  # MultiMesh instance getters require a renderer readback and fail in Dummy.
  if not node.basis.is_equal_approx(Basis.IDENTITY) or not is_zero_approx(node.position.y):continue
  height_=maxf(height_,node.multimesh.mesh.get_aabb().end.y);found[serial]=true
 if found.size()!=2 or height_<=0. or height_+.03>=8.5:
  root.set_meta("source_low_prop_camera_blocker","Measured source furniture meshes unavailable");return false
 var before=AABB(midpoint-extent*.5,extent);var split=height_+.03
 var lower=extent;lower.y=split;var upper=extent;upper.y=8.5-split
 var low_center=midpoint;low_center.y=split*.5
 var high_center=midpoint;high_center.y=(split+8.5)*.5
 var union=AABB(low_center-lower*.5,lower).merge(AABB(high_center-upper*.5,upper))
 assert(union.position.is_equal_approx(before.position) and union.size.is_equal_approx(before.size),"Camera refinement must preserve the full source player barrier")
 var high=Solids.solid(root,high_center,upper,body.collision_layer,"stone");high.name="SourceLowPropUpperBarrier"
 var low_shape=shape.shape.duplicate();low_shape.size=lower;shape.shape=low_shape;shape.position=low_center
 var exclusions:Array[RID]=[];exclusions.assign(root.get_meta(Camera.PROP_ROOT_RIDS,[]));exclusions.append(high.get_rid());root.set_meta(Camera.PROP_ROOT_RIDS,exclusions)
 root.set_meta(APPLIED,{"source":source,"cells":[[24,3],[24,4],[24,5]],"visible_height":height_,"split":split,"original_barrier":before,"full_player_collision_union":union,"upper_camera_rid":high.get_rid(),"lower_player_rid":body.get_rid()})
 return true
