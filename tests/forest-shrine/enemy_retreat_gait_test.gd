extends SceneTree
const Crowd=preload("res://scripts/forest/forest_enemy_crowd.gd")
const Contact=preload("res://scripts/forest/forest_enemy_contact.gd")
var checks=0
var failures=0
var retained={}
var camera: Camera3D
func _initialize():run.call_deferred()
func check(ok: bool,message: String):
	checks+=1
	if not ok:failures+=1;printerr("FAIL: "+message)
func clear_model(m):
	m.trees.clear();m.workers.clear();m.enemies.clear()
	for b in m.buildings.values():
		if b.id!=1:m._remove_building(b.id)
	m.rebuild_navigation();m.start_wave();m.waves.pending=0;m.waves.spawn_clock=10000
func world_foot(e: Dictionary,group: String)->Transform3D:
	return Transform3D(Basis(Vector3.UP,e.facing),e.pos)*Crowd.part_pose(group,e)
func stance(e: Dictionary,group: String)->bool:
	return fposmod(e.walk_phase+(PI if group=="foot_r" else 0),TAU)<PI
func run_forward():
	var m=load("res://scripts/forest/forest_model.gd").new();m.reset(42);clear_model(m)
	var e=m.waves.spawn_enemy(2,Vector3(0,0,102));e.facing=0.0
	var samples=0;var max_slip=0.0
	for i in range(90):
		var old: Dictionary=e.duplicate(true);m.waves.tick(.1,Vector3.ZERO)
		if old.velocity.length()>.7 and e.velocity.length()>.7 and is_equal_approx(old.facing,e.facing):
			for group in ["foot_l","foot_r"]:
				if stance(old,group) and stance(e,group):
					samples+=1;max_slip=maxf(max_slip,world_foot(old,group).origin.distance_to(world_foot(e,group).origin))
	check(samples>50 and max_slip<.0001,"Ordinary forward director walk retains its planted gait")
	check(absf(e.pos.distance_to(Vector3(0,0,102))-6.75)<.001,"Ordinary forward walk retains .75m/s")
	print("FORWARD_GAIT samples=%d max_slip_m=%.8f"%[samples,max_slip])
func run_fixture(tight: bool):
	var m=load("res://scripts/forest/forest_model.gd").new();m.reset(42);clear_model(m)
	var tower=m._make_building("tower",Vector2i(-1,12),0)
	if tight:m._make_building("tower",Vector2i(-5,7),0);m._make_building("tower",Vector2i(2,7),0)
	m.rebuild_navigation();var e=m.waves.spawn_enemy(2,Vector3(0,0,60));e.facing=0.0
	var samples=0;var backward=0;var diagonal=0;var bends=0;var max_slip=0.0;var bend_slip=0.0;var max_speed=0.0;var max_yaw=0.0;var lifted=false;var clear=true
	var freeze_checked=false
	for i in range(650):
		var old: Dictionary=e.duplicate(true)
		m.waves.tick(.1,Vector3.ZERO)
		max_speed=maxf(max_speed,e.pos.distance_to(old.pos)/.1)
		max_yaw=maxf(max_yaw,absf(wrapf(e.facing-old.facing,-PI,PI)))
		if not old.get("turn_escape",[]).is_empty() and e.velocity.length()>.7 and is_equal_approx(old.facing,e.facing):
			clear=clear and m.waves.navigation.fitted_blocker(e,e.pos)<0
			var local: Vector3=Basis(Vector3.UP,e.facing).inverse()*e.velocity
			if local.z>.1:backward+=1
			if absf(local.x)>.1 and absf(local.z)>.1:diagonal+=1
			var bend=old.velocity.length()>.7 and old.velocity.normalized().distance_to(e.velocity.normalized())>.05
			for group in ["foot_l","foot_r"]:
				lifted=lifted or Crowd.part_pose(group,e).origin.y>.4
				if stance(old,group) and stance(e,group) and old.velocity.length()>.7:
					# Check a source vertex as well as the part origin: rotation cannot hide sliding.
					var a=world_foot(old,group);var b=world_foot(e,group)
					var slip=maxf(a.origin.distance_to(b.origin),(a*Vector3(-4.65,.1,0)).distance_to(b*Vector3(-4.65,.1,0)))
					max_slip=maxf(max_slip,slip);samples+=1
					if bend:bends+=1;bend_slip=maxf(bend_slip,slip)
					if tight and bend:retained=e.duplicate(true)
					if tight and bend and not freeze_checked:
						freeze_checked=true
						var planted=world_foot(e,group);var local_pose=Crowd.part_pose(group,e)
						e.frozen=.2;m.waves.tick(.1,Vector3.ZERO)
						var snapshot: Dictionary=e.frozen_pose
						check(world_foot(e,group).is_equal_approx(planted),"Director freeze at a retreat bend retains the stance anchor before presentation")
						m.waves.tick(.2,Vector3.ZERO)
						check(stance(e,group) and world_foot(e,group).origin.distance_to(planted.origin)<.0001,"Thawing resumes retreat without moving the grounded foot")
						check(Crowd.part_pose(group,{"frozen":1.0,"frozen_pose":snapshot}).is_equal_approx(local_pose),"Resumed gait updates cannot mutate the retained freeze snapshot")
		if tower.hp<tower.max_hp:break
	check(samples>50,"%s fixture exercises sustained director retreat stance"%tight)
	check(diagonal>20,"%s fixture exercises local diagonal retreat"%tight)
	if tight:
		check(backward>20,"Tight fixture exercises local backward retreat")
		check(bends>0,"Tight fixture exercises a waypoint bend during the same planted stance")
		check(bend_slip<.0001,"Waypoint changes do not move any grounded foot vertex")
	check(max_slip<.0001,"%s fixed-facing retreat keeps grounded feet planted, max slip %.6fm"%[tight,max_slip])
	check(max_speed<=.7501 and max_yaw<=.0451,"%s retreat preserves the slow movement and turn limits"%tight)
	check(clear,"%s retreat retains fitted building clearance"%tight)
	check(lifted,"%s retreat retains visible alternating foot lift"%tight)
	print("RETREAT_GAIT tight=%s samples=%d backward=%d diagonal=%d stance_bends=%d max_slip_m=%.8f bend_slip_m=%.8f max_speed=%.6f max_yaw=%.6f"%[tight,samples,backward,diagonal,bends,max_slip,bend_slip,max_speed,max_yaw])
