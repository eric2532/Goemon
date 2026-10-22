extends SceneTree
class CountedTarget extends "res://scripts/forest/crowd/army_enemy_target.gd":
 var bounds_calls=0
 func combat_bounds()->AABB:
  bounds_calls+=1;return super.combat_bounds()
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
 for i in 2000:
  var kind:int=[0,1,3][i%3];var point=Vector3(i*4,(i%4)*3,50)
  var handle:int=runtime.spawn(i+1,0,kind,point,192,3.9);runtime.set_pose(handle,point,(i%7)*.2)
  var actor=CountedTarget.new();actor.runtime=runtime;actor.handle=handle;actor.forest_id=i+1;actor.variant=kind;arena.add_child(actor);actor.sync(runtime.unit_state(handle));arena.enemies.append(actor)
  runtime.enemies[i+1]=actor;runtime.register_actor_facade(actor)
 arena.enemies.reverse()
 var director=load("res://scripts/forest/explorer_helpers.gd").new();director.game=arena;director.refresh_targets()
 check(director.projectile_grid.is_empty(),"Native armies filter captured packed boxes without rebuilding GDScript cell dictionaries")
 for actor in arena.enemies:actor.bounds_calls=0
 var generation:int=director.target_generation
 var center=Vector3(12,0,50);var radius=5.0;var rows=director.melee_candidates(center,radius);var expected=[]
 for row in director.melee_rows:
  var box:AABB=row.bounds
  if not (box.end.x<center.x-radius or box.position.x>center.x+radius or box.end.z<center.z-radius or box.position.z>center.z+radius):expected.append(row.enemy)
 check(rows.map(func(row):return row.enemy)==expected,"Native melee broad phase retains every intersecting fitted box in insertion order")
 var fitted=0
 for actor in arena.enemies:fitted+=actor.bounds_calls
 check(fitted>0 and fitted<16,"A local melee query resolves nearby native-grid rows rather than copying 2000 fitted bounds")
 check(director.target_generation==generation,"Local melee never rebuilds or invalidates the shared projectile snapshot")
 check(director.closest_target(center,8)==director._closest_from_rows(director.target_rows,center,8),"Local acquisition retains nearest fitted contact and source tie order")
 var captured=director.projectile_centers;var target=arena.enemies[0];runtime.set_pose(target.handle,center,0);target.sync(runtime.unit_state(target.handle))
 check(director.melee_candidates(center,0).any(func(row):return row.enemy==target),"A second same-frame local query uses the native unit's updated position")
 target.dead=true
 check(not director.melee_candidates(center,0).any(func(row):return row.enemy==target),"Local candidate reads immediately reject a killed target")
 check(director.projectile_centers==captured and director.target_generation==generation,"Nested melee leaves captured projectile geometry and indices intact")
 director.free();runtime.clear();arena.free();runtime.free();finish()
func finish():
 print("ARMY_BOX_FILTER_RESULT checks=",checks," failures=",failures);quit(1 if failures else 0)
