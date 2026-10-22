extends "res://scripts/game.gd"
const ForestModel=preload("res://scripts/forest/forest_model.gd")
const ForestWorld=preload("res://scripts/forest/forest_world.gd")
const Raider=preload("res://scripts/forest/forest_raider.gd")
const MapDocument=preload("res://scripts/forest/forest_map_document.gd")
const COMBAT_CAMERA_PITCH=.22
const COMBAT_CAMERA_FOCUS_RISE=2.0
const PLAYER_RESPAWN_DELAY=3.0
const PLAYER_RESPAWN_PROTECTION=2.0
const PLAYER_SPAWN_CELL=Vector2i(0,3)
const PREPARATION_ZOOM_STEP=1.15
const PREPARATION_ZOOM_MIN=20.0
@export var launch_to_title=false
var model
var gate_defenders
var explorer_helpers
var army_runtime:Node
var forest_ui
var build_kind=""
var build_rotation=0
var placement_hint="Click to place"
var _placement_cache_key:Array=[]
var _placement_cache:Dictionary={}
var _placement_cache_until=0
var pan=Vector3.ZERO
var preparation_size=120.0
var actors: Dictionary={}
var training_dummy: Ninja
var last_phase=""
var model_tick_serial=0
var world_step_elapsed=0.0
var world_step_waves:WeakRef
var world_slice_limit=0
var wall_start=Vector2i(-999,-999)
var ordinary_pause=false
var notice=""
var roster_return_pause=false
var settings_open=false
var settings_from_pause=false
var tower_arrows
var enemy_arrows
var camera_focused=true
var painterly_preview=false
var combat_warmup:Node
var respawn_left=0.0
var ryo_visuals:Node3D
var ryo_feedback_left=0.0
var wall_audio:Node3D
var placement_audio:Node
func _ready():
	preload("res://scripts/recovered_ed_beam_native_state.gd").world_clock(self)
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
	model=ForestModel.new();run_seed=90824 if smoke_test else int(Time.get_ticks_usec())%2147483647;model.reset(run_seed,core_balance,active_forest_map(),false)
	if model.has_elevation():
		var frame=preparation_map_frame();pan=frame.pan;preparation_size=frame.size
	painterly_preview=bool(get_tree().get_meta("forest_painterly_preview",OS.has_feature("painterly_preview") or "--painterly-preview" in OS.get_cmdline_user_args()))
	world=ForestWorld.new();world.model=model;world.painterly_preview_enabled=painterly_preview;world.process_mode=Node.PROCESS_MODE_PAUSABLE;add_child(world)
	tower_arrows=preload("res://scripts/forest/forest_tower_arrows.gd").new();tower_arrows.game=self;add_child(tower_arrows)
	enemy_arrows=preload("res://scripts/forest/forest_enemy_arrows.gd").new();enemy_arrows.game=self;add_child(enemy_arrows)
	player=Hero.new();player.game=self;player.position=Vector3(0,.15,18);player.process_mode=Node.PROCESS_MODE_PAUSABLE;add_child(player)
	selected_rogue_id=int(get_tree().get_meta("forest_fighter",1))
	if selected_rogue_id not in player.RogueRoster.selection_ids():selected_rogue_id=1
	get_tree().set_meta("forest_fighter",selected_rogue_id)
	player.select_character(selected_rogue_id);player.progression.reset(false);player.refresh_max_health();player.hp=player.max_hp;player.soft_target=false
	checkpoint=player.position
	camera_rig=ActionCamera.new();camera_rig.game=self;camera_rig.player=player;add_child(camera_rig)
	camera_rig.sens=settings.sensitivity
	camera_rig.pitch=COMBAT_CAMERA_PITCH;camera_rig.distance=settings.forest_camera_distance
	camera_rig.character_screen_offset=settings.forest_character_screen_offset
	camera_rig.crosshair_focus_rise=COMBAT_CAMERA_FOCUS_RISE
	camera_rig.travel_follow.forward_buffer=0.0
	wall_audio=preload("res://scripts/forest/forest_wall_audio.gd").new();wall_audio.game=self;add_child(wall_audio)
	placement_audio=preload("res://scripts/forest/forest_placement_audio.gd").new();placement_audio.game=self;add_child(placement_audio)
	rogue_view=preload("res://scripts/forest/forest_view.gd").new();rogue_view.game=self;add_child(rogue_view)
	rogue_feedback=preload("res://scripts/rogue_battle_feedback.gd").new();rogue_feedback.game=self;add_child(rogue_feedback)
	crowd=preload("res://scripts/forest/forest_enemy_crowd.gd").new()
	crowd.game=self;crowd.process_mode=Node.PROCESS_MODE_PAUSABLE;add_child(crowd)
	if get_tree().get_meta("forest_army_backend","legacy")=="native":
		army_runtime=preload("res://scripts/forest/crowd/army_coordinator.gd").new();add_child(army_runtime);army_runtime.setup(self)
	# Build fitted collision hulls during scene loading, before combat. Their
	# first use otherwise blocks a spawn frame while generating convex meshes.
	for kind in range(Raider.Roles.COUNT):Raider.Contact.shapes(kind)
	pursuit=EnemyPursuit.new();pursuit.game=self;add_child(pursuit);pursuit.set_physics_process(false)
	encounters=EndlessEncounters.new();encounters.game=self;encounters.enabled=false;add_child(encounters)
	ui=CanvasLayer.new();add_child(ui)
	forest_ui=preload("res://scripts/forest/forest_ui.gd").new();forest_ui.game=self;ui.add_child(forest_ui)
	map_editor=preload("res://scripts/forest/forest_map_editor.gd").new();map_editor.game=self;ui.add_child(map_editor)
	playing=not launch_to_title;won=false;Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	gate_defenders=preload("res://scripts/forest/forest_gate_defenders.gd").new();gate_defenders.game=self;add_child(gate_defenders)
	explorer_helpers=preload("res://scripts/forest/explorer_helpers.gd").new();explorer_helpers.name="ExplorerHelpers";explorer_helpers.game=self;add_child(explorer_helpers)
	rogue_view.set_enabled(false);rogue_feedback.set_enabled(false);set_phase_view()
	if launch_to_title:show_title()
	combat_warmup=preload("res://scripts/forest/forest_combat_warmup.gd").new();add_child(combat_warmup)
