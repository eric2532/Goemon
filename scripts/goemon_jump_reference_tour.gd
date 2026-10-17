extends SceneTree
## Studio capture of the production jump pose. Root motion is supplied as a
## controller-style ballistic arc; no posing code or game settings are changed.
const Actor = preload("res://assets/rogue/scripts/actor.gd")
const IDS = ["goemon", "edo", "pirate", "samurai", "ninja", "mage", "knight", "dragoon", "magic-swordsman", "ranger", "explorer", "master-thief"]
const LABELS = ["GOEMON", "EDO", "PIRATE", "SAMURAI", "NINJA", "MAGE", "KNIGHT", "DRAGOON", "MAGIC SWORDSMAN", "RANGER", "EXPLORER", "MASTER THIEF"]
const STEP = 1.0 / 60.0
const SPEED = 10.2
const INTRO = .4
const AIR_TIME = .8
const FRAMES = 108
var stage: Node3D
var actors: Array[Node3D] = []
var cameras: Array[Camera3D] = []
var header: Label
var phase_label: Label
var out = "res://docs/jump-reference"
var mode = "closeup"
var still = false
var captures = 0
var failures = 0

func _initialize(): call_deferred("run")

func run():
	if DisplayServer.get_name() == "headless":
		push_error("Jump reference tour requires a renderer"); quit(1); return
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="): out = arg.trim_prefix("--out=")
		elif arg.begins_with("--mode="): mode = arg.trim_prefix("--mode=")
		elif arg == "--still": still = true
	if mode not in ["closeup", "roster"]:
		push_error("Expected --mode=closeup or --mode=roster"); quit(1); return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out.path_join(mode + "-frames")))
	root.size = Vector2i(1440, 900) if mode == "closeup" else Vector2i(1920, 1536)
	root.content_scale_size = root.size
	setup_studio()
	await physics_frame
	await physics_frame
	for warm in range(90): pose_at(-STEP)
	for frame in range(FRAMES):
		pose_at(frame * STEP)
		position_cameras()
		if not still: await capture(mode + "-frames/%03d.png" % frame)
		if frame == 48: await capture("goemon-jump-three-views-apex.png" if mode == "closeup" else "all-twelve-jump-apex.png")
		if still and frame == 48: break
	await create_timer(.4).timeout
	stage.free()
	await create_timer(.2).timeout
	print("GOEMON_JUMP_REFERENCE_TOUR mode=", mode, " captures=", captures, " failures=", failures, " simulation_fps=60 playback_fps=30 output=", out)
	quit(1 if failures else 0)

