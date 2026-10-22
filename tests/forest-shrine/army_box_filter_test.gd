extends SceneTree
class State extends RefCounted:
 var next_id=0
class Arena extends Node3D:
 var army_runtime
 var enemies=[]
 var model=State.new()
 func forest_enemy_visible(_enemy):return true
var checks=0
var failures=0
func check(ok,label_):
 checks+=1
 if not ok:failures+=1;printerr("FAIL: ",label_)
func _initialize():run.call_deferred()
func run():
 var runtime=load("res://scripts/forest/crowd/army_runtime.gd").new();runtime.configure(null)
 if not runtime.native.has_method("filter_boxes"):
  check(false,"Shared native filtering needs an owned immutable box snapshot");runtime.free();finish();return
 var minimum=PackedVector3Array();var maximum=PackedVector3Array();seed(91021)
 for i in 500:
  var point=Vector3(randf_range(-100,100),randf_range(-10,30),randf_range(-100,100));minimum.append(point);maximum.append(point+Vector3(randf_range(.1,20),randf_range(.1,20),randf_range(.1,20)))
 minimum.append(Vector3(NAN,0,0));maximum.append(Vector3.ONE)
 for i in 100:
  var point=Vector3(randf_range(-100,100),randf_range(-10,30),randf_range(-100,100));var end=point+Vector3(10,10,10);var expected=PackedInt64Array()
  for j in minimum.size():
   if not minimum[j].is_finite() or not maximum[j].is_finite() or not (maximum[j].x<point.x or minimum[j].x>end.x or maximum[j].y<point.y or minimum[j].y>end.y or maximum[j].z<point.z or minimum[j].z>end.z):expected.append(j)
  check(runtime.native.filter_boxes(minimum,maximum,point,end)==expected,"Native filtering keeps exact overlaps, overflow and original hit order")
 var snapshot=minimum;minimum=minimum.duplicate();minimum[0]=Vector3(999,999,999)
 check(snapshot[0]!=minimum[0],"A captured packed snapshot survives later owner's geometry replacement")
 check(runtime.native.filter_boxes(snapshot,maximum,Vector3(-INF,-INF,-INF),Vector3(INF,INF,INF)).size()==snapshot.size(),"Unbounded requests conservatively retain every target")
 var arena=Arena.new();arena.army_runtime=runtime;root.add_child(arena);runtime.game_ref=weakref(arena)
 for i in 100:
  var handle:int=runtime.spawn(i+1,0,0,Vector3(i*4,0,50),192,3.9)
  var actor=runtime.enemy_target(i+1);actor.sync(runtime.unit_state(handle));arena.enemies.append(actor)
 var director=load("res://scripts/forest/explorer_helpers.gd").new();director.game=arena;director.refresh_targets()
 check(director.melee_grid.is_empty() and director.projectile_grid.is_empty(),"Native armies filter captured packed boxes without rebuilding GDScript cell dictionaries")
 var center=Vector3(12,0,50);var radius=5.0;var rows=director.melee_candidates(center,radius);var expected=[]
 for row in director.melee_rows:
  var box:AABB=row.bounds
  if not (box.end.x<center.x-radius or box.position.x>center.x+radius or box.end.z<center.z-radius or box.position.z>center.z+radius):expected.append(row.enemy)
 check(rows.map(func(row):return row.enemy)==expected,"Native melee broad phase retains every intersecting fitted box in insertion order")
 director.free();runtime.clear();arena.free();runtime.free();finish()
func finish():
 print("ARMY_BOX_FILTER_RESULT checks=",checks," failures=",failures);quit(1 if failures else 0)
