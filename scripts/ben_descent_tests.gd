extends "res://scripts/recovered_leaders_tests.gd"
## Real controller: flight and bomb descent fall faster without snapping to the floor.
func run():
	game=load("res://scenes/forest_title.tscn").instantiate()
	game.settings_path="user://ben-descent-%s.cfg"%OS.get_process_id()
	root.add_child(game);current_scene=game;await frames(5)
	game.begin_forest();game.choose_rogue_character(15);game.start_wave()
	game.tuning.invincible=true;game.tuning.freeze_ai=true;game.character_tuning={}
	await frames(10)
	var p=game.player;p.set_physics_process(false)
	p.position=Vector3(0,.2,22);p.velocity=Vector3.DOWN;p.move_and_slide()
	var floor_y=p.position.y
	for height in [20.0,120.0]:
		p.position.y=floor_y+height;p.velocity=Vector3.UP*8
		p.move_and_slide()
		var before=p.position.y
		Input.action_release("jump");p._physics_process(1.0/60.0)
		check(not p.is_on_floor() and absf(p.velocity.y+12)<.001 and absf(p.position.y-before+.2)<.01,"Releasing Space drops Ben at 12 metres per second from %s metres without snapping"%height)
	p.position.y=floor_y+20;p.velocity=Vector3.ZERO
	Input.action_press("jump");p._physics_process(1.0/60.0)
	check(not p.is_on_floor() and p.velocity.y>0 and p.position.y>floor_y+20,"Holding Space continues normal flight")
	Input.action_release("jump")
	var platform=StaticBody3D.new();platform.position=Vector3(0,floor_y+5,22)
	var shape=CollisionShape3D.new();var box=BoxShape3D.new();box.size=Vector3(8,1,8)
	shape.shape=box;platform.add_child(shape);game.add_child(platform)
	await frames(2)
	p.position.y=floor_y+20;p.velocity=Vector3.UP*5;p._physics_process(1.0/60.0)
	check(not p.is_on_floor() and p.position.y>floor_y+19,"A raised platform does not cause an instant landing")
	for tick in 90:p._physics_process(1.0/60.0)
	check(p.is_on_floor() and absf(p.position.y-(floor_y+5.5))<.1,"Faster descent lands on raised platforms without passing through them")
	p.position.y=floor_y+20;p.velocity=Vector3.ZERO;p.flying=true
	var combat=p.active_ability;combat.start_attack(true);combat._land_bombs()
	p._physics_process(1.0/60.0)
	check(not p.is_on_floor() and absf(p.velocity.y+12)<.001 and absf(p.position.y-(floor_y+19.8))<.01,"Ending bomb hover uses the same faster fall without snapping")
	for tick in 90:p._physics_process(1.0/60.0)
	check(p.is_on_floor() and absf(p.position.y-(floor_y+5.5))<.1,"Bomb descent still collides with raised platforms")
	combat.cancel();p.position.y=floor_y+20;p.velocity=Vector3.ZERO;p.flying=true
	combat.start_attack(true);combat._land_bombs();Input.action_press("jump")
	p._physics_process(1.0/60.0)
	check(not p.is_on_floor() and p.velocity.y>0 and not combat.is_attacking(),"Space overrides automatic landing and keeps Ben airborne")
	Input.action_release("jump");combat.cancel()
	p.position=Vector3(0,floor_y+100,22);p.velocity=Vector3.ZERO
	p.smoke_mode=true;p.smoke_move=Vector2.RIGHT;game.camera_rig.yaw=0
	Input.action_press("jump")
	for tick in 60:p._physics_process(1.0/60.0)
	check(absf(p.velocity.x-21)<.01 and absf(p.velocity.y-15)<.01,"Normal Ben flight reaches triple horizontal and ascent speed")
	Input.action_press("sprint")
	for tick in 60:p._physics_process(1.0/60.0)
	check(absf(p.velocity.x-36)<.01 and absf(p.velocity.y-24)<.01,"Shift flight reaches triple boosted horizontal and ascent speed")
	Input.action_release("jump");Input.action_release("sprint");p.smoke_move=Vector2.ZERO
	p._physics_process(1.0/60.0)
	check(absf(p.velocity.y+12)<.01,"Faster flight preserves the existing descent speed")
	var barrier=StaticBody3D.new();barrier.position=p.position+Vector3.RIGHT*5
	var barrier_shape=CollisionShape3D.new();var barrier_box=BoxShape3D.new();barrier_box.size=Vector3(1,100,20)
	barrier_shape.shape=barrier_box;barrier.add_child(barrier_shape);game.add_child(barrier);await frames(2)
	p.velocity=Vector3.ZERO;p.smoke_move=Vector2.RIGHT;Input.action_press("jump");Input.action_press("sprint")
	for tick in 30:p._physics_process(1.0/60.0)
	check(p.position.x<barrier.position.x-.5,"Boosted Ben flight still stops at solid walls")
	Input.action_release("jump");Input.action_release("sprint");p.smoke_move=Vector2.ZERO;barrier.free()
	platform.free();stop_audio(game);game.move_audio.stop();current_scene=null;game.queue_free();await frames(3);game=null
	await create_timer(.35).timeout
	print("BEN_DESCENT_RESULT checks=",checks," failures=",failures)
	quit(0 if failures==0 else 1)
