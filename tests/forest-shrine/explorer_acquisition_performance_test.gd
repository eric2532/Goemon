extends "res://tests/forest-shrine/explorer_close_assist_test.gd"
## Removing Explorer's broadphase must query all 240 fitted hulls and fail.
## The counting subclass retains actual Forest bounds, geometry and contact.
class CountedRaider extends "res://scripts/forest/forest_raider.gd":
	var contact_queries=0
	func combat_contact_point(point: Vector3)->Vector3:
		contact_queries+=1
		return super.combat_contact_point(point)
func run():
	game=load("res://scenes/forest_shrine.tscn").instantiate();root.add_child(game);current_scene=game
	await frames(3);game.start_wave();game.model.waves.spawn_clock=10000;game.model.waves.pending=0
	game.set_physics_process(false);game.player.set_physics_process(false);game.camera_rig.set_process(false)
	await fresh()
	var actors: Array=[]
	for i in 240:
		var position=ORIGIN+(Vector3(1.25,0,-2.6) if i==0 else Vector3(12+(i%30)*2,0,-4-floori(i/30.0)*3))
		var data={"id":10000+i,"variant":0 if i==0 else 3,"pos":position,"hp":10000.0,"max_hp":10000.0,"velocity":Vector3.ZERO,"stun":100.0,"attack":false,"clock":0.0,"facing":0.0,"action":"walk","action_left":0.0,"attack_progress":0.0,"walk_phase":0.0}
		game.model.enemies[data.id]=data
		var actor=CountedRaider.new();actor.game=game;actor.forest_id=data.id;actor.variant=data.variant;actor.swarm=true;actor.position=position
		game.add_child(actor);actor.set_physics_process(false);game.actors[data.id]=actor;game.enemies.append(actor);actors.append(actor)
		game.model.visible_cells[game.model.cell_of(position)]=true
	for actor in actors:actor.contact_queries=0
	var combat=game.player.active_ability;combat.aim=ORIGIN+Vector3.FORWARD*20
	combat.attack()
	var queries=0
	for actor in actors:queries+=actor.contact_queries
	print("EXPLORER_240_ACQUISITION_NARROW_CONTACTS ",queries)
	check(queries>=1 and queries<=2,"Explorer acquisition excludes remote hulls before detailed contact in a 240-actor crowd")
	swing_steps(combat)
	check(actors[0].hp<10000,"Crowd broadphase retains the nearby off-angle target")
	var start=Time.get_ticks_usec()
	for i in 60:
		game.player.melee_assist.reset();game.player.melee_assist.begin(game.player,PI,2.75)
	print("EXPLORER_240_ACQUISITION_MEAN_MS ",(Time.get_ticks_usec()-start)/60000.0)
	game.queue_free();paused=false;await frames(3);await create_timer(.35).timeout
	print("FOREST_EXPLORER_ACQUISITION_PERFORMANCE_RESULT checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)
