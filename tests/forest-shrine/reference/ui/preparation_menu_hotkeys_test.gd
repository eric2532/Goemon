extends SceneTree
## Preparation digits act on the selected B/M menu and never leak to weapons.
const TEST_INPUT_DEVICE=27182
class VisualInputGuard extends Node:
	func _input(event:InputEvent):
		if event.device!=27182:get_viewport().set_input_as_handled()
var game
var checks=0
var failures=0
var cfg="user://preparation-menu-hotkeys-%d.cfg"%OS.get_process_id()
func _initialize():

	set_meta("forest_painterly_preview",true)
	if "--visual" in OS.get_cmdline_user_args():root.set_flag(Window.FLAG_NO_FOCUS,true)
	create_timer(60).timeout.connect(func():printerr("FAIL: preparation menu hotkeys timeout");quit(1))
	run.call_deferred()
func check(ok:bool,label_:String):
	checks+=1
	if not ok:failures+=1;printerr("FAIL: ",label_)
func frames():
	for i in 3:await process_frame
func key(code:int,pressed:bool=true,echo:bool=false):
	var event=InputEventKey.new();event.device=TEST_INPUT_DEVICE;event.physical_keycode=code;event.pressed=pressed;event.echo=echo
	root.push_input(event,true);Input.flush_buffered_events()
func tap(code:int):
	key(code);key(code,false)
	await frames()
func click(button:Control):
	var event=InputEventMouseButton.new();event.device=TEST_INPUT_DEVICE;event.button_index=MOUSE_BUTTON_LEFT;event.pressed=true;event.position=button.get_global_rect().get_center()
	root.push_input(event,true);event=event.duplicate();event.pressed=false;root.push_input(event,true);await frames()
func check_start_wave(section:String):
	var button=game.forest_ui.start_wave_button
	var rect=button.get_global_rect();var viewport=root.get_visible_rect()
	check(button.is_visible_in_tree() and not button.disabled and rect.end.distance_to(viewport.end-Vector2(22,16))<1,"Start Wave stays available at the bottom right in %s (button=%s viewport=%s visible=%s)"%[section,rect,viewport,button.is_visible_in_tree()])
	check(not rect.intersects(game.forest_ui.bar_paper.get_global_rect()),"Start Wave stays clear of the tray in "+section)
