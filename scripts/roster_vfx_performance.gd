extends SceneTree
## Diagnostic harness only; production game resources are unchanged.
var game
var quality=1
var output=""
var heroes=range(1,13)
var rows=[]
var contacts=0
var fx
var omit_native=false
var hide_shared_visuals=false
var normal_health=false
var scenarios=["idle","primary","secondary","utility","ultimate"]
func _initialize():run.call_deferred()
func impact(_victim,_strength,_duration):contacts+=1
func press(action: String,down: bool=true):
	var event=InputEventAction.new();event.action=action;event.pressed=down
	Input.parse_input_event(event);Input.flush_buffered_events()
func tap(action: String):press(action);press(action,false)
func release_inputs():
	for action in ["light_attack","heavy_attack","jump","equip","surge","sky_strike","weapon_coin","weapon_chain"]:press(action,false)
func stats(values: Array)->Dictionary:
	values.sort();var sum=0.0
	for v in values:sum+=v
	return {"mean":sum/values.size(),"p95":values[int(values.size()*.95)],"max":values.back()}
func labels()->int:
	var count=0
	for child in game.get_children():
		if child is Label3D:count+=1
	return count
func wait_seconds(seconds: float):
	var until=Time.get_ticks_usec()+int(seconds*1000000)
	while Time.get_ticks_usec()<until:await process_frame
func reset(id: int):
	release_inputs();game.clear_siege_projectiles();game.player.clear_powerups()
	game.player.select_character(id)
	var p=game.player;p.cancel_charge();p.clear_powerups();p.end_surge()
	p.position=Vector3(0,.1,210);p.velocity=Vector3.ZERO;p.facing=Vector3.FORWARD
	p.attack_left=0;p.impact_pause=0;p.dodge_time=0;p.dodge_cooldown=0
	p.hp=1000000;p.max_hp=1000000;p.jumps_used=0
	if p.is_rogue_character():p.active_ability.reset_run()
	if id==2:p.musashi.shield_cooldown=0
	game.hit_stop=0
	fx=game.get_node_or_null("RogueSharedClassEffects")
	if fx:
		fx.clear()
		fx.visible=not hide_shared_visuals
	for i in game.enemies.size():
		var e=game.enemies[i]
		if not is_instance_valid(e) or e.dead:push_error("Crowd fixture lost an actor before reset");quit(2);return
		e.position=Vector3((float(i%12)-5.5)*1.2,.15,200-float(i/12)*1.4)
		e.velocity=Vector3.ZERO
		e.max_hp=float(e.get_meta("profile_initial_hp",1000000)) if normal_health else 1000000.0
		e.hp=e.max_hp
		e.state="march";e.defense_waypoint=1;e.stun=0;e.impact_pause=0;e.frozen_left=0
		if is_instance_valid(e.frozen_visual):e.frozen_visual.hide()
	await wait_seconds(1)
