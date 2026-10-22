extends SceneTree
const Model=preload("res://scripts/forest/forest_model.gd")
var checks=0
var failures=0
func check(ok:bool,label_:String):
 checks+=1
 if not ok:failures+=1;printerr("FAIL: ",label_)
func original(m,nav,a:Vector3,b:Vector3,r:float,spacing:float,horizontal:bool,on_road:bool)->PackedVector3Array:
 var count=maxi(1,ceili((Vector2(b.x-a.x,b.z-a.z).length() if horizontal else a.distance_to(b))/spacing));var previous=a;var result=PackedVector3Array()
 for index in range(1,count+1):
  var p=a.lerp(b,float(index)/count);p.y=m.surface_height(p.x,p.z)
  if not m.terrain.step_clear(previous,p) or not nav.terrain_clear(p,r):return PackedVector3Array()
  if on_road:
   for axis in [Vector3.ZERO,Vector3.RIGHT,Vector3.LEFT,Vector3.FORWARD,Vector3.BACK]:
    if not m.roads.has(m.cell_of(p+axis*r)):return PackedVector3Array()
  result.append(p);previous=p
 return result
func original_walls(nav,points:PackedVector3Array,radius:float)->bool:
 for p in points:
  if nav.blocker(p,radius)>=0:return false
 return true
func _initialize():run.call_deferred()
func run():
 check(ClassDB.class_exists("GoemonTerrainMath"),"The current Godot project loads its native terrain math component")
 if failures:finish();return
 var m=Model.new();m.reset(42,{},JSON.parse_string(FileAccess.get_file_as_string("res://assets/maps/forest_kai_highway.json")));var nav=m.waves.navigation
 nav.supported_corridor(Vector3(0,0,18),Vector3(0,0,24),3.9,.1,false,true)
 var native=nav.terrain_corridors.get("native_sampler")
 check(native!=null,"The native Kai map uses compiled math rather than the script fallback")
 if native==null:finish();return
 var rng=RandomNumberGenerator.new();rng.seed=791835;var positives=0
 for i in 2000:
  var a=Vector3(rng.randf_range(-240,240),rng.randf_range(-3,25),rng.randf_range(-240,240));var b=a+Vector3(rng.randf_range(-12,12),rng.randf_range(-3,3),rng.randf_range(-12,12));var r=[0.0,.9,3.9,8.5,5.35][i%5];var spacing=[.1,.25,.75,1.5][i%4];var horizontal=i%2==0;var road=i%7==0
  var expected=original(m,nav,a,b,r,spacing,horizontal,road);var actual:PackedVector3Array=native.sample(a,b,r,spacing,horizontal,road)
  if not expected.is_empty():positives+=1
  check(actual==expected,"Compiled samples exactly match the original float32 positions and clearance decision (case%d)"%i)
  check(native.walls_clear(actual,r)==original_walls(nav,actual,r),"Compiled contacts match live original wall queries (case%d)"%i)
 check(positives>200,"The equivalence test exercises many positive native terrain corridors")
 for x in [-240.0001,-240.,-239.9999,-.0001,0.,.0001,236.9999,237.,239.9999,240.]:
  for z in [-12.,-.0001,0.,.0001,12.]:
   for r in [0.0,3.9,8.5]:
    var a=Vector3(x,0,z);var b=a+Vector3(.001,0,.001)
    check(native.sample(a,b,r,.1,true,false)==original(m,nav,a,b,r,.1,true,false),"Native boundary and zero-length-scale probes retain original decisions")
 var a=Vector3(0,0,18);var b=Vector3(0,0,24);var wall=m._make_building("wall",Vector2i(0,3),0,1);m.rebuild_navigation();nav.supported_corridor(a,b,3.9,.1,false,true)
 check(not nav.corridor_walls_clear(native.sample(a,b,3.9,.1,true,false),3.9),"New walls are immediately visible to compiled contacts")
 m._remove_building(wall.id);m.rebuild_navigation();nav.supported_corridor(a,b,3.9,.1,false,true)
 check(nav.corridor_walls_clear(native.sample(a,b,3.9,.1,true,false),3.9),"Removed walls immediately clear compiled contacts")
 var previous_terrain=m.terrain;var replacement=preload("res://scripts/forest/forest_ramparts.gd").new()
 replacement.configure([{"ax":-100,"az":20,"bx":100,"bz":20,"width":100,"h0":12.0,"h1":12.0}]);m.terrain=replacement
 var replaced=nav.supported_corridor(a,b,3.9,.1,false,true)
 check(replaced.clear and replaced.points[0].y==12.0 and nav.terrain_corridors.native_sampler==null,"Replacing terrain without a navigation revision invalidates old native data and certificates")
 m.terrain=previous_terrain;nav.supported_corridor(a,b,3.9,.1,false,true)
 check(nav.terrain_corridors.native_sampler!=null,"Restoring native terrain without a revision reinstates its own sampler")
 m.terrain.configure([{"ax":-5,"az":0,"bx":5,"bz":0,"width":3,"h0":12.0,"h1":12.0}]);m.rebuild_navigation();nav.supported_corridor(a,b,3.9,.1,false,true)
 check(nav.terrain_corridors.native_sampler==null,"Authored custom ramparts retain the original script sampler")
 finish()
func finish():
 print("CASTLE_NATIVE_TERRAIN_RESULT checks=",checks," failures=",failures);quit(1 if failures else 0)