func run():
	root.content_scale_size=Vector2i.ZERO
	root.size=Vector2i(1280,800)
	var doc=load("res://tests/forest-shrine/reference/map_document.gd").new();doc.load_original();set_meta("forest_custom_layout",doc.data)
	game=load("res://scenes/forest_shrine.tscn").instantiate();game.settings_path=cfg;root.add_child(game);current_scene=game
	if "--visual" in OS.get_cmdline_user_args():
		# Keep physical input from another running Godot window out of screenshot QA.
		var guard=VisualInputGuard.new();guard.process_mode=Node.PROCESS_MODE_ALWAYS;root.add_child(guard)
	await frames();AudioServer.set_bus_mute(0,true)
	check_start_wave("the collapsed menu")
	game.model.gold=5000;game.player.select_character(1);game.player.weapon_slot=3;game.player.set_weapon_visual(3)
	game.model.build("barracks",Vector2i(12,10),0);game.world.sync(0)
	await tap(KEY_B)
	await tap(KEY_B)
	check(game.forest_ui.build_menu_expanded,"Pressing B again keeps the build menu open")
	check_start_wave("Builds")
	var build_tray=game.forest_ui.build_bar.get_global_rect()
	var grid=game.forest_ui.build_bar
	check(grid is GridContainer and grid.columns==4 and grid.get_child_count()==12,"Build menu keeps a fixed four-column, three-row grid")
	for i in 4:
		var button:Button=grid.get_child(i)
		check(button.text.is_empty() and button.size.x>=100 and button.size.y>=100 and button.get_theme_constant("icon_max_width")==80,"Build slot %d uses a large icon and square target"%(i+1))
		check(button.tooltip_text.contains("ryo") or button.tooltip_text.contains("Free"),"Build slot %d shows its price on hover"%(i+1))
		var shortcut=button.get_node("Shortcut")
		check(shortcut.text==str(i+1) and shortcut.get_theme_font_size("font_size")>=28 and shortcut.has_theme_stylebox_override("normal"),"Build slot %d displays a large keyboard keycap"%(i+1))
	for kind in ["tower","barracks","enemy_castle"]:
		check(game.forest_ui.build_buttons[kind].icon.resource_path=="res://assets/ui/forest/buildings/%s.png"%kind,"%s uses a baked portrait of the actual gameplay model"%kind)
	check(game.forest_ui.build_buttons.tower.tooltip_text.contains("Guard Tower") and game.forest_ui.build_buttons.barracks.tooltip_text.contains("Farm"),"Building tooltips show the current building names")
	check(not game.forest_ui.build_frame.get_global_rect().intersects(game.forest_ui.shrine_health_dock.get_global_rect()),"Large building grid stays clear of statue health")
	game.model.gold=0;game.forest_ui.sync()
	check(game.forest_ui.build_buttons.tower.disabled and game.forest_ui.build_buttons.tower.tooltip_text.contains("%d ryo"%game.model.COSTS.tower),"Unaffordable buildings retain their name and current cost on hover")
	game.model.gold=5000;game.forest_ui.sync()
	await capture("build-cards")
	await tap(KEY_1)
	check(game.build_kind=="tower","B then 1 selects tower construction")
	check(game.forest_ui.build_menu_expanded,"Selecting a tower keeps the build tray open")
	var count=game.model.buildings.size();var money=game.model.gold
	await click(game.forest_ui.build_buttons.tower.get_node("Shortcut"))
	check(game.build_kind=="tower" and game.model.buildings.size()==count and game.model.gold==money,"The larger keycap passes clicks to its building button without placing through the grid")
	await click(game.forest_ui.build_buttons.get("barracks",game.forest_ui.build_buttons.tower))
	check(game.build_kind=="barracks" and game.model.buildings.size()==count and game.model.gold==money,"Clicking a build card selects it without placing or charging through the tray")
	await click(grid.get_node("EmptySlot6"))
	check(game.model.buildings.size()==count and game.model.gold==money and game.build_kind=="barracks","Clicking an empty grid slot cannot place a building through the menu")
	check(game.player.weapon_slot==3,"Build menu digits do not select Goemon weapons")
	await tap(KEY_2);check(game.build_kind=="barracks","B then 2 selects barracks construction")
	check(game.place_cell(Vector2i(6,12)) and game.forest_ui.build_menu_expanded and game.build_kind=="barracks","Placing a barracks keeps its build card selected and menu open")
	await tap(KEY_ESCAPE)
	check(game.build_kind.is_empty() and not game.world.preview.visible and not game.ordinary_pause,"Esc cancels repeated building placement without pausing")
	await tap(KEY_B)
	var workers=game.model.workers.size();var gold=game.model.gold
	await tap(KEY_3)
	check(game.model.workers.size()==workers+1 and game.model.gold==gold-50,"B then 3 recruits one paid worker")
	key(KEY_3,true,true);key(KEY_3,false);await frames()
	check(game.model.workers.size()==workers+1,"Held build shortcut cannot repeatedly buy workers")
	await tap(KEY_ESCAPE)
	check(game.build_kind.is_empty() and not game.ordinary_pause,"Esc exits build selection without opening Pause")
	if game.ordinary_pause:game.resume()
	await tap(KEY_M)
	check(game.forest_ui.guard_shop_open(),"M opens the mercenary selection menu")
	check_start_wave("Mercenaries")
	await tap(KEY_M)
	check(game.forest_ui.guard_shop_open(),"Pressing M again keeps the mercenary menu open")
	if not game.forest_ui.guard_shop_open():await tap(KEY_M)
	var mercenary_tray=game.forest_ui.guard_shop.panel.get_global_rect()
	check(mercenary_tray.position.x<build_tray.position.x+1 and mercenary_tray.end.y<=game.forest_ui.preparation_header.get_global_rect().position.y,"Mercenary cards keep their existing bottom tray above the menu tabs")
	root.size=Vector2i(960,600);await frames()
	check_start_wave("Mercenaries in a smaller window")
	check(root.get_visible_rect().encloses(game.forest_ui.guard_shop.panel.get_global_rect()),"Mercenary tray stays inside a smaller game window")
	check(not game.forest_ui.start_wave_button.get_global_rect().intersects(game.forest_ui.guard_shop.panel.get_global_rect()),"Mercenary cards cannot cover Start Wave")
	await tap(KEY_B);check_start_wave("Builds in a smaller window")
	check(root.get_visible_rect().encloses(game.forest_ui.build_frame.get_global_rect()),"All twelve building slots fit inside a smaller window")
	check(not game.forest_ui.build_frame.get_global_rect().intersects(game.forest_ui.shrine_health_dock.get_global_rect()),"Building grid and statue health stay separate in a smaller window")
	await capture("build-grid-small")
	await click(game.forest_ui.preparation_header.get_node("PreparationTools"));check_start_wave("Tools in a smaller window")
	check(game.forest_ui.preparation_actions.is_visible_in_tree() and not game.forest_ui.build_frame.visible,"Tools replaces the enlarged grid without covering its slots")
	await tap(KEY_M)
	root.size=Vector2i(1280,800);await frames();await capture("mercenary-cards")
	gold=game.model.gold
	var food=game.model.food_used()
	for entry in [[KEY_1,2,"Ninja"],[KEY_2,0,"Dragoon"],[KEY_3,1,"Ranger"],[KEY_4,4,"Explorer"],[KEY_5,3,"Knight"]]:
		await tap(entry[0])
		check(game.explorer_helpers.active_units(entry[1]).size()==1 and not game.explorer_helpers.placement_active(),"M then %d hires %s at the castle"%[entry[0]-KEY_1+1,entry[2]])
	check(game.model.gold==gold-470 and game.model.food_used()==food+10,"Five hotkeys charge their displayed prices and two food each")
	check(game.player.weapon_slot==3,"Mercenary digits do not switch weapons")
	check(game.forest_ui.guard_shop_open(),"Hiring keeps the mercenary menu open")
	await tap(KEY_ESCAPE)
	check(not game.forest_ui.guard_shop_open() and not game.explorer_helpers.placement_active() and not game.ordinary_pause,"Esc exits mercenaries and leaves no placement preview without pausing")
	if game.ordinary_pause:game.resume()
	await tap(KEY_M);await tap(KEY_1);await tap(KEY_B);await tap(KEY_2)
	check(game.build_kind=="barracks" and not game.explorer_helpers.placement_active() and not game.forest_ui.guard_shop_open(),"B switches from hiring to building without selecting a placement preview")
	await tap(KEY_M)
	check(game.build_kind.is_empty() and game.forest_ui.guard_shop_open(),"M switches from building to mercenaries")
	await tap(KEY_ESCAPE)
	if game.ordinary_pause:game.resume()
	game.model.gold=0;await tap(KEY_M);await tap(KEY_1)
	check(not game.explorer_helpers.placement_active() and game.model.gold==0,"Mercenary hotkeys cannot bypass insufficient funds")
	check(game.forest_ui.hint.visible and not game.forest_ui.hint.text.is_empty(),"Purchase rejection stays visible while the mercenary menu is open")
	await tap(KEY_ESCAPE)
	if game.ordinary_pause:game.resume()
	game.show_pause();await tap(KEY_B);await tap(KEY_M);await tap(KEY_3)
	check(game.ordinary_pause and not game.forest_ui.guard_shop_open() and game.model.workers.size()==workers+1,"Paused B/M shortcuts cannot open menus or recruit")
	game.resume();await tap(KEY_M);await click(game.forest_ui.start_wave_button);game.model.waves.spawn_clock=100000
	check(not game.forest_ui.start_wave_button.is_visible_in_tree(),"Start Wave launches combat from Mercenaries and hides during the wave")
	await tap(KEY_B);await tap(KEY_M)
	check(game.model.phase=="wave" and not game.forest_ui.guard_shop_open(),"Build and mercenary menus stay closed during combat")
	game.player.select_character(18);await tap(KEY_2)
	check(game.player.master_chief_combat.weapon_slot==2,"Combat number keys still select assigned weapons")
	await finish()
