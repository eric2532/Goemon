extends SceneTree
## Prepared physics snapshots must retain every exact fitted query while live
## authoritative model dictionaries continue to reflect mutations immediately.
const Contact=preload("res://scripts/forest/forest_enemy_contact.gd")
var checks=0
var failures=0
func _initialize():run.call_deferred()
func check(ok: bool,message: String):
	checks+=1
	if not ok:failures+=1;printerr("FAIL: "+message)
func same_segment(a: Dictionary,b: Dictionary)->bool:
	if a.is_empty() or b.is_empty():return a.is_empty()==b.is_empty()
	return absf(a.t-b.t)<.00001 and a.point.distance_to(b.point)<.0001
func run():
	var api: Variant=Contact.new()
	check(api.has_method("prepare"),"Exact enemy geometry supports explicit prepared snapshots")
	if not api.has_method("prepare"):finish();return
	for variant in range(5):
		for mode in ["idle","walk","windup","recoil","frozen"]:
			var data={"variant":variant,"pos":Vector3(17,2,-31),"facing":.73,"velocity":Vector3(1,0,2),"walk_phase":1.7,"action":"walk","attack_progress":0.0}
			if mode=="idle":data.walk_phase=0.0;data.velocity=Vector3.ZERO
			if mode=="windup":data.action="windup";data.attack_progress=.91;data.attack_point=data.pos+Vector3(5,2,-9)
			if mode=="recoil":data.hit_recoil=.21;data.hit_direction=Vector3.RIGHT;data.hit_heavy=true
			if mode=="frozen":
				data.frozen_pose=data.duplicate(true);data.frozen=2.0;data.walk_phase=4.0;data.attack_progress=1.0
			# Exercise world-anchored planted feet as well as procedural walk poses.
			if mode=="walk":data.walk_feet={"foot_l":Transform3D(Basis(Vector3.UP,.13),Vector3(.2,.1,-.4))}
			var prepared: Dictionary=api.prepare(data)
			var expected: AABB=Contact.bounds(data)
			check(api.bounds(data,prepared).is_equal_approx(expected),"Variant %d %s retains posed bounds"%[variant,mode])
			for point in [expected.get_center(),expected.position,expected.end,expected.get_center()+Vector3(30,4,-20),data.pos+Vector3(0,1,0)]:
				check(api.contact(data,point,prepared).distance_to(Contact.contact(data,point))<.0001,"Variant %d %s retains exact contact"%[variant,mode])
			for radius in [0.0,.1,1.2]:
				for line in [[expected.get_center()+Vector3(-40,0,0),expected.get_center()+Vector3(40,0,0)],[expected.get_center(),expected.get_center()],[expected.end+Vector3(1,1,1),expected.end+Vector3(5,1,1)],[expected.position,expected.end]]:
					check(same_segment(api.segment_contact(data,line[0],line[1],radius,prepared),Contact.segment_contact(data,line[0],line[1],radius)),"Variant %d %s retains segment radius %.1f"%[variant,mode,radius])
			# A prepared snapshot is explicit and detached: mutable data keeps its
			# fresh default semantics, including position, facing and nested feet.
			data.pos+=Vector3(60,0,0);data.facing+=1.2
			if data.has("walk_feet"):data.walk_feet.foot_l=Transform3D(Basis.IDENTITY,Vector3(5,5,5))
			check(api.bounds(data,prepared).is_equal_approx(expected),"Prepared snapshot ignores later source mutations")
			check(not Contact.bounds(data).is_equal_approx(expected),"Default live bounds follow source mutations")
			var refreshed: Dictionary=api.prepare(data)
			check(api.bounds(data,refreshed).is_equal_approx(Contact.bounds(data)),"Explicit refresh follows pose changes")
	# Hand-derived boss tangent/interior boundaries guard both routes against a
	# shared regression, rather than relying exclusively on differential answers.
	var boss={"variant":4,"pos":Vector3.ZERO,"facing":0.0}
	var p: Dictionary=api.prepare(boss)
	var box: AABB=Contact.bounds(boss)
	for radius in [0.0,.25]:
		var from=Vector3(box.end.x+radius,box.get_center().y,-50)
		var to=Vector3(from.x,from.y,50)
		check(not api.segment_contact(boss,from,to,radius,p).is_empty(),"Expanded boss tangent remains inclusive")
		check(api.segment_contact(boss,from+Vector3(.001,0,0),to+Vector3(.001,0,0),radius,p).is_empty(),"Outside expanded tangent misses")
	check(api.contact(boss,Vector3(0,1,0),p).is_equal_approx(Vector3(0,1,0)),"Interior point remains unchanged")
	# Clear the shared exporter cache to prove repeated prepared bounds/contact
	# queries use retained geometry, without rebuilding shapes or local poses.
	var retained=Contact.cache.duplicate();Contact.cache.clear()
	for i in range(20):
		check(api.bounds({},p).is_equal_approx(box),"Repeated prepared bounds remain exact")
		api.contact({},Vector3(30,1,0),p);api.segment_contact({},Vector3(-40,1,0),Vector3(40,1,0),.1,p)
	check(Contact.cache.is_empty(),"Prepared queries perform no shape reloading")
	Contact.cache=retained
	await actor_refresh_checks()
	finish()
func actor_refresh_checks():
	var game=load("res://scenes/forest_shrine.tscn").instantiate();root.add_child(game);current_scene=game
	for i in range(3):await physics_frame
	game.start_wave();game.model.waves.pending=0;game.model.waves.spawn_clock=10000
	game.set_physics_process(false);game.player.set_physics_process(false)
	var data=game.model.waves.spawn_enemy(2,Vector3(0,0,70))
	data.action="walk";data.walk_phase=1.7;data.velocity=Vector3(1,0,0)
	game.sync_enemies();var actor=game.actors[data.id];actor.set_physics_process(false);actor._sync_fitted_pose()
	check(actor.combat_bounds().is_equal_approx(Contact.bounds(actor._combat_data())),"Raider snapshot matches exact geometry")
	var previous: AABB=actor.combat_bounds()
	data.pos+=Vector3(33,0,0);data.facing=1.3;game.model_tick_serial+=1;actor._physics_process(0)
	check(not actor.combat_bounds().is_equal_approx(previous),"Raider physics refresh invalidates teleport and rotation")
	check(actor.combat_bounds().is_equal_approx(Contact.bounds(actor._combat_data())),"Refreshed Raider retains exact pose")
	actor.freeze_for(2);actor._physics_process(0)
	previous=actor.combat_bounds();data.walk_phase+=2.0;data.attack_progress=.9;game.model_tick_serial+=1;actor._physics_process(0)
	check(actor.combat_bounds().is_equal_approx(previous),"Frozen Raider retains captured feet across animation changes")
	data.frozen=0.0;game.model_tick_serial+=1;actor._physics_process(0)
	check(actor.combat_bounds().is_equal_approx(Contact.bounds(actor._combat_data())),"Thaw refresh returns to current exact pose")
	game.show_pause();game.queue_free();paused=false
	for i in range(3):await process_frame
	await create_timer(.2).timeout
func finish():
	print("PREPARED_ENEMY_CONTACT_RESULT checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)
