extends "res://scripts/game.gd"
const ForestModel=preload("res://scripts/forest/forest_model.gd")
const ForestWorld=preload("res://scripts/forest/forest_world.gd")
const Raider=preload("res://scripts/forest/forest_raider.gd")
const MapDocument=preload("res://scripts/forest/forest_map_document.gd")
const COMBAT_CAMERA_PITCH=.22
const COMBAT_CAMERA_FOCUS_RISE=2.0
@export var launch_to_title=false
var model
var forest_ui
var build_kind=""
var build_rotation=0
var placement_hint="Click to place"
var pan=Vector3.ZERO
var preparation_size=120.0
var actors: Dictionary={}
var training_dummy: Ninja
var last_phase=""
var wall_start=Vector2i(-999,-999)
var ordinary_pause=false
var notice=""
var roster_return_pause=false
var settings_open=false
var settings_from_pause=false
var tower_arrows
var enemy_arrows
var camera_focused=true
func _ready():
	process_mode=Node.PROCESS_MODE_ALWAYS
	character_control_hints=false
	descent_mode=false;rogue_battle_mode=false;rogue_roster_mode=true;tower_defense_mode=false
	smoke_test="--test" in OS.get_cmdline_user_args() or "--visual" in OS.get_cmdline_user_args()
	setup_inputs()
	if not InputMap.has_action("rally_workers"):
		InputMap.add_action("rally_workers");var key=InputEventKey.new();key.physical_keycode=KEY_V;InputMap.action_add_event("rally_workers",key)
	load_settings();setup_audio()
	sound_library=SoundLibrary.new();sound_library.game=self;add_child(sound_library)
	ComboEnergy.warmup();SkySmoke.warmup();EdoFireExplosion.warmup()
	model=ForestModel.new();run_seed=90824 if smoke_test else int(Time.get_ticks_usec())%2147483647;model.reset(run_seed,core_balance,active_forest_map())
	if not model.ramparts.is_empty():pan=Vector3(0,0,100);preparation_size=340
	world=ForestWorld.new();world.model=model;world.process_mode=Node.PROCESS_MODE_PAUSABLE;add_child(world)
	tower_arrows=preload("res://scripts/forest/forest_tower_arrows.gd").new();tower_arrows.game=self;add_child(tower_arrows)
	enemy_arrows=preload("res://scripts/forest/forest_enemy_arrows.gd").new();enemy_arrows.game=self;add_child(enemy_arrows)
	player=Hero.new();player.game=self;player.position=Vector3(0,.15,18);player.process_mode=Node.PROCESS_MODE_PAUSABLE;add_child(player)
	selected_rogue_id=int(get_tree().get_meta("forest_fighter",1))
	player.select_character(selected_rogue_id);player.progression.reset(false);player.refresh_max_health();player.hp=player.max_hp;player.soft_target=false
	checkpoint=player.position
	camera_rig=ActionCamera.new();camera_rig.game=self;camera_rig.player=player;add_child(camera_rig)
	camera_rig.sens=settings.sensitivity
	camera_rig.pitch=COMBAT_CAMERA_PITCH;camera_rig.distance=settings.forest_camera_distance
	camera_rig.character_screen_offset=settings.forest_character_screen_offset
	camera_rig.crosshair_focus_rise=COMBAT_CAMERA_FOCUS_RISE
	camera_rig.travel_follow.forward_buffer=0.0
	rogue_view=preload("res://scripts/forest/forest_view.gd").new();rogue_view.game=self;add_child(rogue_view)
	rogue_feedback=preload("res://scripts/rogue_battle_feedback.gd").new();rogue_feedback.game=self;add_child(rogue_feedback)
	crowd=preload("res://scripts/forest/forest_enemy_crowd.gd").new()
	crowd.game=self;crowd.process_mode=Node.PROCESS_MODE_PAUSABLE;add_child(crowd)
	# Build fitted collision hulls during scene loading, before combat. Their
	# first use otherwise blocks a spawn frame while generating convex meshes.
	for kind in range(4):Raider.Contact.shapes(kind)
	pursuit=EnemyPursuit.new();pursuit.game=self;add_child(pursuit);pursuit.set_physics_process(false)
	encounters=EndlessEncounters.new();encounters.game=self;encounters.enabled=false;add_child(encounters)
	ui=CanvasLayer.new();add_child(ui)
	forest_ui=preload("res://scripts/forest/forest_ui.gd").new();forest_ui.game=self;ui.add_child(forest_ui)
	map_editor=preload("res://scripts/forest/forest_map_editor.gd").new();map_editor.game=self;ui.add_child(map_editor)
	playing=not launch_to_title;won=false;Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	rogue_view.set_enabled(false);rogue_feedback.set_enabled(false);set_phase_view()
	if launch_to_title:show_title()
