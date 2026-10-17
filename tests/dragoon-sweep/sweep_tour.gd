extends "res://tests/forest-shrine/explorer_close_assist_test.gd"
func run():
 if DisplayServer.get_name()=="headless":quit(1);return
 game=load("res://scenes/forest_shrine.tscn").instantiate();root.add_child(game);current_scene=game
 await frames(3);game.start_wave();game.model.waves.spawn_clock=10000;game.model.waves.pending=0
 game.set_physics_process(false);game.player.set_physics_process(false);game.camera_rig.set_process(false)
 game.tuning.invincible=true;game.tuning.critical_chance=0.0
 await fresh(8);var c=game.player.active_ability
 target(Vector3(-3,0,-3));target(Vector3(3,0,-3))
 game.camera_rig.camera.global_position=ORIGIN+Vector3(6,4,9)
 game.camera_rig.camera.look_at(ORIGIN+Vector3(0,1,0))
 c.aim=ORIGIN+Vector3(0,0,-30)
 # Freeze the real combat heading; only the authored upper body sweeps.
 c.action("flintlock");c.player.attack.angle=PI;c.player.angle=PI
 var previous=0.0
 for frame in [[.16,"left"],[.28,"first-hit"],[.42,"crossing"],[.58,"right"]]:
  c.tick(frame[0]-previous,false);previous=frame[0];c._animate(.05,0)
  await process_frame;await process_frame;await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png("res://tests/dragoon-sweep/"+frame[1]+".png")
 game.queue_free();await frames(3)
 print("DRAGOON_SWEEP_RENDER_OK");quit()
