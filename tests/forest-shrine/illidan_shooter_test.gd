extends "res://tests/forest-shrine/warcraft_characters_test.gd"
const SHOOTER_OUT="res://build/Other Files/Asset Toolkit/Illidan Shooter/"
const Chief=preload("res://scripts/master_chief_combat.gd")
var launches=[]
var driver:Node
var frame_times=[]

func press(action:String,down:bool=true):
	var event=InputEventAction.new();event.action=action;event.pressed=down
	if down:game.player._unhandled_input(event)
	else:game.player._input(event)

func step_shooter(count:int,rendered:bool=false):
	var live_render=rendered and DisplayServer.get_name()!="headless"
	var previous=[Time.get_ticks_usec()]
	await driver.advance(count if live_render else 1,func(dt):
		if live_render:frame_times.append((Time.get_ticks_usec()-previous[0])/1000.0);previous[0]=Time.get_ticks_usec()
		for i in (1 if live_render else count):
			var begin=Time.get_ticks_usec()
			game.player._physics_process(dt);game.camera_rig.update_camera(dt)
			for nodes in Pool.service(game).all.values():
				for shot in nodes:
					if shot.pool_live and shot.get_script()==Shot:shot._physics_process(dt)
			times.append((Time.get_ticks_usec()-begin)/1000.0))

func photo(name_:String):
	if DisplayServer.get_name()=="headless":return
	game.forest_ui.sync();await frames(2);await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(SHOOTER_OUT+name_+".png")

func wall(at:Vector3,size:Vector3)->StaticBody3D:
	var node=StaticBody3D.new();node.collision_layer=1
	var shape=CollisionShape3D.new();shape.shape=BoxShape3D.new();shape.shape.size=size
	node.add_child(shape);game.add_child(node);node.position=at;return node

