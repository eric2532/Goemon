extends "res://scripts/ranger_flight_tests.gd"
## Real latest-MVP flight, release timing, ultimate and camera-relative rolling.
var shot_frames: Dictionary = {}

func record_projectiles():
	super.record_projectiles()
	if not is_instance_valid(game) or not game.player.is_rogue_character():return
	for pr in game.player.active_ability.projectiles:
		if is_instance_valid(pr.mesh) and pr.kind=="arrow" and pr.weapon=="cutlass":
			if not shot_frames.has(pr.mesh.get_instance_id()):shot_frames[pr.mesh.get_instance_id()]=Engine.get_physics_frames()

func run():
	Input.use_accumulated_input=false
	game.smoke_test=true;game.tuning=PrototypeTuning.DEFAULTS.duplicate()
	game.tuning.invincible=true;game.tuning.freeze_ai=true;game.player.smoke_mode=true
	game.start_mode("defense");pause_fixture_director();await frames(3)
	await random_flight_rules()
	await acceleration_rules()
	await ultimate_rules()
	await directional_roll_rules()
	await release_edge_rules()
	await varied_profile_rules()
	await collision_trail_rule()
	await curved_cover_rules()
	await lifecycle_rules()
	game.show_main_menu();game.sound_library.cancel();game.music.stop()
	await frames(3);stop_audio(game)
	var audio=game.get_node_or_null("RogueSharedClassAudio")
	if is_instance_valid(audio):audio.cache.clear()
	await frames(15)
	print("RANGER_PRECISION_RESULT checks=",checks," failures=",failures)
	get_tree().quit(1 if failures else 0)

func random_flight_rules():
	for powered in [false,true]:
		await fresh_class(7);seed(241);var a=game.player.active_ability
		if powered:tap("surge")
		tap("light_attack");await frames(4)
		var pr=a.projectiles[0];var origin=pr.mesh.position;var heading=pr.vel.normalized()
		var trail_id=pr.rangerTrail.node.get_instance_id();var straight=true
		for i in range(35):
			if i==12:game.camera_rig.yaw+=.8;a._update_aim()
			await frames(1)
			straight=straight and (pr.mesh.position-origin).cross(heading).length()<.0001 and pr.vel.normalized().dot(heading)>.999999
		check(straight,"%s actual arrow keeps one perfectly straight trajectory after release" % ("Green" if powered else "Normal"))
		check(pr.rangerTrail.node.get_instance_id()==trail_id,"Straight flight retains the efficient reusable trail")
		check(pr.mesh.basis.z.normalized().dot(heading)>.9999,"Arrow tip keeps the fixed release direction")
	await fresh_class(7);var a=game.player.active_ability;seed(241)
	var quadrants={};var directions=[];var bounded=true;var horizontal=false;var vertical=false
	for i in range(64):
		var powered=i%2==1
		preload("res://assets/rogue/scripts/class_actions.gd").fire_projectile(a,{"direction":Vector3.RIGHT,"speed":36,"power":powered,"feedback":false})
		var heading:Vector3=a.projectiles.back().vel.normalized()
		var yaw=rad_to_deg(atan2(heading.z,heading.x));var pitch=rad_to_deg(atan2(heading.y,heading.x))
		bounded=bounded and absf(yaw)<=(2.501 if powered else 2.001) and absf(pitch)<=(1.501 if powered else 1.251)
		horizontal=horizontal or absf(yaw)>.2;vertical=vertical or absf(pitch)>.2
		quadrants[Vector2(signf(yaw),signf(pitch))]=true;directions.append(heading)
	check(horizontal and vertical and quadrants.size()==4,"Launch variation includes left/right, up/down and all four diagonal combinations")
	check(bounded,"Normal and green launch angles stay within a subtle controlled aim cone")
	check(directions[0].distance_to(directions[2])>.0001 and directions[1].distance_to(directions[3])>.0001,"Successive normal and green arrows receive different launch angles")
	a._clear_projectiles();tap("weapon_chain");await frames(1)
	check(a.projectiles.size()==5,"Small launch variation preserves the simultaneous five-arrow fan")