func toggle_painterly_preview():
	painterly_preview=not painterly_preview
	get_tree().set_meta("forest_painterly_preview",painterly_preview)
	world.set_painterly_preview(painterly_preview)
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
	var live=model!=null and playing and model.phase=="wave" and not paused and not get_tree().paused and not ordinary_pause and not settings_open and not transitioning and not rogue_roster_open and is_instance_valid(player) and player.hp>0 and camera_focused
	if not live and is_instance_valid(player) and player.character_id==player.RogueRoster.MASTER_CHIEF_ID and player.active_ability!=null:
		player.active_ability.cancel()
	if is_instance_valid(camera_rig) and camera_rig.has_method("sync_character_view"):camera_rig.sync_character_view()
	var mode=Input.MOUSE_MODE_CAPTURED if live else Input.MOUSE_MODE_VISIBLE
	if Input.mouse_mode!=mode:Input.mouse_mode=mode
func _notification(what):
	if what==NOTIFICATION_APPLICATION_FOCUS_OUT:
		camera_focused=false;_sync_camera_mouse()
	elif what==NOTIFICATION_APPLICATION_FOCUS_IN:
		camera_focused=true;_sync_camera_mouse()
func set_phase_view():
	if not model.construction_completed.is_connected(_clear_construction_occupants):model.construction_completed.connect(_clear_construction_occupants)
	if model.phase=="preparing" and is_instance_valid(player):
		var hero_cell:Vector2i=model.cell_of(player.position)
		if not model.navigation_region.has_point(hero_cell) or model.occupancy.has(hero_cell) or model.allied_grid.is_point_solid(hero_cell):
			var safe_spawn=_player_respawn_point()
			if safe_spawn.is_finite():ForestModel.ConstructionClearance.move_body(player,safe_spawn);checkpoint=safe_spawn
		model.hero_position=player.position
	if model.phase!="wave" and is_instance_valid(wall_audio):wall_audio.reset()
	if model.has_method("cancel_wave_step"):model.cancel_wave_step()
	world_step_waves=null;world_slice_limit=0
	world_step_elapsed=0.0
	if respawn_left>0:
		if model.phase=="preparing":_respawn_player()
		elif model.phase!="wave":respawn_left=0.0
	if is_instance_valid(explorer_helpers):
		if model.phase=="preparing":explorer_helpers.rest()
		elif model.phase=="wave":explorer_helpers.begin_wave()
		elif model.phase!="wave":explorer_helpers.clear()
	if is_instance_valid(gate_defenders):gate_defenders.reconcile(model.phase=="preparing")
	if is_instance_valid(explorer_helpers):explorer_helpers.sync_targets()
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
		var frame=preparation_map_frame();pan=frame.pan;pan.y=0
		if frame.overview:preparation_size=frame.size
		# The separate preview opens close enough to judge the art. Combat framing
		# and all controls remain shared with the regular game.
		if not frame.overview and painterly_preview and world.painterly_pilot!=null and not world.painterly_pilot.selected_ids.is_empty():
			pan=Vector3.ZERO
			for id in world.painterly_pilot.selected_ids:pan+=model.center(model.buildings[id])
			pan/=world.painterly_pilot.selected_ids.size();preparation_size=90
		rogue_view.clear();update_preparation_camera()
	elif model.phase=="wave":
		set_music_track("res://audio/talesweaver_dive.mp3")
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
func preparation_map_frame()->Dictionary:
	if model.terrain_source in ["kai_highway","blood_gulch"]:return {"pan":Vector3.ZERO,"size":600.0*model.terrain_scale,"overview":true}
	if not model.has_elevation():return {"pan":player.position if is_instance_valid(player) else Vector3.ZERO,"size":120.0,"overview":false}
	if model.portals.size()<=2:return {"pan":Vector3(0,0,100),"size":340.0,"overview":false}
	var low=Vector2(INF,INF);var high=Vector2(-INF,-INF)
	for portal in model.portals:
		var point=Vector2(portal.x,portal.z)*6;low=low.min(point);high=high.max(point)
	var center=(low+high)*.5;var extent=high-low
	return {"pan":Vector3(center.x,0,center.y),"size":maxf(340,ceil(maxf(extent.x,extent.y)*1.35/20)*20),"overview":true}
