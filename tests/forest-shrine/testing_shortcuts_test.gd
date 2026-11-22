extends "res://scripts/recovered_leaders_tests.gd"
const Model=preload("res://scripts/forest/forest_model.gd")
const Roles=preload("res://scripts/forest/forest_enemy_roles.gd")

func key(code:int,pressed:bool=true,echo:bool=false):
	var event=InputEventKey.new();event.physical_keycode=code;event.pressed=pressed;event.echo=echo
	game._input(event)

func run():
	root.size=Vector2i(1280,800)
	var model=Model.new();model.reset(42,{}, {"buildings":[],"trees":[],"deposits":[]},false)
	model.buildings.clear();model.occupancy.clear();model.next_id=1
	model._make_building("shrine",Vector2i.ZERO,0)
	model.start_wave();model.base_invulnerable=true
	var hp:float=model.shrine().hp
	for i in 10:model.damage_building(1,100000)
	check(model.shrine().hp==hp and model.phase=="wave","Repeated lethal damage cannot destroy an invulnerable base")
	var tower=model._make_building("tower",Vector2i(8,8),0)
	model.damage_building(tower.id,1)
	check(tower.hp==tower.max_hp-1,"Base protection leaves other building damage intact")
	model.base_invulnerable=false;model.damage_building(1,100000)
	check(model.phase=="defeat","Turning protection off restores normal base defeat")
	model.base_invulnerable=true;model.reset(42)
	check(not model.base_invulnerable,"A new run starts with base protection off")
	var large="--large" in OS.get_cmdline_user_args()
	set_meta("forest_custom_layout",JSON.parse_string(FileAccess.get_file_as_string("res://assets/maps/forest_wind_meadow_large.json" if large else "res://assets/maps/forest_wind_meadow.json")))
	game=load("res://scenes/forest_shrine.tscn").instantiate();game.settings_path="user://testing-shortcuts-%d.cfg"%OS.get_process_id()
	root.add_child(game);current_scene=game;await frames(3)
	game.player.select_character(game.player.RogueRoster.KAZI_ID)
	game.set_process(false);game.set_physics_process(false);game.player.set_physics_process(false);game.camera_rig.set_process(false)
	model=game.model
	var has_base=not model.shrine().is_empty()
	key(KEY_O)
	check(model.base_invulnerable==has_base and (not has_base or "INVULNERABLE" in game.forest_ui.shrine_health_label.text),"O enables base protection and labels the HUD during preparation")
	key(KEY_O,true,true);key(KEY_O,false)
	check(model.base_invulnerable==has_base,"Key repeat and release cannot toggle protection again")
	key(KEY_P)
	check(model.enemies.is_empty() and model.phase=="preparing","P during preparation cannot start a wave or spawn enemies")
	game.start_wave();game.army_runtime.integration_tick(1.0/60)
	var waves=model.waves;var army=game.army_runtime
	waves.spawn_clock=100000;waves.random_spawn_clock=100000
	var pending:int=waves.pending;var spawned:int=waves.spawned;var roster=waves.remaining_counts.duplicate();var kill_pending:int=waves.kill_spawn_pending
	key(KEY_P)
	check(army.pending_hounds.size()==5,"P queues the five selected pets")
	key(KEY_P,true,true);key(KEY_P,false)
	check(army.pending_hounds.size()==5,"Held P cannot repeat the request")
	game.show_pause();key(KEY_O);key(KEY_P)
	check(model.base_invulnerable==has_base and army.pending_hounds.size()==5,"Paused input leaves the request alone")
	check(game.ordinary_pause and paused and is_instance_valid(game.forest_ui.overlay),"Pause shows the battle overlay")
	game.resume();await process_frame
	var home=Vector3(-150,0,127)
	home.y=model.surface_height(home.x,home.z)
	game.player.position=home
	var spawn_ms=[]
	for i in 24:
		if army.pending_hounds.is_empty():break
		var started=Time.get_ticks_usec()
		army.import_hounds()
		spawn_ms.append((Time.get_ticks_usec()-started)/1000.0)
	print("HOUND_SUMMON_TICK_MAX_MS=",spawn_ms.max())
	var colors=hound_colors(army)
	check(colors==[0,10,17,18,20] and army.pending_hounds.is_empty(),"Each color arrives exactly once in the friendly native army")
	key(KEY_G)
	check(army.hound_order==army.HoundOrder.DEFEND,"G leaves the pet order alone")
	var click=InputEventMouseButton.new();click.button_index=MOUSE_BUTTON_RIGHT;click.position=game.crosshair_screen_position()
	click.pressed=true;root.push_input(click,true)
	click.pressed=false;root.push_input(click,true)
	check(army.hound_order==army.HoundOrder.ATTACK,"Right click orders the pack to attack")
	key(KEY_Z,true,true)
	check(army.hound_order==army.HoundOrder.ATTACK,"A key repeat cannot recall the pack")
	var sprint_recall=InputEventKey.new();sprint_recall.physical_keycode=KEY_Z;sprint_recall.pressed=true;sprint_recall.shift_pressed=true
	game._input(sprint_recall)
	check(army.hound_order==army.HoundOrder.RETURN,"Z orders return while sprint is held")
	if DisplayServer.get_name()!="headless":verify_hound_aim()
	key(KEY_P)
	check(army.pending_hounds.is_empty() and hound_colors(army).is_empty(),"A second press unsummons an intact pack")
	key(KEY_P)
	for i in 24:
		if army.pending_hounds.is_empty():break
		army.import_hounds()
	var fallen:Dictionary=army.apply_hit(army.handles[army.HOUND_ID-20],{"amount":3000.0})
	army.queue_hounds()
	check(fallen.dead and army.pending_hounds==[20],"Missing-only queuing replaces just the fallen hound")
	army.import_hounds()
	check(army.pending_hounds.is_empty() and hound_colors(army)==colors,"The fallen hound returns without duplicating any color")
	check(waves.pending==pending and waves.spawned==spawned and waves.remaining_counts==roster and waves.kill_spawn_pending==kill_pending,"Summoning preserves the enemy wave counters")
	key(KEY_O)
	check(not model.base_invulnerable,"O toggles base protection off during battle")
	game.settings_open=true;key(KEY_O);key(KEY_P);game.settings_open=false
	check(not model.base_invulnerable and army.pending_hounds.is_empty(),"Settings input cannot trigger testing shortcuts")
	var config=game.settings_path;stop_audio(game);game.move_audio.stop();current_scene=null;game.queue_free();paused=false;await frames(3)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(config))
	print("TESTING_SHORTCUTS_RESULT checks=%d failures=%d large=%s"%[checks,failures,large]);quit(1 if failures else 0)

func hound_colors(army)->Array[int]:
	var snapshot:Dictionary=army.render_snapshot()
	var colors:Array[int]=[]
	for i in snapshot.kinds.size():
		if snapshot.kinds[i]==Roles.GATEKEEPER_HOUND and snapshot.teams[i]==1:colors.append(snapshot.pose_rows[i])
	colors.sort()
	return colors

func verify_hound_aim():
	game.camera_focused=true;game._sync_camera_mouse()
	check(Input.mouse_mode==Input.MOUSE_MODE_CAPTURED,"The battle keeps the mouse captured after a hound order")
	var camera=game.camera_rig
	var before:float=camera.yaw
	var motion=InputEventMouseMotion.new();motion.relative=Vector2(40,0)
	camera._unhandled_input(motion)
	check(not is_equal_approx(camera.yaw,before),"Mouse motion still turns the battle camera")
