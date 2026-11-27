extends RefCounted
## Private source-edge prototype; preserves the shared player/World owners.
const Art=preload("res://scripts/forest/forest_art.gd")
const Camera=preload("res://scripts/forest/forest_original_water_camera.gd")

static func bounds(data:Dictionary,row:Dictionary)->AABB:
 var origin=Vector2(data.origin[0],data.origin[1]);var along_x=bool(row.along_x);var span=(float(row.end)-float(row.start))*3.;var middle=(float(row.start)+float(row.end))*.5-.5
 var at=origin+(Vector2(middle,float(row.row)-.5) if along_x else Vector2(float(row.row)-.5,middle))*3.
 var sign_=1. if row.blocked_positive else -1.;at+=(Vector2.DOWN if along_x else Vector2.RIGHT)*float(data.wall_thickness)*.5*sign_
 var size_=Vector3(span,float(data.inferred_wall_height),float(data.wall_thickness)) if along_x else Vector3(float(data.wall_thickness),float(data.inferred_wall_height),span)
 return AABB(Vector3(at.x,0,at.y)-Vector3(size_.x*.5,0,size_.z*.5),size_)

static func build(parent:Node3D,camera_root:Node,data:Dictionary,raw:PackedByteArray,bits:PackedByteArray)->Array:
 var result=[];var size_=Vector2i(data.size[0],data.size[1])
 for row:Dictionary in data.runs:
  var box=bounds(data,row);var body=Art.solid(parent,box.get_center(),box.size,1)
  body.name="IlOriginalBlockedWaterEdge";body.set_meta("source_map",2000);body.set_meta("source_edge",row);body.set_meta("freyja_source_collision",true)
  var excluded=Camera.record(camera_root,body,raw,bits,size_,bool(row.along_x),int(row.row),int(row.start),int(row.end))
  assert(excluded==bool(row.camera_plain_water_eligible),"Only exact original plain-water edges receive the existing camera exemption")
  result.append({"bounds":box,"source_edge":row,"camera_water_only":excluded,"body":body})
 return result
