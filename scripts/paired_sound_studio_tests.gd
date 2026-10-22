extends "res://scripts/character_sound_tests.gd"
## Paired controls use synthetic takes; this test never samples microphone input.
func run():
	DirAccess.make_dir_recursive_absolute(sandbox)
	lib=new_library()
	game=AudioGame.new();root.add_child(game);game.setup_audio()
	game.sound_library=lib;lib.game=game
	game.player=Hero.new();game.player.character_id=10
	game.ui=CanvasLayer.new();game.add_child(game.ui)
	game.show_sound_studio(false)
	var studio=game.menu.find_child("SoundStudio",true,false)
	check(studio.has_method("choose_layer"),"Studio groups each move into separately selectable weapon and character voice layers")
	if failures:
		game.clear_menu();await process_frame
		lib.game=null;lib.free();game.sound_library=null;game.player.free();game.player=null;game.free();finish();return
	check(studio.layers.size()==2 and studio.layers.has("weapon") and studio.layers.has("voice"),"Both layers have visible controls together")
	var move=lib.moves_for(10)[studio.move_key]
	check(studio.layers.weapon.title.text.contains("Weapon") and studio.layers.voice.title.text.contains("Character voice"),"Paired cards clearly identify weapon and character voice")
	check(studio.layers.voice.state.text.contains("Silent") and lib.custom_for(10,move.voice)==null,"Unrecorded voice is explicitly silent")
	studio.layers.weapon.volume.value=.6
	studio.layers.voice.volume.value=1.4
	check(is_equal_approx(lib.gain_for(10,move.weapon),.6) and is_equal_approx(lib.gain_for(10,move.voice),1.4),"Weapon and voice volume controls are independent")
	studio.layers.voice.mute.button_pressed=true
	check(lib.is_muted_for(10,move.voice) and not lib.is_muted_for(10,move.weapon),"Voice mute does not mute weapon")
	var wav=fixture()
	lib.take=wav;lib.take_slot=move.voice;lib.save_take();studio.refresh()
	check(studio.layers.voice.state.text.contains("Recorded"),"Saving a voice take updates its paired card")
	studio.layers.voice.reset.pressed.emit()
	check(lib.custom_for(10,move.voice)==null and not lib.is_muted_for(10,move.voice) and is_equal_approx(lib.gain_for(10,move.weapon),.6),"Reset voice restores silence without changing weapon settings")
	studio.choose_layer("voice")
	check(studio.slot==move.voice and studio.volume==studio.layers.voice.volume,"Selected recording layer owns the legacy active control aliases")
	lib.take=wav;lib.take_slot=move.voice
	studio.choose_layer("weapon")
	check(lib.take==null and studio.slot==move.weapon,"Changing recording layer cannot save a pending take into the wrong layer")
	check(lib.mic==null and not lib.recording,"Browsing and adjusting paired controls keeps microphone closed")
	var all_paired=true
	for id in range(1,13):
		studio.characters.select(id-1);studio.characters.item_selected.emit(id-1)
		all_paired=all_paired and lib.moves_for(id).has(studio.move_key)
		studio.choose_layer("voice")
		all_paired=all_paired and studio.slot==lib.moves_for(id)[studio.move_key].voice
	check(all_paired,"Switching all twelve characters preserves valid paired move selection")
	lib.configure_capture();lib.mic.stream=wav
	studio.layers.voice.record.pressed.emit()
	var recording_slot=studio.slot
	check(lib.recording and lib.active_slot==recording_slot and studio.stop_button.disabled==false,"Voice card Record starts only the selected synthetic capture and enables Stop")
	check(studio.layers.weapon.record.disabled and studio.layers.voice.record.disabled and studio.characters.disabled,"Recording disables both Record buttons and the character selector")
	studio.layers.weapon.record.pressed.emit()
	check(lib.active_slot==recording_slot and studio.slot==recording_slot,"A second layer cannot interrupt or redirect an active take")
	studio.stop_button.pressed.emit()
	check(not lib.recording and not lib.mic.playing,"Shared Stop closes input for the recorded layer")
	if DisplayServer.get_name()!="headless":
		studio.characters.select(9);studio.characters.item_selected.emit(9)
		await process_frame;await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://build/paired-melee/sound-studio-paired.png")
	game.clear_menu();await process_frame
	lib.game=null;lib.free();game.sound_library=null;game.player.free();game.player=null;game.free()
	print("PAIRED_STUDIO_RESULT checks=",checks," failures=",failures)
	finish()
