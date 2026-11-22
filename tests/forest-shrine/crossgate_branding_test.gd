extends SceneTree
var game
var checks=0
var failures=0
var cfg="user://crossgate-branding-%d.cfg"%OS.get_process_id()
const OUTPUT="res://build/Other Files/Asset Toolkit/Cross Gate Branding"
func _initialize():
	create_timer(90).timeout.connect(func():printerr("Branding check timed out");quit(1))
	run.call_deferred()
func check(ok:bool,message:String):
	checks+=1
	if not ok:failures+=1;printerr("FAIL: "+message)
func settle():
	for i in 6:await process_frame
func shot(name_:String):
	if DisplayServer.get_name()=="headless":return
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(OUTPUT.path_join(name_+".png"))==OK,"Save rendered menu")
func escape():
	var event=InputEventKey.new();event.physical_keycode=KEY_ESCAPE;event.pressed=true
	Input.parse_input_event(event);await settle()
	event=InputEventKey.new();event.physical_keycode=KEY_ESCAPE;event.pressed=false
	Input.parse_input_event(event);await settle()
func run():
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	set_meta("forest_painterly_preview",true)
	game=load("res://scenes/forest_title.tscn").instantiate();game.settings_path=cfg;root.add_child(game);current_scene=game
	await settle();AudioServer.set_bus_mute(0,true)
	check(ProjectSettings.get_setting("application/config/name")=="Cross Gate" and root.title=="Cross Gate","Project and window use Cross Gate")
	check(OS.get_user_data_dir().ends_with("Godot/app_userdata/Azure Ember"),"Existing save directory is preserved")
	for dimensions in [Vector2i(1280,800),Vector2i(960,600)]:
		root.size=dimensions;game.show_title();await settle()
		var heading=game.find_child("GoemonTitleHeading",true,false)
		check(heading.text=="Cross Gate" and root.get_visible_rect().encloses(heading.get_global_rect()),"Title fits "+str(dimensions))
		await shot("title-%d"%dimensions.x)
	game.begin_arena();await settle();game.choose_rogue_character(game.player.RogueRoster.KAZI_ID);await settle()
	game.enter_equipped_map();await settle()
	for dimensions in [Vector2i(1280,800),Vector2i(960,600)]:
		root.size=dimensions;await settle();await escape()
		var overlay=game.forest_ui.overlay
		check(game.ordinary_pause and paused and is_instance_valid(overlay),"ESC pauses gameplay")
		check(overlay.find_children("*","Label",true,false).size()==1,"Pause contains a heading and no instructions")
		check(overlay.find_children("*","Button",true,false).size()==4,"Pause retains Resume, Settings, Restart and Main menu")
		check(root.get_visible_rect().encloses(overlay.get_global_rect()),"Pause fits "+str(dimensions))
		await shot("pause-%d"%dimensions.x)
		await escape();check(not paused and not game.ordinary_pause and not is_instance_valid(game.forest_ui.overlay),"ESC resumes gameplay")
	game.sound_library.cancel();game.music.stop();game.queue_free();current_scene=null;paused=false;await settle()
	if FileAccess.file_exists(cfg):DirAccess.remove_absolute(ProjectSettings.globalize_path(cfg))
	print("CROSSGATE_BRANDING_RESULT checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)
