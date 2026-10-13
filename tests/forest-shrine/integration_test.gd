extends SceneTree
var failures=0
func check(ok: bool,message: String):
	if not ok:failures+=1;printerr("FAIL: "+message)
func _initialize():
	create_timer(40).timeout.connect(func():printerr("FAIL: integration timeout");quit(1))
	call_deferred("run")
func run():
	check(ResourceLoader.exists("res://scenes/forest_shrine.tscn"),"Forest Shrine has a playable scene")
	if failures:finish();return
	var game=load("res://scenes/forest_shrine.tscn").instantiate();root.add_child(game);current_scene=game
	await process_frame;await process_frame
	check(game.forest_ui.resources.get_global_rect().position.x>=0 and game.forest_ui.resources.get_global_rect().end.x<=root.get_visible_rect().size.x+1,"Treasury text stays inside the visible window")
	check(game.model.phase=="preparing" and paused,"Preparation stops simulation while keeping the build UI usable")
	check(game.forest_ui.get_node("BuildBar/Mine").visible,"Preparation exposes a mine building card")
	await click(game.forest_ui.get_node("BuildBar/Mine").get_global_rect().get_center())
	check(game.build_kind=="mine","The mine card selects mine placement")
	await click(game.camera_rig.camera.unproject_position(game.model.point(Vector2i(-5,1))))
	check(game.model.buildings.values().any(func(b):return b.kind=="mine"),"A real battlefield click places the selected mine beside the shrine")
	check(game.model.gold==250,"The placement spends its real cost")
	if failures:game.queue_free();paused=false;await process_frame;await create_timer(.35).timeout;finish();return
	var pos=game.world.structure_nodes[game.model.next_id-1].position
	game.start_wave()
	await process_frame
	check(not paused and game.model.phase=="wave","Starting a wave returns to live combat")
	check(not game.forest_ui.get_node("BuildBar").visible,"Combat hides the build interface")
	check(not game.place_cell(Vector2i(5,1)),"Combat rejects construction even through the placement API")
	check(game.world.structure_nodes.values().any(func(n):return n.position==pos),"The built mine remains in place across camera transition")
	var event=InputEventAction.new();event.action="rally_workers";event.pressed=true
	Input.parse_input_event(event);Input.flush_buffered_events();await process_frame
	check(game.model.workforce.held,"Holding the worker action activates live rally")
	event=InputEventAction.new();event.action="rally_workers";event.pressed=false
	Input.parse_input_event(event);Input.flush_buffered_events();await process_frame
	check(not game.model.workforce.held,"Releasing the worker action assigns the group")
	game.show_pause();check(paused,"Ordinary pause remains available")
	game.resume();check(not paused,"Resume restores the active wave")
	game.model.waves.spawn_clock=10000;game.model.waves.spawn_one();game.sync_enemies()
	var data=game.model.enemies.values()[0];data.pos=game.player.position+Vector3(3,0,0);data.stun=100
	var actor=game.actors[data.id];actor.position=data.pos
	game.model.visible_cells.clear()
	check(AttackChain.screen_target(game.player,game.player.position+Vector3.UP*1.25,50)==null,"Automatic attacks cannot select an enemy outside shared vision")
	game.model.update_vision(game.player.position)
	var hp=actor.hp
	game.camera_rig.yaw=-PI/2
	game.camera_rig.reset_follow();game.camera_rig._process(.2)
	var attack=InputEventAction.new();attack.action="light_attack";attack.pressed=true;Input.parse_input_event(attack)
	for i in range(70):await physics_frame
	attack=InputEventAction.new();attack.action="light_attack";attack.pressed=false;Input.parse_input_event(attack)
	check(not is_instance_valid(actor) or actor.hp<hp,"Existing Goemon melee damages a real forest raider")
	game.player.attack_left=2;game.player.queued=true
	game.model.phase="preparing";game.model.enemies.clear();game.set_phase_view()
	check(game.player.attack_left==0 and not game.player.queued,"Wave end clears pending hero attacks before construction")
	if "--visual" in OS.get_cmdline_user_args():
		game.model.phase="preparing";game.model.enemies.clear();game.set_phase_view()
		for w in game.model.workers.values():
			if w.job==-1:w.state="idle";w.pos=Vector3(12,0,18)
		game.model.gold=250;game.select_build("tower");game.place_cell(Vector2i(3,4))
		game.model.build_wall_line([Vector2i(-5,6),Vector2i(-4,6),Vector2i(-3,6),Vector2i(-2,6),Vector2i(-1,6)],0)
		game.model.build("gate",Vector2i(0,6),0);game.world.sync(0)
		game.forest_ui.selected_id=-1;game.forest_ui.message_left=0
		await capture("preparation")
		game.select_build("tower")
		game.world.show_preview("tower",Vector2i(7,6),0,true)
		await capture("placement")
		game.build_kind="";game.world.preview.hide();game.start_wave();game.model.waves.spawn_clock=10000
		game.player.position=Vector3(8,.1,30);game.model.update_vision(game.player.position)
		for i in range(320):await physics_frame
		for i in range(4):
			game.model.waves.spawn_one()
			var e=game.model.enemies.values().back();e.pos=Vector3(10+i*4,0,55+i*3)
		game.sync_enemies();game.camera_rig.reset_follow()
		for i in range(35):await physics_frame
		await capture("battle")
		game.player.position=Vector3(96,.1,24);game.model.update_vision(game.player.position);game.camera_rig.reset_follow()
		for i in range(8):await physics_frame
		await capture("exploration")
	game.queue_free();paused=false;await process_frame;await create_timer(.35).timeout;finish()
func capture(name_: String):
	for i in range(6):await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://tests/forest-shrine/"+name_+".png")
func click(point: Vector2):
	var motion=InputEventMouseMotion.new();motion.position=point;motion.global_position=point;root.push_input(motion,true)
	var press=InputEventMouseButton.new();press.button_index=MOUSE_BUTTON_LEFT;press.position=point;press.global_position=point;press.pressed=true;root.push_input(press,true)
	Input.flush_buffered_events();await process_frame
	var release=InputEventMouseButton.new();release.button_index=MOUSE_BUTTON_LEFT;release.position=point;release.global_position=point;release.pressed=false;root.push_input(release,true)
	Input.flush_buffered_events();await process_frame
func finish():print("FOREST_INTEGRATION_RESULT failures=%d"%failures);quit(1 if failures else 0)
