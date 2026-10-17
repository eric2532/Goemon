extends SceneTree
var game
var checks=0
var failures=0
var config_path="user://forest-character-framing-%d.cfg"%OS.get_process_id()
func _initialize():
	create_timer(60).timeout.connect(func():printerr("FAIL: character framing timeout");quit(1))
	run.call_deferred()
func check(ok: bool,message: String):
	checks+=1
	if not ok:failures+=1;printerr("FAIL: "+message)
func settle():
	for i in range(4):await process_frame
func feet()->Vector2:
	return game.camera_rig.camera.unproject_position(game.player.global_position)/root.get_visible_rect().size
func run():
	game=load("res://scenes/forest_title.tscn").instantiate();game.settings_path=config_path;root.add_child(game);current_scene=game;await settle()
	game.show_settings(false);game.menu.find_child("CameraHUDSettingsButton",true,false).pressed.emit();await settle()
	var slider=game.menu.find_child("CharacterScreenPosition",true,false)
	check(slider is HSlider,"Camera & HUD exposes an adjustable character screen position")
	if slider==null:await finish();return
	check(slider.value==0,"Existing saves preserve the current camera framing")
	game.show_title();game.begin_forest();game.choose_rogue_character(5);await settle();game.start_wave()
	game.model.waves.spawn_clock=10000;game.player.set_physics_process(false);game.set_physics_process(false);game.camera_rig.set_process(false)
	game.player.position=Vector3(0,.15,18);game.player.velocity=Vector3.ZERO
	var rig=game.camera_rig;rig.yaw=0;rig.pitch=.22;rig.reset_follow()
	game.set_forest_camera_distance(17)
	game.show_settings(true);game.menu.find_child("CameraHUDSettingsButton",true,false).pressed.emit();await settle()
	slider=game.menu.find_child("CharacterScreenPosition",true,false)
	var baseline=feet();var origin: Vector3=rig.camera.global_position;var forward: Vector3=-rig.camera.global_basis.z
	check(absf(baseline.y-.65259)<.002,"Neutral framing matches the previous zoom-17 screen position")
	slider.value=8;await settle()
	check(absf(feet().y-baseline.y-.08)<.002,"Lowering by 8% moves the character down eight percentage points in the paused preview")
	check(absf(feet().x-baseline.x)<.005,"Vertical framing keeps the character horizontally centered")
	check(rig.camera.global_position.is_equal_approx(origin) and rig.pitch==.22 and rig.yaw==0,"Framing preserves camera collision position and mouse orbit state")
	check((-rig.camera.global_basis.z).y>forward.y+.05,"Lower framing reveals more ahead by raising the view")
	check(game.paused and paused,"Live preview keeps combat paused")
	check(game.menu.find_child("CharacterPositionValue",true,false).text.contains("lower"),"Position readout explains the lower direction")
	var screen=root.get_visible_rect().size;var ray=rig.camera.project_ray_normal(screen*.5)
	var aim=rig.camera.unproject_position(rig.camera.project_ray_origin(screen*.5)+ray*50)
	check(aim.distance_to(screen*.5)<.1,"Crosshair aiming remains aligned with the center of the reframed view")
	var projectile: Vector3=game.projectile_direction(game.player.position+Vector3.UP)
	var target: Vector3=game.crosshair_target()
	check(projectile.dot((target-game.player.position-Vector3.UP).normalized())>.9999,"Actual projectiles follow the reframed crosshair target")
	if "--visual" in OS.get_cmdline_user_args():await shot("lower")
	slider.value=-6;await settle()
	check(absf(feet().y-baseline.y+.06)<.002,"Higher framing moves the character in the opposite direction")
	check(game.menu.find_child("CharacterPositionValue",true,false).text.contains("higher"),"Position readout explains the higher direction")
	for zoom in [7.0,12.0,22.0]:
		game.set_forest_character_screen_offset(0);game.set_forest_camera_distance(zoom);var normal=feet().y
		game.set_forest_character_screen_offset(.08)
		check(absf(feet().y-minf(normal+.08,.88))<.002,"Framing stays predictable and visible at zoom %s"%zoom)
		check(rig.distance==zoom and game.settings.forest_hud_scale==1,"Framing leaves zoom and HUD size independent (%s)"%zoom)
	rig.pitch=-.65;game.set_forest_character_screen_offset(0)
	var upward: Vector3=-rig.camera.global_basis.z
	game.set_forest_character_screen_offset(.08)
	check((-rig.camera.global_basis.z).dot(upward)>.99999 and (-rig.camera.global_basis.z).y>.6,"Lower framing preserves full upward mouse aiming when the character is already below the screen edge")
	rig.pitch=.22;game.set_forest_character_screen_offset(0)
	game.set_forest_camera_distance(17);game.set_forest_character_screen_offset(0)
	game.menu.find_child("ResetViewSettings",true,false).pressed.emit();await settle()
	check(slider.value==0 and game.settings.forest_character_screen_offset==0 and rig.distance==12,"Reset restores neutral framing alongside camera and HUD defaults")
	game.set_forest_character_screen_offset(.08);game.set_forest_camera_distance(17);game.resume();await settle()
	var wall=StaticBody3D.new();wall.collision_layer=1;wall.collision_mask=0
	var collision=CollisionShape3D.new();var shape=BoxShape3D.new();shape.size=Vector3(12,10,1);collision.shape=shape;wall.add_child(collision);game.add_child(wall)
	wall.position=game.player.position+Vector3(0,4,8);await physics_frame;await physics_frame
	game.show_view_settings(true);game.set_forest_character_screen_offset(0);var wall_baseline=feet().y;game.set_forest_character_screen_offset(.15)
	check(rig.current_distance<10 and rig.camera.global_position.z<wall.position.z,"Lower framing retains camera obstruction protection")
	check(feet().y<=maxf(wall_baseline,.88)+.001,"Maximum lower framing cannot push the character farther past the screen edge near a wall")
	wall.queue_free();await settle()
	game.resume();game.model.phase="preparing";game.set_phase_view();await settle()
	var overhead=rig.camera.global_transform
	game.set_forest_character_screen_offset(-.1)
	check(rig.camera.global_transform.is_equal_approx(overhead) and rig.camera.projection==Camera3D.PROJECTION_ORTHOGONAL,"Character framing leaves the building map unchanged")
	game.set_forest_character_screen_offset(NAN);check(game.settings.forest_character_screen_offset==0,"Invalid framing restores the current-height default")
	game.set_forest_character_screen_offset(999);check(game.settings.forest_character_screen_offset==.15,"Framing clamps excessive lower offsets")
	game.set_forest_character_screen_offset(-999);check(game.settings.forest_character_screen_offset==-.1,"Framing clamps excessive higher offsets")
	var saved=ConfigFile.new();saved.load(config_path);saved.set_value("settings","forest_character_screen_offset","bad");saved.save(config_path);game.load_settings()
	check(game.settings.forest_character_screen_offset==0,"Malformed saved framing cannot break the camera")
	game.set_forest_character_screen_offset(.08);game.set_forest_camera_distance(17)
	game.sound_library.cancel();game.music.stop();game.queue_free();paused=false;await settle()
	game=load("res://scenes/forest_shrine.tscn").instantiate();game.settings_path=config_path;root.add_child(game);current_scene=game;await settle()
	check(game.settings.forest_character_screen_offset==.08,"Relaunch restores the saved character position")
	game.player.set_physics_process(false);game.start_wave();game.camera_rig.set_process(false);game.camera_rig.yaw=0;game.camera_rig.pitch=.22;game.camera_rig.reset_follow();game.camera_rig.update_camera(0)
	check(absf(feet().y-.73259)<.003,"Saved framing is actually applied when combat starts after relaunch")
	await finish()
func shot(label: String):
	await RenderingServer.frame_post_draw
	var folder=OS.get_environment("SONIC_FRAMING_CAPTURE_DIR")
	if folder.is_empty():folder="/tmp"
	root.get_texture().get_image().save_png(folder+"/character-framing-"+label+".png")
func finish():
	game.sound_library.cancel();game.music.stop()
	for voice in game.voices:voice.stop()
	game.queue_free();paused=false;await settle();await create_timer(.35).timeout
	DirAccess.remove_absolute(ProjectSettings.globalize_path(config_path))
	print("FOREST_CHARACTER_FRAMING_RESULT checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)
