extends "res://scripts/game.gd"
const ArmyEnemy=preload("res://scripts/forest/crowd/army_enemy_target.gd")
const ForestModel=preload("res://scripts/forest/forest_model.gd")
const ForestWorld=preload("res://scripts/forest/forest_world.gd")
const EnemyRoles=preload("res://scripts/forest/forest_enemy_roles.gd")
const EnemyContact=preload("res://scripts/forest/forest_enemy_contact.gd")
const MapDocument=preload("res://scripts/forest/forest_map_document.gd")
const FalanTour=preload("res://scripts/forest/forest_falan_tour.gd")
const AreaMusic=preload("res://scripts/forest/crossgate_music.gd")
const Habaru=preload("res://scripts/forest/crowd/habaru_sprites.gd")
const Falken=preload("res://scripts/forest/crowd/falken_sprites.gd")
const FalkenPortrait=preload("res://assets/ui/dialogue/falken-shadow.png")
const SkillPets=preload("res://scripts/forest/pet_catalog.gd")
const COMBAT_CAMERA_PITCH=.22
const COMBAT_CAMERA_FOCUS_RISE=2.0
const CHASE_CLICK_PADDING=.6
const CHASE_CLICK_HEADROOM=3.0
const PLAYER_RESPAWN_DELAY=3.0
const PLAYER_RESPAWN_PROTECTION=2.0
const PLAYER_SPAWN_CELL=Vector2i(0,3)
const PREPARATION_ZOOM_STEP=1.15
const PREPARATION_ZOOM_MIN=20.0
const PREPARATION_CAMERA_OFFSET=Vector3(55,150,118)
@export var launch_to_title=false
var model
var falan_crossing_position=Vector2.INF
var explorer_helpers
var explorer_npcs
var explorer_clock=preload("res://scripts/forest/forest_explorer_clock.gd").new()
var army_runtime:Node
var forest_ui
var team_upgrade_picker:Control
var status_panel:Control
var pet_loadout_panel:Control
var equipment_hub:Control
var equipment_from_game=false
var equipment_return_pause=false
var dialogue:Control
var dialogue_markers:Array[Label3D]=[]
var travel_panel:Control
var habaru_dialogue_seen=false
var habaru_waiting:MultiMeshInstance3D
var habaru_talk_hint:Label3D
var falken_dialogue_seen=false
var falken_waiting:MultiMeshInstance3D
var falken_talk_hint:Label3D
const BOSS_TALK_DISTANCE=8.0
var build_kind=""
var build_rotation=0
var placement_hint="Click to place"
var _placement_cache_key:Array=[]
var _placement_cache:Dictionary={}
var _placement_cache_until=0
var pan=Vector3.ZERO
var preparation_size=120.0
var actors: Dictionary={}
var enemy_objectives:Array=[]
var enemy_objective_targets:Array=[]
var training_dummy: Ninja
var web_coop:Node
var last_phase=""
var model_tick_serial=0
var world_step_elapsed=0.0
var wall_start=Vector2i(-999,-999)
var ordinary_pause=false
var notice=""
var roster_return_pause=false
var roster_from_equipment=false
var settings_open=false
var settings_from_pause=false
var tower_arrows
var camera_focused=true
var painterly_preview=false
var combat_warmup:Node
var respawn_left=0.0
var ryo_visuals:Node3D
var exploration_loot:Node3D
var ryo_feedback_left=0.0
var wall_audio:Node3D
var placement_audio:Node
var chase_click_shape:=BoxShape3D.new()
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
	model.team_progression.cards_enabled=settings.forest_level_up_cards
	painterly_preview=bool(get_tree().get_meta("forest_painterly_preview",OS.has_feature("painterly_preview") or "--painterly-preview" in OS.get_cmdline_user_args()))
	world=ForestWorld.new();world.model=model;world.painterly_preview_enabled=painterly_preview;world.process_mode=Node.PROCESS_MODE_PAUSABLE;add_child(world)
	tower_arrows=preload("res://scripts/forest/forest_tower_arrows.gd").new();tower_arrows.game=self;add_child(tower_arrows)
	player=Hero.new();player.game=self;player.room_ladder=world.habaru_ladder;player.position=FalanTour.spawn(model,PLAYER_SPAWN_CELL);player.process_mode=Node.PROCESS_MODE_PAUSABLE;add_child(player)
	var default_fighter:int=player.RogueRoster.KAZI_ID
	selected_rogue_id=int(get_tree().get_meta("forest_fighter",default_fighter))
	if selected_rogue_id==player.RogueRoster.MAZE_ID:settings.kaz_skin=KazSkins.MAZE
	if player.RogueRoster.gallery_id(selected_rogue_id) not in player.RogueRoster.selection_ids():selected_rogue_id=default_fighter
	selected_rogue_id=player.RogueRoster.skin_character(selected_rogue_id,settings)
	get_tree().set_meta("forest_fighter",selected_rogue_id)
	player.team_progression=model.team_progression
	player.select_character(selected_rogue_id);player.progression.reset(false);player.refresh_max_health();player.hp=player.max_hp;player.mana=player.max_mana;player.soft_target=false
	checkpoint=player.position
	camera_rig=ActionCamera.new();camera_rig.game=self;camera_rig.player=player;add_child(camera_rig)
	prepare_coin_projectiles()
	camera_rig.sens=settings.sensitivity
	camera_rig.pitch=COMBAT_CAMERA_PITCH;camera_rig.distance=settings.forest_camera_distance
	camera_rig.combat_camera_angle=deg_to_rad(settings.forest_camera_angle)
	camera_rig.character_screen_offset=settings.forest_character_screen_offset
	camera_rig.crosshair_focus_rise=COMBAT_CAMERA_FOCUS_RISE
	camera_rig.travel_follow.forward_buffer=0.0
	wall_audio=preload("res://scripts/forest/forest_wall_audio.gd").new();wall_audio.game=self;add_child(wall_audio)
	placement_audio=preload("res://scripts/forest/forest_placement_audio.gd").new();placement_audio.game=self;add_child(placement_audio)
	world.worker_hammered.connect(placement_audio.play_work)
	rogue_view=preload("res://scripts/forest/forest_view.gd").new();rogue_view.game=self;add_child(rogue_view)
	rogue_feedback=preload("res://scripts/rogue_battle_feedback.gd").new();rogue_feedback.game=self;add_child(rogue_feedback)
	crowd=preload("res://scripts/forest/forest_enemy_crowd.gd").new()
	crowd.game=self;crowd.process_mode=Node.PROCESS_MODE_PAUSABLE;add_child(crowd)
	army_runtime=preload("res://scripts/forest/crowd/army_coordinator.gd").new();add_child(army_runtime)
	if not army_runtime.setup(self):get_tree().quit(1);return
	# Build fitted collision hulls during scene loading, before combat. Their
	# first use otherwise blocks a spawn frame while generating convex meshes.
	for kind in CoreBalance.TYPES:EnemyContact.shapes(kind)
	encounters=EndlessEncounters.new();encounters.game=self;encounters.enabled=false;add_child(encounters)
	ui=CanvasLayer.new();add_child(ui)
	forest_ui=preload("res://scripts/forest/forest_ui.gd").new();forest_ui.game=self;ui.add_child(forest_ui)
	map_editor=preload("res://scripts/forest/forest_map_editor.gd").new();map_editor.game=self;ui.add_child(map_editor)
	playing=not launch_to_title;won=false;Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	if OS.has_feature("web"):
		web_coop=load("res://scripts/forest/forest_web_coop.gd").new()
		web_coop.game=self;add_child(web_coop)
	explorer_helpers=preload("res://scripts/forest/explorer_helpers.gd").new();explorer_helpers.name="ExplorerHelpers";explorer_helpers.game=self;add_child(explorer_helpers)
	exploration_loot=preload("res://scripts/forest/exploration_loot.gd").new();exploration_loot.game=self;add_child(exploration_loot)
	explorer_npcs=preload("res://scripts/forest/forest_explorer_npcs.gd").new();explorer_npcs.game=self;add_child(explorer_npcs)
	if model.has_elevation():
		var frame=preparation_map_frame();pan=frame.pan;preparation_size=frame.size
	rogue_view.set_enabled(false);rogue_feedback.set_enabled(false);set_phase_view()
	if launch_to_title:show_title()
	combat_warmup=preload("res://scripts/forest/forest_combat_warmup.gd").new();add_child(combat_warmup)
func toggle_painterly_preview():
	painterly_preview=not painterly_preview
	get_tree().set_meta("forest_painterly_preview",painterly_preview)
	world.set_painterly_preview(painterly_preview)
# Combat capabilities are independent of Fire Siege's old construction director.
func camera_combat()->bool:return true
func cave_camera_limit()->float:
	return (FalanTour.Indoor.CEILING_HEIGHT-.34)*model.falan_scale if FalanTour.Dungeons.roofed(model.falan_floor) else 0.0
func dungeon_boss_nearby()->bool:
	var boss=actors.get(model.waves.dungeon_boss_id)
	return is_instance_valid(boss) and not boss.dead and boss.hp>0 and boss.global_position.distance_squared_to(player.global_position)<32.0*32.0
