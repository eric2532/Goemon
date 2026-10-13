extends SceneTree
var failures=0
func check(ok: bool,message: String):
	if not ok:failures+=1;printerr("FAIL: "+message)
func _initialize():call_deferred("run")
func run():
	change_scene_to_file("res://scenes/forest_shrine.tscn");await process_frame;await process_frame
	var game=current_scene;game.player.select_character(1);game.start_wave();game.model.waves.spawn_clock=10000;game.model.waves.spawn_one()
	var e=game.model.enemies.values()[0];e.pos=Vector3(150,0,60);e.hp=10000;e.max_hp=10000;e.stun=100
	game.sync_enemies();await physics_frame;await physics_frame
	var actor=game.actors[e.id];var strike=game.player.sky_strike
	game.model.update_vision(game.player.position)
	check(not game.forest_enemy_visible(actor),"Distant Sky Strike fixture is outside shared vision")
	check(strike.choose_target()==null,"Goemon T cannot lock onto an unseen forest raider")
	game.player.position=Vector3(0,.1,70);e.pos=Vector3(0,0,66)
	await physics_frame;await physics_frame;game.model.update_vision(game.player.position)
	check(strike.choose_target()==actor,"Goemon T still selects a visible forest raider")
	strike.landing=actor.position;strike.attack_ticket=game.player.attack_chain.begin("sky_strike")
	game.model.visible_cells.clear();var hp=e.hp;strike.impact()
	check(e.hp==hp,"Sky Strike rechecks current visibility at impact")
	game.model.update_vision(game.player.position);strike.impact()
	check(e.hp<hp,"Visible Sky Strike impact retains its native damage")
	game.queue_free();paused=false;await process_frame;await create_timer(.35).timeout
	print("FOREST_FOG_TARGET_RESULT failures=%d"%failures);quit(1 if failures else 0)