func update_preparation_camera():
	var cam=camera_rig.camera;cam.projection=Camera3D.PROJECTION_ORTHOGONAL;cam.size=preparation_size
	cam.global_position=pan+Vector3(0,160,110);cam.look_at(pan,Vector3.UP)
func preparation_zoom_limits()->Vector2:
	return Vector2(PREPARATION_ZOOM_MIN,maxf(PREPARATION_ZOOM_MIN,600.0*model.terrain_scale if model!=null else 600.0))
func clamp_preparation_pan():
	var bounds=model.world_bounds().grow(-model.CELL)
	pan.x=clampf(pan.x,bounds.position.x,bounds.end.x);pan.z=clampf(pan.z,bounds.position.y,bounds.end.y)
func _preparation_zoom_available()->bool:
	if model==null or not playing or model.phase!="preparing" or ordinary_pause or settings_open or rogue_roster_open or transitioning:return false
	if is_instance_valid(map_editor) and map_editor.active:return false
	if is_instance_valid(forest_ui) and (is_instance_valid(forest_ui.overlay) or forest_ui.get_node_or_null("GateDefenderPanel")!=null):return false
	return is_instance_valid(camera_rig)
func zoom_preparation(steps:float,screen:Vector2=Vector2(INF,INF))->bool:
	if not _preparation_zoom_available() or not is_finite(steps):return false
	var limits=preparation_zoom_limits()
	var next_size=clampf(preparation_size*pow(PREPARATION_ZOOM_STEP,-clampf(steps,-100,100)),limits.x,limits.y)
	if is_equal_approx(next_size,preparation_size):return false
	if not screen.is_finite():screen=get_viewport().get_visible_rect().size*.5
	var anchor=ground_at(screen)
	preparation_size=next_size;update_preparation_camera()
	# Preserve the pointed world location, even on raised terrain. Intersect
	# the new ray with the anchor's height so buildings cannot steal the hit.
	var cam=camera_rig.camera;var origin=cam.project_ray_origin(screen);var direction=cam.project_ray_normal(screen)
	if absf(direction.y)>.001:
		var projected=origin+direction*((anchor.y-origin.y)/direction.y)
		pan+=Vector3(anchor.x-projected.x,0,anchor.z-projected.z)
		clamp_preparation_pan()
		update_preparation_camera()
	return true
func reset_preparation_zoom()->bool:
	if not _preparation_zoom_available():return false
	var frame=preparation_map_frame();pan=frame.pan;pan.y=0
	var limits=preparation_zoom_limits();preparation_size=clampf(frame.size,limits.x,limits.y)
	update_preparation_camera();return true
