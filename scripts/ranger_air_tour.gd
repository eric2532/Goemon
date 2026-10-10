extends "res://scripts/ranger_storm_tour.gd"
## Rendered higher jump and held-Space aerial firing through real MVP input.

func measure_peak(index: int, capture_peak: bool = false) -> float:
	await prepare_hero(index);var p=game.player;var start=p.position.y;var peak=start;var captured=false
	tap("jump")
	for i in range(110):
		await frames(1);peak=maxf(peak,p.position.y)
		if capture_peak and not captured and p.velocity.y<0 and not p.is_on_floor():
			captured=true
			await fixed_camera(p.position+Vector3.UP,Vector3(10,1,12),58)
			await shot("ranger-double-height-jump","Ranger's higher grounded jump measured against ordinary Rogue launch")
	return peak-start

func prepare_drop(held: bool) -> float:
	await prepare_hero(7);var p=game.player
	p.global_position+=Vector3.UP*60;await frames(2)
	p.velocity=Vector3(0,-12,0);p.jumps_used=2;p.coyote=0;p.jump_buffer=0
	var start=p.position.y
	if held:press("jump")
	await frames(24);var drop=start-p.position.y
	press("jump",false);return drop

func run():
	visual=true
	report_dir="res://build/ranger-air/tour" if OS.has_feature("editor") else "user://build/ranger-air/tour"
	output_dir=report_dir.path_join("screenshots")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output_dir))
	if DisplayServer.get_name()=="headless":check(false,"Air tour requires rendered gameplay");write_report();get_tree().quit(1);return
	get_tree().root.size=Vector2i(1440,900);Input.use_accumulated_input=false
	game.smoke_test=true;game.tuning=PrototypeTuning.DEFAULTS.duplicate()
	game.tuning.invincible=true;game.tuning.freeze_ai=true;game.player.smoke_mode=true
	game.camera_rig.set_process_unhandled_input(false)
	game.start_mode("defense");pause_fixture_director();await frames(5)
	check(game.is_fire_siege() and not game.rogue_battle_mode,"Air tour runs exclusively in latest Fire Siege MVP")
	var ordinary=await measure_peak(1)
	var high=await measure_peak(7,true)
	measurements.jump_heights={"ordinary":ordinary,"ranger":high,"ratio":high/ordinary}
	check(high/ordinary>1.95 and high/ordinary<2.12,"Rendered native Ranger jump reaches twice the ordinary apex")
	measurements.ranger_geometry_sha256=model_geometry_hash(game.player.model.actor.model)
	var normal_drop=await prepare_drop(false);var held_drop=await prepare_drop(true)
	measurements.fall={"normal_drop":normal_drop,"held_drop":held_drop,"ratio":normal_drop/held_drop}
	check(absf(normal_drop/held_drop-3)<.12,"Rendered held Space descent covers one third the usual distance")
	await prepare_hero(7);var p=game.player;var a=p.active_ability
	tap("jump");await frames(30);tap("jump");await frames(50)
	check(p.jumps_used==2 and p.position.y>8 and p.velocity.y<0,"Higher double jump provides a descending aerial attack position")
	var targets=[]
	for i in range(-7,8):targets.append(fixture(Vector3(i*1.1,TOUR_ORIGIN.y-p.position.y,-7.5)))
	press("jump");press("light_attack");await frames(15)
	check(a.player.rangerGliding and not p.is_on_floor(),"Actual held Space and LMB enter glide while the Ranger continues shooting")
	await fixed_camera(p.position+Vector3(0,-5,-3.5),Vector3(17,6,13),70)
	await shot("gliding-downward-fan","Higher Ranger jump and slow fall sustain straight downward arrow fans")
	await frames(35)
	measurements.glide_primary_releases=a.player.rangerShots
	measurements.glide_target_damage=damage_total(targets)
	check(a.player.rangerShots>=3 and not p.is_on_floor(),"Held primary releases repeated aerial fans without ending the glide")
	check(damage_total(targets)>=125,"Gliding fans damage real ground enemies through native straight-ray collision")
	var powered=flight_samples.values().filter(func(pr):return pr.power and pr.damage==38)
	measurements.gliding_power_arrows=powered.size()
	check(not powered.is_empty(),"Recorded third-release green power arrows reach the gliding attack sequence")
	press("light_attack",false);tap("surge");a._clear_projectiles();tap("weapon_chain");await frames(3)
	var fan=a.projectiles.filter(func(pr):return pr.weapon=="flintlock")
	check(fan.size()==5 and fan.all(func(pr):return pr.power and pr.vel.y<0),"Rain powers the five-arrow fan while Space continues to slow descent")
	game.hud.show()
	await shot("gliding-rain-fan-and-hud","Rain power fan, held slow fall and current Space instructions remain available together")
	var slow=-p.velocity.y;press("jump",false);await frames(2)
	check(not a.player.rangerGliding and -p.velocity.y>slow*2.8,"Releasing Space promptly restores native downward momentum in rendered gameplay")
	measurements.flight_samples=flight_samples
	release_all();game.camera_rig.set_process(true);game.camera_rig.set_process_unhandled_input(true)
	game.show_main_menu();game.sound_library.cancel();game.music.stop();await frames(3);stop_audio(game)
	var audio=game.get_node_or_null("RogueSharedClassAudio")
	if is_instance_valid(audio):audio.cache.clear()
	write_report();print("RANGER_AIR_TOUR_RESULT checks=",checks," failures=",failures," captures=",screenshots.size()," output=",ProjectSettings.globalize_path(report_dir))
	await frames(18);get_tree().quit(1 if failures else 0)

func write_report():
	var manifest={"suite":"ranger-air-v242","checks":checks,"failures":failures,"measurements":measurements,"observations":observations,"screenshots":screenshots}
	FileAccess.open(report_dir.path_join("verification-manifest.json"),FileAccess.WRITE).store_string(JSON.stringify(manifest,"\t"))