func sample(id: int,scenario: String):
	await reset(id)
	var p=game.player
	var names=["", "goemon","edo","pirate","samurai","ninja","mage","knight","dragoon","magic-swordsman","ranger","explorer","master-thief"]
	var duration=2.0 if scenario=="idle" else (8.0 if scenario=="ultimate" else 6.0)
	contacts=0
	var frames=[];var physics=[];var process=[];var draws=[];var effects=[];var text=[];var nodes=[];var projectiles=[]
	var start=Time.get_ticks_usec();var last=start;var next_action=0.0;var second_jump=false
	if scenario=="ultimate":tap("surge")
	if scenario in ["primary","ultimate","airborne"]:p.set_auto_attack(true)
	if scenario=="airborne":tap("jump")
	if scenario=="secondary":press("heavy_attack")
	while Time.get_ticks_usec()-start<int(duration*1000000):
		var age=float(Time.get_ticks_usec()-start)/1000000.0
		if scenario in ["secondary","utility","special","coins","chain"] and age>=next_action:
			if scenario=="secondary":press("heavy_attack",false);press("heavy_attack")
			elif scenario=="utility":tap("equip");tap("dodge")
			elif scenario=="special":tap("sky_strike")
			elif scenario=="coins":tap("weapon_coin")
			elif scenario=="chain":tap("weapon_chain")
			next_action=age+1.1
		if scenario=="airborne" and age>.35 and not second_jump:
			press("jump");second_jump=true
		if hide_shared_visuals and p.is_rogue_character():
			for projectile in p.active_ability.projectiles:
				if is_instance_valid(projectile.mesh):projectile.mesh.hide()
		await process_frame
		var now=Time.get_ticks_usec();frames.append(float(now-last)/1000.0);last=now
		physics.append(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)*1000.0)
		process.append(Performance.get_monitor(Performance.TIME_PROCESS)*1000.0)
		draws.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
		effects.append(fx.items.size() if fx else 0);text.append(labels())
		nodes.append(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
		projectiles.append(get_nodes_in_group("projectiles").size()+(p.active_ability.projectiles.size() if p.is_rogue_character() else 0))
	var damage=0.0;var living=0
	for e in game.enemies:
		if is_instance_valid(e):damage+=e.max_hp-e.hp;living+=int(not e.dead)
	var row={"hero":names[id],"scenario":scenario,"quality":quality,"actors_at_start":300,"actors_alive_at_end":living,"native_feedback_omitted":omit_native,"shared_visuals_hidden":hide_shared_visuals,"normal_enemy_health":normal_health,"seconds":duration,"damage":damage,"contacts":contacts,"frame_ms":stats(frames),"physics_ms":stats(physics),"process_ms":stats(process),"draw_calls":stats(draws),"effects":stats(effects),"damage_labels":stats(text),"scene_nodes":stats(nodes),"projectiles":stats(projectiles)}
	rows.append(row);print("ROSTER_PROFILE ",JSON.stringify(row))
	FileAccess.open(output,FileAccess.WRITE).store_string(JSON.stringify(rows,"\t"))
	release_inputs();p.set_auto_attack(false)
func run():
	if DisplayServer.get_name()=="headless":quit(2);return
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--quality="):quality=int(arg.trim_prefix("--quality="))
		if arg.begins_with("--output="):output=arg.trim_prefix("--output=")
		if arg=="--omit-native-feedback":omit_native=true
		if arg=="--hide-shared-visuals":hide_shared_visuals=true
		if arg=="--normal-enemy-health":normal_health=true
		if arg.begins_with("--scenarios="):scenarios=arg.trim_prefix("--scenarios=").split(",")
		if arg.begins_with("--heroes="):
			heroes=[]
			for id in arg.trim_prefix("--heroes=").split(","):heroes.append(int(id))
	DirAccess.make_dir_recursive_absolute(output.get_base_dir())
	game=load("res://scenes/main.tscn").instantiate()
	if omit_native:
		var diagnostic=GDScript.new()
		diagnostic.source_code="extends \"res://scripts/game.gd\"\nfunc impact_effect(_p: Vector3,_d: Vector3,_s: int):pass\nfunc burst(_p: Vector3,_c: Color,_n: int,_s: float=1):pass\n"
		diagnostic.reload();game.set_script(diagnostic)
	game.smoke_test=true;root.add_child(game)
	game.tuning=PrototypeTuning.DEFAULTS.duplicate()
	game.tuning.invincible=false;game.tuning.freeze_ai=false;game.settings.quality=quality
	game.start_mode("defense");game.apply_quality();game.encounters.set_physics_process(false)
	# Keep raiders in this diagnostic arena; actual AI/attack/death still run.
	game.world.base_position=Vector3(0,0,10000)
	game.kennel.set_physics_process(false);game.barracks.set_physics_process(false)
	game.player.smoke_mode=true;game.player.smoke_move=Vector2.ZERO
	game.camera_rig.yaw=0;game.camera_rig.set_process(false);game.camera_rig.set_physics_process(false)
	game.camera_rig.camera.global_position=Vector3(10,8,218);game.camera_rig.camera.look_at(Vector3(0,2,203))
	game.impact_confirmed.connect(impact)
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED);root.size=Vector2i(1280,800)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED);Engine.max_fps=0
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE;Input.use_accumulated_input=false
	print("ROSTER_START engine=",Engine.get_version_info().string," quality=",quality," actors_per_hero=300 viewport=",root.size," render=",root.get_texture().get_size())
	for id in heroes:
		if not normal_health:await fresh_crowd(id)
		for scenario in scenarios:
			if normal_health:await fresh_crowd(id)
			await sample(id,scenario)
		if id==1 and scenarios.size()>2:
			for scenario in ["coins","chain","special"]:
				if normal_health:await fresh_crowd(id)
				await sample(id,scenario)
		if id==2 and scenarios.size()>2:
			if normal_health:await fresh_crowd(id)
			await sample(id,"special")
		if id==10:
			if normal_health:await fresh_crowd(id)
			if scenarios.size()>2 or normal_health:await sample(id,"airborne")
	release_inputs();game.clear_siege_projectiles();game.sound_library.cancel();game.music.stop();game.queue_free()
	for i in range(5):await process_frame
	print("ROSTER_COMPLETE scenarios=",rows.size());quit()

func fresh_crowd(id: int):
	# Durable tests keep a cohort per hero. Natural-health waves get a fresh
	# cohort per action so deaths cannot invalidate the next sample.
	release_inputs();game.player.set_auto_attack(false);game.clear_siege_projectiles()
	game.player.select_character(id);game.player.clear_powerups();game.player.end_surge()
	if game.player.is_rogue_character():game.player.active_ability.reset_run()
	for e in game.enemies:
		if is_instance_valid(e):e.queue_free()
	game.enemies.clear();game.player.progression.reset()
	game.encounters.begin();game.encounters.set_physics_process(false)
	game.encounters.update_start_input(0,false);game.encounters.update_start_input(3.1,true);game.encounters._spawn_due(300)
	for e in game.enemies:e.set_meta("profile_initial_hp",e.max_hp)
	await wait_seconds(2)
