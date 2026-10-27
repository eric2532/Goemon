extends "res://scripts/recovered_goemon_gameplay_tests.gd"
## Run through Play Goemon.command for actual painterly/Metal verification.
var timings=[]
var skill
func run():
	await setup_fixture()
	game.set_process(false);game.army_runtime.set_process(false);game.army_runtime.set_physics_process(false)
	game.player.select_character(13);game.player.set_physics_process(false)
	var p=game.player;var c=p.active_ability;skill=c.assimilation;skill.set_physics_process(false)
	p.position=ORIGIN
	for i in 3:p.velocity=Vector3.DOWN*20;p.move_and_slide()
	p.velocity=Vector3.ZERO;p.facing=Vector3.FORWARD;p.smoke_mode=true;p.smoke_move=Vector2.ZERO
	game.training_dummy.position=ORIGIN+Vector3(9,0,-15);game.training_dummy.home=game.training_dummy.position
	var camera=game.camera_rig.camera;camera.global_position=ORIGIN+Vector3(12,10,20);camera.look_at(ORIGIN+Vector3(0,2,-3));camera.fov=48
	game.model.update_vision(p.position);game.forest_ui.sync()
	await frames(10)
	for pair in [[3,"dkick"],[4,"fence"],[5,"homing"],[6,"grenade"],[7,"three_way"]]:
		c.cancel();p.position=ORIGIN;p.velocity=Vector3.DOWN*20;p.move_and_slide();p.velocity=Vector3.ZERO
		p.facing=Vector3.FORWARD;c.select_number(pair[0])
		for frame in (4 if pair[0]==3 else 8):
			if pair[0]==3:p.position+=c.source_motion_tick()/30.0
			else:c.tick(1.0/30.0)
			skill.set_physics_process(false);skill._physics_process(1.0/30.0);p.model.animate(1.0/30.0,0,true,0,0,false,0,false)
			await process_frame
		await RenderingServer.frame_post_draw
		var path="res://build/Other Files/Asset Toolkit/Musashi Assimilation/"+pair[1]+"-gameplay.png"
		root.get_texture().get_image().save_png(path)
		print("CAPTURE ",pair[1]," active=",skill.active_count()," path=",path)
		for shot in skill.shots:if shot.active:skill._retire(shot)
	c.cancel();p.position=ORIGIN
	for frame in 60:await process_frame
	var baseline=[]
	for frame in 180:
		await process_frame;baseline.append(Performance.get_monitor(Performance.TIME_PROCESS)*1000)
	c.select_number(7)
	var nodes=Performance.get_monitor(Performance.OBJECT_NODE_COUNT);var resources=Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)
	for frame in 360:
		var delta=root.get_process_delta_time();c.tick(delta);skill.set_physics_process(false);skill._physics_process(delta)
		p.model.animate(delta,0,true,0,0,false,0,false)
		await process_frame;timings.append(Performance.get_monitor(Performance.TIME_PROCESS)*1000)
	skill.held=false
	for frame in 60:c.tick(1.0/60.0);skill.set_physics_process(false);skill._physics_process(1.0/60.0);await process_frame
	baseline.sort();timings.sort()
	var report={"renderer":RenderingServer.get_current_rendering_method(),"idle_process_ms_p95":baseline[int(baseline.size()*.95)],"three_way_process_ms_p95":timings[int(timings.size()*.95)],"three_way_process_ms_p99":timings[int(timings.size()*.99)],"node_growth":Performance.get_monitor(Performance.OBJECT_NODE_COUNT)-nodes,"resource_growth":Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)-resources,"peak_active_projectiles":skill.peak_active,"notes":"Fresh desktop Metal capture in an isolated original-map fixture. Process CPU time only, not a full-army FPS claim or a pre-change benchmark."}
	var file=FileAccess.open("res://build/Other Files/Asset Toolkit/Musashi Assimilation/rendered-check.json",FileAccess.WRITE);file.store_string(JSON.stringify(report,"\t"));file.close()
	print("MUSASHI_RENDERED_CHECK ",report)
	game.sound_library.cancel();game.music.stop();game.move_audio.stop();game.queue_free();game=null;c=null;skill=null;current_scene=null;paused=false
	await frames();quit()
