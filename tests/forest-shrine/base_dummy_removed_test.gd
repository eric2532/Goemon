extends "res://scripts/recovered_leaders_tests.gd"
## The former practice target stays absent through normal phase transitions.
func absent(label_:String):
	check(not is_instance_valid(game.training_dummy) and game.get_node_or_null("TrainingDummy")==null,label_)
	check(game.enemies.all(func(enemy):return not is_instance_valid(enemy) or not enemy.training_dummy),"No practice target remains in combat queries")
func run():
	var doc=preload("res://tests/forest-shrine/reference/map_document.gd").new()
	doc.load_original();set_meta("forest_custom_layout",doc.data)
	game=load("res://scenes/forest_shrine.tscn").instantiate()
	game.settings_path="user://base-dummy-removed-%s.cfg"%OS.get_process_id()
	root.add_child(game);current_scene=game;await frames(3)
	absent("Preparation has no base dummy")
	check(game.model.placement_error("tower",Vector2i(2,2),0).is_empty(),"The former dummy site accepts construction")
	check(preload("res://scripts/forest/forest_construction_clearance.gd").open_point(game.model,game.model.point(Vector2i(2,2)),.55,[]),"Workers and allies can stand on the former dummy site")
	check(doc.place("tower",Vector2i(2,2),0).is_empty(),"Map editor can reuse the former dummy site")
	game.start_wave();await frames(3)
	absent("Starting a wave does not spawn a dummy")
	game.model.phase="preparing";game.set_phase_view();await frames(3)
	absent("Returning to preparation does not recreate a dummy")
	game.start_wave();await frames(3)
	absent("Later waves also leave the base clear")
	stop_audio(game);game.move_audio.stop();current_scene=null;game.queue_free();paused=false;await frames(3)
	print("BASE_DUMMY_REMOVED_RESULT checks=",checks," failures=",failures)
	quit(0 if failures==0 else 1)