func setup_studio():
	stage = Node3D.new(); root.add_child(stage)
	var env = WorldEnvironment.new(); env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color("263444")
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color("d5e1ec")
	env.environment.ambient_light_energy = .8
	stage.add_child(env)
	var light = DirectionalLight3D.new(); stage.add_child(light)
	light.rotation_degrees = Vector3(-42, -28, 0); light.light_energy = 1.2
	light.shadow_enabled = true
	var fill = DirectionalLight3D.new(); stage.add_child(fill)
	fill.rotation_degrees = Vector3(-18, 155, 0); fill.light_energy = .4
	var ground = StaticBody3D.new(); stage.add_child(ground)
	var collision = CollisionShape3D.new(); collision.shape = BoxShape3D.new()
	collision.shape.size = Vector3(400, .2, 300); collision.position = Vector3(70, -.1, 0)
	ground.add_child(collision)
	var floor_mesh = MeshInstance3D.new(); floor_mesh.mesh = PlaneMesh.new()
	floor_mesh.mesh.size = Vector2(2000, 2000); floor_mesh.position.x = 70
	var material = StandardMaterial3D.new(); material.albedo_color = Color("536575")
	floor_mesh.material_override = material; stage.add_child(floor_mesh)
	var background = ColorRect.new(); background.color = Color("132131")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); root.add_child(background)
	var column = VBoxContainer.new(); column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	column.add_theme_constant_override("separation", 0); root.add_child(column)
	header = Label.new(); header.custom_minimum_size.y = 58 if mode == "closeup" else 66
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.add_theme_font_size_override("font_size", 24 if mode == "closeup" else 28)
	header.text = "GOEMON JUMP  ·  THREE VIEWS  ·  0.5× PLAYBACK" if mode == "closeup" else "GOEMON REFERENCE JUMP  ·  ALL TWELVE HEROES  ·  0.5× PLAYBACK"
	column.add_child(header)
	phase_label = Label.new(); phase_label.custom_minimum_size.y = 34
	phase_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	phase_label.add_theme_font_size_override("font_size", 17)
	phase_label.add_theme_color_override("font_color", Color("bbcedd")); column.add_child(phase_label)
	var grid = GridContainer.new(); grid.columns = 3 if mode == "closeup" else 4
	grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 0); grid.add_theme_constant_override("v_separation", 0)
	column.add_child(grid)
	for i in range(1 if mode == "closeup" else IDS.size()):
		var actor: Node3D
		if i == 0:
			actor = HeroModel.new(); stage.add_child(actor)
			actor.rotation.y = PI; actor.set_process(false); actor.equipped = false
		elif i == 1:
			actor = MusashiModel.new(); stage.add_child(actor)
			actor.rotation.y = PI; actor.set_process(false); actor.equipped = false
		else:
			actor = Actor.new(); stage.add_child(actor); actor.setup(IDS[i]); actor.seed = 0
		actor.position.x = i * 14.0
		actors.append(actor)
	for i in range(3 if mode == "closeup" else IDS.size()):
		var panel = SubViewportContainer.new(); panel.stretch = true
		panel.custom_minimum_size = Vector2(480, 808) if mode == "closeup" else Vector2(480, 478)
		grid.add_child(panel)
		var viewport = SubViewport.new(); viewport.size = Vector2i(panel.custom_minimum_size)
		viewport.world_3d = stage.get_world_3d(); viewport.msaa_3d = Viewport.MSAA_4X
		viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS; panel.add_child(viewport)
		var camera = Camera3D.new(); viewport.add_child(camera)
		camera.projection = Camera3D.PROJECTION_ORTHOGONAL
		camera.size = 6.4 if mode == "closeup" else 7.4
		cameras.append(camera)
		var label = Label.new(); label.text = ["REAR", "SIDE", "REAR THREE-QUARTER"][i] if mode == "closeup" else LABELS[i]
		label.position = Vector2(18, 16); label.add_theme_font_size_override("font_size", 18)
		label.add_theme_color_override("font_shadow_color", Color("142030"))
		label.add_theme_constant_override("shadow_offset_x", 1); label.add_theme_constant_override("shadow_offset_y", 1)
		panel.add_child(label)

func pose_at(time: float):
	var air_time = time - INTRO
	var grounded = air_time < 0 or air_time >= AIR_TIME
	var vertical = 0.0 if grounded else 12.0 - 30.0 * air_time
	var height = 0.0 if grounded else 12.0 * air_time - 15.0 * air_time * air_time
	phase_label.text = "RUN-UP" if air_time < 0 else ("LANDING / RECOVERY" if grounded else ("RISE" if vertical > 1 else ("FALL" if vertical < -1 else "APEX")))
	for i in range(actors.size()):
		var actor = actors[i]
		actor.position += Vector3.BACK * SPEED * STEP
		actor.position.y = height
		if i < 2:
			actor.locomotion_velocity = Vector3.BACK * SPEED
			actor.animate(STEP, SPEED, grounded, vertical, 0, false, 0, false)
			actor.sync_skeleton()
		else:
			actor.animate_pose({"grounded":grounded, "vertical":vertical, "isPlayer":true, "motionSpeed":SPEED, "localMotion":Vector3.BACK * SPEED}, STEP, time, 1.0)

func position_cameras():
	for i in range(cameras.size()):
		var actor = actors[0 if mode == "closeup" else i]
		var base = Vector3(actor.global_position.x, actor.global_position.y * .4 if mode == "closeup" else 0, actor.global_position.z)
		var offset = [Vector3(0, 3.4, -10), Vector3(10, 3.4, 0), Vector3(-7, 3.4, -10)][i] if mode == "closeup" else Vector3(-7, 3.7, -10)
		cameras[i].global_position = base + offset
		cameras[i].look_at(base + Vector3(0, 2.65 if mode == "closeup" else 3.25, 0))

func capture(path: String):
	await process_frame
	await RenderingServer.frame_post_draw
	var error = root.get_texture().get_image().save_png(out.path_join(path))
	if error != OK: failures += 1
	captures += 1
