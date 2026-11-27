extends RefCounted
## Cached original-map camera exclusions; full source movement colliders stay intact.
const ROOT_RIDS="original_map_water_camera_exclusions"
const PROP_ROOT_RIDS="original_map_low_prop_camera_exclusions"
const WATER_BOUNDARY="original_map_navigation_boundary_water_only"
var lateral=PhysicsRayQueryParameters3D.new()
var probe=PhysicsRayQueryParameters3D.new()
var _root_id=0
var _water:Array[RID]=[]
var _cutaway:Array[RID]=[]
var _initialized=false

func _init():
 lateral.collision_mask=1;probe.collision_mask=1

static func is_open(bits:PackedByteArray,size_:Vector2i,cell:Vector2i)->bool:
 if not Rect2i(Vector2i.ZERO,size_).has_point(cell):return false
 var i=cell.y*size_.x+cell.x
 return (bits[i>>3]&(1<<(i&7)))!=0

static func water_only_run(raw:PackedByteArray,bits:PackedByteArray,size_:Vector2i,along_x:bool,row:int,start:int,end:int)->bool:
 var cells=size_.x*size_.y
 if size_.x<=0 or size_.y<=0 or raw.size()<20+cells*4 or bits.size()<(cells+7)/8:return false
 var rows=size_.y if along_x else size_.x;var columns=size_.x if along_x else size_.y
 if row<0 or row>rows or start<0 or start>=end or end>columns:return false
 for column in range(start,end):
  var a=Vector2i(column,row-1) if along_x else Vector2i(row-1,column)
  var b=Vector2i(column,row) if along_x else Vector2i(row,column)
  if is_open(bits,size_,a)==is_open(bits,size_,b):return false
  var blocked=b if is_open(bits,size_,a) else a
  if not Rect2i(Vector2i.ZERO,size_).has_point(blocked):return false
  var i=blocked.y*size_.x+blocked.x;var floor_=raw.decode_u16(20+i*2)
  if floor_<5000 or floor_>5008 or raw.decode_u16(20+(cells+i)*2)!=0:return false
 return true

static func record(root:Node,body:CollisionObject3D,raw:PackedByteArray,bits:PackedByteArray,size_:Vector2i,along_x:bool,row:int,start:int,end:int)->bool:
 if not water_only_run(raw,bits,size_,along_x,row,start,end):return false
 body.set_meta(WATER_BOUNDARY,true)
 var rids:Array[RID]=[]
 if root.has_meta(ROOT_RIDS):rids=root.get_meta(ROOT_RIDS)
 rids.append(body.get_rid());root.set_meta(ROOT_RIDS,rids)
 return true

func sync(root:Node,cutaway:Array[RID]=[])->bool:
 var root_id=root.get_instance_id() if is_instance_valid(root) else 0
 var map_changed=not _initialized or root_id!=_root_id
 if not map_changed and cutaway==_cutaway:return false
 if map_changed:
  _root_id=root_id;_water.clear()
  if root_id!=0:_water.assign(root.get_meta(ROOT_RIDS,[]))
  if root_id!=0:_water.append_array(root.get_meta(PROP_ROOT_RIDS,[]))
 _cutaway.assign(cutaway)
 var exclusions:Array[RID]=[];exclusions.assign(_water);exclusions.append_array(_cutaway)
 lateral.exclude=exclusions;probe.exclude=exclusions;_initialized=true
 return true