func _preparation_zoom_input(event:InputEvent)->bool:
	if event is InputEventKey:
		if event.ctrl_pressed or event.alt_pressed or event.meta_pressed:return false
		var focus=get_viewport().gui_get_focus_owner()
		if focus is LineEdit or focus is TextEdit:return false
		var code=event.physical_keycode if event.physical_keycode!=0 else event.keycode
		if code not in [KEY_PLUS,KEY_EQUAL,KEY_KP_ADD,KEY_MINUS,KEY_KP_SUBTRACT]:return false
		if event.pressed and not event.echo:zoom_preparation(-1 if code in [KEY_MINUS,KEY_KP_SUBTRACT] else 1)
		return true
	# Controls may pass wheel events through even when they stop clicks.
	if get_viewport().gui_get_hovered_control()!=null:return false
	if event is InputEventMouseButton and event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN]:
		if event.pressed:
			var amount=absf(event.factor) if event.factor!=0 else 1.0
			zoom_preparation(amount if event.button_index==MOUSE_BUTTON_WHEEL_UP else -amount,event.position)
		return true
	if event is InputEventMagnifyGesture:
		if is_finite(event.factor) and event.factor>0:zoom_preparation(log(event.factor)/log(PREPARATION_ZOOM_STEP),event.position)
		return true
	if event is InputEventPanGesture:
		zoom_preparation(-event.delta.y*.25,event.position);return true
	return false
func start_wave():
	if not playing or ordinary_pause or rogue_roster_open or (is_instance_valid(map_editor) and map_editor.active):return
	if model.phase=="preparing":
		for key in ["enemy_health_mult","enemy_damage_mult","enemy_speed_mult"]:model.balance[key]=core_balance[key]
	if model.start_wave():
		forest_ui.selected_id=-1;set_phase_view();toast("The enemy approaches. Defend the four gates.")
func select_build(kind: String):
	if not playing or ordinary_pause or model.phase!="preparing":return
	if kind=="mine":return
	if is_instance_valid(explorer_helpers):explorer_helpers.cancel_placement()
	build_kind=kind;forest_ui.selected_id=-1;wall_start=Vector2i(-999,-999)
	_placement_cache_key.clear()
func recruit_worker():
	if not playing or ordinary_pause or settings_open or rogue_roster_open or model.phase!="preparing":return
	build_kind="";world.preview.hide()
	if model.workforce.recruit():world.sync(0)
	else:toast("Need 1 food · Build a barracks" if not model.can_recruit(1) else "Need 50 ryo")
func ground_at(screen: Vector2)->Vector3:
	var cam=camera_rig.camera;var from=cam.project_ray_origin(screen);var direction=cam.project_ray_normal(screen)
	if model.has_elevation():
		var query=PhysicsRayQueryParameters3D.create(from,from+direction*2000,1)
		var hit=world.get_world_3d().direct_space_state.intersect_ray(query)
		if not hit.is_empty():return hit.position
	if absf(direction.y)<.001:return Vector3.ZERO
	return from+direction*(-from.y/direction.y)
func build_placement_target(cell:Vector2i,preserve_preview:bool=false)->Dictionary:
	# Cache path checks while hovering. Clicks keep the shown target and build()
	# revalidates it. Standing allies step aside only after the purchase commits.
	var key=[cell,build_kind,build_rotation,model.revision,model.gold,model.phase]
	var now=Time.get_ticks_msec()
	if key==_placement_cache_key and (preserve_preview or now<_placement_cache_until):return _placement_cache
	_placement_cache=model.resolve_placement(build_kind,cell,build_rotation,0 if build_kind=="wall" else 1)
	_placement_cache_key=key;_placement_cache_until=now+100
	return _placement_cache
func _clear_construction_occupants(added:Array):
	ForestModel.ConstructionClearance.relocate_game(self,added)
func place_cell(cell: Vector2i)->bool:
	if not playing or ordinary_pause or model.phase!="preparing" or build_kind.is_empty():return false
	var target_cell=build_placement_target(cell,true).cell
	var reason=model.placement_error(build_kind,target_cell,build_rotation)
	if not reason.is_empty():toast(reason);return false
	var b=model.build(build_kind,target_cell,build_rotation)
	if b.is_empty():return false
	if b.kind in ["mine","tower"]:model.workforce.assign_idle(b.id)
	forest_ui.selected_id=b.id;world.sync(0)
	if is_instance_valid(placement_audio):placement_audio.play_placement(b.kind)
	# Keep the chosen building and rotation ready for another placement.
	update_build_preview(cell)
	return true
