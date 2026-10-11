extends SceneTree
## CPU-only regression for dense projectile updates, on the test host.
var checks=0
var failures=0
class Target:
 extends Ninja
 func _ready():set_physics_process(false)
class Combat:
 extends "res://scripts/rogue_roster_combat.gd"
 func clear_line(_a: Vector3,_b: Vector3)->bool:return true
func _initialize():run.call_deferred()
func check(ok: bool,label: String):
 checks+=1
 if ok:print("PASS: ",label)
 else:failures+=1;push_error(label)
func run():
 var arena=Node3D.new();root.add_child(arena)
 var population=Node.new()
 var state=GDScript.new();state.source_code="extends Node\nvar enemies=[]\n";check(state.reload()==OK,"Crowd query fixture initializes")
 population.set_script(state);root.add_child(population)
 for i in range(300):
  var e=Target.new();arena.add_child(e)
  e.position=Vector3(float(i%12)-6,0,float(i/12));population.enemies.append(e)
 var combat=Combat.new();combat.game=population;root.add_child(combat)
 var from=Vector3(0,20,10);var to=Vector3(0,19,9)
 # Forty concurrent Mage projectiles, or repeated airborne fan segments.
 for i in range(3):combat._segment_targets(from,to,.45)
 var durations=[]
 for batch in range(5):
  var start=Time.get_ticks_usec()
  if combat.has_method("_begin_projectile_queries"):combat._begin_projectile_queries()
  for i in range(40):combat._segment_targets(from,to,.45)
  if combat.has_method("_end_projectile_queries"):combat._end_projectile_queries()
  durations.append(Time.get_ticks_usec()-start)
 durations.sort();var median=durations[2]
 print("PROJECTILE_SCAN_CPU forty_sweeps_median_us=",median," samples=",durations)
 check(median<2000,"Forty off-target projectile sweeps stay below a 2 ms CPU budget on this host")
 check(combat._segment_targets(from,to,.45).is_empty(),"Airborne segments cannot damage enemies below their footprint")
 var e=population.enemies[0];e.position=Vector3(1,0,5);e.body_radius=.5
 var a=Vector3(0,1.1,0);var b=Vector3(0,1.1,10)
 var hits=combat._segment_targets(a,b,.5)
 check(hits.any(func(h):return h.e.node==e),"A tangent body contact at width plus radius remains included")
 e.body_radius=.45;e.position=Vector3(.9,0,5);hits=combat._segment_targets(a,b,.45)
 check(hits.any(func(h):return h.e.node==e),"Decimal body radii retain inclusive tangent contacts")
 e.body_radius=.5;e.position=Vector3(1.001,0,5);hits=combat._segment_targets(a,b,.5)
 check(not hits.any(func(h):return h.e.node==e),"An actor just outside the exact swept radius remains excluded")
 e.body_radius=6;e.position=Vector3(5,0,5);hits=combat._segment_targets(a,b,.5)
 check(hits.any(func(h):return h.e.node==e),"Large-body contact remains conservatively included")
 e.position=Vector3(0,0,0);hits=combat._segment_targets(a,a,.5)
 check(hits.any(func(h):return h.e.node==e and h.t==0),"A zero-length segment still checks its starting volume")
 if combat.has_method("_begin_projectile_queries"):
  e.position=Vector3(0,0,5);e.dead=false;combat._begin_projectile_queries()
  e.dead=true;hits=combat._segment_targets(a,b,.5)
  check(not hits.any(func(h):return h.e.node==e),"A victim killed during the same projectile update is immediately excluded")
  e.dead=false;combat._end_projectile_queries();e.position=Vector3(100,0,5)
  hits=combat._segment_targets(a,b,.5)
  check(not hits.any(func(h):return h.e.node==e),"Queries outside a combat update always read current actor positions")
  combat._begin_projectile_queries();hits=combat._segment_targets(a,b,.5);combat._end_projectile_queries()
  check(not hits.any(func(h):return h.e.node==e),"The following combat update rebuilds the crowd geometry")
  e.position=Vector3(0,0,5);combat._begin_projectile_queries();var uid=e.get_instance_id()
  hits=combat._segment_targets(a,b,.5,[uid]);combat._end_projectile_queries()
  check(not hits.any(func(h):return h.e.node==e),"Shared crowd geometry still honors each projectile's own hit history")
 arena.queue_free();population.queue_free();combat.queue_free();await process_frame
 print("PROJECTILE_SCAN_RESULT checks=",checks," failures=",failures)
 quit(1 if failures else 0)
