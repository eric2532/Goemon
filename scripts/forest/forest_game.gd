extends "res://scripts/game.gd"
const ForestModel=preload("res://scripts/forest/forest_model.gd")
const ForestWorld=preload("res://scripts/forest/forest_world.gd")
const Raider=preload("res://scripts/forest/forest_raider.gd")
@export var launch_to_title=false
var model
var forest_ui
var build_kind=""
var build_rotation=0
var placement_hint="Click to place"
var pan=Vector3.ZERO
var preparation_size=120.0
var actors: Dictionary={}
var last_phase=""
var wall_start=Vector2i(-999,-999)
var ordinary_pause=false
var notice=""
var roster_return_pause=false
func _ready():
	process_mode=Node.PROCESS_MODE_ALWAYS
	descent_mode=false;rogue_battle_mode=true;rogue_roster_mode=true;tower_defense_mode=false
	smoke_test="--test" in OS.get_cmdline_user_args() or "--visual" in OS.get_cmdline_user_args()
	setup_inputs()
	if not InputMap.has_action("rally_workers"):
		InputMap.add_action("rally_workers");var key=InputEventKey.new();key.physical_keycode=KEY_V;InputMap.action_add_event("rally_workers",key)
	load_settings();setup_audio()
	sound_library=SoundLibrary.new();sound_library.game=self;add_child(sound_library)
	ComboEnergy.warmup();SkySmoke.warmup();EdoFireExplosion.warmup()
	model=ForestModel.new();run_seed=90824 if smoke_test else int(Time.get_ticks_usec())%2147483647;model.reset(run_seed)
	world=ForestWorld.new();world.model=model;world.process_mode=Node.PROCESS_MODE_PAUSABLE;add_child(world)
	player=Hero.new();player.game=self;player.position=Vector3(0,.15,18);player.process_mode=Node.PROCESS_MODE_PAUSABLE;add_child(player)
	selected_rogue_id=int(get_tree().get_meta("forest_fighter",1))
	player.select_character(selected_rogue_id);player.progression.reset(false);player.refresh_max_health();player.hp=player.max_hp
	checkpoint=player.position
	camera_rig=ActionCamera.new();camera_rig.game=self;camera_rig.player=player;add_child(camera_rig)
	rogue_view=preload("res://scripts/forest/forest_view.gd").new();rogue_view.game=self;add_child(rogue_view)
	rogue_feedback=preload("res://scripts/rogue_battle_feedback.gd").new();rogue_feedback.game=self;add_child(rogue_feedback)
	crowd=EnemyCrowd.new();crowd.game=self;crowd.process_mode=Node.PROCESS_MODE_PAUSABLE;add_child(crowd)
	pursuit=EnemyPursuit.new();pursuit.game=self;add_child(pursuit);pursuit.set_physics_process(false)
	encounters=EndlessEncounters.new();encounters.game=self;encounters.enabled=false;add_child(encounters)
	ui=CanvasLayer.new();add_child(ui)
	forest_ui=preload("res://scripts/forest/forest_ui.gd").new();forest_ui.game=self;ui.add_child(forest_ui)
	playing=true;won=false;Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	rogue_view.set_enabled(true);rogue_feedback.set_enabled(true);set_phase_view()
	if launch_to_title:show_title()
func set_phase_view():
	last_phase=model.phase;build_kind="";wall_start=Vector2i(-999,-999);ordinary_pause=false
	world.preview.hide();model.workforce.cancel_rally();player.rogue_controls.reset();player.velocity=Vector3.ZERO
	paused=model.phase!="wave";get_tree().paused=paused
	if model.phase=="preparing":
		player.cancel_charge();player.attack_left=0;player.queued=false;player.attack_chain.reset()
		for group in ["projectiles","boss_waves","sky_smoke","edo_explosions","combo_energy"]:
			for effect in get_tree().get_nodes_in_group(group):
				if is_ancestor_of(effect):effect.queue_free()
		for actor in actors.values():
			if is_instance_valid(actor):actor.queue_free()
		actors.clear();enemies.clear();crowd.clear()
		pan=player.position;pan.y=0;rogue_view.clear();update_preparation_camera()
	elif model.phase=="wave":rogue_view.reset()
	elif model.phase=="victory":
		won=true;forest_ui.show_overlay("THE SHRINE ENDURES","Five waves survived. The forest is yours.",false)
	else:forest_ui.show_overlay("THE SHRINE HAS FALLEN","Wave %d · Gather your strength and try again."%model.wave,false)
	world.update_fog();forest_ui.sync()
func update_preparation_camera():
	var cam=camera_rig.camera;cam.projection=Camera3D.PROJECTION_ORTHOGONAL;cam.size=preparation_size
	cam.global_position=pan+Vector3(0,160,110);cam.look_at(pan,Vector3.UP)
func start_wave():
	if not playing or ordinary_pause or rogue_roster_open:return
	if model.start_wave():
		forest_ui.selected_id=-1;set_phase_view();toast("The forest stirs. Watch the edges of your vision.")
func select_build(kind: String):
	if not playing or ordinary_pause or model.phase!="preparing":return
	build_kind=kind;forest_ui.selected_id=-1;wall_start=Vector2i(-999,-999)