func acceleration_rules():
	var rates=[];var intervals=[]
	for links in [0,5,12,24]:
		await fresh_class(7);var p=game.player
		# Confirm real attack tickets, rather than setting a synthetic speed variable.
		for i in range(links):
			var ticket=p.attack_chain.begin("ranger-test-hit-%d" % i)
			p.attack_chain.confirm(ticket);p.attack_chain.sequence+=1
		rates.append(p.attack_speed_multiplier()/p.base_attack_speed_multiplier())
		shot_frames.clear();press("light_attack");await frames(35);press("light_attack",false)
		var ticks=shot_frames.values();ticks.sort()
		intervals.append(float(ticks[-1]-ticks[0])/maxi(1,ticks.size()-1))
	check(rates[0]==1 and rates[1]>1.5 and rates[2]>2.3 and is_equal_approx(rates[3],3.0),"Live hit combos progressively accelerate Ranger firing up to three times base")
	check(intervals[0]>intervals[1] and intervals[1]>intervals[2] and intervals[2]>=intervals[3],"Real held-input arrow releases get progressively closer together")
	await fresh_class(7);var p=game.player
	for i in range(8):
		var ticket=p.attack_chain.begin("confirmed-%d" % i);p.attack_chain.confirm(ticket);p.attack_chain.sequence+=1
	await frames(120)
	check(is_equal_approx(p.attack_speed_multiplier(),p.base_attack_speed_multiplier()),"Breaking the hit combo restores normal firing speed")
	await fresh_class(1);p=game.player
	for i in range(24):
		var ticket=p.attack_chain.begin("confirmed-%d" % i);p.attack_chain.confirm(ticket);p.attack_chain.sequence+=1
	check(is_equal_approx(p.attack_speed_multiplier()/p.base_attack_speed_multiplier(),1.5),"Other heroes retain their existing combo speed cap")

func ultimate_rules():
	await fresh_class(7);var p=game.player;var a=p.active_ability
	tap("surge")
	for i in range(3):
		tap("light_attack");await frames(4)
		check(a.projectiles.back().get("power",false) and a.projectiles.back().damage==101,"Rain powers LMB release %d, including normally regular arrows" % (i+1))
		await frames(12)
	a._clear_projectiles();tap("weapon_chain");await frames(1)
	check(a.projectiles.size()==5 and a.projectiles.all(func(pr):return pr.get("power",false) and pr.damage==38),"Rain powers every arrow in the key3 fan")
	await fresh_class(7);a=p.active_ability;tap("surge")
	tap("jump");await frames(6);tap("jump");await frames(6);tap("light_attack");await frames(4)
	check(a.projectiles.size()==5 and a.projectiles.all(func(pr):return pr.get("power",false) and pr.vel.y< -3),"Rain powers every arrow of the downward aerial LMB fan")
	a._clear_projectiles();a.player.cooldowns.flintlock=0;tap("heavy_attack");await frames(1)
	check(a.projectiles.size()==5 and a.projectiles.all(func(pr):return pr.get("power",false)),"Rain powers the right-click aerial fan too")
	await fresh_class(7);a=p.active_ability;tap("surge");await frames(610)
	for i in range(3):
		tap("light_attack");await frames(4)
		check(a.projectiles.back().get("power",false)==(i==2),"After Rain expires, release%d returns to the two-normal/third-green pattern" % (i+1))
		await frames(12)

func directional_roll_rules():
	for input in [Vector2(0,-1),Vector2(0,1),Vector2(-1,0),Vector2(1,0),Vector2(-1,-1),Vector2(1,-1),Vector2(-1,1),Vector2(1,1)]:
		await fresh_class(7);var p=game.player;var a=p.active_ability
		game.camera_rig.yaw=.7;p.smoke_move=input.normalized();await frames(2)
		var wanted=Vector3(input.x,0,input.y).normalized().rotated(Vector3.UP,.7)
		var start=p.position;tap("dodge");await frames(3)
		check(a.player.roll>0 and a.player.rollDir.dot(wanted)>.999,"Camera-relative roll follows movement direction %s" % input)
		check(absf(p.model.actor.model.rotation.x)>1.0,"The quick dodge remains a visible full tumble")
		await frames(7);p.smoke_move=Vector2.ZERO
		var offset=p.position-start;offset.y=0
		check(a.player.roll<=0 and offset.length()>6.2 and offset.dot(wanted)>6.2,"Roll%s finishes within .17sec and covers useful distance" % input)
		check(absf(p.model.actor.model.position.z)<.1,"Roll recovery stays centered without accumulated model drift")
	await fresh_class(7);var p=game.player;var a=p.active_ability
	a.player.angle=1.2;var wanted=a.front(1.2);tap("dodge");await frames(1)
	check(a.player.rollDir.dot(wanted)>.999,"With no movement input the roll follows the body's current facing")
	await fresh_class(7);a=p.active_ability
	var wall=obstacle(Vector3(3,3,0),Vector3(.3,8,14));p.smoke_move=Vector2(0,-1);await frames(2)
	var start=p.position;tap("dodge");await frames(12)
	check(p.position.x-start.x<2.8,"Super-fast roll still stops at solid cover")
	wall.queue_free();p.smoke_move=Vector2.ZERO;await frames(2)
	await fresh_class(7);a=p.active_ability;p.smoke_mode=false;game.camera_rig.yaw=.7
	press("move_forward");press("move_right");tap("dodge");await frames(1)
	wanted=Vector3(1,0,-1).normalized().rotated(Vector3.UP,.7)
	check(a.player.rollDir.dot(wanted)>.999,"Real held WASD actions select the same natural diagonal roll")
	press("move_forward",false);press("move_right",false);p.smoke_mode=true