# Combat capabilities are independent of Fire Siege's old construction director.
func camera_combat()->bool:return true
func crosshair_aim_enabled()->bool:return true
func attack_aim_point()->Vector3:
	var point=crosshair_target()
	if player.auto_aim_target()!=null:return point
	var forward=Vector3.FORWARD.rotated(Vector3.UP,camera_rig.yaw)
	# Near-floor/overlapping camera hits should not turn a close melee stroke
	# sideways or backward. Ranged trajectories still use the exact 3D ray hit.
	if (point-player.global_position).dot(forward)<.75*player.growth_multiplier():
		var height=point.y;point=player.global_position+forward*8*player.growth_multiplier();point.y=height
	return point
func attack_direction()->Vector3:
	var direction=attack_aim_point()-player.global_position;direction.y=0
	return direction.normalized() if direction.length_squared()>.0001 else Vector3.FORWARD.rotated(Vector3.UP,camera_rig.yaw)
func _sync_camera_mouse():
	if not is_inside_tree():return
	var live=model!=null and playing and model.phase=="wave" and not paused and not get_tree().paused and not transitioning and not rogue_roster_open and is_instance_valid(player) and player.hp>0 and camera_focused
	var mode=Input.MOUSE_MODE_CAPTURED if live else Input.MOUSE_MODE_VISIBLE
	if Input.mouse_mode!=mode:Input.mouse_mode=mode
func _notification(what):
	if what==NOTIFICATION_APPLICATION_FOCUS_OUT:
		camera_focused=false;_sync_camera_mouse()
	elif what==NOTIFICATION_APPLICATION_FOCUS_IN:
		camera_focused=true;_sync_camera_mouse()
func set_phase_view():
	if model.phase!="wave" and is_instance_valid(tower_arrows):tower_arrows.clear()
	if model.phase!="wave" and is_instance_valid(enemy_arrows):enemy_arrows.clear()
	last_phase=model.phase;build_kind="";wall_start=Vector2i(-999,-999);ordinary_pause=false
	world.preview.hide();model.workforce.cancel_rally();player.rogue_controls.reset();player.velocity=Vector3.ZERO
	paused=model.phase!="wave";get_tree().paused=paused
	_sync_camera_mouse()
	player.reset_auto_attack()
	player.combat_aim_left=0
	if is_instance_valid(native_ink_feedback):native_ink_feedback.clear()
	if model.phase=="preparing":
		set_music_track("res://audio/talesweaver_dive.mp3")
		player.cancel_charge();player.attack_left=0;player.queued=false;player.attack_chain.reset()
		for group in ["projectiles","boss_waves","sky_smoke","edo_explosions","combo_energy"]:
			for effect in get_tree().get_nodes_in_group(group):
				if is_ancestor_of(effect):effect.queue_free()
		for actor in actors.values():
			if is_instance_valid(actor):actor.queue_free()
		actors.clear();enemies.clear();crowd.clear()
		pan=Vector3(0,0,100) if not model.ramparts.is_empty() else player.position;pan.y=0;rogue_view.clear();update_preparation_camera()
	elif model.phase=="wave":
		set_music_track("res://audio/talesweaver_reminiscence.mp3")
		camera_rig.camera.projection=Camera3D.PROJECTION_PERSPECTIVE
		camera_rig.distance=settings.forest_camera_distance
		camera_rig.reset_follow();camera_rig.current_distance=camera_rig.distance;camera_rig._process(0)
	elif model.phase=="victory":
		won=true;forest_ui.show_overlay("THE SHRINE ENDURES","%d waves survived. The forest is yours."%model.balance.waves.size(),false)
	else:forest_ui.show_overlay("THE SHRINE HAS FALLEN","Wave %d · Gather your strength and try again."%model.wave,false)
	sync_training_dummy();world.update_fog();forest_ui.sync()
