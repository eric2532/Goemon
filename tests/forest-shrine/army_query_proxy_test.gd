extends SceneTree
const Runtime=preload("res://scripts/forest/crowd/army_runtime.gd")
var checks=0
var failures=0
func check(ok:bool,label_:String):
 checks+=1
 if not ok:failures+=1;printerr("FAIL: ",label_)
func _initialize():run.call_deferred()
func run():
 var army=Runtime.new();army.configure(null)
 var h:int=army.spawn(1,0,0,Vector3.ZERO,192,3.9)
 var actor=preload("res://scripts/forest/crowd/army_enemy_target.gd").new();actor.runtime=army;actor.handle=h;actor.variant=0;root.add_child(actor)
 check(PhysicsServer3D.body_get_mode(actor.get_rid())==PhysicsServer3D.BODY_MODE_STATIC,"Native enemy proxies remain queryable without participating in kinematic pair generation")
 check(actor.collision_layer==4 and actor.collision_mask==0,"Original player query layer and no physical response remain unchanged")
 var previous=Vector3(-1000,0,0)
 for i in 12:
  var point=Vector3(i*23,2+i%3,i*11);army.set_pose(h,point,i*.57);actor.sync(army.unit_state(h))
  await physics_frame;await physics_frame
  var query=PhysicsRayQueryParameters3D.create(point+Vector3(15,3,0),point+Vector3(-15,3,0),4)
  var hit=actor.get_world_3d().direct_space_state.intersect_ray(query)
  check(hit.get("collider")==actor,"Moved and rotated proxy rays still identify the original independent Ninja facade")
  if i>0:
   query=PhysicsRayQueryParameters3D.create(previous+Vector3(10,3,0),previous+Vector3(-10,3,0),4)
   check(actor.get_world_3d().direct_space_state.intersect_ray(query).is_empty(),"No old hitbox remains after a full physics pose update")
  check(actor.combat_bounds().grow(0.00001).has_point(actor.combat_contact_point(point+Vector3(3,3,4))),"Fitted contacts remain aligned with the actual query body")
  previous=point
 actor.free();army.free();print("ARMY_QUERY_PROXY_RESULT checks=",checks," failures=",failures);quit(1 if failures else 0)
