extends SceneTree
## Real-scene regressions for ignored hits, stale windups, sliding strikes and
## combo targets pushed out of reach. No substitute combat actors or movement.
var game
var checks=0
var failures=0
const ORIGIN=Vector3(0,.05,70)
func _initialize():
	create_timer(90).timeout.connect(func():printerr("FAIL: engagement timeout");quit(1))
	run.call_deferred()
func check(ok: bool,message: String):
	checks+=1
	print("PASS: " if ok else "FAIL: ",message)
	if not ok:failures+=1
func frames(n: int=2):
	for i in n:await physics_frame
func fresh(hero_id: int=7):
	for actor in game.actors.values():
		if is_instance_valid(actor):actor.queue_free()
	game.actors.clear();game.enemies.clear();game.model.enemies.clear();game.model.waves.projectiles.clear();game.model.events.clear()
	await frames()
	game.player.select_character(hero_id);game.player.set_auto_attack(false)
	game.player.position=ORIGIN;game.player.velocity=Vector3.ZERO
	game.player.attack_chain.reset();game.model.hero_targetable=true
	game.player.smoke_mode=true;game.player.smoke_move=Vector2.ZERO
	game.model.update_vision(ORIGIN)
func target(variant: int=3):
	var data=game.model.waves.spawn_enemy(variant,ORIGIN+Vector3(0,0,-3))
	data.hp=10000.0;data.max_hp=10000.0
	game.sync_enemies();var actor=game.actors[data.id];actor.set_physics_process(false)
	return actor
func hit(actor,heavy: bool=false,tower: bool=false):
	actor.take_hit(1,Vector3.FORWARD,heavy,{"tower":tower})