func sync_training_dummy():
	if not is_instance_valid(training_dummy):
		training_dummy=preload("res://scripts/forest/forest_training_dummy.gd").new()
		training_dummy.name="TrainingDummy";training_dummy.game=self;training_dummy.position=model.point(model.TRAINING_DUMMY_CELL)
		training_dummy.process_mode=Node.PROCESS_MODE_PAUSABLE;add_child(training_dummy)
	if not enemies.has(training_dummy):enemies.append(training_dummy)
	training_dummy.visible=playing and model.phase in ["preparing","wave"] and model.visible_at(training_dummy.position)
	if model.phase=="preparing":training_dummy.reset_pose()
func update_preparation_camera():
	var cam=camera_rig.camera;cam.projection=Camera3D.PROJECTION_ORTHOGONAL;cam.size=preparation_size
	cam.global_position=pan+Vector3(0,160,110);cam.look_at(pan,Vector3.UP)
func start_wave():
	if not playing or ordinary_pause or rogue_roster_open or (is_instance_valid(map_editor) and map_editor.active):return
	if model.start_wave():
		forest_ui.selected_id=-1;set_phase_view();toast("The forest stirs. Watch the edges of your vision.")
func select_build(kind: String):
	if not playing or ordinary_pause or model.phase!="preparing":return
	build_kind=kind;forest_ui.selected_id=-1;wall_start=Vector2i(-999,-999)
func recruit_worker():
	if not playing or ordinary_pause or settings_open or rogue_roster_open or model.phase!="preparing":return
	if model.workforce.recruit():world.sync(0)
	else:toast("Need 50 gold and room in the 24-worker roster")
func ground_at(screen: Vector2)->Vector3:
	var cam=camera_rig.camera;var from=cam.project_ray_origin(screen);var direction=cam.project_ray_normal(screen)
	if not model.ramparts.is_empty():
		var query=PhysicsRayQueryParameters3D.create(from,from+direction*2000,1)
		var hit=world.get_world_3d().direct_space_state.intersect_ray(query)
		if not hit.is_empty():return hit.position
	if absf(direction.y)<.001:return Vector3.ZERO
	return from+direction*(-from.y/direction.y)
func place_cell(cell: Vector2i)->bool:
	if not playing or ordinary_pause or model.phase!="preparing" or build_kind.is_empty():return false
	var reason=model.placement_error(build_kind,cell,build_rotation)
	if not reason.is_empty():toast(reason);return false
	var b=model.build(build_kind,cell,build_rotation)
	if b.is_empty():return false
	if b.kind in ["mine","tower"]:model.workforce.assign_idle(b.id)
	forest_ui.selected_id=b.id;world.sync(0)
	if build_kind!="wall":build_kind="";world.preview.hide()
	return true
func _input(event):
	if model==null:return
	if is_instance_valid(map_editor) and map_editor.active:map_editor.global_input(event);return
	if settings_open:
		if event.is_action_pressed("pause") and not event.is_echo():
			if is_instance_valid(menu) and menu.find_child("CoreBalance",true,false)!=null and menu.find_child("CoreBalance",true,false).from_map:resume()
			elif is_instance_valid(menu) and (menu.find_child("SoundStudio",true,false)!=null or menu.find_child("CharacterBalance",true,false)!=null or menu.find_child("CoreBalance",true,false)!=null or menu.find_child("ForestViewSettings",true,false)!=null):show_settings(settings_from_pause)
			elif settings_from_pause:show_pause()
			else:show_title()
			get_viewport().set_input_as_handled()
		return
	if not playing and not rogue_roster_open:return
	if event.is_action("character_toggle"):
		if event.is_pressed() and not event.is_echo():
			if rogue_roster_open:close_rogue_roster()
			else:show_rogue_roster()
		get_viewport().set_input_as_handled();return
	if rogue_roster_open:
		if event.is_action_pressed("pause") and not event.is_echo():close_rogue_roster()
		if event.is_action("pause"):get_viewport().set_input_as_handled()
		return
	if event.is_action("summon_dogs") or event.is_action("summon_heroes") or event.is_action("shuffle_map"):
		get_viewport().set_input_as_handled();return
	if event.is_action("rally_workers"):
		if not ordinary_pause and not event.is_echo():model.rally(event.is_pressed(),player.position)
		get_viewport().set_input_as_handled()
	if event.is_action_pressed("pause") and not event.is_echo():
		if not build_kind.is_empty():build_kind="";world.preview.hide()
		elif ordinary_pause:resume()
		elif model.phase in ["preparing","wave"]:show_pause()
		get_viewport().set_input_as_handled()
