extends "res://scripts/ranger_flight_tour.gd"
## Latest MVP visual/trajectory evidence for the approved v2.41 straight-arrow correction.

func coverage_band(distance: float) -> Array:
	var targets=[]
	for i in range(-7,8):targets.append(fixture(Vector3(i*1.1,0,-distance)))
	return targets

func damage_total(targets: Array) -> float:
	var total=0.0
	for e in targets:total+=10000-e.hp
	return total

func run():
	visual=true
	report_dir="res://build/ranger-precision/tour" if OS.has_feature("editor") else "user://build/ranger-precision/tour"
	output_dir=report_dir.path_join("screenshots")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output_dir))
	if DisplayServer.get_name()=="headless":
		check(false,"Precision tour requires rendered gameplay");write_report();get_tree().quit(1);return
	get_tree().root.size=Vector2i(1440,900);Input.use_accumulated_input=false
	game.smoke_test=true;game.tuning=PrototypeTuning.DEFAULTS.duplicate()
	game.tuning.invincible=true;game.tuning.freeze_ai=true;game.player.smoke_mode=true
	game.camera_rig.set_process_unhandled_input(false)
	game.start_mode("defense");pause_fixture_director();await frames(5)
	check(game.is_fire_siege() and not game.rogue_battle_mode,"Precision tour runs only in latest Fire Siege MVP")
	await prepare_hero(7)
	var p=game.player;var a=p.active_ability
	measurements.ranger_geometry_sha256=model_geometry_hash(p.model.actor.model)
	game.hud.hide();await fixed_camera(p.position+Vector3.UP*1.3,Vector3(4,.7,-5),35)
	await shot("current-ranger-hat","Current fitted hat and painted Ranger retained")
	await prepare_hero(7);a=p.active_ability;game.hud.hide();seed(240)
	var targets=coverage_band(8)
	await fixed_camera(p.position+Vector3(0,1.2,-4),Vector3(10,9,9),55)
	tap("weapon_chain");await frames(1)
	var arrows=a.projectiles.duplicate()
	check(arrows.size()==5 and arrows.all(func(pr):return not pr.power),"Outside Rain, normal fan releases five straight arrows with subtle aim variance")
	await frames(7)
	var straight=true;var release_angles=[]
	for pr in arrows:
		if is_instance_valid(pr.mesh):
			straight=straight and (pr.mesh.position-pr.rangerFlight.origin).cross(pr.vel.normalized()).length()<.0001
			var side=pr.aimDirection.cross(Vector3.UP).normalized()
			var up=side.cross(pr.aimDirection).normalized()
			release_angles.append([rad_to_deg(atan2(pr.vel.dot(side),pr.vel.dot(pr.aimDirection))),rad_to_deg(atan2(pr.vel.dot(up),pr.vel.dot(pr.aimDirection)))])
	measurements.normal_fan_release_angles_degrees=release_angles
	check(straight and arrows.any(func(pr):return absf(pr.vel.y)>.01),"Live five-arrow fan has fixed straight flight and small vertical aim variation")
	await shot("straight-human-aim-fan","Five straight arrows leave at slightly different horizontal and vertical angles")
	await frames(32)
	measurements.normal_fan_damage=damage_total(targets)
	check(is_equal_approx(damage_total(targets),125),"Straight fan delivers all five native hits into its coverage area")
	await prepare_hero(7);a=p.active_ability;game.hud.hide();seed(240)
	await fixed_camera(p.position+Vector3(0,1.5,-5),Vector3(10,8,9),55)
	tap("surge");tap("weapon_chain");await frames(8)
	check(a.projectiles.size()==5 and a.projectiles.all(func(pr):return pr.power and pr.damage==38),"Rain makes every fan arrow a stronger green power shot")
	await shot("rain-straight-green-fan","Ultimate fan retains stronger green arrows with controlled straight launch variation")
	await prepare_hero(7);a=p.active_ability
	await fixed_camera(p.position+Vector3(0,1.5,-4),Vector3(8,5,8),52)
	tap("surge");press("light_attack");await frames(20);press("light_attack",false)
	check(a.projectiles.size()>=2 and a.projectiles.all(func(pr):return pr.power),"Rain powers repeated LMB arrows before any third-shot requirement")
	await shot("rain-all-primary-arrows-green","All normal left-click releases become green during Rain")
	# Native collisions confirm chain links; no fabricated speed counter.
	await prepare_hero(7);a=p.active_ability;game.hud.hide()
	var close=fixture(Vector3(0,0,-3));seed(240)
	press("light_attack");await frames(64);press("light_attack",false)
	check(p.attack_chain.count>=2,"Live arrow hits build the actual hit combo")
	measurements.live_combo_links=p.attack_chain.count
	measurements.live_combo_fire_multiplier=a.ranger_fire_rate_multiplier()
	check(a.ranger_fire_rate_multiplier()>1.2,"Live hit combo accelerates the actual Ranger attack clock")
	game.hud.show();await fixed_camera(p.position+Vector3(0,1.3,-3),Vector3(7,4,7),52)
	await shot("live-combo-fire-rate-hud","Latest HUD reports progressive fire-rate multiplier from real hits")
	await prepare_hero(7);a=p.active_ability;game.hud.hide()
	for i in range(2):tap("light_attack");await frames(15)
	a._clear_projectiles();targets=coverage_band(7.5);p.attack_chain.reset()
	tap("surge");tap("jump");await frames(30);tap("jump");await frames(20)
	await fixed_camera(p.position.lerp(p.position+Vector3(0,-p.position.y,-7.5),.5),Vector3(12,4,9),60)
	tap("light_attack");await frames(6)
	check(a.projectiles.size()==5 and a.projectiles.all(func(pr):return pr.power and pr.vel.y< -10),"Rain aerial fan sends five straight power arrows downward")
	await shot("rain-downward-straight-fan","Green arrows fly on fixed downward rays from the double-jump apex with subtle aim variation")
	await frames(45)
	measurements.aerial_coverage_damage=damage_total(targets)
	check(damage_total(targets)>=152,"Powered aerial coverage hits multiple ground enemies through native collision")
	await prepare_hero(7);a=p.active_ability;game.hud.hide()
	await fixed_camera(p.position+Vector3.UP,Vector3(6,2.6,-7),42)
	p.smoke_move=Vector2(1,-1).normalized();await frames(1)
	var start=p.position;tap("dodge");await frames(3)
	check(a.player.roll>0 and absf(p.model.actor.model.rotation.x)>1,"The super-fast diagonal dodge visibly tumbles")
	await shot("snap-diagonal-roll","A quick camera-relative diagonal tumble covers useful ground")
	await frames(7);p.smoke_move=Vector2.ZERO
	measurements.snap_roll_distance=p.position.distance_to(start)
	check(a.player.roll<=0 and p.position.distance_to(start)>6.2,"Snap roll completes within ten frames and covers over six metres")
	await sustained_fire_check()
	measurements.flight_samples=flight_samples
	release_all();game.camera_rig.set_process(true);game.camera_rig.set_process_unhandled_input(true)
	game.show_main_menu();game.sound_library.cancel();game.music.stop()
	await frames(3);stop_audio(game)
	var audio=game.get_node_or_null("RogueSharedClassAudio")
	if is_instance_valid(audio):audio.cache.clear()
	write_report()
	print("RANGER_PRECISION_TOUR_RESULT checks=",checks," failures=",failures," captures=",screenshots.size()," output=",ProjectSettings.globalize_path(report_dir))
	await frames(18);get_tree().quit(1 if failures else 0)