func _input(event):
	if model==null:return
	if is_instance_valid(forest_ui) and forest_ui.preparation_menu_input(event):
		get_viewport().set_input_as_handled();return
	if is_instance_valid(explorer_helpers) and explorer_helpers.handle_global_input(event):
		get_viewport().set_input_as_handled();return
	var defender_panel=forest_ui.get_node_or_null("GateDefenderPanel") if is_instance_valid(forest_ui) else null
	if is_instance_valid(defender_panel):
		if event.is_action_pressed("pause") and not event.is_echo():defender_panel.close();get_viewport().set_input_as_handled()
		return
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
	if event is InputEventKey and not event.shift_pressed and not event.ctrl_pressed and not event.alt_pressed and not event.meta_pressed and (event.is_action("cape_red") or event.is_action("cape_gold")):
		if event.pressed and not event.echo:toggle_player_cape(event.is_action("cape_gold"))
		get_viewport().set_input_as_handled();return
	if model.phase=="preparing" and not ordinary_pause and event is InputEventKey and event.shift_pressed and not event.ctrl_pressed and not event.alt_pressed and not event.meta_pressed:
		var code=event.physical_keycode if event.physical_keycode!=0 else event.keycode
		if code>=KEY_1 and code<=KEY_5:
			if event.pressed and not event.echo:
				if code==KEY_5:recruit_worker()
				elif code in [KEY_2,KEY_3]:select_build("tower" if code==KEY_2 else "barracks")
			get_viewport().set_input_as_handled();return
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
func toggle_player_cape(gold:bool):
	if not playing or ordinary_pause or settings_open or rogue_roster_open or transitioning or won or player.hp<=0 or model.phase not in ["preparing","wave"]:return
	if model.phase=="wave" and paused:return
	if is_instance_valid(map_editor) and map_editor.active:return
	if is_instance_valid(forest_ui) and forest_ui.get_node_or_null("GateDefenderPanel")!=null:return
	if gold:player.set_gold_cloak(not player.gold_cloak)
	else:player.set_scarf_equipped(not player.scarf_equipped or player.gold_cloak)
	forest_ui.sync()
func _unhandled_input(event):
	if model==null or not playing or ordinary_pause or settings_open or rogue_roster_open:return
	if is_instance_valid(map_editor) and map_editor.active:map_editor.handle_input(event);return
	if model.phase=="wave":
		return
	if model.phase!="preparing":return
	if _preparation_zoom_input(event):
		get_viewport().set_input_as_handled();return
	if is_instance_valid(explorer_helpers) and explorer_helpers.handle_map_input(event):
		get_viewport().set_input_as_handled();return
	if event is InputEventKey and not event.echo:
		var code=event.physical_keycode if event.physical_keycode!=0 else event.keycode
		if event.pressed and code==KEY_R and not build_kind.is_empty():
			build_rotation=(build_rotation+1)%4;wall_start=Vector2i(-999,-999)
			get_viewport().set_input_as_handled();return
	if event is InputEventMouseMotion and event.button_mask&MOUSE_BUTTON_MASK_MIDDLE:
		pan+=Vector3(-event.relative.x,0,-event.relative.y)*preparation_size/700.0;clamp_preparation_pan();update_preparation_camera()
	if event is InputEventMouseButton:
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
				if result.is_empty():toast("Wall line was not built. Check ryo, clear ground, and gate access.")
				else:world.sync(0)
				wall_start=Vector2i(-999,-999)
		get_viewport().set_input_as_handled()
func _army_profile_clock()->int:return Time.get_ticks_usec() if is_instance_valid(army_runtime) and army_runtime.profile_enabled else 0
func _army_profile(label_:String,started:int)->int:return army_runtime.profile_mark(label_,started) if started>0 else 0
func update_build_preview(cell:Vector2i):
	var target=build_placement_target(cell);cell=target.cell
	var reason=target.error
	placement_hint=reason if not reason.is_empty() else ("Drag a wall line" if build_kind=="wall" else ("Nearby clear spot · Click to place" if target.adjusted else "Click to place"))
	if build_kind=="wall" and wall_start.x!=-999:
		var cells=wall_cells(cell);var cost=cells.size()*model.COSTS.wall;var valid=model.gold>=cost
		for c in cells:
			if not model.placement_error("wall",c,build_rotation).is_empty():valid=false
		placement_hint="%d segments · %d ryo · Release to build"%[cells.size(),cost] if valid else "Blocked line or insufficient ryo · %d ryo"%cost
		world.show_wall_preview(cells,build_rotation,valid)
	else:world.show_preview(build_kind,cell,build_rotation,reason.is_empty())
