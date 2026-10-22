extends SceneTree
## Render the real playable world and crowd assets for visual inspection.
var game
func _initialize():run.call_deferred()
func frames(count: int):
 for i in range(count):await physics_frame
func capture(label: String,from: Vector3,target: Vector3):
 var camera=game.camera_rig.camera;camera.global_position=from;camera.look_at(target)
 await frames(20);await RenderingServer.frame_post_draw
 var directory="res://build/neon-shrine/captures"
 DirAccess.make_dir_recursive_absolute(directory)
 assert(root.get_texture().get_image().save_png(directory+"/"+label+".png")==OK)
 print("CAPTURE ",label)
func run():
 if DisplayServer.get_name()=="headless":quit(2);return
 game=load("res://scenes/main.tscn").instantiate();game.smoke_test=true;root.add_child(game)
 game.tuning.freeze_ai=true;game.tuning.invincible=true;game.settings.quality=1
 game.start_mode("defense");game.apply_quality();game.encounters.set_physics_process(false)
 DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED);root.size=Vector2i(1280,800)
 Input.mouse_mode=Input.MOUSE_MODE_VISIBLE;Engine.max_fps=60
 game.camera_rig.set_process(false);game.camera_rig.set_physics_process(false)
 game.player.set_physics_process(false)
 await capture("battlefield",Vector3(24,13,216),Vector3(0,3,195))
 await capture("fortress",Vector3(22,14,206),Vector3(0,9,230))
 await capture("shrine",Vector3(24,14,308),Vector3(0,8,330))
 game.encounters.update_start_input(0,false);game.encounters.update_start_input(3.1,true)
 game.encounters._spawn_due(10)
 for enemy in game.enemies:
  enemy.set_physics_process(false);enemy.position=Vector3(60,.15,80)
 var ronin=game.enemies[4];var oni=game.enemies[9]
 game.player.position=Vector3(6,.15,205)
 ronin.position=Vector3(-1.5,.15,196);oni.position=Vector3(1.5,.15,196)
 ronin.rotation.y=PI;oni.rotation.y=PI
 await capture("new-enemies-front",Vector3(0,3.4,203),Vector3(0,1.4,196))
 await capture("new-enemies-profile",Vector3(6,3,197),Vector3(0,1.4,196))
 await capture("new-enemies-back",Vector3(0,3.4,189),Vector3(0,1.4,196))
 game.settings.quality=0;game.apply_quality()
 await capture("low-quality",Vector3(24,13,216),Vector3(0,3,195))
 game.sound_library.cancel();game.music.stop();game.queue_free();await frames(3);quit()
