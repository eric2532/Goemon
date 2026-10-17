extends "res://tests/forest-shrine/explorer_close_assist_test.gd"
## Removing steering fails the melee roster; removing release gates fails
## manual escape. All actors, contacts, movement and attack damage are real.
func prepare(id: int):
	if id>=3:await fresh(id)
	else:
		await fresh(7);game.player.select_character(id);game.player.position=ORIGIN
	game.player.smoke_mode=true;game.player.smoke_move=Vector2.ZERO
	game.player.dodge_time=0;game.player.jump_buffer=0;game.player.jump_windup=0
	game.camera_rig.pitch=ActionCamera.CROSSHAIR_DEFAULT_PITCH
	if id>=3:
		var c=game.player.active_ability
		for i in range(20):c._move_body(1.0/60)
		c.player.pos=game.player.position;c.aim=game.player.position+Vector3.FORWARD*30
	else:
		for i in range(20):game.player._physics_process(1.0/60)
func begin(id: int):
	if id==1:game.player.start_attack(false,1)
	else:game.player.active_ability.attack()
func angle(id: int)->float:
	return atan2(game.player.facing.x,game.player.facing.z) if id==1 else float(game.player.active_ability.player.attack.angle)
func step(id: int,count: int=1):
	for i in count:
		if id==1:game.player._physics_process(.01)
		else:game.player.active_ability.tick(.01,false)
