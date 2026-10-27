extends SceneTree
const Art=preload("res://scripts/forest/forest_wind_meadow_art.gd")
const Layout=preload("res://scripts/forest/forest_wind_meadow_layout.gd")
var checks=0
var failures=0
func check_point(point:Vector2,scale_:float,roads:Array):
 checks+=1
 if Art.near_foliage_road(point,roads)!=(Layout.road_distance(point,scale_)<9):
  failures+=1;printerr("Road clearance changed at ",point," scale ",scale_)
func _initialize():
 var rng=RandomNumberGenerator.new();rng.seed=71023
 for scale_ in [1.0,2.0]:
  for z in range(int(-6*scale_),int(6*scale_)):
   for x in range(int(-6*scale_),int(6*scale_)):
    var origin=Vector2(x*36,z*36);var roads=Art.foliage_roads(origin,scale_)
    for corner in [Vector2.ZERO,Vector2(0,36),Vector2(36,0),Vector2(36,36)]:check_point(origin+corner,scale_,roads)
    for sample in 24:check_point(origin+Vector2(rng.randf()*36,rng.randf()*36),scale_,roads)
  for route in Layout.routes(scale_):
   for i in range(1,route.size()):
    var a:Vector2=route[i-1];var b:Vector2=route[i];var normal=(b-a).orthogonal().normalized()
    for t in [0.0,.25,.5,.75,1.0]:
     for offset in [-9.001,-9.0,-8.999,8.999,9.0,9.001]:
      var p=a.lerp(b,t)+normal*offset
      check_point(p,scale_,Art.foliage_roads(Vector2(floorf(p.x/36)*36,floorf(p.y/36)*36),scale_))
 print("WIND_MEADOW_STARTUP_RESULT checks=",checks," failures=",failures)
 quit(1 if failures else 0)
