extends SceneTree
## Live Forest picker: equal cards, separate art, responsive scroll and selections.
const Roster=preload("res://scripts/rogue_roster.gd")
const Picker=preload("res://scripts/rogue_roster_picker.gd")
var visible_ids=Roster.selection_ids()
class FireFixture extends Node:
	var selected_rogue_id=1
	var rogue_pick_start=false
	var roster_start_mode="defense"
	func choose_rogue_character(_id):pass
	func close_rogue_roster():pass
var game
var checks=0
var failures=0
var output="/Users/eric/Desktop/Projects_Codex/Sonic/build/Other Files/boss-shared-roster-20261018"
func _initialize():run.call_deferred()
func check(ok: bool,message: String):
	checks+=1
	if not ok:failures+=1;printerr("FAIL "+message)
func settle():
	for frame in range(8):await process_frame
func capture(name_: String):
	if DisplayServer.get_name()=="headless":return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output.path_join(name_+".png"))
func run():
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="):output=arg.trim_prefix("--output=")
	DirAccess.make_dir_recursive_absolute(output)
	root.size=Vector2i(1280,800)
	game=load("res://scenes/forest_shrine.tscn").instantiate();game.settings_path="user://roster-selection-test.cfg";root.add_child(game);current_scene=game
	await settle();AudioServer.set_bus_mute(0,true)
	game.selected_rogue_id=1;game.show_rogue_roster();await settle()
	var picker=game.menu.find_child("RosterGrid",true,false).get_parent().get_parent().get_parent().get_parent()
	check(picker is Picker,"Live Forest uses the shared roster picker")
	for id in [20,21,22,23,24,25,26]:check(id not in visible_ids,"Small enemy %d is excluded from selection"%id)
	for id in [13,14,15,27,28,29,30]:check(id in visible_ids,"Boss %d remains selectable"%id)
	check(picker.cards.size()==visible_ids.size(),"The gallery shows exactly the visible roster")
	for key in ["pirate","edo","samurai","master-thief","mage","red-soldier","blue-gunner","green-spearman","vambee","haya-wolf","vambee-torso","slow-guy"]:
		check(picker.find_child("RogueFighter_"+key,true,false)==null,"Unused fighter %s is hidden"%key)
	for id in Roster.HIDDEN_SELECTION_IDS:check(Roster.selection_portrait(id)!=null,"Hidden fighter %d retains its assets and stable ID"%id)
	check(picker.find_child("RosterSharedHelpers",true,false)==null,"Forest picker has no instruction heading")
	var size_: Vector2=picker.cards[0].size
	for index in visible_ids.size():
		var id=visible_ids[index]
		var card=picker.cards[index]
		check(card.get_parent()==picker.grid and card.size.is_equal_approx(size_),"Fighter %d has equal gallery space"%id)
		check(card.find_child("SelectionPortrait",true,false).texture==Roster.selection_portrait(id),"Fighter %d loads dedicated selection art"%id)
		if id<=12:check(Roster.selection_portrait_path(id)!=Roster.portrait_path(id),"Fighter %d preserves HUD portrait framing"%id)
		for child in card.get_child(0).get_children():
			if child is Label:check(not "RMB / 3" in child.text,"Forest reserves key 3 for helpers")
		check(card.get_child(0).get_combined_minimum_size().y<=card.size.y,"Fighter %d controls fit inside card"%id)
	if DisplayServer.get_name()!="headless":check(picker.grid.columns==6,"1280px window uses six columns")
	check(picker.scroll.get_v_scroll_bar().max_value>picker.scroll.size.y,"The remaining fighters can scroll through the gallery")
	await capture("picker-1280x800")
	root.size=Vector2i(960,600);await settle();picker.refresh_columns();await settle()
	if DisplayServer.get_name()!="headless":check(picker.grid.columns==4,"960px window uses four readable columns")
	check(picker.scroll.get_v_scroll_bar().max_value>picker.scroll.size.y,"960px gallery provides scrolling")
	check(picker.find_child("RogueRosterClose",true,false).get_global_rect().end.y<=picker.size.y,"Small-window footer stays accessible")
	picker.scroll.scroll_vertical=0;await settle();await capture("picker-960x600-top")
	picker.cards[-1].grab_focus();await settle()
	check(picker.scroll.scroll_vertical>0,"Keyboard focus scrolls to the final hero")
	await capture("picker-960x600-bottom")
	for id in visible_ids:
		if not game.rogue_roster_open:game.show_rogue_roster()
		await process_frame
		var key="goemon" if id==1 else ("edo" if id==2 else Roster.class_id(id))
		game.menu.find_child("RogueFighter_"+key,true,false).pressed.emit()
		check(game.player.character_id==id,"Card %s selects its actual fighter"%key)
	game.show_character_balance(false,18);await settle()
	var balance_picker=game.menu.find_child("BalanceCharacter",true,false)
	check(balance_picker.item_count==Roster.PLAYABLE_IDS.size() and balance_picker.get_selected_id()==18,"Balance editor retains every stable fighter ID")
	game.show_character_balance(false,2);await settle()
	balance_picker=game.menu.find_child("BalanceCharacter",true,false)
	check(balance_picker.get_selected_id()==2,"Hidden fighters retain editable balance settings")
	for id in Roster.HIDDEN_SELECTION_IDS:check(balance_picker.get_item_index(id)>=0,"Hidden fighter %d retains balance settings"%id)
	game.show_sound_studio(false);await settle()
	var sound_picker=game.menu.find_child("SoundCharacter",true,false)
	check(sound_picker.item_count==visible_ids.size() and sound_picker.get_selected_id()==visible_ids[-1],"Sound picker keeps the current visible fighter selected")
	for id in Roster.HIDDEN_SELECTION_IDS:
		check(sound_picker.get_item_index(id)<0,"Hidden fighter %d is absent from sound settings"%id)
	game.player.select_character(2);game.show_sound_studio(false);await settle()
	sound_picker=game.menu.find_child("SoundCharacter",true,false)
	check(sound_picker.get_selected_id()==1 and game.sound_library.character_id==1,"A hidden sound hub opens on Goemon")
	check(game.player.character_id==2,"Hiding a fighter preserves its internal gameplay implementation")
	# This component is also used by Fire Siege, whose numbered abilities persist.
	game.sound_library.cancel();game.music.stop();game.queue_free();paused=false;await settle()
	var fixture=FireFixture.new();root.add_child(fixture)
	var fire_picker=Picker.new();fire_picker.game=fixture;root.add_child(fire_picker);await settle()
	check(fire_picker.find_child("RosterSharedHelpers",true,false)==null,"Fire Siege does not claim shared Forest helpers")
	var ninja=fire_picker.find_child("RogueFighter_ninja",true,false)
	var native_secondary=false
	for child in ninja.get_child(0).get_children():
		if child is Label and child.text.begins_with("RMB / 4"):native_secondary=true
	check(native_secondary,"Fire Siege still describes its native secondary shortcut")
	fire_picker.queue_free();fixture.queue_free();await settle()
	print("ROSTER_SELECTION_PICKER_RESULT checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)
