extends SceneTree
const Model=preload("res://scripts/forest/forest_model.gd")
class Ground extends "res://scripts/forest/forest_ramparts.gd":
 var probes=0
 var level=0.0
 func height(_x:float,_z:float)->float:probes+=1;return level
var checks=0
var failures=0
func check(ok:bool,label_:String):
 checks+=1
 if not ok:failures+=1;printerr("FAIL: ",label_)
func original(model,nav,p:Vector3,radius:float)->int:
 var c:Vector2i=model.cell_of(p);var cells=ceili((radius+3)/6)+1
 for id in nav._nearby_buildings(c,cells):
  var b:Dictionary=model.buildings.get(id,{})
  if b.is_empty():continue
  var size_:Vector2i=model.dimensions(b.kind,b.rotation,b.get("span",0));var first:Vector3=model.point(b.cell)-Vector3(3,0,3);var last=first+Vector3(size_.x*6,0,size_.y*6)
  var q=Vector3(clampf(p.x,first.x,last.x),model.center(b).y,clampf(p.z,first.z,last.z))
  if p.distance_to(q)<radius+.05:return id
 return -1
func _initialize():run.call_deferred()
func run():
 var m=Model.new();m.reset(41,{}, {"trees":[],"deposits":[],"buildings":[]});var ground=Ground.new();m.terrain=ground;m.rebuild_navigation();var nav=m.waves.navigation
 check(nav.blocker(Vector3(11,0,0),3.9)==1,"Structure fixture has a real soldier contact")
 ground.probes=0
 for i in 100:nav.blocker(Vector3(11,0,0),3.9)
 check(ground.probes==0,"Repeated structure contacts reuse static geometry instead of resampling foundations")
 var rng=RandomNumberGenerator.new();rng.seed=55731
 for i in 1200:
  var p=Vector3(rng.randf_range(-20,20),rng.randf_range(-5,10),rng.randf_range(-20,20));var r=[.9,3.9,5.35,8.5][i%4]
  check(nav.blocker(p,r)==original(m,nav,p,r),"Exact 3D structure contact matches the original rectangle and strict radius")
 var wall=m._make_building("wall",Vector2i(5,0),0,3);m.rebuild_navigation()
 check(nav.blocker(Vector3(31,0,0),3.9)==wall.id,"A newly built wall invalidates cached contact geometry")
 m._remove_building(wall.id);m.rebuild_navigation()
 check(nav.blocker(Vector3(31,0,0),3.9)==-1,"A removed wall immediately clears its contact geometry")
 var raised=Ground.new();raised.level=5;m.terrain=raised
 check(nav.blocker(Vector3(11,5,0),3.9)==1,"A replaced terrain instance refreshes cached foundation heights")
 var kai=Model.new();kai.reset(42,{},JSON.parse_string(FileAccess.get_file_as_string("res://assets/maps/forest_kai_highway.json")));nav=kai.waves.navigation
 for i in 1200:
  var p=Vector3(rng.randf_range(-110,110),rng.randf_range(-2,22),rng.randf_range(-110,110));var r=[.9,3.9,5.35,8.5][i%4]
  check(nav.blocker(p,r)==original(kai,nav,p,r),"Native castle/hills contacts match the original query")
 print("SOLDIER_STRUCTURE_QUERY_RESULT checks=",checks," failures=",failures);quit(1 if failures else 0)
