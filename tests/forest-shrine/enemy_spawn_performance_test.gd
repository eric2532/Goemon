extends SceneTree
## First appearance of each real enemy must fit inside a 60 Hz frame after
## preparation loads. Cold fitted-hull generation used to stall for 24–81 ms.
var game
var failures=0
func _initialize():run.call_deferred()
func run():
	game=load("res://scenes/forest_shrine.tscn").instantiate();root.add_child(game);current_scene=game
	await process_frame;await process_frame
	game.start_wave();game.set_physics_process(false);game.model.waves.spawn_clock=100000
	for kind in range(4):
		var started=Time.get_ticks_usec()
		var data=game.model.waves.spawn_enemy(kind,Vector3(0,0,100+kind*30))
		game.sync_enemies()
		var ms=(Time.get_ticks_usec()-started)/1000.0
		print("FIRST_ENEMY_SPAWN kind=%d ms=%.3f"%[kind,ms])
		if ms>16.667:failures+=1;printerr("FAIL: first enemy spawn exceeds one 60 Hz frame")
		var actor=game.actors[data.id]
		if actor.fitted_shapes.is_empty():failures+=1;printerr("FAIL: spawned enemy requires its fitted colliders")
	print("FOREST_ENEMY_SPAWN_PERFORMANCE_RESULT checks=8 failures=%d"%failures)
	await game.quit_clean();quit(1 if failures else 0)
