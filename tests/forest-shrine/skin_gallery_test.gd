extends SceneTree
## Skins remain available from the equipment model, outside character selection.
const Roster=preload("res://scripts/rogue_roster.gd")
const OUT="res://build/Other Files/Asset Toolkit/Character Selection/"
var game
var checks=0
var failures=0
func _initialize():run.call_deferred()
func check(ok:bool,message:String):
	checks+=1
	if not ok:failures+=1;printerr("FAIL "+message)
func settle():
	for i in 8:await process_frame
func capture(label_:String):
	if DisplayServer.get_name()=="headless":return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT+label_+".png")
func run():
	create_timer(180).timeout.connect(func():printerr("SKIN_GALLERY_TIMEOUT");quit(1))
	DirAccess.make_dir_recursive_absolute(OUT)
	root.content_scale_size=Vector2i.ZERO;root.size=Vector2i(1280,800)
	game=load("res://scenes/forest_title.tscn").instantiate()
	game.settings_path="user://skin-gallery-%d.cfg"%OS.get_process_id()
	root.add_child(game);current_scene=game;await settle()
	AudioServer.set_bus_mute(0,true)
	game.begin_forest();await settle();game.save_settings()
	for character in Roster.selection_ids():
		check(game.menu.find_child("RosterGrid",true,false).find_children("*","Button",true,false).size()==Roster.selection_ids().size(),"Roster contains only fighter buttons")
		game.choose_rogue_character(character);await settle()
		var hub=game.equipment_hub
		var picker=hub.portrait_button
		if picker.catalog.is_empty():
			check(not picker.visible,"Fighters without alternate skins keep the gallery hidden")
			game.back_from_equipment();await settle()
			continue
		var model=game.player.model
		picker.pressed.emit();await settle()
		check(picker.gallery.visible and picker.choices.item_count==picker.catalog.size(),"Equipment model opens every skin for "+Roster.name_for(character))
		for i in picker.catalog.size():
			if not is_instance_valid(picker.gallery):picker.open_gallery();await settle()
			var id:int=picker.choices.get_item_metadata(i)
			var art=picker.choices.get_item_icon(i)
			var expected=preload("res://scripts/rogue_roster_picker.gd").selection_texture(character,{Roster.skin_setting(character):id})
			check(art is AtlasTexture and art.atlas==expected.atlas and art.region==expected.region and art.margin==expected.margin,"Skin %d shares the equipment's body scale and foot alignment"%id)
			check(not picker.choices.is_item_tooltip_enabled(i),"Skin %d has no hover tooltip"%id)
			picker.choices.item_activated.emit(i);await settle()
			check(picker.selected_id==id and picker.gallery==null,"Skin %d previews and closes with double-click"%id)
			check(Roster.selected_skin(character,hub.preview_settings())==id and Roster.selected_skin(character,game.settings)==id,"Skin %d equips and saves immediately"%id)
			check(hub.portrait.texture.atlas==art.atlas,"Skin %d updates the equipment portrait"%id)
		var saved_config=ConfigFile.new();saved_config.load(game.settings_path)
		check(saved_config.get_value("settings",Roster.skin_setting(character))==picker.selected_id,"Equipped skin is already written to settings")
		root.size=Vector2i(960,600);await settle();picker.open_gallery();await settle()
		check(picker.gallery.size.x<=root.size.x and picker.gallery.size.y<=root.size.y,"Gallery fits a small window")
		picker.choices.select(picker.choices.item_count-1);picker.choices.ensure_current_is_visible();await settle()
		if picker.catalog.size()>15:check(picker.choices.get_v_scroll_bar().value>0,"All skins remain reachable by scrolling")
		if character==Roster.SHIN_ID:await capture("equipment-skins-small")
		var escape=InputEventKey.new();escape.keycode=KEY_ESCAPE;escape.pressed=true
		picker.gallery.push_input(escape,true);await settle()
		check(picker.gallery==null and picker.has_focus() and is_instance_valid(game.equipment_hub),"Escape closes only skins and restores model focus")
		var nodes=get_node_count()
		for i in 3:
			picker.pressed.emit();await settle();picker.gallery.hide();await settle()
		check(get_node_count()==nodes,"Repeated openings release gallery controls")
		check(game.player.model==model,"Skin previews preserve the live model")
		var equipped_skin=picker.selected_id
		game.back_from_equipment();await settle()
		check(Roster.selected_skin(character,game.settings)==equipped_skin,"Back retains the equipped skin")
		root.size=Vector2i(1280,800);await settle()
	var path=game.settings_path
	current_scene=null;game.queue_free();paused=false;await settle()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	print("SKIN_GALLERY_RESULT checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)
