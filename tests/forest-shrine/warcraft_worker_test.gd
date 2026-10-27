extends SceneTree
const Art=preload("res://scripts/forest/forest_art.gd")
var game
var checks=0
var failures=0
var hammer_events=0
var cfg="user://peasant-test-%d.cfg"%OS.get_process_id()
var out="res://build/Other Files/Asset Toolkit/Warcraft/Peasant/"
func _initialize():run.call_deferred()
func check(ok:bool,label_:String):
	checks+=1
	if not ok:failures+=1;printerr("FAIL: ",label_)
func frames(count=3):
	for i in count:await process_frame
func capture(label_:String):
	if DisplayServer.get_name()=="headless":return
	await frames();await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(ProjectSettings.globalize_path(out+label_+".png"))==OK,"Capture "+label_)
func percentile(values:Array,fraction:float)->float:
	var sorted=values.duplicate();sorted.sort();return sorted[mini(floori(sorted.size()*fraction),sorted.size()-1)]
func run():
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out))
	var doc=load("res://tests/forest-shrine/reference/map_document.gd").new();doc.load_original();set_meta("forest_custom_layout",doc.data)
	game=load("res://scenes/forest_shrine.tscn").instantiate();game.settings_path=cfg;root.add_child(game);current_scene=game;await frames(6)
	game.set_process(false);game.set_physics_process(false);game.player.set_physics_process(false);game.camera_rig.set_process(false)
	var model=game.model;var world=game.world;var sound=game.placement_audio
	while model.workers.size()<24:model.workforce.recruit(true)
	world.sync(0);await frames(6)
	check(world.worker_nodes.size()==24,"Twenty-four workers use the real game presentation")
	var workers=model.workers.values();var shared=world.worker_nodes[workers[0].id].get_node("WorkerBody").multimesh.mesh
	for node in world.worker_nodes.values():
		check(node.get_node("WorkerBody").multimesh.mesh==shared and node.find_children("*","Skeleton3D",true,false).is_empty(),"The workforce shares one prepared mesh/material set without skeletons")
	var shrine=model.shrine();shrine.hp-=1000;model.gold=10000
	var w:Dictionary=workers[0];w.job=shrine.id;w.state="repair";w.pos=model.point(model.workforce.repairs.faces(shrine)[0]);w.timer=0
	var hp:float=shrine.hp;var gold:int=model.gold
	model.workforce.repairs.tick(w,shrine,.25)
	check(shrine.hp==hp+10 and model.gold==gold-1,"Original repair health, ryo cost and 250 ms interval remain authoritative")
	world.worker_hammered.connect(func(_point):hammer_events+=1)
	world.sync(0)
	for i in 90:world.sync(1.0/60)
	check(hammer_events>=2,"Real world presentation delivers the native work-animation events")
	check(sound.voices.size()==4,"Construction reuses the existing four-voice placement pool")
	game.model.update_vision(game.player.position)
	var cursor:int=sound.voice_cursor
	sound.next_work=0;check(sound.play_work(game.player.position),"Visible nearby work plays through the real game audio path")
	check(not sound.play_work(game.player.position) and sound.voice_cursor==cursor+1,"Simultaneous workers obey the shared overlap limit")
	check(not sound.play_work(Vector3(10000,0,10000)),"Distant and hidden work stays silent")
	game.sound_library.set_process(false);game.sound_library.recording=true;sound.next_work=0
	check(not sound.play_work(game.player.position),"Recording suppresses worker sounds")
	await frames();check(sound.voices.all(func(v):return not v.playing),"Recording stops active work tails")
	game.sound_library.recording=false;game.sound_library.set_process(true);game.settings.volume=0
	check(not sound.play_work(game.player.position),"Mute consumes no work voice")
	game.settings.volume=.65;game.ordinary_pause=true
	check(not sound.play_work(game.player.position),"An explicit pause suppresses work audio")
	game.ordinary_pause=false
	var states=["idle","move","mine","repair","deliver","garrison","wounded","follow"]
	for i in workers.size():
		var worker:Dictionary=workers[i];worker.pos=Vector3(-12+(i%6)*4,0,10+(i/6)*4);worker.state=states[i%states.size()];worker.cargo=10 if worker.state=="deliver" else 0
	world.sync(0);game.camera_rig.camera.position=Vector3(30,38,48);game.camera_rig.camera.look_at(Vector3(0,4,18))
	await capture("gameplay-workforce")
	for i in 30:world.sync(1.0/60);await process_frame
	var nodes=Performance.get_monitor(Performance.OBJECT_NODE_COUNT);var resources=Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT);var voices=sound.voices.map(func(v):return v.get_instance_id());var times=[];var intervals=[];var previous=Time.get_ticks_usec()
	for cycle in 5:
		for i in 120:
			var now=Time.get_ticks_usec();intervals.append((now-previous)/1000.0);previous=now
			var started=Time.get_ticks_usec()
			world.sync(1.0/60)
			times.append((Time.get_ticks_usec()-started)/1000.0)
			await process_frame
		check(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)==nodes and Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)==resources,"Repeated simultaneous jobs retain no nodes/resources: cycle %d"%cycle)
	check(sound.voices.map(func(v):return v.get_instance_id())==voices,"Repeated work retains the same four voices")
	var result={"checks":checks,"failures":failures,"workers":workers.size(),"cycles":5,"world_cpu_p95_ms":percentile(times,.95),"world_cpu_max_ms":times.max(),"frame_p95_ms":percentile(intervals,.95),"frame_max_ms":intervals.max(),"node_delta":Performance.get_monitor(Performance.OBJECT_NODE_COUNT)-nodes,"resource_delta":Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)-resources}
	for worker in workers:worker.state="idle";worker.job=-1;worker.cargo=0
	game.set_process(true);game.set_physics_process(true);game.start_wave()
	# The wave opens after two simulation seconds; headless render frames run faster.
	for i in 180:await physics_frame
	check(model.phase=="wave" and is_instance_valid(game.army_runtime),"Normal combat still uses the existing native army owner")
	check(model.enemies.size()>0,"The unchanged wave schedule spawns actual enemies")
	check(world.worker_nodes.values().all(func(node):return node.get_node_or_null("WorkerBody")!=null),"The same Peasant workforce remains active during combat")
	await capture("gameplay-wave")
	result.checks=checks;result.failures=failures
	FileAccess.open(out+"desktop.json",FileAccess.WRITE).store_string(JSON.stringify(result,"\t"));print("WARCRAFT_WORKER_DESKTOP_RESULT ",JSON.stringify(result))
	game.sound_library.cancel();game.music.stop();game.queue_free();paused=false;await frames()
	if FileAccess.file_exists(cfg):DirAccess.remove_absolute(ProjectSettings.globalize_path(cfg))
	quit(1 if failures else 0)
