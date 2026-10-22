extends SceneTree
## Exact nearest-part identity and contact geometry must survive spatial pruning.
const Contact=preload("res://scripts/forest/forest_enemy_contact.gd")
var checks=0
var failures=0
var cases=[]
func _initialize():run.call_deferred()
func check(ok:bool,label_:String):
 checks+=1
 if not ok:failures+=1;printerr("FAIL: ",label_)
# Frozen exhaustive oracle: each original part is queried in native order.
# No candidate bounds or candidate ordering are used by this reference.
func exhaustive(data:Dictionary,point:Vector3,prepared:Dictionary,shape_index:int=-1)->Vector3:
 var best:Vector3=prepared.pos;var distance=INF
 for index in prepared.shapes.size():
  if shape_index>=0 and index!=shape_index:continue
  var item:Dictionary=prepared.shapes[index]
  var pose:Transform3D=prepared.world_poses[index]
  var inverse:Transform3D=prepared.inverses[index]
  var local=inverse*point
  var candidate:Vector3
  if item.get("box",false):candidate=local.clamp(item.bounds.position,item.bounds.end)
  elif item.group=="capsule":candidate=Contact._capsule_contact(item,local)
  else:
   var interval=Contact._hull_interval(item,local,item.center,0.0)
   candidate=local.lerp(item.center,interval.x) if interval.x>=0 else item.center
  candidate=pose*candidate
  var gap=point.distance_squared_to(candidate)
  if gap<distance:best=candidate;distance=gap
 return best
func verify(data:Dictionary,point:Vector3,prepared:Dictionary,index:int=-1):
 var expected=exhaustive(data,point,prepared,index)
 var actual=Contact.contact(data,point,prepared,index)
 check(actual.distance_to(expected)<.00001,"nearest contact equals exhaustive geometry at %s (part %d)"%[point,index])
func run():
 var random=RandomNumberGenerator.new();random.seed=195377
 for blocks in [false,true]:
  for role in 5:
   var data={"variant":role,"pos":Vector3(90,2,-100),"facing":.53,"walk_phase":1.4,"velocity":Vector3(1,0,-2),"block_contacts":blocks}
   var roots=[];var parts=[]
   for member in 5:
    var scale_=1.0 if member==0 else [.7,.93,1.3,2.0][member-1]
    var basis=Basis.from_euler(Vector3(.03*member,.71*member,-.02*member)).scaled(Vector3.ONE*scale_)
    roots.append(Transform3D(basis,data.pos+Vector3((member%3)*6.3,member*.07,int(member/3)*8.4)))
    parts.append(data)
   var prepared=Contact.prepare(data,{"roots":roots,"parts":parts})
   for sample_ in 220:
    var point=data.pos+Vector3(random.randf_range(-30,35),random.randf_range(-3,30),random.randf_range(-25,30))
    verify(data,point,prepared)
    if blocks and role in [0,1,3]:cases.append({"data":data,"point":point,"prepared":prepared})
   for index in prepared.shapes.size():
    var pose:Transform3D=prepared.world_poses[index];var box:AABB=prepared.shapes[index].bounds
    for local in [box.position,box.end,box.get_center(),Vector3(box.position.x,box.end.y,box.end.z)]:
     # Face/vertex contact and the next float32 position outside its face.
     for epsilon in [-.00001,0.0,.00001]:
      var point=pose*(local+Vector3.ONE*epsilon)
      verify(data,point,prepared);verify(data,point,prepared,index)
   verify(data,data.pos,prepared,prepared.shapes.size()+1)
   var legacy=prepared.duplicate();legacy.erase("shape_bounds")
   verify(data,data.pos+Vector3(7,1,4),legacy)
 # Two equally distant parts must return the first part's point.
 var box=BoxShape3D.new();box.size=Vector3.ONE*2
 var item={"group":"body","box":true,"shape":box,"bounds":AABB(-Vector3.ONE,Vector3.ONE*2)}
 var tied={"pos":Vector3.ZERO,"shapes":[item,item],"world_poses":[Transform3D(Basis.IDENTITY,Vector3(-3,0,0)),Transform3D(Basis.IDENTITY,Vector3(3,0,0))],"inverses":[Transform3D(Basis.IDENTITY,Vector3(3,0,0)),Transform3D(Basis.IDENTITY,Vector3(-3,0,0))],"shape_bounds":[AABB(Vector3(-4,-1,-1),Vector3.ONE*2),AABB(Vector3(2,-1,-1),Vector3.ONE*2)]}
 check(Contact.contact({},Vector3.ZERO,tied)==Vector3(-2,0,0),"equal-distance contacts preserve first-part order")
 tied.shape_bounds[1]=AABB(Vector3.ONE*-10,Vector3.ONE*20)
 check(Contact.contact({},Vector3.ZERO,tied)==Vector3(-2,0,0),"a later part with a looser bound cannot win an exact tie")
 # Same-run, alternating timing avoids a machine-specific frame-time limit.
 var reference_times=[];var candidate_times=[]
 for trial in 5:
  var start=Time.get_ticks_usec()
  for repeat_ in 8:
   for row in cases:exhaustive(row.data,row.point,row.prepared)
  reference_times.append(Time.get_ticks_usec()-start)
  start=Time.get_ticks_usec()
  for repeat_ in 8:
   for row in cases:Contact.contact(row.data,row.point,row.prepared)
  candidate_times.append(Time.get_ticks_usec()-start)
 reference_times.sort();candidate_times.sort()
 var ratio=float(candidate_times[2])/float(reference_times[2])
 print("CONTACT_QUERY_TIMING reference_us=",reference_times[2]," candidate_us=",candidate_times[2]," ratio=",ratio)
 if "--benchmark" in OS.get_cmdline_user_args():check(ratio<.85,"prepared contact query removes at least 15 percent of exhaustive work")
 print("FOREST_CONTACT_QUERY_RESULT checks=",checks," failures=",failures)
 quit(1 if failures else 0)
