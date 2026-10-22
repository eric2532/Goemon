extends SceneTree
const Model=preload("res://scripts/forest/forest_model.gd")
class Navigation extends "res://scripts/forest/forest_enemy_navigation.gd":
 var probes=0
 func terrain_clear(p:Vector3,radius:float)->bool:
  probes+=1;return super.terrain_clear(p,radius)
var checks=0
var failures=0
func check(ok:bool,label_:String):
 checks+=1
 if not ok:failures+=1;printerr("FAIL: ",label_)
func _initialize():run.call_deferred()
func run():
 var m=Model.new();m.reset(42,{}, {"trees":[],"deposits":[],"buildings":[]});var nav=Navigation.new(m);m.waves.navigation=nav
 var flow=m.waves.flow;var a=Vector3(0,0,180);var b=Vector3(0,0,174);var e={"variant":0}
 check(flow.corridor_clear(e,a,b,false),"A supported incoming soldier lane remains traversable")
 var n=nav.probes
 check(flow.corridor_clear({"variant":1},a,b,false) and nav.probes==n,"Equal footprints reuse an exact incoming corridor instead of resampling unchanged terrain")
 flow.corridor_clear(e,a+Vector3(.0001,0,0),b,false)
 check(nav.probes>n,"A different actual root receives its own native incoming sweep")
 n=nav.probes;flow.corridor_clear({"variant":2},a,b,false)
 check(nav.probes>n,"Different footprint radii retain independent clearance proofs")
 check(not flow.corridor_clear(e,a,b,true),"A road-restricted query never reuses an unrestricted lane")
 m.trees[Vector2i(0,29)]=1.0;m.rebuild_navigation();n=nav.probes
 check(not flow.corridor_clear(e,a,b,false) and nav.probes>n,"A new tree invalidates an earlier clear corridor immediately")
 n=nav.probes
 check(not flow.corridor_clear(e,a,b,false) and nav.probes==n,"An exact repeated blocked corridor does not repeat failed terrain probes")
 m.trees.clear();m.rebuild_navigation()
 check(flow.corridor_clear(e,a,b,false),"Removing the obstruction restores the original clear result")
 var supported=flow.get("corridor_certificates") is Dictionary
 check(supported,"Incoming certificate storage is bounded and inspectable")
 if supported:
  for index in 16500:
   var from=Vector3(index*.00001,0,180)
   flow.corridor_clear(e,from,from+Vector3(0,0,.01),false)
  check(flow.corridor_certificates.size()<=16384,"Exact-root certificates cannot grow without a storage bound")
 print("SOLDIER_CORRIDOR_REUSE_RESULT checks=",checks," failures=",failures);quit(1 if failures else 0)
