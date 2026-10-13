extends SceneTree
var failures=0
func check(ok: bool,message: String):
	if not ok:failures+=1;printerr("FAIL: "+message)
func _initialize():
	create_timer(55).timeout.connect(func():printerr("FAIL: lifecycle timeout");quit(1))
	call_deferred("run")
func settle():
	for i in range(8):await process_frame
func run():
	change_scene_to_file("res://scenes/main.tscn")
	await settle()
	var menu_game=current_scene
	var button=menu_game.find_child("ForestShrineButton",true,false)
	check(button!=null,"Main menu exposes Forest Shrine")
	if button==null:finish();return
	button.pressed.emit();await settle()
	var game=current_scene
	check(game.has_method("place_cell") and game.model.phase=="preparing","Menu entry opens a fresh Forest Shrine settlement")
	game.start_wave();game.model.rally(true,game.player.position)
	game.model.damage_building(1,10000);await settle()
	check(game.model.phase=="defeat" and game.paused,"Shrine destruction opens defeat and freezes combat")
	game.restart_area();await settle();game=current_scene
	check(game.model.wave==0 and game.model.gold==400 and not game.model.workforce.held,"Retry restores a fresh economy and clears held rally")
	game.show_main_menu();await settle()
	check(current_scene.find_child("ForestShrineButton",true,false)!=null and not paused,"Return reaches the unpaused main menu")
	current_scene.queue_free();current_scene=null;await settle();finish()
func finish():print("FOREST_LIFECYCLE_RESULT failures=%d"%failures);quit(1 if failures else 0)
