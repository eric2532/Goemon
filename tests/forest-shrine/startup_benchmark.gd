extends SceneTree
var batch_hashes={}
func _initialize():
 run.call_deferred()
func run():
 var started=Time.get_ticks_usec()
 var scene=load("res://scenes/forest_shrine.tscn")
 var loaded=Time.get_ticks_usec()
 var game=scene.instantiate()
 var instantiated=Time.get_ticks_usec()
 root.add_child(game);current_scene=game
 var ready_at=Time.get_ticks_usec()
 await process_frame
 if DisplayServer.get_name()!="headless":await RenderingServer.frame_post_draw
 var drawn=Time.get_ticks_usec()
 if not game.combat_warmup.complete:await game.combat_warmup.finished
 var warmed=Time.get_ticks_usec()
 assert(game.painterly_preview)
 assert(game.army_runtime!=null)
 assert(game.player.character_id==game.selected_rogue_id)
 print("STARTUP_BENCHMARK ",JSON.stringify({"load_ms":(loaded-started)/1000.0,"instantiate_ms":(instantiated-loaded)/1000.0,"ready_ms":(ready_at-instantiated)/1000.0,"first_draw_ms":(drawn-started)/1000.0,"combat_warmed_ms":(warmed-started)/1000.0,"engine_to_warmed_ms":warmed/1000.0,"renderer":DisplayServer.get_name(),"focused":DisplayServer.window_is_focused() if DisplayServer.get_name()!="headless" else false}))
 for batch in game.world.find_children("*","MultiMeshInstance3D",true,false):
  var buffer=batch.multimesh.buffer.to_byte_array()
  var hash_=HashingContext.new();hash_.start(HashingContext.HASH_SHA256);hash_.update(buffer)
  batch_hashes[String(game.world.get_path_to(batch))]={"instances":batch.multimesh.instance_count,"sha256":hash_.finish().hex_encode()}
 var label="before" if "--before" in OS.get_cmdline_user_args() else "after"
 FileAccess.open("res://build/Other Files/Startup Optimization/"+label+"-batches.json",FileAccess.WRITE).store_string(JSON.stringify(batch_hashes," "))
 if DisplayServer.get_name()!="headless":
  root.get_texture().get_image().save_png("res://build/Other Files/Startup Optimization/"+label+"-startup.png")
 if "--hold" in OS.get_cmdline_user_args():await create_timer(50,true).timeout
 game.queue_free();paused=false
 for i in 8:await process_frame
 quit()
