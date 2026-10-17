extends "res://tests/forest-shrine/explorer_close_assist_test.gd"
## Real Forest attacks must play Dragoon's isolated spear assets, once per cast.
var sandbox="user://dragoon-lance-audio-%s"%OS.get_process_id()
func last_voice(combat)->AudioStreamPlayer:
	return combat.sound.voices[(combat.sound.cursor+27)%28]
func stop_voices(combat):
	for channel in combat.sound.voices:channel.stop()
func run():
	game=load("res://scenes/forest_shrine.tscn").instantiate();game.settings_path=sandbox+"/game.cfg"
	root.add_child(game);current_scene=game;await frames(3)
	game.sound_library.free()
	var lib=SoundLibrary.new();lib.folder=sandbox+"/recordings";lib.config_path=sandbox+"/studio.cfg"
	game.sound_library=lib;lib.game=game;game.add_child(lib)
	game.start_wave();game.model.waves.spawn_clock=10000;game.model.waves.pending=0
	game.set_physics_process(false);game.player.set_physics_process(false);game.camera_rig.set_process(false)
	game.tuning.invincible=true;game.player.smoke_mode=true;game.player.smoke_move=Vector2.ZERO
	for index in 3:
		await fresh(8);var combat=game.player.active_ability
		stop_voices(combat);combat.sound.last_events.clear();combat.combo=index;combat.combo_timer=1
		var before: int=combat.sound.cursor
		combat.action("cutlass");combat.tick(.09,false)
		check(combat.sound.cursor==before,"Thrust %d waits for contact before playing"%(index+1))
		combat.tick(.02,false)
		var expected="res://assets/rogue/audio/thrust-dragoon-%d.wav"%index
		check(combat.sound.cursor==(before+1)%28 and last_voice(combat).stream.resource_path==expected,"Actual left-click %d plays its selected spear thrust"%(index+1))
		var preview=game.sound_preview(8,"move_primary_%d_weapon"%(index+1))
		check(preview!=null and preview.resource_path==expected,"Sound Studio previews the same thrust %d"%(index+1))
	await fresh(8);var combat=game.player.active_ability
	stop_voices(combat);combat.sound.last_events.clear();var before: int=combat.sound.cursor
	combat.action("flintlock");combat.tick(.21,false)
	check(combat.sound.cursor==before,"Sweep stays silent before its first strike")
	combat.tick(.26,false)
	var sweep_path="res://assets/rogue/audio/sweep-dragoon.wav"
	check(combat.sound.cursor==(before+1)%28 and last_voice(combat).stream.resource_path==sweep_path,"Three-hit right-click plays one layered Dragoon sweep")
	var preview=game.sound_preview(8,"move_sweep_weapon")
	check(preview!=null and preview.resource_path==sweep_path,"Sound Studio previews the new sweep")
	check(game.sound_preview(9,"move_primary_1_weapon").resource_path=="res://assets/rogue/audio/claymore-sweep-0.wav","Magic Swordsman retains his own existing claymore sound")
	check(game.sound_preview(8,"move_secondary_weapon").resource_path=="res://assets/rogue/audio/slam.wav","Dragon Leap retains its separate landing impact")
	# A real saved take must still replace the new built-in asset at original pitch.
	lib.select_character(8)
	var samples=PackedVector2Array()
	for i in 4000:samples.append(Vector2.ONE*sin(float(i)*TAU*440/16000)*.15)
	lib.take=lib.make_take(samples,16000);lib.take_slot="move_sweep_weapon"
	check(lib.save_take(),"An isolated custom sweep recording saves normally")
	await fresh(8);combat=game.player.active_ability;combat.sound.last_events.clear();stop_voices(combat)
	game.player.powerups.attack_speed=20;game.player.attack_speed_stacks=2
	combat.action("flintlock");combat.tick(.47,false)
	check(last_voice(combat).stream==lib.custom_for(8,"move_sweep_weapon") and last_voice(combat).pitch_scale==1.0,"Custom sweep recording keeps priority and original pitch")
	check(game.sound_preview(8,"move_sweep_weapon")==lib.custom_for(8,"move_sweep_weapon"),"Custom recording also remains the Studio preview")
	game.player.clear_powerups()
	lib.set_muted("move_sweep_weapon",true)
	await fresh(8);combat=game.player.active_ability;combat.sound.last_events.clear();stop_voices(combat);before=combat.sound.cursor
	combat.action("flintlock");combat.tick(.47,false)
	check(combat.sound.cursor==before,"Saved sweep mute still suppresses the weapon layer")
	game.queue_free();paused=false;await frames(3)
	remove_folder(sandbox)
	print("DRAGOON_LANCE_AUDIO_RESULT checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)
func remove_folder(path: String):
	var dir=DirAccess.open(path)
	if dir==null:return
	for name_ in dir.get_files():DirAccess.remove_absolute(path+"/"+name_)
	for name_ in dir.get_directories():remove_folder(path+"/"+name_)
	DirAccess.remove_absolute(path)
