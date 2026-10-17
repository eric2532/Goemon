extends SceneTree
var game
var checks=0
var failures=0
const Contact=preload("res://scripts/forest/forest_enemy_contact.gd")
const Roles=preload("res://scripts/forest/forest_enemy_roles.gd")
func _initialize():
	create_timer(60).timeout.connect(func():printerr("FAIL: contact review timeout");quit(1))
	run.call_deferred()
func frames(count: int=2):
	for i in range(count):await physics_frame
func check(ok: bool,message: String):
	checks+=1
	if not ok:failures+=1;printerr("FAIL: "+message)
func run():
	game=load("res://scenes/forest_shrine.tscn").instantiate();root.add_child(game);current_scene=game;await frames()
	game.start_wave();game.model.waves.pending=0;game.model.waves.spawn_clock=10000
	game.set_physics_process(false);game.player.set_physics_process(false)
	var point=Vector3(0,0,70)
	var data=game.model.waves.spawn_enemy(2,point)
	data.action="walk";data.walk_phase=PI*1.3;data.velocity=Vector3(.75,0,0);data.attack_progress=0.0
	game.sync_enemies();var actor=game.actors[data.id];actor.set_physics_process(false);actor._sync_fitted_pose()
	var frozen_surface: Vector3=actor.combat_contact_point(point+Vector3(-4.65,1,-6))
	actor.freeze_for(2);game.model.waves.tick_enemy(data,.1,game.player.position);actor._physics_process(.016)
	var from=point+Vector3(-4.65,1,-6)
	game.model.workforce.arrows[888]={"id":888,"from":from,"pos":from,"target":data.id,"age":0.0}
	game.model.workforce.tick_arrows(.1)
	var impacts: Array=game.model.events.filter(func(event):return event.kind=="arrow_impact" and event.id==888)
	check(impacts.size()==1,"A tower arrow reaches the frozen walking foot")
	if impacts.size()==1:
		check(impacts[0].to.distance_to(frozen_surface)<.002,"Model-owned frozen arrow hits the retained rendered walking-foot surface")
		check(actor.combat_segment_hit(impacts[0].to,impacts[0].to,.002),"Frozen tower impact lies inside the actual posed actor foot collider")
	# Freeze before an actor's first presentation update must retain its authored phase.
	var first=game.model.waves.spawn_enemy(2,Vector3(0,0,120))
	first.action="walk";first.walk_phase=PI*1.3;first.velocity=Vector3(.75,0,0)
	var first_from: Vector3=first.pos+Vector3(-4.65,1,-6)
	var expected=Roles.hurt_point(first,first_from)
	first.frozen=2.0;game.model.waves.tick_enemy(first,.1,game.player.position);game.sync_enemies()
	var first_actor=game.actors[first.id];first_actor.set_physics_process(false);first_actor._physics_process(.016)
	check(first_actor.combat_contact_point(first_from).distance_to(expected)<.002,"Freeze before presentation keeps the same physical walking-foot surface")
	game.model.update_vision(first.pos);game.crowd._process(0)
	var pose: Transform3D=game.crowd.part_pose("foot_l",game.crowd._poses[first.id])
	check(pose.origin.distance_to(Vector3(0,.566312,.426))<.002,"Renderer consumes authoritative first-freeze raised-foot pose")
	# A real thin terrain wall separates the chain's path from its target.
	game.crowd.set_process(false)
	var victim=Ninja.new();victim.game=game;victim.training_dummy=true;victim.practice=true
	victim.position=Vector3(500.6,0,500);game.add_child(victim);victim.set_physics_process(false)
	victim.hp=1000;victim.max_hp=1000;game.enemies.append(victim)
	var wall=StaticBody3D.new();wall.collision_layer=1;wall.collision_mask=0
	var shape=CollisionShape3D.new();var box=BoxShape3D.new();box.size=Vector3(.1,4,10);shape.shape=box;wall.add_child(shape)
	wall.position=Vector3(500.3,2,500);game.add_child(wall);await frames()
	var chain=game.player.chain_pipe_combat;chain.damage=60;chain.direction=Vector3.BACK;chain.struck.clear()
	var a=Vector3(500,1.1,495);var b=Vector3(500,1.1,505)
	chain.hit_path(a,b)
	check(victim.hp==1000,"Chain cannot hit a nearby legacy Ninja across a thin terrain wall")
	wall.collision_layer=0;await frames();chain.struck.clear();chain.hit_path(a,b)
	check(victim.hp<1000,"The same chain path hits when the obstruction is removed")
	# The two callers keep their original root+1.5 boss/root+1.1 other centers.
	game.player.select_character(2)
	var beam=load("res://assets/vfx/fire_beam/fire_beam.gd").new();beam.game=game;beam.hero=game.player;beam.balance=MusashiBalance.new()
	beam.balance.beam_radius=.01;game.add_child(beam);beam.set_physics_process(false);beam.direction=Vector3.BACK;beam.length_now=10
	victim.position=Vector3(500,0,500)
	for kind in ["boss","elite","giant"]:
		victim.boss=kind=="boss";victim.island_elite=kind=="elite";victim.ground_giant=kind=="giant"
		victim.body_radius=.03 if kind=="boss" else (.15 if kind=="elite" else 3.1)
		var low=.8 if kind=="boss" else (.3 if kind=="elite" else 1.1)
		victim.hp=1000;chain.struck.clear();chain.hit_path(Vector3(500,low,495),Vector3(500,low,505))
		check(victim.hp<1000,"Chain retains original %s hurt height"%kind)
		victim.hp=1000;beam.position=Vector3(500,1.5 if kind=="boss" else 1.1,495);beam.damage_tick()
		check(victim.hp<1000,"Edo beam retains original %s hurt height"%kind)
	victim.position.z=506;victim.hp=1000;beam.position=Vector3(500,1.1,495);beam.damage_tick()
	check(victim.hp==1000,"Legacy Edo beam rejects a giant center beyond its original segment end")
	beam.stop();game.show_pause()
	if DisplayServer.get_name()!="headless":
		print("FOREST_ENEMY_CONTACT_REVIEW_RESULT checks=%d failures=%d"%[checks,failures])
		await game.quit_clean();quit(1 if failures else 0);return
	game.queue_free();paused=false;await frames();await create_timer(.35).timeout
	print("FOREST_ENEMY_CONTACT_REVIEW_RESULT checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)
