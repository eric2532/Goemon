extends SceneTree
var failures=0
var checks=0
func check(ok: bool,message: String):
	checks+=1
	if not ok:failures+=1;printerr("FAIL: "+message)
func _initialize():
	create_timer(60).timeout.connect(func():printerr("FAIL: crosshair timeout");quit(1))
	call_deferred("run")
func frames(n: int=4):
	for i in range(n):await physics_frame
func run():
	var game=load("res://scenes/forest_shrine.tscn").instantiate();root.add_child(game);current_scene=game
	await frames()
	var camera=game.camera_rig.camera
	check(camera.projection==Camera3D.PROJECTION_ORTHOGONAL and camera.size>=100,"Preparation uses the overhead view of the same battlefield")
	game.show_rogue_roster()
	check(game.menu.find_children("RogueFighter_*","Button",true,false).size()==12,"Latest roster includes Goemon, Edo and all ten Rogue heroes")
	game.choose_rogue_character(2)
	check(game.player.character_id==2,"Updated Edo can be selected in Forest Shrine")
	game.close_rogue_roster();game.start_wave();game.model.waves.spawn_clock=10000;await frames()
	check(camera.projection==Camera3D.PROJECTION_PERSPECTIVE,"Wave uses the true perspective crosshair camera")
	check(game.has_method("camera_combat") and game.camera_combat(),"Modern camera-relative combat is enabled")
	check(game.has_method("crosshair_aim_enabled") and game.crosshair_aim_enabled(),"Three-dimensional crosshair aiming is enabled by default")
	check(game.forest_ui.has_method("crosshair_visible") and game.forest_ui.crosshair_visible(),"Fixed reticle appears in live combat")
	check(DisplayServer.get_name()=="headless" or Input.mouse_mode==Input.MOUSE_MODE_CAPTURED,"Combat captures the mouse for ordinary camera look")
	if failures==0:
		var position_before=game.player.position
		var motion=InputEventMouseMotion.new();motion.relative=Vector2(120,90)
		motion.position=root.get_visible_rect().size*Vector2(.6,.45)
		var yaw_before=game.camera_rig.yaw;var pitch_before=game.camera_rig.pitch
		game._input(motion)
		game.camera_rig._unhandled_input(motion)
		check(DisplayServer.get_name()=="headless" or (game.camera_rig.yaw!=yaw_before and game.camera_rig.pitch!=pitch_before),"Mouse movement rotates the camera without a held button")
		check(game.crosshair_screen_position().distance_to(root.get_visible_rect().size*.5)<.1,"Camera look keeps the reticle centred")
		game.show_pause();await frames()
		check(Input.mouse_mode==Input.MOUSE_MODE_VISIBLE and not game.forest_ui.crosshair_visible(),"Pause releases the mouse and hides the reticle")
		game.resume();await frames()
		check((DisplayServer.get_name()=="headless" or Input.mouse_mode==Input.MOUSE_MODE_CAPTURED) and game.forest_ui.crosshair_visible(),"Resume restores camera look and the fixed reticle")
		game.show_rogue_roster();await frames()
		check(Input.mouse_mode==Input.MOUSE_MODE_VISIBLE and not game.forest_ui.crosshair_visible(),"Roster releases the mouse and hides the reticle")
		game.choose_rogue_character(7);await frames()
		check((DisplayServer.get_name()=="headless" or Input.mouse_mode==Input.MOUSE_MODE_CAPTURED) and camera.projection==Camera3D.PROJECTION_PERSPECTIVE,"Hero selection returns to perspective combat and camera look")
		check(game.player.position.distance_to(position_before)<1,"Switching views preserves the hero on the prepared battlefield")
		game.model.phase="preparing";game.set_phase_view();await frames()
		check(camera.projection==Camera3D.PROJECTION_ORTHOGONAL and Input.mouse_mode==Input.MOUSE_MODE_VISIBLE and not game.forest_ui.crosshair_visible(),"Between waves restores building view and free cursor")
	game.queue_free();paused=false;await frames();await create_timer(.35).timeout
	print("FOREST_CROSSHAIR_RESULT checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)
