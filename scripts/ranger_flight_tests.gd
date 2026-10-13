extends "res://scripts/rogue_equipment_combat_tests.gd"
## Real input, sampled flight and collision for the approved Ranger changes.

func run():
	Input.use_accumulated_input=false
	game.smoke_test=true;game.tuning=PrototypeTuning.DEFAULTS.duplicate()
	game.tuning.invincible=true;game.tuning.freeze_ai=true;game.player.smoke_mode=true
	game.start_mode("defense");pause_fixture_director();await frames(3)
	await drift_rules()
	await combo_rules()
	await lifecycle_rules()
	await curved_cover_rules()
	game.show_main_menu();game.sound_library.cancel();game.music.stop()
	await frames(3);stop_audio(game)
	var audio=game.get_node_or_null("RogueSharedClassAudio")
	if is_instance_valid(audio):audio.cache.clear()
	await frames(15)
	print("RANGER_FLIGHT_RESULT checks=",checks," failures=",failures)
	get_tree().quit(1 if failures else 0)

func drift_rules():
	await fresh_class(7);seed(241);var a=game.player.active_ability
	tap("weapon_chain");await frames(1)
	check(a.projectiles.size()==5,"Fan still releases five simultaneous arrows")
	if a.projectiles.size()!=5:return
	var arrows=a.projectiles.duplicate();var origins=[];var directions=[]
	for pr in arrows:origins.append(pr.mesh.position);directions.append(pr.vel.normalized())
	var opening=absf(directions[0].signed_angle_to(directions[4],Vector3.UP))
	check(opening>.88 and opening<1.05,"Five-arrow fan keeps its roughly 55-degree opening with subtle launch variation")
	var straight=true;var curve_offset=0.0;var aligned=true
	for step in range(16):
		var previous=[]
		for pr in arrows:previous.append(pr.mesh.position if is_instance_valid(pr.mesh) else Vector3.ZERO)
		await frames(1)
		for i in range(arrows.size()):
			if is_instance_valid(arrows[i].mesh):straight=straight and (arrows[i].mesh.position-origins[i]).cross(directions[i]).length()<.0001
			if is_instance_valid(arrows[i].mesh):curve_offset=maxf(curve_offset,(arrows[i].mesh.position-arrows[i].rangerFlight.origin).cross(directions[i]).length())
			if is_instance_valid(arrows[i].mesh):
				var displacement:Vector3=arrows[i].mesh.position-previous[i]
				if displacement.length_squared()>.000001:aligned=aligned and arrows[i].mesh.basis.z.normalized().dot(displacement.normalized())>.99999
	if game.crosshair_aim_enabled():
		check(curve_offset>.02 and curve_offset<.3,"Fan arrows keep a gentle bounded curve around their separate release rays")
	else:check(straight,"Every fan arrow follows its own fixed straight release ray")
	check(aligned and arrows.all(func(pr):return is_instance_valid(pr.mesh)),"Arrow tips remain aligned with measured flight displacement")
	check(arrows.any(func(pr):return absf(pr.vel.y)>.02),"Ground fan includes small vertical launch variation")
	await fresh_class(1);a=game.player.active_ability;tap("equip");await frames(1)
	var pr=a.projectiles[0];var start:Vector3=pr.mesh.position;var side:Vector3=pr.vel.normalized().cross(Vector3.UP)
	await frames(10)
	check(is_instance_valid(pr.mesh) and absf((pr.mesh.position-start).dot(side))<.0001,"Samurai arrows keep their existing straight flight")

