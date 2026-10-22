extends SceneTree
var checks=0
var failures=0
func check(value:bool,label:String):
 checks+=1
 if not value:failures+=1;printerr("FAIL ",label)
func _initialize():call_deferred("_run")
func _run():
 var mesh=load("res://assets/maps/blood_gulch/terrain.res") as ArrayMesh
 check(mesh.get_surface_count()==2,"native boundary cap exists")
 if mesh.get_surface_count()<2:quit(1);return
 var world=Node3D.new();root.add_child(world)
 var body=StaticBody3D.new();world.add_child(body)
 var shape=CollisionShape3D.new();shape.shape=load("res://assets/maps/blood_gulch/collision.res");body.add_child(shape)
 await physics_frame
 await physics_frame
 var points=mesh.surface_get_arrays(1)[Mesh.ARRAY_VERTEX] as PackedVector3Array
 var space=world.get_world_3d().direct_space_state
 var stride=maxi(3,(points.size()/100/3)*3)
 for at in range(0,points.size(),stride):
  var p=(points[at]+points[at+1]+points[at+2])/3.
  var query=PhysicsRayQueryParameters3D.create(p+Vector3.UP*30,p-Vector3.UP*30)
  var hit=space.intersect_ray(query)
  check(not hit.is_empty(),"native boundary has physical floor support")
  if not hit.is_empty():check(absf(hit.position.y-p.y)<.002,"visible boundary and physical support agree")
 for p in [Vector3(-225,0,0),Vector3(225,0,0),Vector3(0,0,-225),Vector3(0,0,225)]:
  var query=PhysicsRayQueryParameters3D.create(p+Vector3.UP*100,p-Vector3.UP*100)
  check(space.intersect_ray(query).is_empty(),"outside actual native map remains empty")
 print("BLOOD_GULCH_BOUNDARY_SUPPORT_CHECKS ",checks," failures ",failures)
 quit(1 if failures else 0)
