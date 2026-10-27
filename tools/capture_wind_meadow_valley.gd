extends SceneTree
## Real game capture and controller traversal; no alternate movement simulation.
class Battle extends "res://scripts/forest/forest_game.gd":
 func _sync_camera_mouse():
  if Input.mouse_mode!=Input.MOUSE_MODE_VISIBLE:Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
const OUT="res://build/Other Files/Asset Toolkit/Wind Meadow/Valley/"
var game
var times=[]
func _initialize():run.call_deferred()
func run():
 root.size=Vector2i(1280,800);root.title="Goemon · Wind Meadow Valley"
 set_meta("forest_painterly_preview",true);set_meta("forest_fighter",1)
 game=Battle.new();game.settings_path="user://wind-meadow-review-%d.cfg"%OS.get_process_id();root.add_child(game);current_scene=game
 for i in 10:await process_frame
 if game.model.terrain_source!="wind_meadow":printerr("FAIL: Valley did not load");quit(1);return
 game.camera_rig.set_process(false);game.camera_rig.set_process_unhandled_input(false)
 if DisplayServer.get_name()!="headless":
  game.forest_ui.hide();await shot("valley-overview",Vector3(290,330,360),Vector3(0,5,0),60)
 game.start_wave();game.model.waves.spawn_clock=10000000
 game.camera_rig.set_process(false);game.camera_rig.yaw=0
 if DisplayServer.get_name()!="headless":
  await shot("castle-meadow",Vector3(104,72,132),Vector3(0,10,2),55)
  await shot("valley-ground",Vector3(-24,7,104),Vector3(4,9,-30),68)
  await shot("north-clearing",Vector3(48,46,-125),Vector3(-8,26,-177),65)
  await shot("west-route",Vector3(-165,24,56),Vector3(-33,18,-36),68)
  game.player.position=Vector3(36,game.model.surface_height(36,87)+.1,87);game.player.velocity=Vector3.ZERO
  await shot("goemon-in-valley",Vector3(38,4.5,99),Vector3(35,2,78),64)
 if "--traversal" in OS.get_cmdline_user_args():
  for route in [
   {"name":"castle_to_south","points":[Vector2(3,18),Vector2(3,60),Vector2(0,162)]},
   {"name":"castle_to_east","points":[Vector2(3,18),Vector2(3,60),Vector2(84,66),Vector2(84,6),Vector2(162,0)]},
   {"name":"castle_to_west","points":[Vector2(3,18),Vector2(3,60),Vector2(-78,66),Vector2(-78,0),Vector2(-162,0)]},
   {"name":"castle_to_north","points":[Vector2(3,18),Vector2(3,60),Vector2(-78,66),Vector2(-72,-66),Vector2(0,-84),Vector2(0,-162)]},
   {"name":"outer_north_to_east","points":[Vector2(0,-150),Vector2(114,-114),Vector2(150,0)]}]:
   await traverse(route)
  var file=FileAccess.open(OUT+("traversal-running.json" if "--no-sprint" in OS.get_cmdline_user_args() else "traversal.json"),FileAccess.WRITE);file.store_string(JSON.stringify({"fighter":"Goemon","walk_speed":game.player.combat_tuning("walk_speed"),"sprint_speed":game.player.combat_tuning("sprint_speed"),"controller":"unchanged real player physics; normal running" if "--no-sprint" in OS.get_cmdline_user_args() else "unchanged real player physics; held sprint","routes":times},"  "));file.close()
 if "--stay" in OS.get_cmdline_user_args():
  game.forest_ui.show();game.camera_rig.set_process(true);game.camera_rig.set_process_unhandled_input(true);game.camera_rig.reset_follow();game.model.waves.spawn_clock=2;return
 game.queue_free();for i in 3:await process_frame
 print("WIND_MEADOW_RENDER_REVIEW_PASS");quit()
func shot(file:String,eye:Vector3,focus:Vector3,fov:float):
 var camera:Camera3D=game.camera_rig.camera;camera.projection=Camera3D.PROJECTION_PERSPECTIVE;camera.global_position=eye;camera.look_at(focus);camera.fov=fov;camera.far=2000
 for i in 18:await process_frame
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(ProjectSettings.globalize_path(OUT+file+".png"))
func traverse(route:Dictionary):
 var points:Array=route.points;var first:Vector2=points[0]
 game.player.position=Vector3(first.x,game.model.surface_height(first.x,first.y)+.08,first.y);game.player.velocity=Vector3.ZERO
 for i in 12:await physics_frame
 var started=Time.get_ticks_usec();var simulation=0.0;var distance_=0.0;var last:Vector3=game.player.position;var fell=false
 if "--no-sprint" not in OS.get_cmdline_user_args():Input.action_press("sprint")
 for i in range(1,points.size()):
  var target:Vector2=points[i];var leg_time=0.0
  while Vector2(game.player.position.x,game.player.position.z).distance_to(target)>1.0:
   var p:Vector3=game.player.position;var direction=(target-Vector2(p.x,p.z)).normalized()
   Input.action_press("move_right",maxf(0,direction.x));Input.action_press("move_left",maxf(0,-direction.x));Input.action_press("move_back",maxf(0,direction.y));Input.action_press("move_forward",maxf(0,-direction.y))
   game.camera_rig.camera.global_position=p+Vector3(14,14,20);game.camera_rig.camera.look_at(p+Vector3.UP*2)
   await physics_frame
   var delta=1.0/Engine.physics_ticks_per_second;simulation+=delta;leg_time+=delta;distance_+=game.player.position.distance_to(last);last=game.player.position
   if game.player.position.y<game.model.surface_height(last.x,last.z)-.5:fell=true
   if leg_time>45:printerr("FAIL: Traversal blocked: ",route.name," at ",last);quit(1);return
 for action in ["sprint","move_right","move_left","move_back","move_forward"]:Input.action_release(action)
 var result={"name":route.name,"seconds":simulation,"wall_seconds":(Time.get_ticks_usec()-started)/1000000.0,"travel_distance":distance_,"fell_through_floor":fell}
 times.append(result);print("VALLEY_TRAVERSAL ",JSON.stringify(result))
