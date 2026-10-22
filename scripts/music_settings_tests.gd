extends "res://scripts/musashi_tests.gd"

func run():
	visual="--music-settings-visual" in OS.get_cmdline_user_args()
	var original_path=game.settings_path
	var original_settings=game.settings.duplicate()
	game.settings_path="user://music-settings-test-%s.cfg" % OS.get_process_id()
	game.load_settings()
	check(not game.settings.music_enabled and not game.music.playing,"A fresh settings file defaults to music off")
	check(game.music.stream is AudioStreamMP3 and game.music.stream.loop,"The existing looping OST remains available")
	var config=ConfigFile.new()
	config.set_value("settings","volume",.37)
	config.save(game.settings_path)
	game.settings.music_enabled=true;game.apply_music_setting();game.load_settings()
	check(not game.settings.music_enabled and not game.music.playing and game.settings.volume==.37,"Older settings default music off while retaining the user's volume")
	game.show_settings(false)
	await wait(.05)
	var toggle=game.menu.find_child("BackgroundMusicToggle",true,false)
	check(toggle is CheckButton and not toggle.button_pressed,"Main-menu Settings exposes the music toggle in its off state")
	toggle.button_pressed=true
	await wait(.05)
	check(game.settings.music_enabled and game.music.playing,"Enabling the Settings toggle immediately plays music")
	config.load(game.settings_path)
	check(config.get_value("settings","music_enabled",false),"Enabling music saves the preference")
	game.settings.music_enabled=false;game.apply_music_setting();game.load_settings()
	check(game.settings.music_enabled and game.music.playing,"Reloading settings restores an explicitly enabled music preference")
	toggle.button_pressed=false
	game.sound("swing")
	check(not game.music.playing and game.last_sound_voice.playing and is_equal_approx(db_to_linear(AudioServer.get_bus_volume_db(0)),.37),"Disabling music leaves attack sound effects and master volume intact")
	game.load_settings()
	check(not game.settings.music_enabled and not game.music.playing,"The off preference also persists across settings reloads")
	if visual:
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://tests/music-toggle/settings.png")
	game.tuning.freeze_ai=true;game.tuning.invincible=true
	game.start_game();game.encounters.enabled=false
	check(not game.music.playing,"Starting gameplay does not turn disabled music on")
	game.show_pause();game.show_settings(true);await wait(.05)
	toggle=game.menu.find_child("BackgroundMusicToggle",true,false)
	toggle.button_pressed=true
	check(game.paused and game.music.playing,"The same toggle works from paused-game Settings")
	toggle.button_pressed=false;game.resume();game.show_main_menu()
	check(not game.music.playing,"Resume and returning to the menu preserve disabled music")
	game.settings_path=original_path;game.settings=original_settings;game.apply_music_setting()
	AudioServer.set_bus_volume_db(0,linear_to_db(game.settings.volume))
	DirAccess.remove_absolute("user://music-settings-test-%s.cfg" % OS.get_process_id())
	print("MUSIC_SETTINGS_RESULT failures=",failures)
	get_tree().quit(1 if failures else 0)
