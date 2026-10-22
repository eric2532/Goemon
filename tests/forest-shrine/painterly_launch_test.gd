extends SceneTree
func _initialize():
 create_timer(30).timeout.connect(func():printerr("FAIL: Preview launch timeout");quit(1))
 run.call_deferred()
func run():
 change_scene_to_file("res://scenes/main.tscn")
 for i in 8:await process_frame
 var correct=current_scene!=null and current_scene.get_script().resource_path=="res://scripts/forest/forest_game.gd"
 print("PASS: " if correct else "FAIL: ","Painterly flag routes the ordinary launcher into Forest Shrine")
 if correct:
  correct=current_scene.painterly_preview and current_scene.world.painterly_pilot.enabled and current_scene.preparation_size==90
  print("PASS: " if correct else "FAIL: ","Painterly launch enables and frames the gate pilot")
 if correct:
  if current_scene.player.active_ability!=null:current_scene.player.active_ability.cancel()
  current_scene.sound_library.cancel();current_scene.music.stop()
  for voice in current_scene.voices:voice.stop()
 current_scene.queue_free();paused=false
 for i in 4:await process_frame
 await create_timer(.3).timeout
 print("PAINTERLY_LAUNCH_RESULT failures=",0 if correct else 1);quit(0 if correct else 1)
