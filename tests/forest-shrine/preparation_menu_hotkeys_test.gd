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
	set_meta("forest_army_backend","legacy")
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
func run():
	root.size=Vector2i(1280,800)
	var doc=load("res://scripts/forest/forest_map_document.gd").new();doc.load_original();set_meta("forest_custom_layout",doc.data)
	game=load("res://scenes/forest_shrine.tscn").instantiate();game.settings_path=cfg;root.add_child(game);current_scene=game
	if "--visual" in OS.get_cmdline_user_args():
		# Keep physical input from another running Godot window out of screenshot QA.
		var guard=VisualInputGuard.new();guard.process_mode=Node.PROCESS_MODE_ALWAYS;root.add_child(guard)
	await frames();AudioServer.set_bus_mute(0,true)
	game.model.gold=5000;game.player.select_character(1);game.player.weapon_slot=3;game.player.set_weapon_visual(3)
	game.model.build("barracks",Vector2i(12,10),0);game.world.sync(0)
	await tap(KEY_B)
	await tap(KEY_B)
	check(game.forest_ui.build_menu_expanded,"Pressing B again keeps the build menu open")
	var build_tray=game.forest_ui.build_bar.get_global_rect()
	await capture("build-cards")
	await tap(KEY_1)
	check(game.build_kind=="tower","B then 1 selects tower construction")
	check(game.forest_ui.build_menu_expanded,"Selecting a tower keeps the build tray open")
	var count=game.model.buildings.size();var money=game.model.gold
	await click(game.forest_ui.build_buttons.get("barracks",game.forest_ui.build_buttons.tower))
	check(game.build_kind=="barracks" and game.model.buildings.size()==count and game.model.gold==money,"Clicking a build card selects it without placing or charging through the tray")
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
	await tap(KEY_M)
	check(game.forest_ui.guard_shop_open(),"Pressing M again keeps the mercenary menu open")
	if not game.forest_ui.guard_shop_open():await tap(KEY_M)
	var mercenary_tray=game.forest_ui.guard_shop.panel.get_global_rect()
	check(mercenary_tray.position.distance_to(build_tray.position)<1 and mercenary_tray.size.distance_to(build_tray.size)<1,"M cards occupy the same bottom tray as B")
	root.size=Vector2i(960,600);await frames()
	check(root.get_visible_rect().encloses(game.forest_ui.guard_shop.panel.get_global_rect()),"Mercenary tray stays inside a smaller game window")
	root.size=Vector2i(1280,800);await frames();await capture("mercenary-cards")
	gold=game.model.gold
	for entry in [[KEY_1,2,"Ninja"],[KEY_2,0,"Dragoon"],[KEY_3,1,"Ranger"],[KEY_4,4,"Explorer"]]:
		await tap(entry[0])
		check(game.explorer_helpers.selected_slot==entry[1],"M then %d selects %s for map placement"%[entry[0]-KEY_1+1,entry[2]])
	check(game.model.gold==gold and game.explorer_helpers.active_units().is_empty(),"Mercenary selection never charges before valid map placement")
	check(game.player.weapon_slot==3,"Mercenary digits do not switch weapons")
	var food=game.model.food_used()
	check(game.explorer_helpers.purchase(4,game.model.point(Vector2i(5,10))) and game.forest_ui.guard_shop_open(),"Placing a fighter keeps the mercenary menu open")
	check(game.model.food_used()==food+2,"Placing a fighter consumes two shared food")
	await tap(KEY_ESCAPE)
	check(not game.forest_ui.guard_shop_open() and not game.explorer_helpers.placement_active() and not game.ordinary_pause,"Esc exits mercenaries and cancels the preview without pausing")
	if game.ordinary_pause:game.resume()
	await tap(KEY_M);await tap(KEY_1);await tap(KEY_B);await tap(KEY_2)
	check(game.build_kind=="barracks" and not game.explorer_helpers.placement_active() and not game.forest_ui.guard_shop_open(),"B switches from hiring to building and cancels the mercenary preview")
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
	game.resume();game.start_wave();game.model.waves.spawn_clock=100000
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
