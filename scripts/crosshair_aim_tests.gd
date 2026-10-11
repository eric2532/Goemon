extends "res://scripts/rogue_equipment_combat_tests.gd"
var Flight = load("res://assets/rogue/scripts/ranger_arrow_flight.gd")

func run():
	game.smoke_test=true;game.tuning.invincible=true;game.tuning.freeze_ai=true
	ProjectSettings.set_setting("goemon/experimental_crosshair",true)
	game.player.smoke_mode=true;game.start_mode("defense");pause_fixture_director();await frames(3)
	check(game.camera_rig.pitch<.1 and game.camera_rig.distance==9.0,"Fire Siege starts with the crosshair shoulder-view defaults")
	check(game.has_method("crosshair_aim_enabled"),"Separate crosshair aiming feature exists")
	if game.has_method("crosshair_aim_enabled"):
		await aiming_rules()
		curve_rules()
		if not OS.has_feature("crosshair_aim"):
			game.start_mode("defense");pause_fixture_director();await frames(3)
			check(game.camera_rig.pitch==.5 and game.camera_rig.distance==14.0,"Baseline Fire Siege retains its original camera defaults")
	game.show_main_menu();game.sound_library.cancel();game.music.stop();stop_audio(game)
	await frames(10)
	print("CROSSHAIR_AIM_RESULT checks=",checks," failures=",failures)
	get_tree().quit(1 if failures else 0)

