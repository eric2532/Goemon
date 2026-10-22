extends SceneTree
const Terrain=preload("res://scripts/forest/forest_ramparts.gd")
var checks=0
var failures=0
func _initialize():run.call_deferred()
func check(ok:bool,label_:String):
 checks+=1
 if not ok:failures+=1;printerr("FAIL: "+label_)
# Frozen exhaustive reference preserves the original continuous terrain rules.
func exhaustive(terrain,point:Vector2)->float:
 var result=0.0
 for p in terrain.pieces:
  var offset=point-p.a;var u=offset.dot(p.along)
  if u<p.start-.001 or u>p.end+.001 or absf(offset.dot(p.side))>p.half+.001:continue
  result=maxf(result,lerpf(p.h0,p.h1,clampf(u/p.length,0,1)))
 return result
func cost(terrain)->float:
 var samples=[];var sink=0.0
 for repeat_ in range(3):
  var start=Time.get_ticks_usec()
  for i in range(6000):sink+=terrain.height(float(i%17)-8,70.0+float(i%29))
  samples.append(float(Time.get_ticks_usec()-start))
 samples.sort()
 if sink<1:printerr("Missing benchmark surface")
 return samples[1]
func run():
 var data=JSON.parse_string(FileAccess.get_file_as_string("res://assets/maps/forest_four_gates.json"))
 var terrain=Terrain.new();terrain.configure(data.ramparts)
 for point in [Vector2(0,84),Vector2(84,0),Vector2(-84,0),Vector2(0,-84)]:check(is_equal_approx(terrain.height(point.x,point.y),9),"Halfway ramp height stays exactly nine metres at "+str(point))
 var same=true
 for x in range(-240,241,3):
  for z in range(-240,241,3):same=same and is_equal_approx(terrain.height(x,z),exhaustive(terrain,Vector2(x,z)))
 # Include points on either side of bucket/segment edges and the original tolerance.
 for p in terrain.pieces:
  for u in [p.start-.002,p.start-.0005,p.start,p.end,p.end+.0005,p.end+.002]:
   for v in [-p.half-.002,-p.half-.0005,-p.half,0,p.half,p.half+.0005,p.half+.002]:
    var point=p.a+p.along*u+p.side*v
    same=same and is_equal_approx(terrain.height(point.x,point.y),exhaustive(terrain,point))
 check(same,"Continuous heights agree with the previous exhaustive sampler across the map, overlaps and edge tolerances")
 var single=Terrain.new();single.configure([data.ramparts[0]])
 var small=cost(single);var large=cost(terrain)
 print("RAMPART_SAMPLE_COST single_us=",small," full_us=",large," ratio=",large/maxf(1,small))
 check(large<small*3,"Local sampling cost stays bounded when distant wall routes are added")
 terrain.configure([]);check(terrain.height(0,84)==0,"Reconfiguration removes previous raised surfaces")
 terrain.configure([{"ax":0,"az":12,"bx":0,"bz":18,"width":5,"h0":4,"h1":4},{"ax":-3,"az":15,"bx":3,"bz":15,"width":5,"h0":12,"h1":12}])
 check(terrain.height(0,90)==12 and terrain.height(0,72)==4,"Overlapping surfaces still select the highest continuous deck")
 print("RAMPART_SAMPLING_RESULT checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)