func run():
	run_forward();run_fixture(false);run_fixture(true)
	# Feed the actual director retreat into the production actor and renderer, then freeze.
	var game=load("res://scenes/forest_shrine.tscn").instantiate();root.add_child(game);current_scene=game
	await physics_frame;await physics_frame
	game.start_wave();game.set_physics_process(false);game.player.set_physics_process(false)
	game.model.enemies.clear();game.model.workforce.arrows.clear();game.model.events.clear()
	game.model.waves.pending=0;game.model.waves.spawn_clock=10000
	var e: Dictionary=retained.duplicate(true);game.model.enemies[e.id]=e
	game.sync_enemies();var actor=game.actors[e.id];actor.set_physics_process(false);actor._sync_fitted_pose()
	game.model.update_vision(e.pos);game.crowd.set_process(false);game.crowd._process(0)
	if DisplayServer.get_name()!="headless":
		camera=Camera3D.new();camera.fov=45;camera.far=300;game.add_child(camera);camera.current=true
		camera.position=e.pos+Vector3(34,14,-40);camera.look_at(e.pos+Vector3.UP*10,Vector3.UP)
		await native_shot("live")
	var group="foot_l" if stance(e,"foot_l") else "foot_r"
	var before=world_foot(e,group)
	var item: Dictionary
	for shape in Contact.shapes(2):
		if shape.group==group:item=shape;break
	var center: Vector3=before*item.center
	var from=center+Vector3(0,0,-8)
	var surface: Vector3=actor.combat_contact_point(from)
	check(actor.combat_segment_hit(center,center,.002),"Live retreat actor contact contains the rendered planted foot center")
	var aligned=false
	for entry in actor.fitted_shapes:
		if entry.item.group==group:aligned=entry.node.global_transform.is_equal_approx(before)
	check(aligned,"Live retreat physical collider and rendered foot use the same transform")
	actor.freeze_for(2)
	for i in range(10):
		game.model.waves.tick_enemy(e,.1,Vector3.ZERO);actor._physics_process(.016);game.crowd._process(0)
	check(world_foot(e,group).is_equal_approx(before),"Freeze during retreat retains the planted world foot transform")
	check(actor.combat_contact_point(from).distance_to(surface)<.002,"Frozen actor keeps the retreat foot contact surface")
	check(actor.combat_segment_hit(center,center,.002),"Frozen actor collider contains the rendered retreat foot center")
	aligned=false
	for entry in actor.fitted_shapes:
		if entry.item.group==group:aligned=entry.node.global_transform.is_equal_approx(before)
	check(aligned,"Frozen physical collider retains the live rendered retreat transform")
	var image=game.crowd.pose_images[2];var index=Crowd.GROUPS.find(group)
	var local_pose=Crowd.part_pose(group,e)
	var uploaded=Vector3(image.get_pixel(index*3,0).a,image.get_pixel(index*3+1,0).a,image.get_pixel(index*3+2,0).a)
	check(uploaded.distance_to(local_pose.origin)<.0001,"Renderer uploads the authoritative frozen directional foot pose")
	var basis_ok=true
	for axis in range(3):
		var column=image.get_pixel(index*3+axis,0)
		basis_ok=basis_ok and Vector3(column.r,column.g,column.b).distance_to(local_pose.basis[axis])<.0001
	check(basis_ok,"Frozen uploaded foot orientation agrees with the physical collider")
	game.model.workforce.arrows[888]={"id":888,"from":from,"pos":from,"target":e.id,"age":0.0}
	game.model.workforce.tick_arrows(.1)
	var impacts: Array=game.model.events.filter(func(event):return event.kind=="arrow_impact" and event.id==888)
	check(impacts.size()==1,"Model-owned arrow reaches the frozen retreat foot")
	if impacts.size()==1:
		check(impacts[0].to.distance_to(surface)<.002,"Model-owned arrow and actor agree on the frozen directional foot surface")
		check(actor.combat_segment_hit(impacts[0].to,impacts[0].to,.002),"Frozen directional arrow impact lies in the actor collider")
	if DisplayServer.get_name()!="headless":
		await native_shot("freeze")
		print("FOREST_ENEMY_RETREAT_GAIT_RESULT checks=%d failures=%d"%[checks,failures]);await game.quit_clean();quit(1 if failures else 0);return
	game.queue_free();await physics_frame;await physics_frame;await create_timer(.35).timeout
	print("FOREST_ENEMY_RETREAT_GAIT_RESULT checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)
func native_shot(label: String):
	await process_frame;await process_frame;await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.superpowers/sdd/2026-10-14-forest-enemy-integration/final-retreat-%s.png"%label)
