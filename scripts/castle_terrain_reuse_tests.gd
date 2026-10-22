extends SceneTree
const Model=preload("res://scripts/forest/forest_model.gd")
class Navigation extends "res://scripts/forest/forest_enemy_navigation.gd":
 var probes=0
 func terrain_clear(p:Vector3,r:float)->bool:probes+=1;return super.terrain_clear(p,r)
 func terrain_obstacles_clear(p:Vector3,r:float)->bool:probes+=1;return super.terrain_obstacles_clear(p,r)
class Ground extends "res://scripts/forest/forest_kai_terrain.gd":
 var probes=0
 func height(x:float,z:float)->float:probes+=1;return super.height(x,z)
var checks=0
var failures=0
func check(ok:bool,label_:String):
 checks+=1
 if not ok:failures+=1;printerr("FAIL: ",label_)
func original(model,nav,a:Vector3,b:Vector3,r:float,spacing:float,on_road:bool,horizontal:bool)->bool:
 var steps=maxi(1,ceili((Vector2(b.x-a.x,b.z-a.z).length() if horizontal else a.distance_to(b))/spacing));var prior=a
 for index in range(1,steps+1):
  var p=a.lerp(b,float(index)/steps);p.y=model.surface_height(p.x,p.z)
  if not model.terrain.step_clear(prior,p) or not nav.terrain_clear(p,r):return false
  if on_road:
   for axis in [Vector3.ZERO,Vector3.RIGHT,Vector3.LEFT,Vector3.FORWARD,Vector3.BACK]:
    if not model.roads.has(model.cell_of(p+axis*r)):return false
  prior=p
 return true
func _initialize():run.call_deferred()
func run():
 var ground=Ground.new();ground.configure([]);ground.cliff_cell(Vector2i(0,2));ground.probes=0;ground.cliff_cell(Vector2i(0,2))
 check(ground.probes==0,"Unchanged native cliff cells reuse their exact sampled result")
 ground.configure([{"ax":-5,"az":0,"bx":5,"bz":0,"width":3,"h0":12.0,"h1":12.0}]);ground.probes=0
 check(ground.cliff_cell(Vector2i(0,2)) and ground.probes>0,"Reconfigured raised geometry invalidates native cliff certificates")
 var m=Model.new();m.reset(42,{},JSON.parse_string(FileAccess.get_file_as_string("res://assets/maps/forest_kai_highway.json")));var nav=Navigation.new(m);m.waves.navigation=nav
 check(nav.has_method("supported_corridor"),"Navigation shares terrain-only corridor support separately from walls")
 if not nav.has_method("supported_corridor"):finish();return
 var a=Vector3(0,0,18);var b=Vector3(0,0,24)
 var certificate=nav.supported_corridor(a,b,3.9,.1,false,true)
 check(certificate.clear,"The native castle clearing supports the enlarged footprint")
 var wall=m._make_building("wall",Vector2i(20,20),0,1);m.rebuild_navigation()
 check(nav.supported_corridor(a,b,3.9,.1,false,true).clear and is_same(certificate,nav.supported_corridor(a,b,3.9,.1,false,true)),"A remote wall change does not rescan unchanged terrain")
 wall=m._make_building("wall",Vector2i(0,3),0,1);m.rebuild_navigation()
 check(not m.waves.flow.corridor_clear({"variant":0},a,b,false),"A newly built wall still blocks a terrain-supported corridor")
 m._remove_building(wall.id);m.rebuild_navigation()
 check(m.waves.flow.corridor_clear({"variant":0},a,b,false),"A removed wall restores the route with fresh live wall checks")
 m.trees[Vector2i(0,4)]=1.;m.rebuild_navigation()
 check(not nav.supported_corridor(a,b,3.9,.1,false,true).clear and not is_same(certificate,nav.supported_corridor(a,b,3.9,.1,false,true)),"Changed tree geometry invalidates shared terrain support")
 m.trees.clear();m.rebuild_navigation();nav.supported_corridor(a,b,3.9,.1,false,true);var n=nav.terrain_corridors.entries.size()
 nav.supported_corridor(a+Vector3(.0001,0,0),b,3.9,.1,false,true)
 check(nav.terrain_corridors.entries.size()>n,"Distinct actual roots are never quantized into one support proof")
 n=nav.terrain_corridors.entries.size();nav.supported_corridor(a,b,8.5,.1,false,true)
 check(nav.terrain_corridors.entries.size()>n,"Different footprints have independent terrain support")
 var rng=RandomNumberGenerator.new();rng.seed=10813
 for i in 600:
  var from=Vector3(rng.randf_range(-232,232),rng.randf_range(-2,24),rng.randf_range(-232,232));var to=from+Vector3(rng.randf_range(-12,12),rng.randf_range(-3,3),rng.randf_range(-12,12));var r=[.9,3.9,8.5][i%3];var spacing=[.1,.75,1.5][i%3];var on_road=i%5==0;var horizontal=i%2==0
  check(nav.supported_corridor(from,to,r,spacing,on_road,horizontal).clear==original(m,nav,from,to,r,spacing,on_road,horizontal),"Native terrain support equals the original full sampled algorithm")
 check(nav.terrain_corridors.entries.size()<=8192 and nav.terrain_corridors.sample_count<=262144,"Terrain support storage is bounded")
 finish()
func finish():
 print("CASTLE_TERRAIN_REUSE_RESULT checks=",checks," failures=",failures);quit(1 if failures else 0)
