extends SceneTree
const Filter=preload("res://scripts/forest/forest_original_water_camera.gd")
var checks=0
var failures=0
func check(value:bool,message:String):
 checks+=1
 if not value:failures+=1;push_error(message)
func _initialize():run.call_deferred()
func run():
 var size_=Vector2i(4,4);var raw=PackedByteArray();raw.resize(20+size_.x*size_.y*6)
 var bits=PackedByteArray([15,0]) # First source row is walkable; the next row is water.
 for x in 4:raw.encode_u16(20+(4+x)*2,5000+x)
 check(Filter.water_only_run(raw,bits,size_,true,1,0,4),"All-water horizontal run eligible")
 check(not Filter.water_only_run(raw,bits,size_,true,0,0,4),"Outside-map boundary retained")
 raw.encode_u16(20+(16+6)*2,12345)
 check(not Filter.water_only_run(raw,bits,size_,true,1,0,4),"Water with one object retains whole mixed run")
 check(Filter.water_only_run(raw,bits,size_,true,1,0,2),"Separate unchanged pure-water run eligible")
 raw.encode_u16(20+(16+6)*2,0);raw.encode_u16(20+6*2,0)
 check(not Filter.water_only_run(raw,bits,size_,true,1,0,4),"Void mixed with water retained")
 raw.encode_u16(20+6*2,5010)
 check(not Filter.water_only_run(raw,bits,size_,true,1,0,4),"Unconfirmed water ID retained")
 raw.encode_u16(20+6*2,5008)
 check(Filter.water_only_run(raw,bits,size_,true,1,0,4),"Confirmed upper water ID eligible")
 check(not Filter.water_only_run(PackedByteArray(),bits,size_,true,1,0,4),"Missing source planes retained")
 check(not Filter.water_only_run(raw,PackedByteArray(),size_,true,1,0,4),"Missing walk bits retained")
 check(not Filter.water_only_run(raw,bits,size_,true,1,2,2),"Empty run retained")
 var vertical=PackedByteArray([17,17]);var vertical_raw=raw.duplicate()
 for y in 4:vertical_raw.encode_u16(20+(y*4+1)*2,5004)
 check(Filter.water_only_run(vertical_raw,vertical,size_,false,1,0,4),"Vertical water boundary eligible")
 var stage=Node3D.new();get_root().add_child(stage)
 var water=body(stage,Vector3(0,4.25,0),Vector3(.04,8.5,12))
 var real_wall=body(stage,Vector3(4,4.25,0),Vector3(.2,8.5,12))
 var shape=water.get_child(0);var original_shape=shape.shape;var original_transform=shape.transform
 check(Filter.record(stage,water,raw,bits,size_,true,1,0,4),"Only eligible body registered")
 check(not Filter.record(stage,real_wall,raw,bits,size_,true,0,0,4),"Real/unsupported boundary not registered")
 check(water.collision_layer==1 and water.collision_mask==0 and shape.shape==original_shape and shape.transform==original_transform,"Tagging preserves physical body, shape and transform")
 var filter=Filter.new()
 check(filter.sync(stage),"Initial root binds exclusions")
 check(not filter.sync(stage),"Unchanged root/list does not rebuild or copy query exclusions")
 check(filter.probe.exclude==[water.get_rid()] and filter.lateral.exclude==filter.probe.exclude,"Both camera queries reuse same eligible exclusions")
 var cutaway:Array[RID]=[real_wall.get_rid()]
 check(filter.sync(stage,cutaway) and filter.probe.exclude.size()==2,"Existing cutaway API merges independently")
 check(not filter.sync(stage,cutaway),"Unchanged small cutaway list does not rebuild")
 check(filter.sync(stage),"Leaving room restores water-only exclusions")
 await physics_frame;await physics_frame
 var physics=stage.get_world_3d().direct_space_state
 var from=Vector3(-4,2,0);var to=Vector3(8,2,0)
 var ordinary=PhysicsRayQueryParameters3D.create(from,to,1)
 var player_hit=physics.intersect_ray(ordinary)
 check(player_hit.get("collider")==water,"Unmodified player/attack collision still hits invisible water boundary")
 filter.probe.from=from;filter.probe.to=to
 var camera_hit=physics.intersect_ray(filter.probe)
 check(camera_hit.get("collider")==real_wall,"Camera passes water-only boundary but stops at real wall")
 var next=Node3D.new();get_root().add_child(next)
 check(filter.sync(next) and filter.probe.exclude.is_empty(),"Map root change drops obsolete RIDs")
 check(not filter.sync(next),"Stable empty map does not rebuild exclusions")
 stage.queue_free();next.queue_free()
 print("ORIGINAL_WATER_CAMERA_RESULT checks=",checks," failures=",failures)
 quit(failures)
func body(parent:Node3D,at:Vector3,size_:Vector3)->StaticBody3D:
 var result=StaticBody3D.new();result.collision_layer=1;result.collision_mask=0;parent.add_child(result)
 var shape=CollisionShape3D.new();var box=BoxShape3D.new();box.size=size_;shape.shape=box;shape.position=at;result.add_child(shape)
 return result