func run():
	create_timer(150).timeout.connect(func():printerr("ILLIDAN_SHOOTER_TIMEOUT");quit(1))
	DirAccess.make_dir_recursive_absolute(SHOOTER_OUT)
	await setup_fixture();game.tuning.invincible=true
	driver=load("res://tests/forest-shrine/physics_step_driver.gd").new();root.add_child(driver)
	game.set_process_input(false);game.set_process_unhandled_input(false)
	var p=game.player;var rig=game.camera_rig;var pool=Pool.service(game)
	p.set_process_input(false);p.set_process_unhandled_input(false);rig.set_process_unhandled_input(false)
	p.select_character(32);fresh();p.smoke_mode=true
	wall(Vector3(0,99.5,60),Vector3(160,1,160))
	p.position=Vector3(0,100.1,60);p.velocity=Vector3.ZERO
	rig.yaw=0;rig.pitch=.22;rig.reset_follow();rig.update_camera(1)
	var normal_pitch=rig.pitch;var normal_distance=rig.distance
	await step_shooter(12)
	var c=p.active_ability
	var normal_damage=p.damage_multiplier()
	press("heavy_attack");await step_shooter(100)
	check(c.demon and rig.meta_shooter_mode and rig.first_person_mode,"Metamorphosis enables the first-person hands camera")
	check(not p.model.visible and rig.camera.position.distance_to(p.position+Vector3.UP*3.0)<.001,"Raised meta eyes hide the full body, wings and head")
	check(is_equal_approx(p.damage_multiplier(),normal_damage*10),"Meta form multiplies existing outgoing damage by ten")
	var ceiling=wall(p.position+Vector3.UP*2.5,Vector3(5,.2,5));await physics_frame;await physics_frame;rig.update_camera(0)
	check(rig.camera.global_position.y<p.position.y+2.4 and rig.camera.global_position.y>p.position.y+1.68,"Raised view stays below a low ceiling")
	ceiling.free();await physics_frame;rig.update_camera(0)
	check(is_equal_approx(rig.distance,normal_distance),"Meta framing preserves the saved camera distance")
	check(game.forest_ui.crosshair_visible(),"Meta uses the existing crosshair")
	Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
	var mouse=InputEventMouseMotion.new();mouse.relative=Vector2(40,-50)
	var old_yaw=rig.yaw;var old_pitch=rig.pitch;rig._unhandled_input(mouse)
	if DisplayServer.get_name()!="headless":
		check(is_equal_approx(rig.yaw,old_yaw-40*.0025*rig.sens) and is_equal_approx(rig.pitch,old_pitch-50*.0021*rig.sens),"Meta reuses Chief's mouse sensitivity and pitch controls")
	var dummy=game.training_dummy;dummy.home=p.position+Vector3(0,0,-32);dummy.position=dummy.home
	pool.launched.connect(func(shot):
		if shot.get_script()==Shot:
			shot.set_physics_process(false)
			launches.append({"position":shot.position,"velocity":shot.velocity,"hand":rig.meta_viewmodel.muzzle_position(),"damage":shot.damage}))
	aim_meta_at(dummy.position+Vector3.UP*1.5)
	var sight=Chief.trace_shot(p,rig.camera.position,rig.camera.position-rig.camera.global_basis.z*120)
	check(sight.target==dummy,"Chief's shared fitted-volume trace selects the reticle target")
	contacts.clear();press("light_attack");press("light_attack",false);await step_shooter(3)
	check(launches.is_empty(),"The original bolt windup is preserved")
	await step_shooter(90)
	check(launches.size()==1 and contacts.size()==1,"One aimed click lands one energy bolt")
	if not launches.is_empty():
		check(launches[0].position.distance_to(launches[0].hand)<.001,"Bolt launches from the animated right hand")
		check(is_equal_approx(launches[0].velocity.length(),28) and is_equal_approx(launches[0].damage,640),"Meta bolts deal ten times their former 64 damage at the original speed")
	# Visible, moving casting hand through the original clip, using the gameplay camera.
	var view=rig.meta_viewmodel
	check(view.hand_triangles>0 and view.hand_triangles<40000 and view.hand_meshes.size()==2,"Only the prepared anatomical arms and claws are visible")
	view.pose("Stand Alternate",0)
	var finger=view.skeleton.find_bone("frame r middle mid")
	var relaxed=view.skeleton.get_bone_pose_rotation(finger)
	var thumbs=[view.skeleton.find_bone("frame l thumb low"),view.skeleton.find_bone("frame r thumb low")]
	var resting_thumbs=thumbs.map(func(bone):return view.skeleton.get_bone_pose_rotation(bone))
	var rest_hand=view.muzzle_position()
	for hand in [view.hand_bone,view.left_hand_bone]:
		check(view.skeleton.get_bone_pose_rotation(hand).angle_to(Quaternion.IDENTITY)<.001,"Resting wrist has no extra bend or twist")
	view.pose("Attack Alternate",.26)
	var opening=relaxed.angle_to(view.skeleton.get_bone_pose_rotation(finger))
	check(opening>deg_to_rad(25) and opening<deg_to_rad(45),"Release opens the fingers into the expressive casting pose")
	for i in thumbs.size():
		var spread=resting_thumbs[i].angle_to(view.skeleton.get_bone_pose_rotation(thumbs[i]))
		check(spread>deg_to_rad(35) and spread<deg_to_rad(65),"Casting thumb spreads away from the palm %d"%i)
	check(view.muzzle_position().distance_to(rest_hand)>.025,"Cast socket follows the animated palm")
	view.pose("Attack Alternate",view.animations.get_animation("Attack Alternate").length)
	check(view.skeleton.get_bone_pose_rotation(finger).angle_to(relaxed)<.001,"Cast recovery returns to the relaxed fingers")
	for i in thumbs.size():
		check(view.skeleton.get_bone_pose_rotation(thumbs[i]).angle_to(resting_thumbs[i])<.001,"Casting thumb returns to its resting pose %d"%i)
	check(view.muzzle_position().distance_to(rest_hand)<.001,"Cast recovery restores the resting palm")
	check(view.hand_meshes[0].layers==1 and view.weapon_camera.cull_mask==1,"Isolated hand viewport uses a lit layer")
	var screens=[]
	for t in [0.0,.13,.26,.4]:
		view.pose("Attack Alternate",t)
		var hand=view.muzzle_anchor.global_position;var screen=view.weapon_camera.unproject_position(hand)
		screens.append(screen)
		check(not view.weapon_camera.is_position_behind(hand) and root.get_visible_rect().has_point(screen),"Casting hand stays in frame at %.2fs"%t)
		await photo("cast-%.2f"%t)
	check(screens[0].distance_to(screens[2])>20,"Authored palm animation visibly moves on screen")
	# Free aim above the target must miss; the shot still travels upward.
	c.cancel(true);rig.pitch=-.6;rig.update_camera(1);contacts.clear();launches.clear()
	press("light_attack");press("light_attack",false);await step_shooter(100)
	check(launches.size()==1 and launches[0].velocity.y>0 and contacts.is_empty(),"Pitch aiming fires upward without auto-snapping to the enemy")
	# Movement retains the camera's facing while the existing attack motion runs.
	aim_meta_at(dummy.position+Vector3.UP*1.5)
	var before=p.position;launches.clear();p.smoke_move=Vector2.RIGHT
	press("light_attack");await step_shooter(80,true);press("light_attack",false);p.smoke_move=Vector2.ZERO
	check(p.position.distance_to(before)>1 and p.facing.dot(Vector3.FORWARD.rotated(Vector3.UP,rig.yaw))>.999,"Strafing and held fire preserve camera-facing aim")
	check(launches.size()>=3,"Holding LMB repeats complete original casting cycles")
	await step_shooter(60);var stopped=launches.size();await step_shooter(60)
	check(launches.size()==stopped and not c.primary_held,"Releasing LMB stops repeat fire after the current cast")
	# A hand behind cover must not emit on its far side.
	c.cancel(true);p.position=Vector3(0,100.1,60);p.velocity=Vector3.ZERO;rig.yaw=0;rig.pitch=0;rig.reset_follow();rig.update_camera(1)
	view.pose("Attack Alternate",c.contact)
	var cover=wall(rig.camera.global_position.lerp(view.muzzle_position(),.5),Vector3(.04,.25,.04));await physics_frame;await physics_frame
	var eye_sight=Chief.trace_shot(p,rig.camera.position,rig.camera.position-rig.camera.global_basis.z*120)
	check(not eye_sight.impact or eye_sight.target==dummy,"Eye sight is clear while the visible hand crosses nearby cover")
	launches.clear();press("light_attack");press("light_attack",false);await step_shooter(6)
	var resolved=false
	for nodes in pool.all.values():
		for shot in nodes:
			if shot.pool_live and shot.get_script()==Shot and shot.resolved and shot.position.z>cover.position.z-.03:resolved=true
	check(resolved,"Chief's eye-to-hand sweep prevents firing through nearby cover")
	cover.free();await step_shooter(60)
	press("light_attack");game.show_pause()
	rig.sync_character_view()
	check(not c.primary_held and c.demon and not view.visible and not view.overlay.visible,"Pause cancels held fire and hides hands while preserving meta form")
	game.resume();stopped=launches.size();await step_shooter(40)
	check(launches.size()==stopped,"Resume does not replay the old trigger")
	press("light_attack");c.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	check(not c.primary_held and c.demon,"Focus loss clears the trigger and keeps the form")
	c.cooldown=0;press("heavy_attack");press("light_attack");await step_shooter(100)
	check(not c.demon and not rig.meta_shooter_mode and is_equal_approx(rig.pitch,normal_pitch),"Reverse morph restores the previous camera pitch")
	check(is_equal_approx(p.damage_multiplier(),normal_damage),"Reverse morph removes the tenfold damage multiplier")
	check(not c.primary_held and not c.is_attacking(),"Holding fire during reverse morph cannot repeat normal-form melee")
	press("light_attack",false)
	p.select_character(18);rig.update_camera(1)
	check(rig.first_person_mode and not rig.meta_shooter_mode and not p.model.visible,"Master Chief still uses his original first-person camera")
	p.select_character(32);p.active_ability.demon=true;rig.update_camera(1)
	check(rig.meta_shooter_mode and rig.meta_viewmodel.visible and not rig.first_person_viewmodel.visible,"Chief to meta swaps gun for hands")
	p.select_character(1);rig.update_camera(1)
	check(not rig.meta_shooter_mode and not rig.first_person_mode and is_equal_approx(rig.pitch,normal_pitch),"Character changes restore the ordinary view")
	p.select_character(32);c=p.active_ability;c.demon=true;rig.update_camera(1);rig.pitch=-.3
	await step_shooter(120);await create_timer(.4).timeout
	var resources=Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT);var nodes=Performance.get_monitor(Performance.OBJECT_NODE_COUNT);var made=pool.created
	for cycle in 3:
		press("light_attack");await step_shooter(120,cycle==0);press("light_attack",false);await step_shooter(360)
	await create_timer(.4).timeout;await frames(2)
	check(pool.created==made and pool.misses==0,"Repeated firing reuses all prepared bolt leases")
	var resource_delta=Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)-resources
	var node_delta=Performance.get_monitor(Performance.OBJECT_NODE_COUNT)-nodes
	check(resource_delta<=0 and node_delta<=0,"Settled repeat fire retains no nodes or resources: nodes %d, resources %d"%[node_delta,resource_delta])
	times.sort();frame_times.sort()
	var report={"checks":checks,"failures":failures,"step_p95_ms":times[int(times.size()*.95)],"frame_p95_ms":frame_times[int(frame_times.size()*.95)] if not frame_times.is_empty() else null,"frame_max_ms":frame_times[-1] if not frame_times.is_empty() else null,"pool_misses":pool.misses,"resource_delta":resource_delta,"node_delta":node_delta}
	FileAccess.open(SHOOTER_OUT+DisplayServer.get_name()+".json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("ILLIDAN_SHOOTER_RESULT ",JSON.stringify(report))
	game.queue_free();await frames(3);DirAccess.remove_absolute(cfg);quit(1 if failures else 0)
