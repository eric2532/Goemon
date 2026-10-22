extends "res://scripts/combat_tests.gd"
var visual=false
func frames(n: int):
	for i in range(n):await get_tree().physics_frame
func capture(label: String):
	if not visual:return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://tests/map-shuffle/"+label+".png")
func layout_valid()->bool:
	var sky=game.world.sky_islands
	var ok=sky.islands.size()==784 and sky.bridges.is_empty()
	for layer in range(sky.LAYERS):
		for a in range(sky.PER_LAYER):
			var point=sky.islands[layer*sky.PER_LAYER+a]
			ok=ok and game.world.playable_bounds.grow(-sky.radii[layer*sky.PER_LAYER+a]-2).has_point(Vector2(point.x,point.z))
			for b in range(a+1,sky.PER_LAYER):
				ok=ok and point.distance_to(sky.islands[layer*sky.PER_LAYER+b])>20
	return ok
func old_refresh_event()->InputEventKey:
	var event=InputEventKey.new();event.physical_keycode=KEY_F5
	return event
func run():
	visual="--map-shuffle-visual" in OS.get_cmdline_user_args()
	if visual:DirAccess.make_dir_recursive_absolute("res://tests/map-shuffle")
	Input.use_accumulated_input=false
	game.tuning=PrototypeTuning.DEFAULTS.duplicate();game.tuning.invincible=true
	game.start_game();game.player.smoke_mode=true
	game.camera_rig.set_process_unhandled_input(false);get_window().set_flag(Window.FLAG_NO_FOCUS,true);Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	await frames(20)
	check(layout_valid(),"Seeded sky keeps 784 separated islands inside the map and open jump gaps")
	var enemy=game.enemies[0];var distance=enemy.position.distance_to(game.player.position)
	await frames(40)
	check(enemy.alerted and enemy.position.distance_to(game.player.position)<distance-1,"Starting island enemy pursues immediately without needing to be hit")
	game.player.set_physics_process(false);game.player.position+=Vector3.UP*10
	await frames(3)
	check(enemy.state!="patrol" and enemy.alerted,"Jumping ten metres above an island retains enemy pursuit")
	game.player.position-=Vector3.UP*10;game.player.set_physics_process(true)
	game.tuning.freeze_ai=true
	await capture("01-first-layout")
	var first_seed=game.run_seed
	var islands=game.world.sky_islands.islands.duplicate();var districts=game.world.furnished_districts.duplicate()
	var buildings=TidefallTown.layout(game.world);var courts=game.world.outposts.duplicate()
	var chain=game.player.attack_chain;chain.confirm(chain.begin("pipe"))
	game.player.progression.award_kills(5)
	game.show_pause()
	await capture("04-shuffle-menu")
	var echo=InputEventKey.new();echo.physical_keycode=KEY_Y;echo.pressed=true;echo.echo=true
	Input.parse_input_event(echo);Input.flush_buffered_events()
	check(not game.transitioning and game.run_seed==first_seed,"Holding Y does not repeatedly rebuild the map")
	check(InputMap.action_has_event("shuffle_map",echo) and not InputMap.action_has_event("shuffle_map",old_refresh_event()),"Y is assigned to map refresh and F5 is unassigned")
	await key(KEY_Y);await frames(25);Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	check(game.run_seed!=first_seed and not game.paused and game.playing,"One Y press shuffles from pause and starts the new run")
	check(game.world.sky_islands.islands!=islands and game.world.furnished_districts!=districts and game.world.outposts!=courts and TidefallTown.layout(game.world)!=buildings,"Shuffle changes island, building, furnished district and outpost locations")
	check(chain.count==0 and game.player.progression.level==1 and game.encounters.defeated.is_empty(),"Shuffle resets combo, progression and old encounter state")
	check(game.player.is_on_floor() and game.world.sky_islands.island_at(game.player.position)==0 and layout_valid(),"New run starts safely on its new highest island")
	await capture("02-shuffled-layout")
	var seed=game.run_seed;islands=game.world.sky_islands.islands.duplicate();buildings=TidefallTown.layout(game.world)
	game.restart_area();await frames(25);Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	check(seed==game.run_seed and islands==game.world.sky_islands.islands and buildings==TidefallTown.layout(game.world),"Restart replays exactly the same map seed")
	var valid=true;var minimum=1000
	for sample in range(20):
		var world=Sanctuary.new();world.generation_seed=sample*104729+37
		WorldExpansion.plan(world);FurnishedTown.plan(world)
		var lots=TidefallTown.layout(world);minimum=mini(minimum,lots.size())
		var existing=lots.slice(0,3)
		for lot in lots.slice(3):
			valid=valid and TidefallTown.safe_lot(lot[0],existing,world);existing.append(lot)
		for lot in world.furnished_lots:valid=valid and world.playable_bounds.encloses(lot.rect.grow(6))
		world.free()
	check(valid and minimum==TidefallTown.TARGET_COUNT,"Twenty different seeds preserve town clearances, bounds and all 48 town buildings (minimum %d)" % minimum)
	game.reset_player_at(game.world.sky_islands.ground_point+Vector3.UP*.2)
	var bounded=true
	for i in range(180):
		var count=game.encounters.total_spawned
		await frames(1)
		bounded=bounded and game.encounters.total_spawned-count<=4
	check(bounded,"Ground arrivals create at most four actors per frame")
	var run=game.encounters
	check(run.completed and run.ground_remaining()==50 and run.ground_raiders().size()==24,"Landing populates all 50 giants plus 24 nearby regular enemies")
	var safe=true
	for raider in run.ground_raiders():
		var floor_hit=game.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(raider.position+Vector3.UP*.25,raider.position-Vector3.UP,1))
		safe=safe and raider.position.distance_to(game.player.position)>=20 and not floor_hit.is_empty() and absf(raider.position.y-floor_hit.position.y)<.25
	check(safe,"Ground raiders spawn away from the player on real collision floors")
	await capture("03-ground-raiders")
	enemy=run.ground_raiders()[0];distance=enemy.position.distance_to(game.player.position)
	game.tuning.freeze_ai=false;await frames(45);game.tuning.freeze_ai=true
	check(enemy.position.distance_to(game.player.position)<distance-1,"Ground raiders actively approach the player")
	var raiders=run.ground_raiders()
	for e in raiders.slice(0,6):e.take_hit(100000,Vector3.UP,true)
	await frames(60)
	run.ground_refill_clock=0;await frames(45)
	check(run.ground_raiders().size()==24,"Ground reinforcements replenish the bounded nearby group")
	var before=run.total_spawned;var clock=run.ground_refill_clock
	game.show_pause();run.tick(20);await frames(4)
	check(before==run.total_spawned and clock==run.ground_refill_clock,"Pause freezes ground spawning and reinforcement timers")
	game.resume()
	for e in run.ground_raiders():game.enemies.erase(e);e.queue_free()
	await frames(2)
	game.active_enemy_limit=game.active_enemy_count()+2;run.ground_refill_clock=0
	var initial=game.active_enemy_count();await frames(60)
	check(game.active_enemy_count()==initial+2,"Ground additions obey the global enemy limit without deleting giants")
	game.active_enemy_limit=200
	for e in game.enemies:
		if is_instance_valid(e) and e.ground_giant and not e.dead:e.take_hit(1000000,Vector3.UP,true)
	await frames(90)
	enemy=run.ground_raiders()[0];enemy.position+=Vector3.RIGHT*150
	run.ground_refill_clock=0;run.tick(.016)
	check(not enemy.is_queued_for_deletion() and not run.ground_cleared,"After the giants fall, distant surviving raiders cannot despawn into a false victory")
	for e in run.ground_raiders():e.take_hit(1000000,Vector3.UP,true)
	await frames(60)
	check(run.ground_cleared and run.ground_raiders().is_empty() and run.ground_raiders_pending==0,"Defeating the final ground raiders liberates the map and stops reinforcements")
	chain.reset()
	for i in range(3):chain.confirm(chain.begin("pipe"))
	check(is_equal_approx(chain.multiplier(),1.1),"Three successful links now grant only ten percent extra speed")
	for i in range(30):chain.confirm(chain.begin("pipe"))
	check(chain.multiplier()==1.5,"Long combos cap at one and a half times base speed")
	print("MAP_SHUFFLE_RESULT failures=",failures)
	get_tree().quit(1 if failures else 0)
