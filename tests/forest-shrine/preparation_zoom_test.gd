extends SceneTree
## Exercise real preparation input and projection, including phase/menu boundaries.
var game
var checks=0
var failures=0
var cfg="user://preparation-zoom-%d.cfg"%OS.get_process_id()
func _initialize():
	set_meta("forest_army_backend","legacy")
	create_timer(60).timeout.connect(func():printerr("FAIL: preparation zoom timeout");quit(1))
	run.call_deferred()
func check(ok:bool,label_:String):
	checks+=1
	if not ok:failures+=1;printerr("FAIL: ",label_)
func frames():
	for i in 3:await process_frame
func input(event:InputEvent):
	root.push_input(event,true);Input.flush_buffered_events()
func wheel(at:Vector2,up:bool=true,factor:float=1.0,pressed:bool=true):
	var motion=InputEventMouseMotion.new();motion.position=at;input(motion)
	var event=InputEventMouseButton.new();event.position=at;event.pressed=pressed
	event.button_index=MOUSE_BUTTON_WHEEL_UP if up else MOUSE_BUTTON_WHEEL_DOWN;event.factor=factor
	input(event)
	if pressed:
		event=event.duplicate();event.pressed=false;input(event)
func key(code:int,ctrl:bool=false,echo:bool=false):
	var event=InputEventKey.new();event.physical_keycode=code;event.pressed=true;event.ctrl_pressed=ctrl;event.echo=echo;input(event)
	event=event.duplicate();event.pressed=false;event.echo=false;input(event)
func click(button:Control):
	var motion=InputEventMouseMotion.new();motion.position=button.get_global_rect().get_center();input(motion)
	var event=InputEventMouseButton.new();event.position=button.get_global_rect().get_center();event.button_index=MOUSE_BUTTON_LEFT;event.pressed=true;input(event)
	event=event.duplicate();event.pressed=false;input(event)
	await frames()
func view(size_:float=120.0):
	game.preparation_size=size_;game.pan=Vector3.ZERO;game.update_preparation_camera()
