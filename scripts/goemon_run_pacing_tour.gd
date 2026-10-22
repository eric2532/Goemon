extends SceneTree
## Real-time production run capture: each rendered frame advances exactly 1/30 s.
## Fixed world-space stripes make travel speed and foot cadence visible together.
const Actor = preload("res://assets/rogue/scripts/actor.gd")
const IDS = ["goemon", "edo", "pirate", "samurai", "ninja", "mage", "knight", "dragoon", "magic-swordsman", "ranger", "explorer", "master-thief"]
const LABELS = ["GOEMON", "EDO", "PIRATE", "SAMURAI", "NINJA", "MAGE", "KNIGHT", "DRAGOON", "MAGIC SWORDSMAN", "RANGER", "EXPLORER", "MASTER THIEF"]
const STEP = 1.0 / 30.0
const FRAMES = 120
const SEGMENT_FRAMES = 60
var stage: Node3D
var actors: Array[Node3D] = []
var cameras: Array[Camera3D] = []
var header: Label
var phase_label: Label
var out = "res://docs/run-pacing"
var mode = "closeup"
var still = false
var captures = 0
var failures = 0
var key_poses: Dictionary = {}

func _initialize(): call_deferred("run")

func run():
	if DisplayServer.get_name() == "headless":
		push_error("Run pacing tour requires a renderer"); quit(1); return
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="): out = arg.trim_prefix("--out=")
		elif arg.begins_with("--mode="): mode = arg.trim_prefix("--mode=")
		elif arg == "--still": still = true
	if mode not in ["closeup", "roster", "poses"]:
		push_error("Expected --mode=closeup, --mode=roster or --mode=poses"); quit(1); return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out.path_join(mode + "-frames")))
	var ignore = FileAccess.open(out.path_join(".gdignore"), FileAccess.WRITE)
	ignore.store_string(""); ignore.close()
	root.size = Vector2i(1920, 1536) if mode == "roster" else Vector2i(960 if mode == "poses" else 1440, 810)
	root.content_scale_size = root.size
	setup_studio()
	await physics_frame
	await physics_frame
	for frame in range(30): pose_run(10.2, (frame - 30) * STEP)
	var start_z = actors[0].position.z
	for frame in range(FRAMES):
		var speed = 10.2 if frame < SEGMENT_FRAMES else 18.0
		pose_run(speed, frame * STEP)
		phase_label.text = ("RUN  10.2 UNITS/S" if frame < SEGMENT_FRAMES else "SPRINT  18.0 UNITS/S") + "  ·  GROUND MARKS EVERY 2 UNITS  ·  %.2f S" % (frame * STEP)
		position_cameras()
		if mode == "poses":
			var swing = sin(TAU * (actors[0].locomotion.phase - .12))
			var front = "left" if swing > .96 else ("right" if swing < -.96 else "")
			if frame >= 8 and front != "" and not key_poses.has(front):
				phase_label.text = "%s ARM FORWARD / INWARD  ·  %s ARM BACK / OUTWARD" % [front.to_upper(), "RIGHT" if front == "left" else "LEFT"]
				var base = actors[0].global_position
				cameras[1].global_position = base + Vector3(10 if front == "left" else -10, 2.8, -6)
				cameras[1].look_at(base + Vector3(0, 1.85, 0))
				await capture("goemon-run-" + front + "-arm-forward.png")
				key_poses[front] = true
				print("GOEMON_RUN_KEY_POSE front=", front, " phase=", actors[0].locomotion.phase, " frame=", frame)
			if key_poses.size() == 2: break
			continue
		if not still: await capture(mode + "-frames/%03d.png" % frame)
		if frame == (36 if mode == "closeup" else 30): await capture("goemon-run-pacing.png" if mode == "closeup" else "all-twelve-run-pacing.png")
		if frame == (91 if mode == "closeup" else 94): await capture("goemon-sprint-pacing.png" if mode == "closeup" else "all-twelve-sprint-pacing.png")
		if still and frame == (91 if mode == "closeup" else 94): break
	var distance = actors[0].position.z - start_z
	await create_timer(.4).timeout
	stage.free()
	await create_timer(.2).timeout
	print("GOEMON_RUN_PACING_TOUR mode=", mode, " captures=", captures, " failures=", failures, " simulation_fps=30 playback_fps=30 distance=", distance, " output=", out)
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
	light.rotation_degrees = Vector3(-42, -28, 0); light.light_energy = 1.2; light.shadow_enabled = true
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
	var stripe_material = StandardMaterial3D.new(); stripe_material.albedo_color = Color("8a9dad")
	var major_material = StandardMaterial3D.new(); major_material.albedo_color = Color("bac8d4")
	for index in range(-10, 65):
		var stripe = MeshInstance3D.new(); stripe.mesh = BoxMesh.new()
		stripe.mesh.size = Vector3(2000, .006, .09 if index % 5 == 0 else .035)
		stripe.position = Vector3(75, .003, index * 2.0)
		stripe.material_override = major_material if index % 5 == 0 else stripe_material
		stripe.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		stage.add_child(stripe)
	var background = ColorRect.new(); background.color = Color("132131")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); root.add_child(background)
	var column = VBoxContainer.new(); column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	column.add_theme_constant_override("separation", 0); root.add_child(column)
	header = Label.new(); header.custom_minimum_size.y = 66 if mode == "roster" else 58
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.add_theme_font_size_override("font_size", 28 if mode == "roster" else 24)
	header.text = "RUN + SPRINT  ·  ALL TWELVE HEROES  ·  REAL TIME 1×" if mode == "roster" else ("GOEMON RUN  ·  ALTERNATING ARM SWEEP" if mode == "poses" else "GOEMON RUN + SPRINT  ·  THREE VIEWS  ·  REAL TIME 1×")
	column.add_child(header)
	phase_label = Label.new(); phase_label.custom_minimum_size.y = 34
	phase_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	phase_label.add_theme_font_size_override("font_size", 17)
	phase_label.add_theme_color_override("font_color", Color("bbcedd")); column.add_child(phase_label)
	var grid = GridContainer.new(); grid.columns = 4 if mode == "roster" else (2 if mode == "poses" else 3)
	grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 0); grid.add_theme_constant_override("v_separation", 0)
	column.add_child(grid)
	for i in range(IDS.size() if mode == "roster" else 1):
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
	for i in range(IDS.size() if mode == "roster" else (2 if mode == "poses" else 3)):
		var panel = SubViewportContainer.new(); panel.stretch = true
		panel.custom_minimum_size = Vector2(480, 478) if mode == "roster" else Vector2(480, 718)
		grid.add_child(panel)
		var viewport = SubViewport.new(); viewport.size = Vector2i(panel.custom_minimum_size)
		viewport.world_3d = stage.get_world_3d(); viewport.msaa_3d = Viewport.MSAA_4X
		viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS; panel.add_child(viewport)
		var camera = Camera3D.new(); viewport.add_child(camera)
		camera.projection = Camera3D.PROJECTION_ORTHOGONAL
		camera.size = 4.9 if mode == "roster" else 4.8
		cameras.append(camera)
		var label = Label.new(); label.text = LABELS[i] if mode == "roster" else (["REAR", "REAR THREE-QUARTER"][i] if mode == "poses" else ["REAR", "SIDE", "REAR THREE-QUARTER"][i])
		label.position = Vector2(18, 16); label.add_theme_font_size_override("font_size", 18)
		label.add_theme_color_override("font_shadow_color", Color("142030"))
		label.add_theme_constant_override("shadow_offset_x", 1); label.add_theme_constant_override("shadow_offset_y", 1)
		panel.add_child(label)

