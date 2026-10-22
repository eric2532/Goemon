extends SceneTree
# Only assigned weapons use numeric slots; paid guard placement is separate.
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
	game.player.select_character(14);game.forest_ui.sync()
	var ui=game.forest_ui
	var row=ui.find_child("LoadoutSlots",true,false)
	check(row!=null and row.get_child_count()==5,"Portrait retains five numbered loadout slots")
	if row==null:await finish();return
	ui.loadout_slot_selected.connect(func(index):selected_events.append(index))
	check(ui.hero_dock.size.x<=450 and ui.hero_portrait.size.x<=90,"Character strip remains compact")
	check(row.get_global_rect().position.y>=ui.hero_portrait.get_global_rect().end.y,"Loadout stays below the portrait")
	check(not row.get_global_rect().intersects(ui.bar_paper.get_global_rect()),"Loadout stays above building controls")
	for i in 5:
		var button=row.get_child(i)
		check(button is Button and str(i+1) in button.text and button.disabled,"Unused slot %d is visibly empty and inactive"%(i+1))
		check(not ui.helper_portraits[i].visible,"Unused slot %d has no ally portrait"%(i+1))
		await key(KEY_1+i)
	check(selected_events.is_empty() and game.explorer_helpers.active_units().is_empty(),"Bare preparation number keys cannot summon allies")
	await click(row.get_child(2))
	check(ui.selected_loadout_slot==-1 and selected_events.is_empty(),"Clicking an empty slot performs no action")
	await key(KEY_2,true)
	check(game.build_kind=="tower" and selected_events.is_empty(),"Shift+2 still selects tower construction")
	var housing={}
	for z in range(10,24):
		for x in range(-22,23):
			if game.model.placement_error("barracks",Vector2i(x,z),0).is_empty():housing=game.model.build("barracks",Vector2i(x,z),0);break
		if not housing.is_empty():break
	check(not housing.is_empty(),"Worker recruitment shortcut has barracks capacity available")
	var workers=game.model.workers.size();await key(KEY_5,true)
	check(game.model.workers.size()==workers+1,"Shift+5 still recruits a worker")
	game.build_kind="";game.world.preview.hide();game.start_wave();game.model.waves.spawn_clock=10000;await settle()
	for i in 5:await key(KEY_1+i)
	check(game.explorer_helpers.active_units().is_empty() and selected_events.is_empty(),"Battle number keys cannot create unpaid allies")
	check(ui.loadout_buttons.all(func(button):return button.disabled and not button.button_pressed),"Unassigned battle slots stay blank")
	check(not ui.guard_shop_button.visible,"Guards can only be hired during preparation")
	game.player.select_character(18);await settle()
	for i in 5:
		await key(KEY_1+i)
		check(game.player.master_chief_combat.weapon_slot==i+1,"Chief key %d still selects its real weapon"%(i+1))
	check(selected_events.is_empty(),"Real weapon keys never emit summon requests")
	game.show_pause();await key(KEY_2)
	check(game.player.master_chief_combat.weapon_slot==5,"Pause prevents weapon switching")
	game.resume();game.show_rogue_roster();await key(KEY_2)
	check(game.player.master_chief_combat.weapon_slot==5,"Character gallery prevents weapon switching")
	game.choose_rogue_character(7);await settle()
	check(ui.hero_name.text=="Knight" and ui.helper_portraits.all(func(icon):return not icon.visible),"Switching to Knight keeps unused slots blank")
	game.show_settings(true);await key(KEY_4)
	check(selected_events.is_empty(),"Settings cannot create allies")
	game.resume();await settle()
	check(row.get_global_rect().end.y<=root.get_visible_rect().end.y-12,"The compact hotbar remains inside the viewport")
	await finish()
func number(code: int)->InputEventKey:
	var e=InputEventKey.new();e.physical_keycode=code;e.pressed=true;return e
func key(code: int,shift_: bool=false):
	var e=number(code);e.shift_pressed=shift_;root.push_input(e,true);await process_frame
	e=number(code);e.shift_pressed=shift_;e.pressed=false;root.push_input(e,true);await process_frame
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
