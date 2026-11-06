extends "res://tests/forest-shrine/team_leveling_gameplay_test.gd"
## Permanent card heroes share the castle/hill defense area across waves.
var army
var heroes
var chosen=[]
var step_ms=[]
var output="res://build/Other Files/Castle Defense AI/Heroes-"
func _initialize():
	set_meta("forest_painterly_preview",true)
	if "--large" in OS.get_cmdline_user_args():set_meta("forest_custom_layout",JSON.parse_string(FileAccess.get_file_as_string("res://assets/maps/forest_wind_meadow_large.json")))
	output+=("large" if "--large" in OS.get_cmdline_user_args() else "standard")+("-baseline" if "--baseline" in OS.get_cmdline_user_args() else "-final")
	DirAccess.make_dir_recursive_absolute(output)
	run.call_deferred()
func advance(count:int):
	for i in count:
		var started=Time.get_ticks_usec()
		army.integration_tick(1.0/60)
		step_ms.append((Time.get_ticks_usec()-started)/1000.0)
		if i%12==0:army.flush_presentation();await process_frame
func foe(portal:int,at:Vector3=Vector3.INF)->int:
	var point:Vector3=game.model.waves.routes.exit_point(game.model.portals[portal],0)
	if at.is_finite():point=at
	point.y=game.model.surface_height(point.x,point.z)
	var row=game.model.waves.spawn_enemy(0,point);row.hp=1000000000;row.max_hp=row.hp
	army.import_arrivals();var handle:int=army.handles[row.id]
	army.apply_hit(handle,{"element":"ice","status_seconds":1000})
	return handle
func view(label_:String,point:Vector3):
	if DisplayServer.get_name()=="headless":return
	var camera=game.camera_rig.camera;camera.global_position=point+Vector3(30,55,45);camera.look_at(point+Vector3.UP*2)
	army.flush_presentation();await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(output+"/"+label_+".png")==OK,"Capture "+label_)
func run():
	create_timer(240).timeout.connect(func():printerr("LEGENDARY_HUNTING_TIMEOUT");quit(1))
	game=load("res://scenes/forest_shrine.tscn").instantiate();game.settings_path=cfg;root.add_child(game);current_scene=game;await frames(5)
	game.start_wave();game.model.waves.spawn_clock=100000
	game.set_process(false);game.set_physics_process(false);game.player.set_physics_process(false);game.crowd.set_process(false);game.explorer_helpers.set_process(false)
	game.camera_rig.set_process(false);game.camera_rig.set_process_unhandled_input(false)
	game.camera_rig.camera.projection=Camera3D.PROJECTION_PERSPECTIVE;game.camera_rig.camera.fov=63
	root.gui_disable_input=true;game.set_process_input(false);game.set_process_unhandled_input(false)
	game.player.set_process_input(false);game.player.set_process_unhandled_input(false);game.player.set_process(false)
	game.ui.hide();game.music.stop();root.title="Goemon · Legendary hero defense"
	army=game.army_runtime;army.set_process(false);army.record_events=true
	heroes=game.explorer_helpers.legendary_heroes
	var p=game.model.team_progression
	for character in game.explorer_helpers.HEROES:
		var card_id=""
		for id in p.CARDS:
			if p.CARDS[id].get("hero",-1)==character:card_id=id
		legendary_offer();p.offer[2]=card_id;game.team_upgrade_picker.refresh()
		check(game.choose_team_upgrade(card_id,p.choice_level()),"Card summons hero %d"%character)
		chosen.append(heroes.bodies.back())
	var starts=chosen.map(func(body):return body.position)
	var target=foe(0);var target_id:int=army.unit_state(target).logical_id
	check(starts.all(func(point):return point.distance_to(army.unit_state(target).position)>48),"Enemy entrance is beyond the old hero search limit")
	await advance(30)
	for handle in heroes.handles:check(army.unit_state(handle).target_id!=target_id,"Permanent hero ignores the enemy outside the defense area")
	check(chosen.all(func(body):return body.position.distance_to(starts[chosen.find(body)])<.25),"Permanent heroes hold their castle posts")
	army.despawn(target)
	var hill=Vector3(-105,0,-90);var lawn:Vector3=(hill-hill.normalized()*45)*game.model.terrain_scale
	target=foe(0,lawn);target_id=army.unit_state(target).logical_id
	await advance(30)
	for handle in heroes.handles:check(army.unit_state(handle).target_id==target_id,"Permanent hero acquires an intruder near a hill")
	await advance(900)
	for i in chosen.size():check(chosen[i].position.distance_to(starts[i])>10,"Hero %d leaves the castle to seek combat"%chosen[i].character_id)
	await view("outbound",chosen[2].position)
	for batch in 18:
		await advance(600)
		if chosen.all(func(body):return not body.action_history.is_empty()):break
	for body in chosen:
		check(not body.action_history.is_empty(),"Hero %d reaches the hill intruder and attacks"%body.character_id)
		print("HERO_HUNT_TRACE ",body.character_id," ",army.unit_state(heroes.handles[heroes.bodies.find(body)])," actions=",body.action_history)
	check(army.event_log.any(func(event):return event.kind=="damage" and event.target_id==target_id and event.amount>0),"Pursuing heroes deal real native damage")
	await view("fighting",army.unit_state(target).position)
	game.model.phase="preparing";game.explorer_helpers.rest()
	check(chosen.all(func(body):return body.leased) and heroes.handles.all(func(handle):return army.valid(handle)),"All permanent heroes survive wave preparation")
	game.start_wave();game.model.waves.spawn_clock=100000
	hill=Vector3(105,0,90);lawn=(hill-hill.normalized()*45)*game.model.terrain_scale
	target=foe(1,lawn);target_id=army.unit_state(target).logical_id
	await advance(300)
	for handle in heroes.handles:check(army.unit_state(handle).target_id==target_id,"Hero reacquires a hill intruder after a wave reset")
	var outside:Vector3=game.model.waves.routes.exit_point(game.model.portals[1],0);outside.y=game.model.surface_height(outside.x,outside.z)
	army.set_pose(target,outside,0)
	for batch in 24:
		await advance(600)
		if chosen.all(func(body):return body.position.distance_to(starts[chosen.find(body)])<1):break
	check(chosen.all(func(body):return body.position.distance_to(starts[chosen.find(body)])<1),"Permanent heroes release escaped enemies and return home")
	army.despawn(target);await advance(600)
	var nodes=Performance.get_monitor(Performance.OBJECT_NODE_COUNT);var resources=Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)
	await advance(600)
	check(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)<=nodes and Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)<=resources,"Repeated idle searches retain no extra nodes or resources")
	step_ms.sort()
	var report={"checks":checks,"failures":failures,"steps":step_ms.size(),"step_p95_ms":step_ms[int(step_ms.size()*.95)],"step_max_ms":step_ms[-1],"node_delta":Performance.get_monitor(Performance.OBJECT_NODE_COUNT)-nodes,"resource_delta":Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)-resources}
	FileAccess.open(output+"/results.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("LEGENDARY_DEFENSE_RESULT ",JSON.stringify(report))
	game.sound_library.cancel();game.queue_free();current_scene=null;paused=false;await frames(3)
	if FileAccess.file_exists(cfg):DirAccess.remove_absolute(ProjectSettings.globalize_path(cfg))
	quit(1 if failures else 0)
