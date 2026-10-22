extends "res://tests/forest-shrine/hidden_melee_assist_test.gd"
## Real Forest actors and primary attacks: memory must survive a natural combo
## pause and modest drift, without widening acquisition or granting extra travel.
func place_contact(data: Dictionary,offset: Vector3):
	var actor=game.actors[data.id]
	for i in 6:
		var p: Vector3=actor.combat_contact_point(game.player.position+Vector3.UP)
		actor.position.x+=game.player.position.x+offset.x-p.x
		actor.position.z+=game.player.position.z+offset.z-p.z
		data.pos=actor.position;actor._sync_fitted_pose()
	game.model.update_vision(game.player.position)
func finish_primary():
	game.player.active_ability.tick(.6,false)
func idle_memory(seconds: float):
	for i in int(round(seconds*100)):
		game.player.melee_assist.tick(game.player,.01)
func run():
	game=load("res://scenes/forest_shrine.tscn").instantiate();root.add_child(game);current_scene=game
	await frames(3);game.start_wave();game.model.waves.spawn_clock=10000;game.model.waves.pending=0
	game.set_physics_process(false);game.player.set_physics_process(false);game.camera_rig.set_process(false)
	game.tuning.invincible=true;game.tuning.critical_chance=0.0
	await prepare(7);var original=target(Vector3(.9,0,-2.6));begin(7);finish_primary()
	idle_memory(1.0)
	check(game.player.melee_assist.target()==game.actors[original.id],"Original enemy survives a one-second pause after contact")
	target(Vector3(-.2,0,-2.1));begin(7)
	check(game.player.melee_assist.target()==game.actors[original.id],"Next real primary retains the remembered enemy over a closer newcomer")
	finish_primary();idle_memory(1.2)
	check(game.player.melee_assist.target()==null,"Memory expires after the longer combo window without a new primary")
	for side in [-1.0,1.0]:
		await prepare(7);original=target(Vector3(side*.9,0,-2.6));begin(7);finish_primary()
		# Fitted contact at 55 degrees: outside acquisition, inside retention.
		place_contact(original,Vector3(side*2.13,0,-1.49));idle_memory(.1)
		check(game.player.melee_assist.target()==game.actors[original.id],"A remembered enemy may drift to 55 degrees (%s)"%side)
		target(Vector3(-side*.2,0,-2.1));begin(7);step(7,4)
		check(game.player.melee_assist.target()==game.actors[original.id],"A moved enemy keeps priority on the next primary (%s)"%side)
		check(absf(wrapf(angle(7)-PI,-PI,PI))<=deg_to_rad(25)+.001,"Retention still obeys the gentle correction cap (%s)"%side)
		await prepare(7);var outside=target(Vector3(side*2.13,0,-1.49));place_contact(outside,Vector3(side*2.13,0,-1.49));begin(7)
		check(game.player.melee_assist.target()==null,"A fresh primary cannot acquire the wider retention cone (%s)"%side)
	await prepare(7);original=target(Vector3(.9,0,-2.6));begin(7);finish_primary()
	var reach: float=game.player.melee_assist.reach
	place_contact(original,Vector3(0,0,-reach-.55));idle_memory(.1)
	check(game.player.melee_assist.target()==game.actors[original.id],"Memory tolerates a small retreat beyond the acquisition distance")
	begin(7);var start: Vector3=game.player.position;var hp: float=original.hp
	var travel=Vector3.ZERO
	for i in 12:travel+=game.player.melee_assist.motion(game.player,.01)*.01
	check(travel.length()<.001,"Remembering a target beyond the approach range grants no extra lunge")
	check(game.player.melee_assist.target()==game.actors[original.id],"Skipping an out-of-range lunge preserves combo memory")
	finish_primary()
	check(original.hp==hp and game.player.position==start,"Remembered out-of-range enemy receives no expanded damage reach")
	await prepare(7);var distant=target(Vector3(0,0,-reach-1));place_contact(distant,Vector3(0,0,-reach-.55));begin(7)
	check(game.player.melee_assist.target()==null,"Fresh primary cannot acquire the extra memory distance")
	for offset in [Vector3(2.4,0,-.8),Vector3(0,0,-20)]:
		await prepare(7);original=target(Vector3(.9,0,-2.6));begin(7);finish_primary()
		place_contact(original,offset);idle_memory(.01)
		check(game.player.melee_assist.target()==null,"Memory releases an enemy outside the retention cone or distance (%s)"%offset)
	for mode in ["aim","pitch","retreat","dodge"]:
		await prepare(7);original=target(Vector3(.9,0,-2.6));begin(7);step(7)
		match mode:
			"aim":game.camera_rig.yaw=deg_to_rad(23)
			"pitch":game.camera_rig.pitch+=deg_to_rad(23)
			"retreat":game.player.smoke_move=Vector2(0,1)
			"dodge":game.player.active_ability.standard_evade()
		game.player._physics_process(.01)
		check(game.player.melee_assist.target()==null,"Sticky combo still releases immediately for "+mode)
		if mode=="aim":check(absf(wrapf(angle(7)-(PI+deg_to_rad(23)),-PI,PI))<.05,"Aim-away still hands the active swing back to manual facing")
	game.queue_free();paused=false;await frames(3);await create_timer(.35).timeout
	print("FOREST_STICKY_COMBO_RESULT checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)
