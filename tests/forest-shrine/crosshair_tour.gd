extends SceneTree
var game
func _initialize():call_deferred("run")
func frames(n: int=5):
	for i in range(n):await physics_frame
func capture(name_: String):
	await frames();await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://tests/forest-shrine/crosshair-"+name_+".png")
func run():
	game=load("res://scenes/forest_title.tscn").instantiate();root.add_child(game);current_scene=game;await frames()
	await capture("title");game.begin_forest();await capture("roster");game.choose_rogue_character(4)
	game.model.gold=1000
	game.select_build("mine");game.place_cell(Vector2i(-5,1))
	game.select_build("tower");game.place_cell(Vector2i(3,4))
	game.model.build_wall_line([Vector2i(-5,6),Vector2i(-4,6),Vector2i(-3,6),Vector2i(-2,6),Vector2i(-1,6)],0)
	game.model.build("gate",Vector2i(0,6),0);game.world.sync(0)
	game.forest_ui.selected_id=-1;game.forest_ui.message_left=0
	await capture("preparation")
	game.start_wave();game.model.waves.spawn_clock=10000;game.tuning.invincible=true
	game.player.position=Vector3(0,.1,55);game.camera_rig.yaw=0;game.camera_rig.reset_follow()
	for i in range(6):
		game.model.waves.spawn_one();var e=game.model.enemies.values().back();e.pos=Vector3(-7+i*3,0,46-i%2*4);e.stun=100;e.hp=10000;e.max_hp=10000
	game.model.update_vision(game.player.position);game.sync_enemies();game.forest_ui.message_left=0
	await frames(12);await capture("battle")
	var press=InputEventAction.new();press.action="light_attack";press.pressed=true;Input.parse_input_event(press);Input.flush_buffered_events()
	await frames(7);await capture("samurai-attack")
	press.pressed=false;Input.parse_input_event(press);Input.flush_buffered_events()
	game.show_rogue_roster();game.choose_rogue_character(2);await frames(12);await capture("edo")
	game.show_pause();await capture("pause")
	print("FOREST_CROSSHAIR_TOUR_COMPLETE")
	game.quit_clean()
