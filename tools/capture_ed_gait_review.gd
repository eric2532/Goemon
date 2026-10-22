extends SceneTree
## Side-by-side original ROM poses and the active playable Ed locomotion.
const OUTPUT = "/Users/eric/Desktop/Projects_Codex/Sonic/build/Other Files/Ed Original Restore"
var actors = []
var camera: Camera3D

func _initialize():
	run.call_deferred()

func run():
	await process_frame
	if current_scene != null:
		current_scene.queue_free()
		current_scene = null
		await process_frame
	root.size = Vector2i(1080, 720)
	DirAccess.make_dir_recursive_absolute(OUTPUT)
	var stage = Node3D.new()
	root.add_child(stage)
	var world = WorldEnvironment.new()
	world.environment = Environment.new()
	world.environment.background_mode = Environment.BG_COLOR
	world.environment.background_color = Color("25323d")
	world.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	world.environment.ambient_light_color = Color.WHITE
	world.environment.ambient_light_energy = 0.8
	stage.add_child(world)
	var floor_mesh = MeshInstance3D.new()
	floor_mesh.mesh = PlaneMesh.new()
	floor_mesh.mesh.size = Vector2(12, 12)
	stage.add_child(floor_mesh)
	var floor_mat = StandardMaterial3D.new()
	floor_mat.albedo_color = Color("4b5862")
	floor_mesh.material_override = floor_mat
	for i in 2:
		var actor = load("res://scripts/recovered_ed_model.gd" if i == 0 else "res://scripts/recovered_leader_model.gd").new()
		stage.add_child(actor)
		actor.position.x = -1.35 if i == 0 else 1.35
		actor.rotation.y = -0.4
		actors.append(actor)
	var canvas = CanvasLayer.new()
	root.add_child(canvas)
	for i in 2:
		var label = Label.new()
		label.text = "Current playable Ed" if i == 0 else "Original ROM Ed · source 01"
		label.position = Vector2(95 + i * 500, 36)
		label.add_theme_font_size_override("font_size", 24)
		canvas.add_child(label)
	camera = Camera3D.new()
	stage.add_child(camera)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 5.4
	camera.position = Vector3(0, 2.2, -7)
	camera.look_at(Vector3(0, 1.1, 0))
	camera.make_current()
	await process_frame
	for frame in 48:
		actors[0].animate(1.0 / 30.0, 7.0, true, 0.0, 0.0, false, 0, false)
		actors[0].blend_left = 0
		actors[1]._sample(actors[1].motion("source_01"), float(frame) / 30.0, 0.1, true)
		await process_frame
		RenderingServer.force_draw(false)
		root.get_texture().get_image().save_png(OUTPUT + "/gait_%03d.png" % frame)
	print("ED_GAIT_REVIEW frames=48 output=", OUTPUT)
	stage.queue_free()
	canvas.queue_free()
	await process_frame
	quit()
