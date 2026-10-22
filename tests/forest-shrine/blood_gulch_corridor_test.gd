extends SceneTree
## Catches the compatible canyon field silently falling back to per-sample script work.
const Model=preload("res://scripts/forest/forest_model.gd")
const Blood=preload("res://scripts/forest/forest_blood_gulch_terrain.gd")
class CustomField extends "res://scripts/forest/forest_blood_gulch_terrain.gd":
 func height(x:float,z:float)->float:return super.height(x,z)+.5
var checks=0
var failures=0
func _initialize():run.call_deferred()
func check(ok:bool,label_:String):
 checks+=1
 if not ok:failures+=1;printerr("FAIL: ",label_)
func reference(model,from:Vector3,to:Vector3,radius:float,spacing:float,horizontal:bool,on_road:bool)->PackedVector3Array:
 var distance=Vector2(to.x-from.x,to.z-from.z).length() if horizontal else from.distance_to(to)
 var steps=maxi(1,ceili(distance/spacing));var points=PackedVector3Array();var previous=from
 for i in range(1,steps+1):
  var point=from.lerp(to,float(i)/steps);point.y=model.surface_height(point.x,point.z)
  if not model.terrain.step_clear(previous,point) or not model.waves.navigation.terrain_clear(point,radius):return PackedVector3Array()
  if on_road:
   for axis in [Vector3.ZERO,Vector3.RIGHT,Vector3.LEFT,Vector3.FORWARD,Vector3.BACK]:
    if not model.roads.has(model.cell_of(point+axis*radius)):return PackedVector3Array()
  points.append(point);previous=point
 return points
func domain_edges():
 var native=ClassDB.instantiate("GoemonTerrainMath")
 var methods=native.get_method_list().filter(func(method):return method.name=="set_domain")
 var compatible=not methods.is_empty() and methods[0].args.size()==4
 check(compatible,"Native terrain can preserve both original inclusive and Rect2 exclusive boundaries")
 if not compatible:return
 var heights=PackedFloat32Array();heights.resize(161*161);heights.fill(0)
 var covered=PackedByteArray();covered.resize(161*161);covered.fill(1)
 native.configure_field(161,3.0,heights,covered)
 var bounds=Rect2(-100,-100,200,200)
 native.set_domain(240.0,bounds.position,bounds.end,true)
 for radius in [0.0,.1,3.9,8.5]:
  var envelope=14.0 if radius>=8.5 else radius
  var inset=bounds.grow(-envelope)
  for x in [inset.position.x-.00001,inset.position.x,inset.position.x+.00001,inset.end.x-.00001,inset.end.x,inset.end.x+.00001]:
   var point=Vector3(x,0,0)
   check((not native.sample(point,point,radius,.25,true,false).is_empty())==inset.has_point(Vector2(point.x,point.z)),"Native boundary rounding and edge inclusion match Rect2 clearance")
