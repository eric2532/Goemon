extends SceneTree
var game
var capture_dir="res://tests/forest-shrine/hud-polish"
func _initialize():run.call_deferred()
func run():
	if OS.has_environment("FOREST_HUD_CAPTURE_DIR"):capture_dir=OS.get_environment("FOREST_HUD_CAPTURE_DIR")
	DirAccess.make_dir_recursive_absolute(capture_dir)
	game=load("res://scenes/forest_shrine.tscn").instantiate();root.add_child(game);current_scene=game
	await process_frame;await process_frame;AudioServer.set_bus_mute(0,true)
	game.forest_ui.message_left=0;await capture("preparation")
	game.player.select_character(7);game.start_wave();game.model.waves.spawn_clock=100000
	game.set_physics_process(false);game.player.set_physics_process(false)
	game.player.position=Vector3(3,.15,54);game.player.hp=game.player.max_hp
	game.camera_rig.yaw=PI;game.camera_rig.reset_follow();game.camera_rig._process(0)
	game.forest_ui.message_left=0;await capture("combat-knight")
	game.player.hp=22;game.forest_ui.sync();await capture("damage-trail",2)
	game.player.active_ability.player.cooldowns.flintlock=2.5;game.player.active_ability.set_process(false)
	game.model.wave=3;game.model.waves.pending=48;game.model.waves.giant_pending=true;game.model.waves.spawned=0
	await capture("critical-health-cooldown")
	var sheet=Control.new();game.ui.add_child(sheet)
	for id in range(1,13):
		game.player.select_character(id);game.forest_ui.sync()
		var index=id-1;var tile=Panel.new();tile.position=Vector2(205+(index%6)*172,170+(index/6)*210);tile.size=Vector2(162,194)
		tile.add_theme_stylebox_override("panel",game.forest_ui.skin.lacquer());sheet.add_child(tile)
		game.forest_ui.dock_icon(tile,game.forest_ui.skin.texture("ring"),Vector2(9,9),Vector2(144,144))
		var portrait=game.forest_ui.hero_portrait.duplicate();portrait.position=Vector2(24,24);portrait.size=Vector2(114,114);tile.add_child(portrait)
		var name_=game.forest_ui.dock_label(tile,game.forest_ui.hero_name.text,Vector2(0,160),14);name_.size.x=162;name_.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	game.forest_ui.message_left=0;await capture("all-twelve-portraits")
	sheet.queue_free()
	await process_frame
	game.player.select_character(2);game.player.active_ability.shield_left=1;game.player.active_ability.start_beam()
	game.forest_ui.message_left=0;await capture("edo-sustained-beam",4)
	game.player.active_ability.stop_hold_beam()
	print("FOREST_HUD_POLISH_TOUR_RESULT captures=6")
	await game.quit_clean()
func capture(label: String,frames: int=20):
	for i in range(frames):await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(capture_dir+"/"+label+".png")