func _process(delta):
	if model==null:return
	var cpu_clock=_army_profile_clock()
	_sync_camera_mouse()
	if is_instance_valid(map_editor) and map_editor.active:map_editor.tick(delta);return
	if not paused and is_instance_valid(tower_arrows):tower_arrows.sync(delta)
	if not paused and is_instance_valid(enemy_arrows):enemy_arrows.sync(delta)
	if is_instance_valid(native_ink_feedback):native_ink_feedback.tick(delta)
	if not ordinary_pause:
		if model.phase=="preparing":
			if is_instance_valid(gate_defenders):gate_defenders.reconcile()
			model.tick(delta,player.position)
			var move_=Input.get_vector("move_left","move_right","move_forward","move_back")
			pan+=Vector3(move_.x,0,move_.y)*delta*preparation_size*.7
			clamp_preparation_pan();update_preparation_camera()
			if not build_kind.is_empty():
				update_build_preview(model.cell_of(ground_at(get_viewport().get_mouse_position())))
		else:
			hit_stop=maxf(0,hit_stop-delta);chain_timer-=delta
			if chain_timer<=0:chain=0
		cpu_clock=_army_profile("game_render_logic",cpu_clock)
		world.sync(delta)
		_army_profile("game_world_present",cpu_clock)
func world_update_interval()->float:
	if model.enemies.size()>=128:return 1.0/20
	if model.enemies.size()>=48 or explorer_helpers.living_count>=12:return 1.0/30
	return 0.0
func _advance_world(delta:float)->bool:
	if is_instance_valid(army_runtime):
		world_step_elapsed+=maxf(0,delta)
		if world_step_elapsed+.000001<world_update_interval():return false
		model.tick(world_step_elapsed,player.position);world_step_elapsed=0;model_tick_serial+=1;return true
	# Retain the logical20/30Hz clocks, but spread the enemy loop over physics
	# frames instead of making one frame pay for the entire crowd.
	var sliced=model.has_method("wave_step_active")
	if sliced:
		if world_step_waves!=null and world_step_waves.get_ref()!=model.waves:
			world_step_elapsed=0.0;world_slice_limit=0
		world_step_waves=weakref(model.waves)
		if model.phase!="wave":
			model.cancel_wave_step();world_step_elapsed=0.0;world_slice_limit=0;return false
	world_step_elapsed+=maxf(0,delta)
	if sliced and model.wave_step_active():
		if model.advance_wave_slice(world_slice_limit,player.position):world_slice_limit=0
		model_tick_serial+=1;return true
	if world_step_elapsed+0.000001<world_update_interval():return false
	if sliced and model.enemies.size()>=48:
		var frames=maxi(1,roundi(world_update_interval()*Engine.physics_ticks_per_second))
		model.begin_wave_step(world_step_elapsed,player.position);world_step_elapsed=0.0
		world_slice_limit=maxi(1,ceili(model.wave_step_count()/float(frames)))
		if model.advance_wave_slice(world_slice_limit,player.position):world_slice_limit=0
		model_tick_serial+=1;return true
	model.tick(world_step_elapsed,player.position)
	world_step_elapsed=0.0;model_tick_serial+=1
	return true
