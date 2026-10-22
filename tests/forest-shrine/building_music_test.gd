extends SceneTree
var checks=0
var failures=0
var game
var settings_path="user://building-music-test-%s.cfg"%OS.get_process_id()
const BUILD_MUSIC="res://audio/talesweaver_dive.mp3"
const BATTLE_MUSIC="res://audio/talesweaver_reminiscence.mp3"
func _initialize():call_deferred("run")
func check(ok: bool,message: String):
	checks+=1
	if not ok:failures+=1;printerr("FAIL: "+message)
func track(path: String)->bool:return game.music.stream.resource_path==path
func run():
	var config=ConfigFile.new();config.set_value("settings","music_enabled",true);config.save(settings_path)
	game=load("res://scenes/forest_title.tscn").instantiate();game.settings_path=settings_path
	root.add_child(game);current_scene=game
	await process_frame
	check(not game.music.playing and game.settings.music_enabled,"Title stays silent with music enabled")
	game.show_settings(false)
	var title_toggle=game.menu.find_child("BackgroundMusicToggle",true,false)
	title_toggle.button_pressed=false;title_toggle.button_pressed=true
	check(not game.music.playing and game.settings.music_enabled,"Enabling music in title settings preserves silence")
	game.load_settings()
	check(not game.music.playing and game.settings.music_enabled,"Reloading enabled settings cannot start title music")
	game.show_title()
	game.begin_forest();game.choose_rogue_character(7)
	check(game.model.phase=="preparing" and track(BUILD_MUSIC) and game.music.playing,"Selecting Knight starts Dive during building")
	check(paused and game.music.can_process() and not game.music.stream_paused,"Building's paused game tree does not pause its music")
	check(game.music.stream.loop,"Building music loops")
	game.start_wave()
	check(game.model.phase=="wave" and track(BATTLE_MUSIC) and game.music.playing,"Starting combat selects the battle track")
	game.model.phase="preparing";game.set_phase_view()
	check(track(BUILD_MUSIC) and game.music.playing,"Returning to building restores Dive")
	game.show_settings(true)
	var toggle=game.menu.find_child("BackgroundMusicToggle",true,false)
	toggle.button_pressed=false
	check(not game.music.playing,"Settings can mute building music")
	game.resume();game.start_wave()
	check(track(BATTLE_MUSIC) and not game.music.playing,"Combat respects the mute preference")
	game.model.phase="preparing";game.set_phase_view()
	check(track(BUILD_MUSIC) and not game.music.playing,"Returning to building respects mute")
	game.show_settings(true);toggle=game.menu.find_child("BackgroundMusicToggle",true,false);toggle.button_pressed=true
	check(track(BUILD_MUSIC) and game.music.playing,"Settings can enable building music again")
	game.resume();game.show_title()
	check(not game.music.playing and game.settings.music_enabled,"Returning to title stops building music without changing preference")
	game.begin_forest()
	check(not game.music.playing,"Character selection before a run stays silent")
	game.choose_rogue_character(7)
	check(track(BUILD_MUSIC) and game.music.playing,"Starting building again restarts the same track after title silence")
	game.start_wave();game.show_title()
	check(not game.music.playing,"Returning to title stops combat music")
	game.music.stop();paused=false;game.queue_free();await process_frame
	game=load("res://scenes/forest_shrine.tscn").instantiate();game.settings_path=settings_path
	root.add_child(game);current_scene=game;await process_frame
	check(track(BUILD_MUSIC) and game.music.playing,"Direct building launch and retry select Dive")
	game.music.stop();paused=false;game.queue_free();await process_frame
	DirAccess.remove_absolute(settings_path)
	print("BUILDING_MUSIC_RESULT checks=%d failures=%d"%[checks,failures])
	quit(1 if failures else 0)
