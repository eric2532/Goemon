extends SceneTree
const Runtime=preload("res://scripts/forest/crowd/army_runtime.gd")
const Snapshot=preload("res://scripts/forest/crowd/army_snapshot.gd")
var checks=0
var failures=0
func check(ok:bool,label_:String):
 checks+=1
 if not ok:failures+=1;printerr("FAIL: ",label_)
func pose_error(a:Transform3D,b:Transform3D)->float:
 return maxf(a.origin.distance_to(b.origin),maxf(a.basis.x.distance_to(b.basis.x),maxf(a.basis.y.distance_to(b.basis.y),a.basis.z.distance_to(b.basis.z))))
func _initialize():run.call_deferred()
func run():
 var army=Runtime.new();army.configure(null)
 var parents=[];var actors=[];var enemies={};var allies={};var rows={};var handles=[]
 for p in 2:
  var parent=Node3D.new();root.add_child(parent);parents.append(parent)
  if p==1:parent.transform=Transform3D(Basis.from_euler(Vector3(.2,.7,-.1)).scaled(Vector3(1.1,.9,1.3)),Vector3(14,5,-9))
  for team in 2:
   var id=(p+1)*(1 if team==0 else -1);var h:int=army.spawn(id,team,0 if team==0 else 11,Vector3.ZERO,192.125,.4 if team else 3.9);handles.append(h)
   var actor=load("res://scripts/forest/crowd/army_enemy_target.gd" if team==0 else "res://scripts/forest/crowd/army_ally_target.gd").new();actor.runtime=army
   if team==0:actor.variant=0;enemies[id]=actor;rows[id]={}
   else:allies[id]=actor
   parent.add_child(actor);actors.append(actor)
 for sample in 256:
  for i in 4:army.set_pose(handles[i],Vector3(sin(sample*.27+i)*80,3+sample%9,cos(sample*.71+i)*80),float(sample-128)*.517+i)
  var data=army.render_snapshot();var view=Snapshot.new(data);var expected=[];var contacts=[];var shapes=[]
  for i in 4:
   var actor=actors[i];actor.sync_snapshot(view,i);expected.append(actor.global_transform)
   contacts.append(actor.combat_contact_point(data.positions[i]+Vector3(3,2,-4)) if i%2==0 else Vector3.ZERO)
   shapes.append(actor.get_child(0).global_transform if i%2==0 else Transform3D.IDENTITY)
   actor.position+=Vector3(4,2,-3);actor.rotation.y+=.3
  check(army.native.sync_facades(data,rows,enemies,allies,view)==4,"Every engine-transferred facade retains exactly one state callback")
  for i in 4:
   var actor=actors[i]
   check(pose_error(actor.global_transform,expected[i])<.00001 and actor.hp==data.hp[i],"Engine calls preserve original pose, parent transforms, yaw winding and double HP")
   if i%2==0:
    check(actor._yaw==data.yaw[i] and actor.combat_contact_point(data.positions[i]+Vector3(3,2,-4)).distance_to(contacts[i])<.00001 and pose_error(actor.get_child(0).global_transform,shapes[i])<.00001,"Exact raw combat heading and original physical/fitted contacts remain aligned")
 for parent in parents:parent.free()
 army.free();print("ARMY_ENGINE_POSE_RESULT checks=",checks," failures=",failures);quit(1 if failures else 0)
