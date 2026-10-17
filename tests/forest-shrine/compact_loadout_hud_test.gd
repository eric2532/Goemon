extends SceneTree
# Real input must select empty loadout slots without stealing building or combat controls.
var game
var checks=0
var failures=0
var selected_events:Array=[]
var config_path="user://compact-loadout-%d.cfg"%OS.get_process_id()
func _initialize():
	create_timer(45).timeout.connect(func():printerr("FAIL: compact HUD timeout");quit(1))
	run.call_deferred()
func check(ok: bool,message: String):
	checks+=1
	if not ok:failures+=1;printerr("FAIL: "+message)
func settle():
	for i in range(3):await process_frame
func run():
	game=load("res://scenes/forest_shrine.tscn").instantiate();game.settings_path=config_path;root.add_child(game);current_scene=game;await settle()
	var ui=game.forest_ui
	var row=ui.find_child("LoadoutSlots",true,false)
	check(row!=null and row.get_child_count()==5,"Portrait has five loadout buttons underneath")
	if row==null:await finish();return
	ui.loadout_slot_selected.connect(func(index):selected_events.append(index))
	check(ui.hero_dock.size.x<=450 and ui.hero_portrait.size.x<=90,"Character strip and portrait occupy less screen space")
	check(row.get_global_rect().position.y>=ui.hero_portrait.get_global_rect().end.y,"Loadout row sits below the portrait")
	check(ui.hero_dock.get_child(0).get_global_rect().end.y<row.get_global_rect().position.y,"Portrait frame also fits above the slots")
	check(absf(row.get_global_rect().get_center().x-ui.hero_portrait.get_global_rect().get_center().x)<2,"Loadout row centers beneath the portrait")
	check(not row.get_global_rect().intersects(ui.bar_paper.get_global_rect()),"Loadout row stays above building controls")
	for i in range(5):
		var button=row.get_child(i)
		check(button is Button and str(i+1) in button.text,"Slot %d exposes its number"%(i+1))
		check(button.focus_mode==Control.FOCUS_NONE,"Slot %d cannot capture movement or jump keys"%(i+1))
	await click(row.get_child(2))
	check(ui.selected_loadout_slot==2 and row.get_child(2).button_pressed,"Mouse selects a slot during preparation")
	var prior=selected_events.size()
	await key(KEY_2)
	check(game.build_kind=="tower" and ui.selected_loadout_slot==2 and selected_events.size()==prior,"Preparation number keys keep their building shortcuts")
	var workers=game.model.workers.size();await key(KEY_5)
	check(game.model.workers.size()==workers+1 and ui.selected_loadout_slot==2,"Preparation 5 recruits without selecting a loadout")
	game.build_kind="";game.world.preview.hide();game.start_wave();game.model.waves.spawn_clock=10000;await settle()
	game.player.select_character(1);game.player.quick_attacks.cancel()
	for i in range(5):
		await key(KEY_1+i)
		check(ui.selected_loadout_slot==i and row.get_child(i).button_pressed,"Combat key %d selects its slot"%(i+1))
		check(row.get_children().filter(func(button):return button.button_pressed).size()==1,"Only the selected loadout is highlighted")
		if i==1:
			check(game.player.quick_attacks.coins_enabled,"Empty slots preserve the fighter's existing combat number actions")
			game.player.quick_attacks.stop_coins()
	check(selected_events.slice(-5)==[0,1,2,3,4],"Future loadout actions receive the selected index once per press")
	prior=selected_events.size()
	var repeat=number(KEY_2);repeat.echo=true;root.push_input(repeat,true)
	var released=number(KEY_2);released.pressed=false;root.push_input(released,true)
	var modified=number(KEY_2);modified.ctrl_pressed=true;root.push_input(modified,true);await settle()
	check(selected_events.size()==prior,"Key repeat, release and modified shortcuts do not reselect slots")
	check(row.get_child(1).mouse_filter==Control.MOUSE_FILTER_IGNORE,"Combat slots leave pointer input available for aiming")
	if DisplayServer.get_name()!="headless":check(Input.mouse_mode==Input.MOUSE_MODE_CAPTURED,"Combat keeps its captured aiming pointer")
	await key(KEY_2);check(ui.selected_loadout_slot==1,"Combat selection remains responsive after repeated input")
	game.player.quick_attacks.stop_coins()
	game.show_pause();await key(KEY_4);check(ui.selected_loadout_slot==1,"Pause menu ignores loadout keys")
	game.resume();game.show_rogue_roster();await key(KEY_4);check(ui.selected_loadout_slot==1,"Character chooser ignores loadout keys")
	game.choose_rogue_character(7);await settle()
	check(row.is_visible_in_tree() and ui.hero_name.text=="Knight","Loadout row remains available after switching fighters")
	game.show_settings(true);await key(KEY_4);check(ui.selected_loadout_slot==1,"Settings ignore loadout keys")
	game.resume();await settle()
	check(row.get_global_rect().end.y<=root.get_visible_rect().end.y-12,"Combat hotbar fits within the viewport")
	if "--visual" in OS.get_cmdline_user_args():
		await shot("combat")
		game.model.phase="preparing";game.set_phase_view();ui.sync();await settle();await shot("building")
	await finish()
func number(code: int)->InputEventKey:
	var e=InputEventKey.new();e.physical_keycode=code;e.pressed=true;return e
func key(code: int):
	root.push_input(number(code),true);await process_frame
	var e=number(code);e.pressed=false;root.push_input(e,true);await process_frame
func click(button: Button):
	var e=InputEventMouseButton.new();e.position=button.get_global_rect().get_center();e.button_index=MOUSE_BUTTON_LEFT;e.pressed=true;root.push_input(e,true);await process_frame
	e=e.duplicate();e.pressed=false;root.push_input(e,true);await process_frame
func shot(label: String):
	await RenderingServer.frame_post_draw
	var folder=OS.get_environment("SONIC_HUD_CAPTURE_DIR")
	if folder.is_empty():folder="/tmp"
	root.get_texture().get_image().save_png(folder+"/compact-hud-"+label+".png")
func finish():
	game.sound_library.cancel();game.music.stop()
	for voice in game.voices:voice.stop()
	game.queue_free();paused=false;await settle();await create_timer(.35).timeout
	DirAccess.remove_absolute(ProjectSettings.globalize_path(config_path))
	print("COMPACT_LOADOUT_HUD_RESULT checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)