func _physics_process(delta):
	if model!=null and model.phase!=last_phase:set_phase_view()
	if model==null:return
	if paused or model.phase!="wave":
		_tick_ryo(delta);return
	var cpu_clock=_army_profile_clock()
	_tick_player_respawn(delta)
	gate_defenders.tick(delta);cpu_clock=_army_profile("game_defenders",cpu_clock)
	var army_pending=false;var army_prepare_ms=0.0
	if is_instance_valid(army_runtime) and army_runtime.can_overlap():
		army_pending=army_runtime.begin_integration(delta)
		if cpu_clock>0:
			var after_prepare=_army_profile_clock();army_prepare_ms=(after_prepare-cpu_clock)/1000.0;cpu_clock=after_prepare
	explorer_helpers.sync_targets();cpu_clock=_army_profile("game_helper_targets",cpu_clock)
	_tick_ryo(delta);cpu_clock=_army_profile("game_loot",cpu_clock)
	model.hero_targetable=player.hp>0 and not player.rogue_untargetable()
	if is_instance_valid(army_runtime):
		if army_pending:army_runtime.finish_integration()
		else:army_runtime.integration_tick(delta)
	cpu_clock=_army_profile("game_army_total",cpu_clock)
	if army_prepare_ms>0:
		army_runtime.profile_totals["game_army_prepare"]=float(army_runtime.profile_totals.get("game_army_prepare",0))+army_prepare_ms
		army_runtime.profile_totals["game_army_total"]=float(army_runtime.profile_totals.get("game_army_total",0))+army_prepare_ms
	var world_advanced=_advance_world(delta);cpu_clock=_army_profile("game_world_tick",cpu_clock)
	if not world_advanced:return
	for event in model.events:
		match event.kind:
			"wall_damage":wall_audio.impact(event)
			"hero_hit":player.take_hit(event.amount,(player.position-event.from).normalized(),event.get("projectile",false))
			"defender_hit":
				var defender=gate_defenders.units.get(event.id)
				if not is_instance_valid(defender):defender=explorer_helpers.target_actor(event.id)
				if is_instance_valid(defender):defender.take_hit(event.amount,(defender.position-event.from).normalized(),event.get("projectile",false))
			"wounded":toast("A worker is wounded. They will recover during preparation.")
			"arrow":
				tower_arrows.launch(event)
			"arrow_impact":tower_arrows.impact(event)
			"enemy_arrow":enemy_arrows.launch(event)
			"enemy_arrow_impact":enemy_arrows.impact(event)
	model.events.clear();sync_enemies()
	if model.phase!=last_phase:set_phase_view()
	_army_profile("game_events",cpu_clock)
func _ryo_collectors()->Array:
	var collectors:Array=[]
	if is_instance_valid(player):
		collectors.append({"id":"player","pos":player.global_position,"hp":player.hp,"active":respawn_left<=0})
	for defender:Dictionary in model.defenders.values():
		collectors.append({"id":"ally_%s"%defender.id,"pos":defender.pos,"hp":defender.hp})
	for worker:Dictionary in model.workers.values():
		if worker.has("sheltered_building"):continue
		var height=world.Profile.TOWER_DECK_HEIGHT if worker.state=="garrison" else float(worker.get("deck_height",0))
		collectors.append({"id":"worker_%s"%worker.id,"pos":worker.pos+Vector3.UP*height,"hp":worker.hp,"state":worker.state})
	return collectors
func _ryo_clear_path(from:Vector3,to:Vector3)->bool:
	var query=PhysicsRayQueryParameters3D.create(from,to,1)
	query.hit_from_inside=true
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()
func _tick_ryo(delta:float):
	if model==null or model.ryo==null:return
	var stopped=not playing or ordinary_pause or settings_open or rogue_roster_open or transitioning or model.phase not in ["wave","preparing"] or (model.phase=="wave" and paused) or (is_instance_valid(map_editor) and map_editor.active)
	if stopped:return
	ryo_feedback_left=maxf(0,ryo_feedback_left-delta)
	# Bounties are already credited at death. Only coalesced HUD/audio feedback
	# runs here; there are no collector snapshots, pickup rays or coin updates.
	if model.ryo.take_bounty_total()>0:
		if ryo_feedback_left<=0:
			sound("pickup",.45);ryo_feedback_left=.12
		forest_ui.sync()
func sync_enemies():
	if is_instance_valid(army_runtime):return
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
	if not rogue_roster_open or id not in player.RogueRoster.selection_ids():return
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
	# Hero death is recoverable. Only destruction of the shrine changes the
	# model to defeat; keep workers, enemies and the current wave running.
	if model.phase!="wave" or respawn_left>0:return
	respawn_left=PLAYER_RESPAWN_DELAY;model.hero_targetable=false
	player.cancel_charge();player.reset_auto_attack();player.velocity=Vector3.ZERO
	if player.character_id in [16,17]:player.active_ability.die()
	hit_stop=0;Engine.time_scale=1
	_sync_camera_mouse();forest_ui.sync()
func _tick_player_respawn(delta:float):
	if respawn_left<=0:return
	if not playing or model.phase not in ["wave","preparing"]:
		respawn_left=0.0;return
	if paused or ordinary_pause or settings_open or rogue_roster_open:return
	respawn_left=maxf(0,respawn_left-delta)
	if respawn_left<=0:_respawn_player()
