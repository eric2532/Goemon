extends SceneTree
var failures=0
func check(ok: bool,message: String):
	if not ok:failures+=1;printerr("FAIL: "+message)
func _initialize():call_deferred("run")
func frames():
	for i in range(3):await process_frame
func press(action: String,down: bool=true):
	var e=InputEventAction.new();e.action=action;e.pressed=down;Input.parse_input_event(e);Input.flush_buffered_events()
func run():
	change_scene_to_file("res://scenes/forest_shrine.tscn");await frames();var game=current_scene
	game.show_rogue_roster();game.choose_rogue_character(7);game.show_rogue_roster();game.close_rogue_roster()
	check(game.paused and not game.ordinary_pause and game.camera_rig.camera.size>=100,"Cancelling the preparation roster restores the overhead grid")
	game.show_pause();game.show_rogue_roster();game.close_rogue_roster()
	check(game.ordinary_pause and game.forest_ui.overlay!=null,"Cancelling a roster opened from pause restores that pause")
	game.resume();game.start_wave();await frames();press("light_attack")
	check(game.player.active_ability.primary_held,"Native attack starts through real input")
	game.show_pause();press("light_attack",false);await frames();game.resume()
	check(not game.player.active_ability.primary_held,"Releasing an attack while paused cannot leave it held after resume")
	game.model.rally(true,game.player.position);game.show_rogue_roster();game.close_rogue_roster()
	check(not game.paused and not game.model.workforce.held and game.camera_rig.camera.projection==Camera3D.PROJECTION_PERSPECTIVE,"Closing the battle roster resumes close combat with rally released")
	var gold=game.model.gold;game.build_kind="wall";game.show_pause()
	check(not game.place_cell(Vector2i(4,4)) and game.model.gold==gold,"A paused battle cannot construct or spend gold")
	game.queue_free();paused=false;await frames();await create_timer(.35).timeout
	print("FOREST_TRANSITION_RESULT failures=%d"%failures);quit(1 if failures else 0)
