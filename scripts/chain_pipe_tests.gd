extends "res://scripts/power_combat_tests.gd"

func fresh_chain():
	await prepare(1);await key(KEY_3);game.player.invuln=0
func capture(label: String):
	if not visual:return
	game.hud.toast_time=0;game.hud.banner_time=0
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://tests/chain-pipe/"+label+".png")
func run():
	visual="--chain-visual" in OS.get_cmdline_user_args()
	Input.use_accumulated_input=false
	check(ProjectSettings.get_setting("application/config/name")=="Goemon","Game is named Goemon")
	check(OS.get_user_data_dir().ends_with("Godot/app_userdata/Azure Ember"),"Rename retains the existing settings and recording directory")
	await capture("01-title")
	game.tuning=PrototypeTuning.DEFAULTS.duplicate();game.tuning.invincible=true;game.tuning.freeze_ai=true
	game.start_game();game.encounters.enabled=false;game.player.smoke_mode=true
	game.camera_rig.set_process_unhandled_input(false);get_window().set_flag(Window.FLAG_NO_FOCUS,true);Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	var p=game.player
	await fresh_chain()
	check(p.weapon_slot==3 and p.model.chain_pipe.visible and not p.model.pipe.visible and not p.model.coin.visible,"3 selects the chain pipe and hides the other weapons")
	check(ChainPipeVisual.meshes.size()==5 and p.model.chain_pipe.links.multimesh.visible_instance_count>8,"Chain weapon uses the Blender handle, bowl, links and attachment eyes")
	await capture("02-chain-equipped")
	var front=target(Vector3(0,0,-5));var rear=target(Vector3(0,0,-12));var side=target(Vector3(5,0,-8))
	await mouse(true);await mouse(false);await wait(.42)
	check(p.chain_pipe_combat.active and p.chain_pipe_combat.mode=="throw" and p.model.chain_pipe.endpoint_override,"LMB throws an attached, extending chain pipe")
	await capture("03-piercing-throw");await attack_frames();await wait(.1)
	check(front.hp==9940 and rear.hp==9940 and side.hp==10000,"Throw pierces multiple enemies along its path and excludes off-path targets")
	check(not p.model.chain_pipe.endpoint_override and not p.chain_pipe_combat.active,"Head returns to its handle without dealing a second return hit")
	await fresh_chain();front=target(Vector3(0,0,-5));side=target(Vector3(4,0,-3));rear=target(Vector3(0,0,3));var far=target(Vector3(0,0,-11))
	await mouse(true,true);await mouse(false,true);await wait(.38);await capture("04-fan-swing");await attack_frames()
	check(front.hp==9930 and side.hp==9930 and rear.hp==10000 and far.hp==10000,"RMB hits a wide forward fan once; rear and out-of-range enemies are safe")
	await fresh_chain();front=target(Vector3(0,0,-8))
	var wall=Geo.box(game,p.position+Vector3(0,1.5,-4),Vector3(6,4,.4),Geo.mat("888888"),true)
	await wait(.1);await mouse(true);await mouse(false);await attack_frames()
	check(front.hp==10000,"Solid cover stops the thrown tip and its damage")
	wall.queue_free()
	await fresh_chain();game.camera_rig.yaw=PI;await key(KEY_R);await mouse(true)
	var endpoint=p.chain_pipe_combat.end
	var tip_enemy=target(endpoint-p.position-Vector3.UP*1.2);var blast_enemy=target(endpoint-p.position+Vector3(3,-1.2,0))
	tip_enemy.set_physics_process(false);blast_enemy.set_physics_process(false)
	await mouse(false);await wait(.58);await capture("05-powered-explosion");await attack_frames()
	check(tip_enemy.hp==9790 and blast_enemy.hp==9880,"R throw adds a 120-damage endpoint blast to the 90-damage piercing tip: HP %s/%s" % [tip_enemy.hp,blast_enemy.hp])
	await fresh_chain();front=target(Vector3(3,0,-4));await key(KEY_R);await mouse(true,true);await mouse(false,true);await wait(.35)
	check(p.model.chain_pipe.powered and p.model.chain_pipe.flame.visible,"R fan swing has fire on its moving pipe head")
	await capture("06-fire-fan");await attack_frames();check(front.hp==9890,"Powered fan applies its stronger fire attack damage")
	var durations=[]
	for boosted in [false,true]:
		await fresh_chain();front=target(Vector3(0,0,-5))
		if boosted:p.collect_powerup("attack_speed");p.collect_powerup("damage")
		await mouse(true);await mouse(false);durations.append(await attack_frames())
		check(front.hp==(9910 if boosted else 9940),"Chain throw obeys damage orbs, boosted="+str(boosted))
	check(durations[1]<durations[0]*.76,"Attack speed accelerates extension and return: "+str(durations))
	await fresh_chain();await mouse(true);await mouse(false);await key(KEY_2)
	check(not p.chain_pipe_combat.active and not p.model.chain_pipe.visible and p.weapon_slot==2,"Weapon switching cancels and hides an active chain")
	await key(KEY_1);check(p.model.pipe.visible and not p.model.chain_pipe.visible,"1 restores the original pipe")
	await key(KEY_3);await mouse(true,true);await mouse(false,true);game.show_pause();game.resume()
	check(not p.chain_pipe_combat.active and not p.model.chain_pipe.endpoint_override,"Pause safely retracts the chain and clears pending damage")
	await key(KEY_Q);await key(KEY_3)
	check(p.character_id==2 and p.musashi.ranged_mode,"3 does not alter Edo's fixed firecaster moveset")
	await key(KEY_Q);await key(KEY_3);target(Vector3(0,0,-6));await mouse(true);await mouse(false);await key(KEY_T)
	check(not p.chain_pipe_combat.active,"Goemon's T cleanly interrupts the chain weapon")
	await fresh_chain();game.restart_area();game.encounters.enabled=false;await wait(.1)
	check(p.weapon_slot==1 and not p.model.chain_selected and not p.model.chain_pipe.visible,"Restart restores pipe selection and clears chain visuals")

	await prepare(1);var enemy=target(Vector3(0,0,-4));enemy.state="windup";enemy.timer=.4
	var torus_count=0
	for node in enemy.get_children():
		if node is MeshInstance3D and node.mesh is TorusMesh:torus_count+=1
	check(torus_count==0,"Enemies have no attack-range ring geometry")
	check(p.charge_ring is Node3D and not p.charge_ring is MeshInstance3D and p.aura.bands.is_empty(),"Player charge and ground aura circles are removed")
	await prepare(2);await key(KEY_T);await wait(.55)
	var rains=get_tree().get_nodes_in_group("edo_meteor_rains")
	check(not rains.is_empty() and not rains[0].strikes[0].has("marker"),"Meteor rain no longer creates target/range circles")
	p.cancel_charge()

	# Synthetic recordings exercise all new slots without opening the microphone.
	var lib=game.sound_library;var saved_custom=lib.custom.duplicate();var saved_gains=lib.gains.duplicate();var folder=lib.folder
	lib.folder="user://chain_sound_test";DirAccess.make_dir_recursive_absolute(lib.folder)
	var data=PackedVector2Array()
	for i in range(8000):data.append(Vector2.ONE*sin(i*.1)*.15)
	var fixture=lib.make_take(data,48000)
	var keys=["spin_swing","giant_toss","sky_leap","sky_stomp","chain_throw","chain_sweep","chain_hit","chain_explosion","chain_fire_sweep","edo_volley","edo_giant","fire_impact","edo_shield","edo_beam_start","edo_beam_loop","edo_meteor_cast","edo_meteor_strike","edo_meteor_impact","edo_dodge","edo_dodge_impact"]
	var all_routed=true
	for slot in keys:
		all_routed=all_routed and lib.SLOTS.has(slot) and game.sounds.has(slot)
		lib.take=fixture;lib.take_slot=slot
		all_routed=all_routed and lib.save_take()
		game.sound(slot)
		all_routed=all_routed and game.last_sound_voice.stream==fixture and game.last_sound_voice.pitch_scale==1.0
		DirAccess.remove_absolute(lib.folder+"/"+slot+".wav")
	check(all_routed,"All 20 newer attack slots save and play custom recordings at original pitch")
	await prepare(2);await key(KEY_R);await mouse(true)
	check(p.musashi.beam.loop.stream.data==fixture.data and p.musashi.beam.loop.stream.loop_mode==AudioStreamWAV.LOOP_FORWARD and p.musashi.beam.loop.pitch_scale==1.0,"Held beam loops the selected custom recording")
	await mouse(false);lib.custom=saved_custom;lib.gains=saved_gains;lib.folder=folder
	game.show_pause();game.show_sound_studio(true);await wait(.1)
	var studio=game.menu.find_children("*","",true,false).filter(func(n):return n is SoundStudio)
	check(studio.size()==1,"Sound Studio is available for newer attacks")
	if not studio.is_empty():
		var panel=studio[0];panel.search.text="Chain pipe";panel.search.text_changed.emit(panel.search.text);await wait(.05)
		check(panel.slots.item_count==5 and panel.slot.begins_with("chain_"),"Recording search exposes and selects the five chain-weapon sounds")
		await capture("07-chain-recording-slots")
		panel.search.text="Edo";panel.search.text_changed.emit(panel.search.text);await wait(.05)
		check(panel.slots.item_count==11 and not lib.recording,"All Edo attacks are recordable; browsing never opens the microphone")
		await capture("08-edo-recording-slots")
	game.show_main_menu();await wait(.1)
	print("CHAIN_RESULT failures=",failures)
	get_tree().quit(1 if failures else 0)
