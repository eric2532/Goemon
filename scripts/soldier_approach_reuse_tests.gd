extends SceneTree
const Model=preload("res://scripts/forest/forest_model.gd")
class Navigation extends "res://scripts/forest/forest_enemy_navigation.gd":
 var searches=0
 func route(e:Dictionary,destination:Vector3)->Array:
  searches+=1;return super.route(e,destination)
class Barrier extends "res://scripts/forest/forest_ramparts.gd":
 func cliff_cell(cell:Vector2i)->bool:return cell.y==10
var checks=0
var failures=0
func check(ok:bool,label_:String):
 checks+=1
 if not ok:failures+=1;printerr("FAIL: ",label_)
func fresh():
 var m=Model.new();m.reset(41,{}, {"trees":[],"deposits":[],"buildings":[]});m.waves.navigation=Navigation.new(m);return m
func _initialize():run.call_deferred()
func run():
 var m=fresh();var nav=m.waves.navigation;var e={"pos":Vector3(0,0,180),"variant":0}
 var first=nav.approach(e,m.shrine());check(not first.is_empty(),"An enlarged soldier has a valid castle approach")
 var n=nav.searches;var original=first.duplicate(true)
 first.path.pop_front()
 var again=nav.approach(e,m.shrine())
 check(again==original and nav.searches==n,"An exact repeated castle approach shares searches but owns an independent path")
 e.pos.x+=.0001;nav.approach(e,m.shrine())
 check(nav.searches>n,"Different actual roots never reuse an offset approach certificate")
 n=nav.searches;e.variant=1;nav.approach(e,m.shrine())
 check(nav.searches>n,"Gun and melee approaches keep their different attack ranges")
 n=nav.searches;m.rebuild_navigation();nav.approach(e,m.shrine())
 check(nav.searches>n,"Building or tree navigation changes force an immediate fresh approach")
 m=fresh();m.terrain=Barrier.new();m.rebuild_navigation();nav=m.waves.navigation;e={"pos":Vector3(0,0,180),"variant":0}
 check(nav.approach(e,m.shrine()).is_empty(),"A full-width unsupported barrier prevents a castle approach")
 n=nav.searches
 check(nav.approach(e,m.shrine()).is_empty() and nav.searches==n,"A stationary blocked crowd does not repeat all failed castle searches")
 m.terrain=load("res://scripts/forest/forest_ramparts.gd").new();m.rebuild_navigation()
 check(not nav.approach(e,m.shrine()).is_empty(),"Restoring supported terrain invalidates a failed approach certificate")
 var storage=nav.get("approach_cache") is Dictionary
 check(storage,"Approach certificates have bounded storage")
 if storage:
  for index in 8192:nav.approach_cache[index]={}
  e.pos.x+=.01;nav.approach(e,m.shrine())
  check(nav.approach_cache.size()<=8192,"Capacity eviction recomputes real geometry with bounded storage")
 print("SOLDIER_APPROACH_REUSE_RESULT checks=",checks," failures=",failures);quit(1 if failures else 0)
