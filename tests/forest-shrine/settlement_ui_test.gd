extends SceneTree
var failures=0
var game
func check(ok: bool,message: String):
	if not ok:failures+=1;printerr("FAIL: "+message)
func _initialize():
	create_timer(40).timeout.connect(func():printerr("FAIL: settlement UI timeout");quit(1))
	call_deferred("run")
func run():
	game=load("res://scenes/forest_shrine.tscn").instantiate();root.add_child(game);current_scene=game
	await process_frame;await process_frame
	game.set_process(false)
	for entry in [[KEY_1,"mine"],[KEY_2,"tower"],[KEY_3,"wall"],[KEY_4,"gate"]]:
		await key(entry[0]);check(game.build_kind==entry[1],"Number key selects "+entry[1])
	var before=game.model.workers.size();var gold=game.model.gold
	await key(KEY_5);check(game.model.workers.size()==before+1 and game.model.gold==gold-50,"Key5 recruits exactly one worker")
	var repeat=InputEventKey.new();repeat.physical_keycode=KEY_5;repeat.pressed=true;repeat.echo=true
	game._unhandled_input(repeat);check(game.model.workers.size()==before+1,"Key repeat cannot purchase extra workers")
	await key(KEY_3);game.build_rotation=0;await key(KEY_R)
	game.wall_start=Vector2i(-6,6)
	var cells=game.wall_cells(Vector2i(-6,6))
	check(game.build_rotation==1 and cells==[Vector2i(-6,6)],"Single wall click retains its R rotation")
	cells=game.wall_cells(Vector2i(-6,12))
	check(cells==[Vector2i(-6,6),Vector2i(-6,12)],"Wall drag snaps in complete six-cell sections")
	game.world.show_wall_preview(cells,1,true)
	check(game.world.preview_mesh.mesh.size.z==72 and game.world.preview_mesh.mesh.size.x==6,"Rotated drag preview covers the complete reserved footprint")
	game.build_kind="";game.world.preview.hide();game.wall_start=Vector2i(-999,-999)
	game.forest_ui.sync()
	var dock=game.forest_ui.shrine_health_dock
	check(dock.get_global_rect().end.y<game.forest_ui.bar_paper.get_global_rect().position.y,"Main base health sits above the menu hub")
	check(game.forest_ui.shrine_health_bar.value==3000 and "3000" in game.forest_ui.shrine_health_label.text,"Main base HUD uses the increased health maximum")
	game.show_pause();gold=game.model.gold;await key(KEY_5)
	check(game.model.gold==gold,"Paused hotkeys do not recruit workers")
	game.resume();game.start_wave();game.model.waves.spawn_clock=10000
	game.model.damage_building(1,250);game.forest_ui.sync()
	check(game.forest_ui.shrine_health_bar.value==2750 and game.forest_ui.shrine_health_dock.visible,"Base health updates and stays visible during combat")
	gold=game.model.gold;game._unhandled_input(number(KEY_5))
	check(game.model.gold==gold,"Building hotkeys leave wave combat controls intact")
	await hero_landing()
	if "--visual" in OS.get_cmdline_user_args():await preview()
	game.sound_library.cancel();game.music.stop();game.queue_free();paused=false
	await process_frame;await create_timer(.35).timeout
	print("FOREST_SETTLEMENT_UI_RESULT failures=",failures);quit(1 if failures else 0)
func number(code: int)->InputEventKey:
	var e=InputEventKey.new();e.physical_keycode=code;e.pressed=true;return e
func key(code: int):
	var e=number(code);root.push_input(e,true);Input.flush_buffered_events();await process_frame
	e=number(code);e.pressed=false;root.push_input(e,true);Input.flush_buffered_events();await process_frame
func hero_landing():
	var tower=preload("res://scripts/forest/forest_art.gd").building({"id":999,"kind":"tower","rotation":0})
	game.world.add_child(tower);tower.position=Vector3(0,0,70)
	for id in [1,3]:
		game.player.select_character(id);game.player.position=tower.position+Vector3.UP*11;game.player.velocity=Vector3.ZERO
		for i in range(120):await physics_frame
		check(game.player.is_on_floor() and absf(game.player.position.y-8.95)<.08,"Actual fighter %d lands and remains on the tower deck"%id)
	game.player.select_character(1);game.player.position=Vector3(0,.1,18);game.player.velocity=Vector3.ZERO;tower.queue_free()
func preview():
	game.model.phase="preparing";game.set_phase_view();game.model.gold=1600
	for w in game.model.workers.values():w.pos=Vector3(-18,0,24)
	for x in range(-12,13):
		for y in range(-12,13):game.model.explored[Vector2i(x,y)]=true
	game.model.build("mine",Vector2i(-5,1),0);game.model.build("tower",Vector2i(4,4),0)
	for offset in range(0,18,6):
		game.model.build("wall",Vector2i(-9+offset,-9),0)
		game.model.build("wall",Vector2i(9,-9+offset),1)
		game.model.build("wall",Vector2i(-8+offset,9),0)
		game.model.build("wall",Vector2i(-9,-8+offset),1)
	game.model.build("gate",Vector2i(0,9),0)
	game.world.sync(0);game.forest_ui.message_left=0;game.forest_ui.selected_id=-1
	game.preparation_size=155;game.pan=Vector3.ZERO;game.update_preparation_camera();game.forest_ui.sync()
	await shot("settlement-menu")
	game.start_wave();game.model.waves.spawn_clock=10000;game.player.set_physics_process(false)
	var tower=game.model.buildings.values().filter(func(b):return b.kind=="tower")[0]
	var center=game.model.center(tower);game.player.position=center+Vector3(0,8.96,0)
	game.player.model.animate(0,0,true,0,0,false,0,false)
	game.camera_rig.set_process(false);game.rogue_view.set_process(false)
	game.camera_rig.camera.global_position=center+Vector3(22,21,26);game.camera_rig.camera.look_at(center+Vector3.UP*7)
	game.model.update_vision(center);game.world.sync(0);game.forest_ui.sync()
	await shot("tower-deck")
func shot(name_: String):
	for i in range(4):await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://docs/settlement-update/"+name_+".png")
