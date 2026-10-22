extends 'res://tests/tidefall-town-expanded/checks.gd'
func run():
 root.size=Vector2i(1024,720);root.set_flag(Window.FLAG_NO_FOCUS,true)
 game=load('res://scenes/main.tscn').instantiate();root.add_child(game);await process_frame
 game.smoke_test=true;game.tuning=PrototypeTuning.DEFAULTS.duplicate();game.tuning.freeze_ai=true;game.start_game();game.encounters.enabled=false;game.encounters.pending=0;game.orb_system.active=false
 game.player.smoke_mode=true;game.player.set_physics_process(false);game.player.select_character(2);game.camera_rig.set_process(false);game.camera_rig.set_process_unhandled_input(false);game.hud.hide();game.world.set_process(false);Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
 town=game.world.get_node('TidefallTown');await physics_frame
 await capture('spawn',Vector3(0,game.world.height_at(0,41)+.14,41),0)
 await capture('street',Vector3(-2,game.world.height_at(-2,20)+.14,20),PI/2)
 var h=town.buildings[0]
 await capture('doorway',h.to_global(Vector3(0,.14,20)),h.rotation.y)
 await capture('interior',h.to_global(Vector3(0,.14,1)),h.rotation.y)
 var cam=game.camera_rig.camera;cam.position=h.to_global(Vector3(0,5,9));cam.look_at(h.to_global(Vector3(0,1,-5)));cam.fov=75
 await process_frame;await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png('/tmp/goemon-town-expanded-interior-wide.png')
 var p=game.player
 p.rotation.y=PI;p.model.rotation.y=0;p.model.locomotion.phase=.9;p.model.locomotion.dirty=true;p.model.locomotion.evaluate()
 cam.position=p.position+Vector3(.3,1.6,2.7);cam.look_at(p.position+Vector3.UP*1.55);cam.fov=35
 await process_frame;await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png('/tmp/goemon-town-expanded-edo-face.png')
 cam.position=Vector3(95,70,80);cam.look_at(Vector3(-35,5,-80));cam.fov=75
 await process_frame;await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png('/tmp/goemon-town-expanded-overview.png')
 print('FINAL_NATIVE_REVIEW_COMPLETE count=',town.buildings.size(),' colored_edo=',p.model.rig_visual.scene_file_path)
 game.queue_free();await process_frame;await process_frame;quit()
