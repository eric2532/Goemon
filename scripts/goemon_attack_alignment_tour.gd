extends SceneTree
## Render current imported rigs and their production pose adapters, without game settings.
const Actor = preload("res://assets/rogue/scripts/actor.gd")
const Actions = preload("res://assets/rogue/scripts/class_actions.gd")
const Combat = preload("res://scripts/rogue_roster_combat.gd")
const GoemonCombo = preload("res://scripts/goemon_rogue_combo.gd")
const IDS = ["goemon", "edo", "pirate", "samurai", "ninja", "mage", "knight", "dragoon", "magic-swordsman", "ranger", "explorer", "master-thief"]
const LABELS = ["GOEMON", "EDO", "PIRATE", "SAMURAI", "NINJA", "MAGE", "KNIGHT", "DRAGOON", "MAGIC SWORDSMAN", "RANGER", "EXPLORER", "MASTER THIEF"]
const STEP = 1.0 / 30.0
var stage: Node3D
var actors: Array[Node3D] = []
var cameras: Array[Camera3D] = []
var header: Label
var edo_combat: MusashiCombat
var edo_hero: Hero
var out = "res://docs/attack-alignment"
var captures = 0
var failures = 0

func _initialize():call_deferred("run")

func run():
	if DisplayServer.get_name() == "headless":
		push_error("Attack alignment tour requires a renderer");quit(1);return
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):out = arg.trim_prefix("--out=")
	for folder in [out, out.path_join("attack-frames"), out.path_join("run-frames")]:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
	var ignore = FileAccess.open(out.path_join(".gdignore"), FileAccess.WRITE)
	ignore.store_string("");ignore.close()
	root.size = Vector2i(1680, 1260)
	root.content_scale_size = root.size
	setup_studio()
	await physics_frame
	await physics_frame
	header.text = "ATTACK CONTACT / RELEASE  ·  CURRENT RUNTIME RIGS"
	for warm in range(15):pose_attacks(0.0, true)
	position_cameras(false)
	await capture("attack-contact.png")
	header.text = "ATTACK CYCLES  ·  0.5× PLAYBACK  ·  CURRENT RUNTIME RIGS"
	for frame in range(60):
		pose_attacks(frame * STEP)
		position_cameras(false)
		await capture("attack-frames/%03d.png" % frame)
	for i in range(IDS.size()):
		if i < 2:actors[i].locomotion.reset()
		else:actors[i].reset_motion()
	for warm in range(90):pose_run()
	header.text = "RUN  ·  REAR THREE-QUARTER  ·  0.5× PLAYBACK"
	for frame in range(60):
		pose_run()
		position_cameras(true)
		await capture("run-frames/%03d.png" % frame)
		if frame == 8:await capture("run-three-quarter.png")
	await create_timer(1.0).timeout
	stage.free()
	edo_combat.free();edo_hero.free()
	await create_timer(.3).timeout
	print("GOEMON_ATTACK_ALIGNMENT_TOUR captures=", captures, " failures=", failures, " output=", out)
	quit(1 if failures else 0)

func setup_studio():
	stage = Node3D.new();root.add_child(stage)
	var env = WorldEnvironment.new();env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color("25313f")
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color("d5e1ec")
	env.environment.ambient_light_energy = .7
	stage.add_child(env)
	var light = DirectionalLight3D.new();stage.add_child(light)
	light.rotation_degrees = Vector3(-48, -28, 0);light.light_energy = 1.1
	light.shadow_enabled = true
	var ground = StaticBody3D.new();stage.add_child(ground)
	var collision = CollisionShape3D.new();collision.shape = BoxShape3D.new()
	collision.shape.size = Vector3(400, .2, 300);collision.position = Vector3(70, -.1, 0)
	ground.add_child(collision)
	var floor_mesh = MeshInstance3D.new();floor_mesh.mesh = PlaneMesh.new()
	floor_mesh.mesh.size = Vector2(400, 300);floor_mesh.position.x = 70
	var material = StandardMaterial3D.new();material.albedo_color = Color("536170")
	floor_mesh.material_override = material;stage.add_child(floor_mesh)
	var background = ColorRect.new();background.color = Color("15212d")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);root.add_child(background)
	var column = VBoxContainer.new();column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	column.add_theme_constant_override("separation", 0);root.add_child(column)
	header = Label.new();header.custom_minimum_size.y = 72
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.add_theme_font_size_override("font_size", 25);column.add_child(header)
	var grid = GridContainer.new();grid.columns = 4
	grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 0);grid.add_theme_constant_override("v_separation", 0)
	column.add_child(grid)
	edo_hero = Hero.new() # Real attack-speed state; no scene lifecycle or settings.
	edo_combat = MusashiCombat.new();edo_combat.hero = edo_hero
	for i in range(IDS.size()):
		var actor: Node3D
		if i == 0:
			actor = HeroModel.new();stage.add_child(actor)
			actor.rotation.y = PI;actor.set_process(false)
			actor.pipe_combo_active = true;actor.rogue_pipe_combo_active = true;actor.equipped = true
		elif i == 1:
			actor = MusashiModel.new();stage.add_child(actor)
			actor.rotation.y = PI;actor.set_process(false);actor.combat = edo_combat
		else:
			actor = Actor.new();stage.add_child(actor);actor.setup(IDS[i]);actor.seed = 0
		actor.position.x = i * 14.0
		actors.append(actor)
		var panel = SubViewportContainer.new();panel.stretch = true
		panel.custom_minimum_size = Vector2(420, 396);grid.add_child(panel)
		var viewport = SubViewport.new();viewport.size = Vector2i(420, 396)
		viewport.world_3d = stage.get_world_3d();viewport.msaa_3d = Viewport.MSAA_4X
		viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS;panel.add_child(viewport)
		var camera = Camera3D.new();viewport.add_child(camera)
		camera.projection = Camera3D.PROJECTION_ORTHOGONAL;camera.size = 4.9
		cameras.append(camera)
		var label = Label.new();label.text = LABELS[i]
		label.position = Vector2(16, 14);label.add_theme_font_size_override("font_size", 18)
		label.add_theme_color_override("font_shadow_color", Color("142030"))
		label.add_theme_constant_override("shadow_offset_x", 1);label.add_theme_constant_override("shadow_offset_y", 1)
		panel.add_child(label)

