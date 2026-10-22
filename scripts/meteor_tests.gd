extends "res://scripts/power_combat_tests.gd"

func rains()->Array:return get_tree().get_nodes_in_group("edo_meteor_rains")
func fresh_meteor():
	await prepare(2);game.player.invuln=0
	for effect in get_tree().get_nodes_in_group("edo_explosions"):effect.queue_free()
	await get_tree().physics_frame
func capture(label: String):
	if not visual:return
	game.hud.banner_time=0;game.hud.toast_time=0
	var close=label in ["01-arm-raised","02-ground-strike"]
	var camera=game.camera_rig.camera;var old_transform=camera.global_transform
	if close:
		game.camera_rig.set_process(false)
		camera.global_position=game.player.position+Vector3(3,2.4,-4.5)
		camera.look_at(game.player.position+Vector3.UP*1.1)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://tests/edo-meteor/"+label+".png")
	if close:camera.global_transform=old_transform;game.camera_rig.set_process(true)
func planted_target(offset: Vector3)->Ninja:
	var point=EdoMeteorRain.ground_point(game.player,game.player.position+offset)
	var enemy=target(offset)
	if point!=null:enemy.global_position=point+Vector3.UP*.02
	enemy.set_physics_process(false)
	return enemy
func test_rain(points: Array[Vector3],damage: float=240,radius: float=5.5)->EdoMeteorRain:
	var rain=EdoMeteorRain.new();rain.game=game;rain.hero=game.player;rain.targets=points;rain.damage=damage;rain.radius=radius
	game.add_child(rain);return rain

