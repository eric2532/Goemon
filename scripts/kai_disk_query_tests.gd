extends SceneTree
const Terrain=preload("res://scripts/forest/forest_kai_terrain.gd")
# Frozen pre-optimization algorithm. Public contains/height semantics remain
# unchanged; this deliberately keeps their two independent coordinate queries.
class Original extends "res://scripts/forest/forest_kai_terrain.gd":
 func disk_clear(point:Vector3,radius:float)->bool:
  if not contains(point.x,point.z):return false
  var center=height(point.x,point.z);var tolerance=.15+radius*.35
  for axis in [Vector2.RIGHT,Vector2.LEFT,Vector2.UP,Vector2.DOWN,Vector2(.707,.707),Vector2(-.707,.707),Vector2(.707,-.707),Vector2(-.707,-.707)]:
   var x=point.x+axis.x*radius;var z=point.z+axis.y*radius
   if not contains(x,z) or absf(height(x,z)-center)>tolerance:return false
  return true
class CountTerrain extends "res://scripts/forest/forest_kai_terrain.gd":
 var coordinates=0
 func coordinate(x:float,z:float)->Vector2:
  coordinates+=1;return super.coordinate(x,z)
var checks=0
var failures=0
func check(ok:bool,label_:String):
 checks+=1
 if not ok:failures+=1;printerr("FAIL: ",label_)
func compare(actual,original,point:Vector3,radius:float,label_:String):
 check(actual.disk_clear(point,radius)==original.disk_clear(point,radius),"Exact native disk equivalence "+label_)
 if actual.has_method("_covered_height"):
  var h=actual._covered_height(point.x,point.z)
  check((is_nan(h) and not original.contains(point.x,point.z)) or (not is_nan(h) and original.contains(point.x,point.z) and h==original.height(point.x,point.z)),"Combined query preserves exact covered native height "+label_)
func synthetic():
 var t=Terrain.new();t.width=8;t.spacing=3.0
 t.heights.resize(64);t.heights.fill(7.25);t.covered.resize(64);t.covered.fill(1)
 return t
func flat_proofs(actual,original,rng):
 var api=actual.has_method("flat_corridor")
 check(api,"Native terrain exposes an exact conservative flat corridor certificate")
 if not api:return
 var from=Vector3(-230,0,-230);var to=Vector3(-226,0,-226)
 var t=synthetic()
 check(t.flat_corridor(from,to,2.0),"A fully covered constant-height rectangle proves the complete disk corridor")
 check(t.flat_corridor_cache.size()==1 and t.flat_corridor(from,to,2.0) and t.flat_corridor_cache.size()==1,"Exact integer rectangle reuses its cached geometry result")
 var slope=synthetic();slope.heights[27]+=.000001
 check(not slope.flat_corridor(from,to,2.0),"Even a one-float-step slope rejects an exact flat certificate")
 var hole=synthetic();hole.covered[27]=0
 check(not hole.flat_corridor(from,to,2.0),"Any uncovered vertex rejects the complete rectangle")
 check(not t.flat_corridor(Vector3(-240,0,-240),Vector3(-238,0,-238),.1),"Expanded corridor coverage rejects out-of-bounds disk edges")
 check(not t.flat_corridor(Vector3(-219,0,-219),Vector3(-219,0,-219),0),"Upper field cell without four vertices cannot be certified")
 check(not t.flat_corridor(from,to,-1),"Invalid negative footprint cannot shrink a proof rectangle")
 t.configure([{"ax":-10,"az":0,"bx":10,"bz":0,"width":3,"h0":12.0,"h1":12.0}])
 check(t.flat_corridor_cache.is_empty() and not t.flat_corridor(from,to,2),"Configure clears certificates and custom ramparts force exact fallback")
 var positives=0;var benchmark=[]
 for index in 1000:
  var a=Vector3(rng.randf_range(-235,235),0,rng.randf_range(-235,235))
  var b=a+Vector3(rng.randf_range(-8,8),0,rng.randf_range(-8,8));var radius=[0.0,.9,3.9,14.75][index%4]
  if not actual.flat_corridor(a,b,radius):continue
  positives+=1
  if benchmark.is_empty() and a.distance_to(b)>1:benchmark=[a,b,radius]
  var previous=a
  for step in range(21):
   var point=a.lerp(b,step/20.0)
   check(original.disk_clear(point,radius) and original.step_clear(previous,point),"Every positive native rectangle proves all original disk/step samples")
   previous=point
 check(positives>0 and not benchmark.is_empty(),"Random native field produces nontrivial exact flat certificates")
 for index in 4200:
  var p=Vector3((1+index%150)*3-239.9,0,(1+index/150)*3-239.9)
  actual.flat_corridor(p,p,0)
 check(actual.flat_corridor_cache.size()<=4096,"Flat rectangle cache remains bounded")
 actual.configure([]);check(actual.flat_corridor_cache.is_empty(),"Reconfiguring the native field clears all cached true and false certificates")
 if not benchmark.is_empty():
  var a:Vector3=benchmark[0];var b:Vector3=benchmark[1];var radius:float=benchmark[2]
  var count=maxi(1,ceili(Vector2(b.x-a.x,b.z-a.z).length()/.1));var start=Time.get_ticks_usec()
  for repeat in 1000:
   var previous=a
   for step in range(1,count+1):
    var point=a.lerp(b,float(step)/count);point.y=original.height(point.x,point.z)
    if not original.step_clear(previous,point) or not original.disk_clear(point,radius):break
    previous=point
  var original_us=Time.get_ticks_usec()-start;start=Time.get_ticks_usec()
  for repeat in 1000:actual.flat_corridor(a,b,radius)
  print("KAI_FLAT_CORRIDOR_BATCH queries=1000 samples_per_corridor=",count," original_ms=",original_us/1000.0," proof_ms=",(Time.get_ticks_usec()-start)/1000.0)
