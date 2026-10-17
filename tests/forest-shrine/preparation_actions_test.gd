extends SceneTree
var game
var checks=0
var failures=0
var config_path="user://preparation-actions-%d.cfg"%OS.get_process_id()
func _initialize():run.call_deferred()
func check(ok: bool,message: String):
	checks+=1
	if not ok:failures+=1;printerr("FAIL: "+message)
func settle():
	for i in range(5):await process_frame
func run():
	game=load("res://scenes/forest_shrine.tscn").instantiate();game.settings_path=config_path;root.add_child(game);current_scene=game;await settle()
	var balance=game.forest_ui.find_child("PreparationBalance",true,false)
	var restart=game.forest_ui.find_child("PreparationRestart",true,false)
	check(balance is Button and restart is Button,"Building map exposes Balance and Instant Restart buttons")
	if balance==null or restart==null:await finish();return
	check(balance.is_visible_in_tree() and restart.is_visible_in_tree(),"Both actions are visible directly on the building map")
	if "--visual" in OS.get_cmdline_user_args():await shot("/tmp/sonic-building-actions.png")
	balance.pressed.emit();await settle()
	var editor=game.menu.find_child("CoreBalance",true,false)
	check(editor!=null and game.settings_open and game.ordinary_pause,"Balance opens the editor directly with preparation suspended")
	if "--visual" in OS.get_cmdline_user_args():await shot("/tmp/sonic-building-balance.png")
	var back=editor.find_child("CoreBalanceBack",true,false)
	check(back.text=="Back to building map","Editor clearly returns to the map")
	editor.find_child("Core_tower_health",true,false).value=900
	back.pressed.emit();await settle()
	check(game.menu==null and game.forest_ui.visible and not game.ordinary_pause and paused,"Back restores building mode without opening Settings or unpausing combat")
	check(game.model.buildings.values().filter(func(b):return b.kind=="tower").all(func(b):return b.max_hp==900),"Map balance edits reach live towers")
	balance.pressed.emit();await settle()
	game.menu.find_child("CoreBalanceReset",true,false).pressed.emit();await settle()
	check(game.menu.find_child("CoreBalanceBack",true,false).text=="Back to building map","Reset retains the direct map return")
	var escape=InputEventKey.new();escape.physical_keycode=KEY_ESCAPE;escape.pressed=true;game._input(escape);await settle()
	check(game.menu==null and not game.settings_open and not game.ordinary_pause,"Escape returns directly to the building map")
	game.show_pause();await settle();check(not balance.is_visible_in_tree() and not restart.is_visible_in_tree(),"Map actions hide behind pause overlay")
	game.resume();game.show_settings(true);await settle()
	check(game.menu.find_child("CoreBalanceButton",true,false)==null,"Core balance no longer appears in Settings")
	game.resume();game.show_rogue_roster();game.choose_rogue_character(7)
	game.model.gold=0;game.model.wave=2
	var old_game=game
	restart.pressed.emit();await settle();game=current_scene;await settle()
	check(not is_instance_valid(old_game) and game!=null,"Instant Restart executes immediately without confirmation")
	check(game.playing and game.model.phase=="preparing" and game.model.wave==0 and game.model.gold==game.core_balance.starting_gold,"Restart opens a fresh building map and restores saved starting gold")
	check(game.player.character_id==7 and not game.rogue_roster_open and game.menu==null,"Restart preserves the chosen fighter and skips intermediate menus")
	game.start_wave();game.model.waves.spawn_clock=10000;await settle()
	check(not game.forest_ui.find_child("PreparationBalance",true,false).is_visible_in_tree() and not game.forest_ui.find_child("PreparationRestart",true,false).is_visible_in_tree(),"Building map actions hide during combat")
	await finish()
func finish():
	game.sound_library.cancel();game.music.stop();game.queue_free();paused=false;await settle()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(config_path))
	print("PREPARATION_ACTIONS_RESULT checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)

func shot(path: String):
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(path)
