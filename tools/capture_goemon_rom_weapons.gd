extends "res://tests/forest-shrine/goemon_rom_weapons_test.gd"
const OUTPUT="res://build/Other Files/Asset Toolkit/Goemon Chain and Icons/Gameplay/"
func capture_frame(file:String,description:String):
 game.forest_ui.sync();game.camera_rig.camera.current=true
 await process_frame;await RenderingServer.frame_post_draw
 check(root.get_texture().get_image().save_png(OUTPUT+file)==OK,description)
func run():
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
 root.size=Vector2i(1280,800)
 await setup_fixture()
 game.forest_ui.close_overlay();game.settings.quality=2
 game.camera_rig.camera.global_position=ORIGIN+Vector3(8,5,12)
 game.camera_rig.camera.look_at(ORIGIN+Vector3(0,1,-4))
 var p=game.player;var c=p.chain_pipe_combat
 fresh();ground_player();p.select_weapon(3);c.start();chain_step(4)
 await capture_frame("ground-windup.png","Painterly ground windup uses native action70")
 chain_step(13)
 await capture_frame("ground-extension.png","Original chain head extends with the original weapon HUD")
 c.cancel();fresh();p.select_weapon(3);p.position=ORIGIN+Vector3.UP*4;p.velocity=Vector3.UP;p.move_and_slide();c.start();chain_step(1)
 await capture_frame("air-windup.png","Air attack uses native action75")
 chain_step(5)
 await capture_frame("air-flight.png","Air flight uses native action76 without prone poses")
 c.cancel();fresh(true);ground_player();p.select_weapon(2)
 p.model.animate(1.0,0,true,0,0,false,1,false);p.model.sync_skeleton()
 tap("light_attack");await step(10)
 var coins=get_nodes_in_group("projectiles").filter(func(coin):return coin.get_meta("original_goemon_charged_coin",false))
 check(coins.size()==1,"Rendered golden attack released exactly one flaming ryo")
 if not coins.is_empty():
  coins[0].set_physics_process(false);coins[0].global_position=p.global_position+Vector3(2.1,1.7,1.2)
  check(not coins[0].is_queued_for_deletion(),"The captured flaming projectile is still live")
  print("FLAMING_RENDER ",coins[0].ornament.get_child(0).mesh.get_aabb()," scale=",coins[0].ornament.scale," position=",coins[0].global_position)
 await capture_frame("golden-flaming-ryo.png","Golden Goemon throws the recovered flaming ryo art")
 # Warm the renderer before recording a short focused cost check.
 for i in 60:await process_frame
 var samples=[]
 for i in 120:
  samples.append(root.get_process_delta_time()*1000)
  await process_frame
 samples.sort()
 var report={"frames":samples.size(),"frame_p95_ms":samples[int(samples.size()*.95)],"frame_p99_ms":samples[int(samples.size()*.99)],"focused":root.has_focus(),"note":"Short rendered weapon fixture, no before/after or full-army benchmark."}
 var file=FileAccess.open(OUTPUT+"render-check.json",FileAccess.WRITE);file.store_string(JSON.stringify(report,"  "))
 game.queue_free();await frames(3)
 if FileAccess.file_exists(cfg):DirAccess.remove_absolute(ProjectSettings.globalize_path(cfg))
 print("GOEMON_ROM_RENDER_RESULT checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)
