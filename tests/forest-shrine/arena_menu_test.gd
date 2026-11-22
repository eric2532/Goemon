extends "res://scripts/recovered_leaders_tests.gd"
const Document=preload("res://scripts/forest/forest_map_document.gd")
const Roles=preload("res://scripts/forest/forest_enemy_roles.gd")

func run():
	create_timer(180).timeout.connect(func():quit(1))
	var path="user://arena-menu-%d.cfg"%OS.get_process_id()
	game=load("res://scenes/forest_title.tscn").instantiate()
	game.settings_path=path
	root.add_child(game);current_scene=game
	game.set_process(false);game.set_physics_process(false);game.player.set_physics_process(false)
	var city=Document.new(false)
	check(city.read_file("res://tests/forest-shrine/reference/maps/forest_falan_city.json").is_empty(),"City fixture loads")
	set_meta("forest_custom_layout",city.data)
	set_meta("falan_venture",{"falan_areas":{"city":city.data}})
	game.begin_forest();game.choose_rogue_character(game.player.RogueRoster.KAZI_ID);game.equipment_hub.enter_map()
	check(game.model.falan_area=="city" and game.forest_ui.start_wave_button.text=="EXPLORE","The city retains exploration")
	game.start_wave()
	game.show_main_menu()
	await scene_changed
	game=current_scene
	var title_ready=is_instance_valid(game.player) and is_instance_valid(game.menu)
	check(title_ready,"Returning from the city initializes the player and title menu")
	if not title_ready:quit(1);return
	game.settings_path=path
	game.set_process(false);game.set_physics_process(false);game.player.set_physics_process(false)
	var button=game.menu.find_child("ForestPlay",true,false)
	check(button is Button and button.text=="ARENA · SLIME WAVES","The title clearly offers the slime-wave arena")
	button.pressed.emit()
	check(game.rogue_roster_open and game.model.terrain_detail==Document.Model.Arena.ID and game.model.falan_area.is_empty(),"Arena selection leaves the city and loads the actual arena")
	check(not has_meta("falan_venture") and not has_meta("forest_custom_layout"),"City session state cannot leak into arena restart")
	game.choose_rogue_character(game.player.RogueRoster.KAZI_ID)
	check(is_instance_valid(game.equipment_hub) and not game.playing and game.equipment_hub.enter_button.text=="Enter Map","Arena selection opens equipment before the map starts")
	check(game.player.position.is_equal_approx(game.model.point(game.PLAYER_SPAWN_CELL)+Vector3.UP*.15),"Arena starts at its own spawn rather than the city plaza")
	game.equipment_hub.enter_map()
	for i in 240:
		game._physics_process(1.0/60)
		if game.model.enemies.size()==Roles.SLIME_COLORS:break
	check(game.model.phase=="wave" and game.model.enemies.size()==Roles.SLIME_COLORS,"Start releases the first 29 slimes")
	print("ARENA_MENU_STATE phase=",game.model.phase," playing=",game.playing," paused=",game.paused," ordinary_pause=",game.ordinary_pause," enemies=",game.model.enemies.size()," wave=",game.model.wave," released=",game.model.waves.released_waves," detail=",game.model.terrain_detail)
	check(game.model.enemies.values().all(func(enemy):return enemy.variant==Roles.SLIME),"The arena test uses slimes")
	game.model.waves.tick(30.0,game.player.position)
	check(game.model.wave==2 and game.model.waves.released_waves==2,"The arena continues to the next timed wave")
	if DisplayServer.get_name()!="headless":
		game.world.sync(0);game.army_runtime.flush_presentation();game.forest_ui.sync()
		for i in 5:await process_frame
		await RenderingServer.frame_post_draw
		var out="res://build/Other Files/Arena Menu/"
		DirAccess.make_dir_recursive_absolute(out)
		root.get_texture().get_image().save_png(out+"slime-waves.png")
	stop_audio(game);current_scene=null;game.queue_free();paused=false;await frames(3)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	print("ARENA_MENU_RESULT checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)