func _unhandled_input(event):
	if model==null or not playing or ordinary_pause or settings_open or rogue_roster_open:return
	if is_instance_valid(map_editor) and map_editor.active:map_editor.handle_input(event);return
	if model.phase=="wave":
		return
	if model.phase!="preparing":return
	if event is InputEventKey and not event.echo:
		var code=event.physical_keycode if event.physical_keycode!=0 else event.keycode
		if code>=KEY_1 and code<=KEY_5:
			if event.pressed:
				if code==KEY_5:recruit_worker()
				else:select_build(["mine","tower","wall","gate"][code-KEY_1])
			get_viewport().set_input_as_handled();return
		if event.pressed and code==KEY_R and not build_kind.is_empty():
			build_rotation=(build_rotation+1)%4;wall_start=Vector2i(-999,-999)
			get_viewport().set_input_as_handled();return
	if event is InputEventMouseMotion and event.button_mask&MOUSE_BUTTON_MASK_MIDDLE:
		pan+=Vector3(-event.relative.x,0,-event.relative.y)*preparation_size/700.0;update_preparation_camera()
	if event is InputEventMouseButton:
		if event.button_index==MOUSE_BUTTON_WHEEL_UP and event.pressed:preparation_size=clampf(preparation_size-12,60,300)
		if event.button_index==MOUSE_BUTTON_WHEEL_DOWN and event.pressed:preparation_size=clampf(preparation_size+12,60,300)
		if event.button_index==MOUSE_BUTTON_RIGHT and event.pressed:build_kind="";world.preview.hide();wall_start=Vector2i(-999,-999)
		if event.button_index==MOUSE_BUTTON_LEFT:
			var cell=model.cell_of(ground_at(event.position))
			if event.pressed:
				if build_kind=="wall":wall_start=cell
				elif not build_kind.is_empty():place_cell(cell)
				else:forest_ui.selected_id=model.occupancy.get(cell,-1)
			elif build_kind=="wall" and wall_start.x!=-999:
				var cells=wall_cells(cell)
				var result=model.build_wall_line(cells,build_rotation)
				if result.is_empty():toast("Wall line was not built. Check gold, clear ground, and gate access.")
				else:world.sync(0)
				wall_start=Vector2i(-999,-999)
		get_viewport().set_input_as_handled()
func _process(delta):
	if model==null:return
	_sync_camera_mouse()
	if is_instance_valid(map_editor) and map_editor.active:map_editor.tick(delta);return
	if not paused and is_instance_valid(tower_arrows):tower_arrows.sync(delta)
	if not paused and is_instance_valid(enemy_arrows):enemy_arrows.sync(delta)
	if is_instance_valid(native_ink_feedback):native_ink_feedback.tick(delta)
	if not ordinary_pause:
		if model.phase=="preparing":
			model.tick(delta,player.position)
			var move_=Input.get_vector("move_left","move_right","move_forward","move_back")
			pan+=Vector3(move_.x,0,move_.y)*delta*preparation_size*.7
			pan.x=clampf(pan.x,-155,155);pan.z=clampf(pan.z,-155,155);update_preparation_camera()
			if not build_kind.is_empty():
				var cell=model.cell_of(ground_at(get_viewport().get_mouse_position()))
				var reason=model.placement_error(build_kind,cell,build_rotation)
				placement_hint=reason if not reason.is_empty() else ("Drag a wall line" if build_kind=="wall" else "Click to place")
				if build_kind=="wall" and wall_start.x!=-999:
					var cells=wall_cells(cell);var cost=cells.size()*model.COSTS.wall;var valid=model.gold>=cost
					for c in cells:
						if not model.placement_error("wall",c,build_rotation).is_empty():valid=false
					placement_hint="%d segments · %d gold · Release to build"%[cells.size(),cost] if valid else "Blocked line or insufficient gold · %d gold"%cost
					world.show_wall_preview(cells,build_rotation,valid)
				else:world.show_preview(build_kind,cell,build_rotation,reason.is_empty())
		else:
			hit_stop=maxf(0,hit_stop-delta);chain_timer-=delta
			if chain_timer<=0:chain=0
		world.sync(delta)
