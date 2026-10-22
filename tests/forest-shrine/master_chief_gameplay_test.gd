extends SceneTree
## Exercises the shipped forest scene: camera isolation, real enemy hit volumes,
## world occlusion, continuous fire, and interruption across menus/characters.
var checks=0
var failures=0
var game
func _initialize():
	create_timer(150).timeout.connect(func():printerr("FAIL: Master Chief gameplay timeout");quit(1))
	run.call_deferred()
func check(ok: bool,message: String):
	checks+=1
	if not ok:failures+=1;printerr("FAIL: "+message)
func frames(count: int=3):
	for i in range(count):await physics_frame
func press(action: String,down: bool=true):
	var event=InputEventAction.new();event.action=action;event.pressed=down
	Input.parse_input_event(event);Input.flush_buffered_events()
func run():
	game=load("res://scenes/forest_shrine.tscn").instantiate();root.add_child(game);current_scene=game
	await frames()
	var hero=game.player
	hero.select_character(18)
	check(hero.character_id==18,"Master Chief can be selected as a native playable hero")
	if hero.character_id!=18:await finish();return
	game.start_wave();game.model.waves.spawn_clock=10000;game.tuning.invincible=true
	# Isolate controls from terrain elevation and autonomous tower attacks while
	# retaining the actual scene, Hero, camera, enemy volumes and damage path.
	game.set_physics_process(false)
	var platform=StaticBody3D.new();platform.collision_layer=1
	var platform_shape=CollisionShape3D.new();platform_shape.shape=BoxShape3D.new()
	platform_shape.shape.size=Vector3(40,1,40);platform.add_child(platform_shape)
	game.add_child(platform);platform.position=Vector3(0,99.5,110)
	hero.position=Vector3(0,100.1,110);hero.velocity=Vector3.ZERO
	game.camera_rig.yaw=0;game.camera_rig.pitch=0
	await frames(8)
	var camera=game.camera_rig.camera
	var combat=hero.active_ability
	combat.select_slot(2)
	game.camera_rig.update_camera(0)
	check(game.camera_rig.first_person_active(),"Chief activates first person in live combat")
	check(camera.global_position.distance_to(hero.global_position+Vector3.UP*1.68)<.08,"Chief camera is at the hero's eyes without a third-person orbit")
	check(not hero.model.visible,"Chief's world body does not obscure the first-person camera")
	check(combat.ammo_infinite,"Pistol has unlimited ammunition")
	var start=hero.position
	press("move_right");await frames(12);press("move_right",false)
	check(hero.position.x>start.x+.25 and absf(hero.position.z-start.z)<.25,"Strafing moves laterally without turning the view")
	check(hero.facing.dot(Vector3.FORWARD)>.99,"Strafing preserves camera-facing aim")
	check(hero.is_on_floor(),"Chief is grounded on the test platform before jumping")
	press("jump");await frames(7);press("jump",false)
	check(hero.position.y>start.y+.3,"Chief jumps with the regular Space input (start %s after %s velocity %s)"%[start,hero.position,hero.velocity])
	await frames(60)
	hero.position=Vector3(0,100.1,110);hero.velocity=Vector3.ZERO
	await frames(3)
	var data=game.model.waves.spawn_enemy(0,Vector3(0,100,98))
	data.hp=10000;data.max_hp=10000;data.stun=100
	game.sync_enemies();await frames();game.model.update_vision(hero.position)
	var actor=game.actors[data.id]
	game.tower_arrows.clear()
	game.camera_rig.pitch=0;game.camera_rig.yaw=0;game.camera_rig.update_camera(0)
	var before=data.hp
	var saw_hit_marker=false
	press("light_attack")
	for i in range(22):
		await frames(1)
		saw_hit_marker=saw_hit_marker or combat.hit_marker_timer>0
	press("light_attack",false)
	check(data.hp<before,"Holding LMB damages a real forest enemy through native hit volumes")
	check(combat.shots_fired>=2,"Holding LMB repeats automatic pistol shots")
	check(saw_hit_marker,"A real enemy hit shows confirmation")
	var stopped=combat.shots_fired
	await frames(12)
	check(combat.shots_fired==stopped,"Releasing LMB stops automatic fire")
	var dummy_home=game.training_dummy.home
	game.training_dummy.home=Vector3(0,100,104)
	await frames(3);before=data.hp
	press("light_attack");await frames(8);press("light_attack",false)
	check(is_equal_approx(data.hp,before) and combat.hit_marker_timer>0,"The nearest enemy volume absorbs the shot before a farther target")
	game.training_dummy.home=dummy_home;await frames(3)
	# A static wall must win over a farther fitted enemy hit.
	var wall=StaticBody3D.new();wall.collision_layer=1
	var shape=CollisionShape3D.new();shape.shape=BoxShape3D.new();shape.shape.size=Vector3(5,5,.5)
	wall.add_child(shape);game.add_child(wall);wall.position=Vector3(0,102.5,104)
	await frames(3)
	before=data.hp
	press("light_attack");await frames(14);press("light_attack",false)
	check(is_equal_approx(data.hp,before),"World geometry blocks pistol damage")
	wall.queue_free();await frames(3)
	game.camera_rig.pitch=-.75;game.camera_rig.update_camera(0);before=data.hp
	press("light_attack");await frames(14);press("light_attack",false)
	check(is_equal_approx(data.hp,before),"Aiming above an enemy misses rather than snapping to a target (%.1f -> %.1f, hit %s)"%[before,data.hp,combat.last_hit_point])
	hero.set_physics_process(false)
	combat.cancel();combat.cooldown=0
	var nodes_before=combat.get_child_count()
	press("light_attack")
	combat.tick(0)
	var count_before=combat.shots_fired
	for i in range(50):
		combat.tick_timers(.02);combat.tick(.02)
	press("light_attack",false)
	check(combat.shots_fired-count_before==3,"Native pistol cadence remains 3 follow-up shots at 3.5 rounds/second in one second at 50 Hz")
	check(combat.get_child_count()==nodes_before,"Sustained automatic fire reuses a bounded effect pool")
	hero.set_physics_process(true)
	press("light_attack");await frames(3)
	game.tuning.invincible=false;hero.invuln=0;hero.take_hit(1,Vector3.ZERO);game.tuning.invincible=true
	count_before=combat.shots_fired;await frames(20);press("light_attack",false)
	check(combat.shots_fired>count_before,"A nonfatal hit does not release a held pistol trigger")
	press("light_attack");await frames(3)
	combat.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	count_before=combat.shots_fired;await frames(8);press("light_attack",false)
	check(not combat.primary_held and combat.shots_fired==count_before,"Losing window focus cancels the trigger without replay")
	game.camera_rig.pitch=0;game.camera_rig.update_camera(0)
	press("light_attack");await frames(4);game.show_pause()
	stopped=combat.shots_fired
	check(not combat.primary_held,"Pause clears the held trigger")
	game.resume();await frames(12)
	check(combat.shots_fired==stopped,"Resume never replays shots from the pre-pause hold")
	press("light_attack",false)
	press("light_attack");await frames(3);game.show_rogue_roster()
	check(not combat.primary_held,"Opening the fighter roster cancels held pistol fire")
	game.choose_rogue_character(1);await frames()
	check(not game.camera_rig.first_person_active(),"Switching to Goemon restores third-person view")
	check(camera.global_position.distance_to(hero.global_position)>4,"The regular camera returns to its chase distance")
	check(not is_instance_valid(game.camera_rig.first_person_viewmodel) or not game.camera_rig.first_person_viewmodel.visible,"The pistol viewmodel is hidden for other characters")
	hero.select_character(18);await frames()
	stopped=combat.shots_fired;await frames(10)
	check(combat.shots_fired==stopped,"Switching back to Chief does not resume an old held trigger")
	press("light_attack",false)
	press("light_attack");await frames(3);hero.hp=0;game.defeat();await frames()
	check(not combat.primary_held,"Defeat clears the held trigger")
	check(Input.mouse_mode==Input.MOUSE_MODE_VISIBLE,"Defeat restores the free cursor")
	await finish()
func finish():
	for action in ["move_right","jump","light_attack"]:Input.action_release(action)
	if is_instance_valid(game):game.queue_free()
	paused=false;await frames();await create_timer(.2).timeout
	print("MASTER_CHIEF_GAMEPLAY_RESULT checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)
