extends SceneTree
## Removed fighters cannot return through menus or session restore.
const Roster=preload("res://scripts/rogue_roster.gd")
var game
var checks=0
var failures=0
var config_path="user://roster-selection-%d.cfg"%OS.get_process_id()
func _initialize():
	create_timer(90).timeout.connect(func():printerr("FAIL: roster selection timed out");quit(1))
	run.call_deferred()
func check(ok:bool,message:String):
	checks+=1
	print("PASS: " if ok else "FAIL: ",message)
	if not ok:failures+=1
func frames():
	for i in 4:await process_frame
func capture(label_:String):
	if DisplayServer.get_name()=="headless":return
	await RenderingServer.frame_post_draw
	var directory="res://build/Other Files/Asset Toolkit/Cross Gate Roster/"
	DirAccess.make_dir_recursive_absolute(directory)
	root.get_texture().get_image().save_png(directory+label_+".png")
func run():
	root.content_scale_size=Vector2i.ZERO;root.size=Vector2i(1280,800)
	set_meta("forest_fighter",20)
	game=load("res://scenes/forest_shrine.tscn").instantiate()
	game.settings_path=config_path;root.add_child(game);current_scene=game
	await frames()
	check(game.player.character_id==Roster.KAZI_ID and game.selected_rogue_id==Roster.KAZI_ID and get_meta("forest_fighter")==Roster.KAZI_ID,"Old small-enemy session returns to the default Kaz")
	game.show_rogue_roster();await frames()
	var grid=game.menu.find_child("RosterGrid",true,false)
	var picker=grid.get_parent().get_parent().get_parent().get_parent()
	for dimensions in [Vector2i(1280,800),Vector2i(960,600),Vector2i(1600,900),Vector2i(1280,800)]:
		root.size=dimensions;await frames();await frames()
		check(grid.columns==4,"Gallery shows four characters per row at %s"%dimensions)
		var first:Control=picker.cards[0]
		var right:Control=picker.cards[grid.columns-1]
		var scroll_rect:Rect2=picker.scroll.get_global_rect()
		check(absf(first.get_global_rect().position.x-scroll_rect.position.x)<1,"Gallery starts at the left edge at %s"%dimensions)
		check(absf(right.get_global_rect().end.x-scroll_rect.end.x)<=20,"Gallery fills the right side at %s"%dimensions)
		check(root.get_visible_rect().encloses(picker.scroll.get_global_rect()),"Gallery fits the window at %s"%dimensions)
		picker.cards[-1].grab_focus();picker.scroll.ensure_control_visible(picker.cards[-1]);await frames()
		check(scroll_rect.encloses(picker.cards[-1].get_global_rect()),"Last fighter scrolls fully into view at %s"%dimensions)
		if DisplayServer.get_name()!="headless":
			await RenderingServer.frame_post_draw
			DirAccess.make_dir_recursive_absolute("res://build/Other Files/Character Select")
			root.get_texture().get_image().save_png("res://build/Other Files/Character Select/roster-%dx%d.png"%[dimensions.x,dimensions.y])
	check(game.menu.find_child("RogueFighter_samurai",true,false)==null,"Fighter gallery excludes Samurai")
	check(game.menu.find_child("RogueFighter_musashi",true,false)==null,"Musashi is hidden from the player gallery")
	var previous=game.player.character_id
	game.choose_rogue_character(4)
	check(game.player.character_id==previous and game.rogue_roster_open,"A stale Samurai selection cannot close the gallery or select him")
	for id in [20,21,22,23,24,25,26]:
		game.choose_rogue_character(id)
		check(game.player.character_id==previous and game.rogue_roster_open,"A stale small-enemy selection %d cannot change fighters"%id)
	game.choose_rogue_character(Roster.MAZE_ID)
	check(game.player.character_id==previous and game.rogue_roster_open,"Maze has no separate roster selection")
	game.select_kaz_skin(preload("res://scripts/kaz_skins.gd").MAZE)
	game.choose_rogue_character(Roster.KAZI_ID);await frames()
	check(game.player.character_id==Roster.MAZE_ID and not game.rogue_roster_open and get_meta("forest_fighter")==Roster.MAZE_ID,"Kaz's Maze skin is selected and remembered")
	root.size=Vector2i(1440,900)
	game.show_settings(true);await frames()
	game.show_character_balance(true,4);await frames()
	var balance=game.menu.find_child("BalanceCharacter",true,false)
	check(balance.get_selected_id()==Roster.MAZE_ID,"A stale legacy balance request opens the current Cross Gate fighter")
	check(balance.item_count==Roster.CROSSGATE.size(),"Character Balance offers all nine Cross Gate identities, including the Maze appearance")
	for id in Roster.PLAYABLE_IDS:
		check((balance.get_item_index(id)>=0)==Roster.is_crossgate_fighter(id),"Character Balance visibility follows the Cross Gate roster for %d"%id)
	var legacy_profile={"max_hp":321.0,"damage_mult":1.25}
	game.character_tuning.goemon=legacy_profile.duplicate()
	for id in Roster.CROSSGATE:
		game.show_character_balance(true,id);await frames()
		balance=game.menu.find_child("BalanceCharacter",true,false)
		check(balance.get_selected_id()==id,"Cross Gate fighter %d opens independently"%id)
		var hp=game.menu.find_child("Balance_max_hp",true,false)
		hp.value=600+id
		check(game.balance_value(id,"max_hp")==600+id,"Cross Gate fighter %d saves its own balance"%id)
	game.save_settings();game.character_tuning.clear();game.load_settings()
	check(game.character_tuning.goemon==legacy_profile,"Hiding legacy characters preserves their saved balance")
	for id in Roster.CROSSGATE:
		check(game.balance_value(id,"max_hp")==600+id,"Cross Gate balance %d survives reload"%id)
	game.show_character_balance(true,Roster.KAZI_ID);await frames();await capture("character-balance")
	game.player.select_character(1)
	game.show_character_balance(true,1);await frames()
	check(game.menu.find_child("BalanceCharacter",true,false).get_selected_id()==Roster.KAZI_ID,"Legacy active fighter falls back to Kaz in Character Balance")
	game.show_sound_studio(true);await frames()
	var sounds=game.menu.find_child("SoundCharacter",true,false)
	check(sounds.item_count==Roster.CROSSGATE.size() and sounds.get_selected_id()==Roster.KAZI_ID,"Sound Studio shows only Cross Gate characters and falls back to Kaz")
	for id in Roster.PLAYABLE_IDS:
		check((sounds.get_item_index(id)>=0)==Roster.is_crossgate_fighter(id),"Sound Studio visibility follows the Cross Gate roster for %d"%id)
	for id in Roster.CROSSGATE:
		var index=sounds.get_item_index(id)
		sounds.select(index);sounds.item_selected.emit(index)
		check(game.sound_library.character_id==id,"Cross Gate sound hub %d remains selectable"%id)
	check(game.sound_library.mic==null and not game.sound_library.recording,"Browsing Cross Gate sound hubs leaves microphone closed")
	game.player.select_character(Roster.KAZI_ID)
	await capture("sound-studio")
	check(Roster.class_id(5)=="ninja" and Roster.class_id(13)=="musashi" and Roster.class_id(17)=="yae","Hiding preserves stable character identities")
	check(Roster.valid_loadout_key("1") and Roster.valid_loadout_key("13"),"Hidden characters retain valid saved loadout identities")
	game.queue_free();paused=false;await frames();remove_meta("forest_fighter")
	for path in [config_path]:DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	print("ROSTER_SELECTION_RESULT checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)
