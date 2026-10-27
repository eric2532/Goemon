extends SceneTree
const Runtime=preload("res://scripts/forest/crowd/army_runtime.gd")
const Target=preload("res://scripts/forest/crowd/army_enemy_target.gd")
const Contact=preload("res://scripts/forest/forest_enemy_contact.gd")
const Roles=preload("res://scripts/forest/forest_enemy_roles.gd")
var checks=0
var failures=0
func _initialize():run.call_deferred()
func run():
 var runtime=Runtime.new();runtime.configure(null);seed(71025)
 for kind in Roles.RIGID_TYPES:
  var handle=runtime.spawn(kind+1,0,kind,Vector3.ZERO,100,.4)
  var actor=Target.new();actor.runtime=runtime;actor.handle=handle;actor.variant=kind;root.add_child(actor)
  for size_ in [.5,1.0,3.0]:
   runtime.enemy_size=size_
   for yaw in [0.0,.73,PI/2,PI*1.25]:
    var point=Vector3(13,7,-11);runtime.set_pose(handle,point,yaw);actor.sync(runtime.unit_state(handle))
    var data=actor._combat_data();var original=Contact.prepare(data)
    for radius in [0.0,.2,6.0,36.0]:
     for i in 24:
      var from=point+Vector3(randf_range(-20,20),randf_range(-10,20),randf_range(-20,20))*size_
      var to=from if i%4==0 else point if i%4==1 else point+(from-point)*-1.0
      var expected=Contact.segment_contact(data,from,to,radius,original)
      var actual=actor.combat_segment_contact(from,to,radius)
      checks+=1
      if expected.is_empty()!=actual.is_empty() or (not expected.is_empty() and (expected.t!=actual.t or expected.point!=actual.point)):
       failures+=1
       if failures<5:printerr("Rigid sweep mismatch: ",kind," size=",size_," yaw=",yaw," expected=",expected," actual=",actual)
  actor.free();runtime.despawn(handle)
 runtime.free();print("ARMY_RIGID_SWEEP_RESULT checks=",checks," failures=",failures);quit(1 if failures else 0)
