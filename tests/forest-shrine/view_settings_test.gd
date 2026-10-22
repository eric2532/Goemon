extends SceneTree
var game
var checks=0
var failures=0
var config_path="user://forest-view-settings-%d.cfg"%OS.get_process_id()
func _initialize():
	create_timer(60).timeout.connect(func():printerr("FAIL: view settings timeout");quit(1))
	run.call_deferred()
func check(ok: bool,message: String):
	checks+=1
	if not ok:failures+=1;printerr("FAIL: "+message)
func settle():
	for i in range(4):await process_frame
func run():
	game=load("res://scenes/forest_title.tscn").instantiate();game.settings_path=config_path;root.add_child(game);current_scene=game;await settle()
	check(is_equal_approx(game.camera_rig.distance,12),"New Forest camera defaults to a modestly wider view")
	game.show_settings(false);await settle()
	var entry=game.menu.find_child("CameraHUDSettingsButton",true,false)
	check(entry is Button,"Settings exposes Camera & HUD")
	if entry==null:await finish();return
	entry.pressed.emit();await settle()
	var zoom=game.menu.find_child("CombatCameraDistance",true,false)
	var scale=game.menu.find_child("HUDScale",true,false)
	check(zoom is HSlider and scale is HSlider,"Dedicated view settings has two adjustable sliders")
	check(game.settings_open and game.ordinary_pause and paused and game.forest_ui.visible,"View settings keeps the game paused with live HUD preview")
	check(not game.forest_ui.build_bar.visible,"HUD preview keeps building controls clear of settings")
	zoom.value=17;scale.value=85;await settle()
	check(is_equal_approx(game.camera_rig.distance,17) and is_equal_approx(game.forest_ui.hero_dock.scale.x,.85),"Both controls update immediately")
	check(game.menu.find_child("CameraDistanceValue",true,false).text=="17.0" and game.menu.find_child("HUDScaleValue",true,false).text=="85%","Sliders show their current values")
	var saved=ConfigFile.new();check(saved.load(config_path)==OK and saved.get_value("settings","forest_camera_distance")==17 and is_equal_approx(saved.get_value("settings","forest_hud_scale"),.85),"View preferences save automatically")
	if "--visual" in OS.get_cmdline_user_args():await shot("title-settings")
	var escape=InputEventKey.new();escape.physical_keycode=KEY_ESCAPE;escape.pressed=true;game._input(escape);await settle()
	check(game.menu.find_child("CameraHUDSettingsButton",true,false)!=null and not game.forest_ui.visible,"Escape returns to Settings and ends preview")
	game.show_title();game.begin_forest();game.choose_rogue_character(5);await settle()
	var ui=game.forest_ui
	for factor in [.65,1.25]:
		game.set_forest_hud_scale(factor);await settle()
		var row=ui.loadout_slots.get_global_rect()
		check(row.end.y<ui.bar_paper.get_global_rect().position.y,"Scaled loadout stays above the building controls (%s)"%factor)
		check(absf(row.get_center().x-ui.hero_portrait.get_global_rect().get_center().x)<1,"Scaled portrait and slots remain centered (%s)"%factor)
		check(ui.preparation_actions.position.y>ui.loadout_slots.get_global_rect().end.y,"Map actions stay below the scaled loadout (%s)"%factor)
		await click(ui.loadout_buttons[3]);check(ui.selected_loadout_slot==-1 and ui.loadout_buttons[3].disabled,"Scaled unassigned slots remain empty (%s)"%factor)
		for node in [ui.hero_dock,ui.loadout_slots,ui.find_child("ResourceHub",true,false),ui.shrine_health_dock]:
			var r=node.get_global_rect();var screen=root.get_visible_rect()
			check(r.position.x>=0 and r.end.x<=screen.end.x and r.position.y>=0 and r.end.y<=screen.end.y,"HUD bounds stay on screen at %s (%s)"%[factor,node.name])
		check(ui.reticle.scale==Vector2.ONE and ui.build_bar.scale==Vector2.ONE,"HUD scaling preserves aim reticle and construction controls")
	game.start_wave();game.model.waves.spawn_clock=10000;await settle()
	check(game.camera_rig.distance==17,"Starting combat preserves the chosen zoom")
	game.show_settings(true);game.menu.find_child("CameraHUDSettingsButton",true,false).pressed.emit();await settle()
	zoom=game.menu.find_child("CombatCameraDistance",true,false);scale=game.menu.find_child("HUDScale",true,false)
	var previous: Vector3=game.camera_rig.camera.global_position
	zoom.value=20;scale.value=65;await settle()
	check(game.camera_rig.camera.global_position.distance_to(previous)>.5 and game.paused and paused,"Combat zoom visibly updates without resuming the battle")
	check(ui.hero_dock.scale==Vector2.ONE*.65 and ui.reticle.scale==Vector2.ONE,"Combat preview applies HUD scale independently of crosshair")
	if "--visual" in OS.get_cmdline_user_args():await shot("combat-small")
	scale.value=125;await settle()
	if "--visual" in OS.get_cmdline_user_args():await shot("combat-large")
	game.resume()
	var wall=StaticBody3D.new();wall.collision_layer=1;wall.collision_mask=0
	var collision=CollisionShape3D.new();var shape=BoxShape3D.new();shape.size=Vector3(12,10,1);collision.shape=shape;wall.add_child(collision);game.add_child(wall)
	wall.position=game.player.position+Vector3(0,4,8);await settle()
	game.show_settings(true);game.menu.find_child("CameraHUDSettingsButton",true,false).pressed.emit();await settle()
	zoom=game.menu.find_child("CombatCameraDistance",true,false);scale=game.menu.find_child("HUDScale",true,false)
	zoom.value=22;await settle()
	check(game.camera_rig.current_distance<10 and game.settings.forest_camera_distance==22,"Paused camera preview respects walls without overwriting desired zoom")
	wall.queue_free();await settle()
	game.menu.find_child("ResetViewSettings",true,false).pressed.emit();await settle()
	check(zoom.value==12 and scale.value==100 and game.camera_rig.distance==12 and ui.hero_dock.scale==Vector2.ONE,"Reset restores the wider default camera and compact HUD")
	zoom.value=17;scale.value=85;game.resume();await settle()
	var wheel=InputEventMouseButton.new();wheel.button_index=MOUSE_BUTTON_WHEEL_DOWN;wheel.pressed=true;game.camera_rig._unhandled_input(wheel)
	check(game.camera_rig.distance==17.5 and game.settings.forest_camera_distance==17.5,"Combat mouse-wheel zoom uses and saves the same preference")
	game.show_rogue_roster();game.choose_rogue_character(7);await settle()
	check(game.camera_rig.distance==17.5 and ui.hero_dock.scale==Vector2.ONE*.85,"Character changes retain camera and HUD preferences")
	game.model.phase="preparing";game.set_phase_view();await settle()
	check(game.camera_rig.camera.projection==Camera3D.PROJECTION_ORTHOGONAL and game.preparation_size==game.preparation_map_frame().size,"Combat zoom leaves the overhead building camera independent")
	game.set_forest_camera_distance(NAN);game.set_forest_hud_scale("bad")
	check(game.settings.forest_camera_distance==12 and game.settings.forest_hud_scale==1,"Invalid view values restore safe defaults")
	game.set_forest_camera_distance(1000);game.set_forest_hud_scale(.01)
	check(game.settings.forest_camera_distance==22 and game.settings.forest_hud_scale==.65,"Programmatic view values respect usable bounds")
	saved.load(config_path);saved.set_value("settings","forest_camera_distance","far");saved.set_value("settings","forest_hud_scale",[2]);saved.save(config_path);game.load_settings()
	check(game.camera_rig.distance==12 and ui.hero_dock.scale==Vector2.ONE,"Malformed saved preferences cannot break camera or HUD layout")
	game.set_forest_camera_distance(17);game.set_forest_hud_scale(.85)
	game.sound_library.cancel();game.music.stop();game.queue_free();paused=false;await settle()
	game=load("res://scenes/forest_shrine.tscn").instantiate();game.settings_path=config_path;root.add_child(game);current_scene=game;await settle()
	check(game.camera_rig.distance==17 and game.forest_ui.hero_dock.scale==Vector2.ONE*.85,"Relaunch restores both saved view preferences")
	await finish()
func click(button: Button):
	var e=InputEventMouseButton.new();e.position=button.get_global_rect().get_center();e.button_index=MOUSE_BUTTON_LEFT;e.pressed=true;root.push_input(e,true);await process_frame
	e=e.duplicate();e.pressed=false;root.push_input(e,true);await process_frame
func shot(label: String):
	await RenderingServer.frame_post_draw
	var folder=OS.get_environment("SONIC_VIEW_CAPTURE_DIR")
	if folder.is_empty():folder="/tmp"
	root.get_texture().get_image().save_png(folder+"/view-settings-"+label+".png")
func finish():
	game.sound_library.cancel();game.music.stop()
	for voice in game.voices:voice.stop()
	game.queue_free();paused=false;await settle();await create_timer(.35).timeout
	DirAccess.remove_absolute(ProjectSettings.globalize_path(config_path))
	print("FOREST_VIEW_SETTINGS_RESULT checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)
