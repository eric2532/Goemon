extends "res://tests/forest-shrine/hidden_melee_assist_test.gd"
## Exercise real hit acceptance and CharacterBody movement, including assist gaps.
var config_path="user://ninja-hit-drift-%d.cfg"%OS.get_process_id()
func distance_from(start: Vector3)->float:
	return Vector2(game.player.position.x-start.x,game.player.position.z-start.z).length()
func place_surface(data: Dictionary,distance: float):
	var actor=game.actors[data.id]
	for i in range(6):
		var contact: Vector3=actor.combat_contact_point(game.player.position+Vector3.UP)
		actor.position.z+=game.player.position.z-distance-contact.z;data.pos=actor.position;actor._sync_fitted_pose()
	game.model.update_vision(game.player.position)
func primary(stage: int):
	var c=game.player.active_ability;c.combo=stage;c.combo_timer=1;c.attack();c.primary_held=false
func swing(c,seconds: float=.6):
	# CharacterBody integrates using the engine's fixed physics tick.
	for i in range(ceili(seconds*60)):c.physics_step(1.0/60)
func run():
	game=load("res://scenes/forest_shrine.tscn").instantiate();game.settings_path=config_path;root.add_child(game);current_scene=game
	await frames(3);game.start_wave();game.model.waves.spawn_clock=10000;game.model.waves.pending=0
	game.set_physics_process(false);game.player.set_physics_process(false);game.camera_rig.set_process(false)
	game.tuning.invincible=true;game.tuning.critical_chance=0;game.character_tuning={}
	for stage in range(3):
		await prepare(5);var c=game.player.active_ability;var start: Vector3=game.player.position
		primary(stage)
		check(c.player.vel.length()<.001,"Ninja stage %d has no forward launch before contact"%(stage+1))
		swing(c)
		check(distance_from(start)<.001,"Ninja stage %d stays in place when swinging at empty space"%(stage+1))
	# Being near a target is insufficient: approach assist cannot turn a miss into travel.
	await prepare(5);var c=game.player.active_ability;primary(0);var reach: float=c.player.attack.reach
	c.reset_run();c.player.pos=game.player.position;c.aim=game.player.position+Vector3.FORWARD*30
	var e=target(Vector3(0,0,-reach-2));place_surface(e,reach+.2)
	var start: Vector3=game.player.position;primary(0)
	check(game.player.melee_assist.target()!=null,"Out-of-reach fixture still acquires gentle aiming assistance")
	swing(c)
	check(e.hp==10000 and distance_from(start)<.001,"A nearby target outside weapon reach causes neither damage nor an approach step")
	var travel=[]
	for stage in range(3):
		await prepare(5);c=game.player.active_ability;e=target(Vector3(0,0,-2.6));start=game.player.position
		primary(stage);var a: Dictionary=c.player.attack
		while a.time+1.0/60<a.contact-.001:c.physics_step(1.0/60)
		check(distance_from(start)<.001 and e.hp==10000,"Connected stage %d remains planted until actual damage"%(stage+1))
		swing(c)
		var distance=distance_from(start);travel.append(distance)
		check(e.hp<10000 and game.player.attack_chain.count>0,"Stage %d registers real damage before drifting"%(stage+1))
		check(distance>.015 and distance<.3 and game.player.position.z<start.z,"Stage %d adds a small forward follow-through only after a hit (%.4fm, %s)"%[stage+1,distance,game.player.position-start])
		check(c.player.vel.length()<.01,"Stage %d drift settles without continuous sliding"%(stage+1))
	check(travel[2]>travel[0]*1.4,"Ninja finisher retains a stronger follow-through than the first cut")
	# More enemies in one swing must not multiply the step.
	await prepare(5);c=game.player.active_ability
	var first=target(Vector3(-.2,0,-2.6));var second=target(Vector3(.2,0,-2.6));start=game.player.position
	primary(0);swing(c)
	check(first.hp<10000 and second.hp<10000,"Multi-target fixture connects both enemies")
	check(absf(distance_from(start)-travel[0])<.015,"One swing gives one drift impulse even when hitting several enemies")
	for mode in ["fog","behind","cover"]:
		await prepare(5);c=game.player.active_ability;e=target(Vector3(0,0,-2.6));start=game.player.position
		var wall: StaticBody3D
		if mode=="fog":game.model.visible_cells.clear()
		elif mode=="behind":game.actors[e.id].position=game.player.position+Vector3.BACK*3;e.pos=game.actors[e.id].position;game.actors[e.id]._sync_fitted_pose()
		else:
			wall=StaticBody3D.new();wall.collision_layer=1;wall.collision_mask=0
			var shape=CollisionShape3D.new();var box=BoxShape3D.new();box.size=Vector3(8,6,.2);shape.shape=box;wall.add_child(shape);game.add_child(wall);wall.position=game.player.position+Vector3(0,1,-.6);await frames()
		primary(0);swing(c)
		check(e.hp==10000 and distance_from(start)<.001,"Rejected "+mode+" contact cannot enable drift")
		if is_instance_valid(wall):wall.queue_free();await frames()
	await prepare(5);c=game.player.active_ability;start=game.player.position;game.player.smoke_move=Vector2(0,-1)
	primary(0);swing(c,.25)
	check(distance_from(start)>.5,"Manual forward movement still works during a miss")
	await prepare(5);c=game.player.active_ability;start=game.player.position;c.action("flintlock");c.physics_step(.01)
	check(c.player.roll>0 and distance_from(start)>.1,"Ninja dash attack retains intentional movement without a hit")
	# A surviving immortal target still counts as a confirmed hit.
	await prepare(5);c=game.player.active_ability;var dummy=game.training_dummy
	game.player.position=dummy.home+Vector3(0,.1,2);c.player.pos=game.player.position;c.aim=dummy.home;game.enemies.append(dummy)
	game.model.update_vision(game.player.position);start=game.player.position;primary(0);swing(c)
	check(distance_from(start)>.015 and dummy.hp==dummy.max_hp and not dummy.dead,"Infinite-health dummy confirms drift without needing to lose health")
	# Legitimate level, pickup and chain bonuses can retire a swing while planted.
	for links in [6,11]:
		await prepare(5);c=game.player.active_ability
		game.player.progression.level=99;game.player.powerups.attack_speed=20;game.player.attack_speed_stacks=4;game.player.attack_chain.count=links
		e=target(Vector3(0,0,-2.6));start=game.player.position;primary(0);swing(c,.5)
		check(e.hp<10000 and distance_from(start)>.015 and distance_from(start)<.3,"A confirmed boosted hit preserves one small step across normal retirement (%d links)"%links)
	await prepare(5);c=game.player.active_ability;game.player.attack_chain.count=6
	e=target(Vector3(0,0,-2.6));primary(0)
	c.tick(1.0/60,false);c.tick(1.0/60,false)
	check(e.hp<10000 and c.player.attack==null,"Cancellation fixture has a confirmed boosted hit waiting after normal retirement")
	c.cancel(true);start=game.player.position;swing(c,.3)
	check(distance_from(start)<.001,"Cancellation discards a completed hit's unconsumed step")
	game.sound_library.cancel();game.music.stop()
	for voice in game.voices:voice.stop()
	game.queue_free();paused=false;await frames(3);await create_timer(.35).timeout
	DirAccess.remove_absolute(ProjectSettings.globalize_path(config_path))
	print("NINJA_HIT_DRIFT_RESULT checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)
