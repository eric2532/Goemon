extends SceneTree
const Model=preload("res://scripts/forest/forest_model.gd")
class Counter extends RefCounted:
 func building_point(_b:Dictionary,_point:Vector3)->Vector3:return Vector3.ZERO
 var calls=0
 func approach(_e:Dictionary,_b:Dictionary)->Dictionary:calls+=1;return {}
 func line_clear(_a:Vector3,_b:Vector3,_ignore:int=-1)->bool:calls+=1;return true
var checks=0
var failures=0
func _initialize():run.call_deferred()
func check(ok:bool,label_:String):
 checks+=1
 if not ok:failures+=1;printerr("FAIL: ",label_)
func fresh():
 var m=Model.new();m.reset(41,{}, {"trees":[],"deposits":[],"buildings":[]});m.workers.clear();m.defenders.clear();m.phase="wave";m.waves.pending=0;return m
func run():
 for role in [0,3]:
  var m=fresh();var e=m.waves.spawn_enemy(role,Vector3(60,0,60));var count=Counter.new();m.waves.navigation=count
  check(not m.waves.in_reach(e,"hero",0,Vector3(100,0,60)) and count.calls==0,"Distant soldier targets are rejected before native cover queries (%d)"%role)
  e.facing=0.0;e.soldier_charge_tick=15.0;count.calls=0
  check(m.waves.turn(e,Vector3(60,0,30),.05) and count.calls==0,"Committed heading reuses authoritative swept movement rather than tracing the whole route (%d)"%role)
  m=fresh();e=m.waves.spawn_enemy(role,Vector3(57.1,0,60));e.facing=0;e.retaliation=20
  var near=Vector3(62.9,0,60)
  check(m.cell_of(e.pos)==m.cell_of(near) and not m.waves.soldier_melee_proximity(e,"hero",0,near),"Enlarged samecell fixture begins beyond actual source weapon contact (%d)"%role)
  for frame in 180:m.waves.tick_enemy(e,1.0/30,near)
  check(m.events.any(func(event):return event.kind=="hero_hit") and e.pos.x>57.3,"Samecell targets outside weapon reach trigger a safe final approach (%d)"%role)
  check(m.waves.navigation.fitted_blocker(e,e.pos)<0,"Final approach retains native solid contact (%d)"%role)
  m=fresh();e=m.waves.spawn_enemy(role,Vector3(57.1,0,57.1));e.facing=0;e.retaliation=20
  for frame in 240:m.waves.tick_enemy(e,1.0/30,Vector3(62.9,0,62.9))
  check(m.events.any(func(event):return event.kind=="hero_hit"),"Long diagonal samecell targets first reach the grid center then close safely (%d)"%role)
  m=fresh();e=m.waves.spawn_enemy(role,Vector3(60,0,60));count=Counter.new();m.waves.navigation=count
  m.waves.rebuild_path(e,Vector3.ZERO,"building",1);m.waves.rebuild_path(e,Vector3.ZERO,"building",1)
  check(count.calls==1,"An unreachable route is briefly cached instead of searched every crowd tick (%d)"%role)
  m.navigation_revision+=1;m.waves.rebuild_path(e,Vector3.ZERO,"building",1)
  check(count.calls==2,"Changing native geometry immediately invalidates an unreachable route (%d)"%role)
  m=fresh();m.hero_targetable=false;var wall=m._make_building("wall",Vector2i(10,8),0,1);var hp:float=wall.hp
  e=m.waves.spawn_enemy(role,Vector3(60,0,66));e.route_obstacle=wall.id
  for frame in 240:m.waves.tick_enemy(e,1.0/30,Vector3(0,0,18))
  check(wall.hp<hp,"Short native melee reaches a wall despite sixmetre navigation cells (%d)"%role)
  check(m.waves.navigation.fitted_blocker(e,e.pos)<0,"Soldier reaches the wall without entering solid geometry (%d)"%role)
 print("THIRSTQUENCHER_NAVIGATION_RESULT checks=",checks," failures=",failures);quit(1 if failures else 0)
