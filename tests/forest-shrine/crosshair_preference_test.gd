extends SceneTree
var game
var checks=0
var failures=0
var config_path="user://optional-crosshair-%d.cfg"%OS.get_process_id()
func _initialize():
	create_timer(60).timeout.connect(func():printerr("FAIL: crosshair preference timeout");quit(1))
	run.call_deferred()
func check(ok: bool,message: String):
	checks+=1
	if not ok:failures+=1;printerr("FAIL: "+message)
func frames(n: int=3):
	for i in n:await process_frame
func run():
	game=load("res://scenes/forest_shrine.tscn").instantiate();game.settings_path=config_path;root.add_child(game);current_scene=game;await frames()
	check(game.settings.get("forest_show_crosshair")==true,"Existing saves default to a crosshair for all characters")
	if not game.settings.has("forest_show_crosshair"):await finish();return
	check(not game.forest_ui.crosshair_visible(),"Building mode hides the crosshair")
	game.start_wave();game.model.waves.spawn_clock=10000;game.set_physics_process(false);game.player.set_physics_process(false);game.camera_rig.set_process(false)
	for id in range(1,13):
		game.player.select_character(id);check(game.forest_ui.crosshair_visible(),"Fighter %d has a crosshair, including melee and hybrid kits"%id)
	game.player.select_character(5);game.player.position=Vector3(0,.1,70);game.player.active_ability.player.pos=game.player.position
	game.camera_rig.yaw=0;game.camera_rig.reset_follow();game.camera_rig.update_camera(0)
	var data=game.model.waves.spawn_enemy(0,game.player.position+Vector3(0,0,-2));data.stun=100
	game.sync_enemies();game.actors[data.id].set_physics_process(false);game.model.update_vision(game.player.position);game.world.update_fog()
	game.show_view_settings(true);await frames();var toggle=game.menu.find_child("ShowCrosshairToggle",true,false)
	check(toggle is CheckButton and toggle.button_pressed,"Camera & HUD exposes the enabled Show crosshair toggle")
	if toggle==null:await finish();return
	check(game.forest_ui.crosshair_visible() and game.paused and paused,"Combat settings previews the enabled reticle without resuming battle")
	var target: Vector3=game.crosshair_target();var direction: Vector3=game.projectile_direction(game.player.position+Vector3.UP)
	toggle.button_pressed=false;await frames()
	check(not game.forest_ui.crosshair_visible() and not game.settings.forest_show_crosshair,"Turning off the toggle hides the reticle immediately")
	check(game.crosshair_target().is_equal_approx(target) and game.projectile_direction(game.player.position+Vector3.UP).is_equal_approx(direction),"Crosshair visibility does not change attack aiming")
	var saved=ConfigFile.new();saved.load(config_path);check(saved.get_value("settings","forest_show_crosshair")==false,"The preference saves automatically")
	game.resume();await frames()
	for id in range(1,13):
		game.player.select_character(id);check(not game.forest_ui.crosshair_visible(),"Hidden crosshair stays hidden for fighter %d"%id)
	game.player.select_character(5);game.player.active_ability.player.pos=game.player.position
	game.show_view_settings(true);await frames();toggle=game.menu.find_child("ShowCrosshairToggle",true,false)
	check(not toggle.button_pressed,"Reopening settings retains the hidden state")
	if "--visual" in OS.get_cmdline_user_args():await shot("off")
	toggle.button_pressed=true;await frames();game.resume();await frames()
	if "--visual" in OS.get_cmdline_user_args():await shot("on")
	if DisplayServer.get_name()!="headless":
		game.crowd._process(.016);await frames();var color=game.crowd.batches[0].multimesh.get_instance_color(0)
		check(color.is_equal_approx(game.crowd.PROXY_COLORS[0]),"A reachable enemy keeps its normal color with no gold highlight")
		data.frozen=1;data.frozen_pose=data.duplicate();game.crowd._process(.016);await frames()
		check(game.crowd.batches[0].multimesh.get_instance_color(0).b>.8,"Frozen enemies retain their blue status color")
		data.frozen=0;data.erase("frozen_pose")
	game.show_pause();check(not game.forest_ui.crosshair_visible(),"Pause hides the crosshair")
	game.resume();check(game.forest_ui.crosshair_visible(),"Resume restores the enabled crosshair")
	game.show_view_settings(true);await frames();toggle=game.menu.find_child("ShowCrosshairToggle",true,false)
	toggle.button_pressed=false;game.menu.find_child("ResetViewSettings",true,false).pressed.emit();await frames()
	check(toggle.button_pressed and game.settings.forest_show_crosshair,"Reset restores the enabled default")
	game.set_forest_show_crosshair("bad");check(game.settings.forest_show_crosshair==true,"Invalid toggle input defaults to enabled")
	saved.load(config_path);saved.set_value("settings","forest_show_crosshair",[false]);saved.save(config_path);game.load_settings()
	check(game.settings.forest_show_crosshair==true,"Malformed saved values default to enabled")
	game.set_forest_show_crosshair(false);game.sound_library.cancel();game.music.stop();game.queue_free();paused=false;await frames()
	game=load("res://scenes/forest_shrine.tscn").instantiate();game.settings_path=config_path;root.add_child(game);current_scene=game;await frames();game.start_wave();game.model.waves.spawn_clock=10000
	check(game.settings.forest_show_crosshair==false and not game.forest_ui.crosshair_visible(),"Relaunch restores the disabled preference")
	game.set_forest_show_crosshair(true);check(game.forest_ui.crosshair_visible(),"Enabling restores the crosshair in live combat")
	await finish()
func shot(label: String):
	await RenderingServer.frame_post_draw
	var folder=OS.get_environment("SONIC_AIM_CAPTURE_DIR")
	if folder.is_empty():folder="/tmp"
	root.get_texture().get_image().save_png(folder+"/optional-crosshair-"+label+".png")
func finish():
	game.sound_library.cancel();game.music.stop()
	for voice in game.voices:voice.stop()
	game.queue_free();paused=false;await frames();await create_timer(.35).timeout
	DirAccess.remove_absolute(ProjectSettings.globalize_path(config_path))
	print("FOREST_CROSSHAIR_PREFERENCE_RESULT checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)
