extends "res://scripts/rogue_equipment_upgrade_tour.gd"
## Live MVP picker, Ranger art, fan ballistics and fast roll evidence.

func run():
	visual=true
	report_dir="res://build/ranger-redesign/tour" if OS.has_feature("editor") else "user://build/ranger-redesign/tour"
	output_dir=report_dir.path_join("screenshots")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output_dir))
	get_tree().root.size=Vector2i(1440,900)
	Input.use_accumulated_input=false
	game.smoke_test=true;game.tuning=PrototypeTuning.DEFAULTS.duplicate()
	game.tuning.invincible=true;game.tuning.freeze_ai=true;game.player.smoke_mode=true
	game.start_mode("defense");pause_fixture_director();await frames(5)
	check(game.is_fire_siege() and not game.rogue_battle_mode,"Ranger tour runs exclusively in the latest Fire Siege MVP")
	await prepare_hero(7)
	var p=game.player;var a=p.active_ability
	check(p.model.actor.model.scene_file_path=="res://assets/rogue/styled/models/ranger.glb","Ranger uses the latest styled model rather than the legacy original")
	measurements.ranger_geometry_sha256=model_geometry_hash(p.model.actor.model)
	game.hud.hide()
	for view in [{"name":"front","offset":Vector3(0,.45,-6)}, {"name":"profile","offset":Vector3(6,.45,0)}, {"name":"three-quarter","offset":Vector3(4,.7,-5)}, {"name":"back","offset":Vector3(0,.8,6)}]:
		await fixed_camera(p.position+Vector3.UP*1.3,view.offset,35)
		await shot("hat-"+view.name,"Fitted crown and brim cover the scalp while retaining the current painted face and hair")
	await prepare_hero(7);a=p.active_ability
	game.hud.hide()
	var targets=[]
	for x in [-3.91,-1.84,0.0,1.84,3.91]:targets.append(fixture(Vector3(x,0,-7.5)))
	await fixed_camera(p.position+Vector3(0,1.1,-4),Vector3(9,7,7),48)
	tap("weapon_chain");await frames(2)
	check(a.projectiles.size()==5,"Key 3 releases one complete five-arrow fan")
	check(a.projectiles.all(func(pr):return pr.mesh.scale.is_equal_approx(Vector3.ONE*2.4)),"Every Ranger arrow is twenty percent larger than the latest v2.37 arrows")
	await shot("ground-five-arrow-fan","Five simultaneous larger arrows form a broad forward fan")
	await frames(28)
	check(targets.all(func(e):return e.hp<10000),"The ground fan hits five separated live enemies")
	await prepare_hero(7);a=p.active_ability
	game.hud.hide();targets.clear()
	for x in [-3.91,-1.84,0.0,1.84,3.91]:targets.append(fixture(Vector3(x,0,-7.5)))
	await fixed_camera(p.position+Vector3(0,3,-3.5),Vector3(10,5,7),50)
	tap("jump");await frames(30);tap("jump");await frames(20)
	check(p.jumps_used==2 and p.position.y>6,"Delayed double jump reaches its high aerial firing position")
	await fixed_camera(p.position.lerp(p.position+Vector3(0,-p.position.y,-7.5),.5),Vector3(12,4,9),58)
	tap("light_attack");await frames(4)
	check(a.projectiles.size()==5 and a.projectiles.all(func(pr):return pr.vel.y< -10),"Double-jump LMB fires the complete fan downward at real ground")
	await shot("double-jump-downward-fan","Ranger aims the bow downward while five arrows descend toward enemies below")
	await frames(40)
	check(targets.all(func(e):return e.hp<10000),"The high aerial fan hits all five real floor targets")
	await prepare_hero(7);a=p.active_ability
	game.hud.hide()
	await fixed_camera(p.position+Vector3.UP,Vector3(6,2.6,-7),42)
	var origin=p.position
	tap("dodge");await frames(3)
	await shot("fast-roll-entry","The dodge tucks into a fast forward tumble")
	await frames(3)
	check(a.player.roll>0 and absf(p.model.actor.model.rotation.x)>1,"Ranger visibly tumbles during the roll")
	await shot("fast-roll-midpoint","The rolling model stays centred above the physical player body")
	await frames(12)
	check(a.player.roll<=0 and p.position.distance_to(origin)>4,"The fast roll finishes after travelling more than four metres")
	check(absf(p.model.actor.model.position.z)<.1,"The roll restores the model without accumulating offsets")
	await prepare_hero(7)
	game.hud.show();await frames(5)
	await shot("latest-game-hud","The current MVP HUD shows Fan Shot and teaches the double-jump downward fan")
	release_all();game.camera_rig.set_process(true)
	game.show_main_menu();game.sound_library.cancel();game.music.stop()
	await frames(3);stop_audio(game)
	var shared_audio=game.get_node_or_null("RogueSharedClassAudio")
	if is_instance_valid(shared_audio):shared_audio.cache.clear()
	write_report()
	print("RANGER_REDESIGN_TOUR_RESULT checks=",checks," failures=",failures," captures=",screenshots.size()," output=",ProjectSettings.globalize_path(report_dir))
	await frames(18)
	get_tree().quit(1 if failures else 0)

func write_report():
	var manifest={"suite":"ranger-redesign-v238","baseline":"eb97bcc / Fire Siege v2.37.0","checks":checks,"failures":failures,"rendering_method":RenderingServer.get_current_rendering_method(),"measurements":measurements,"observations":observations,"screenshots":screenshots}
	FileAccess.open(report_dir.path_join("verification-manifest.json"),FileAccess.WRITE).store_string(JSON.stringify(manifest,"\t"))
