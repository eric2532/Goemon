extends SceneTree
var failures=0
var config_path="user://forest-lifecycle-%d.cfg"%OS.get_process_id()
func check(ok: bool,message: String):
	if not ok:failures+=1;printerr("FAIL: "+message)
func _initialize():
	# Scene changes must not pick up the user's saved balance instead of defaults.
	node_added.connect(func(node):
		if node.get_script()==load("res://scripts/forest/forest_game.gd"):node.settings_path=config_path)
	create_timer(55).timeout.connect(func():printerr("FAIL: lifecycle timeout");quit(1))
	call_deferred("run")
func settle():
	for i in range(8):await process_frame
func run():
	change_scene_to_file("res://scenes/forest_title.tscn")
	await settle()
	var menu_game=current_scene
	var button=menu_game.find_child("ForestPlay",true,false)
	check(button!=null,"Title exposes Forest Shrine")
	if button==null:finish();return
	button.pressed.emit();await settle();menu_game.choose_rogue_character(1);await settle()
	var game=current_scene
	check(game.has_method("place_cell") and game.model.phase=="preparing","Menu entry opens a fresh Forest Shrine settlement")
	game.start_wave();game.model.rally(true,game.player.position)
	game.model.damage_building(1,10000);await settle()
	check(game.model.phase=="defeat" and game.paused,"Shrine destruction opens defeat and freezes combat")
	game.restart_area();await settle();game=current_scene
	check(game.model.wave==0 and game.model.gold==1000000 and not game.model.workforce.held,"Retry restores a fresh economy and clears held rally")
	game.show_main_menu();await settle()
	check(current_scene.find_child("ForestPlay",true,false)!=null and paused,"Return reaches the Forest Shrine title")
	current_scene.queue_free();current_scene=null;await settle();finish()
func finish():
	DirAccess.remove_absolute(ProjectSettings.globalize_path(config_path))
	print("FOREST_LIFECYCLE_RESULT failures=%d"%failures);quit(1 if failures else 0)