func run():
	root.size=Vector2i(1440,900)
	var doc=load("res://scripts/forest/forest_map_document.gd").new();doc.load_original();set_meta("forest_custom_layout",doc.data)
	game=load("res://scenes/forest_shrine.tscn").instantiate();game.settings_path=cfg;root.add_child(game);current_scene=game
	await frames();AudioServer.set_bus_mute(0,true)
	var screen=root.get_visible_rect().size;var at=screen*Vector2(.61,.43)
	view();game.select_build("tower")
	var point=game.ground_at(at);var count=game.model.buildings.size();var gold=game.model.gold
	wheel(at)
	check(game.preparation_size<120 and is_equal_approx(game.camera_rig.camera.size,game.preparation_size),"Wheel immediately magnifies the preparation camera")
	check(game.camera_rig.camera.unproject_position(point).distance_to(at)<.05,"Wheel keeps the pointed ground location under the cursor")
	check(game.build_kind=="tower" and game.model.buildings.size()==count and game.model.gold==gold,"Zoom preserves selection without placing or spending")
	for i in 30:wheel(at)
	check(game.preparation_size<=25 and game.preparation_size>=10,"Repeated wheel zoom reaches a useful close construction view")
	var closest=game.preparation_size;wheel(at)
	check(is_equal_approx(game.preparation_size,closest),"Further zoom at the close limit remains stable")
	view();wheel(at,true,.25);var fractional=game.preparation_size
	view();wheel(at);var full=game.preparation_size
	check(fractional<120 and fractional>full,"High precision scrolling uses smaller fractional steps")
	wheel(at,false)
	check(absf(game.preparation_size-120)<.001,"Opposite wheel steps restore the same scale")
	wheel(at,true,1,false)
	check(absf(game.preparation_size-120)<.001,"Wheel release does not apply another zoom")
	wheel(at,true,0)
	check(game.preparation_size<120,"Platforms without wheel factor still receive a normal zoom step")
	view();var pinch=InputEventMagnifyGesture.new();pinch.position=at;pinch.factor=1.5;input(pinch)
	check(absf(game.preparation_size-80)<.001,"Trackpad pinch magnifies proportionally")
	pinch=pinch.duplicate();pinch.factor=2.0/3.0;input(pinch)
	check(absf(game.preparation_size-120)<.001,"Reverse pinch restores the view without drift")
	var scroll=InputEventPanGesture.new();scroll.position=at;scroll.delta=Vector2(0,-.5);input(scroll)
	check(game.preparation_size<120 and game.preparation_size>100,"Trackpad scrolling supports fine preparation zoom")
	view();key(KEY_EQUAL);check(game.preparation_size<120,"Plus keyboard shortcut zooms into preparation")
	key(KEY_MINUS);check(absf(game.preparation_size-120)<.001,"Minus keyboard shortcut zooms back out")
	key(KEY_EQUAL,true);key(KEY_EQUAL,false,true)
	check(absf(game.preparation_size-120)<.001,"Modified shortcuts and key echo do not unexpectedly change zoom")
	var text=LineEdit.new();game.forest_ui.add_child(text);text.grab_focus();key(KEY_MINUS)
	check(absf(game.preparation_size-120)<.001,"Typing into a text control does not zoom the map")
	text.queue_free();await frames()
	var panel=game.forest_ui.build_bar;game.forest_ui.open_build_menu();await frames();view()
	wheel(panel.get_global_rect().get_center())
	check(absf(game.preparation_size-120)<.001,"Scrolling over construction controls does not zoom through the UI")
	view();game.ordinary_pause=true;wheel(at);key(KEY_EQUAL);game.ordinary_pause=false
	check(absf(game.preparation_size-120)<.001,"Paused preparation ignores zoom input")
	var public_api=game.has_method("zoom_preparation") and game.has_method("reset_preparation_zoom")
	check(public_api,"Visible zoom controls can use the shared guarded preparation API")
	if public_api:
		view();var centered=game.pan;game.zoom_preparation(1)
		check(game.pan.distance_to(centered)<.001,"Button zoom without a cursor anchors the center of the view")
		game.zoom_preparation(1000);check(game.preparation_size<=25 and game.preparation_size>=10,"Large button requests clamp to the close limit")
		game.zoom_preparation(-1000);check(game.preparation_size==600*game.model.terrain_scale,"Zoom out retains the terrain-scaled overview limit")
		var before=game.preparation_size;game.zoom_preparation(NAN)
		check(game.preparation_size==before,"Nonfinite zoom input cannot corrupt the camera")
		game.pan=Vector3(75,0,60);game.reset_preparation_zoom();var frame=game.preparation_map_frame();frame.pan.y=0
		check(game.pan.is_equal_approx(frame.pan) and game.preparation_size==frame.size,"Overview button restores map context after close placement")
		view();game.map_editor.active=true;before=game.preparation_size
		check(not game.zoom_preparation(1) and game.preparation_size==before,"Build zoom buttons cannot change the active map editor view")
		wheel(at)
		check(game.preparation_size==108,"Map editor retains ownership of its existing wheel zoom")
		game.map_editor.active=false
		for flag in ["settings_open","rogue_roster_open","ordinary_pause","transitioning"]:
			game.set(flag,true);before=game.preparation_size
			check(not game.zoom_preparation(1) and not game.reset_preparation_zoom() and game.preparation_size==before,"Preparation API respects %s"%flag)
			game.set(flag,false)
	var zoom_in=game.forest_ui.find_child("PreparationZoomIn",true,false)
	var zoom_out=game.forest_ui.find_child("PreparationZoomOut",true,false)
	var zoom_reset=game.forest_ui.find_child("PreparationZoomReset",true,false)
	check(zoom_in is Button and zoom_out is Button and zoom_reset is Button,"Preparation exposes discoverable zoom in, zoom out, and map buttons")
	if zoom_in!=null and zoom_out!=null and zoom_reset!=null:
		view();await frames();count=game.model.buildings.size();gold=game.model.gold
		await click(zoom_in);check(game.preparation_size<120,"Clicking the plus button magnifies the map")
		await click(zoom_out);check(absf(game.preparation_size-120)<.001,"Clicking the minus button restores the scale")
		check(game.model.buildings.size()==count and game.model.gold==gold,"Zoom buttons consume clicks without placing the selected building")
		if public_api:game.zoom_preparation(100)
		await frames();check(zoom_in.disabled and not zoom_out.disabled,"Close limit disables only further zoom in")
		await click(zoom_reset)
		check(game.preparation_size==120 and not zoom_in.disabled,"Map button restores context and enables close zoom again")
		for dimensions in [Vector2i(960,600),Vector2i(1280,800)]:
			root.size=dimensions;await frames()
			check(root.get_visible_rect().encloses(zoom_in.get_global_rect()) and root.get_visible_rect().encloses(zoom_out.get_global_rect()),"Zoom buttons remain reachable at %s"%dimensions)
		game.map_editor.active=true;game.forest_ui.sync()
		check(not zoom_in.is_visible_in_tree(),"Preparation zoom controls hide while editing a map")
		game.map_editor.active=false;game.forest_ui.sync()
	view(30);game.pan=Vector3(210,0,210);game.update_preparation_camera();game.zoom_preparation(1)
	check(game.pan.distance_to(Vector3(210,0,210))<.001,"Original-map clear outer ground can be centered during close construction")
	# Use a real native-map model to check its wider camera domain. The current
	# world remains a flat projection fixture; no terrain collision is required.
	var original_model=game.model
	var native_doc=load("res://scripts/forest/forest_map_document.gd").new();native_doc.load_blood_gulch()
	var native_model=load("res://scripts/forest/forest_model.gd").new();native_model.reset(42,{},native_doc.data,false)
	game.model=native_model;view(30);game.pan=Vector3(210,0,210);game.update_preparation_camera()
	if public_api:game.zoom_preparation(1)
	check(game.pan.distance_to(Vector3(210,0,210))<.001,"Native map edge sites remain centered during close zoom")
	var drag=InputEventMouseMotion.new();drag.position=at;drag.button_mask=MOUSE_BUTTON_MASK_MIDDLE;drag.relative=Vector2(-5000,-5000);input(drag)
	var domain=native_model.world_bounds()
	check(domain.has_point(Vector2(game.pan.x,game.pan.z)) and game.pan.x>210 and game.pan.z>210,"Middle drag reaches outer native construction sites and clamps inside the map")
	game.model=original_model;view()
	game.start_wave();game.model.waves.spawn_clock=100000;game.player.set_physics_process(false)
	var prep_size=game.preparation_size;var distance=game.camera_rig.distance;wheel(at)
	check(game.preparation_size==prep_size and game.camera_rig.camera.projection==Camera3D.PROJECTION_PERSPECTIVE,"Combat wheel input never switches back to the build camera")
	check(game.camera_rig.distance<distance,"Combat keeps its existing wheel zoom")
	if zoom_in!=null:check(not zoom_in.is_visible_in_tree(),"Preparation zoom buttons hide during combat")
	if public_api:check(not game.zoom_preparation(1) and not game.reset_preparation_zoom(),"Preparation buttons cannot modify the combat camera")
	await finish()
func finish():
	game.sound_library.cancel();game.music.stop();game.queue_free();paused=false
	await frames();await create_timer(.25).timeout
	if FileAccess.file_exists(cfg):DirAccess.remove_absolute(ProjectSettings.globalize_path(cfg))
	print("PREPARATION_ZOOM_RESULT checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)
