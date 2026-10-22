extends SceneTree
const Model=preload("res://scripts/forest/forest_model.gd")
class ScriptGround extends "res://scripts/forest/forest_kai_terrain.gd":
 pass
class CountingNavigation extends "res://scripts/forest/forest_enemy_navigation.gd":
 var field_queries=0
 var obstacle_queries=0
 func terrain_clear(p:Vector3,radius:float)->bool:
  field_queries+=1;return super.terrain_clear(p,radius)
 func terrain_obstacles_clear(p:Vector3,radius:float)->bool:
  obstacle_queries+=1;return super.terrain_obstacles_clear(p,radius)
var checks=0
var failures=0
func _initialize():run.call_deferred()
func check(ok:bool,label_:String):
 checks+=1
 if not ok:failures+=1;printerr("FAIL: ",label_)
func run():
 var m=Model.new();m.reset(42,{},JSON.parse_string(FileAccess.get_file_as_string("res://assets/maps/forest_kai_highway.json")))
 m.terrain=ScriptGround.new();m.terrain.configure(m.ramparts);m.rebuild_navigation()
 check(m.terrain.has_method("flat_corridor"),"The native field can prove a fully covered constant-height corridor")
 if failures:finish();return
 var nav=CountingNavigation.new(m);m.waves.navigation=nav;var flow=m.waves.flow;var e={"variant":0}
 var fixture={}
 for z in range(72,91,6):
  for x in range(-36,37,6):
   var from=Vector3(x,m.surface_height(x,z),z);var to=Vector3(x,m.surface_height(x,z+2),z+2)
   if m.terrain.flat_corridor(from,to,3.9) and flow.corridor_clear(e,from,to,false):fixture={"from":from,"to":to};break
  if not fixture.is_empty():break
 check(not fixture.is_empty(),"The native outer castle terrain has a proven flat supported fixture")
 if fixture.is_empty():finish();return
 var a:Vector3=fixture.from;var b:Vector3=fixture.to;nav.field_queries=0;nav.obstacle_queries=0
 flow.corridor_certificates.clear();nav.terrain_corridors.clear()
 var cell:Vector2i=m.cell_of(a)
 check(flow.corridor_clear(e,a,b,false),"The large soldier retains its supported road corridor")
 check(nav.field_queries==0 and nav.obstacle_queries>0,"A flat proof removes repeated field probes while every obstacle sample remains")
 m.trees[cell]=1.0;m.navigation_revision+=1
 check(not flow.corridor_clear(e,a,b,false),"A new tree still blocks a field-certified flat corridor")
 m.trees.clear();m.navigation_revision+=1;m._make_building("wall",cell,0,1);m.rebuild_navigation()
 check(not flow.corridor_clear(e,a,b,false),"A new solid wall still blocks a field-certified flat corridor")
 a=Vector3(0,m.surface_height(0,108),108);b=Vector3(0,m.surface_height(0,114),114);nav.field_queries=0
 flow.corridor_clear(e,a,b,false)
 check(not m.terrain.flat_corridor(a,b,3.9) and nav.field_queries>0,"The raised road slope keeps native field and step validation")
 finish()
func finish():
 print("SOLDIER_FLAT_CORRIDOR_RESULT checks=",checks," failures=",failures);quit(1 if failures else 0)
