extends SceneTree
## Real physics rays must ignore fog without visiting off-ray crowds.
class CountedGame extends "res://scripts/forest/forest_game.gd":
 var visibility_queries=0
 func forest_enemy_visible(enemy)->bool:
  visibility_queries+=1
  return super.forest_enemy_visible(enemy)
class Target extends Ninja:
 func _ready():
  set_process(false);set_physics_process(false);collision_layer=4;collision_mask=0
  var shape=CollisionShape3D.new();shape.shape=BoxShape3D.new();shape.shape.size=Vector3(2,2,2);add_child(shape)
var checks=0
var failures=0
var game
func check(ok:bool,label_:String):
 checks+=1
 if not ok:failures+=1;printerr("FAIL: ",label_)
func _initialize():run.call_deferred()
func frames():
 for i in 3:await physics_frame
func target(point:Vector3)->Target:
 var actor=Target.new();actor.position=point;game.add_child(actor);game.enemies.append(actor);return actor
func verify(expected:Vector3,label_:String,max_queries:int):
 game.visibility_queries=0
 var actual:Vector3=game.crosshair_target()
 check(actual.distance_to(expected)<.01,label_+" retains the exact ray contact (actual %s, expected %s)"%[actual,expected])
 check(game.visibility_queries<=max_queries,label_+" inspects only ray contacts (%d queries)"%game.visibility_queries)
func run():
 root.size=Vector2i(1280,800)
 var doc=load("res://scripts/forest/forest_map_document.gd").new();doc.load_original()
 set_meta("forest_custom_layout",doc.data)
 game=CountedGame.new();game.settings_path="user://crosshair-crowd-%d.cfg"%OS.get_process_id();root.add_child(game);current_scene=game
 await frames()
 game.start_wave();game.model.waves.spawn_clock=100000
 game.set_process(false);game.set_physics_process(false);game.player.set_physics_process(false);game.camera_rig.set_process(false)
 game.player.set_auto_attack(false);game.player.position=Vector3(0,300,0)
 var camera:Camera3D=game.camera_rig.camera
 camera.global_position=Vector3(0,301.1,10);camera.look_at(Vector3(0,301.1,-100))
 var height=301.1
 var near=target(Vector3(0,height,-12));var middle=target(Vector3(0,height,-24));var far=target(Vector3(0,height,-36))
 for i in 600:target(Vector3(600+i*3,height,-36))
 game.model.visible_cells.clear();game.model.visible_cells[game.model.cell_of(far.position)]=true
 await frames()
 verify(Vector3(0,height,-35),"Two hidden enemies before a visible target",3)
 game.model.visible_cells[game.model.cell_of(near.position)]=true
 verify(Vector3(0,height,-11),"Nearest visible target",1)
 game.model.visible_cells.clear()
 verify(Vector3(0,height,-120),"All ray contacts hidden",3)
 var wall=StaticBody3D.new();wall.collision_layer=1;wall.position=Vector3(0,height,-30)
 var shape=CollisionShape3D.new();shape.shape=BoxShape3D.new();shape.shape.size=Vector3(6,6,2);wall.add_child(shape);game.add_child(wall)
 game.model.visible_cells[game.model.cell_of(far.position)]=true
 await frames()
 verify(Vector3(0,height,-29),"Cover behind hidden enemies",2)
 wall.position.z=-6;await frames()
 verify(Vector3(0,height,-5),"Cover before the crowd",0)
 wall.queue_free();middle.queue_free();game.enemies.erase(middle);near.queue_free();game.enemies.erase(near)
 await frames()
 verify(Vector3(0,height,-35),"Deleted front enemies",1)
 var cfg:String=game.settings_path
 game.sound_library.cancel();game.music.stop();game.queue_free();paused=false;await frames()
 if FileAccess.file_exists(cfg):DirAccess.remove_absolute(ProjectSettings.globalize_path(cfg))
 print("CROSSHAIR_CROWD_QUERY_RESULT checks=",checks," failures=",failures)
 quit(1 if failures else 0)
