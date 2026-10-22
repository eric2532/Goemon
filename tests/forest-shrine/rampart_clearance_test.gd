extends SceneTree
const Terrain=preload("res://scripts/forest/forest_ramparts.gd")
class CountedTerrain extends "res://scripts/forest/forest_ramparts.gd":
 var samples=0
 func height(x:float,z:float)->float:
  samples+=1
  return super.height(x,z)
var checks=0
var failures=0
const AXES=[Vector2.RIGHT,Vector2.LEFT,Vector2.UP,Vector2.DOWN,Vector2(.707,.707),Vector2(-.707,.707),Vector2(.707,-.707),Vector2(-.707,-.707)]
func _initialize():run.call_deferred()
func check(ok:bool,label_:String):
 checks+=1
 if not ok:failures+=1;printerr("FAIL: "+label_)
func original(terrain,point:Vector3,radius:float)->bool:
 if terrain.pieces.is_empty():return true
 var center=terrain.height(point.x,point.z)
 for axis in AXES:
  if absf(terrain.height(point.x+axis.x*radius,point.z+axis.y*radius)-center)>.15+radius*.35:return false
 return true
func run():
 var data=JSON.parse_string(FileAccess.get_file_as_string("res://assets/maps/forest_four_gates.json"))
 var terrain=CountedTerrain.new();terrain.configure(data.ramparts)
 check(terrain.disk_clear(Vector3(0,18,132),.9),"A raider fits on the broad flat wall deck")
 check(terrain.samples<=2,"Flat deck clearance avoids resampling the same surface nine times per movement step")
 var same=true
 var rng=RandomNumberGenerator.new();rng.seed=7319
 for i in 1500:
  var point=Vector3(rng.randf_range(-240,240),0,rng.randf_range(-240,240))
  for radius in [.8,.85,.9,8.5,14.75]:
   same=same and terrain.disk_clear(point,radius)==original(terrain,point,radius)
 for p in terrain.pieces:
  for u in [p.start-.002,p.start,p.start+.9,p.end-.9,p.end,p.end+.002]:
   for v in [-p.half-.002,-p.half,-p.half+.9,0,p.half-.9,p.half,p.half+.002]:
    var point2=p.a+p.along*u+p.side*v
    for radius in [.8,.9,8.5]:
     var point=Vector3(point2.x,0,point2.y)
     same=same and terrain.disk_clear(point,radius)==original(terrain,point,radius)
 check(same,"Clearance matches the original exact samples across ramps, wall edges, negative coordinates and all enemy radii")
 terrain.configure([{"ax":0,"az":0,"bx":0,"bz":10,"width":5,"h0":4,"h1":4},{"ax":-3,"az":5,"bx":3,"bz":5,"width":3,"h0":12,"h1":12}])
 same=true
 for z in range(-30,91):
  for x in range(-30,31,3):
   var point=Vector3(x,0,z)
   for radius in [.9,8.5]:same=same and terrain.disk_clear(point,radius)==original(terrain,point,radius)
 check(same,"Overlapping higher walls cannot incorrectly certify a lower deck as clear")
 terrain.configure([]);check(terrain.disk_clear(Vector3.ZERO,8.5),"Loading flat terrain removes previous deck clearance data")
 print("RAMPART_CLEARANCE_RESULT checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)
