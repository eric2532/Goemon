extends SceneTree
## Isolated real WAV/config persistence and both production playback routes.
class AudioGame extends "res://scripts/game.gd":
	func _ready():
		set_process(false);set_physics_process(false);set_process_unhandled_input(false)

var checks=0
var failures=0
var game
var lib
var sandbox="user://character-sound-test-%s" % OS.get_process_id()

func _initialize():run.call_deferred()
func check(ok: bool,message: String):
	checks+=1
	if not ok:failures+=1
	print("PASS: " if ok else "FAIL: ",message)
func fixture(rate: int=16000)->AudioStreamWAV:
	var samples=PackedVector2Array()
	for i in range(4000):
		var value=sin(float(i)*TAU*440/rate)*.15 if i>400 and i<3200 else 0.0
		samples.append(Vector2(value,value))
	return lib.make_take(samples,rate)
func new_library():
	var result=SoundLibrary.new()
	result.folder=sandbox+"/recordings"
	result.config_path=sandbox+"/studio.cfg"
	root.add_child(result)
	return result
func save(slot: String,stream: AudioStreamWAV)->bool:
	lib.take=stream;lib.take_slot=slot
	return lib.save_take()

func run():
	lib=SoundLibrary.new()
	check(lib.has_method("select_character"),"Sound Library provides independent character recording hubs")
	if failures:lib.free();finish();return
	lib.free()
	DirAccess.make_dir_recursive_absolute(sandbox+"/recordings")
	lib=new_library()
	var original=fixture()
	check(original!=null and original.get_length()<.25,"Recording conversion trims silence into playable PCM")
	check(lib.make_take(PackedVector2Array([Vector2.ZERO]),16000)==null,"Silent takes cannot overwrite saved recordings")
	lib.free()
	# Old global data remains intact and has a single character owner.
	original.save_to_wav(sandbox+"/recordings/swing.wav")
	original.save_to_wav(sandbox+"/recordings/edo_volley.wav")
	var legacy=ConfigFile.new()
	legacy.set_value("gain","swing",.65);legacy.set_value("gain","edo_volley",.8)
	legacy.set_value("other","preserve","unchanged");legacy.save(sandbox+"/studio.cfg")
	lib=new_library()
	check(lib.custom_for(1,"swing")!=null and lib.custom_for(2,"swing")==null and lib.custom_for(3,"swing")==null,"Legacy pipe take belongs to Goemon without leaking to other characters")
	check(lib.custom_for(2,"edo_volley")!=null and lib.custom_for(1,"edo_volley")==null,"Legacy Edo take remains available only in Edo's hub")
	var before=FileAccess.get_file_as_bytes(lib.config_path)
	for id in range(1,13):lib.select_character(id)
	check(FileAccess.get_file_as_bytes(lib.config_path)==before and lib.mic==null,"Browsing all twelve hubs neither writes preferences nor opens microphone")
	check(lib.slots_for(1).has("swing") and not lib.slots_for(1).has("edo_volley") and lib.slots_for(2).has("edo_volley") and not lib.slots_for(2).has("swing"),"Goemon and Edo show their relevant attack slots")
	check(lib.slots_for(3).has("native_shot") and not lib.slots_for(3).has("edo_volley") and lib.slots_for(10).has("native_bow"),"Pirate and Ranger expose their native weapon sounds")
	for id in range(1,13):
		lib.select_character(id);save("land",original);lib.set_gain("land",float(id)/12)
	lib.select_character(1);lib.set_gain("jump",.4)
	check(save("jump",original),"Goemon take saves successfully")
	lib.select_character(2)
	check(lib.custom_for(2,"jump")==null and lib.gain_for(2,"jump")==1.0,"Shared movement slots are isolated by character")
	var second=fixture(22050)
	check(save("jump",second),"Edo can save a different take for the same slot")
	lib.set_gain("jump",1.6)
	lib.select_character(3);save("native_blade",original);lib.set_gain("native_blade",.35)
	lib.select_character(4);save("native_blade",second);lib.set_gain("native_blade",1.25)
	lib.select_character(1);lib.take=second;lib.take_slot="jump";lib.select_character(2)
	check(lib.take==null and not lib.save_take(),"Changing character discards a pending take so it cannot be saved into another hub")
	lib.free();lib=new_library()
	var all_profiles=true
	for id in range(1,13):
		all_profiles=all_profiles and lib.custom_for(id,"land")!=null and is_equal_approx(lib.gain_for(id,"land"),float(id)/12)
	check(all_profiles,"All twelve named hubs retain their own takes and gains after reload")
	check(lib.custom_for(1,"jump").data==original.data and lib.custom_for(2,"jump").mix_rate==22050,"Independent recordings survive reload")
	check(is_equal_approx(lib.gain_for(1,"jump"),.4) and is_equal_approx(lib.gain_for(2,"jump"),1.6),"Per-character volume survives reload")
	game=AudioGame.new();root.add_child(game);game.setup_audio()
	game.player=Hero.new();game.sound_library=lib;lib.game=game
	game.ui=CanvasLayer.new();game.add_child(game.ui)
	game.player.character_id=1;lib.select_character(2);game.sound("jump")
	check(game.last_sound_voice.stream==lib.original_for(1,"jump") and game.last_sound_voice.pitch_scale==1.0,"Goemon gameplay uses original audio even with a saved take and another hub selected")
	check(is_equal_approx(db_to_linear(game.last_sound_voice.volume_db),.55*.4),"Gameplay applies active character's slot volume")
	game.player.character_id=2;game.sound("jump")
	check(game.last_sound_voice.stream==lib.custom_for(2,"jump"),"Switching the active hero switches runtime recording")
	check(game.sound_preview(3,"dash")==load("res://assets/rogue/audio/roll.wav"),"Pirate default preview matches its native evade sound")
	check(game.sound_preview(4,"native_bow")==load("res://assets/rogue/audio/bow-power.wav"),"Samurai bow preview matches its Crimson Arrow power shot")
	check(game.sound_preview(9,"heavy_hit")==load("res://assets/rogue/audio/claymore-impact-heavy.wav"),"Magic Swordsman's impact preview matches its dedicated native impact")
	var previews_complete=true
	for id in range(1,13):
		for key in lib.slots_for(id):
			var preview_stream=game.sound_preview(id,key)
			previews_complete=previews_complete and (preview_stream==lib.original_for(id,key) if key.begins_with("move_") and key.ends_with("_voice") else preview_stream!=null)
	check(previews_complete,"All twelve hubs preview existing sounds and use only recovered originals for unrecorded voices")
	var native=load("res://assets/rogue/scripts/audio.gd").new();native.game=game;native.name="RogueSharedClassAudio";game.add_child(native)
	game.player.character_id=3;native.play("blade",{"style":"pirate"})
	check(native.voices[0].stream==lib.custom_for(3,"native_blade") and native.voices[0].pitch_scale==1.0,"Native Pirate attack uses the Pirate hub at original recorded pitch")
	check(is_equal_approx(db_to_linear(native.voices[0].volume_db),.55*.35),"Native attack volume uses the selected hero's saved gain")
	game.player.character_id=4;native.last_events.clear();native.play("blade",{"style":"samurai"})
	check(native.voices[1].stream==lib.custom_for(4,"native_blade"),"Native Samurai attacks never inherit Pirate's recording")
	lib.recording=true;var cursor=native.cursor;native.play("shot")
	check(native.cursor==cursor,"Native sound playback is silent while recording")
	lib.recording=false
	game.player.character_id=4;game.show_sound_studio(false)
	var studio=game.menu.find_child("SoundStudio",true,false)
	var picker=studio.find_child("SoundCharacter",true,false)
	var visible_ids=lib.Roster.selection_ids()
	var actual_ids=[]
	if picker:
		for i in picker.item_count:actual_ids.append(picker.get_item_id(i))
	check(picker!=null and actual_ids==visible_ids and picker.get_item_text(picker.get_item_index(18))=="Master Chief" and picker.get_selected_id()==4,"Studio offers the visible roster by stable ID and opens on the active hero")
	if picker:
		var ranger_index=picker.get_item_index(10)
		picker.select(ranger_index);picker.item_selected.emit(ranger_index)
		check(lib.character_id==10 and game.player.character_id==4,"Browsing Ranger hub leaves the playing hero unchanged")
	check(lib.mic==null and not lib.recording,"Opening and switching recording hubs keeps microphone off")
	if DisplayServer.get_name()!="headless" and "--visual" in OS.get_cmdline_user_args():
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://build/settlement-update/character-recording-hub.png")
	game.clear_menu();await process_frame
	# Feed an authored fixture into the capture bus: never request private mic input.
	var bus_count_before=AudioServer.bus_count
	lib.configure_capture();lib.mic.stream=original
	native.last_events.clear();native.play("shot")
	check(native.voices[(native.cursor-1)%native.voices.size()].playing,"Recording fixture begins with a playing native attack")
	var selected_id=lib.character_id
	check(lib.begin("jump"),"Record accepts a valid selected-character slot")
	check(not native.voices[(native.cursor-1)%native.voices.size()].playing,"Starting recording stops native attack voices so preview audio cannot bleed into a take")
	lib.select_character(4)
	check(lib.character_id==selected_id and not lib.begin("hit"),"An active take cannot switch character or start overlapping capture")
	lib.discard()
	check(not lib.recording and not lib.mic.playing,"Discard closes the recording stream")
	lib.select_character(1);lib.reset_slot("swing");lib.reset_slot("jump")
	check(lib.custom_for(1,"swing")==null and lib.custom_for(1,"jump")==null and lib.gain_for(1,"jump")==1.0,"Restore default clears only selected character's take and gain")
	check(lib.custom_for(2,"jump")!=null and is_equal_approx(lib.gain_for(2,"jump"),1.6),"Reset preserves another character's recording and volume")
	for voice in game.voices:voice.stop()
	for voice in native.voices:voice.stop()
	for i in range(5):await physics_frame
	lib.game=null;lib.free()
	check(AudioServer.bus_count==bus_count_before,"Releasing a recording library also releases its private capture bus")
	lib=new_library()
	check(lib.custom_for(1,"swing")==null and AudioStreamWAV.load_from_file(sandbox+"/recordings/swing.wav").data==original.data,"Reset legacy fallback persists without deleting the original WAV")
	legacy.load(lib.config_path)
	check(legacy.get_value("other","preserve")=="unchanged" and legacy.get_value("gain","swing")==.65,"Saving profiles preserves unrelated and legacy config sections")
	lib.free();game.sound_library=null;game.player.free();game.player=null;game.free()
	await create_timer(.15).timeout
	finish()

func remove_sandbox(path: String):
	for entry in DirAccess.get_directories_at(path):remove_sandbox(path+"/"+entry)
	for entry in DirAccess.get_files_at(path):DirAccess.remove_absolute(path+"/"+entry)
	DirAccess.remove_absolute(path)
func finish():
	if DirAccess.dir_exists_absolute(sandbox):remove_sandbox(sandbox)
	print("CHARACTER_SOUND_RESULT checks=",checks," failures=",failures)
	quit(1 if failures else 0)
