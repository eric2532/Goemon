extends SceneTree
const Model=preload("res://scripts/forest/forest_model.gd")
class CountFlow extends "res://scripts/forest/forest_enemy_flow.gd":
 var validations=[]
 func corridor_clear(e:Dictionary,from:Vector3,to:Vector3,on_road:bool)->bool:
  validations.append([from,to,on_road,e.variant])
  return super.corridor_clear(e,from,to,on_road)
var checks=0
var failures=0
func check(ok:bool,label_:String):
 checks+=1
 if not ok:failures+=1;printerr("FAIL: ",label_)
func fresh():
 var m=Model.new();m.reset(41,{}, {"trees":[],"deposits":[],"buildings":[]});m.enemies.clear();m.workers.clear();m.defenders.clear();return m
func actor(id:int,pos:Vector3,role:int=0)->Dictionary:
 return {"id":id,"pos":pos,"variant":role,"path":[Vector2i(0,29),Vector2i(0,28),Vector2i(0,9)]}
func _initialize():run.call_deferred()
func run():
 var m=fresh();var flow=CountFlow.new(m)
 for i in 100:flow.route_point(actor(7*i,Vector3(float(i)*.001,0,180+float(i)*.001)),false)
 var incoming=flow.validations.filter(func(v):return Vector3(v[0]).z>179).size()
 var onward=flow.validations.size()-incoming
 check(incoming==100,"Every actor root keeps its own full incoming geometry validation")
 check(onward==1,"One hundred actors sharing a fixed lane reuse one onward certificate")
 var api=flow.has_method("onward_clear")
 check(api,"Fixed onward geometry has an explicit shared certificate path")
 if api:
  var e=actor(0,Vector3(0,0,180));var a=Vector3(0,0,174);var b=Vector3(0,0,168)
  flow.validations.clear()
  check(flow.onward_clear(e,a,b,false),"Clear fixed geometry produces a positive certificate")
  check(flow.onward_clear(e,a,b,false) and flow.validations.size()==1,"An exact positive repeat performs no new geometry query")
  flow.onward_clear(e,a+Vector3(.0001,0,0),b,false)
  check(flow.validations.size()==2,"Distinct exact source positions never alias in a quantized key")
  flow.onward_clear(actor(0,e.pos,2),a,b,false)
  check(flow.validations.size()==3,"Different actual footprint radii have separate certificates")
  check(not flow.onward_clear(e,a,b,true) and flow.validations.size()==4,"Road-constrained geometry does not reuse an unconstrained certificate")
  check(not flow.onward_clear(e,a,b,true) and flow.validations.size()==4,"Negative certificates are reused as exact geometry results")
  m.trees[Vector2i(0,28)]=1.0;m.rebuild_navigation()
  check(not flow.onward_clear(e,a,b,false) and flow.validations.size()==5,"A geometry revision invalidates previously clear terrain")
  check(not flow.onward_clear(e,a,b,false) and flow.validations.size()==5,"Failed geometry also shares its certificate after invalidation")
  m.trees.clear();m.rebuild_navigation()
  check(flow.onward_clear(e,a,b,false) and flow.validations.size()==6,"A later geometry revision restores newly clear paths")
  flow=CountFlow.new(m)
  for index in 4200:
   var p=Vector3(float(index)*.0001,0,160)
   flow.onward_clear(e,p,p+Vector3(0,0,1),false)
  check(flow.onward_certificates.size()<=4096,"Shared fixed-geometry certificates have bounded storage")
  var n=flow.validations.size();flow.onward_clear(e,Vector3(0,0,160),Vector3(0,0,161),false)
  check(flow.validations.size()==n+1,"Capacity eviction recomputes geometry rather than returning a stale result")
 print("SOLDIER_FLOW_CERTIFICATE_TESTS checks=",checks," failures=",failures)
 quit(1 if failures else 0)
