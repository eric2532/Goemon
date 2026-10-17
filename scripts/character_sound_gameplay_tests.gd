extends "res://scripts/character_sound_tests.gd"
## Exercises actual Forest heroes, native attack facades, and Edo's looping beam.
func frames(count: int):
	for i in range(count):await process_frame
func pool_has(pool: Node,stream: AudioStream)->bool:
	for voice in pool.voices:
		if voice.stream==stream and voice.playing:return true
	return false
func stop_audio(node: Node):
	if node is AudioStreamPlayer or node is AudioStreamPlayer3D:node.stop()
	for child in node.get_children():stop_audio(child)

func run():
	DirAccess.make_dir_recursive_absolute(sandbox)
	game=load("res://scenes/forest_title.tscn").instantiate()
	game.settings_path=sandbox+"/game.cfg"
	root.add_child(game);current_scene=game
	await frames(4)
	game.sound_library.free();lib=new_library();lib.game=game;game.sound_library=lib
	var first=fixture();var second=fixture(22050)
	lib.select_character(1);save("swing",first);save("heavy_swing",second)
	lib.select_character(2);save("edo_beam_loop",second);lib.set_gain("edo_beam_loop",.7)
	lib.select_character(3);save("native_blade",first)
	lib.select_character(9);save("native_claymore-sweep",second)
	game.player.smoke_mode=true
	game.player.select_character(3)
	var pirate=game.player.active_ability
	pirate.sound.last_events.clear();pirate.action("cutlass");pirate.tick(.12)
	check(pool_has(pirate.sound,first),"Actual Pirate cutlass attack reaches Pirate's saved recording")
	game.player.select_character(9)
	var swordsman=game.player.active_ability
	swordsman.sound.last_events.clear();swordsman.action("cutlass");swordsman.tick(.13)
	check(pool_has(swordsman.sound,second),"Actual Magic Swordsman swing reaches its own recorded take")
	game.player.select_character(1)
	var combo=game.player.rogue_pipe_combo
	combo.prepare();combo.sound.last_events.clear();combo.release(1)
	check(pool_has(combo.sound,first),"Goemon's native combo adapter reaches the Goemon light-swing recording")
	combo.sound.last_events.clear();combo.release(3)
	check(pool_has(combo.sound,second),"Goemon's combo finisher reaches the Goemon heavy-swing recording")
	game.player.select_character(2);lib.select_character(3)
	game.player.musashi.shield_left=5;game.player.musashi.start_beam()
	var beam=game.player.musashi.beam
	check(is_instance_valid(beam) and beam.loop.stream.data==second.data and beam.loop.pitch_scale==1.0,"Actual Edo beam loops Edo's recording while another hub is selected")
	check(is_equal_approx(db_to_linear(beam.loop.volume_db),.35*.7),"Edo beam consumes Edo's saved slot volume")
	lib.configure_capture();lib.mic.stream=first;lib.begin("jump")
	check(not beam.loop.playing,"Starting a take stops an already playing Edo beam loop")
	lib.discard();game.player.musashi.cancel_beam()
	game.show_settings(false);game.show_sound_studio(false);await frames(3)
	var picker=game.menu.find_child("SoundCharacter",true,false)
	check(picker!=null and picker.get_selected_id()==2,"Forest Settings opens recording hub on the currently active Edo")
	check(not lib.recording and not lib.mic.playing,"Forest recording menu leaves microphone stopped")
	if DisplayServer.get_name()!="headless" and "--visual" in OS.get_cmdline_user_args():
		picker.select(8);picker.item_selected.emit(8)
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://build/settlement-update/character-recording-forest.png")
	game.clear_menu();await frames(2)
	stop_audio(game);lib.cancel();lib.game=null
	game.queue_free();await frames(3);lib.free()
	await create_timer(.15).timeout
	remove_sandbox(sandbox)
	print("CHARACTER_SOUND_GAMEPLAY_RESULT checks=",checks," failures=",failures)
	quit(1 if failures else 0)