func _physics_process(delta):
	if model!=null and model.phase!=last_phase:set_phase_view()
	if model==null or paused or model.phase!="wave":return
	model.hero_targetable=not player.rogue_untargetable()
	model.tick(delta,player.position)
	for event in model.events:
		match event.kind:
			"hero_hit":player.take_hit(event.amount,(player.position-event.from).normalized(),event.get("projectile",false))
			"wounded":toast("A worker is wounded. They will recover during preparation.")
			"arrow":
				tower_arrows.launch(event)
			"arrow_impact":tower_arrows.impact(event)
			"enemy_arrow":enemy_arrows.launch(event)
			"enemy_arrow_impact":enemy_arrows.impact(event)
	model.events.clear();sync_enemies()
	if model.phase!=last_phase:set_phase_view()
func sync_enemies():
	for data in model.enemies.values():
		if not actors.has(data.id):
			var actor=Raider.new();actor.game=self;actor.forest_id=data.id;actor.variant=data.variant;actor.swarm=true;actor.position=data.pos
			actor.process_mode=Node.PROCESS_MODE_PAUSABLE;add_child(actor);actor.hp=data.hp;actor.max_hp=data.max_hp
			actors[data.id]=actor;enemies.append(actor)
	for id in actors.keys():
		if not is_instance_valid(actors[id]):actors.erase(id)
	for i in range(enemies.size()-1,-1,-1):
		if not is_instance_valid(enemies[i]):enemies.remove_at(i)
func forest_enemy_visible(enemy)->bool:
	if model==null:return false
	if model.visible_at(enemy.global_position):return true
	if enemy.variant!=2:return false
	# A giant can enter sight feet first, while its root is still in hidden ground.
	var radius=14.0
	var center=model.cell_of(enemy.global_position);var reach=ceili(radius/model.CELL)
	for x in range(-reach,reach+1):
		for z in range(-reach,reach+1):
			var point=model.point(center+Vector2i(x,z))
			if Vector2(point.x-enemy.global_position.x,point.z-enemy.global_position.z).length()<=radius and model.visible_at(point):return true
	return false
func forest_point_visible(point: Vector3)->bool:return model!=null and model.visible_at(point)
func show_rogue_roster(starting: bool=false):
	if not playing and not starting:return
	if model.phase not in ["preparing","wave"] or player.hp<=0 or rogue_roster_open:return
	roster_return_pause=ordinary_pause
	player.cancel_charge(true);model.workforce.cancel_rally();Engine.time_scale=1
	ordinary_pause=true;paused=true;get_tree().paused=true
	_sync_camera_mouse()
	build_kind="";wall_start=Vector2i(-999,-999);world.preview.hide();forest_ui.hide()
	rogue_roster_open=true;rogue_pick_start=starting
	var root=menu_base()
	var picker=load("res://scripts/rogue_roster_picker.gd").new();picker.game=self
	picker.title_text="F O R E S T   S H R I N E   /   C H O O S E   Y O U R   F I G H T E R"
	picker.start_hint="Choose a fighter, then build your settlement before the first wave."
	picker.back_text="Q / Esc · Back to preparation" if model.phase=="preparing" else "Q / Esc · Back to battle"
	root.add_child(picker)
func choose_rogue_character(id: int):
	if not rogue_roster_open or (id not in [1,2] and not player.RogueRoster.is_rogue(id)):return
	selected_rogue_id=id;get_tree().set_meta("forest_fighter",id);player.select_character(id)
	var starting=rogue_pick_start
	rogue_roster_open=false;rogue_pick_start=false;clear_menu();forest_ui.show()
	if starting:
		playing=true;set_phase_view()
	elif roster_return_pause:show_pause()
	else:resume()
