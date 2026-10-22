extends SceneTree
## Removed fighters cannot return through menus, session restore, or saved defenders.
const Roster=preload("res://scripts/rogue_roster.gd")
var game
var checks=0
var failures=0
var config_path="user://roster-selection-%d.cfg"%OS.get_process_id()
var defender_path="user://roster-defender-%d.cfg"%OS.get_process_id()
func _initialize():
	create_timer(90).timeout.connect(func():printerr("FAIL: roster selection timed out");quit(1))
	run.call_deferred()
func check(ok:bool,message:String):
	checks+=1
	print("PASS: " if ok else "FAIL: ",message)
	if not ok:failures+=1
func frames():
	for i in 4:await process_frame
func run():
	set_meta("forest_fighter",4)
	game=load("res://scenes/forest_shrine.tscn").instantiate()
	game.settings_path=config_path;root.add_child(game);current_scene=game
	await frames()
	check(game.player.character_id==1 and game.selected_rogue_id==1 and get_meta("forest_fighter")==1,"Old Samurai session returns to Goemon")
	game.show_rogue_roster();await frames()
	check(game.menu.find_child("RogueFighter_samurai",true,false)==null,"Fighter gallery excludes Samurai")
	check(game.menu.find_child("RogueFighter_musashi",true,false)!=null,"Musashi remains a separate selectable fighter")
	var previous=game.player.character_id
	game.choose_rogue_character(4)
	check(game.player.character_id==previous and game.rogue_roster_open,"A stale Samurai selection cannot close the gallery or select him")
	game.choose_rogue_character(5);await frames()
	check(game.player.character_id==5 and not game.rogue_roster_open,"Ninja keeps his original ID and still selects normally")
	game.show_character_balance(true,4);await frames()
	var balance=game.menu.find_child("BalanceCharacter",true,false)
	check(balance.get_item_index(4)==-1 and balance.get_selected_id()==1,"Removed fighter is excluded from balance choices and falls back safely")
	check(balance.get_item_index(13)>=0 and balance.get_item_index(17)>=0,"Other fighters retain their balance choices")
	game.show_sound_studio(true);await frames()
	var sounds=game.menu.find_child("SoundCharacter",true,false)
	check(sounds.get_item_index(4)==-1 and sounds.get_item_index(13)>=0,"Sound Studio excludes Samurai while keeping Musashi")
	var saved=ConfigFile.new();saved.set_value("defenders","assignments",{"old_samurai":4,"knight":7});saved.save(defender_path)
	var defenders=load("res://scripts/forest/forest_gate_defenders.gd").new()
	defenders.settings_path=defender_path;defenders.load_assignments()
	check(not defenders.assignments.has("old_samurai") and defenders.assignments.get("knight")==7,"Saved Samurai defenders are retired without changing valid assignments")
	defenders.free()
	check(Roster.class_id(5)=="ninja" and Roster.class_id(13)=="musashi" and Roster.class_id(17)=="yae","Removal preserves stable character identities")
	game.queue_free();paused=false;await frames();remove_meta("forest_fighter")
	for path in [config_path,defender_path]:DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	print("ROSTER_SELECTION_RESULT checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)
