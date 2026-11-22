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
func verify_pointer_tip(camera:Camera3D,label_:String):
 var screen:Vector2=game.crosshair_screen_position()
 var hit:Dictionary=game.crosshair_ray_hit()
 check(camera.unproject_position(hit.position).distance_to(screen)<.05,label_+" uses the exact ray point on screen")
 if DisplayServer.get_name()=="headless":return
 await RenderingServer.frame_post_draw
 var frame=root.get_texture().get_image()
 var pixel=frame.get_pixelv(frame.get_size()/2)
 check(minf(pixel.r,minf(pixel.g,pixel.b))>.95,label_+" renders its bright tip over the aim point (%s)"%pixel)
func run():
 root.size=Vector2i(1280,800)
 var doc=load("res://tests/forest-shrine/reference/map_document.gd").new();doc.load_original()
 set_meta("forest_custom_layout",doc.data)
 game=CountedGame.new();game.settings_path="user://crosshair-crowd-%d.cfg"%OS.get_process_id();root.add_child(game);current_scene=game
 await frames()
 game.start_wave();game.model.waves.spawn_clock=100000
 game.set_process(false);game.set_physics_process(false);game.player.set_physics_process(false);game.camera_rig.set_process(false)
 game.camera_rig.set_process_unhandled_input(false)
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
 check(game.forest_ui.attack_pointer_active and not game.aimed_enemy_in_melee_range(game.crosshair_ray_hit()),"The pointer shows a selectable enemy beyond melee reach")
 var row:Dictionary=game.model.waves.spawn_enemy(0,Vector3(0,300,-3))
 game.army_runtime.import_arrivals()
 var soldier:Ninja=game.actors[row.id]
 var cell:Vector2i=game.model.cell_of(soldier.position)
 game.model.visible_cells[cell]=true
 await frames()
 check(game.forest_ui.attack_pointer_active,"A visible native soldier under the aim point shows the sword")
 camera.look_at(Vector3(10,height,-3));await frames()
 check(not game.forest_ui.attack_pointer_active,"A nearby enemy off the aim point keeps the arrow")
 camera.look_at(Vector3(0,height,-100))
 var cover=StaticBody3D.new();cover.collision_layer=1;cover.position=Vector3(0,height,-1.5)
 var blocker=CollisionShape3D.new();blocker.shape=BoxShape3D.new();blocker.shape.size=Vector3(2,2,.2)
 cover.add_child(blocker);game.add_child(cover);await frames()
 check(not game.forest_ui.attack_pointer_active,"Cover between the fighter and enemy keeps the arrow")
 cover.queue_free();game.model.visible_cells.clear();await frames()
 check(not game.forest_ui.attack_pointer_active,"When all enemies on the ray are hidden, the pointer shows the arrow")
 game.model.visible_cells[cell]=true;await frames()
 check(game.forest_ui.attack_pointer_active,"Revealing the same enemy restores the sword")
 game.player.position.z=8;await frames()
 check(game.forest_ui.attack_pointer_active and not game.aimed_enemy_in_melee_range(game.crosshair_ray_hit()),"Backing out of melee reach keeps the sword on the same selectable enemy")
 game.character_tuning={"kazi":{"melee_reach":3.0}};await frames()
 check(game.forest_ui.attack_pointer_active and game.aimed_enemy_in_melee_range(game.crosshair_ray_hit()),"Increasing the equipped fighter's reach brings the soldier into range")
 game.character_tuning={};game.player.position.z=0
 game.player.select_character(game.player.RogueRoster.LANCELOT_ID);await frames()
 check(game.player.active_ability.primary_is_ranged() and game.forest_ui.attack_pointer_active,"A ranged fighter sees the same cue for a selectable enemy")
 game.player.select_character(34);await frames()
 check(game.forest_ui.attack_pointer_active and game.aimed_enemy_in_melee_range(game.crosshair_ray_hit()),"Returning to Kaz keeps the cue over an enemy in melee reach")
 game.player.position.z=8
 game.player.select_character(game.player.RogueRoster.SHIN_ID);await frames()
 check(game.forest_ui.attack_pointer_active and not game.aimed_enemy_in_melee_range(game.crosshair_ray_hit()),"Shin shows the sword over an enemy he can chase beyond melee reach")
 await verify_pointer_tip(camera,"The sword")
 camera.look_at(Vector3(10,height,-3));await frames()
 check(not game.forest_ui.attack_pointer_active,"Shin shows the arrow when its tip moves off the target")
 root.size=Vector2i(960,640);camera.h_offset=.20;camera.v_offset=-.12;await frames()
 await verify_pointer_tip(camera,"The arrow in a resized view with camera offsets")
 camera.h_offset=0;camera.v_offset=0;camera.look_at(Vector3(0,height,-100))
 game.enemies.erase(far);far.queue_free();await frames()
 soldier.mark_dead();await frames()
 check(not game.forest_ui.attack_pointer_active,"A defeated enemy stops showing the sword")
 var cfg:String=game.settings_path
 game.sound_library.cancel();game.music.stop();game.queue_free();paused=false;await frames()
 if FileAccess.file_exists(cfg):DirAccess.remove_absolute(ProjectSettings.globalize_path(cfg))
 print("CROSSHAIR_CROWD_QUERY_RESULT checks=",checks," failures=",failures)
 quit(1 if failures else 0)