func close_rogue_roster():
	if not rogue_roster_open:return
	var starting=rogue_pick_start
	rogue_roster_open=false;rogue_pick_start=false;clear_menu();forest_ui.show()
	if starting:show_main_menu()
	elif roster_return_pause:show_pause()
	else:resume()
func show_pause():
	if model==null or model.phase not in ["preparing","wave"]:return
	settings_open=false;clear_menu();forest_ui.show()
	ordinary_pause=true;paused=true;get_tree().paused=true;model.workforce.cancel_rally();player.cancel_charge(true);Engine.time_scale=1
	_sync_camera_mouse()
	forest_ui.show_overlay("REST A MOMENT","Your settlement and the forest are paused.",true)
func resume():
	if model.phase not in ["preparing","wave"]:return
	forest_ui.view_settings_preview=false
	settings_open=false;clear_menu();forest_ui.show()
	ordinary_pause=false;forest_ui.close_overlay();paused=model.phase!="wave";get_tree().paused=paused
	_sync_camera_mouse()
func restart_area():
	get_tree().paused=false;get_tree().change_scene_to_file.call_deferred("res://scenes/forest_shrine.tscn")
func show_main_menu():
	get_tree().paused=false
	get_tree().change_scene_to_file.call_deferred("res://scenes/forest_title.tscn")
func defeat():
	if model.phase=="wave":model.phase="defeat";set_phase_view()
func toast(words: String):
	if is_instance_valid(forest_ui):forest_ui.notify(words)
func drop_powerup(_point: Vector3):pass
func damage_number(p: Vector3,amount: int,heavy: bool,critical: bool=false):
	if model.visible_at(p):super.damage_number(p,amount,heavy,critical)
func burst(p: Vector3,color: Color,count: int,scale_factor: float=1.0):
	if model!=null and model.visible_at(p):super.burst(p,color,count,scale_factor)
func confirm_impact(victim: Ninja,p: Vector3,direction: Vector3,strength: int,projectile: bool):
	if model.visible_at(p):super.confirm_impact(victim,p,direction,strength,projectile)
func impact_effect(p: Vector3,direction: Vector3,strength: int):
	if model.visible_at(p):super.impact_effect(p,direction,strength)

func wall_cells(end: Vector2i)->Array:
	var change=end-wall_start;var horizontal=build_rotation%2==0
	var distance=change.x if horizontal else change.y
	var span: int=model.SIZES.wall.x
	var cells=[]
	for i in range(mini(absi(distance)/span+1,40)):
		var offset=signi(distance)*i*span
		cells.append(wall_start+(Vector2i(offset,0) if horizontal else Vector2i(0,offset)))
	return cells

func apply_music_setting():
	# The preference controls gameplay music; the title and its menus stay silent.
	if not playing:
		if is_instance_valid(music):music.stop()
		return
	super.apply_music_setting()

func set_music_track(path: String):
	if music.stream.resource_path!=path:
		music.stop()
		music.stream=load(path)
		music.stream.loop=true
	apply_music_setting()

func show_title():
	settings_open=false
	playing=false;ordinary_pause=true;paused=true;get_tree().paused=true
	apply_music_setting()
	_sync_camera_mouse()
	forest_ui.hide();update_preparation_camera();rogue_feedback.set_enabled(false)
	world.ground_material.set_shader_parameter("show_grid",false)
	var root=menu_base()
	var title_ui=preload("res://scripts/forest/forest_title_ui.gd").new();title_ui.game=self;root.add_child(title_ui)
func show_settings(from_pause: bool):
	settings_open=true;settings_from_pause=from_pause
	ordinary_pause=true;paused=true;get_tree().paused=true
	model.workforce.cancel_rally();player.cancel_charge(true);Engine.time_scale=1
	_sync_camera_mouse()
	forest_ui.view_settings_preview=false;forest_ui.close_overlay();forest_ui.hide()
	super.show_settings(from_pause)
func load_settings():
	super.load_settings()
	apply_forest_view_settings()
func apply_forest_view_settings():
	if is_instance_valid(camera_rig):
		camera_rig.distance=settings.forest_camera_distance
		camera_rig.character_screen_offset=settings.forest_character_screen_offset
		if model!=null and playing and model.phase=="wave":
			camera_rig.current_distance=camera_rig.distance;camera_rig.update_camera(0,true)
	if is_instance_valid(forest_ui):forest_ui.sync()