func collision_trail_rule():
	await fresh_class(7);seed(240)
	var a=game.player.active_ability
	tap("light_attack");await frames(4)
	var pr=a.projectiles[0]
	var wall=obstacle(Vector3(3,2,0),Vector3(.2,5,12));await frames(1)
	var before=pr.mesh.position
	preload("res://assets/rogue/scripts/class_actions.gd").update_projectile(a,pr,.1)
	var vertices=pr.rangerTrail.node.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var tip=pr.rangerTrail.node.global_transform*((vertices[-4]+vertices[-1])*.5)
	check(pr.life<=0 and tip.distance_to(pr.mesh.position)<.001 and tip.distance_to(before)>0,"Straight trail ends at actual cover contact instead of extending through the wall")
	var contact=pr.mesh.position;a.fx.tick(.04)
	tip=pr.rangerTrail.node.global_transform*((vertices[-4]+vertices[-1])*.5)
	check(tip.distance_to(contact)<.001,"Fading straight trails stay at their world collision contact")
	wall.queue_free();await frames(2)

func release_edge_rules():
	await fresh_class(7);var p=game.player;var a=p.active_ability
	for i in range(2):tap("light_attack");await frames(15)
	a._clear_projectiles();tap("light_attack");await frames(1)
	p.smoke_move=Vector2(1,0);tap("dodge");await frames(12);p.smoke_move=Vector2.ZERO
	check(a.projectiles.is_empty() and a.player.rangerShots==2,"Rolling during draw cancels the arrow and preserves the pending third shot")
	tap("light_attack");await frames(4)
	check(a.projectiles.back().power and a.player.rangerShots==3,"First release after interrupted draw is still the third green shot")
	await fresh_class(7);a=p.active_ability;tap("surge")
	a.player.buffTime=.02;tap("light_attack");await frames(4)
	check(not a.projectiles.back().power,"Rain expiring during draw restores normal power at release time")
	await fresh_class(7);a=p.active_ability;tap("surge")
	a.player.buffTime=.1;tap("light_attack");await frames(4)
	var released=a.projectiles.back();await frames(5)
	check(a.player.buffTime<=0 and released.power and released.damage==101,"Already released Rain arrows retain power after the ultimate expires")

func varied_profile_rules():
	var flight=preload("res://assets/rogue/scripts/ranger_arrow_flight.gd")
	var straight=true;var full_range=true
	for seed_value in [1,17,241,777,9999]:
		for scale in [1.0,1.5,3.0]:
			for heading in [Vector3.RIGHT,Vector3(1,.3,-1).normalized(),Vector3.UP,Vector3.DOWN]:
				seed(seed_value);var mesh=Node3D.new();mesh.position=Vector3(50,5,205)
				var origin=mesh.position
				var pr={"mesh":mesh,"vel":heading*36,"life":60.0*scale/36.0,"power":seed_value%2==1}
				flight.attach(pr,seed_value,scale)
				for i in range(ceilf(pr.life*60)+1):
					flight.advance(pr,1.0/60)
					straight=straight and (mesh.position-origin).cross(heading).length()<.0002
				full_range=full_range and mesh.position.distance_to(origin+heading*60*scale)<.0002
				mesh.free()
	check(straight,"All growth scales and horizontal, vertical and diagonal headings remain straight throughout flight")
	check(full_range,"Straight arrows retain their full configured lifetime range at every growth scale")