func crosshair_aim_enabled()->bool:return true
func enemy_near_crosshair(max_distance:float,padding:float=CHASE_CLICK_PADDING,native_only:bool=false)->Ninja:
	var camera:Camera3D=camera_rig.camera
	var center=crosshair_screen_position()
	var direction=camera.project_ray_normal(center)
	var origin=crosshair_ray_start(camera.project_ray_origin(center),direction)
	chase_click_shape.size=Vector3(2.0*padding,2.0*padding+CHASE_CLICK_HEADROOM,max_distance)
	var basis=Basis.looking_at(direction,camera.global_basis.y)
	var query=PhysicsShapeQueryParameters3D.new()
	query.shape=chase_click_shape
	query.collision_mask=4
	# Extend above the enemy on screen without widening selection between neighbors.
	query.transform=Transform3D(basis,origin+direction*max_distance*.5-basis.y*CHASE_CLICK_HEADROOM*.5)
	var best:Ninja
	var best_score=INF
	var best_depth=INF
	for result in get_world_3d().direct_space_state.intersect_shape(query):
		var enemy=result.collider as Ninja
		if enemy==null or enemy.dead or enemy.hp<=0 or not forest_enemy_visible(enemy):continue
		if native_only and (not enemy is ArmyEnemy or enemy.runtime!=army_runtime):continue
		var anchor:Vector3=AttackChain.effect_anchor(enemy).position
		var depth=(anchor-origin).dot(direction)
		var point=AttackChain.contact_point(enemy,origin+direction*depth,anchor)
		depth=(point-origin).dot(direction)
		if depth<=0.0 or depth>max_distance:continue
		var score=camera.unproject_position(anchor).distance_squared_to(center)
		var worse_match=depth>=best_depth if is_equal_approx(score,best_score) else score>=best_score
		if worse_match or not AttackChain.clear_line(self,origin,point):continue
		best=enemy
		best_score=score
		best_depth=depth
	return best

func aimed_enemy_shows_attack_pointer(hit:Dictionary)->bool:
	var ability=player.active_ability
	if Hero.RogueRoster.is_crossgate_fighter(player.character_id) and ability.uses_primary_targeting():
		var offset:Vector3=ability.primary_target_offset(hit.get("collider") as Ninja)
		return offset.is_finite() and offset.length()<=ability.PRIMARY_SELECTION_DISTANCE
	return aimed_enemy_in_melee_range(hit)

func aimed_enemy_in_melee_range(hit:Dictionary)->bool:
	if enemies.is_empty():return false
	var reach:float=world.attack_range.radius(player)
	if reach<=0.0:return false
	var enemy=hit.get("collider") as Ninja
	if enemy==null or enemy.dead or enemy.hp<=0:return false
	var height=1.1*player.growth_multiplier()
	var origin=player.global_position+Vector3.UP*height
	var point=AttackChain.contact_point(enemy,origin,hit.position)
	var offset=point-origin
	return absf(offset.y)<=height and Vector2(offset.x,offset.z).length_squared()<=reach*reach and AttackChain.clear_line(player,origin,point)

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
func _sync_camera_mouse(capture_from_click:bool=false)->bool:
	if not is_inside_tree():return false
	var live=model!=null and playing and model.phase=="wave" and not paused and not get_tree().paused and not ordinary_pause and not settings_open and not transitioning and not rogue_roster_open and is_instance_valid(player) and player.hp>0 and camera_focused
	if not live and is_instance_valid(player) and player.active_ability!=null:
		if player.RogueRoster.is_crossgate_fighter(player.character_id):player.active_ability.primary_hold_target=null
		elif player.character_id==player.RogueRoster.MASTER_CHIEF_ID:player.active_ability.cancel()
	if is_instance_valid(camera_rig) and camera_rig.has_method("sync_character_view"):camera_rig.sync_character_view()
	# Browsers only allow pointer lock during a user gesture.
	if live and OS.has_feature("web") and not capture_from_click:return false
	var mode=Input.MOUSE_MODE_CAPTURED if live else Input.MOUSE_MODE_VISIBLE
	if Input.mouse_mode!=mode:Input.mouse_mode=mode
	return live
func issue_hound_order(order:int):
	if model==null or not playing or model.phase!="wave" or paused or get_tree().paused or ordinary_pause or settings_open or transitioning or rogue_roster_open or is_instance_valid(team_upgrade_picker) or not is_instance_valid(player) or player.hp<=0 or not is_instance_valid(army_runtime):return
	var focus=0
	if order==army_runtime.HoundOrder.ATTACK:
		army_runtime.finish_integration()
		var kit=player.active_ability
		var enemy:Ninja=kit.locked_primary_enemy()
		if enemy is ArmyEnemy and enemy.runtime==army_runtime:
			var camera_origin:Vector3=camera_rig.camera.global_position
			if not forest_enemy_visible(enemy) or not AttackChain.clear_line(self,camera_origin,AttackChain.aim_point(enemy,camera_origin)):
				kit.primary_tab_target=null
				enemy=null
		else:enemy=null
		if enemy==null:
			enemy=crosshair_ray_hit(kit.PRIMARY_SELECTION_DISTANCE).get("collider") as Ninja
			if not enemy is ArmyEnemy or enemy.runtime!=army_runtime or enemy.dead or enemy.hp<=0:enemy=enemy_near_crosshair(kit.PRIMARY_SELECTION_DISTANCE,1.0,true)
		if enemy is ArmyEnemy and enemy.runtime==army_runtime and not enemy.dead and enemy.hp>0:focus=enemy.handle
	if army_runtime.order_hounds(order,focus):
		if focus!=0:player.play_sound("shin_target_select",.65)
		toast("Pets · Focus marked enemy" if focus!=0 else {army_runtime.HoundOrder.ATTACK:"Pets · Hunt enemies",army_runtime.HoundOrder.RETURN:"Pets · Return and defend",army_runtime.HoundOrder.HOLD:"Pets · Defending this position · No need to hold F"}[order])
	else:toast("Press P to summon your selected pets")
func _notification(what):
	if what==NOTIFICATION_APPLICATION_FOCUS_OUT:
		camera_focused=false;_sync_camera_mouse()
	elif what==NOTIFICATION_APPLICATION_FOCUS_IN:
		camera_focused=true;_sync_camera_mouse()
func set_phase_view():
	if not model.construction_completed.is_connected(_clear_construction_occupants):model.construction_completed.connect(_clear_construction_occupants)
	if not model.wave_started.is_connected(_sync_wave_balance):model.wave_started.connect(_sync_wave_balance)
	if model.phase=="preparing" and is_instance_valid(player):
		var hero_cell:Vector2i=model.cell_of(player.position/model.falan_scale)
		if not model.navigation_region.has_point(hero_cell) or model.occupancy.has(hero_cell) or model.allied_grid.is_point_solid(hero_cell):
			var safe_spawn=_player_respawn_point()
			if safe_spawn.is_finite():ForestModel.ConstructionClearance.move_body(player,safe_spawn);checkpoint=safe_spawn
		model.hero_position=player.position
	if model.phase!="wave" and is_instance_valid(wall_audio):wall_audio.reset()
	world_step_elapsed=0.0
	if respawn_left>0:
		if model.phase=="preparing":_respawn_player()
		elif model.phase!="wave":respawn_left=0.0
	if is_instance_valid(explorer_helpers):
		if model.phase=="preparing":explorer_helpers.rest()
		elif model.phase=="wave":explorer_helpers.begin_wave()
		elif model.phase!="wave":explorer_helpers.clear()
	if is_instance_valid(explorer_helpers):explorer_helpers.sync_targets()
	if model.phase!="wave" and is_instance_valid(tower_arrows):tower_arrows.clear()
	last_phase=model.phase;build_kind="";wall_start=Vector2i(-999,-999);ordinary_pause=false
	world.preview.hide();model.workforce.cancel_rally();player.rogue_controls.reset();player.velocity=Vector3.ZERO
	paused=model.phase!="wave";get_tree().paused=paused
	_sync_camera_mouse()
	player.reset_auto_attack()
	player.combat_aim_left=0
	if is_instance_valid(native_ink_feedback):native_ink_feedback.clear()
	if model.phase=="preparing":
		sync_area_music();apply_music_setting()
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
			for id in world.painterly_pilot.selected_ids:pan+=model.center(model.buildings[id])*model.falan_scale
			pan/=world.painterly_pilot.selected_ids.size();preparation_size=90
		rogue_view.clear();update_preparation_camera()
		if playing and model.terrain_source=="wind_meadow" and model.falan_area.is_empty() and model.terrain_detail in ["",ForestModel.Arena.ID]:
			army_runtime.prepare_navigation.call_deferred()
	elif model.phase=="wave":
		sync_area_music();apply_music_setting()
		camera_rig.camera.projection=Camera3D.PROJECTION_PERSPECTIVE
		camera_rig.distance=settings.forest_camera_distance
		camera_rig.reset_follow();camera_rig.current_distance=camera_rig.combat_distance();camera_rig._process(0)
	elif model.phase=="victory":
		for target in enemy_objectives:
			if not target.castle_ruins.is_empty():target.castle_ruins.collapse.process_mode=Node.PROCESS_MODE_ALWAYS
		var survived=model.waves.released_waves==model.balance.waves.size() and model.waves.pending==0 and model.enemies.is_empty()
		var detail=("All enemy Skullpion statues destroyed." if model.has_enemy_castles() else "All four enemy farms destroyed.") if model.terrain_source=="wind_meadow" else "All camps and the enemy statue destroyed."
		if survived:detail="%d waves survived. The forest is yours."%model.balance.waves.size()
		won=true;forest_ui.show_overlay("VALLEY LIBERATED" if model.terrain_source=="wind_meadow" else "ENEMY CASTLE FALLEN" if model.enemy_camps_prototype else "THE SHRINE ENDURES",detail,false)
	elif model.survival_run:
		forest_ui.show_overlay("RUN OVER","Wave %d reached · %d enemies defeated."%[model.wave,kills],false)
	else:forest_ui.show_overlay("THE SHRINE HAS FALLEN","Wave %d · Gather your strength and try again."%model.wave,false)
	sync_training_dummy()
	for target in enemy_objective_targets:
		if not target.dead and not enemies.has(target):enemies.append(target)
	world.update_fog();forest_ui.sync()
func sync_training_dummy():
	if not is_instance_valid(training_dummy):return
	if not enemies.has(training_dummy):enemies.append(training_dummy)
	training_dummy.visible=playing and model.phase in ["preparing","wave"] and model.visible_at(training_dummy.position)
	if model.phase=="preparing":training_dummy.reset_pose()