func run():
	game=load("res://scenes/forest_shrine.tscn").instantiate();root.add_child(game);current_scene=game
	await frames(3);game.start_wave();game.model.waves.spawn_clock=10000;game.model.waves.pending=0
	game.set_physics_process(false);game.player.set_physics_process(false);game.camera_rig.set_process(false)
	game.tuning.invincible=true;game.tuning.critical_chance=0.0
	for id in [1,3,4,5,7,8,9,11,12]:
		for side in [-1.0,1.0]:
			await prepare(id);target(Vector3(side*1.25,0,-2.6))
			var yaw: float=game.camera_rig.yaw;var pitch: float=game.camera_rig.pitch
			begin(id);var initial=angle(id);step(id,4)
			var turn=wrapf(angle(id)-initial,-PI,PI)
			check(turn*side<-.015 and absf(turn)<.46,"Melee %d gently turns toward the nearby enemy (%s)"%[id,side])
			check(game.camera_rig.yaw==yaw and game.camera_rig.pitch==pitch,"Melee assistance leaves the camera under manual control (%d)"%id)
	check(game.player.get("melee_assist")!=null,"Shared melee assistance is available to the whole roster")
	if game.player.get("melee_assist")==null:
		game.queue_free();await frames(3);print("FOREST_HIDDEN_MELEE_RESULT checks=%d failures=%d"%[checks,failures]);quit(1);return
	for mode in ["aim","pitch","retreat","dodge","dead","fog","cover","far","behind"]:
		await prepare(7);var e=target(Vector3(1.25,0,-2.6));begin(7);step(7)
		check(game.player.melee_assist.target()!=null,"Fixture acquires a nearby enemy before release: "+mode)
		var wall: StaticBody3D
		match mode:
			"aim":game.camera_rig.yaw=.8
			"pitch":game.camera_rig.pitch+=.5
			"retreat":game.player.smoke_move=Vector2(0,1)
			"dodge":game.player.active_ability.standard_evade()
			"dead":game.actors[e.id].dead=true;e.hp=0
			"fog":game.model.visible_cells.clear()
			"cover":
				wall=StaticBody3D.new();wall.collision_layer=1;wall.collision_mask=0
				var shape=CollisionShape3D.new();var box=BoxShape3D.new();box.size=Vector3(8,6,.2);shape.shape=box;wall.add_child(shape);game.add_child(wall);wall.position=ORIGIN+Vector3(0,1,-1.3);await frames()
			"far":game.actors[e.id].position=ORIGIN+Vector3(0,0,-20);e.pos=game.actors[e.id].position;game.actors[e.id]._sync_fitted_pose()
			"behind":game.actors[e.id].position=ORIGIN+Vector3(0,0,3);e.pos=game.actors[e.id].position;game.actors[e.id]._sync_fitted_pose()
		if mode in ["aim","pitch","retreat","dodge"]:game.player._physics_process(.01)
		else:step(7)
		check(game.player.melee_assist.target()==null,"Hidden lock releases immediately for "+mode)
		if mode=="aim":check(absf(wrapf(angle(7)-(PI+.8),-PI,PI))<.05,"Turning the camera away controls the remaining windup immediately")
		if is_instance_valid(wall):wall.queue_free();await frames()
	await prepare(7);var original=target(Vector3(.9,0,-2.6));begin(7);step(7,4)
	game.player.active_ability.tick(.6,false)
	target(Vector3(-.2,0,-2.1));game.player.active_ability.attack();step(7)
	check(game.player.melee_assist.target()==game.actors[original.id],"A short combo retains its original valid enemy despite a closer newcomer")
	game.player.active_ability.tick(.6,false)
	for i in 120:game.player.melee_assist.tick(game.player,.01)
	check(game.player.melee_assist.target()==null,"Combo memory expires without another melee swing")
	await prepare(7);var removed=target(Vector3(.9,0,-2.6));begin(7)
	game.actors[removed.id].queue_free();game.model.enemies.erase(removed.id);await frames();step(7)
	check(game.player.melee_assist.target()==null,"A freed enemy releases the weak target safely")
	for id in [6,10]:
		await prepare(id);target(Vector3(.9,0,-2.6));begin(id)
		check(game.player.melee_assist.target()==null,"Ranged kit %d never acquires melee assistance"%id)
	await prepare(7);target(Vector3(.9,0,-2.6));game.player.set_auto_attack(true);begin(7)
	check(game.player.melee_assist.target()==null and game.player.auto_aim_target()!=null,"Existing automatic attack targeting keeps its own aim without a second steering controller")
	# The step closes only a small gap, always through native collision.
	for blocked in [false,true]:
		await prepare(7);var c=game.player.active_ability;c.attack();var reach: float=c.player.attack.reach
		c.player.attack=null;c.player.cooldowns.cutlass=0
		var e=target(Vector3(0,0,-reach-1.0));var actor=game.actors[e.id]
		for i in 5:
			var surface: Vector3=actor.combat_contact_point(game.player.position+Vector3.UP)
			actor.position.z+=game.player.position.z-(reach+.22)-surface.z;e.pos=actor.position;actor._sync_fitted_pose()
		var wall: StaticBody3D
		if blocked:
			wall=StaticBody3D.new();wall.collision_layer=1;wall.collision_mask=0
			var shape=CollisionShape3D.new();var box=BoxShape3D.new();box.size=Vector3(8,.25,.1);shape.shape=box;wall.add_child(shape);game.add_child(wall);wall.position=game.player.position+Vector3(0,.4,-.6);await frames()
		var start: Vector3=game.player.position;c.attack()
		for i in 22:c.physics_step(.01)
		var distance: float=start.distance_to(game.player.position)
		check(distance<.65,"Assisted step remains small (blocked=%s)"%blocked)
		if not blocked:check(distance>.10 and e.hp<10000,"The small grounded step connects a target just outside static reach")
		else:check(game.player.position.z>start.z-.5,"Assisted movement cannot cross a low solid obstacle")
		if is_instance_valid(wall):wall.queue_free();await frames()
	await prepare(1)
	var pipe_reach: float=game.player.melee_strike_reach()
	var pipe_enemy=target(Vector3(0,0,-pipe_reach-1.0));var pipe_actor=game.actors[pipe_enemy.id]
	for i in 5:
		var surface: Vector3=pipe_actor.combat_contact_point(game.player.position+Vector3.UP)
		pipe_actor.position.z+=game.player.position.z-(pipe_reach+.22)-surface.z;pipe_enemy.pos=pipe_actor.position;pipe_actor._sync_fitted_pose()
	var pipe_start: Vector3=game.player.position;game.player.start_attack(true)
	for i in 25:game.player._physics_process(.01)
	check(game.player.position.distance_to(pipe_start)>.10 and game.player.position.distance_to(pipe_start)<.35,"Goemon's approach remains within one small step without accumulating velocity (%.3fm)"%game.player.position.distance_to(pipe_start))
	if "--visual" in OS.get_cmdline_user_args():
		await prepare(7);target(Vector3(1.25,0,-2.6));begin(7)
		for i in 6:game.player._physics_process(.01)
		game.model.update_vision(game.player.position);game.world.update_fog()
		game.camera_rig.reset_follow();game.camera_rig._process(0)
		await capture_soft("assisted-turn")
		game.camera_rig.yaw=.8;game.player._physics_process(.01)
		game.camera_rig._process(0);await capture_soft("manual-breakaway")
	game.queue_free();paused=false;await frames(3);await create_timer(.35).timeout
	print("FOREST_HIDDEN_MELEE_RESULT checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)
func capture_soft(label: String):
	for i in 3:await process_frame
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("/tmp/sonic-soft-render")
	check(root.get_texture().get_image().save_png("/tmp/sonic-soft-render/"+label+".png")==OK,"Native hidden assistance capture saves: "+label)