func combo_rules():
	await fresh_class(7)
	var p=game.player;var a=p.active_ability
	var releases=[]
	for shot in range(6):
		p.attack_chain.reset();tap("light_attack");await frames(4)
		var pr=a.projectiles.back()
		releases.append(pr)
		check(pr.get("power",false)==(shot%3==2),"Released LMB shot %d follows normal, normal, green power rhythm" % (shot+1))
		if shot%3==2:
			check(pr.damage==101 and pr.color.g>pr.color.r*1.5 and pr.mesh.scale.x>3.1,"Third arrow has stronger damage, green energy and a larger mesh")
		else:check(pr.damage==67,"Regular combo arrows retain their native 67 damage")
		# Deliberately outwait the melee combo timer: every third shot still counts.
		await frames(70)
	await fresh_class(7);a=p.active_ability
	tap("light_attack");await frames(15);tap("weapon_chain");await frames(1)
	check(a.projectiles.filter(func(pr):return pr.get("power",false)).is_empty(),"Secondary fan cannot become a combo power shot")
	await frames(20);tap("light_attack");await frames(15);tap("light_attack");await frames(4)
	check(a.projectiles.back().get("power",false),"Secondary fan does not consume or reset LMB combo progress")
	await fresh_class(7);a=p.active_ability
	for i in range(2):tap("light_attack");await frames(15)
	tap("light_attack");game.show_pause();await frames(3);game.resume();await frames(15)
	tap("light_attack");await frames(4)
	check(a.projectiles.back().get("power",false),"Cancelling an unreleased third shot preserves the pending power shot")
	a.reset_run();await frames(15);tap("light_attack");await frames(4)
	check(not a.projectiles.back().get("power",false),"Run reset clears the Ranger power-shot counter")
	await fresh_class(7);a=p.active_ability
	for i in range(2):tap("light_attack");await frames(15)
	tap("jump");await frames(6);tap("jump");await frames(6)
	tap("light_attack");await frames(4)
	var green=a.projectiles.filter(func(pr):return pr.get("power",false))
	var powered_fan=green.size()==5 and green.all(func(pr):return pr.damage==38)
	if game.crosshair_aim_enabled():
		check(powered_fan and green[2].aimDirection.dot(game.projectile_direction(a.player.pos+Vector3.UP*1.05))>.999,"Third aerial LMB attack is one complete green reticle-aimed fan")
	else:check(powered_fan and green.all(func(pr):return pr.vel.y< -3),"Third aerial LMB attack is one complete green downward fan")
	await fresh_class(7);a=p.active_ability
	for i in range(2):tap("light_attack");await frames(15)
	a._clear_projectiles();p.attack_chain.reset()
	var targets=ranger_target_band(7,3);tap("light_attack");await frames(24)
	check(is_equal_approx(ranger_band_damage(targets),101),"The green third arrow deals its stronger damage through native enemy collision")

func curved_cover_rules():
	await fresh_class(7);seed(241);var a=game.player.active_ability
	tap("light_attack");await frames(4);var pr=a.projectiles[0]
	var direction:Vector3=pr.vel.normalized();var origin:Vector3=pr.mesh.position
	var center=origin+direction*4
	var solid=obstacle(center-game.player.global_position,Vector3(.2,3,3));await frames(12)
	check(not is_instance_valid(pr.mesh) or pr.life<=0,"Solid cover stops arrows on their actual randomized straight release ray")
	solid.queue_free();await frames(2)

func lifecycle_rules():
	await fresh_class(7)
	var p=game.player;var a=p.active_ability
	for i in range(2):tap("light_attack");await frames(15)
	p.hp=0;game.encounters.hero_died();await frames(2)
	check(int(a.player.get("rangerShots",0))==0,"Actual Fire Siege death clears the pending third-shot combo")
	game.encounters.revive_now();await frames(15);tap("light_attack");await frames(4)
	check(not a.projectiles.back().get("power",false),"Revival starts with a regular arrow")
	await frames(15);tap("light_attack");await frames(15)
	p.select_character(4);p.select_character(10);a=p.active_ability
	await frames(15);tap("light_attack");await frames(4)
	check(not a.projectiles.back().get("power",false) and a.player.rangerShots==1,"Switching away and back resets Ranger's shot sequence")