func preparation_map_frame()->Dictionary:
	if model.terrain_detail==ForestModel.Arena.ID:return {"pan":Vector3.ZERO,"size":(model.terrain.floor_radius()+70)*2.4,"overview":true}
	if model.falan_area=="city":return {"pan":player.position,"size":240.0*model.falan_scale,"overview":true}
	if model.terrain_source=="wind_meadow":return {"pan":Vector3.ZERO,"size":535.0*model.terrain_scale*model.map_expansion*model.falan_scale,"overview":true}
	if model.enemy_camps_prototype:return {"pan":Vector3(0,0,96),"size":380.0,"overview":true}
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
	cam.far=maxf(1400,preparation_size*3)
	cam.global_position=pan+PREPARATION_CAMERA_OFFSET*maxf(1.0,preparation_size/535.0);cam.look_at(pan,Vector3.UP)
func preparation_pan_direction(move_:Vector2)->Vector3:
	return Vector3(move_.x,0,move_.y).rotated(Vector3.UP,atan2(PREPARATION_CAMERA_OFFSET.x,PREPARATION_CAMERA_OFFSET.z))
func preparation_zoom_limits()->Vector2:
	return Vector2(PREPARATION_ZOOM_MIN,maxf(PREPARATION_ZOOM_MIN,600.0*model.terrain_scale*model.map_expansion*model.falan_scale if model!=null else 600.0))
func clamp_preparation_pan():
	var grid_bounds=model.world_bounds().grow(-model.CELL)
	var bounds=Rect2(grid_bounds.position*model.falan_scale,grid_bounds.size*model.falan_scale)
	pan.x=clampf(pan.x,bounds.position.x,bounds.end.x);pan.z=clampf(pan.z,bounds.position.y,bounds.end.y)
func _preparation_zoom_available()->bool:
	if model==null or not playing or model.phase!="preparing" or ordinary_pause or settings_open or rogue_roster_open or transitioning:return false
	if is_instance_valid(map_editor) and map_editor.active:return false
	if is_instance_valid(forest_ui) and is_instance_valid(forest_ui.overlay):return false
	return is_instance_valid(camera_rig)
func zoom_preparation(steps:float,screen:Vector2=Vector2(INF,INF))->bool:
	if not _preparation_zoom_available():return false
	return _zoom_preparation_view(steps,screen)
func _zoom_preparation_view(steps:float,screen:Vector2=Vector2(INF,INF))->bool:
	if not is_finite(steps):return false
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
func _preparation_zoom_input(event:InputEvent,editor:bool=false)->bool:
	var zoom=_zoom_preparation_view if editor else zoom_preparation
	if event is InputEventKey:
		if event.ctrl_pressed or event.alt_pressed or event.meta_pressed:return false
		var focus=get_viewport().gui_get_focus_owner()
		if focus is LineEdit or focus is TextEdit:return false
		var code=event.physical_keycode if event.physical_keycode!=0 else event.keycode
		if code not in [KEY_PLUS,KEY_EQUAL,KEY_KP_ADD,KEY_MINUS,KEY_KP_SUBTRACT]:return false
		if event.pressed and not event.echo:zoom.call(-1 if code in [KEY_MINUS,KEY_KP_SUBTRACT] else 1)
		return true
	# Controls may pass wheel events through even when they stop clicks.
	if get_viewport().gui_get_hovered_control()!=null:return false
	if event is InputEventMouseButton and event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN]:
		if event.pressed:
			var amount=absf(event.factor) if event.factor!=0 else 1.0
			zoom.call(amount if event.button_index==MOUSE_BUTTON_WHEEL_UP else -amount,event.position)
		return true
	if event is InputEventMagnifyGesture:
		if is_finite(event.factor) and event.factor>0:zoom.call(log(event.factor)/log(PREPARATION_ZOOM_STEP),event.position)
		return true
	if event is InputEventPanGesture:
		zoom.call(-event.delta.y*.25,event.position);return true
	return false
func start_wave():
	if not playing or ordinary_pause or rogue_roster_open or (is_instance_valid(map_editor) and map_editor.active):return
	if model.phase=="preparing":
		model.balance.waves=core_balance.waves.duplicate(true)
		for key in ["spawn_group_start","spawn_group_growth"]:model.balance[key]=core_balance[key]
		_sync_wave_balance()
		if not model.waves.patrol_posts.is_empty():army_runtime.prepare_navigation()
	if model.start_wave():
		forest_ui.selected_id=-1;set_phase_view()
		prepare_habaru_dialogue()
		prepare_falken_dialogue()
		exploration_loot.prepare_world()
func prepare_habaru_dialogue():
	if model.falan_floor!=Habaru.ROOM or habaru_dialogue_seen or get_tree().get_meta("habaru_slain",{}).has(0) or is_instance_valid(habaru_waiting):return
	habaru_waiting=prepare_boss_host(Habaru.make_mesh(),"HabaruWaiting",FalanTour.Regions.Sites.HABARU_FORMATION[0],Habaru.CHAMBER_BODY,float(Habaru.motions().variants[0].standing_height),"熊弟")
	habaru_talk_hint=habaru_waiting.get_child(0)
	habaru_talk_hint.visible=can_talk_habaru()
func prepare_falken_dialogue():
	if model.falan_floor!=Falken.ROOM or falken_dialogue_seen or falken_defeated() or is_instance_valid(falken_waiting):return
	var at=Falken.Route.point(Falken.ROOM,Falken.Route.BOSS_CELL)
	falken_waiting=prepare_boss_host(Falken.make_mesh(),"FalkenWaiting",at,Falken.BODY,float(Falken.motions().variants[0].standing_height),"法爾肯")
	falken_talk_hint=falken_waiting.get_child(0)
	falken_talk_hint.visible=can_talk_falken()
func prepare_boss_host(mesh:Mesh,label:String,at:Vector2,bounds:AABB,height:float,speaker:String)->MultiMeshInstance3D:
	# Reuse the army sprite batch as a harmless host until the native encounter starts.
	var host=crowd.army.presentation.make_batch(mesh,label)
	host.position=model.world_point(at)
	host.multimesh.instance_count=1
	host.multimesh.set_instance_transform(0,Transform3D(Basis(Vector3.UP,PI),Vector3.ZERO))
	host.multimesh.set_instance_custom_data(0,Color(0,0,0,0))
	host.custom_aabb=bounds.grow(2)
	var hint=Label3D.new()
	hint.text="F · 和%s交談"%speaker
	hint.font=preload("res://scripts/forest/preparation_skin.gd").FONT
	hint.font_size=40;hint.pixel_size=.014
	hint.billboard=BaseMaterial3D.BILLBOARD_ENABLED
	hint.position.y=height+.6
	host.add_child(hint)
	return host
func can_talk_habaru()->bool:
	if model.falan_floor!=Habaru.ROOM or habaru_dialogue_seen or get_tree().get_meta("habaru_slain",{}).has(0):return false
	return can_talk_to_host(habaru_waiting)
func falken_defeated()->bool:
	return get_tree().get_meta(Falken.SLAIN,{}).has(Vector2i(Falken.ROOM,0))
func can_talk_falken()->bool:
	if model.falan_floor!=Falken.ROOM or falken_dialogue_seen or falken_defeated():return false
	return can_talk_to_host(falken_waiting)
func can_talk_to_host(host:MultiMeshInstance3D)->bool:
	if not is_instance_valid(host) or not playing or model.phase!="wave" or ordinary_pause or paused or transitioning or player.hp<=0:return false
	return player.position.distance_squared_to(host.position)<=pow(BOSS_TALK_DISTANCE*model.falan_scale,2)
func tick_boss_host(host:MultiMeshInstance3D,hint:Label3D,talkable:bool,delta:float):
	hint.visible=talkable
	var pose=host.multimesh.get_instance_custom_data(0)
	pose.b+=delta
	host.multimesh.set_instance_custom_data(0,pose)
func show_habaru_dialogue():
	if not can_talk_habaru():return
	show_boss_dialogue("熊弟",[
		{"text":"想通過這裡？\n先讓我看看你的本事吧！","portrait":preload("res://assets/ui/dialogue/kumatei-confident.png")},
		{"text":"熊兄弟們，出來吧！\n一起上，讓他見識我們的厲害！","portrait":preload("res://assets/ui/dialogue/kumatei-shouting.png")},
	],habaru_talk_hint,finish_habaru_dialogue)
func show_falken_dialogue():
	if not can_talk_falken():return
	show_boss_dialogue("法爾肯",[
		{"text":"耶卡替你打開了結界？\n那你應該知道，我為何把這座塔封起來。","portrait":FalkenPortrait},
		{"text":"想拿走天書，就走上石壇。\n守衛們，聽我號令！","portrait":FalkenPortrait},
	],falken_talk_hint,finish_falken_dialogue)
func show_boss_dialogue(speaker:String,pages:Array,hint:Label3D,finished:Callable):
	if is_instance_valid(dialogue):return
	dialogue=preload("res://scripts/forest/forest_dialogue.gd").new()
	dialogue.speaker=speaker
	dialogue.pages=pages
	ordinary_pause=true;paused=true;get_tree().paused=true;Engine.time_scale=1
	player.cancel_charge(true);player.rogue_controls.reset();player.velocity=Vector3.ZERO
	hint.hide()
	for marker in world.map_features.find_children("*","Label3D",false,false):
		if not marker.visible:continue
		marker.hide()
		dialogue_markers.append(marker)
	forest_ui.hide();ui.add_child(dialogue);dialogue.finished.connect(finished)
	_sync_camera_mouse()
func finish_habaru_dialogue():
	if not is_instance_valid(dialogue):return
	habaru_dialogue_seen=true
	habaru_waiting.hide()
	close_boss_dialogue()
func finish_falken_dialogue():
	if not is_instance_valid(dialogue):return
	falken_dialogue_seen=true
	falken_waiting.hide()
	close_boss_dialogue()
func close_boss_dialogue():
	restore_dialogue_markers()
	dialogue.queue_free();dialogue=null;resume()
func restore_dialogue_markers():
	for marker in dialogue_markers:
		if is_instance_valid(marker):marker.show()
	dialogue_markers.clear()
func clear_dialogue():
	restore_dialogue_markers()
	if is_instance_valid(dialogue):dialogue.queue_free()
	dialogue=null;habaru_dialogue_seen=false
	if is_instance_valid(habaru_waiting):habaru_waiting.queue_free()
	habaru_waiting=null;habaru_talk_hint=null
	falken_dialogue_seen=false
	if is_instance_valid(falken_waiting):falken_waiting.queue_free()
	falken_waiting=null;falken_talk_hint=null