func run():
 var layout=JSON.parse_string(FileAccess.get_file_as_string("res://assets/maps/forest_blood_gulch.json"))
 var m=Model.new();m.reset(90824,{},layout)
 var nav=m.waves.navigation;var corridors=nav.terrain_corridors
 var rng=RandomNumberGenerator.new();rng.seed=451982
 var queries=[]
 for i in 240:
  var extent=240.0*float(layout.get("terrain_scale",1.0))
  var from=Vector3(rng.randf_range(-extent,extent),0,rng.randf_range(-extent,extent));from.y=m.surface_height(from.x,from.z)
  var to=from+Vector3(rng.randf_range(-10,10),rng.randf_range(-3,3),rng.randf_range(-10,10))
  if i%20==0:to=from
  queries.append([from,to,[0.0,1.0,3.9,8.5][i%4],[.1,.25,.7][i%3],i%2==0,i%7==0])
 for q in queries:
  var expected=reference(m,q[0],q[1],q[2],q[3],q[4],q[5])
  var actual=corridors.support(q[0],q[1],q[2],q[3],q[5],q[4])
  if actual.points!=expected and failures<3:
   print("CORRIDOR_DIFFERENCE query=",q," expected_size=",expected.size()," actual_size=",actual.points.size())
   for index in mini(expected.size(),actual.points.size()):
    if expected[index]!=actual.points[index]:
     print("POINT_DIFFERENCE index=",index," expected=",expected[index]," actual=",actual.points[index]," gap=",expected[index].distance_to(actual.points[index]));break
  check(actual.clear==not expected.is_empty() and actual.points==expected,"Canyon support, coverage and sampled coordinates match the script oracle exactly")
 var native=ClassDB.class_exists("GoemonTerrainMath")
 if native:
  domain_edges()
  check(corridors.native_sampler!=null,"The compatible canyon field uses native sampling")
  var begin=Time.get_ticks_usec()
  for q in queries:reference(m,q[0],q[1],q[2],q[3],q[4],q[5])
  var script_us=Time.get_ticks_usec()-begin
  corridors.clear();begin=Time.get_ticks_usec()
  for q in queries:corridors.support(q[0],q[1],q[2],q[3],q[5],q[4])
  var accelerated_us=Time.get_ticks_usec()-begin
  print("CANYON_CORRIDOR_TIMING script_us=",script_us," optimized_us=",accelerated_us)
  check(accelerated_us<maxf(1000,script_us*.65),"Unique canyon queries avoid per-sample script overhead")
 # Geometry revisions must refresh physical wall contacts even if terrain is unchanged.
 var gate=m.buildings.values().filter(func(b):return b.kind=="gate")[0]
 var center=m.center(gate);var points=PackedVector3Array([center]);var radius=3.9
 check(not corridors.walls_clear(points,radius),"A closed gate blocks a corridor")
 gate.breached=true;m.rebuild_navigation()
 var expected_clear=nav.blocker(center,radius)<0
 check(corridors.walls_clear(points,radius)==expected_clear and expected_clear,"A breached opening refreshes native wall contacts")
 gate.breached=false;m.rebuild_navigation()
 check(not corridors.walls_clear(points,radius),"A repaired gate blocks the opening again")
 var custom=CustomField.new();custom.configure([]);m.terrain=custom;m.rebuild_navigation()
 corridors.support(Vector3.ZERO,Vector3.ONE,0,.25,false,true)
 check(corridors.native_sampler==null,"Terrain subclasses with custom height behavior retain script sampling")
 m.terrain=Blood.new();m.terrain.configure([]);m.rebuild_navigation()
 corridors.support(Vector3.ZERO,Vector3.ONE,0,.25,false,true)
 check(not native or corridors.native_sampler!=null,"Replacing terrain reconfigures the native field")
 m.trees[Vector2i.ZERO]=true;m.rebuild_navigation()
 var tree_result=corridors.support(Vector3(-1,0,0),Vector3(1,0,0),1,.25,false,true)
 check(not tree_result.clear,"Adding a tree invalidates cached support")
 if m.has_method("world_bounds") or m.has_method("navigation_bounds"):
  # Exercise the production model-to-native wiring on an expanded flat field.
  # A valid point beyond the old +237 boundary catches a misspelled getter.
  var flat=Blood.new();flat.horizontal_scale=1.2;flat.configure([])
  flat.width=161;flat.spacing=3.6
  flat.heights=PackedFloat32Array();flat.heights.resize(161*161);flat.heights.fill(0)
  flat.covered=PackedByteArray();flat.covered.resize(161*161);flat.covered.fill(1)
  m.terrain=flat;m.trees.clear();m.navigation_region=Rect2i(-48,-48,96,96);m.rebuild_navigation()
  for x in [260.0,284.99997,285.0,285.00003]:
   var point=Vector3(x,0,0);var expected=reference(m,point,point,0,.25,true,false)
   var actual=corridors.support(point,point,0,.25,false,true)
   check(actual.points==expected,"The real model passes its expanded world boundary into native clearance")
  check(corridors.support(Vector3(260,0,0),Vector3(260,0,0),0,.25,false,true).clear,"Supported outer-map ground is not clipped to the old map domain")
 print("BLOOD_GULCH_CORRIDOR_RESULT checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)
