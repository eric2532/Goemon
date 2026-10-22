extends SceneTree
## Rebuild the HUD images from the same recovered meshes/materials used in play.
## Run with the native renderer (not --headless):
## godot --path . --audio-driver Dummy --script tools/render_goemon_weapon_icons.gd
const Weapons = preload("res://scripts/recovered_goemon_weapons.gd")
const OUTPUT := "res://assets/ui/recovered_goemon/"
const RESOLUTION := 512
const PADDING := 0.12

func _initialize() -> void:
	run.call_deferred()

func chain_pipe() -> Node3D:
	var weapon := Node3D.new()
	weapon.name = "RecoveredChainPipe"
	var grip := Weapons.create_part("chain_pipe_grip", 0.01)
	grip.rotation.y = PI / 2.0
	weapon.add_child(grip)
	var head := Weapons.create_part("chain_pipe_projectile_head", 0.01)
	var endpoint := Vector3(0, -0.15, -1.48)
	var start := Vector3(0, 0, -0.3)
	var direction := (endpoint - start).normalized()
	head.basis = Basis.looking_at(direction, Vector3.UP)
	head.position = endpoint
	weapon.add_child(head)
	# Match ChainPipeVisual's recovered link spacing, alternating planes, and sag.
	var count := clampi(ceili(start.distance_to(endpoint) / 0.095), 2, 512)
	for i in range(count):
		var link := Weapons.create_part("chain_link", 0.0068)
		var t := float(i) / maxf(1, count - 1)
		link.position = start.lerp(endpoint, t)
		link.position.y -= sin(t * PI) * 0.16
		link.basis = head.basis * Basis(Vector3.FORWARD, (i % 2) * PI / 2) * Basis.from_scale(Vector3(2.6, 2.6, 1.0))
		weapon.add_child(link)
	return weapon

func bounds_in_view(weapon: Node3D) -> AABB:
	var bounds := AABB()
	var first := true
	for part: MeshInstance3D in weapon.find_children("*", "MeshInstance3D", true, false):
		for surface in range(part.mesh.get_surface_count()):
			var vertices: PackedVector3Array = part.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]
			for vertex in vertices:
				var point := part.global_transform * vertex
				bounds = AABB(point, Vector3.ZERO) if first else bounds.expand(point)
				first = false
	return bounds

func render_icon(file_name: String, weapon: Node3D, pose: Basis) -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(RESOLUTION, RESOLUTION)
	viewport.transparent_bg = true
	viewport.own_world_3d = true
	viewport.msaa_3d = Viewport.MSAA_4X
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color(0, 0, 0, 0)
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color.WHITE
	environment.environment.ambient_light_energy = 0.8
	environment.environment.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	viewport.add_child(environment)
	var key := DirectionalLight3D.new()
	key.light_energy = 0.8
	key.rotation_degrees = Vector3(-25, -25, 0)
	viewport.add_child(key)
	var framing := Node3D.new()
	viewport.add_child(framing)
	framing.add_child(weapon)
	weapon.basis = pose
	var bounds := bounds_in_view(framing)
	framing.position = -bounds.get_center()
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = maxf(bounds.size.x, bounds.size.y) / (1.0 - PADDING * 2.0)
	camera.position.z = maxf(5.0, bounds.size.z * 3.0)
	camera.far = camera.position.z + bounds.size.z * 3.0 + 100.0
	camera.current = true
	viewport.add_child(camera)
	for i in range(4):
		await process_frame
	await RenderingServer.frame_post_draw
	var rendered := viewport.get_texture().get_image()
	rendered.resize(256, 256, Image.INTERPOLATE_LANCZOS)
	var path := OUTPUT + file_name + ".png"
	var error := rendered.save_png(path)
	assert(error == OK, "Unable to save " + path)
	print("GOEMON_WEAPON_ICON ", path, " source_bounds=", bounds, " image=", rendered.get_size())
	viewport.queue_free()
	await process_frame

func run() -> void:
	if DisplayServer.get_name() == "headless":
		printerr("Weapon HUD images require the native Godot renderer")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	var gold := Node3D.new()
	gold.add_child(Weapons.create_part("gold_pipe", 0.01))
	await render_icon("gold_pipe", gold, Basis(Vector3.BACK, deg_to_rad(35)) * Basis(Vector3.UP, deg_to_rad(68)) * Basis(Vector3.RIGHT, deg_to_rad(8)))
	var coin := Weapons.create_coin()
	await render_icon("ryo", coin, Basis.IDENTITY)
	await render_icon("chain_pipe", chain_pipe(), Basis(Vector3.BACK, deg_to_rad(38)) * Basis(Vector3.UP, deg_to_rad(-45)))
	print("GOEMON_WEAPON_ICONS_RENDERED count=3")
	quit()
