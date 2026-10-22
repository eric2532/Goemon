extends "res://scripts/character_sound_tests.gd"
## Real playback and confirmed damage: original sounds cannot bleed into other
## heroes/enemies, or mistake Fusion's third cut for a Lumina hit.
const ORIGINAL="res://assets/audio/recovered_musashi/"
func original(stream: AudioStream,name: String="")->bool:
	return stream!=null and (stream.resource_path.begins_with(ORIGINAL) if name.is_empty() else stream.resource_path==ORIGINAL+name+".wav")
func count_original(pool: Array,name: String="")->int:
	var result=0
	for voice in pool:
		if voice.playing and original(voice.stream,name):result+=1
	return result
func stop_audio(node: Node):
	if node is AudioStreamPlayer or node is AudioStreamPlayer3D:node.stop()
	for child in node.get_children():stop_audio(child)
func frames(n: int):
	for i in n:await physics_frame
func run():
	game=load("res://scenes/forest_title.tscn").instantiate();game.settings_path=sandbox+"/game.cfg"
	root.add_child(game);current_scene=game;await frames(5)
	game.sound_library.free();lib=new_library();lib.game=game;game.sound_library=lib
	game.begin_forest();game.choose_rogue_character(13);game.start_wave()
	game.tuning.invincible=true;game.tuning.freeze_ai=true;game.tuning.critical_chance=0;game.character_tuning={}
	await frames(8)
	var p=game.player;p.set_physics_process(false)
	var c=p.active_ability
	for entry in [["swing","fusion_swing"],["heavy_swing","lumina_swing"],["hit","sword_hit"],["heavy_hit","sword_hit"]]:
		check(original(game.sound_preview(13,entry[0]),entry[1]),"Musashi previews the original "+entry[1])
	check(game.sound_preview(13,"move_primary_1_voice")==null,"Retail inactive normal-sword voice remains silent by default")
	check(game.sound_preview(13,"jump")==null and original(game.sound_preview(13,"hurt")),"Unconfirmed jump audio is silent while original hurt audio remains available")
	check(original(game.sound_preview(13,"land"),"foot_contact"),"Actual air landing uses source 0x42E rather than the source 0x41E run-stop sound")
	check(not original(game.sound_preview(2,"swing")) and game.sound_preview(3,"move_primary_1_voice")==null,"Original Musashi defaults stay isolated from Edo and native heroes")
	c.cancel();stop_audio(game)
	p.model.native_motion=true;p.model.was_moving=false;p.model.was_grounded=true;c.locomotion.source_speed=-0x80000
	var step_start=game.voice_idx
	p.model.animate(0,4.35,true,0,0,false,0,false);p.model.animate(1.0/30.0,4.35,true,0,0,false,0,false)
	check(game.voice_idx==step_start,"Run footstep waits for the source body marker")
	p.model.animate(1.0/30.0,4.35,true,0,0,false,0,false)
	check(game.voice_idx==step_start+1 and original(game.last_sound_voice.stream,"foot_contact"),"Source run tick 2 plays the recovered terrain-0 footstep")
	p.model.animate(0,4.35,true,0,0,false,0,false)
	check(game.voice_idx==step_start+1,"Resampling a source pose cannot duplicate a footstep")
	p.model.animate(8.0/30.0,4.35,true,0,0,false,0,false)
	check(game.voice_idx==step_start+2,"Source run tick 10 plays the second footstep once")
	c.locomotion.state="stop";c.locomotion.source_speed=-0x40000;c.locomotion.stop_ticks=0
	step_start=game.voice_idx;p.model.animate(1.0/30.0,2.16,true,0,0,false,0,false)
	check(game.voice_idx==step_start+1 and original(game.last_sound_voice.stream,"land"),"Full-speed skid plays the source 0x41E stop event at entry")
	p.model.animate(.3,2.16,true,0,0,false,0,false)
	check(game.voice_idx==step_start+1,"A skid cannot also emit ordinary walking footstep markers")
	c.locomotion.reset()
	p.model.native_motion=false
	stop_audio(game);game.sound("heavy_swing",.7,true)
	check(count_original(game.voices)==0,"Enemy swing audio never borrows Musashi's original sword sound")
	c.cancel();stop_audio(game);c.start_attack(false)
	check(count_original(game.voices,"fusion_swing")==1,"Actual Fusion attack plays its original swing")
	check(count_original(game.move_audio.voices)==0,"An actual Fusion attack does not invent a grunt for the inactive retail event")
	var voice_count=game.move_audio.cursor
	c.tick(.08);c.tick(.05)
	check(game.move_audio.cursor==voice_count,"Contact frames cannot repeat a move's voice")
	for voice in game.voices:
		if original(voice.stream):check(is_equal_approx(voice.pitch_scale,1.0),"Original samples keep the source pitch")
	c.cancel();stop_audio(game);c.start_attack(true)
	check(c.clip=="Extra__800d4f14","Lumina uses the original normal-sword clip")
	check(count_original(game.voices,"lumina_swing")==1,"Lumina initializer plays its original swing at action entry")
	c.tick(8.0/30.0)
	check(count_original(game.voices,"lumina_swing")==1,"Contact does not duplicate the original Lumina swing")
	check(p.model.has_method("sword_segment"),"Weapon trails can sample the actual animated blade")
	if p.model.has_method("sword_segment"):
		c.elapsed=8.0/30.0;p.model.animate(1.0/30.0,0,true,0,.5,true,0,false)
		var high: PackedVector3Array=p.model.sword_segment(true)
		c.elapsed=9.0/30.0;p.model.animate(1.0/30.0,0,true,0,.2,true,0,false) # Native descriptor delay/seed update.
		c.elapsed=12.0/30.0;p.model.animate(1.0/30.0,0,true,0,.2,true,0,false)
		var low: PackedVector3Array=p.model.sword_segment(true)
		check(high.size()==2 and low.size()==2 and high[1].distance_to(low[1])>.25,"Lumina's visible tip follows the original strike across its active window")
		check(p.model.sword_trail.mesh!=null,"Lumina trail follows sampled blade positions")
	# Real Forest victim, placed in the existing melee resolver's range.
	c.cancel();p.position=Vector3(0,.05,18);p.velocity=Vector3.DOWN;p.move_and_slide();p.velocity=Vector3.ZERO;p.facing=Vector3.FORWARD;p.model.rotation=Vector3.ZERO
	game.model.waves.spawn_one()
	var target=game.model.enemies.values().back()
	target.pos=p.position+Vector3.FORWARD*1.3;target.hp=1000;target.max_hp=1000;target.stun=100
	game.model.update_vision(p.position);game.sync_enemies()
	var enemy=game.actors[target.id]
	stop_audio(game);game.confirm_ally_impact(enemy,target.pos,Vector3.FORWARD,0,false,1)
	check(count_original(game.voices)==0,"Goemon allies never borrow Musashi's original hit while Musashi is selected")
	stop_audio(game);game.confirm_ally_impact(enemy,target.pos,Vector3.FORWARD,0,false,13)
	check(count_original(game.voices,"sword_hit")==1,"Musashi allies resolve their own original impact default")
	c.combo=1;c.combo_timer=1;stop_audio(game);c.primary_attack();c.tick(.21)
	check(enemy.hp<1000 and count_original(game.voices,"fusion_finisher_hit")==1,"Confirmed Fusion finisher uses its original stronger entity-hit variant")
	check(count_original(game.voices,"sword_hit")==0,"Fusion finisher does not fall back to the normal sword hit")
	c.cancel();stop_audio(game);var hp=enemy.hp;c.start_attack(true);c.tick(.26)
	check(enemy.hp==hp and count_original(game.voices,"sword_hit")==0,"Lumina windup cannot play an impact before source tick 8")
	c.tick(.02)
	check(enemy.hp<hp and count_original(game.voices,"sword_hit")==1,"Confirmed Lumina contact plays its original hitting sound")
	c.cancel();stop_audio(game);target.pos=Vector3(40,0,40);enemy.position=target.pos
	enemy.fitted_pose_dirty=true;enemy._sync_fitted_pose()
	game.sync_enemies() # Refresh the actor-owned cached hurt volume as well.
	c.start_attack(true);c.tick(.51)
	check(count_original(game.voices,"sword_hit")==0,"Missing an enemy never plays a sword-on-enemy hit")
	c.cancel();lib.select_character(13);save("move_primary_1_voice",fixture())
	check(game.sound_preview(13,"move_primary_1_voice")==lib.custom_for(13,"move_primary_1_voice"),"Saved voice recordings still override original defaults")
	lib.set_muted("move_primary_1_voice",true);voice_count=game.move_audio.cursor
	c.primary_attack()
	check(game.move_audio.cursor==voice_count,"Voice mute still applies to Musashi")
	c.cancel();stop_audio(game);game.move_audio.stop()
	var ally=load("res://scripts/forest/forest_gate_defender.gd").new()
	ally.game=game;game.add_child(ally);ally.select_character(13);ally.set_physics_process(false)
	p.select_character(1);stop_audio(game);ally.active_ability.start_attack(false)
	check(count_original(game.voices,"fusion_swing")==1,"Musashi allies keep their original swing when Goemon is selected")
	check(count_original(game.move_audio.voices)==0,"Off-player ally swings preserve the existing local-player voice policy")
	ally.active_ability.cancel();ally.select_character(1);p.select_character(13)
	stop_audio(game);ally.attack_heavy=true;ally.play_swing_sound()
	check(count_original(game.voices)==0,"Inherited Goemon ally heavy swing never borrows Lumina")
	stop_audio(game);ally.wall_jump_normal=Vector3.RIGHT;ally.perform_wall_jump()
	check(count_original(game.voices)==0,"Inherited Goemon ally ground contact never borrows Musashi landing")
	ally.queue_free()
	p.select_character(1);lib.select_character(1)
	save("move_evade_weapon",fixture());save("move_evade_voice",fixture(22050))
	p.attack_ticket=p.attack_chain.begin("pipe","primary_1");p.attack_chain.reset()
	p.dodge_cooldown=0;stop_audio(game)
	var evade=InputEventAction.new();evade.action="dodge";evade.pressed=true;p._unhandled_input(evade)
	check(game.last_sound_voice.stream==game.sound_preview(1,"move_evade_weapon") and game.last_sound_voice.stream!=lib.custom_for(1,"move_evade_weapon"),"Goemon dodge after chain reset bypasses its saved take consistently with preview")
	var evade_voiced=false
	for voice in game.move_audio.voices:
		if voice.playing and voice.stream==lib.custom_for(1,"move_evade_voice"):evade_voiced=true
	check(not evade_voiced and lib.custom_for(1,"move_evade_voice")!=null,"Goemon dodge preserves its recorded voice without playing it under original-only preference")
	game.queue_free();await process_frame;await process_frame;game=null
	lib.game=null;lib.free();await create_timer(.35).timeout
	print("MUSASHI_AUDIO_RESULT checks=",checks," failures=",failures)
	finish()
