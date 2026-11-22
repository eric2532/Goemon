extends SceneTree
## Live Forest picker: equal cards, separate art, responsive scroll and selections.
const Roster=preload("res://scripts/rogue_roster.gd")
const Picker=preload("res://scripts/rogue_roster_picker.gd")
const Proportions=preload("res://scripts/character_proportions.gd")
var visible_ids=Roster.selection_ids()
var game
var checks=0
var failures=0
var output="/Users/eric/Desktop/Projects_Codex/Sonic/build/Other Files/Asset Toolkit/Character Selection"
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
	create_timer(120).timeout.connect(func():printerr("ROSTER_SELECTION_TIMEOUT");quit(1))
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="):output=arg.trim_prefix("--output=")
	DirAccess.make_dir_recursive_absolute(output)
	root.size=Vector2i(1280,800)
	game=load("res://scenes/forest_shrine.tscn").instantiate();game.settings_path="user://roster-selection-%d.cfg"%OS.get_process_id();root.add_child(game);current_scene=game
	await settle();AudioServer.set_bus_mute(0,true)
	game.selected_rogue_id=1;game.show_rogue_roster();await settle()
	var picker=game.menu.find_child("RosterGrid",true,false).get_parent().get_parent().get_parent().get_parent()
	check(picker is Picker,"Live Forest uses the shared roster picker")
	for id in [20,21,22,23,24,25,26]:check(id not in visible_ids,"Small enemy %d is excluded from selection"%id)
	check(picker.cards.size()==visible_ids.size(),"The gallery shows exactly the visible roster")
	check(picker.grid.columns==4 and visible_ids==Roster.CROSSGATE.keys(),"Blue Cross Gate shows four fighters per row from the current Cross Gate roster")
	check(picker.art.texture.resource_path.ends_with("/crossgate_character_making.png"),"Blue Cross Gate shows the recovered Character Making art")
	check(picker.art.get_global_rect().is_equal_approx(picker.get_global_rect()),"Illustration fills the screen behind the fighter cards")
	check(picker.toolbar.get_theme_stylebox("panel")==picker.dark_toolbar,"Cross Gate toolbar retains its shared frame")
	var back_button:Button=picker.find_child("RogueRosterClose",true,false)
	check(picker.find_child("SpellEquipmentButton",true,false)==null,"Equipment replaces the redundant Loadout button")
	check(back_button.get_theme_stylebox("normal").texture==Picker.PreparationSkin.BUTTON,"Back retains the gallery button style")
	for card in [picker.cards[0],picker.cards[1]]:
		check(card.get_theme_stylebox("normal").texture==Picker.PreparationSkin.COMPACT and card.get_theme_stylebox("focus").border_width_bottom>0,"Fighter uses an ivory/slate card and retains a focus cue")
	await capture("crossgate-1280x800")
	root.size=Vector2i(960,600);await settle()
	check(picker.art.get_global_rect().is_equal_approx(picker.get_global_rect()),"Illustration stays full screen at 960px")
	var first_name_y:float=picker.cards[0].find_child("FighterName",true,false).global_position.y
	check(picker.cards.slice(0,4).all(func(card):return is_equal_approx(card.find_child("FighterName",true,false).global_position.y,first_name_y)),"The first row of portraits aligns at 960px")
	await capture("crossgate-960x600")
	for card in picker.cards:
		var labels=card.find_children("*","Label",true,false)
		check(card.tooltip_text.is_empty(),"No duplicate hover name on "+card.name)
		check(labels.size()==1 and labels[0].name=="FighterName", "Only the fighter name appears below the portrait on "+card.name)
		check(card.find_children("*","Button",true,false).is_empty(),"No skin controls on "+card.name)
	root.size=Vector2i(1280,800);await settle()
	check(picker.find_child("OtherFightersTab",true,false)==null,"Gallery has no tab for hidden fighters")
	for key in ["pirate","edo","samurai","master-thief","mage","red-soldier","blue-gunner","green-spearman","vambee","haya-wolf","vambee-torso","slow-guy"]:
		check(picker.find_child("RogueFighter_"+key,true,false)==null,"Unused fighter %s is hidden"%key)
	check(picker.find_child("RosterSharedHelpers",true,false)==null,"Forest picker has no instruction heading")
	var size_: Vector2=picker.cards[2].size
	for card in picker.cards:
		var id: int=card.get_meta("fighter_id")
		check(id in visible_ids and card.get_parent()==picker.grid,"Fighter %d belongs to the playable gallery"%id)
		if card.visible:check(card.size.is_equal_approx(size_),"Fighter %d has equal gallery space"%id)
		check((card.find_child("SelectionPortrait",true,false).texture.atlas if card.find_child("SelectionPortrait",true,false).texture is AtlasTexture else card.find_child("SelectionPortrait",true,false).texture)==Roster.selection_portrait(id),"Fighter %d loads dedicated selection art"%id)
		if id<=12:check(Roster.selection_portrait_path(id)!=Roster.portrait_path(id),"Fighter %d preserves HUD portrait framing"%id)
		for child in card.get_child(0).get_children():
			if child is Label:check(not "RMB / 3" in child.text,"Forest reserves key 3 for helpers")
		check(card.get_child(0).get_combined_minimum_size().y<=card.size.y,"Fighter %d controls fit inside card"%id)
	if DisplayServer.get_name()!="headless":check(picker.grid.columns==4,"1280px window shows four fighters per row")
	await capture("picker-1280x800")
	root.size=Vector2i(960,600);await settle();picker.refresh_columns();await settle()
	if DisplayServer.get_name()!="headless":check(picker.grid.columns==4,"960px window shows four fighters per row")
	check(picker.find_child("RogueRosterClose",true,false).get_global_rect().end.y<=picker.size.y,"Small-window footer stays accessible")
	picker.scroll.scroll_vertical=0;await settle();await capture("picker-960x600-top")
	picker.cards[-1].grab_focus();await settle()
	check(picker.cards[-1].has_focus(),"Keyboard focus can reach the final fighter")
	await capture("picker-960x600-bottom")
	for id in visible_ids:
		if not game.rogue_roster_open:game.show_rogue_roster()
		await process_frame
		var key="goemon" if id==1 else ("edo" if id==2 else Roster.class_id(id))
		game.menu.find_child("RogueFighter_"+key,true,false).pressed.emit()
		check(game.player.character_id==id,"Card %s selects its actual fighter"%key)
		var model=game.player.model
		check(is_equal_approx(model.body_height_pixels*model.sprite.pixel_size,Proportions.GOEMON_HEIGHT),"Fighter %d matches Kaz's default gameplay height"%id)
	var path=game.settings_path
	game.queue_free();paused=false;await settle()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	print("ROSTER_SELECTION_PICKER_RESULT checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)
