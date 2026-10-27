extends "res://scripts/recovered_goemon_gameplay_tests.gd"
const SIZE=preload("res://scripts/weapon_proportions.gd").RECOVERED_SKILL_SCALE
const OUTPUT="res://build/Other Files/Asset Toolkit/Weapon Scale/"
var visual=false

func capture(label:String):
	if not visual:return
	game.forest_ui.sync()
	await frames(3)
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(OUTPUT+label+".png")==OK,"Rendered "+label)

func run():
	visual="--visual" in OS.get_cmdline_user_args()
	create_timer(120).timeout.connect(func():printerr("Skill scale test timed out");quit(1))
	await setup_fixture()
	game.set_process(false);game.army_runtime.set_process(false);game.army_runtime.set_physics_process(false)
	if visual:DisplayServer.window_move_to_foreground();root.grab_focus()
	var p=game.player
	p.position=ORIGIN;p.facing=Vector3.FORWARD;p.velocity=Vector3.ZERO
	game.training_dummy.position=ORIGIN+Vector3(12,0,0)
	var camera=game.camera_rig.camera
	camera.global_position=ORIGIN+Vector3(11,10,18);camera.look_at(ORIGIN+Vector3(0,3,-3));camera.fov=50
	var pool=preload("res://scripts/character_projectile_pool.gd").service(game)
	p.model.pipe.show();p.model.apply_native_pose(0x68,.1)
	camera.global_position=ORIGIN+Vector3(9,6,-14);camera.look_at(ORIGIN+Vector3(0,2,0))
	await capture("goemon-reference")
	for id in [16,17]:
		p.select_character(id);p.set_physics_process(false)
		var c=p.active_ability;var model=p.model
		model.set_process(false);model.rotation=Vector3.ZERO
		check(is_equal_approx(c.reach_scale(),SIZE),"Default weapon uses the shared multiplier: %d"%id)
		model.apply_native_pose(0x68,.1)
		var raw=model.sampler.sample_source(0x68,.1);var enlarged=model.scaled_source_pose(0x68,.1)
		var weapons=model.KUNAI if id==16 else model.KATANA+["0x9007bb8"]
		check(raw.keys().all(func(pointer):return pointer in weapons or raw[pointer].is_equal_approx(enlarged[pointer])),"Enlargement preserves every body and hair part: %d"%id)
		camera.global_position=ORIGIN+Vector3(9,6,-14);camera.look_at(ORIGIN+Vector3(0,2,0))
		await capture("sasuke-kunai" if id==16 else "yae-katana")
		if id==17:
			model.apply_native_pose(0x69,.14)
			camera.global_position=ORIGIN+Vector3(-14,7,-6);camera.look_at(ORIGIN+Vector3(0,2,0))
			await capture("yae-cut")
		camera.global_position=ORIGIN+Vector3(11,10,18);camera.look_at(ORIGIN+Vector3(0,3,-3))
		for kind in (["bomb","ice","hail"] if id==16 else ["bazooka","lock_on"]):
			c.mode=kind;c.action_id=0xa5 if id==17 else 0x70;c.elapsed=.3
			if id==17:model.apply_native_pose(c.action_id,c.elapsed)
			c._release_projectiles()
			var shots=get_nodes_in_group("sasuke_projectiles" if id==16 else "yae_projectiles")
			check(not shots.is_empty(),"Launch "+kind)
			for i in shots.size():
				var shot=shots[i];shot.set_physics_process(false)
				check(shot.ornament.scale.is_equal_approx(Vector3.ONE*SIZE),"Projectile visual uses shared size: "+kind)
				check(is_equal_approx(shot.blast_radius,(2.3 if id==16 else 1.25)*SIZE),"Blast matches enlarged projectile: "+kind)
				shot.position=ORIGIN+Vector3((i-1)*3,3,-5)
			await capture(kind)
			for shot in shots:shot.retire()
			c.cancel()
		p.buildings_broken=50;p.scale=Vector3.ONE*p.growth_multiplier()
		c.mode="ice" if id==16 else "bazooka";c.action_id=0xa5 if id==17 else 0x70;c.elapsed=.3;c._release_projectiles()
		var grown=get_nodes_in_group("sasuke_projectiles" if id==16 else "yae_projectiles")
		p.select_character(1)
		for shot in grown:
			check(shot.ornament.scale.is_equal_approx(Vector3.ONE*SIZE*2),"Growth snapshots size and survives character switching")
			shot.retire()
		p.buildings_broken=0;p.scale=Vector3.ONE;p.select_character(id);p.set_physics_process(false)
		if id==17:
			var wall=StaticBody3D.new();wall.collision_layer=1
			var shape=CollisionShape3D.new();var box=BoxShape3D.new();box.size=Vector3(8,8,.2);shape.shape=box;wall.add_child(shape)
			game.add_child(wall);wall.position=ORIGIN+Vector3(0,3,-1);await physics_frame
			c.mode="bazooka";c.action_id=0xa5;c.elapsed=.3;c._release_projectiles()
			for shot in get_nodes_in_group("yae_projectiles"):
				check(shot.position.z>wall.position.z,"Enlarged barrel cannot launch through nearby cover")
				shot.retire()
			wall.free()
		# Launch snapshots size; reusing a lease must neither compound nor retain it.
		var nodes=Performance.get_monitor(Performance.OBJECT_NODE_COUNT)
		var resources=Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)
		for repeat in 20:
			c.mode="ice" if id==16 else "bazooka";c.action_id=0xa5 if id==17 else 0x70;c.elapsed=.3
			c._release_projectiles()
			for shot in get_nodes_in_group("sasuke_projectiles" if id==16 else "yae_projectiles"):
				check(shot.ornament.scale.is_equal_approx(Vector3.ONE*SIZE),"Reused scale stays at the shared size")
				shot.retire()
		check(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)==nodes and Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)==resources,"Repeated enlarged shots reuse nodes and resources: %d"%id)
		c.cancel()
	p.select_character(13);p.set_physics_process(false);p.position=ORIGIN
	for i in 3:p.velocity=Vector3.DOWN*20;p.move_and_slide()
	p.velocity=Vector3.ZERO;p.facing=Vector3.FORWARD
	var c=p.active_ability;var skill=c.assimilation;var unit=p.model.rig_visual.global_basis.get_scale().x*.01
	skill.set_physics_process(false)
	for kind in ["fence","homing","grenade","three_way"]:
		skill.release_shot(kind);skill.set_physics_process(false)
		for shot in skill.shots:
			if not shot.active:continue
			check(is_equal_approx(shot.unit,unit) and is_equal_approx(shot.effect_unit,unit*SIZE),"Musashi effect grows without changing travel units: "+kind)
			shot.age=12;skill._pose(shot)
			shot.node.position=ORIGIN+Vector3(0,3,-6)
		await capture("musashi-"+kind)
		if kind in ["homing","grenade"]:
			for shot in skill.shots:
				if shot.active:skill._explode(shot);skill._shot_tick(shot)
			await capture("musashi-"+kind+"-explosion")
		for shot in skill.shots:if shot.active:skill._retire(shot)
	c.start_counter();c.tick(11.0/30.0)
	var effect=p.model.rotation_effect
	check(effect.vortices.size()==2 and effect.spawn_transform.basis.get_scale().is_equal_approx(p.model.rig_visual.global_basis.get_scale()*SIZE),"Mighty Strike vortex and ring use shared size")
	effect.advance(.2);p.model.animate(0,0,true,0,0,true,0,false)
	await capture("musashi-mighty-strike")
	c.cancel();c.start_rotation()
	for i in 12:c.tick(1.0/30.0);p.model.animate(1.0/30.0,0,true,0,0,true,0,false)
	check(c.lumina_scale_factor()>SIZE,"Lumina Rotation enlarges the sword with its trail")
	await capture("musashi-rotation")
	c.cancel();skill.start(3);c.source_motion_tick();c.source_motion_tick();skill.set_physics_process(false);p.model.animate(0,0,false,0,0,false,0,false)
	check(skill.ghosts.any(func(g):return g.visible and is_equal_approx(g.scale.x,unit*SIZE)),"D-Kick afterimage uses enlarged skill scale")
	await capture("musashi-dkick")
	c.cancel();skill.set_physics_process(false)
	# All four shot families overlap repeatedly using the same prepared slots.
	var nodes=Performance.get_monitor(Performance.OBJECT_NODE_COUNT)
	var resources=Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)
	for repeat in 20:
		for kind in ["fence","homing","grenade","three_way"]:skill.release_shot(kind)
		for shot in skill.shots:if shot.active:skill._retire(shot)
	check(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)==nodes and Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)==resources,"Overlapping enlarged Musashi spells reuse nodes and resources")
	check(skill.shots.all(func(s):return not s.active and s.target==null and s.ticket.is_empty() and s.hits.is_empty()),"Scaled spells clear targets, tickets and victims")
	skill.set_physics_process(false)
	p.select_character(1)
	var borrowed=preload("res://scripts/spells/spell_instance.gd").new();p.add_child(borrowed)
	borrowed.setup(p,preload("res://scripts/spells/spell_catalog.gd").all()["musashi/counter"])
	var borrowed_skill=borrowed.controller.assimilation
	borrowed_skill.release_shot("three_way");borrowed_skill.set_physics_process(false)
	for shot in borrowed_skill.shots:
		if shot.active:
			check(is_equal_approx(shot.effect_unit,unit*SIZE),"Borrowed Musashi spell retains its source model's effect size")
			check(is_equal_approx(shot.unit,.018),"Borrowing the enlarged effect preserves the wearer's existing travel units")
	borrowed.free()
	print("RECOVERED_SKILL_SCALE_TEST checks=",checks," failures=",failures," pool_misses=",pool.misses)
	game.sound_library.cancel();game.music.stop();game.move_audio.stop();game.queue_free();game=null;current_scene=null
	await frames();quit(1 if failures else 0)
