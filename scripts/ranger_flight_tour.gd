extends "res://scripts/ranger_redesign_tour.gd"
## Rendered latest-MVP evidence and actual world-space flight samples.
var flight_samples: Dictionary = {}

func _physics_process(_delta):
	if not is_instance_valid(game) or not game.player.is_rogue_character():return
	for pr in game.player.active_ability.projectiles:
		if not is_instance_valid(pr.mesh) or not pr.has("rangerFlight"):continue
		var key=str(pr.mesh.get_instance_id())
		if not flight_samples.has(key):
			flight_samples[key]={"power":pr.get("power",false),"damage":pr.damage,"aim_direction":[pr.aimDirection.x,pr.aimDirection.y,pr.aimDirection.z],"launch_direction":[pr.vel.normalized().x,pr.vel.normalized().y,pr.vel.normalized().z],"samples":[]}
		var point:Vector3=pr.mesh.position
		flight_samples[key].samples.append([point.x,point.y,point.z])

func run():
	visual=true
	report_dir="res://build/ranger-flight/tour" if OS.has_feature("editor") else "user://build/ranger-flight/tour"
	output_dir=report_dir.path_join("screenshots")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output_dir))
	if DisplayServer.get_name()=="headless":
		check(false,"Flight tour requires rendered gameplay");write_report();get_tree().quit(1);return
	get_tree().root.size=Vector2i(1440,900);Input.use_accumulated_input=false
	game.smoke_test=true;game.tuning=PrototypeTuning.DEFAULTS.duplicate()
	game.tuning.invincible=true;game.tuning.freeze_ai=true;game.player.smoke_mode=true
	# Capturing/releasing the native mouse can emit relative motion on macOS.
	# This fixture aims through explicit yaw; unrelated cursor motion must not steer it.
	game.camera_rig.set_process_unhandled_input(false)
	game.start_mode("defense");pause_fixture_director();await frames(5)
	check(game.is_fire_siege() and not game.rogue_battle_mode,"Curved-flight tour runs exclusively in latest Fire Siege MVP")
	await prepare_hero(7)
	var p=game.player;var a=p.active_ability
	measurements.ranger_geometry_sha256=model_geometry_hash(p.model.actor.model)
	game.hud.hide();await fixed_camera(p.position+Vector3.UP*1.3,Vector3(4,.7,-5),35)
	await shot("ranger-current-hat","Current covered hat, painted face and body remain intact")
	await prepare_hero(7);a=p.active_ability;game.hud.hide()
	var targets=[]
	for x in [-4.16,-1.96,0.0,1.96,4.16]:targets.append(fixture(Vector3(x,0,-8)))
	await fixed_camera(p.position+Vector3(0,1.1,-4),Vector3(9,7,7),50)
	tap("weapon_chain");await frames(1)
	check(a.projectiles.size()==5,"Key 3 releases all five curved fan arrows together")
	var origins=[];var arrows=a.projectiles.duplicate()
	for pr in arrows:origins.append(pr.mesh.position)
	await frames(7)
	var curving=0
	for i in range(arrows.size()):
		var pr=arrows[i]
		if is_instance_valid(pr.mesh) and absf((pr.mesh.position-origins[i]).dot(pr.rangerFlight.side))>.1:curving+=1
	check(curving==5,"All five live arrows visibly leave their initial straight rays")
	await shot("wide-curved-fan","Broad fan with distinct physical shafts, arrowheads and individually drifting flight")
	await frames(26)
	check(targets.all(func(e):return e.hp<10000),"Wider curved fan reaches five separated enemies through native collision")
	await prepare_hero(7);a=p.active_ability
	await fixed_camera(p.position+Vector3(0,1.2,-3),Vector3(7,3.5,6),48)
	game.hud.hide()
	for i in range(2):tap("light_attack");await frames(15)
	check(a.player.rangerShots==2,"Two normal LMB releases arm the third-shot combo")
	game.hud.show();await frames(2)
	check(game.hud.siege_hud.hero_info(p).primary=="Green Power","HUD teaches that the next shot is green power")
	await shot("green-power-ready-hud","Current MVP HUD labels the armed third shot")
	game.hud.hide();tap("light_attack");await frames(4)
	var power=a.projectiles.back()
	check(power.get("power",false) and power.damage==101,"Third LMB releases the larger green energy arrow")
	await shot("third-green-power-arrow","Green arrow and segmented green energy trail stand apart from normal physical arrows")
	await prepare_hero(7);a=p.active_ability;game.hud.hide();targets.clear()
	for x in [-3.91,-1.84,0.0,1.84,3.91]:targets.append(fixture(Vector3(x,0,-7.5)))
	for i in range(2):tap("light_attack");await frames(15)
	# Remove warm-up arrows and enemies' incidental hits before the aerial test.
	a._clear_projectiles()
	for e in targets:e.hp=10000
	p.attack_chain.reset()
	tap("jump");await frames(30);tap("jump");await frames(20)
	await fixed_camera(p.position.lerp(p.position+Vector3(0,-p.position.y,-7.5),.5),Vector3(12,4,9),58)
	measurements.aerial_camera_yaw=game.camera_rig.yaw
	tap("light_attack");await frames(4)
	check(a.projectiles.size()==5 and a.projectiles.all(func(pr):return pr.get("power",false) and pr.vel.y< -10),"Third aerial LMB releases five green arrows downward")
	await shot("green-aerial-curved-fan","Five green energy arrows curve downward from the double-jump apex")
	await frames(45)
	measurements.aerial_target_damage=targets.map(func(e):return 10000-e.hp)
	check(targets.all(func(e):return is_equal_approx(10000-e.hp,38)),"Powered aerial fan deals native damage to all five ground targets")
	await prepare_hero(7);game.hud.hide();a=p.active_ability
	await fixed_camera(p.position+Vector3.UP,Vector3(6,2.6,-7),42)
	tap("dodge");await frames(6)
	check(a.player.roll>0 and absf(p.model.actor.model.rotation.x)>1,"Current fast rolling dodge remains intact")
	await shot("retained-fast-roll","Covered hat and fast tumble retained alongside curved arrows")
	measurements.flight_samples=flight_samples
	release_all();game.camera_rig.set_process(true);game.camera_rig.set_process_unhandled_input(true)
	game.show_main_menu();game.sound_library.cancel();game.music.stop()
	await frames(3);stop_audio(game)
	var audio=game.get_node_or_null("RogueSharedClassAudio")
	if is_instance_valid(audio):audio.cache.clear()
	write_report()
	print("RANGER_FLIGHT_TOUR_RESULT checks=",checks," failures=",failures," captures=",screenshots.size()," output=",ProjectSettings.globalize_path(report_dir))
	await frames(18);get_tree().quit(1 if failures else 0)

func write_report():
	var manifest={"suite":"ranger-flight-v239","checks":checks,"failures":failures,"measurements":measurements,"observations":observations,"screenshots":screenshots}
	FileAccess.open(report_dir.path_join("verification-manifest.json"),FileAccess.WRITE).store_string(JSON.stringify(manifest,"\t"))