func attack_at(id: String, time: float, contact: bool) -> Dictionary:
	var phases: Array = []
	if id == "pirate":
		for item in Combat.COMBO:phases.append(item.duplicate())
	elif id == "samurai":
		for item in Actions.SAMURAI_CUTS:
			var cut = Actions.PRIMARY.samurai.duplicate();cut.merge(item, true);cut.style = "samurai-cut";phases.append(cut)
	else:
		for index in range(3):
			var cut: Dictionary = Actions.PRIMARY[id].duplicate()
			if index == 2 and id != "ranger":cut.duration *= 1.2
			phases.append(cut)
	var total = 0.0
	for item in phases:total += item.duration
	var elapsed = fposmod(time, total)
	for index in range(phases.size()):
		var attack: Dictionary = phases[index]
		if elapsed < attack.duration or index == phases.size() - 1:
			attack.time = attack.contact if contact else elapsed
			attack.index = index;attack.primary = true;attack.swingSide = -1 if index % 2 else 1
			return attack
		elapsed -= attack.duration
	return {}

func pose_attacks(time: float, contact: bool = false):
	var goemon = actors[0]
	goemon.locomotion_velocity = Vector3.ZERO
	var elapsed = fposmod(time, GoemonCombo.DURATIONS[0] + GoemonCombo.DURATIONS[1] + GoemonCombo.DURATIONS[2])
	var combo = 1
	while combo < 3 and elapsed > GoemonCombo.duration(combo):
		elapsed -= GoemonCombo.duration(combo);combo += 1
	var progress = GoemonCombo.contact_phase(combo) if contact else elapsed / GoemonCombo.duration(combo)
	goemon.animate(STEP, 0, true, 0, 1.0 - progress, false, combo, false);goemon.sync_skeleton()
	edo_combat.state = MusashiCombat.State.FIREBALL
	edo_combat.duration = edo_combat.balance.volley_duration
	edo_combat.elapsed = edo_combat.duration * .27 if contact else fposmod(time, edo_combat.duration)
	actors[1].locomotion_velocity = Vector3.ZERO
	actors[1].animate(STEP, 0, true, 0, 0, false, 0, false)
	for i in range(2, IDS.size()):
		var state = {"grounded":true, "isPlayer":true, "motionSpeed":0.0, "meleeVisualScale":1.0}
		if IDS[i] == "mage":
			state.shot = .2 if contact else maxf(0, .2 - fposmod(time, .75))
		else:state.attack = attack_at(IDS[i], time, contact)
		actors[i].animate_pose(state, STEP, time, 0)

func pose_run():
	edo_combat.state = MusashiCombat.State.MOVING
	for i in range(IDS.size()):
		if i < 2:
			if i == 0:actors[i].position += Vector3.BACK * 10.2 * STEP
			actors[i].locomotion_velocity = Vector3.BACK * 10.2
			actors[i].animate(STEP, 10.2, true, 0, 0, false, 0, false)
			actors[i].sync_skeleton()
		else:
			actors[i].animate_pose({"grounded":true, "motionSpeed":10.2, "localMotion":Vector3.BACK * 10.2}, STEP, actors[i].locomotion.phase, 1.0)

func position_cameras(rear: bool):
	for i in range(cameras.size()):
		cameras[i].global_position = actors[i].global_position + (Vector3(-7, 3.0, -10) if rear else Vector3(7, 3.0, 10))
		cameras[i].look_at(actors[i].global_position + Vector3(0, 1.60, 0))

func capture(path: String):
	await process_frame
	await RenderingServer.frame_post_draw
	var error = root.get_texture().get_image().save_png(out.path_join(path))
	if error != OK:failures += 1
	captures += 1