func _player_respawn_point()->Vector3:
	# Saved maps and player construction can cover the usual home position.
	# Check both navigation and the real body shape before restoring control.
	var body_shape:CollisionShape3D
	for child in player.get_children():
		if child is CollisionShape3D:body_shape=child;break
	var query=PhysicsShapeQueryParameters3D.new()
	query.shape=body_shape.shape;query.collision_mask=player.collision_mask
	query.exclude=[player.get_rid()]
	for radius in range(model.ALLIED_REGION.size.x):
		for x in range(-radius,radius+1):
			for z in range(-radius,radius+1):
				if maxi(absi(x),absi(z))!=radius:continue
				var cell=PLAYER_SPAWN_CELL+Vector2i(x,z)
				if not model.ALLIED_REGION.has_point(cell) or model.occupancy.has(cell) or model.allied_grid.is_point_solid(cell):continue
				var point=model.point(cell)+Vector3.UP*.15
				if not model.terrain.disk_clear(point,.5*player.growth_multiplier()):continue
				var body_transform=player.global_transform;body_transform.origin=point
				query.transform=body_transform*body_shape.transform
				if player.get_world_3d().direct_space_state.intersect_shape(query,1).is_empty():return point
	return Vector3.INF
func _respawn_player():
	if model.phase not in ["wave","preparing"] or model.shrine().is_empty():respawn_left=0.0;return
	var point=_player_respawn_point()
	if point==Vector3.INF:
		respawn_left=.25;return
	reset_player_at(point)
	player.refresh_max_health();player.hp=player.max_hp
	player.invuln=PLAYER_RESPAWN_PROTECTION
	player.reset_auto_attack();player.combat_aim_left=0
	respawn_left=0.0;model.hero_targetable=true
	_sync_camera_mouse()
	forest_ui.sync()
func toast(words: String):
	if is_instance_valid(forest_ui):forest_ui.notify(words)
func drop_powerup(_point: Vector3):pass
func damage_number(p: Vector3,amount: int,heavy: bool,critical: bool=false):
	if model.visible_at(p):super.damage_number(p,amount,heavy,critical)
func burst(p: Vector3,color: Color,count: int,scale_factor: float=1.0):
	if model!=null and model.visible_at(p):super.burst(p,color,count,scale_factor)
func confirm_impact(victim: Ninja,p: Vector3,direction: Vector3,strength: int,projectile: bool,source_character:int=0,spawn_visuals: bool=true):
	if model.visible_at(p):super.confirm_impact(victim,p,direction,strength,projectile,source_character,spawn_visuals)
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
	respawn_left=0.0
	if is_instance_valid(explorer_helpers):explorer_helpers.clear()
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
	model.reset(run_seed,core_balance,active_forest_map(),false);world.reload_map();forest_ui.sync()
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
	if document.load_blood_gulch().is_empty():return document.data.duplicate(true)
	push_error("Could not load the Blood Gulch Castle preset")
	return {}
func open_map_editor():
	if not playing or ordinary_pause or settings_open or rogue_roster_open or model.phase!="preparing":return
	build_kind="";wall_start=Vector2i(-999,-999);world.preview.hide();forest_ui.selected_id=-1
	map_editor.open()
func preview_forest_map(layout: Dictionary,preview: bool=true):
	respawn_left=0.0
	var saved_pan=pan
	if is_instance_valid(explorer_helpers):explorer_helpers.clear()
	model=ForestModel.new();model.reset(run_seed,core_balance,layout,false)
	if preview:
		for x in range(-40,40):
			for z in range(-40,40):model.explored[Vector2i(x,z)]=true;model.visible_cells[Vector2i(x,z)]=true
	else:
		player.progression.reset(false);player.refresh_max_health();player.hp=player.max_hp;won=false;checkpoint=player.position
	world.model=model;world.reload_map();set_phase_view()
	if preview:pan=saved_pan;update_preparation_camera()

func show_gate_defenders():
	if not playing or ordinary_pause or settings_open or rogue_roster_open or model.phase!="preparing":return
	build_kind="";wall_start=Vector2i(-999,-999);world.preview.hide()
	ordinary_pause=true;paused=true;get_tree().paused=true
	var panel=preload("res://scripts/forest/forest_gate_defender_panel.gd").new();panel.game=self;panel.name="GateDefenderPanel";forest_ui.add_child(panel)
