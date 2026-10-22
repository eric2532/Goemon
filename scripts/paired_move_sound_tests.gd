extends "res://scripts/character_sound_tests.gd"
## Real saved WAVs, production playback pools, and actual Forest attack tickets.
func pool_count(pool: Array,stream: AudioStream)->int:
	var count=0
	for voice in pool:
		if voice.stream==stream and voice.playing:count+=1
	return count
func run():
	lib=new_library()
	check(lib.has_method("moves_for") and lib.has_method("is_muted_for"),"Each character exposes paired move slots and independent mute settings")
	if failures:lib.free();finish();return
	var catalog_ok=true
	for id in range(1,13):
		var moves: Dictionary=lib.moves_for(id)
		catalog_ok=catalog_ok and not moves.is_empty()
		for key in moves:
			var move: Dictionary=moves[key]
			catalog_ok=catalog_ok and lib.slots_for(id).has(move.weapon) and lib.slots_for(id).has(move.voice) and lib.slots_for(id).has(move.legacy)
	check(catalog_ok,"All twelve move catalogs retain their legacy defaults and expose both editable layers")
	check(lib.moves_for(4).has("primary_5") and lib.moves_for(3).has("primary_3"),"Samurai's five cuts and Pirate's three cuts have independent move slots")
	DirAccess.make_dir_recursive_absolute(sandbox)
	var weapon=fixture();var voice=fixture(22050)
	lib.select_character(3)
	check(save("move_primary_1_weapon",weapon) and save("move_primary_1_voice",voice),"A move saves separate weapon and voice WAVs")
	lib.set_gain("move_primary_1_weapon",.4);lib.set_gain("move_primary_1_voice",1.6)
	lib.set_muted("move_primary_1_weapon",true)
	lib.free();lib=new_library();lib.select_character(3)
	check(lib.is_muted_for(3,"move_primary_1_weapon") and not lib.is_muted_for(3,"move_primary_1_voice"),"Mute survives reload without muting the other layer")
	check(is_equal_approx(lib.gain_for(3,"move_primary_1_weapon"),.4) and is_equal_approx(lib.gain_for(3,"move_primary_1_voice"),1.6),"Independent layer gains survive reload")
	check(lib.custom_for(4,"move_primary_1_voice")==null,"Paired recordings stay isolated by character")
	game=load("res://scenes/forest_title.tscn").instantiate();game.settings_path=sandbox+"/game.cfg";root.add_child(game);current_scene=game
	for i in 4:await process_frame
	game.sound_library.free();lib.game=game;game.sound_library=lib
	var p=game.player;p.smoke_mode=true;p.select_character(3)
	check(game.sound_preview(1,"move_primary_1_weapon")==lib.original_for(1,"move_primary_1_weapon") and game.sound_preview(1,"move_primary_3_weapon")==lib.original_for(1,"move_primary_3_weapon"),"Current Forest Goemon previews use the recovered original light and finisher sounds")
	check(game.sound_preview(3,"move_primary_2_voice")==null,"Unrecorded voices have a silent default")
	check(game.sound_preview(4,"move_primary_5_weapon")!=null,"A combo-stage weapon has its authored built-in preview")
	lib.listen_pair(3,"primary_1")
	check(not lib.preview.playing and lib.preview_voice.playing and lib.preview_voice.stream==lib.custom_for(3,"move_primary_1_voice"),"Listen Together respects weapon mute while playing the voice layer")
	var preview_gain: float=db_to_linear(lib.preview_voice.volume_db)
	lib.cancel();lib.set_muted("move_primary_1_weapon",false)
	game.settings.volume=.4
	p.active_ability.sound.last_events.clear();p.active_ability.action("cutlass")
	p.active_ability.tick(.12,false)
	check(pool_count(game.move_audio.voices,lib.custom_for(3,"move_primary_1_voice"))==1,"An actual Pirate primary releases its recorded voice once with its weapon")
	check(is_equal_approx(db_to_linear(game.move_audio.voices[0].volume_db),preview_gain),"Voice preview and gameplay use the same saved layer gain before Master volume")
	var count: int=game.move_audio.cursor
	check(pool_count(p.active_ability.sound.voices,lib.custom_for(3,"move_primary_1_weapon"))==1,"The actual primary weapon event uses the move's weapon take")
	for i in 5:
		p.active_ability.sound.last_events.clear();p.active_ability.sound.play("hit")
	check(game.move_audio.cursor==count,"Enemy impacts cannot repeat the attack voice")
	lib.set_muted("move_primary_1_voice",true)
	p.active_ability.player.attack=null;p.active_ability.player.cooldowns.cutlass=0;p.active_ability.combo=0;p.active_ability.combo_timer=0
	p.active_ability.action("cutlass")
	p.active_ability.sound.last_events.clear();p.active_ability.tick(.12,false)
	check(game.move_audio.cursor==count,"A muted voice remains silent on the next actual attack")
	lib.set_muted("move_primary_1_voice",false);lib.reset_slot("move_primary_1_voice")
	check(lib.custom_for(3,"move_primary_1_voice")==null and lib.gain_for(3,"move_primary_1_voice")==1.0 and not lib.is_muted_for(3,"move_primary_1_voice"),"Restoring voice defaults clears only its recording, gain, and mute")
	check(lib.custom_for(3,"move_primary_1_weapon")!=null,"Restoring voice preserves the paired weapon")
	# A move without its own weapon take inherits the old recording and gain.
	save("native_blade",weapon);lib.set_gain("native_blade",.7);lib.set_gain("move_primary_2_weapon",.6)
	lib.listen_pair(3,"primary_2")
	check(lib.preview.stream==lib.custom_for(3,"native_blade") and is_equal_approx(db_to_linear(lib.preview.volume_db),.55*.7*.6),"Paired weapon preview inherits legacy recording and multiplies its saved gain")
	lib.cancel();p.active_ability.player.attack=null;p.active_ability.player.cooldowns.cutlass=0;p.active_ability.combo=1;p.active_ability.combo_timer=1
	p.active_ability.sound.last_events.clear();p.active_ability.action("cutlass");p.active_ability.tick(.12,false)
	var last=p.active_ability.sound.voices[(p.active_ability.sound.cursor+27)%28]
	check(last.stream==lib.custom_for(3,"native_blade") and is_equal_approx(db_to_linear(last.volume_db),.55*.7*.6),"The same inherited weapon stream and gain reach actual attack playback")
	lib.set_muted("native_blade",true);lib.listen_pair(3,"primary_2")
	check(not lib.preview.playing,"Legacy weapon mute also silences an inheriting paired preview")
	lib.set_muted("native_blade",false)
	# Every authored native primary routes through its actual cast/release path.
	for id in range(3,13):
		game.move_audio.stop();lib.select_character(id);save("move_primary_1_voice",voice)
		p.select_character(id);p.active_ability.reset_run()
		# Dragoon now routes an airborne left click to Dragon Leap. Test his
		# ordinary thrust voice from a real grounded body.
		if id==8:
			for i in 120:p.active_ability._move_body(1.0/60)
			p.active_ability.player.pos=p.global_position
		p.active_ability.sound.last_events.clear();p.active_ability.action("cutlass")
		if id==6:preload("res://assets/rogue/scripts/class_actions.gd").release_charge(p.active_ability)
		else:p.active_ability.tick(.25,false)
		check(pool_count(game.move_audio.voices,lib.custom_for(id,"move_primary_1_voice"))==1,"Actual native primary voices once for character %d"%id)
	# A buff can replace the foreground ticket during an earlier cut's windup.
	game.move_audio.stop();lib.select_character(4);p.select_character(4);p.active_ability.reset_run()
	p.active_ability.sound.last_events.clear();p.active_ability.action("cutlass")
	var cut_ticket: Dictionary=p.active_ability.player.attack.ticket
	p.active_ability.action("drink");p.active_ability.tick(.12,false)
	check(cut_ticket.move_audio.voiced and pool_count(game.move_audio.voices,lib.custom_for(4,"move_primary_1_voice"))==1,"A cut resolves its own voice after an intervening buff changes the foreground ticket")
	# Background Goemon coins must not consume or replace the pending pipe pair.
	game.move_audio.stop();lib.select_character(1);save("move_primary_1_voice",voice);save("move_coin_voice",weapon)
	p.select_character(1);p.start_attack(false,1)
	var pipe_ticket: Dictionary=p.attack_chain.active_ticket
	game.throw_coin(false,false,1.0,p.attack_chain.make_ticket("coin"),true)
	check(pipe_ticket.move_audio.voiced and pool_count(game.move_audio.voices,lib.original_for(1,"move_coin_voice"))==1,"A background coin voices its original release independently of the pipe entry grunt")
	if p.rogue_pipe_combo.sound!=null:p.rogue_pipe_combo.sound.last_events.clear()
	p.play_swing_sound()
	check(pipe_ticket.move_audio.voiced and pool_count(game.move_audio.voices,lib.original_for(1,"move_primary_1_voice"))==1,"Goemon's pipe retains one original entry grunt after a background volley")
	game.move_audio.stop();lib.select_character(2);save("move_volley_voice",voice);p.select_character(2)
	p.musashi.cast_fireball(false);p.musashi.tick(.3,false);p.musashi.after_pose()
	check(pool_count(game.move_audio.voices,lib.custom_for(2,"move_volley_voice"))==1,"Edo's triple fireball releases one voice for its shared volley")
	for id in [7,12]:
		game.move_audio.stop();lib.select_character(id);save("move_secondary_voice",voice)
		p.select_character(id);p.active_ability.reset_run();p.active_ability.action("flintlock")
		check(pool_count(game.move_audio.voices,lib.custom_for(id,"move_secondary_voice"))==1,"Accepted guard activation voices without requiring an incoming hit (%d)"%id)
	game.move_audio.stop();lib.select_character(2);p.select_character(2)
	save("move_beam_weapon",weapon);lib.set_gain("move_beam_weapon",.6);lib.set_muted("move_beam_weapon",true)
	p.musashi.shield_left=5;p.musashi.start_beam()
	check(not p.musashi.beam.loop.playing,"Paired beam weapon mute also silences its sustained loop")
	p.musashi.cancel_beam();lib.set_muted("move_beam_weapon",false);p.musashi.start_beam()
	check(p.musashi.beam.loop.stream.data==weapon.data and is_equal_approx(db_to_linear(p.musashi.beam.loop.volume_db),.35*.6),"Sustained beam uses the paired weapon recording and gain")
	p.musashi.cancel_beam()
	check(game.sound_preview(10,"move_primary_3_weapon")==load("res://assets/rogue/audio/bow-power.wav") and game.sound_preview(4,"move_utility_weapon")==load("res://assets/rogue/audio/bow-power.wav"),"Power-arrow move previews match Ranger's third shot and Samurai's utility")
	lib.select_character(3);lib.take=voice;lib.take_slot="move_primary_1_weapon";lib.listen(lib.take,lib.take_slot)
	check(lib.preview.stream==voice and is_equal_approx(db_to_linear(lib.preview.volume_db),.55*.4),"Listen to take plays the new pending take rather than the previous saved weapon")
	lib.discard();game.move_audio.stop();lib.select_character(1)
	if lib.slots_for(1).has("move_surge_voice"):save("move_surge_voice",voice)
	p.select_character(1);p.activate_surge()
	check(pool_count(game.move_audio.voices,lib.original_for(1,"move_surge_voice"))==1,"Goemon's accepted R surge bypasses saved takes for its original paired voice")
	# Dragoon's new grounded sweep has its own pair; airborne Leap preserves
	# the original secondary recordings and releases only once on landing.
	game.move_audio.stop();lib.select_character(8)
	save("move_sweep_weapon",weapon);save("move_sweep_voice",voice);save("move_secondary_voice",voice)
	p.select_character(8);p.active_ability.reset_run()
	p.position=Vector3(0,.1,70);p.velocity=Vector3.ZERO
	for i in 120:p.active_ability._move_body(1.0/60)
	for channel in p.active_ability.sound.voices:channel.stop()
	p.active_ability.player.pos=p.global_position
	p.active_ability.sound.last_events.clear();p.active_ability.action("flintlock");p.active_ability.tick(1.0,false)
	check(pool_count(game.move_audio.voices,lib.custom_for(8,"move_sweep_voice"))==1,"Three-hit Dragoon sweep releases its separate voice once")
	check(pool_count(p.active_ability.sound.voices,lib.custom_for(8,"move_sweep_weapon"))==1,"Dragoon sweep uses its separate recorded weapon layer")
	game.move_audio.stop();p.active_ability.player.attack=null;p.active_ability.player.cooldowns.flintlock=10
	p.jump_buffer=.15
	for i in 20:p.active_ability._move_body(1.0/120)
	p.active_ability.action("cutlass")
	var leap_ticket: Dictionary=p.active_ability.player.travel.ticket if p.active_ability.player.travel!=null else {}
	if p.active_ability.player.travel!=null:p.active_ability.player.travel.target=Vector3(p.position.x,0,p.position.z)
	check(leap_ticket.get("move_audio",{}).get("move_key","")=="secondary","Airborne LMB keeps Dragon Leap's existing recording group")
	for i in 180:p.active_ability.step_travel(1.0/120)
	check(pool_count(game.move_audio.voices,lib.custom_for(8,"move_secondary_voice"))==1,"Dragon Leap's impact releases its preserved voice once")
	for node in [game]:stop_audio(node)
	lib.game=null;game.sound_library=null;game.queue_free()
	for i in 4:await process_frame
	lib.free();await create_timer(.2).timeout
	finish()
func stop_audio(node: Node):
	if node is AudioStreamPlayer or node is AudioStreamPlayer3D:node.stop()
	for child in node.get_children():stop_audio(child)
func finish():
	if DirAccess.dir_exists_absolute(sandbox):remove_sandbox(sandbox)
	print("PAIRED_MOVE_SOUND_RESULT checks=",checks," failures=",failures)
	quit(1 if failures else 0)