func _initialize():run.call_deferred()
func run():
 var actual=Terrain.new();actual.configure([]);var original=Original.new();original.configure([])
 var counted=CountTerrain.new();counted.configure([])
 check(counted.disk_clear(Vector3.ZERO,3.9),"Counting fixture covers all nine native terrain sample points")
 check(counted.coordinates<=9,"Covered disks avoid duplicate native coordinates, including exact flat region proofs")
 check(actual.has_method("_covered_height"),"Coverage and native height have a shared calculation")
 var rng=RandomNumberGenerator.new();rng.seed=781251
 var queries=[];var radii=[0.0,.000001,.9,1.3,3.9,5.35,8.5,14.0,14.75]
 for i in 5000:
  var point=Vector3(rng.randf_range(-255,255),rng.randf_range(-30,60),rng.randf_range(-255,255));var radius=float(radii[i%radii.size()])
  queries.append([point,radius]);compare(actual,original,point,radius,"random%d"%i)
 for axis in [-240.0001,-240.0,-239.9999,-.0001,0.0,.0001,236.9999,237.0,239.9999,240.0,240.0001]:
  for offset in [-3.0001,-3.0,-2.9999,-.0001,0.0,.0001,2.9999,3.0,3.0001]:
   for radius in [0.0,3.9,14.75]:
    compare(actual,original,Vector3(axis,0,offset),radius,"boundaryX")
    compare(actual,original,Vector3(offset,0,axis),radius,"boundaryZ")
 for i in 200:
  var ix=rng.randi_range(0,actual.width-2);var iz=rng.randi_range(0,actual.width-2);var u=rng.randf()
  for epsilon in [-.00001,0.0,.00001]:
   var p=Vector3((ix+u)*actual.spacing-240,0,(iz+1-u+epsilon)*actual.spacing-240)
   compare(actual,original,p,3.9,"triangle diagonal")
 var pieces=[{"ax":-10,"az":0,"bx":10,"bz":0,"width":3,"h0":12.0,"h1":12.0},{"ax":0,"az":-12,"bx":0,"bz":-6,"width":5,"h0":0.0,"h1":12.0}]
 actual.configure(pieces);original.configure(pieces)
 for i in 500:compare(actual,original,Vector3(rng.randf_range(-80,80),0,rng.randf_range(-80,80)),float(radii[i%radii.size()]),"custom ramparts")
 check(not Terrain.new().disk_clear(Vector3.ZERO,3.9),"Unconfigured terrain remains uncovered")
 actual.configure([]);original.configure([])
 flat_proofs(actual,original,rng)
 var start=Time.get_ticks_usec();var old_count=0
 for repeat in 4:
  for q in queries:old_count+=int(original.disk_clear(q[0],q[1]))
 var before=Time.get_ticks_usec()-start;start=Time.get_ticks_usec();var new_count=0
 for repeat in 4:
  for q in queries:new_count+=int(actual.disk_clear(q[0],q[1]))
 var after=Time.get_ticks_usec()-start
 check(old_count==new_count,"Measured disk batches have identical coverage results")
 print("KAI_DISK_BATCH queries=20000 original_ms=",before/1000.0," optimized_ms=",after/1000.0," ratio=",float(after)/maxi(1,before))
 print("KAI_DISK_QUERY_TESTS checks=",checks," failures=",failures)
 quit(1 if failures else 0)