func capture(label_:String):
	if "--visual" not in OS.get_cmdline_user_args() or DisplayServer.get_name()=="headless":return
	for i in 3:await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("/Users/eric/Desktop/Projects_Codex/Sonic/build/Other Files/Menu Assets/"+label_+".png")
	if label_=="build-cards":
		var motion=InputEventMouseMotion.new();motion.device=TEST_INPUT_DEVICE;motion.position=game.forest_ui.build_buttons.tower.get_global_rect().get_center()
		root.push_input(motion,true);Input.flush_buffered_events();await create_timer(.8).timeout;await RenderingServer.frame_post_draw
		check(root.gui_get_hovered_control()==game.forest_ui.build_buttons.tower,"Large building icons receive real pointer hover")
		root.get_texture().get_image().save_png("/Users/eric/Desktop/Projects_Codex/Sonic/build/Other Files/Menu Assets/build-grid-hover.png")
	if label_=="mercenary-cards":
		var previous_pan=game.pan;var previous_size=game.preparation_size
		for b in game.model.buildings.values():
			if b.kind=="barracks":game.pan=game.model.center(b);break
		game.preparation_size=50;game.update_preparation_camera();await frames();await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("/Users/eric/Desktop/Projects_Codex/Sonic/build/Other Files/Menu Assets/barracks.png")
		game.pan=previous_pan;game.preparation_size=previous_size;game.update_preparation_camera();await frames()
func finish():
	game.sound_library.cancel();game.music.stop();game.queue_free();paused=false
	await frames();await create_timer(.25).timeout
	if FileAccess.file_exists(cfg):DirAccess.remove_absolute(ProjectSettings.globalize_path(cfg))
	print("PREPARATION_MENU_HOTKEYS_RESULT checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)
