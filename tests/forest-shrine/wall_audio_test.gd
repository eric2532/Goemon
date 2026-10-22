extends SceneTree
var checks=0
var failures=0
var game
func _initialize():
	create_timer(90).timeout.connect(func():printerr("FAIL: wall audio timeout");quit(1))
	run.call_deferred()
func pcm_hash(data:PackedByteArray)->String:
	var hash=HashingContext.new();hash.start(HashingContext.HASH_SHA256);hash.update(data);return hash.finish().hex_encode()
func check(ok:bool,message:String):
	checks+=1
	if not ok:failures+=1;printerr("FAIL: "+message)
func run():
	var m=load("res://scripts/forest/forest_model.gd").new();m.reset(42,{}, {},false);m.phase="wave"
	var wall=m.buildings.values().filter(func(b):return b.kind=="wall")[0]
	m.events.clear();m.damage_building(wall.id,30)
	var events=m.events.filter(func(e):return e.kind=="wall_damage")
	check(events.size()==1,"Real wall HP loss emits one positional cracking event")
	if not events.is_empty():
		check(events[0].id==wall.id and events[0].point.is_finite() and events[0].damage==30 and not events[0].destroyed,"Damage feedback carries source, position and severity")
	m.events.clear();m.damage_building(wall.id,0);m.damage_building(wall.id,-10)
	check(m.events.is_empty(),"Zero damage and healing never crack")
	m.phase="preparing";m.damage_building(wall.id,30)
	check(m.events.is_empty(),"Preparation cannot emit attack audio")
	m.phase="wave";m.damage_building(wall.id,100000)
	events=m.events.filter(func(e):return e.kind=="wall_damage")
	check(events.size()==1 and events[0].destroyed and not m.buildings.has(wall.id),"Destruction preserves its crack event before removing the wall")
	var gate=m.buildings.values().filter(func(b):return b.kind=="gate")[0]
	m.events.clear();m.damage_building(gate.id,20)
	check(m.events.filter(func(e):return e.kind=="wall_damage").size()==1,"Stone gates share damage feedback")
	var tower=m.buildings.values().filter(func(b):return b.kind=="tower")[0]
	m.events.clear();m.damage_building(tower.id,20)
	check(m.events.is_empty(),"Unrelated building kinds do not use stone cracking")
	check(ResourceLoader.exists("res://scripts/forest/forest_wall_audio.gd"),"Forest owns a bounded wall-audio player")
	if not ResourceLoader.exists("res://scripts/forest/forest_wall_audio.gd"):finish();return
	game=load("res://scenes/forest_shrine.tscn").instantiate();game.settings_path="user://wall-audio-test-%d.cfg"%OS.get_process_id();root.add_child(game);current_scene=game
	for i in range(4):await process_frame
	game.start_wave();game.model.waves.spawn_clock=10000;game.set_physics_process(false);game.player.set_physics_process(false)
	for w in game.model.workers.values():w.follow=true
	var sound=game.wall_audio
	check(sound.CRACK.mix_rate==22050 and pcm_hash(sound.CRACK.data)=="b955931c73057287b1830fa8c999951396c9efcc2a885dc8cad2716c7382a070","The imported stream preserves the exact recovered Musashi PCM and playback rate")
	check(sound.voices.size()==6,"The audio voice pool is bounded")
	check(sound.MIX_INTERVAL*sound.MAX_VOICES>=sound.CRACK.get_length(),"Rapid ordinary hits preserve the full selected F impact tail")
	var event={"kind":"wall_damage","id":100,"point":game.player.position+Vector3.FORWARD*4,"damage":30,"max_hp":7500,"destroyed":false}
	check(sound.impact(event) and sound.voice_cursor==1,"A nearby hit plays the original sample")
	var voice=sound.voices[0]
	check(voice.stream!=null and voice.stream.get_length()>.2 and voice.pitch_scale==1.0 and voice.position==event.point,"Playback uses source pitch and the damaged wall position")
	check(not sound.impact(event),"A swarm cannot retrigger one wall every frame")
	event.id=102
	check(not sound.impact(event),"Global overlap limiting covers simultaneous attacks on different walls")
	event.destroyed=true
	check(sound.impact(event),"A final break is audible even immediately after an ordinary crack")
	event.destroyed=false
	sound._process(.4);event.id=101
	check(sound.impact(event),"Cracks can repeat after the cooldown")
	sound._process(.4);event.point=game.player.position+Vector3.RIGHT*200
	check(not sound.impact(event),"Inaudibly distant walls do not consume voices")
	sound.reset();event.point=game.player.position+Vector3.FORWARD*4
	game.settings.volume=0
	check(not sound.impact(event),"Master volume zero mutes wall cracking")
	game.settings.volume=.65;game.sound_library.recording=true
	check(not sound.impact(event),"Wall audio stays silent while recording a custom sound")
	game.sound_library.recording=false;game.show_pause()
	check(not sound.impact(event),"Pause cannot trigger new cracking sounds")
	game.resume();sound.reset()
	var live_wall=game.model.buildings.values().filter(func(b):return b.kind=="wall")[0]
	game.player.position=game.model.center(live_wall)+Vector3.BACK*6
	game.model.damage_building(live_wall.id,30)
	game._physics_process(.05)
	check(sound.voice_cursor==1,"Actual Forest event processing plays wall damage audio")
	for i in range(40):
		sound._process(.31);event.id=200+i;sound.impact(event)
	check(sound.voices.size()==6 and sound.cooldowns.size()<=1,"Sustained attacks retain bounded voices and cooldown memory")
	sound.reset();check(sound.voice_cursor==0 and sound.cooldowns.is_empty() and sound.voices.all(func(v):return not v.playing),"Reset stops voices and clears prior run cooldowns")
	game.sound_library.cancel();game.music.stop();game.queue_free();paused=false
	for i in range(4):await process_frame
	finish()
func finish():
	print("WALL_AUDIO_RESULT checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)
