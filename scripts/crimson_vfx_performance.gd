extends SceneTree
## Fixed window, real crowd physics and real held Samurai contacts.
var game
var quality=1
var output=""
var contacts=0
var report=[]
var hide_numbers=false
var omit_numbers=false
var scenarios=["idle","primary","ultimate"]
func damage_labels()->int:
	var count=0
	if not is_instance_valid(game):return count
	for child in game.get_children():
		if child is Label3D:
			count+=1
			if hide_numbers:child.hide()
	return count
func _initialize():run.call_deferred()
func impact(_enemy,_strength,_duration):contacts+=1
func stats(a: Array)->Dictionary:
	a.sort();var sum=0.0
	for v in a:sum+=v
	return {"mean":sum/a.size(),"p95":a[int(a.size()*.95)],"max":a.back()}
func sample(label: String):
	var p=game.player;var a=p.active_ability
	p.position=Vector3(0,.1,210);p.velocity=Vector3.ZERO;a.cancel();a.player.cooldowns.cutlass=0;a.combo=0;a.combo_timer=0
	for i in range(game.enemies.size()):
		var e=game.enemies[i];e.position=Vector3((float(i%12)-5.5)*1.2,.15,200-float(i/12)*1.4)
		e.velocity=Vector3.ZERO;e.state="march";e.defense_waypoint=1;e.hp=1000000;e.max_hp=1000000
	if label=="ultimate":a.player.cooldowns.drink=0;a.action("drink")
	a.primary_held=label!="idle"
	var warm=Time.get_ticks_msec()+2000
	while Time.get_ticks_msec()<warm:await process_frame
	contacts=0
	var frames=[];var physics=[];var draws=[];var effects=[];var labels=[]
	var last=Time.get_ticks_usec();var until=last+3000000
	while Time.get_ticks_usec()<until:
		await process_frame
		var now=Time.get_ticks_usec();frames.append((now-last)/1000.0);last=now
		physics.append(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)*1000.0)
		draws.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
		effects.append(a.fx.items.size())
		labels.append(damage_labels())
	var row={"scenario":label,"quality":quality,"engine":Engine.get_version_info().string,"enemies":game.enemies.size(),"viewport":str(root.size),"render_size":str(root.get_texture().get_size()),"contacts":contacts,"damage_labels_hidden":hide_numbers,"damage_labels_omitted":omit_numbers,"frame_ms":stats(frames),"physics_ms":stats(physics),"draw_calls":stats(draws),"effects":stats(effects),"damage_labels":stats(labels)}
	report.append(row);print("PROFILE ",JSON.stringify(row));a.primary_held=false;a.cancel()
func run():
	if DisplayServer.get_name()=="headless":quit(2);return
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--quality="):quality=int(arg.trim_prefix("--quality="))
		if arg.begins_with("--output="):output=arg.trim_prefix("--output=")
		if arg=="--hide-damage-numbers":hide_numbers=true
		if arg=="--omit-damage-numbers":omit_numbers=true
		if arg=="--ultimate-only":scenarios=["ultimate"]
	game=load("res://scenes/main.tscn").instantiate()
	if omit_numbers:
		# Diagnostic isolation only: retain all real contacts, damage and AI.
		var diagnostic=GDScript.new()
		diagnostic.source_code="extends \"res://scripts/game.gd\"\nfunc damage_number(_p: Vector3,_amount: int,_heavy: bool,_critical: bool=false):pass\n"
		diagnostic.reload();game.set_script(diagnostic)
	game.smoke_test=true;root.add_child(game)
	game.tuning.invincible=true;game.tuning.freeze_ai=false;game.settings.quality=quality
	game.start_mode("defense");game.apply_quality();game.encounters.set_physics_process(false)
	game.kennel.set_physics_process(false);game.barracks.set_physics_process(false)
	game.encounters.update_start_input(0,false);game.encounters.update_start_input(3.1,true);game.encounters._spawn_due(300)
	game.player.select_character(4);game.player.smoke_mode=true;game.player.smoke_move=Vector2.ZERO
	game.camera_rig.yaw=0;game.camera_rig.set_process(false);game.camera_rig.set_physics_process(false)
	game.camera_rig.camera.global_position=Vector3(10,8,218);game.camera_rig.camera.look_at(Vector3(0,2,203))
	game.impact_confirmed.connect(impact)
	if hide_numbers:process_frame.connect(damage_labels)
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED);root.size=Vector2i(1280,800)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED);Engine.max_fps=0
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	for scenario in scenarios:await sample(scenario)
	DirAccess.make_dir_recursive_absolute(output.get_base_dir());FileAccess.open(output,FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	game.sound_library.cancel();game.music.stop();game.queue_free()
	for i in range(5):await process_frame
	quit()