func run():
	visual="--meteor-visual" in OS.get_cmdline_user_args()
	Input.use_accumulated_input=false
	game.tuning=PrototypeTuning.DEFAULTS.duplicate();game.tuning.invincible=true;game.tuning.freeze_ai=true
	game.start_game();game.encounters.enabled=false;game.player.smoke_mode=true
	game.camera_rig.set_process_unhandled_input(false);get_window().set_flag(Window.FLAG_NO_FOCUS,true)
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	var p=game.player
	await fresh_meteor()
	var first=planted_target(Vector3(-10,0,-12));var second=planted_target(Vector3(10,0,-14));var third=planted_target(Vector3(0,0,-24))
	var start=p.position
	await key(KEY_T)
	check(p.musashi.is_casting_meteors() and p.musashi.beam==null,"T starts a meteor pose, not the old beam shortcut")
	p.smoke_move=Vector2(0,-1);await wait(.25);p.smoke_move=Vector2.ZERO
	var raised_hand=p.model.hand_position("R").y-p.global_position.y
	check(p.position.distance_to(start)<.15 and rains().is_empty(),"Edo stays planted while winding up before rainfall")
	var head_height=p.model.skeleton.get_bone_global_pose(p.model.skeleton.find_bone("Head")).origin.y
	check(raised_hand>head_height+.25,"Casting pose raises Edo's right hand above his head bone (height %.2f)" % raised_hand)
	await capture("01-arm-raised")
	await wait(.32)
	check(rains().size()==1,"Downward strike releases exactly one rainfall")
	var rain=rains()[0]
	check(rain.targets.size()>=4 and rain.targets.size()<=12 and rain.strikes.size()==rain.targets.size(),"Cast contains 4–12 falling fireballs")
	check(p.model.hand_position("R").y-p.global_position.y<raised_hand-.4,"Arm drives downward into the ground-strike pose")
	await capture("02-ground-strike")
	var unique={}
	for point in rain.targets:unique[str(point)]=true
	check(unique.size()==rain.targets.size(),"Rainfall spreads impacts across distinct areas")
	await wait(.62);await capture("03-falling-meteors")
	check(rain.impacts==0,"Falling fireballs do not deal damage before landing")
	await wait(.37);await capture("04-explosions")
	await wait(.35);await capture("05-dodge-smoke")
	await wait(.75)
	check(first.hp<=9760 and second.hp<=9760 and third.hp<=9760,"One T cast deals massive blast damage to multiple separated enemy groups")
	check(rains().is_empty(),"Rain controller, fireballs clean up after final impact")
	await wait(1.5);check(get_tree().get_nodes_in_group("edo_explosions").is_empty(),"Dodge-style fire and smoke also clean up")

	await fresh_meteor()
	for count in [4,12]:
		var points=EdoMeteorRain.choose_targets(p,count,80)
		var distinct={};var inside=true
		for point in points:
			distinct[str(point)]=true
			inside=inside and game.world.playable_bounds.has_point(Vector2(point.x,point.z))
		check(points.size()==count and distinct.size()==count and inside,"Empty battlefield still receives %d distinct valid ground impacts" % count)
	# Deterministic blast tests isolate damage from randomized targeting/counts.
	var enemy=planted_target(Vector3(0,0,-6));var nearby=planted_target(Vector3(2,0,-6));var outside=planted_target(Vector3(9,0,-6))
	var point=enemy.position-Vector3.UP*.02
	rain=test_rain([point]);await wait(1.2)
	check(enemy.hp==9760 and nearby.hp==9760 and outside.hp==10000,"A meteor deals 240 AoE damage once per nearby target, with a finite blast radius")
	await fresh_meteor();enemy=planted_target(Vector3(0,0,-6));point=enemy.position-Vector3.UP*.02
	rain=test_rain([point,point]);await wait(1.4)
	check(enemy.hp==9520,"Separate overlapping meteors each deal their own impact damage")
	await fresh_meteor();p.collect_powerup("damage");p.collect_powerup("range")
	await key(KEY_T);await wait(.55);rain=rains()[0]
	check(rain.damage==360 and is_equal_approx(rain.radius,8.25),"Damage and range orbs boost meteor damage and blast radius")

	var durations=[]
	for stacks in [0,4]:
		await fresh_meteor()
		for i in range(stacks):p.collect_powerup("attack_speed")
		seed(3029);await key(KEY_T);var frames=0
		while (p.musashi.is_casting_meteors() or not rains().is_empty()) and frames<300:
			await get_tree().physics_frame;frames+=1
		durations.append(frames)
	check(durations[1]<durations[0]*.43 and durations[1]>durations[0]*.25,"Attack-speed stacks accelerate both casting and falling: "+str(durations))
	await fresh_meteor();await key(KEY_T);await key(KEY_T);await key(KEY_T)
	check(p.musashi.meteor_pending==0,"Rapid T taps do not queue more casts during an active cast")
	var seen={}
	for frame in range(240):
		await get_tree().physics_frame
		for effect in rains():seen[effect.get_instance_id()]=true
	check(seen.size()==1 and p.musashi.meteor_pending==0,"Rapid taps finish only the active rainfall without a stored backlog")
	await fresh_meteor()
	var hold=InputEventKey.new();hold.physical_keycode=KEY_T;hold.pressed=true;Input.parse_input_event(hold);Input.flush_buffered_events()
	await wait(.1)
	var repeat=hold.duplicate();repeat.echo=true;Input.parse_input_event(repeat);Input.flush_buffered_events()
	await wait(.1)
	check(p.musashi.meteor_pending==0,"Keyboard auto-repeat cannot silently queue extra casts")
	var release=hold.duplicate();release.pressed=false;Input.parse_input_event(release);Input.flush_buffered_events()
	await wait(.4);check(rains().size()==1,"Releasing T does not cancel its one-shot spell")

	await fresh_meteor();await key(KEY_T);await wait(.55);rain=rains()[0]
	game.show_pause();var age=rain.elapsed;await wait(.3)
	check(is_instance_valid(rain) and rain.elapsed==age,"Pause freezes an already released rainfall")
	game.resume();await wait(1.8);check(rains().is_empty(),"Released rainfall resumes and finishes after unpausing")
	await fresh_meteor();await key(KEY_T);await key(KEY_T);game.show_pause();game.resume();await wait(1)
	check(rains().is_empty() and p.musashi.meteor_pending==0,"Pause cancels unreleased casting and queued taps")
	await fresh_meteor();await key(KEY_T);await wait(.2);p.musashi.interrupt_for_dodge();await wait(1)
	check(rains().is_empty(),"Dodging before the ground strike cancels an unreleased spell")
	await fresh_meteor();await key(KEY_T);await wait(.55);p.musashi.interrupt_for_dodge();await wait(.1)
	check(not rains().is_empty(),"Dodging after release lets falling meteors finish")
	await key(KEY_Q);await wait(.1)
	check(rains().is_empty(),"Character switching removes Edo's pending rain")
	await fresh_meteor();await key(KEY_R);await mouse(true);await wait(.15)
	check(is_instance_valid(p.musashi.beam),"R + held LMB retains the shield beam")
	await key(KEY_T)
	check(p.musashi.is_casting_meteors() and p.musashi.beam==null and p.musashi.empowered(),"T replaces an active beam with meteor casting while retaining R shield")
	await mouse(false);await wait(.9);await mouse(true)
	check(is_instance_valid(p.musashi.beam),"LMB can channel the R beam again after the meteor pose")
	await mouse(false)
	await fresh_meteor();await key(KEY_T);await wait(.55);game.restart_area();await wait(.1)
	check(rains().is_empty() and get_tree().get_nodes_in_group("edo_explosions").is_empty(),"Restart removes rain and explosions")
	game.show_main_menu();await wait(.1)
	print("METEOR_RESULT failures=",failures)
	get_tree().quit(1 if failures else 0)