func run():
	game=load("res://scenes/forest_shrine.tscn").instantiate();root.add_child(game);current_scene=game
	await frames(3);game.start_wave();game.model.waves.pending=0;game.model.waves.spawn_clock=10000
	game.set_physics_process(false);game.player.set_physics_process(false);game.camera_rig.set_process(false)
	game.tuning.invincible=true;game.tuning.critical_chance=0.0
	for variant in [0,1,3]:
		await fresh();var actor=target(variant);var e=game.model.enemies[actor.forest_id]
		e.action="windup";e.action_left=.01;e.target_kind="building";e.target_id=1;e.strike_kind="building";e.strike_id=1;e.attack=true;e.attack_progress=.9
		hit(actor)
		check(e.action=="walk" and not e.attack and e.attack_progress==0,"Hit cancels the pending strike for ordinary role %d"%variant)
		game.model.waves.choose_target(e,ORIGIN)
		check(e.target_kind=="hero","Hero hit wins over the ordinary role's objective (%d)"%variant)
		var start: Vector3=e.pos
		for i in range(15):game.model.waves.tick_enemy(e,1.0/60,ORIGIN)
		check(start.distance_to(e.pos)<.4,"Normal-hit displacement keeps role %d in combo reach"%variant)
		check(e.stun>0 and e.velocity.length()<.3,"Role %d remains staggered through most of a quarter second"%variant)
		for i in range(30):game.model.waves.tick_enemy(e,1.0/60,ORIGIN)
		check(e.stun==0 and (absf(e.facing)>.2 or e.action!="walk"),"Role %d resumes acting after its short stagger"%variant)
		if variant==3:
			for i in range(120):game.model.waves.tick_enemy(e,1.0/60,ORIGIN)
			hit(actor);game.model.waves.tick_enemy(e,.5,ORIGIN);game.model.waves.choose_target(e,ORIGIN)
			check(e.target_kind=="hero","Repeated hits refresh the retaliation window")
			for i in range(300):game.model.waves.tick_enemy(e,1.0/60,ORIGIN)
			game.model.waves.choose_target(e,ORIGIN)
			check(e.target_kind=="building","Lantern returns to its shrine objective after retaliation expires")
			game.model.events.clear();hit(actor);game.model.hero_targetable=false
			for i in range(90):game.model.waves.tick_enemy(e,1.0/60,ORIGIN)
			check(e.target_kind=="building" and not game.model.events.any(func(event):return event.kind=="hero_hit"),"Retaliation releases an untargetable hero")
	await fresh();var actor=target();var e=game.model.enemies[actor.forest_id]
	hit(actor,false,true);game.model.waves.choose_target(e,ORIGIN)
	check(e.target_kind=="building","Tower damage never draws enemies toward the hero")
	actor.take_hit(0,Vector3.FORWARD,false);game.model.waves.choose_target(e,ORIGIN)
	check(e.target_kind=="building","Zero-damage hits never provoke retaliation")
	await fresh();actor=target(2);e=game.model.enemies[actor.forest_id]
	e.action="windup";e.action_left=.8;e.attack=true
	hit(actor);game.model.waves.choose_target(e,ORIGIN)
	check(e.target_kind=="building" and e.action=="windup" and e.stun==0,"Daruma retains siege commitment and interruption resistance")
	await fresh();actor=target();e=game.model.enemies[actor.forest_id];hit(actor,true)
	var start: Vector3=e.pos
	for i in range(24):game.model.waves.tick_enemy(e,1.0/60,ORIGIN)
	check(start.distance_to(e.pos)<.6,"Heavy combo hits also keep the target close")
	# The shared visible pose and fitted hull must both recoil, then recover.
	await fresh();actor=target();e=game.model.enemies[actor.forest_id];hit(actor)
	if "--visual" in OS.get_cmdline_user_args():
		# Capture the actual crowd geometry, under the normal Forest lighting.
		game.camera_rig.camera.position=ORIGIN+Vector3(9,6,9)
		game.camera_rig.camera.look_at(ORIGIN+Vector3(0,2,-1.5))
		game.world.update_fog()
		await capture("contact")
	game.model.waves.tick_enemy(e,.05,ORIGIN);game.crowd._process(.016)
	var posed=game.crowd.part_pose("body",game.crowd._poses[e.id])
	check(not posed.basis.is_equal_approx(Basis.IDENTITY),"A real hit produces recoil in the shared crowd renderer")
	check(game.crowd.part_pose("body",e).is_equal_approx(posed),"Visible recoil matches the authoritative fitted contact pose")
	if "--visual" in OS.get_cmdline_user_args():await capture("recoil")
	for i in range(30):game.model.waves.tick_enemy(e,1.0/60,ORIGIN)
	e.velocity=Vector3.ZERO;e.walk_phase=0;game.crowd._process(.016)
	check(game.crowd.part_pose("body",game.crowd._poses[e.id]).is_equal_approx(Transform3D.IDENTITY),"Recoil settles without a lingering lean")
	# Retaliating archers must actually hit the hero, and respect evasion/cover.
	for mode in ["hit","dodge","untargetable","cover"]:
		await fresh();actor=target(1);e=game.model.enemies[actor.forest_id]
		e.pos=ORIGIN+Vector3(0,0,-12)
		var arrow_target=ORIGIN+Vector3.UP*1.3
		game.model.waves.arrows.launch(game.model.waves.projectiles,e,"hero",0,arrow_target)
		var hero: Vector3=ORIGIN+Vector3.RIGHT*4 if mode=="dodge" else ORIGIN
		if mode=="untargetable":game.model.hero_targetable=false
		if mode=="cover":game.model.trees[Vector2i(0,11)]=1;game.model.rebuild_navigation()
		for i in range(40):game.model.waves.tick(1.0/60,hero)
		check(game.model.events.any(func(event):return event.kind=="hero_hit")== (mode=="hit"),"Retaliation arrow contact: "+mode)
		if mode=="hit":check(game.model.events.any(func(event):return event.kind=="hero_hit" and event.get("projectile",false)),"Archer damage keeps projectile attribution for hero defenses")
		if mode=="cover":game.model.trees.clear();game.model.rebuild_navigation()
	# Removing strike planting must permit displacement here. Ranged/airborne
	# controls must keep travelling; freezing the whole animation fails recovery.
	for id in [3,4,5,7,8,9,11,12,10]:
		await fresh(id);var combat=game.player.active_ability
		for i in range(20):combat._move_body(1.0/60)
		check(game.player.is_on_floor(),"Movement fixture is grounded (%d)"%id)
		combat.attack();var a: Dictionary=combat.player.attack
		a.time=a.contact;combat.move_input=Vector3.RIGHT;combat.locomotion_velocity=Vector3.RIGHT*15;combat.player.vel=Vector3.RIGHT*4
		start=game.player.position;combat._move_body(1.0/60)
		var distance=Vector2(game.player.position.x-start.x,game.player.position.z-start.z).length()
		check(distance<.015 if id!=10 else distance>.05,"Only melee strikes plant the feet at contact (%d)"%id)
		if id!=10:
			for offset in [-.045,.08]:
				a.time=maxf(0,a.contact+offset);combat.move_input=Vector3.RIGHT
				var walk: float=game.hero_tuning("walk_speed")*game.player.progression.movement_multiplier()
				combat.locomotion_velocity=Vector3.RIGHT*walk;combat.player.vel=Vector3.ZERO
				combat._move_body(1.0/60)
				check(game.player.velocity.x>walk*.93,"Melee movement is free just outside the short contact plant (%d, %.3f)"%[id,offset])
			var sample=combat.player.duplicate();sample.attack=a.duplicate();sample.attack.time=a.contact
			sample.meleeVisualScale=a.meleeVisualScale
			combat.visual_actor.animate_pose(sample,0,combat.time,0)
			var weapon=combat.visual_actor.joints.Weapon_Cutlass.node
			var tip: Vector3=weapon.to_global(combat.visual_actor.WEAPON_AXES[combat.class_id])
			var origin: Vector3=game.player.global_position
			var visible_reach=maxf(Vector2(tip.x-origin.x,tip.z-origin.z).length(),Vector2(weapon.global_position.x-origin.x,weapon.global_position.z-origin.z).length())+.12*game.player.growth_multiplier()
			check(absf(a.reach-visible_reach*1.12)<.025,"Melee contact extends twelve percent beyond the prior fitted reach (%d)"%id)
			if id==7:
				for extension in [1.06,1.20]:
					var victim=target(0);var data: Dictionary=game.model.enemies[victim.forest_id]
					var direction: Vector3=combat.front(a.angle)
					victim.position=origin+direction*(visible_reach*extension+1.0)
					for i in range(5):
						data.pos=victim.position;victim._sync_fitted_pose()
						var surface: Vector3=victim.combat_contact_point(origin+Vector3.UP)
						victim.position+=direction*(visible_reach*extension-Vector2(surface.x-origin.x,surface.z-origin.z).length())
					data.pos=victim.position;victim._sync_fitted_pose();game.model.update_vision(origin)
					combat.player.pos=origin;a.time=a.contact-.001;a.hit=false
					combat.tick(.002,false)
					check(data.hp<10000 if extension<1.12 else data.hp==10000,"Actual Knight strike respects the expanded hit boundary (%.2f)"%extension)
		a.time=a.duration-.015;combat.move_input=Vector3.RIGHT;start=game.player.position;combat._move_body(1.0/60)
		check(game.player.position.x>start.x+.01,"Movement resumes during attack recovery (%d)"%id)
		game.player.position.y+=3;game.player.velocity=Vector3.UP;combat._move_body(1.0/60)
		a.time=a.contact;combat.locomotion_velocity=Vector3.RIGHT*10;start=game.player.position;combat._move_body(1.0/60)
		check(game.player.position.x>start.x+.05,"Air attacks retain horizontal steering (%d)"%id)
	await fresh(1)
	for i in range(20):game.player._physics_process(1.0/60)
	game.player.start_attack(false,1);game.player.attack_left=game.player.attack_duration*(1.0-game.player.attack_contact_phase());game.player.smoke_move=Vector2.RIGHT;game.player.velocity.x=15
	start=game.player.position;game.player._physics_process(1.0/60)
	check(absf(game.player.position.x-start.x)<.015 and absf(game.player.position.z-start.z)<.015,"Goemon's pipe strike plants at contact despite input and attack impulse")
	game.player.attack_left=game.player.attack_duration*.05;start=game.player.position;game.player._physics_process(1.0/60)
	check(game.player.position.x>start.x+.01,"Goemon regains movement during pipe recovery")
	for offset in [-.045,.08]:
		game.player.attack_left=game.player.attack_duration-(game.player.attack_duration*game.player.attack_contact_phase()+offset)
		var walk: float=game.hero_tuning("walk_speed")*game.player.movement_multiplier()
		game.player.velocity=Vector3.RIGHT*walk
		game.player._physics_process(1.0/60)
		check(game.player.velocity.x>walk*.93,"Goemon moves freely outside the short contact plant (%.3f)"%offset)
	var original_reach=minf(HeroModel.WeaponProportions.SCALE*game.hero_tuning("pipe_range")*game.player.attack_reach_multiplier(),game.player.model.visible_pipe_reach()+.12*game.player.growth_multiplier())
	check(absf(game.player.melee_strike_reach()-original_reach*1.12)<.001,"Goemon gains twelve percent reach after his visible-weapon limit")
	game.player.combo=1;game.player.attack_left=.001;game.player.velocity=Vector3(10,0,0)
	game.player.attack_chain.count=1;game.player.attack_chain.remaining=1.75
	start=game.player.position;game.player._physics_process(1.0/60)
	check(game.player.combo==2 and game.player.hit_done and game.player.position.distance_to(start)<.015,"An energized combo starting directly at contact still plants before body movement")
	game.player.attack_left=game.player.attack_duration*(1.0-game.player.attack_contact_phase())
	game.player.jump_windup=.005;game.player.jump_buffer=0;game.player.velocity=Vector3(10,0,0)
	start=game.player.position;game.player._physics_process(1.0/60)
	check(game.player.velocity.y>0 and game.player.position.x>start.x+.05,"A jump taking off during pipe contact preserves horizontal momentum")
	game.queue_free();await frames();await create_timer(.3).timeout
	print("FOREST_MELEE_ENGAGEMENT_RESULT checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)
func capture(label: String):
	for i in range(3):await process_frame
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("/tmp/sonic-melee-render")
	check(root.get_texture().get_image().save_png("/tmp/sonic-melee-render/"+label+".png")==OK,"Rendered engagement capture saves: "+label)