func ground_at(screen: Vector2)->Vector3:
	var cam=camera_rig.camera;var from=cam.project_ray_origin(screen);var direction=cam.project_ray_normal(screen)
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
	if model==null or ordinary_pause:return
	if model.phase=="wave":
		return
	if model.phase!="preparing":return
	if event is InputEventKey and event.pressed and event.physical_keycode==KEY_R:build_rotation=(build_rotation+1)%4;get_viewport().set_input_as_handled()
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
	if not ordinary_pause:
		if model.phase=="preparing":
			var move_=Input.get_vector("move_left","move_right","move_forward","move_back")
			pan+=Vector3(move_.x,0,move_.y)*delta*preparation_size*.7
			pan.x=clampf(pan.x,-155,155);pan.z=clampf(pan.z,-155,155);update_preparation_camera()
			if not build_kind.is_empty():
				var cell=model.cell_of(ground_at(get_viewport().get_mouse_position()))
				var reason=model.placement_error(build_kind,cell,build_rotation)
				placement_hint=reason if not reason.is_empty() else ("Drag a wall line" if build_kind=="wall" else "Click to place")
				if build_kind=="wall" and wall_start.x!=-999:
					var cells=wall_cells(cell);var cost=cells.size()*10;var valid=model.gold>=cost
					for c in cells:
						if not model.placement_error("wall",c,build_rotation).is_empty():valid=false
					placement_hint="%d segments · %d gold · Release to build"%[cells.size(),cost] if valid else "Blocked line or insufficient gold · %d gold"%cost
					world.show_wall_preview(cells,valid)
				else:world.show_preview(build_kind,cell,build_rotation,reason.is_empty())
		else:
			hit_stop=maxf(0,hit_stop-delta);chain_timer-=delta
			if chain_timer<=0:chain=0
		world.sync(delta if not paused else 0.0)
func _physics_process(delta):
	if model!=null and model.phase!=last_phase:set_phase_view()
	if model==null or paused or model.phase!="wave":return
	model.hero_targetable=not player.rogue_untargetable()
	model.tick(delta,player.position)
	for event in model.events:
		match event.kind:
			"hero_hit":player.take_hit(event.amount,(player.position-event.from).normalized())
			"wounded":toast("A worker is wounded. They will recover during preparation.")
			"arrow":
				if model.visible_at(event.to):
					var arrow=Geo.beam(self,event.from,event.to,.035,Geo.mat("edd293",0,.5))
					get_tree().create_timer(.12,false).timeout.connect(arrow.queue_free)
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
func forest_enemy_visible(enemy)->bool:return model!=null and model.visible_at(enemy.global_position)
func show_rogue_roster(starting: bool=false):
	if not playing and not starting:return
	if model.phase not in ["preparing","wave"] or player.hp<=0 or rogue_roster_open:return
	roster_return_pause=ordinary_pause
	player.cancel_charge(true);model.workforce.cancel_rally();Engine.time_scale=1
	ordinary_pause=true;paused=true;get_tree().paused=true
	build_kind="";wall_start=Vector2i(-999,-999);world.preview.hide();forest_ui.hide()
	rogue_roster_open=true;rogue_pick_start=starting
	var root=menu_base()
	var picker=load("res://scripts/rogue_roster_picker.gd").new();picker.game=self
	picker.title_text="F O R E S T   S H R I N E   /   C H O O S E   Y O U R   F I G H T E R"
	picker.start_hint="Choose a fighter, then build your settlement before the first wave."
	picker.back_text="Q / Esc · Back to preparation" if model.phase=="preparing" else "Q / Esc · Back to battle"
	root.add_child(picker)
func choose_rogue_character(id: int):
	if not rogue_roster_open or (id!=1 and not player.RogueRoster.is_rogue(id)):return
	selected_rogue_id=id;get_tree().set_meta("forest_fighter",id);player.select_character(id)
	var starting=rogue_pick_start
	rogue_roster_open=false;rogue_pick_start=false;clear_menu();forest_ui.show()
	if starting:playing=true;set_phase_view()
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
	ordinary_pause=true;paused=true;get_tree().paused=true;model.workforce.cancel_rally();player.cancel_charge(true);Engine.time_scale=1
	forest_ui.show_overlay("REST A MOMENT","Your settlement and the forest are paused.",true)
func resume():
	if model.phase not in ["preparing","wave"]:return
	ordinary_pause=false;forest_ui.close_overlay();paused=model.phase!="wave";get_tree().paused=paused
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
func damage_number(p: Vector3,amount: int,heavy: bool):
	if model.visible_at(p):super.damage_number(p,amount,heavy)
func burst(p: Vector3,color: Color,count: int,scale_factor: float=1.0):
	if model!=null and model.visible_at(p):super.burst(p,color,count,scale_factor)
func confirm_impact(victim: Ninja,p: Vector3,direction: Vector3,strength: int,projectile: bool):
	if model.visible_at(p):super.confirm_impact(victim,p,direction,strength,projectile)
func impact_effect(p: Vector3,direction: Vector3,strength: int):
	if model.visible_at(p):super.impact_effect(p,direction,strength)

func wall_cells(end: Vector2i)->Array:
	var change=end-wall_start;var horizontal=absi(change.x)>=absi(change.y)
	var length_=absi(change.x) if horizontal else absi(change.y)
	build_rotation=0 if horizontal else 1
	var cells=[]
	for i in range(mini(length_+1,40)):
		cells.append(wall_start+(Vector2i(signi(change.x)*i,0) if horizontal else Vector2i(0,signi(change.y)*i)))
	return cells

func show_title():
	playing=false;ordinary_pause=true;paused=true;get_tree().paused=true
	forest_ui.hide();rogue_view.reset();rogue_feedback.set_enabled(false)
	world.ground_material.set_shader_parameter("show_grid",false)
	var root=menu_base()
	var title_ui=preload("res://scripts/forest/forest_title_ui.gd").new();title_ui.game=self;root.add_child(title_ui)
func begin_forest():
	if playing:return
	rogue_feedback.set_enabled(true);show_rogue_roster(true)
