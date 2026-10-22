extends SceneTree
const Model=preload("res://scripts/forest/forest_model.gd")
const Roles=preload("res://scripts/forest/forest_enemy_roles.gd")
class CountWaves extends "res://scripts/forest/forest_waves.gd":
 var calls=0
 var successes=0
 func spawn_one(_reserved:Array=[])->bool:
  calls+=1
  if successes<=0:return false
  successes-=1;pending-=1;remaining_counts[0]-=1
  return true
var checks=0
var failures=0
func check(ok:bool,label_:String):
 checks+=1
 if not ok:failures+=1;printerr("FAIL: ",label_)
func fresh():
 var m=Model.new();m.reset(41,{}, {"trees":[],"deposits":[],"buildings":[]});m.enemies.clear();return m
func exhaustive(m,point:Vector3,radius:float)->bool:
 for e in m.enemies.values():
  if point.distance_to(e.pos)<radius+Roles.visibility_radius(e.variant)+.35:return false
 return true
func _initialize():run.call_deferred()
func run():
 var m=fresh();var waves=CountWaves.new(m);waves.pending=12;waves.remaining_counts=[12,0,0,0];m.portals=[Vector2i.ZERO]
 check(waves.spawn_batch()==0 and waves.calls==1,"Exhaustive failed portal search runs once per unchanged batch")
 check(waves.pending==12 and waves.remaining_counts==[12,0,0,0],"Failed portal attempt preserves exact queued counts")
 waves.calls=0;waves.successes=2
 check(waves.spawn_batch()==2 and waves.calls==3 and waves.pending==10,"Successful portal releases continue until the first exhaustive failure")
 waves.calls=0;m.portals.clear()
 check(waves.spawn_batch()==0 and waves.calls==12 and waves.pending==10,"Random nonportal mode retains all twelve retries and pending slots")
 var api=m.waves.has_method("begin_spawn_query") and m.waves.has_method("spawn_space_clear") and m.waves.has_method("register_spawn") and m.waves.has_method("end_spawn_query")
 check(api,"Batch-owned spawn spatial query API exists")
 if api:
  var rng=RandomNumberGenerator.new();rng.seed=1701
  for id in 240:
   m.enemies[id]={"id":id,"pos":Vector3(rng.randf_range(-240,240),rng.randf_range(-30,30),rng.randf_range(-240,240)),"variant":id%5,"hp":0 if id%7==0 else 100}
  m.waves.begin_spawn_query()
  for sample in 1000:
   var point=Vector3(rng.randf_range(-270,270),rng.randf_range(-40,40),rng.randf_range(-270,270));var radius=Roles.visibility_radius(sample%5)
   check(m.waves.spawn_space_clear(point,radius)==exhaustive(m,point,radius),"Bucket query equals original 3D scan sample%d"%sample)
  m.enemies.clear();m.waves.end_spawn_query();m.waves.begin_spawn_query()
  var added={"id":999,"pos":Vector3(-16,3,16),"variant":2,"hp":0};m.enemies[999]=added;m.waves.register_spawn(added)
  check(not m.waves.spawn_space_clear(Vector3(-40,3,16),14),"Registered giant updates maximum radius across multiple buckets, including dead actors")
  check(m.waves.spawn_space_clear(Vector3(-16,40,16),3.9),"XZ candidate query preserves exact vertical separation")
  m.waves.end_spawn_query();m.enemies.clear()
  check(m.waves.spawn_space_clear(Vector3(-16,3,16),3.9),"Ending a batch removes stale cached actors")
  m.enemies[999]=added
  check(not m.waves.spawn_space_clear(Vector3(-16,3,16),3.9),"Inactive direct Routes.spawn queries retain exhaustive live fallback")
  m.enemies[999].pos=Vector3(80,0,80)
  check(m.waves.spawn_space_clear(Vector3(-16,3,16),3.9),"Inactive fallback observes moved actors without a rebuild")
 var contact=load("res://scripts/forest/forest_enemy_contact.gd")
 contact.crowd_script=null;contact.cache.clear();contact.block_cache.clear();contact.soldier_cache.clear()
 await process_frame
 await process_frame
 print("SOLDIER_SPAWN_PERFORMANCE_TESTS checks=",checks," failures=",failures)
 quit(1 if failures else 0)