func _sync_wave_balance():
	var enemy_size:float=core_balance.enemy_size_mult*EnemyRoles.MAP_ENEMY_SCALE
	if model.balance.enemy_size_mult!=enemy_size:model.navigation_revision+=1
	model.balance.enemy_size_mult=enemy_size
	for key in ["enemy_health_mult","enemy_damage_mult","enemy_speed_mult","boss_health","boss_speed"]:model.balance[key]=core_balance[key]
	model.balance.enemy_profiles=core_balance.enemy_profiles.duplicate(true)
	model.waves.stats_cache.clear()
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
	else:toast("Need 1 food · Build a farm" if not model.can_recruit(1) else "Need 50 ryo")
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
	_placement_cache={"cell":cell,"error":model.enemy_castle_placement_error(cell,build_rotation),"adjusted":false} if build_kind=="enemy_castle" else model.resolve_placement(build_kind,cell,build_rotation,0 if build_kind=="wall" else 1)
	_placement_cache_key=key;_placement_cache_until=now+100
	return _placement_cache
func _clear_construction_occupants(added:Array):
	ForestModel.ConstructionClearance.relocate_game(self,added)
func place_cell(cell: Vector2i)->bool:
	if not playing or ordinary_pause or model.phase!="preparing" or build_kind.is_empty():return false
	var target_cell=build_placement_target(cell,true).cell
	if build_kind=="enemy_castle":
		var error=model.enemy_castle_placement_error(target_cell,build_rotation)
		if not error.is_empty():toast(error);return false
		if model.place_enemy_castle(target_cell,build_rotation).is_empty():return false
		world.refresh_castle_build_site(model.portals.size()-1)
		if is_instance_valid(placement_audio):placement_audio.play_placement("enemy_castle")
		toast("Enemy castle placed · Free · Reinforcements begin when you start")
		update_build_preview(cell);return true
	var reason=model.placement_error(build_kind,target_cell,build_rotation)
	if not reason.is_empty():toast(reason);return false
	var b=model.build(build_kind,target_cell,build_rotation)
	if b.is_empty():return false
	if b.kind=="mine":model.workforce.assign_idle(b.id)
	forest_ui.selected_id=b.id;world.sync(0)
	if is_instance_valid(placement_audio):placement_audio.play_placement(b.kind)
	# Keep the chosen building and rotation ready for another placement.
	update_build_preview(cell)
	return true
func _input(event):
	if is_instance_valid(dialogue):dialogue.handle_input(event);return
	if is_instance_valid(travel_panel):travel_panel.handle_input(event);return
	if model==null:return
	if is_instance_valid(pet_loadout_panel):
		if event.is_action_pressed("pause") and event.is_pressed() and not event.is_echo():close_pet_loadout()
		if event is InputEventKey and event.physical_keycode not in [KEY_TAB,KEY_ENTER,KEY_SPACE,KEY_LEFT,KEY_RIGHT,KEY_UP,KEY_DOWN]:get_viewport().set_input_as_handled()
		return
	if is_instance_valid(equipment_hub):
		if event is InputEventKey and equipment_hub.pet_name_field.has_focus() and not event.is_action("pause"):return
		if (event.is_action_pressed("pause") or event.is_action_pressed("character_toggle")) and not event.is_echo():back_from_equipment()
		if event is InputEventKey and event.physical_keycode not in [KEY_TAB,KEY_ENTER,KEY_SPACE,KEY_LEFT,KEY_RIGHT,KEY_UP,KEY_DOWN]:get_viewport().set_input_as_handled()
		return
	if is_instance_valid(status_panel):
		if event.is_action_pressed("pause") and event.is_pressed() and not event.is_echo():close_status_panel()
		if event is InputEventKey and event.physical_keycode not in [KEY_TAB,KEY_ENTER,KEY_SPACE,KEY_LEFT,KEY_RIGHT,KEY_UP,KEY_DOWN]:get_viewport().set_input_as_handled()
		return
	if is_instance_valid(team_upgrade_picker):
		if event is InputEventKey:
			var code=event.physical_keycode if event.physical_keycode!=0 else event.keycode
			if event.pressed and not event.echo and code>=KEY_1 and code<=KEY_3:team_upgrade_picker.select(code-KEY_1)
			if code not in [KEY_TAB,KEY_ENTER,KEY_SPACE,KEY_LEFT,KEY_RIGHT,KEY_UP,KEY_DOWN]:get_viewport().set_input_as_handled()
		return
	if OS.has_feature("web") and event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT and event.pressed and Input.mouse_mode!=Input.MOUSE_MODE_CAPTURED:
		if _sync_camera_mouse(true):
			get_viewport().set_input_as_handled();return
	if playing and not paused and not transitioning and not settings_open and not rogue_roster_open and is_instance_valid(forest_ui) and is_instance_valid(forest_ui.enemy_minimap) and forest_ui.enemy_minimap.handle_map_input(event):
		get_viewport().set_input_as_handled();return
	if is_instance_valid(forest_ui) and forest_ui.preparation_menu_input(event):
		get_viewport().set_input_as_handled();return
	if is_instance_valid(explorer_helpers) and explorer_helpers.handle_global_input(event):
		get_viewport().set_input_as_handled();return
	if is_instance_valid(map_editor) and map_editor.active:map_editor.global_input(event);return
	if settings_open:
		if event.is_action_pressed("pause") and not event.is_echo():
			if is_instance_valid(menu) and menu.find_child("CoreBalance",true,false)!=null and menu.find_child("CoreBalance",true,false).from_map:resume()
			elif is_instance_valid(menu) and (menu.find_child("SoundStudio",true,false)!=null or menu.find_child("SkillBalance",true,false)!=null or menu.find_child("CharacterBalance",true,false)!=null or menu.find_child("EnemyBalance",true,false)!=null or menu.find_child("CoreBalance",true,false)!=null or menu.find_child("ForestViewSettings",true,false)!=null):show_settings(settings_from_pause)
			elif settings_from_pause:show_pause()
			else:show_title()
			get_viewport().set_input_as_handled()
		return
	if not playing and not rogue_roster_open:return
	if event.is_action("character_toggle"):
		if event.is_pressed() and not event.is_echo():
			if rogue_roster_open:close_rogue_roster()
			else:show_equipment_hub(true)
		get_viewport().set_input_as_handled();return
	if rogue_roster_open:
		if event.is_action_pressed("pause") and not event.is_echo():close_rogue_roster()
		if event.is_action("pause"):get_viewport().set_input_as_handled()
		return
	if model.phase=="wave" and not paused and not transitioning and player.hp>0 and event.is_action("assist",true) and Hero.RogueRoster.is_crossgate_fighter(player.character_id) and player.active_ability.uses_primary_targeting():
		if event.is_pressed() and not event.is_echo():player.active_ability.cycle_primary_lock()
		get_viewport().set_input_as_handled();return
	if event is InputEventKey and not event.alt_pressed and not event.ctrl_pressed and not event.meta_pressed and not event.shift_pressed:
		var code=event.physical_keycode if event.physical_keycode!=0 else event.keycode
		if code==KEY_E:
			if event.pressed and not event.echo:preload("res://scripts/forest/forest_travel_stones.gd").open(self)
			get_viewport().set_input_as_handled();return
		if code==KEY_F:
			if event.pressed and not event.echo:
				if can_talk_habaru():show_habaru_dialogue()
				elif can_talk_falken():show_falken_dialogue()
				elif explorer_npcs.interact():pass
				elif exploration_loot.open_nearest():pass
				else:issue_hound_order(army_runtime.HoundOrder.HOLD)
			get_viewport().set_input_as_handled();return
		if code==KEY_J:
			if event.pressed and not event.echo:preload("res://scripts/forest/forest_explorer_travel.gd").open(self)
			get_viewport().set_input_as_handled();return
		if code in [KEY_O,KEY_P]:
			if event.pressed and not event.echo and not ordinary_pause and not transitioning and model.phase in ["preparing","wave"]:
				if code==KEY_O:
					if not model.shrine().is_empty():
						model.base_invulnerable=not model.base_invulnerable
						forest_ui.sync();toast("Base invulnerability: "+("ON" if model.base_invulnerable else "OFF"))
				elif model.phase=="wave" and not paused:
					if army_runtime.recall_hounds():toast("Pets · Unsummoned")
					else:
						var queued:int=army_runtime.queue_hounds()
						toast("Pets · %d queued"%queued if queued>0 else "Choose pets in Q Equipment")
					forest_ui.sync_hound_health()
				else:toast("Start the battle first, then press P to summon your selected pets")
			get_viewport().set_input_as_handled();return
	if model.phase=="preparing" and not ordinary_pause and event is InputEventKey and event.shift_pressed and not event.ctrl_pressed and not event.alt_pressed and not event.meta_pressed:
		var code=event.physical_keycode if event.physical_keycode!=0 else event.keycode
		if code>=KEY_1 and code<=KEY_5:
			if event.pressed and not event.echo:
				if code==KEY_5:recruit_worker()
				elif code in [KEY_2,KEY_3]:select_build("tower" if code==KEY_2 else "barracks")
			get_viewport().set_input_as_handled();return
	if event is InputEventKey and not event.alt_pressed and not event.ctrl_pressed and not event.meta_pressed:
		var code=event.physical_keycode if event.physical_keycode!=0 else event.keycode
		if code==KEY_Z:
			if event.is_pressed() and not event.is_echo():issue_hound_order(army_runtime.HoundOrder.RETURN)
			get_viewport().set_input_as_handled();return
	if event.is_action("shuffle_map"):
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
		pan+=preparation_pan_direction(-event.relative)*preparation_size/700.0;clamp_preparation_pan();update_preparation_camera()
	if event is InputEventMouseButton:
		if event.button_index==MOUSE_BUTTON_RIGHT and event.pressed:build_kind="";world.preview.hide();wall_start=Vector2i(-999,-999)
		if event.button_index==MOUSE_BUTTON_LEFT:
			var cell=model.cell_of(ground_at(event.position)/model.falan_scale)
			if event.pressed:
				if build_kind=="wall":wall_start=cell
				elif not build_kind.is_empty():place_cell(cell)
				else:
					forest_ui.selected_id=model.occupancy.get(cell,-1)
					if model.buildings.get(forest_ui.selected_id,{}).get("kind","")=="cannon_tower":placement_audio.play_cannon("select")
			elif build_kind=="wall" and wall_start.x!=-999:
				var cells=wall_cells(cell)
				var result=model.build_wall_line(cells,build_rotation)
				if result.is_empty():toast("Wall line was not built. Check ryo, clear ground, and gate access.")
				else:
					world.sync(0)
					if is_instance_valid(placement_audio):placement_audio.play_placement("wall")
				wall_start=Vector2i(-999,-999)
		get_viewport().set_input_as_handled()
