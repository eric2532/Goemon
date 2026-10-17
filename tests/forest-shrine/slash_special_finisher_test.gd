extends SceneTree
var game
var lib
var checks=0
var failures=0
var sandbox="user://slash-special-test-%s"%OS.get_process_id()
func _initialize():call_deferred("run")
func check(ok: bool,message: String):
	checks+=1
	if not ok:failures+=1
	print("PASS: " if ok else "FAIL: ",message)
func frames(count: int):
	for i in range(count):await process_frame
func pool_has(pool: Node,stream: AudioStream)->bool:
	for voice in pool.voices:
		if voice.stream==stream and voice.playing:return true
	return false
func stop_audio(node: Node):
	if node is AudioStreamPlayer or node is AudioStreamPlayer3D:node.stop()
	for child in node.get_children():stop_audio(child)
func new_library():
	var result=load("res://scripts/sound_library.gd").new()
	result.folder=sandbox+"/recordings";result.config_path=sandbox+"/studio.cfg"
	root.add_child(result)
	return result
func remove_sandbox(path: String):
	for entry in DirAccess.get_directories_at(path):remove_sandbox(path+"/"+entry)
	for entry in DirAccess.get_files_at(path):DirAccess.remove_absolute(path+"/"+entry)
	DirAccess.remove_absolute(path)
func peak(stream: AudioStreamWAV)->float:
	var playback=stream.instantiate_playback();playback.start()
	var decoded=playback.mix_audio(1.0,ceili(stream.get_length()*48000))
	var result=0.0
	for frame in decoded:result=maxf(result,maxf(absf(frame.x),absf(frame.y)))
	playback.stop()
	return result
func run():
	DirAccess.make_dir_recursive_absolute(sandbox)
	game=load("res://scenes/forest_title.tscn").instantiate();game.settings_path=sandbox+"/game.cfg"
	root.add_child(game);current_scene=game;await frames(4)
	game.sound_library.free();lib=new_library();lib.game=game;game.sound_library=lib
	game.player.smoke_mode=true
	var cases=[{"id": 11, "style": "explorer"}, {"id": 5, "style": "ninja"}]
	for entry in cases:
		game.player.select_character(entry.id)
		var fighter=game.player.active_ability
		check(fighter.class_id==entry.style,"Active character is "+entry.style)
		for i in range(3):
			var path="res://assets/rogue/audio/blade-%s-%d.wav"%[entry.style,i]
			var sample=load(path)
			check(sample!=null and sample.get_length()>.15 and sample.get_length()<1.0,entry.style+" trimmed mix %d loads"%(i+1))
			fighter.player.attack=null;fighter.player.cooldowns.cutlass=0;fighter.player.travel=null;fighter.player.blocking=false
			fighter.combo=i;fighter.combo_timer=1;fighter.sound.last_events.clear()
			fighter.action("cutlass")
			check(fighter.player.attack!=null and fighter.player.attack.index==i,entry.style+" starts combo %d"%(i+1))
			fighter.tick((fighter.player.attack.contact+.01)/game.player.attack_speed_multiplier(),false)
			check(pool_has(fighter.sound,sample),entry.style+" actual combo %d plays its new mix"%(i+1))
		fighter.player.attack=null;fighter.player.travel=null;fighter.player.roll=0;fighter.player.dashAttack=null
		fighter.player.cooldowns.flintlock=0;fighter.sound.last_events.clear()
		var special_path="res://assets/rogue/audio/blade-%s-special.wav"%entry.style
		fighter.action("flintlock")
		check(fighter.player.dashAttack!=null,entry.style+" right click starts its slash special")
		var special_played=false
		for voice in fighter.sound.voices:
			if voice.playing and voice.stream!=null and voice.stream.resource_path==special_path:special_played=true
		check(special_played,entry.style+" right-click special plays its dedicated slash mix")
		var after_start=fighter.sound.cursor
		fighter.tick(.01,false)
		check(fighter.sound.cursor==after_start,entry.style+" special does not restart its audio every frame")
		var finisher=load("res://assets/rogue/audio/blade-%s-2.wav"%entry.style)
		var light=load("res://assets/rogue/audio/blade-%s-0.wav"%entry.style)
		check(peak(finisher)>peak(light)*1.3,entry.style+" finisher has a stronger transient than normal swings")
		check(game.sound_preview(entry.id,"native_blade")==load("res://assets/rogue/audio/blade-%s-0.wav"%entry.style),entry.style+" studio preview matches")
		lib.select_character(entry.id)
		var take=AudioStreamWAV.new();take.format=AudioStreamWAV.FORMAT_16_BITS;take.mix_rate=48000
		var samples=PackedByteArray();samples.resize(4800*2)
		for sample in range(4800):samples.encode_s16(sample*2,int(sin(sample*TAU*440/48000)*2000))
		take.data=samples;lib.take=take;lib.take_slot="native_blade"
		check(lib.save_take(),entry.style+" can save a custom blade recording")
		fighter.player.roll=0;fighter.player.cooldowns.flintlock=0;fighter.player.dashAttack=null;fighter.sound.last_events.clear()
		fighter.action("flintlock")
		check(pool_has(fighter.sound,lib.custom_for(entry.id,"native_blade")),entry.style+" special respects its Sound Studio recording")
		lib.reset_slot("native_blade")
	check(game.model.waves.COUNTS==[72,108,144,180,240] and game.model.waves.ACTIVE_CAP==240,"Increased enemy counts retained")
	check(game.music.stream.resource_path.ends_with("talesweaver_dive.mp3"),"Dive building/title soundtrack retained")
	check(game.sound_preview(7,"native_blade")==load("res://assets/rogue/audio/blade-knight-0.wav"),"Knight keeps its existing sword sample")
	stop_audio(game);lib.cancel();lib.game=null
	game.queue_free();await frames(3);lib.free();await create_timer(.15).timeout;remove_sandbox(sandbox)
	print("SLASH_SPECIAL_FINISHER_RESULT checks=",checks," failures=",failures)
	quit(1 if failures else 0)
