extends "res://scripts/goemon_run_reference_tests.gd"
## Three synchronized views of the actual gameplay skeleton and terrain solver.
var cameras: Array[Camera3D] = []
var out = "res://docs/goemon-run-reference/frames"

func run():
	if DisplayServer.get_name() == "headless":
		quit(1)
		return
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="): out = arg.trim_prefix("--out=")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out))
	root.size = Vector2i(1296, 520)
	root.content_scale_size = Vector2i(1296, 520)
	await setup()
	var env = WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color("394450")
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color("cbd5df")
	env.environment.ambient_light_energy = .65
	stage.add_child(env)
	var light = DirectionalLight3D.new()
	stage.add_child(light)
	light.rotation_degrees = Vector3(-48, -30, 0)
	light.shadow_enabled = true
	light.light_energy = 1.3
	var floor_mesh = MeshInstance3D.new()
	floor_mesh.mesh = PlaneMesh.new()
	floor_mesh.mesh.size = Vector2(200, 200)
	var material = StandardMaterial3D.new()
	material.albedo_color = Color("646c71")
	floor_mesh.material_override = material
	stage.add_child(floor_mesh)
	var row = HBoxContainer.new()
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.add_theme_constant_override("separation", 0)
	root.add_child(row)
	for title in ["SIDE", "REAR", "REAR THREE-QUARTER"]:
		var panel = SubViewportContainer.new()
		panel.stretch = true
		panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(panel)
		var viewport = SubViewport.new()
		viewport.size = Vector2i(432, 520)
		viewport.world_3d = stage.get_world_3d()
		viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		viewport.msaa_3d = Viewport.MSAA_4X
		panel.add_child(viewport)
		var camera = Camera3D.new()
		viewport.add_child(camera)
		camera.projection = Camera3D.PROJECTION_ORTHOGONAL
		camera.size = 4.1
		cameras.append(camera)
		var label = Label.new()
		label.text = title
		label.position = Vector2(20, 18)
		label.add_theme_font_size_override("font_size", 18)
		panel.add_child(label)
	for i in range(120): step(Vector3.FORWARD * 10.2)
	var gait: Vector3 = model.locomotion.gait()
	var frame_delta = (gait.y / gait.x / 10.2) * 5.0 / 60.0
	for frame in range(60):
		step(Vector3.FORWARD * 10.2, frame_delta * .5)
		step(Vector3.FORWARD * 10.2, frame_delta * .5)
		for i in range(3):
			cameras[i].global_position = model.global_position + [Vector3(-7, 2.3, 0), Vector3(0, 2.3, 7), Vector3(-5, 2.3, 6)][i]
			cameras[i].look_at(model.global_position + Vector3(0, 1.60, 0))
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(out.path_join("%03d.png" % frame))
	# Let the last captured frame finish on Metal before releasing its world.
	await create_timer(1.0).timeout
	stage.free()
	await create_timer(.3).timeout
	print("GOEMON_RUN_REFERENCE_TOUR frames=60 fps=", 1.0 / frame_delta, " output=", out)
	quit()