func _army_profile_clock()->int:return Time.get_ticks_usec() if is_instance_valid(army_runtime) and army_runtime.profile_enabled else 0
func _army_profile(label_:String,started:int)->int:return army_runtime.profile_mark(label_,started) if started>0 else 0
func update_build_preview(cell:Vector2i):
	var target=build_placement_target(cell);cell=target.cell
	var reason=target.error
	placement_hint=reason if not reason.is_empty() else ("Drag a wall line" if build_kind=="wall" else ("Nearby clear spot · Click to place" if target.adjusted else "Click to place"))
	if build_kind=="enemy_castle":
		if reason.is_empty():placement_hint="Free · Clears trees · Click to place"
		world.show_enemy_castle_preview(cell,build_rotation,reason.is_empty());return
	if build_kind=="wall" and wall_start.x!=-999:
		var cells=wall_cells(cell);var cost=cells.size()*model.COSTS.wall;var valid=model.gold>=cost
		for c in cells:
			if not model.placement_error("wall",c,build_rotation).is_empty():valid=false
		placement_hint="%d segments · %d ryo · Release to build"%[cells.size(),cost] if valid else "Blocked line or insufficient ryo · %d ryo"%cost
		world.show_wall_preview(cells,build_rotation,valid)
	else:world.show_preview(build_kind,cell,build_rotation,reason.is_empty())
func _process(delta):
	if model==null:return
	if model.team_progression.pending()>0 and not is_instance_valid(team_upgrade_picker) and playing and not ordinary_pause and not settings_open and not rogue_roster_open and not transitioning and model.phase in ["preparing","wave"] and not map_editor.active:show_team_upgrade()
	if is_instance_valid(team_upgrade_picker):return
	var cpu_clock=_army_profile_clock()
	_sync_camera_mouse()
	if is_instance_valid(map_editor) and map_editor.active:map_editor.tick(delta);return
	explorer_clock.tick(self,delta)
	if not paused and is_instance_valid(tower_arrows):tower_arrows.sync(delta)
	if is_instance_valid(native_ink_feedback):native_ink_feedback.tick(delta)
	if not ordinary_pause:
		if model.phase=="preparing":
			if playing and not transitioning and player.hp>0 and player.uses_mana():player.tick_mana(delta)
			model.tick(delta,player.position)
			var move_=Input.get_vector("move_left","move_right","move_forward","move_back")
			pan+=preparation_pan_direction(move_)*delta*preparation_size*.7
			clamp_preparation_pan();update_preparation_camera()
			if not build_kind.is_empty():
				update_build_preview(model.cell_of(ground_at(get_viewport().get_mouse_position())/model.falan_scale))
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
	world_step_elapsed+=maxf(0,delta)
	if world_step_elapsed+.000001<world_update_interval():return false
	model.tick(world_step_elapsed,player.position);world_step_elapsed=0;model_tick_serial+=1;return true
func _physics_process(delta):
	if is_instance_valid(dialogue):return
	if is_instance_valid(team_upgrade_picker):return
	if model!=null and model.phase!=last_phase:set_phase_view()
	if model==null:return
	if paused or model.phase!="wave":
		_tick_ryo(delta);return
	var cpu_clock=_army_profile_clock()
	_tick_player_respawn(delta)
	if FalanTour.cross_on_foot(self):return
	if AreaMusic.Regions.CONNECTED_VILLAGES.has(FalanTour.area(model)):sync_area_music()
	if is_instance_valid(habaru_waiting) and not habaru_dialogue_seen:
		tick_boss_host(habaru_waiting,habaru_talk_hint,can_talk_habaru(),delta)
	elif is_instance_valid(falken_waiting) and not falken_dialogue_seen:
		tick_boss_host(falken_waiting,falken_talk_hint,can_talk_falken(),delta)
	var army_pending=false;var army_prepare_ms=0.0
	if not army_runtime.integration_pending:
		army_pending=army_runtime.begin_integration(delta)
		if army_pending and cpu_clock>0:
			var after_prepare=_army_profile_clock();army_prepare_ms=(after_prepare-cpu_clock)/1000.0;cpu_clock=after_prepare
	explorer_helpers.sync_targets();cpu_clock=_army_profile("game_helper_targets",cpu_clock)
	_tick_ryo(delta);cpu_clock=_army_profile("game_loot",cpu_clock)
	model.hero_targetable=player.hp>0 and not player.rogue_untargetable()
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
				var defender=explorer_helpers.target_actor(event.id)
				if is_instance_valid(defender):defender.take_hit(event.amount,(defender.position-event.from).normalized(),event.get("projectile",false))
			"wounded":toast("A worker is wounded. They will return during preparation.")
			"arrow":
				tower_arrows.launch(event)
			"arrow_impact":tower_arrows.impact(event)
			"cannon_sound":placement_audio.play_cannon(event.event,event.point)
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
	army_runtime.import_arrivals()
func forest_enemy_visible(enemy)->bool:
	if model==null:return false
	if model.visible_at(enemy.global_position/model.falan_scale):return true
	if enemy.variant!=2:return false
	# A giant can enter sight feet first, while its root is still in hidden ground.
	var radius=14.0
	var center=model.cell_of(enemy.global_position/model.falan_scale);var reach=ceili(radius/(model.CELL*model.falan_scale))
	for x in range(-reach,reach+1):
		for z in range(-reach,reach+1):
			var point=model.point(center+Vector2i(x,z))
			if Vector2(point.x*model.falan_scale-enemy.global_position.x,point.z*model.falan_scale-enemy.global_position.z).length()<=radius and model.visible_at(point):return true
	return false
func forest_point_visible(point: Vector3)->bool:return model!=null and model.visible_at(point/model.falan_scale)
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
	picker.start_hint="Choose a fighter, then equip your character and companions before entering the map."
	picker.back_text="Q / Esc · Back to Equipment" if roster_from_equipment else "Q / Esc · Back to preparation" if model.phase=="preparing" else "Q / Esc · Back to battle"
	root.add_child(picker)
func choose_rogue_character(id: int):
	if not rogue_roster_open or id not in player.RogueRoster.selection_ids():return
	id=Hero.RogueRoster.skin_character(id,settings)
	selected_rogue_id=id;get_tree().set_meta("forest_fighter",id);player.select_character(id)
	var starting=rogue_pick_start
	rogue_roster_open=false;rogue_pick_start=false;clear_menu();forest_ui.show()
	if roster_from_equipment:
		roster_from_equipment=false;ordinary_pause=equipment_return_pause
		show_equipment_hub(equipment_from_game)
	elif starting:
		show_equipment_hub()
	elif roster_return_pause:show_pause()
	else:resume()
func close_rogue_roster():
	if not rogue_roster_open:return
	var starting=rogue_pick_start
	rogue_roster_open=false;rogue_pick_start=false;clear_menu();forest_ui.show()
	if roster_from_equipment:
		roster_from_equipment=false;ordinary_pause=equipment_return_pause
		show_equipment_hub(equipment_from_game)
	elif starting:show_main_menu()
	elif roster_return_pause:show_pause()
	else:resume()
func show_equipment_hub(from_game:bool=false):
	if is_instance_valid(equipment_hub) or model.phase not in ["preparing","wave"] or player.hp<=0 or transitioning:return
	equipment_from_game=from_game;equipment_return_pause=ordinary_pause
	player.cancel_charge(true);model.workforce.cancel_rally();Engine.time_scale=1
	build_kind="";wall_start=Vector2i(-999,-999);world.preview.hide()
	ordinary_pause=true;paused=true;get_tree().paused=true;forest_ui.hide();_sync_camera_mouse()
	equipment_hub=preload("res://scripts/forest/equipment_hub.gd").new();equipment_hub.game=self;ui.add_child(equipment_hub)
func choose_character_from_equipment():
	if not is_instance_valid(equipment_hub) or rogue_roster_open or model.phase not in ["preparing","wave"] or player.hp<=0 or transitioning:return
	equipment_hub.hide();equipment_hub.queue_free();equipment_hub=null
	roster_from_equipment=true;ordinary_pause=equipment_return_pause
	show_rogue_roster(not equipment_from_game)
func back_from_equipment():
	if not is_instance_valid(equipment_hub):return
	equipment_hub.hide();equipment_hub.queue_free();equipment_hub=null
	if equipment_from_game:
		equipment_from_game=false
		if equipment_return_pause:show_pause()
		else:resume()
	else:show_rogue_roster(true)
func unlock_weapon_slot(owner:String)->bool:
	var gear=preload("res://scripts/forest/equipment.gd")
	if not gear.valid_wearer(owner) or not owner.begins_with("character:"):return false
	var count=gear.unlocked(owner,settings)
	if count>=gear.WEAPON_SLOTS.size():return false
	var previous=settings.weapon_slot_unlocks
	var unlocks=gear.sanitized_unlocks(previous);unlocks[owner]=count+1;settings.weapon_slot_unlocks=unlocks
	if save_settings()!=OK:settings.weapon_slot_unlocks=previous;return false
	if is_instance_valid(equipment_hub):equipment_hub.refresh()
	return true
