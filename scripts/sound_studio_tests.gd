extends Node
var game: Node
var failures=0
func check(ok: bool,message: String):
	if ok:print("SOUND PASS: ",message)
	else:failures+=1;push_error("SOUND FAIL: "+message)
func run():
	var lib=game.sound_library
	print("INPUT_DEVICES ",lib.devices())
	var config_path="user://sound_studio.cfg"
	var old_config=FileAccess.get_file_as_bytes(config_path) if FileAccess.file_exists(config_path) else PackedByteArray()
	var old_folder=lib.folder;var old_custom=lib.custom.duplicate();var old_gains=lib.gains.duplicate()
	lib.folder="user://sound_studio_test";DirAccess.make_dir_recursive_absolute(lib.folder)
	var samples=PackedVector2Array()
	for i in range(24000):
		var value=sin(float(i)*TAU*440/48000)*0.15 if i>2400 and i<18000 else 0.0
		samples.append(Vector2(value,value))
	var fixture=lib.make_take(samples,48000)
	check(fixture!=null and fixture.get_length()<0.40 and fixture.get_length()>0.30,"Trims silence and creates playable PCM WAV")
	check(lib.make_take(PackedVector2Array([Vector2.ZERO]),48000)==null,"Rejects empty/silent microphone takes")
	lib.take=fixture;lib.take_slot="throw"
	check(lib.save_take(),"Saves recording atomically")
	var disk=AudioStreamWAV.load_from_file(lib.folder+"/throw.wav")
	check(disk!=null and disk.data==fixture.data,"WAV persists and reloads without data loss")
	game.sound("throw")
	check(game.last_sound_voice.stream==fixture,"Gameplay throw routes to custom audio")
	check(game.last_sound_voice.pitch_scale==1.0,"Custom recordings play at their original pitch")
	var replacement=lib.make_take(samples.slice(0,12000),48000)
	lib.take=replacement;lib.take_slot="throw"
	check(lib.save_take(),"Saving a second take replaces the selected slot")
	check(AudioStreamWAV.load_from_file(lib.folder+"/throw.wav").data==replacement.data and lib.custom.throw==replacement,"Only the replacement take remains on disk and in gameplay")
	lib.recording=true;lib.active_slot="throw";lib.elapsed=.5
	check(not lib.begin("hit") and lib.active_slot=="throw" and lib.elapsed==.5,"A second Record request cannot interrupt or overlap the active recording")
	lib.recording=false
	# Exercise the actual audio capture effect using a known sound, not private microphone input.
	lib.configure_capture();lib.mic.stream=fixture
	await get_tree().create_timer(0.3).timeout
	lib.capture.clear_buffer();lib.discarded_before=lib.capture.get_discarded_frames();lib.frames.clear();lib.recording=true;lib.active_slot="hit";lib.elapsed=0
	lib.music_was_paused=game.music.stream_paused;game.music.stream_paused=true
	lib.mic.play()
	await get_tree().create_timer(0.65).timeout
	lib.finish()
	print("CAPTURE_STATUS ",lib.status," mixed=",lib.capture.get_pushed_frames()," dropped=",lib.capture.get_discarded_frames()," rate=",AudioServer.get_mix_rate())
	if DisplayServer.get_name()!="headless":check(lib.take!=null,"Muted recording bus captures a real audio stream")
	check(not lib.recording and not lib.mic.playing,"Stop closes the recording input")
	lib.mic.stream=AudioStreamMicrophone.new()
	lib.reset_slot("throw")
	check(not lib.custom.has("throw") and not FileAccess.file_exists(lib.folder+"/throw.wav"),"Restore default removes only that custom slot")
	lib.folder=old_folder;lib.custom=old_custom;lib.gains=old_gains
	game.show_settings(false)
	game.show_sound_studio(false)
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	await get_tree().create_timer(0.3).timeout
	if DisplayServer.get_name()!="headless":
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://tests/sound-studio-ui.png" if DirAccess.dir_exists_absolute("res://tests") else "user://sound-studio-ui.png")
	check(not lib.recording and not lib.mic.playing,"Opening Sound Studio leaves microphone off")
	game.show_settings(false)
	await get_tree().process_frame
	game.start_game();game.show_pause();game.show_sound_studio(true)
	check(get_tree().paused,"Sound Studio works while game is paused")
	game.resume();await get_tree().process_frame
	check(not lib.recording and not lib.mic.playing,"Leaving studio stops capture and preview")
	if old_config.is_empty():
		if FileAccess.file_exists(config_path):DirAccess.remove_absolute(config_path)
	else:
		var file=FileAccess.open(config_path,FileAccess.WRITE);file.store_buffer(old_config);file.close()
	print("SOUND_STUDIO_TEST_RESULT failures=",failures)
	game.quit_clean()