func aiming_rules():
	ProjectSettings.set_setting("goemon/experimental_crosshair",false)
	check(not game.crosshair_aim_enabled() or OS.has_feature("crosshair_aim"),"Baseline keeps camera-facing aiming")
	ProjectSettings.set_setting("goemon/experimental_crosshair",true)
	await fresh_class(7)
	var p=game.player;var a=p.active_ability;var camera=game.camera_rig.camera
	game.camera_rig.set_process(false);p.set_physics_process(false);a.set_process(false)
	p.position=Vector3(0,300,210);a.player.pos=p.position
	camera.global_position=p.position+Vector3(1.4,3,8);camera.look_at(p.position+Vector3(0,8,-30))
	await frames(2)
	var origin:Vector3=p.position+Vector3.UP*1.05
	var target:Vector3=game.crosshair_target()
	var ray:Vector3=camera.project_ray_normal(camera.get_viewport().get_visible_rect().size*.5)
	check(target.distance_to(camera.project_ray_origin(camera.get_viewport().get_visible_rect().size*.5)+ray*120)<.01,"Reticle uses the exact camera center ray")
	var direction:Vector3=game.projectile_direction(origin)
	check(direction.y>0 and direction.dot((target-origin).normalized())>.99999,"Weapon converges on upward crosshair in three dimensions")
	a._update_aim();a.Actions.fire_ranger_fan(a,a.player.angle,true,"flintlock",a.ranger_ground_target(a.player.angle))
	check(a.projectiles.size()==5,"Airborne fan retains five arrows")
	if a.projectiles.size()==5:
		var shots=a.projectiles
		check(shots.all(func(pr):return pr.aimDirection.y>0),"Airborne arrows can aim upward instead of forced downward fire")
		check(shots[2].aimDirection.dot(direction)>.9999,"Middle fan arrow uses crosshair reference")
		check(absf(shots[0].aimDirection.signed_angle_to(shots[4].aimDirection,Vector3.UP))>.9,"Fan keeps its broad spread")
		check(shots.any(func(pr):return pr.vel.normalized().distance_to(pr.aimDirection)>.001),"Arrows keep independent release deviation")
		check(shots.all(func(pr):return pr.rangerFlight.get("curved",false)),"Experimental fan enables gentle curved flight")
	a.cancel();p.move_and_slide();p.jumps_used=2;a._update_aim()
	a.player.cooldowns.cutlass=0;a.attack();a.tick(.12,false)
	check(a.projectiles.size()==5,"Actual double-jump primary still releases the fan")
	check(not a.projectiles.is_empty() and a.projectiles.all(func(pr):return pr.aimDirection.y>0),"Double-jump attack release follows upward crosshair")
	a.cancel();p.jumps_used=0;a.player.rangerShots=0
	for shot in range(3):
		a.player.cooldowns.cutlass=0;a.attack();a.tick(.12,false)
		check(not a.projectiles.is_empty() and a.projectiles.back().get("power",false)==(shot==2),"Crosshair LMB preserves third-shot power rhythm %d" % (shot+1))
		a._clear_projectiles()
	# Physical wall: camera ray acquires the surface, muzzle sweep cannot pass it.
	a.cancel();camera.look_at(p.position+Vector3(0,1,-30))
	var wall=obstacle(Vector3(0,2,-4),Vector3(10,10,.5));await frames(2)
	target=game.crosshair_target();check(target.z>p.position.z-4.5 and target.z<p.position.z-3.5,"Crosshair ray respects physical cover")
	a._update_aim();a.Actions.fire_projectile(a,{"speed":34,"kind":"arrow"})
	var pr=a.projectiles.back();a.Actions.update_projectile(a,pr,.5)
	check(pr.life<=0 and pr.mesh.position.z>wall.position.z-.5,"Curved arrow is stopped by actual cover")
	wall.queue_free();await frames(2)
	check(game.hud.crosshair_visible(),"Reticle appears in living gameplay")
	game.paused=true;check(not game.hud.crosshair_visible(),"Pause hides the reticle");game.paused=false
	p.hp=0;check(not game.hud.crosshair_visible(),"Defeat hides the reticle");p.hp=p.max_hp
	game.camera_rig.pitch=.06;game.camera_rig.distance=9;game.camera_rig.reset_follow()
	game.camera_rig._process(.2)
	var screen:Vector2=camera.unproject_position(p.position+Vector3.UP*1.4)
	check(screen.x<camera.get_viewport().get_visible_rect().size.x*.5-20,"Shoulder camera leaves the center clear of the hero")
	game.camera_rig.pitch=-.5;game.camera_rig._process(.2)
	check(-camera.global_basis.z.y>0 and camera.position.y>p.position.y,"Camera can aim upward while staying above the ground")
	var side_wall=obstacle(Vector3(.65,2,5),Vector3(.2,16,30));await frames(2)
	game.camera_rig.yaw=0;game.camera_rig.pitch=.06;game.camera_rig._process(.2)
	check(camera.position.x<.55,"Shoulder camera cannot cross a thin wall beside the hero")
	side_wall.queue_free();await frames(2)
	p.select_character(2);p.set_physics_process(false)
	p.position=Vector3(0,300,210);camera.global_position=p.position+Vector3(1.4,3,8)
	camera.look_at(p.position+Vector3(0,8,-30))
	p.musashi.activate_shield();p.musashi.start_beam("light_attack")
	var beam=p.musashi.beam
	check(is_instance_valid(beam) and beam.direction.y>0 and beam.direction.dot(game.projectile_direction(beam.global_position))>.9999,"Edo empowered beam follows the upward reticle")
	p.musashi.cancel();ProjectSettings.set_setting("goemon/experimental_crosshair",false)

func curve_rules():
	var node=Node3D.new();add_child(node)
	var pr={"mesh":node,"vel":Vector3.FORWARD*20,"life":1.0}
	Flight.attach(pr,1,1.0,true);Flight.advance(pr,.5)
	check(node.position.distance_to(Vector3(0,0,-10))>.1 and node.position.distance_to(Vector3(0,0,-10))<.3,"Flight has a gentle bounded curve")
	check(node.basis.z.normalized().dot(pr.flightDirection)>.9999,"Arrow follows its actual curved-flight tangent")
	Flight.advance(pr,.5);check(node.position.distance_to(Vector3(0,0,-20))<.0001,"Curve returns to original launch ray at full range")
	var stepped=Node3D.new();add_child(stepped)
	var other={"mesh":stepped,"vel":Vector3.FORWARD*20,"life":1.0}
	Flight.attach(other,1,1.0,true)
	for step in range(10):Flight.advance(other,.1)
	check(node.position.distance_to(stepped.position)<.0001,"Flight endpoint is independent of frame subdivisions")
	node.queue_free();stepped.queue_free()
