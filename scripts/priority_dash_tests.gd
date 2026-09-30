extends "res://scripts/power_combat_tests.gd"

func clean():
	await prepare(1)
	game.player.invuln=0;game.player.hp=100;game.player.smoke_move=Vector2.ZERO
	game.tuning.invincible=false;game.tuning.freeze_ai=true

func capture_dash(label: String):
	if not visual:return
	game.hud.toast_time=0;game.hud.banner_time=0
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://tests/priority-dash/"+label+".png")

func run():
	visual="--priority-dash-visual" in OS.get_cmdline_user_args()
	Input.use_accumulated_input=false
	game.tuning=PrototypeTuning.DEFAULTS.duplicate()
	game.start_game();game.encounters.enabled=false;game.player.smoke_mode=true
	game.camera_rig.set_process_unhandled_input(false);get_window().set_flag(Window.FLAG_NO_FOCUS,true);Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	var p=game.player
	await clean()
	# Synthetic long clips test continuity without recording or touching saved audio.
	var lib=game.sound_library;var saved=lib.custom.duplicate();var gains=lib.gains.duplicate()
	var data=PackedVector2Array()
	for i in range(96000):data.append(Vector2.ONE*sin(i*.057)*.1)
	var fixture=lib.make_take(data,48000)
	AudioServer.set_bus_mute(0,true)
	for voice in game.voices:voice.stop()
	lib.custom.swing=fixture;lib.gains.swing=.8
	game.sound("swing")
	var attack_voice=game.last_sound_voice;var order=attack_voice.get_meta("order")
	await wait(.1)
	var cursor=attack_voice.get_playback_position()
	for i in range(200):
		game.sound("hit");game.sound("enemy_reaction");game.sound("step");game.sound("heavy_swing",.5,true)
	await wait(.1)
	check(attack_voice.playing and attack_voice.stream==fixture and attack_voice.get_meta("order")==order,"800 crowd sounds cannot interrupt or restart a playing attack recording")
	# Headless uses a dummy audio driver; the rendered run checks the real mixer clock.
	if DisplayServer.get_name()!="headless":check(attack_voice.get_playback_position()>cursor,"Real audio playback continues advancing through crowd hits")
	check(is_equal_approx(attack_voice.pitch_scale,1) and is_equal_approx(db_to_linear(attack_voice.volume_db),.55*.8),"Custom attack pitch and saved volume remain intact")
	var count=0
	for voice in game.voices:
		if voice.playing and voice.get_meta("kind","")=="hit":count+=1
	check(count<=2,"Repeated crowd impacts have at most two simultaneous voices")
	game.sound("hit")
	check(is_equal_approx(db_to_linear(game.last_sound_voice.volume_db),.55*.45*float(lib.gains.get("hit",1))),"Hit mix is reduced so attacks remain in the foreground")
	game.sound("edo_volley");check(game.last_sound_voice!=attack_voice and attack_voice.playing,"Distinct attacks overlap instead of replacing each other")
	for voice in game.voices:voice.stop()
	for slot in game.ATTACK_SOUNDS:lib.custom[slot]=fixture
	for i in range(16):game.sound(game.ATTACK_SOUNDS[i])
	var orders=[]
	for i in range(16):orders.append(game.voices[i].get_meta("order"))
	for i in range(100):
		for slot in game.IMPACT_SOUNDS:game.sound(slot)
	var intact=true
	for i in range(16):intact=intact and game.voices[i].playing and game.voices[i].get_meta("order")==orders[i]
	check(intact,"All 16 reserved attack voices survive 1,200 impact requests")
	game.sound("swing")
	check(game.last_sound_voice==game.voices[0],"Only a new player attack can replace the oldest saturated attack voice")
	lib.recording=true;var serial=game.voice_idx;game.sound("swing");lib.recording=false
	check(game.voice_idx==serial,"Recording mode suppresses gameplay sound requests")
	for voice in game.voices:voice.stop()
	check(lib.SLOTS.has("goemon_dash") and lib.SLOTS.has("goemon_dash_hit"),"Dash and shove have dedicated recording slots")
	lib.custom=saved;lib.gains=gains

	for slot in [1,2,3]:
		await clean();p.select_weapon(slot)
		var equipped=p.model.equipped;var origin=p.position
		await key(KEY_E)
		check(p.forward_dash.active and p.forward_dash.immunity_left>0 and p.model.equipped==equipped,"E starts a protected dash without stowing weapon "+str(slot))
		p.take_hit(20,Vector3.BACK)
		check(p.hp==100,"Dash blocks incoming damage with weapon "+str(slot))
		await wait(.23)
		check(not p.forward_dash.active and absf(origin.z-p.position.z-4)<.12 and absf(p.position.x-origin.x)<.05,"Weapon %d dash travels four metres and stops" % slot)
		p.take_hit(20,Vector3.BACK)
		check(p.hp==100,"Short protection continues just after dash "+str(slot))
		await wait(.16);p.take_hit(20,Vector3.BACK)
		check(p.hp==80,"Protection expires after the brief dash window "+str(slot))

	await clean();var origin=p.position;game.camera_rig.yaw=PI*.5
	await key(KEY_E);game.camera_rig.yaw=0;p.smoke_move=Vector2.RIGHT
	await wait(.21);p.smoke_move=Vector2.ZERO
	check(origin.x-p.position.x>3.8 and absf(origin.z-p.position.z)<.12,"Dash locks its camera-forward heading despite turning and strafe input")
	await clean();var first=target(Vector3(0,0,-1.4));var second=target(Vector3(.65,0,-3));var outside=target(Vector3(4,0,-2))
	await key(KEY_E);await wait(.23)
	check(first.hp==9996 and second.hp==9996 and outside.hp==10000,"Dash deals only 4 damage once to each contacted enemy")
	await key(KEY_E);await key(KEY_C)
	check(not p.forward_dash.active and p.dodge_time==0,"E and C cannot bypass the shared evade cooldown")
	await wait(.62);await key(KEY_E)
	check(p.forward_dash.active,"Dash is usable again after its cooldown")
	await clean();first=target(Vector3(0,0,-1.3));first.training_dummy=false;game.tuning.freeze_ai=false
	var enemy_origin=first.position
	await key(KEY_E);await wait(.1)
	check(first.stun>0 and Vector2(first.velocity.x,first.velocity.z).length()>18,"Light dash hit produces strong knockback and interrupts the enemy")
	await capture_dash("01-dash-knockback");await wait(.12)
	check(first.position.distance_to(enemy_origin)>3 and first.hp==9996,"Enemy is visibly pushed several metres, with no repeated damage")
	await clean();first=target(Vector3(0,0,-1.4));p.collect_powerup("damage")
	for i in range(4):p.collect_powerup("attack_speed")
	origin=p.position;await key(KEY_E);await wait(.23)
	check(first.hp==9994 and absf(origin.z-p.position.z-4)<.12,"Damage orb gives 6 damage; attack speed does not extend dash distance")
	await clean();origin=p.position;first=target(Vector3(0,0,-1.5))
	var wall=Geo.box(game,p.position+Vector3(0,1.5,-1),Vector3(6,4,.3),Geo.mat("888888"),true)
	await wait(.06);await key(KEY_E);await wait(.23)
	check(origin.z-p.position.z<.7 and first.hp==10000,"Wall stops the dash and prevents shoving an enemy through cover")
	wall.queue_free()
	await clean();await mouse(true);await key(KEY_E)
	check(p.attack_left==0 and not p.queued and p.forward_dash.active,"E cancels the pipe combo immediately")
	await clean();p.select_weapon(3);await mouse(true);await mouse(false);await key(KEY_E)
	check(not p.chain_pipe_combat.active and not p.model.chain_pipe.endpoint_override and p.forward_dash.active,"E retracts an active chain before dashing")
	game.show_pause();game.resume()
	check(not p.forward_dash.active and p.forward_dash.immunity_left==0 and p.dodge_time==0,"Pause cancels dash movement and its invulnerability")
	await clean();await key(KEY_E);await key(KEY_Q)
	check(p.character_id==2 and not p.forward_dash.active and p.forward_dash.immunity_left==0,"Character switching removes Goemon's dash state")
	await prepare(2);await key(KEY_E)
	check(p.musashi.teleport.active and not p.forward_dash.active,"Edo E still uses the existing fire teleport")
	await clean();await key(KEY_C);await key(KEY_E)
	check(p.dodge_time>0 and not p.forward_dash.active,"C remains the existing evade and prevents an immediate E")
	await clean();await key(KEY_E);game.restart_area();game.encounters.enabled=false
	check(not p.forward_dash.active and p.forward_dash.immunity_left==0 and p.dodge_cooldown==0,"Restart clears dash state and cooldown")
	await capture_dash("02-controls")
	print("PRIORITY_DASH_RESULT failures=",failures)
	get_tree().quit(1 if failures else 0)
