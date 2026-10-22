extends "res://scripts/character_sound_tests.gd"
## Catches missing original defaults, wrong actor ownership, mistimed releases,
## and recordings being bypassed by recovered audio.
const ORIGINAL="res://assets/audio/recovered_leaders/"
func original(stream: AudioStream,id: int)->bool:
	return stream!=null and stream.resource_path.begins_with(ORIGINAL+("ed/" if id==14 else "ben/"))
func count_original(pool: Array,id: int)->int:
	var count=0
	for voice in pool:
		if voice.playing and original(voice.stream,id):count+=1
	return count
func stop_audio(node: Node):
	if node is AudioStreamPlayer or node is AudioStreamPlayer3D:node.stop()
	for child in node.get_children():stop_audio(child)
func frames(n: int):
	for i in n:await physics_frame
func run():
	game=load("res://scenes/forest_title.tscn").instantiate();game.settings_path=sandbox+"/game.cfg"
	root.add_child(game);current_scene=game;await frames(5)
	game.sound_library.free();lib=new_library();lib.game=game;game.sound_library=lib
	game.begin_forest();game.choose_rogue_character(14);game.start_wave()
	game.tuning.invincible=true;game.tuning.freeze_ai=true
	await frames(8)
	var p=game.player;p.set_physics_process(false)
	for id in [14,15]:
		p.select_character(id);var combat=p.active_ability
		check(original(game.sound_preview(id,"move_primary_1_weapon"),id),"Fighter%d previews its recovered original primary sound"%id)
		check(original(game.sound_preview(id,"move_secondary_weapon"),id),"Fighter%d previews its recovered original projectile release"%id)
		check(original(game.sound_preview(id,"hurt"),id),"Fighter%d hurt default is its source-confirmed damage voice"%id)
		stop_audio(game);combat.cancel();combat.start_attack(false)
		if id==14:
			check(combat.beam.charge.playing,"Ed starts the recovered charge during beam windup")
			check(original(game.sound_preview(14,"move_primary_1_voice"),14),"Ed previews the recovered voice referenced by his beam animation")
		combat.tick(.04)
		check(count_original(game.voices,id)==(0 if id==14 else 1),"Ed windup waits for release; Ben starts original93F at polearm entry")
		combat.tick(.31)
		check(combat.beam.bed.playing if id==14 else count_original(game.voices,id)==1,"Fighter%d actual primary uses its source audio"%id)
		if id==14:
			check(combat.beam.charge.playing and combat.beam.bed.playing,"Ed keeps the source startup and sustained bed as separate layers")
			check(count_original(game.move_audio.voices,14)==1,"Ed's actual beam releases the requested recovered beam voice once")
		if id==15:
			check(count_original(game.move_audio.voices,15)==1,"Ben's polearm starts original A8A once at entry")
			var startup_cursor=game.move_audio.cursor
			combat.tick(44.0/60.0-.35+.001)
			check(game.last_sound_voice.get_meta("kind","")=="ben_polearm_strike_voice" and game.last_sound_voice.stream==SoundLibrary.original_for(15,"ben_polearm_strike_voice"),"Ben's original A8B follows source key44")
			var transition_order=game.voice_idx
			combat.tick(21.0/60.0)
			if combat.polearm_dash_distance>0:
				check(game.last_sound_voice.get_meta("kind","")=="ben_polearm_finish" and game.last_sound_voice.stream==SoundLibrary.original_for(15,"heavy_swing"),"Ben's original93F ends the key49..65 dash stage")
			else:check(game.voice_idx==transition_order,"A skipped near-target dash cannot play its movement or finish sound")
			check(game.move_audio.cursor==startup_cursor,"Later polearm phases cannot release the startup cast voice again")
		for voice in game.voices:
			if voice.playing and original(voice.stream,id):check(is_equal_approx(voice.pitch_scale,1.0),"Fighter%d retains original source playback pitch"%id)
		stop_audio(game);combat.cancel();combat.start_attack(true);combat.tick(1.75 if id==15 else .6)
		check(count_original(game.voices,id)==1,"Each fighter secondary release plays its source-confirmed cast sound once")
		check(count_original(game.move_audio.voices,id)==(1 if id==14 else 0),"Fighter%d projectile voice follows the source move instead of another attack"%id)
		if id==15:
			combat.cancel();combat.start_utility();combat.tick(.34)
			check(count_original(game.move_audio.voices,15)==1,"Ben's original throw voice belongs to the E shuriken fan")
			check(game.last_sound_voice.stream==SoundLibrary.original_for(15,"move_utility_weapon"),"Ben E plays the decoded four-note945 throw sequence")
		var voice_cursor=game.move_audio.cursor
		var released=get_nodes_in_group("leader_projectiles").filter(func(shot):return shot.source_character==id and (id!=15 or shot.bomb)).back()
		p.select_character(1);stop_audio(game);released._finish(released.global_position)
		if id==15:
			check(count_original(game.voices,15)==1 and count_original(game.voices,14)==0,"Ben's released bomb retains its single941boom after switching")
			var detonation_order=game.voice_idx;released._physics_process(1.0)
			check(game.voice_idx==detonation_order and game.last_sound_voice.stream.resource_path.ends_with("/ben/bomb_end.wav"),"The real bomb keeps only its initial boom without a second phase sound")
		check(game.move_audio.cursor==voice_cursor,"Fighter%d projectile impact cannot replay the cast voice"%id)
		p.select_character(id)
		for shot in get_nodes_in_group("leader_projectiles"):shot.set_physics_process(false)
		lib.select_character(id);check(save("move_primary_1_weapon",fixture()),"Fighter%d accepts a custom primary recording"%id)
		check(game.sound_preview(id,"move_primary_1_weapon")==lib.custom_for(id,"move_primary_1_weapon"),"Fighter%d studio recording overrides the recovered default"%id)
		stop_audio(game);combat.cancel();combat.start_attack(false);combat.primary_held=true;combat.tick(1.05 if id==14 else .35)
		check(combat.beam.loop.stream.data==lib.custom_for(id,"move_primary_1_weapon").data if id==14 else game.last_sound_voice.stream==lib.custom_for(id,"move_primary_1_weapon"),"Fighter%d real attack respects its custom recording"%id)
		lib.set_muted("move_primary_1_weapon",true)
		stop_audio(game);combat.cancel();combat.start_attack(false);combat.primary_held=true;combat.tick(1.05 if id==14 else .35)
		check(not combat.beam.loop.playing if id==14 else count_original(game.voices,id)==0,"Fighter%d muted weapon does not play the source default"%id)
		lib.set_muted("move_primary_1_weapon",false)
		combat.cancel();p.select_character(1);stop_audio(game)
		game.sound("heavy_swing",.5,true)
		check(count_original(game.voices,id)==0,"Enemy audio cannot borrow fighter%d's recovered sounds"%id)
	check(not original(game.sound_preview(2,"edo_beam_start"),14),"Edo keeps his own beam audio separate from Ed")
	p.select_character(15);lib.select_character(15)
	for shot in get_nodes_in_group("leader_projectiles"):shot.queue_free()
	p.position=Vector3(0,.05,18);p.velocity=Vector3.DOWN;p.move_and_slide();p.velocity=Vector3.ZERO;p.set_physics_process(true)
	Input.action_press("jump");await frames(20)
	var audio=p.active_ability.original_audio
	check(p.flying and audio.rotor.playing,"Holding Space flies Ben with his original sustained flight sound")
	check(audio.rotor.stream.loop_mode==AudioStreamWAV.LOOP_FORWARD and audio.rotor.stream.loop_begin==28 and audio.rotor.stream.loop_end==3276,"Ben's flight uses the verified audible source loop rather than a terminal silent loop")
	check(is_equal_approx(audio.rotor.pitch_scale,1.0),"Ben's flight loop preserves the original pitch")
	game.paused=true;await frames(2)
	check(audio.rotor.stream_paused,"Pausing also pauses Ben's sustained propeller audio")
	game.paused=false;await frames(2)
	check(audio.rotor.playing and not audio.rotor.stream_paused,"Resuming restores flight audio")
	lib.set_process(false);lib.recording=true;await frames(2)
	check(not audio.rotor.playing,"Recording stops Ben's propeller to keep the microphone take clean")
	lib.recording=false;lib.set_process(true);await frames(2)
	lib.set_muted("ben_propeller",true);await frames(2)
	check(not audio.rotor.playing,"Ben's flight mute stops the loop immediately")
	lib.set_muted("ben_propeller",false);await frames(2)
	check(audio.rotor.playing,"Unmuting restores the loop while Ben remains airborne")
	audio._notification(NOTIFICATION_APPLICATION_FOCUS_OUT);await frames(2)
	check(not audio.rotor.playing,"Losing focus stops the sustained flight sound")
	audio._notification(NOTIFICATION_APPLICATION_FOCUS_IN);await frames(2)
	p.select_character(1);await frames(2)
	check(not audio.rotor.playing,"Switching away from Ben stops his flight sound")
	p.select_character(15);await frames(2)
	p.hp=0;await frames(2)
	check(not audio.rotor.playing,"Defeated Ben cannot leave a propeller loop playing")
	p.hp=p.max_hp
	Input.action_release("jump");await frames(130)
	check(p.is_on_floor() and not audio.rotor.playing,"Releasing Space and landing stops Ben's propeller loop")
	stop_audio(game);game.move_audio.stop();current_scene=null;game.queue_free();await frames(3);game=null
	await create_timer(.35).timeout
	print("RECOVERED_LEADER_AUDIO_RESULT checks=",checks," failures=",failures)
	quit(0 if failures==0 else 1)