func pose_run(speed: float, time: float):
	for i in range(actors.size()):
		var actor = actors[i]
		actor.position += Vector3.BACK * speed * STEP
		if i < 2:
			actor.locomotion_velocity = Vector3.BACK * speed
			actor.animate(STEP, speed, true, 0, 0, false, 0, false)
			actor.sync_skeleton()
		else:
			actor.animate_pose({"grounded":true, "isPlayer":true, "motionSpeed":speed, "localMotion":Vector3.BACK * speed}, STEP, time, 1.0)

func position_cameras():
	for i in range(cameras.size()):
		var actor = actors[i if mode == "roster" else 0]
		var base = Vector3(actor.global_position.x, 0, actor.global_position.z)
		var view_index = 2 if mode == "poses" and i == 1 else i
		var offset = Vector3(-7, 3.0, -10) if mode == "roster" else [Vector3(0, 2.8, -10), Vector3(10, 2.8, 0), Vector3(-7, 2.8, -10)][view_index]
		cameras[i].global_position = base + offset
		cameras[i].look_at(base + Vector3(0, 1.85, 0))

func capture(path: String):
	await process_frame
	await RenderingServer.frame_post_draw
	var error = root.get_texture().get_image().save_png(out.path_join(path))
	if error != OK: failures += 1
	captures += 1