func write_report():
	var manifest={"suite":"ranger-precision-v241","checks":checks,"failures":failures,"measurements":measurements,"observations":observations,"screenshots":screenshots}
	FileAccess.open(report_dir.path_join("verification-manifest.json"),FileAccess.WRITE).store_string(JSON.stringify(manifest,"\t"))

func sustained_fire_check():
	await prepare_hero(7);var p=game.player;var a=p.active_ability
	game.hud.show()
	await fixed_camera(p.position+Vector3(0,1.5,-12),Vector3(16,12,14),72)
	# Explicit load fixture: capped combo, 1.5x speed pickup, ten tempo upgrades.
	p.run_upgrades.tempo=10;p.powerups.attack_speed=20;p.attack_speed_stacks=1
	for i in range(24):
		var ticket=p.attack_chain.begin("stress-hit-%d" % i);p.attack_chain.confirm(ticket);p.attack_chain.sequence+=1
	tap("surge");press("light_attack");press("heavy_attack")
	var peak_arrows=0;var peak_fx=0;var all_power=true;var began=Time.get_ticks_usec()
	for i in range(180):
		p.attack_chain.remaining=AttackChain.GRACE
		await frames(1)
		peak_arrows=maxi(peak_arrows,a.projectiles.size());peak_fx=maxi(peak_fx,a.fx.items.size())
		all_power=all_power and a.projectiles.all(func(pr):return pr.power)
	release_all()
	measurements.sustained_fire={"physics_frames":180,"wall_seconds":(Time.get_ticks_usec()-began)/1000000.0,"peak_arrows":peak_arrows,"peak_effects":peak_fx,"base_rate":p.base_attack_speed_multiplier(),"combo_rate":a.ranger_fire_rate_multiplier()}
	check(peak_arrows>=30 and all_power,"Sustained upgraded max-combo LMB/RMB fire keeps all arrows powered")
	check(peak_fx<a.fx.MAX_EFFECTS,"Sustained upgraded fire preserves effects without reaching the pruning cap")
	await shot("sustained-max-combo-rain","Rendered load fixture with both attacks held, maximum combo and speed upgrades")
	p.run_upgrades.tempo=0;p.powerups.attack_speed=0;p.attack_speed_stacks=0