func save_equipment_loadouts(value:Dictionary,skill_items:Dictionary,cosmetics:Dictionary,appearances:Dictionary={},spells:Variant=null,pet_skills:Variant=null)->bool:
	var clean=preload("res://scripts/forest/equipment.gd").sanitized(value)
	var clean_skills=preload("res://scripts/forest/equipment.gd").sanitized(skill_items,"skill")
	var clean_cosmetics=preload("res://scripts/forest/equipment.gd").sanitized_cosmetics(cosmetics)
	if clean!=value or clean_skills!=skill_items or clean_cosmetics!=cosmetics or not preload("res://scripts/forest/equipment.gd").slots_unlocked(clean,settings):return false
	if spells!=null and (not spells is Dictionary or preload("res://scripts/spells/spell_catalog.gd").valid_loadouts(spells)!=spells):return false
	if pet_skills!=null and (not pet_skills is Dictionary or preload("res://scripts/forest/pet_catalog.gd").sanitized_skills(pet_skills)!=pet_skills):return false
	for owner in clean:
		for id in clean[owner].values():
			if id in preload("res://scripts/forest/equipment.gd").CHEST_SWORDS and id not in settings.chest_swords:return false
	var changed_characters=[]
	for setting in appearances:
		var matched=false
		for character in Hero.RogueRoster.CROSSGATE:
			if Hero.RogueRoster.skin_setting(character)!=setting or str(setting).is_empty():continue
			if not appearances[setting] is int or not Hero.RogueRoster.skin_catalog(character).has(appearances[setting]):return false
			changed_characters.append(character);matched=true;break
		if not matched:return false
	var previous=settings.duplicate()
	var proposed=settings.duplicate();proposed.merge(appearances,true)
	if spells!=null and not preload("res://scripts/forest/equipment.gd").skill_weapon_error(clean,spells,Hero.RogueRoster.skin_character(player.character_id,proposed),proposed).is_empty():return false
	settings.gear_loadouts=clean;settings.skill_item_loadouts=clean_skills;settings.cosmetic_loadouts=clean_cosmetics
	settings.merge(appearances,true)
	if spells!=null:settings.spell_loadouts=spells
	if pet_skills!=null:settings.forest_pet_skills=pet_skills
	if save_settings()!=OK:
		settings.merge(previous,true);return false
	for character in changed_characters:
		if not player.character_models.has(character):continue
		cancel_skin_loadout(character)
		var visual=player.character_models[character];var id=Hero.RogueRoster.selected_skin(character,settings)
		if character==Hero.RogueRoster.KAZI_ID:visual.set_kaz_skin(id)
		elif Hero.RogueRoster.is_shin(character):visual.set_shin_skin(id)
		else:visual.set_variant_skin(id)
		apply_skin_loadout(character)
	var selected=Hero.RogueRoster.skin_character(player.character_id,settings)
	if selected!=player.character_id:player.select_character(selected)
	get_tree().set_meta("forest_fighter",player.character_id)
	preload("res://scripts/forest/equipment.gd").apply(player)
	if is_instance_valid(explorer_helpers) and explorer_helpers.legendary_heroes!=null:
		for recruit in explorer_helpers.legendary_heroes.bodies:
			if Hero.RogueRoster.is_crossgate_fighter(recruit.character_id):recruit.model.refresh_cosmetics()
	if spells!=null:
		player.active_ability.cancel(true)
		if Hero.RogueRoster.has_crossgate_throws(player.character_id):player.active_ability.disable_assassination()
		player.spell_loadout.interrupt();player.spell_loadout.prepare()
	if pet_skills!=null:army_runtime.reconcile_pet_loadout()
	return true
func enter_equipped_map():
	if not is_instance_valid(equipment_hub):return
	if equipment_from_game:
		back_from_equipment();return
	equipment_hub.hide();equipment_hub.queue_free();equipment_hub=null
	playing=true;forest_ui.show();set_phase_view()
	army_runtime.prepare_navigation()
	start_wave()
	if OS.has_feature("web"):
		toast("Click to capture the mouse · Share this page address to invite friends" if web_coop.connected else "Click the city to capture the mouse")
func show_pause():
	if is_instance_valid(team_upgrade_picker):return
	if model==null or model.phase not in ["preparing","wave"]:return
	settings_open=false;clear_menu();forest_ui.show()
	ordinary_pause=true;paused=true;get_tree().paused=true;model.workforce.cancel_rally();player.cancel_charge(true);Engine.time_scale=1
	_sync_camera_mouse()
	forest_ui.show_overlay("REST A MOMENT","",true)
func resume():
	if is_instance_valid(team_upgrade_picker):return
	if model.phase not in ["preparing","wave"]:return
	forest_ui.view_settings_preview=false
	settings_open=false;clear_menu();forest_ui.show()
	ordinary_pause=false;forest_ui.close_overlay();paused=model.phase!="wave";get_tree().paused=paused
	_sync_camera_mouse()
func award_team_kill(reward_tenths:int=10,source_id:int=0,enemy_id:int=0):
	if not playing or paused or transitioning or model.phase!="wave":return
	var gained=model.team_progression.award_enemy(reward_tenths)
	var pets_leveled:bool=army_runtime.award_pet_kill(source_id,reward_tenths,enemy_id)
	if gained>0:
		if player.hp>0:player.refresh_max_health(true)
		toast("Level %d · +%d %s · Q: Equipment / Upgrades"%[model.team_progression.level,gained,"point" if gained==1 else "points"])
	if gained>0 or pets_leveled:sound("team_level_up",.8)
func show_pet_loadout():
	if is_instance_valid(pet_loadout_panel) or is_instance_valid(status_panel) or ((not playing or ordinary_pause) and not is_instance_valid(equipment_hub)) or settings_open or rogue_roster_open or transitioning or is_instance_valid(team_upgrade_picker) or map_editor.active or model.phase not in ["wave","preparing"] or player.hp<=0:return
	ordinary_pause=true;paused=true;get_tree().paused=true;Engine.time_scale=1
	model.workforce.cancel_rally();player.cancel_charge(true);player.reset_auto_attack();player.rogue_controls.reset()
	forest_ui.close_guard_shop();_sync_camera_mouse()
	pet_loadout_panel=preload("res://scripts/forest/pet_loadout_panel.gd").new();pet_loadout_panel.game=self;ui.add_child(pet_loadout_panel)
func close_pet_loadout():
	if not is_instance_valid(pet_loadout_panel):return
	pet_loadout_panel.hide();pet_loadout_panel.queue_free();pet_loadout_panel=null
	if is_instance_valid(equipment_hub):equipment_hub.refresh_party()
	else:resume()
func save_pet_loadout(selection,skills=null)->bool:
	var previous=settings.forest_pet_loadout
	var previous_skills=settings.forest_pet_skills
	settings.forest_pet_loadout=preload("res://scripts/forest/pet_catalog.gd").sanitized(selection)
	if skills!=null:settings.forest_pet_skills=preload("res://scripts/forest/pet_catalog.gd").sanitized_skills(skills)
	if save_settings()!=OK:
		settings.forest_pet_loadout=previous;settings.forest_pet_skills=previous_skills;return false
	army_runtime.reconcile_pet_loadout();army_runtime.prepare_pet_navigation();forest_ui.sync();return true
func save_pet_name(key:String,value:String)->bool:
	if SkillPets.skin(key)<0 or key not in settings.forest_pet_loadout:return false
	var previous:Dictionary=settings.forest_pet_names
	var names=previous.duplicate()
	var name_=SkillPets.clean_name(value)
	if name_.is_empty():names.erase(key)
	else:names[key]=name_
	if names==previous:return true
	settings.forest_pet_names=names
	if save_settings()==OK:return true
	settings.forest_pet_names=previous
	return false
func show_status_panel():
	if is_instance_valid(status_panel) or not playing or ordinary_pause or settings_open or rogue_roster_open or transitioning or is_instance_valid(team_upgrade_picker) or map_editor.active or model.phase not in ["wave","preparing"] or player.hp<=0:return
	ordinary_pause=true;paused=true;get_tree().paused=true;Engine.time_scale=1
	model.workforce.cancel_rally();player.cancel_charge(true);player.reset_auto_attack();player.rogue_controls.reset()
	forest_ui.close_guard_shop();_sync_camera_mouse()
	status_panel=preload("res://scripts/forest/character_status_panel.gd").new();status_panel.game=self;ui.add_child(status_panel)
func close_status_panel():
	if not is_instance_valid(status_panel):return
	status_panel.hide();status_panel.queue_free();status_panel=null;resume()
func spend_pet_stat(key:String,id:String)->bool:
	if not is_instance_valid(equipment_hub) or equipment_hub.wearer_key!="pet:"+key or key not in settings.forest_pet_loadout or model.phase not in ["wave","preparing"] or player.hp<=0:return false
	army_runtime.finish_integration()
	if not model.team_progression.spend_pet_stat(key,id):return false
	var handle:int=army_runtime.handles.get(army_runtime.HOUND_ID-SkillPets.skin(key),0)
	if handle!=0 and army_runtime.valid(handle):army_runtime.apply_pet_growth(handle,key)
	forest_ui.sync();return true
func spend_level_stat(id:String)->bool:
	if id in ["critical_chance","dodge_chance","counter_chance"] and player.combat_tuning(id)>=100:return false
	if (not is_instance_valid(status_panel) and not is_instance_valid(equipment_hub)) or (not playing and not is_instance_valid(equipment_hub)) or model.phase not in ["wave","preparing"] or player.hp<=0 or not model.team_progression.spend_stat(id):return false
	player.refresh_max_health(true);forest_ui.sync();return true
func spend_level_skill(id:String)->bool:
	if not is_instance_valid(status_panel) or not playing or model.phase not in ["wave","preparing"] or player.hp<=0:return false
	if id.is_empty() or not SkillBalance.active_slots(player).has(id) or SkillBalance.rules_for(player,id).is_empty():return false
	var progression=model.team_progression
	var level_=SkillBalance.level_for(player,id)
	if progression.stat_points<=0 or level_>=SkillBalance.Levels.MAX_LEVEL:return false
	if not SkillBalance.set_level(player,id,level_+1):return false
	progression.stat_points-=1;forest_ui.sync();return true
