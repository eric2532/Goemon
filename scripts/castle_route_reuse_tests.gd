extends SceneTree
const Model=preload("res://scripts/forest/forest_model.gd")
class Navigation extends "res://scripts/forest/forest_enemy_navigation.gd":
 var searches=0
 var contacts=0
 func _find_grid_path(grid_:AStarGrid2D,from:Vector2i,to:Vector2i)->Array:
  searches+=1;return Array(grid_.get_id_path(from,to))
 func move_clear(p:Vector3,r:float)->bool:
  contacts+=1;return super.move_clear(p,r)
var checks=0
var failures=0
func check(ok:bool,label_:String):
 checks+=1
 if not ok:failures+=1;printerr("FAIL: ",label_)
func _initialize():run.call_deferred()
func run():
 var m=Model.new();m.reset(42,{},JSON.parse_string(FileAccess.get_file_as_string("res://assets/maps/forest_kai_highway.json")));var nav=Navigation.new(m);m.waves.navigation=nav
 check(nav.has_method("_grid_path"),"Grid paths share immutable searches within one navigation revision")
 if not nav.has_method("_grid_path"):finish();return
 var g=AStarGrid2D.new();g.region=Rect2i(-5,-5,10,10);g.update()
 var original=nav._grid_path(g,Vector2i(-3,0),Vector2i(3,0));var copy=original.duplicate();original.clear()
 check(nav._grid_path(g,Vector2i(-3,0),Vector2i(3,0))==copy and nav.searches==1,"Shared paths cannot be mutated by individual enemies")
 nav._grid_path(g,Vector2i(-2,0),Vector2i(3,0));check(nav.searches==2,"Different start cells retain their own route")
 var wall=m._make_building("wall",Vector2i(20,20),0,1);m.rebuild_navigation();nav._grid_path(g,Vector2i(-3,0),Vector2i(3,0))
 check(nav.searches==3,"A structure revision invalidates shared paths before they are used")
 nav._sample_approach({"variant":0,"pos":m.point(Vector2i(0,7))},m.buildings[1]);var n=nav.contacts
 nav._sample_approach({"variant":0,"pos":m.point(Vector2i(1,7))},m.buildings[1])
 check(nav.contacts==n,"Enemies with different roots reuse the same live contact ring geometry")
 m._remove_building(wall.id);m.rebuild_navigation();nav._sample_approach({"variant":0,"pos":m.point(Vector2i(1,7))},m.buildings[1])
 check(nav.contacts>n,"Contact rings are recertified after structure changes")
 finish()
func finish():
 print("CASTLE_ROUTE_REUSE_RESULT checks=",checks," failures=",failures);quit(1 if failures else 0)
