extends "res://scripts/recovered_leaders_tests.gd"
const OUT="res://build/Other Files/Asset Toolkit/Wave Settings/"

func run():
	create_timer(90).timeout.connect(func():printerr("FAIL: wave settings timeout");quit(1))
	DirAccess.make_dir_recursive_absolute(OUT)
	game=load("res://scenes/forest_shrine.tscn").instantiate()
	game.settings_path="user://wave-settings-%d.cfg"%OS.get_process_id()
	root.add_child(game);current_scene=game;await frames(4)
	game.set_physics_process(false);game.player.set_physics_process(false);game.camera_rig.set_process(false)
	var model=game.model
	var buildings=model.buildings.duplicate(true)
	var gold=model.gold
	var original=model.balance.waves.duplicate(true)
	game.forest_ui.find_child("PreparationBalance",true,false).pressed.emit();await frames(2)
	var editor=game.menu.find_child("CoreBalance",true,false)
	editor.find_child("Core_wave_count",true,false).value=2
	for wave in 2:
		for slot in game.CoreBalance.TYPES.size():
			editor.find_child("Wave_%d_enemy_%d"%[wave+1,slot],true,false).value=0
	editor.find_child("Wave_1_enemy_0",true,false).value=3
	editor.find_child("Wave_1_enemy_6",true,false).value=2
	editor.find_child("Wave_2_enemy_4",true,false).value=4
	editor.find_child("Core_spawn_group_start",true,false).value=2
	editor.find_child("Core_spawn_group_growth",true,false).value=3
	var configured=game.core_balance.waves.duplicate(true)
	check(model.balance.waves==original,"Preparation edits stay separate until START")
	game.load_settings()
	check(game.core_balance.waves==configured and game.core_balance.spawn_group_start==2 and game.core_balance.spawn_group_growth==3,"Actual wave and group controls persist their values")
	editor.find_child("CoreBalanceBack",true,false).pressed.emit()
	game.start_wave()
	var waves=model.waves
	waves.random_spawn_clock=100000
	check(model.phase=="wave" and model.balance.waves==configured,"START adopts composition and wave count edited on the building map")
	check(waves.pending==5 and waves.remaining_counts==configured[0],"First wave schedules exactly three swords and two Slow Guys")
	check(model.balance.spawn_group_start==2 and model.balance.spawn_group_growth==3,"START adopts edited group size and growth")
	check(model.gold==gold and model.buildings==buildings,"Applying wave settings preserves the built settlement and gold")
	check(waves.countdown_text().contains("WAVE 2 / 2"),"Countdown uses the edited number of waves")
	for attempt in 30:
		for enemy in model.enemies.values():enemy.pos=Vector3.ZERO
		waves.spawn_batch()
		if waves.pending==0:break
	check(model.enemies.size()==5 and waves.pending==0 and model.enemies.values().filter(func(e):return e.variant==0).size()==3 and model.enemies.values().filter(func(e):return e.variant==16).size()==2,"First wave spawns exactly the selected types and totals")
	game.army_runtime.import_arrivals();game.army_runtime.flush_presentation()
	check(game.army_runtime.handles.size()==5,"Every configured first-wave enemy enters the existing native army")
	game.show_pause();game.show_core_balance(true);await frames(2)
	editor=game.menu.find_child("CoreBalance",true,false)
	editor.find_child("Core_wave_count",true,false).value=1
	editor.find_child("Wave_1_enemy_0",true,false).value=99
	editor.find_child("Core_spawn_group_start",true,false).value=9
	editor.find_child("Core_spawn_group_growth",true,false).value=0
	game.start_wave()
	check(model.balance.waves==configured and model.balance.spawn_group_start==2 and model.balance.spawn_group_growth==3,"Paused edits and START cannot rewrite an active battle")
	game.resume();waves.tick(60,model.hero_position)
	check(model.wave==2 and waves.released_waves==2 and model.balance.waves==configured and waves.pending==0 and waves.spawned==9,"Minute two retains the original run's second wave after paused edits")
	if DisplayServer.get_name()!="headless":
		game.forest_ui.sync();await frames(2);await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(OUT+"configured-waves.png")
	var path=game.settings_path
	stop_audio(game);game.move_audio.stop();current_scene=null;game.queue_free();paused=false;await frames(3)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	print("WAVE_SETTINGS_RESULT checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)