func spend_pet_skill(pet_key:String,id:String)->bool:
	if not is_instance_valid(status_panel) or not playing or model.phase not in ["wave","preparing"] or player.hp<=0:return false
	var pets=preload("res://scripts/forest/pet_catalog.gd")
	if pet_key not in pets.sanitized(settings.forest_pet_loadout) or id.is_empty() or id not in pets.skill_slots(pets.sanitized_skills(settings.forest_pet_skills),pet_key):return false
	if SkillBalance.Levels.stats(id,1).is_empty():return false
	var progression=model.team_progression;var level_=SkillBalance.pet_level_for(progression,pet_key,id)
	if progression.stat_points<=0 or level_>=SkillBalance.Levels.MAX_LEVEL:return false
	set_pet_skill_level(pet_key,id,level_+1)
	progression.stat_points-=1;forest_ui.sync();return true

func set_pet_skill_level(pet_key:String,id:String,level_:int):
	var levels:Dictionary=model.team_progression.pet_skill_levels.get_or_add(pet_key,{})
	levels[SkillBalance.Levels.family(id)]=level_
	if army_runtime.pet_skills==null:return
	var caster=army_runtime.pet_skills.casters.get(pet_key)
	if is_instance_valid(caster):caster.prepare_skill_count(id)

func skill_card_level(target:String)->int:
	var id=target.get_slice("|",0)
	var pet_key=skill_card_pet(target)
	return SkillBalance.level_for(player,id) if pet_key.is_empty() else SkillBalance.pet_level_for(model.team_progression,pet_key,id)

func skill_card_pet(target:String)->String:
	return target.get_slice("|",1) if target.contains("|") else ""

func skill_card_targets()->Array[String]:
	var targets:Array[String]=[]
	var families:Dictionary={}
	for id in SkillBalance.active_slots(player):
		if id.is_empty() or SkillBalance.rules_for(player,id).is_empty() or skill_card_level(id)>=SkillBalance.Levels.MAX_LEVEL:continue
		var family=SkillBalance.Levels.family(id)
		if families.has(family):continue
		families[family]=true;targets.append(id)
	for pet_key in SkillPets.sanitized(settings.forest_pet_loadout):
		for id in SkillPets.skill_slots(settings.forest_pet_skills,pet_key):
			if not id.is_empty() and not SkillBalance.Levels.stats(id,1).is_empty():
				var target:String=id+"|"+pet_key
				if skill_card_level(target)<SkillBalance.Levels.MAX_LEVEL:targets.append(target)
	if targets.is_empty() and SkillBalance.Catalog.Roster.is_crossgate_fighter(player.character_id):
		var catalog=SkillBalance.Catalog.all()
		for id in SkillBalance.level_skills():
			if catalog.has(id) and SkillBalance.Catalog.available(catalog[id]) and SkillBalance.Catalog.weapon_compatible(catalog[id],player.model) and skill_card_level(id)<SkillBalance.Levels.MAX_LEVEL:targets.append(id)
	return targets

func show_team_upgrade():
	var progression=model.team_progression
	if progression.pending()<=0 or player.hp<=0 or is_instance_valid(team_upgrade_picker):return
	if progression.offer.is_empty():progression.roll_offer(skill_card_targets())
	if progression.offer.is_empty():
		progression.skip_offers();return
	ordinary_pause=true;paused=true;get_tree().paused=true;Engine.time_scale=1
	model.workforce.cancel_rally();player.cancel_charge(true);player.reset_auto_attack();player.rogue_controls.reset()
	_sync_camera_mouse()
	forest_ui.close_overlay();forest_ui.close_guard_shop()
	team_upgrade_picker=preload("res://scripts/forest/team_upgrade_picker.gd").new();team_upgrade_picker.game=self
	ui.add_child(team_upgrade_picker)
func choose_team_upgrade(id:String,offered_level:int)->bool:
	var progression=model.team_progression
	if not is_instance_valid(team_upgrade_picker) or model.phase not in ["wave","preparing"] or not progression.can_choose(id,offered_level):return false
	var skill=id.get_slice("|",0)
	var pet_key=skill_card_pet(id)
	var gain:int=progression.CARD_LEVELS[progression.offer_rarities[progression.offer.find(id)]]
	var next=mini(SkillBalance.Levels.MAX_LEVEL,skill_card_level(id)+gain)
	if pet_key.is_empty():
		if not SkillBalance.set_level(player,skill,next):return false
	else:set_pet_skill_level(pet_key,skill,next)
	progression.choose(id,offered_level)
	if progression.pending()>0:progression.roll_offer(skill_card_targets())
	if not progression.offer.is_empty():team_upgrade_picker.refresh()
	else:
		progression.skip_offers()
		team_upgrade_picker.hide();team_upgrade_picker.queue_free();team_upgrade_picker=null
		ordinary_pause=false;paused=model.phase!="wave";get_tree().paused=paused;_sync_camera_mouse()
	forest_ui.sync()
	return true
func restart_area():
	get_tree().paused=false;get_tree().change_scene_to_file.call_deferred("res://scenes/forest_shrine.tscn")
func show_main_menu():
	get_tree().paused=false
	get_tree().change_scene_to_file.call_deferred("res://scenes/forest_title.tscn")
func defeat():
	if model.phase!="wave" or respawn_left>0:return
	if model.survival_run:
		if player.hp>0:return
		model.phase="defeat"
	else:respawn_left=PLAYER_RESPAWN_DELAY
	model.hero_targetable=false
	player.cancel_charge(player.character_id in [31,32,33]);player.reset_auto_attack();player.velocity=Vector3.ZERO
	if player.character_id in [16,17,30,31,32,33]:player.active_ability.die()
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
				if not model.ALLIED_REGION.has_point(cell) or not model.allied_grid.region.has_point(cell) or model.occupancy.has(cell) or model.allied_grid.is_point_solid(cell):continue
				var authored=model.point(cell)
				if not model.terrain.disk_clear(authored,.5*player.growth_multiplier()/model.falan_scale):continue
				var point=authored*model.falan_scale+Vector3.UP*.15
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
	player.refresh_max_health();player.hp=player.max_hp;player.mana=player.max_mana;player.skullpion_poison_left=0;player.confusion_left=0;player.clear_cursed_afflictions()
	player.invuln=PLAYER_RESPAWN_PROTECTION
	player.reset_auto_attack();player.combat_aim_left=0
	respawn_left=0.0;model.hero_targetable=true
	_sync_camera_mouse()
	forest_ui.sync()
func toast(words: String):
	if is_instance_valid(forest_ui):forest_ui.notify(words)
func drop_powerup(_point: Vector3):pass
func damage_number(p: Vector3,amount: int,heavy: bool,critical: bool=false):
	if not forest_point_visible(p):return
	if critical and is_instance_valid(crowd) and is_instance_valid(crowd.army):
		crowd.army.presentation.critical_burst(p)
	super.damage_number(p,amount,heavy,critical)
func burst(p: Vector3,color: Color,count: int,scale_factor: float=1.0):
	if forest_point_visible(p):super.burst(p,color,count,scale_factor)
func confirm_impact(victim: Ninja,p: Vector3,direction: Vector3,strength: int,projectile: bool,source_character:int=0,spawn_visuals: bool=true,impact_sample:AudioStream=null,primary_feedback:bool=true,impact_cue:String=""):
	if not forest_point_visible(p):return
	super.confirm_impact(victim,p,direction,strength,projectile,source_character,spawn_visuals,impact_sample,primary_feedback,impact_cue)
func impact_effect(p: Vector3,direction: Vector3,strength: int):
	if forest_point_visible(p):super.impact_effect(p,direction,strength)

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

func sync_area_music():
	var at=Vector2(player.position.x,player.position.z)/model.falan_scale
	var stream:AudioStream=AreaMusic.STREAMS[AreaMusic.key(FalanTour.area(model),model.falan_floor,at)]
	if music.stream==stream:return
	music.stop()
	music.stream=stream
	music.stream.loop=true
	apply_music_setting()

func menu_base()->Control:
	var root=super.menu_base();root.theme=preload("res://scripts/forest/preparation_skin.gd").theme()
	root.get_child(0).color=Color(.06,.09,.11,.24 if playing else .20)
	return root
func button_at(parent:Control,words:String,p:Vector2,action:Callable,width:float=300)->Button:
	var button=super.button_at(parent,words,p,action,width)
	preload("res://scripts/forest/preparation_skin.gd").apply_button(button)
	return button
func show_title():
	if playing:save_settings()
	if is_instance_valid(equipment_hub):equipment_hub.hide();equipment_hub.queue_free();equipment_hub=null
	clear_dialogue()
	if model!=null:model.team_progression.skill_food_stacks=0
	if is_instance_valid(exploration_loot):exploration_loot.clear();exploration_loot.opened_chests.clear()
	if is_instance_valid(player):player.clear_food_buffs()
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
	var cards=CheckButton.new()
	cards.name="ForestLevelUpCardsToggle"
	cards.text="Level-up Cards"
	cards.tooltip_text="Choose a skill upgrade when your character levels up. Character XP and earned upgrades stay when cards are off."
	cards.position=Vector2(710,549);cards.size=Vector2(390,48)
	cards.add_theme_font_size_override("font_size",20)
	cards.button_pressed=settings.forest_level_up_cards
	menu.add_child(cards)
	cards.toggled.connect(func(enabled):
		settings.forest_level_up_cards=enabled
		model.team_progression.cards_enabled=enabled
		save_settings())
	var canvas=Control.new();canvas.name="SettingsCanvas";canvas.size=Vector2(1440,800);menu.add_child(canvas)
	var frame=Panel.new();frame.position=Vector2(64,112);frame.size=Vector2(1352,620)
	frame.add_theme_stylebox_override("panel",forest_ui.PreparationSkin.panel());canvas.add_child(frame)
	for child in menu.get_children():
		if child!=canvas and child!=menu.get_child(0):child.reparent(canvas,false)
	var fit=func():
		var factor=minf(1.0,minf((canvas.get_parent().size.x-24)/1440,(canvas.get_parent().size.y-24)/800))
		canvas.scale=Vector2.ONE*factor;canvas.position=(canvas.get_parent().size-canvas.size*factor)*.5
	menu.resized.connect(fit);fit.call()