func set_forest_camera_distance(value):
	settings.forest_camera_distance=ViewPreferences.bounded(value,ViewPreferences.CAMERA_DEFAULT,ViewPreferences.CAMERA_MIN,ViewPreferences.CAMERA_MAX)
	apply_forest_view_settings();save_settings()
func set_forest_hud_scale(value):
	settings.forest_hud_scale=ViewPreferences.bounded(value,ViewPreferences.HUD_DEFAULT,ViewPreferences.HUD_MIN,ViewPreferences.HUD_MAX)
	if is_instance_valid(forest_ui):forest_ui.sync()
	save_settings()
func set_forest_character_screen_offset(value):
	settings.forest_character_screen_offset=ViewPreferences.bounded(value,ViewPreferences.CHARACTER_OFFSET_DEFAULT,ViewPreferences.CHARACTER_OFFSET_MIN,ViewPreferences.CHARACTER_OFFSET_MAX)
	apply_forest_view_settings();save_settings()
func set_forest_show_crosshair(value):
	settings.forest_show_crosshair=value if value is bool else true
	if is_instance_valid(forest_ui):forest_ui.reticle.queue_redraw()
	save_settings()
func show_view_settings(from_pause: bool):
	settings_open=true;settings_from_pause=from_pause;ordinary_pause=true;paused=true;get_tree().paused=true
	model.workforce.cancel_rally();player.cancel_charge(true);Engine.time_scale=1;_sync_camera_mouse()
	forest_ui.close_overlay();forest_ui.view_settings_preview=true;forest_ui.show();forest_ui.sync()
	var root=menu_base();root.get_child(0).color.a=.22
	var controls=preload("res://scripts/forest/forest_view_settings.gd").new();controls.game=self;controls.from_pause=from_pause;root.add_child(controls)
func show_lab():
	show_settings(playing)
	show_character_balance(playing)
func begin_forest():
	if playing:return
	# Title settings belong to the run about to start, not the preview snapshot.
	model.reset(run_seed,core_balance,active_forest_map());world.reload_map();forest_ui.sync()
	show_rogue_roster(true)

func apply_core_towers():
	if model!=null:model.apply_tower_balance(core_balance)

func show_building_balance():
	if not playing or ordinary_pause or settings_open or rogue_roster_open or model.phase!="preparing":return
	settings_open=true;settings_from_pause=true;ordinary_pause=true;paused=true;get_tree().paused=true
	model.workforce.cancel_rally();player.cancel_charge(true);Engine.time_scale=1
	build_kind="";wall_start=Vector2i(-999,-999);world.preview.hide()
	_sync_camera_mouse();forest_ui.close_overlay();forest_ui.hide()
	show_core_balance(true,true)

func active_forest_map()->Dictionary:
	var layout=get_tree().get_meta("forest_custom_layout",{})
	if layout is Dictionary and not layout.is_empty() and MapDocument.validate(layout).is_empty():return layout.duplicate(true)
	if "--original-map" in OS.get_cmdline_user_args():return {}
	var document=MapDocument.new()
	if document.load_ramparts().is_empty():return document.data.duplicate(true)
	push_error("Could not load the Twin Ramparts preset")
	return {}
func open_map_editor():
	if not playing or ordinary_pause or settings_open or rogue_roster_open or model.phase!="preparing":return
	build_kind="";wall_start=Vector2i(-999,-999);world.preview.hide();forest_ui.selected_id=-1
	map_editor.open()
func preview_forest_map(layout: Dictionary,preview: bool=true):
	var saved_pan=pan
	model=ForestModel.new();model.reset(run_seed,core_balance,layout)
	if preview:
		for x in range(-40,40):
			for z in range(-40,40):model.explored[Vector2i(x,z)]=true;model.visible_cells[Vector2i(x,z)]=true
	else:
		player.progression.reset(false);player.refresh_max_health();player.hp=player.max_hp;won=false;checkpoint=player.position
	world.model=model;world.reload_map();set_phase_view()
	if preview:pan=saved_pan;update_preparation_camera()
