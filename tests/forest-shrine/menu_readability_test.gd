extends SceneTree
## Menu copy stays compact and contextual text stays within its frame.
var game
var failures=0
var checks=0
var cfg="user://menu-readability-%d.cfg"%OS.get_process_id()
var output="res://build/Other Files/Maroon UI"
func _initialize():
	if "--visual" in OS.get_cmdline_user_args():root.set_flag(Window.FLAG_NO_FOCUS,true)
	create_timer(90).timeout.connect(func():printerr("FAIL: menu readability timeout");quit(1))
	run.call_deferred()
func check(ok:bool,words:String):
	checks+=1
	if not ok:failures+=1;printerr("FAIL: "+words)
func settle():
	for i in 6:await process_frame
func shot(name_:String):
	if DisplayServer.get_name()=="headless" or "--visual" not in OS.get_cmdline_user_args():return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output.path_join(name_+".png"))
func run():
	root.content_scale_size=Vector2i.ZERO;root.size=Vector2i(1280,800)
	set_meta("forest_painterly_preview",true)
	game=load("res://scenes/forest_shrine.tscn").instantiate();game.settings_path=cfg;root.add_child(game);current_scene=game
	await settle();AudioServer.set_bus_mute(0,true)
	for dimensions in [Vector2i(1280,800),Vector2i(960,600)]:
		root.size=dimensions;await settle()
		var suffix="%dx%d"%[dimensions.x,dimensions.y]
		game.show_title();await settle()
		var title=game.find_child("TitleFrame",true,false)
		check(root.get_visible_rect().encloses(title.get_global_rect()),"Title frame fits "+suffix)
		check(title.get_global_rect().end.x<=dimensions.x*.32,"Title buttons stay clear of Kojiro's face "+suffix)
		check(game.find_child("ForestPlay",true,false).text=="PLAY","Play has a short caption")
		check(game.find_child("ForestPlay",true,false).alignment==HORIZONTAL_ALIGNMENT_CENTER,"Main buttons center their captions")
		var font=game.find_child("ForestPlay",true,false).get_theme_font("font")
		check(font.get_font_name().contains("Oxanium") and font.variation_opentype.get(2003265652)==600.0,"Menus use the shared semibold sci-fi typeface")
		await shot("title-"+suffix)
		game.begin_forest();await settle()
		var picker=game.menu.find_child("RosterGrid",true,false).get_parent().get_parent().get_parent().get_parent()
		for card in picker.cards:
			var labels=card.get_child(0).get_children().filter(func(node):return node is Label)
			check(labels.size()==1 and labels[0].text==card.tooltip_text.to_upper(),"Fighter cards show only their names")
			check(card.get_child(0).get_combined_minimum_size().y<=card.size.y,"%s content fits %s: %s in %s"%[card.name,suffix,card.get_child(0).get_combined_minimum_size(),card.size])
			check(not card.tooltip_text.contains("LMB"),"Fighter cards do not restore control descriptions")
		var footer=picker.find_child("RosterToolbar",true,false)
		check(root.get_visible_rect().encloses(footer.get_global_rect()),"Gallery toolbar fits %s: %s in %s"%[suffix,footer.get_global_rect(),root.get_visible_rect()])
		check(footer.get_global_rect().position.y<picker.scroll.get_global_rect().position.y,"Back and equipment buttons stay at the top")
		check(footer.find_children("*","Button",true,false).all(func(button):return button.alignment==HORIZONTAL_ALIGNMENT_CENTER),"Toolbar buttons center their captions")
		check(picker.find_child("RosterSharedHelpers",true,false)==null,"Gallery has no instruction heading")
		await shot("fighters-"+suffix)
		game.choose_rogue_character(1);await settle()
		var ui=game.forest_ui;ui.message_left=0;ui.sync();await settle()
		check(not ui.hint.visible,"Idle map does not repeat button shortcuts")
		check(ui.find_child("PreparationZoom",true,false)==null,"Map zoom buttons are removed")
		check(ui.ryo_caption.text.is_empty() and ui.find_child("FoodCount",true,false)==null,"Resource badges use icons and current counts only")
		var worker=game.model.workers.values()[0];var worker_state=worker.state
		worker.state="wounded";ui.sync()
		check(ui.worker_count.text==str(game.model.workers.size()),"Worker badge counts all current workers")
		worker.state=worker_state;ui.sync()
		check(not ui.primary_icon.get_parent().visible and not ui.secondary_icon.get_parent().visible,"Mouse attack tiles stay hidden")
		check(ui.hero_portrait.is_visible_in_tree() and ui.player_health_bar.is_visible_in_tree() and ui.health.is_visible_in_tree(),"Preparation keeps the character icon and HP visible")
		check(not ui.hero_name.visible and not ui.loadout_slots.visible and not ui.spell_dock.visible and not ui.ben_utility_tile.visible and ui.cape_buttons.all(func(button):return not button.visible),"Preparation hides character descriptions and keys")
		check(ui.preparation_header.get_global_rect().position.x<48,"Build and mercenary controls sit at the bottom left")
		check(absf(ui.shrine_health_dock.get_global_rect().get_center().x-dimensions.x*.5)<1,"Statue health stays centered")
		check(ui.shrine_health_dock.size.x>=500 and ui.shrine_health_bar.size.y>=28,"Statue health has a wide, thick bar")
		check(not ui.shrine_health_dock.get_global_rect().intersects(ui.preparation_header.get_global_rect()),"Statue health stays clear of navigation")
		check(ui.start_wave_button.get_theme_color("font_color")==ui.PreparationSkin.INK,"Silver buttons use dark text")
		check(ui.start_wave_button.alignment==HORIZONTAL_ALIGNMENT_CENTER,"Preparation buttons center their captions")
		check(ui.start_wave_button.text=="START" and ui.start_wave_button.size.x<=112,"Start has a short caption and proportionate width")
		check(ui.build_menu_button.text=="BUILD" and ui.guard_shop_button.text=="MERCENARIES","Preparation buttons do not repeat keyboard shortcuts")
		await shot("preparation-"+suffix)
		ui.open_build_menu();await settle();await shot("builds-"+suffix)
		ui.show_guard_shop();await settle();await shot("mercenaries-"+suffix)
		ui.close_preparation_menu();ui.notify("Not enough ryo. Build a gold mine or defeat enemies to earn more.");await settle()
		check(ui.hint.has_theme_stylebox_override("normal"),"Context messages have a background frame")
		check(root.get_visible_rect().encloses(ui.hint.get_global_rect()),"Context frame fits "+suffix)
		check(ui.hint.size.y>=ui.hint.get_combined_minimum_size().y,"Context text fits its frame")
		await shot("message-"+suffix)
		game.player.spell_loadout.equip(1,"equip","musashi/charge");game.player.spell_loadout.equip(1,"surge","ben/bombs");game.player.spell_loadout.equip(1,"sky_strike","sasuke/ice")
		ui.preparation_tools_open=true;await settle()
		check(not ui.spell_dock.visible and not ui.loadout_slots.visible,"Equipping skills keeps their descriptions and keys hidden during preparation")
		check(not ui.shrine_health_dock.get_global_rect().intersects(ui.preparation_actions.get_global_rect()),"Statue frame stays clear of wrapped tool buttons")
		check(not ui.preparation_header.get_global_rect().intersects(ui.preparation_actions.get_global_rect()),"Tool buttons stay above navigation")
		await shot("spells-"+suffix)
		for id in [13,18,1]:
			game.player.select_character(id);ui.sync()
			check(ui.hero_portrait.texture!=null and ui.hero_portrait.is_visible_in_tree() and ui.hero_dock.size.x==250,"Preparation keeps a compact portrait when switching to fighter %d"%id)
			check(not ui.spell_dock.visible and not ui.ben_utility_tile.visible and not ui.master_chief_hud.visible,"Switching fighters cannot restore skill text or character-specific keys in preparation")
		game.player.hp=37;ui.sync()
		check(ui.player_health_bar.value==37 and ui.health.text.contains("37"),"Preparation HP continues following current health")
		game.start_wave();await settle()
		check(ui.spell_dock.is_visible_in_tree() and ui.spell_dock.get_global_rect().encloses(ui.spell_summary.get_global_rect()),"Starting combat restores the skill descriptions inside their frame")
		check(ui.hero_name.is_visible_in_tree() and ui.loadout_slots.is_visible_in_tree() and ui.cape_buttons.all(func(button):return button.is_visible_in_tree()),"Starting combat restores the character keys without switching fighters")
		await shot("combat-spells-"+suffix)
		game.model.phase="preparing";game.set_phase_view();await settle()
		check(not ui.spell_dock.visible and not ui.loadout_slots.visible and ui.cape_buttons.all(func(button):return not button.visible),"Returning to preparation hides the descriptions and keys again")
		for action in ["equip","surge","sky_strike"]:game.player.spell_loadout.equip(1,action,"")
		game.show_pause();await settle()
		check(root.get_visible_rect().encloses(ui.overlay.get_global_rect()),"Pause frame fits "+suffix)
		for button in ui.overlay.find_children("*","Button",true,false):
			check(ui.overlay.get_global_rect().encloses(button.get_global_rect()),"Pause button stays inside its frame")
		await shot("pause-"+suffix)
		game.show_settings(true);await settle()
		for item in [["CharacterBalanceButton","CHARACTER BALANCE"],["SoundStudioButton","SOUND STUDIO"],["CameraHUDSettingsButton","CAMERA & HUD"]]:
			var button=game.menu.find_child(item[0],true,false)
			check(button.text==item[1] and button.alignment==HORIZONTAL_ALIGNMENT_CENTER,"Settings uses a short centered caption for "+item[0])
		for id in ["BackgroundMusicToggle","FullscreenToggle"]:
			var toggle=game.menu.find_child(id,true,false)
			check(toggle is CheckButton and toggle.get_theme_stylebox("normal") is StyleBoxEmpty,"Settings switches have no button frame")
		game.resume()
	game.sound_library.cancel();game.music.stop();game.queue_free();paused=false;await settle()
	if FileAccess.file_exists(cfg):DirAccess.remove_absolute(ProjectSettings.globalize_path(cfg))
	print("MENU_READABILITY_RESULT checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)