func load_settings():
	super.load_settings()
	explorer_clock.load_hour(settings.explorer_hour)
	if model!=null:model.team_progression.cards_enabled=settings.forest_level_up_cards
	apply_forest_view_settings()
func save_settings()->Error:
	settings.explorer_hour=explorer_clock.hour
	return super.save_settings()
func _exit_tree():
	if playing and not settings.is_empty():save_settings()
	explorer_clock.restore()
	super._exit_tree()
func apply_forest_view_settings():
	if is_instance_valid(camera_rig):
		camera_rig.distance=settings.forest_camera_distance
		camera_rig.combat_camera_angle=deg_to_rad(settings.forest_camera_angle)
		camera_rig.character_screen_offset=settings.forest_character_screen_offset
		if model!=null and playing and model.phase=="wave":
			camera_rig.current_distance=camera_rig.combat_distance();camera_rig.update_camera(0,true)
	if is_instance_valid(forest_ui):forest_ui.sync()
func set_forest_camera_distance(value):
	settings.forest_camera_distance=ViewPreferences.bounded(value,ViewPreferences.CAMERA_DEFAULT,ViewPreferences.CAMERA_MIN,ViewPreferences.CAMERA_MAX)
	apply_forest_view_settings();save_settings()
func set_forest_camera_angle(value):
	settings.forest_camera_angle=ViewPreferences.bounded(value,ViewPreferences.CAMERA_ANGLE_DEFAULT,ViewPreferences.CAMERA_ANGLE_MIN,ViewPreferences.CAMERA_ANGLE_MAX)
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
func begin_arena():
	if playing:return
	# Returning from the city must not reuse its exploration layout for the arena.
	for key in ["forest_custom_layout","falan_venture","falan_exit","freyja_site_return"]:
		get_tree().remove_meta(key)
	begin_forest()
	player.position=FalanTour.spawn(model,PLAYER_SPAWN_CELL)
	player.reset_physics_interpolation()
	checkpoint=player.position

func begin_forest():
	if playing:return
	player.timed_dodge.reset()
	# Title settings belong to the run about to start, not the preview snapshot.
	kills=0
	model.reset(run_seed,core_balance,active_forest_map(),false);world.reload_map();army_runtime.reset_world();forest_ui.sync()
	show_rogue_roster(true)

func begin_saved_falan(path:String):
	if playing:return
	var document=MapDocument.new(false)
	var error=document.read_file(path)
	if not error.is_empty() or not document.data.has("falan_areas"):
		OS.alert("Could not load the Freyja and Falan save." if error.is_empty() else error,"Freyja and Falan")
		return
	var tree=get_tree()
	run_seed=90824 if smoke_test else int(Time.get_ticks_usec())%2147483647
	if web_coop!=null and web_coop.connected:run_seed=web_coop.seed_value
	tree.set_meta("forest_custom_layout",document.data.falan_areas.city)
	tree.set_meta("falan_venture",document.data)
	tree.remove_meta("falan_exit")
	tree.remove_meta("freyja_site_return")
	tree.remove_meta("habaru_slain")
	tree.remove_meta(Habaru.SLIME_SLAIN)
	tree.remove_meta(Habaru.VENOA_SLAIN)
	tree.remove_meta("map_patrol_slain")
	tree.remove_meta("zombie_slain")
	tree.remove_meta(FalanTour.Captain.SLAIN)
	tree.remove_meta(FalanTour.Grave.SLAIN)
	tree.remove_meta(FalanTour.Ruby.SLAIN)
	tree.remove_meta(FalanTour.Winter.SLAIN)
	tree.remove_meta(FalanTour.Winter.Decree.BLADE)
	tree.remove_meta(FalanTour.Winter.Decree.COMPLETE)
	tree.remove_meta(FalanTour.Falken.SLAIN)
	tree.remove_meta(FalanTour.Falken.SCROLL)
	tree.remove_meta(FalanTour.Prayer.SLAIN)
	tree.remove_meta(model.waves.Undersea.SLAIN)
	begin_forest()
	player.position=FalanTour.spawn(model,PLAYER_SPAWN_CELL)
	if web_coop!=null and web_coop.connected:
		player.position.z-=web_coop.spawn_slot*1.7
		player.position.y=model.world_height(player.position.x,player.position.z)+.15
	player.reset_physics_interpolation()
	camera_rig.yaw=PI/6.0
	checkpoint=player.position

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
	var document=MapDocument.new()
	if document.load_wind_meadow().is_empty():return document.data.duplicate(true)
	push_error("Could not load the Falan Arena preset")
	return {}
var map_resize_pending=false
func request_map_resize(direction:int):
	if map_resize_pending or not _preparation_zoom_available():return
	map_resize_pending=true;forest_ui.sync()
	# Let the size control paint its busy state before preparing terrain and collision.
	await get_tree().process_frame
	await get_tree().process_frame
	resize_preparation_map(direction)
	map_resize_pending=false;forest_ui.sync()
func resize_preparation_map(direction:int)->bool:
	if not _preparation_zoom_available() or model.terrain_source!="wind_meadow" or model.terrain_detail==ForestModel.Arena.ID or direction not in [-1,1]:return false
	var sizes=ForestModel.WindMeadowTerrain.EXPANSIONS
	var index=sizes.find(model.map_expansion)+direction
	if index<0 or index>=sizes.size():return false
	var expansion:float=sizes[index]
	var document=MapDocument.new(false);document.capture(model)
	document.data.map_expansion=expansion
	var error=MapDocument.validate(document.data)
	if not error.is_empty():toast("Cannot resize: "+error+" Your map is unchanged.");return false
	var terrain=ForestModel.create_terrain(model.terrain_source,model.terrain_scale,expansion,model.raised_castle,model.terrain_detail,model.falan_area);terrain.configure(model.ramparts)
	var protected_cells=[]
	for building in model.buildings.values():protected_cells.append_array(model.footprint(building.kind,building.cell,building.rotation,building.get("span",0)))
	for portal in model.portals:protected_cells.append_array(ForestModel.portal_cells(portal))
	for cell:Vector2i in protected_cells:
		for offset in [Vector2.ZERO,Vector2(-3,-3),Vector2(3,-3),Vector2(-3,3),Vector2(3,3)]:
			var p=Vector2(cell)*model.CELL+offset
			if absf(terrain.height(p.x,p.y)-model.surface_height(p.x,p.y))>.01:toast("Cannot resize: the cliff edge would move under a building or castle. Move that placement inward first.");return false
	var bounds=Rect2(Vector2(-234,-234)*model.terrain_scale*expansion,Vector2(468,468)*model.terrain_scale*expansion)
	var positions=[player.position]
	for group in [model.workers,model.defenders,model.enemies]:
		for actor in group.values():positions.append(actor.pos)
	positions.append_array(model.fighter_posts.values())
	for point:Vector3 in positions:
		if not bounds.has_point(Vector2(point.x,point.z)):toast("Cannot shrink while a character is outside the smaller map. Move them inward first.");return false
		if absf(terrain.height(point.x,point.z)-model.surface_height(point.x,point.z))>.01:toast("Move characters away from the outer cliff before resizing.");return false
	army_runtime.finish_integration()
	model.map_expansion=expansion
	model.terrain=terrain
	model.navigation_region=ForestModel.region_for(model.terrain_source,model.terrain_scale*expansion)
	model.rebuild_navigation();model.revision+=1
	world.reload_map()
	var frame=preparation_map_frame();pan=frame.pan;preparation_size=frame.size;update_preparation_camera()
	forest_ui.sync();toast("Map %s× wide · %.2f× area · Placements kept. Use Map Editor → Save to keep this layout."%[str(expansion),expansion*expansion])
	return true
func open_map_editor():
	if model.enemy_camps_prototype:toast("Map editing is unavailable in this test layout.");return
	if not playing or ordinary_pause or settings_open or rogue_roster_open or model.phase!="preparing":return
	build_kind="";wall_start=Vector2i(-999,-999);world.preview.hide();forest_ui.selected_id=-1
	map_editor.open()
func preview_forest_map(layout: Dictionary,preview: bool=true,reuse_world:bool=false,keep_runner:bool=false):
	clear_dialogue()
	player.guard_reply_left=0.0
	if is_instance_valid(exploration_loot):exploration_loot.clear()
	var previous=model
	respawn_left=0.0
	var saved_pan=pan
	if is_instance_valid(explorer_helpers):explorer_helpers.clear()
	model=ForestModel.new();model.reset(run_seed,core_balance,layout,false)
	if keep_runner:
		model.team_progression=previous.team_progression
		model.gold=previous.gold
	else:kills=0
	model.team_progression.cards_enabled=settings.forest_level_up_cards
	if preview:
		for x in range(-40,40):
			for z in range(-40,40):model.explored[Vector2i(x,z)]=true;model.visible_cells[Vector2i(x,z)]=true
	elif not keep_runner:
		player.position=FalanTour.spawn(model,PLAYER_SPAWN_CELL)
		player.team_progression=model.team_progression
		player.progression.reset(false);player.refresh_max_health();player.hp=player.max_hp;player.mana=player.max_mana;player.confusion_left=0;player.clear_cursed_afflictions();won=false;checkpoint=player.position
	player.team_progression=model.team_progression
	if not keep_runner:player.double_edge_left=0.0;player.double_edge_penalty=0.0
	player.spell_loadout.prepare()
	player.refresh_max_health()
	var reuse=preview and reuse_world and world.can_reuse_map(model)
	world.model=model
	if reuse:world.reload_preview(previous)
	else:world.reload_map()
	player.room_ladder=world.habaru_ladder
	army_runtime.reset_world();set_phase_view()
	if preview:pan=saved_pan;update_preparation_camera()

func prepare_skill_count(id:String):
	super.prepare_skill_count(id)
	if is_instance_valid(army_runtime) and army_runtime.pet_skills!=null:army_runtime.pet_skills.prepare_skill_count(id)
