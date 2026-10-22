extends SceneTree
## Render the real beam runtime with the recovered Ed model for visual review.
const Fixture = preload("res://scripts/recovered_ed_beam_tests.gd")
const OUTPUT = "/Users/eric/Desktop/Projects_Codex/Sonic/build/Other Files/Ed Original Restore/Beam Frames"

class ReviewBeam:
	extends "res://scripts/recovered_ed_beam.gd"
	func stop():
		# Offline capture must continue while the user works in another window.
		if not _focused:
			_focused = true
			return
		super.stop()

func _initialize():run.call_deferred()

func run():
	await process_frame
	if current_scene != null:
		current_scene.queue_free()
		current_scene = null
		await process_frame
	paused = false
	DirAccess.make_dir_recursive_absolute(OUTPUT)
	root.size = Vector2i(1280, 800)
	create_timer(60).timeout.connect(func(): push_error("Ed beam capture timed out"); quit(1))
	var arena = Fixture.Arena.new()
	root.add_child(arena)
	var lib = SoundLibrary.new()
	lib.config_path = "user://ed-beam-review-%d/studio.cfg" % OS.get_process_id()
	lib.folder = "user://ed-beam-review-%d/recordings" % OS.get_process_id()
	arena.add_child(lib)
	lib.set_process(false)
	arena.sound_library = lib
	lib.custom_for(14, "ed_beam_charge")
	var environment = WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("24313b")
	arena.add_child(environment)
	var floor_mesh = MeshInstance3D.new()
	floor_mesh.mesh = PlaneMesh.new()
	floor_mesh.mesh.size = Vector2(80, 80)
	var floor_material = StandardMaterial3D.new()
	floor_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	floor_material.albedo_color = Color("3b4650")
	floor_mesh.material_override = floor_material
	arena.add_child(floor_mesh)
	var caster = Fixture.Caster.new()
	caster.character_id = 14
	caster.game = arena
	arena.player = caster
	arena.add_child(caster)
	caster.set_process_unhandled_input(false)
	caster.set_process_input(false)
	caster.model = load("res://scripts/recovered_ed_model.gd").new()
	caster.add_child(caster.model)
	caster.model.rotation.y = -PI / 2
	var camera = Camera3D.new()
	arena.add_child(camera)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 32
	camera.position = Vector3(-2, 16, 24)
	camera.look_at(Vector3(10, 1.6, 0))
	camera.make_current()
	var beam = ReviewBeam.new()
	beam.hero = caster
	beam.game = arena
	arena.add_child(beam)
	beam.set_process(false)
	var beam_end = beam.visual.to_global(Vector3(0, 0, -784))
	var beam_center = (beam.global_position + beam_end) * 0.5
	camera.size = maxf(32.0, beam.global_position.distance_to(beam_end) * 0.65)
	camera.position = beam_center + Vector3(-12, 14.4, 24)
	camera.look_at(beam_center)
	for frame in 60:
		if not is_instance_valid(beam): push_error("Capture beam ended early"); quit(1); return
		beam.advance(1.0 / 30.0)
		caster.model._sample(caster.model.motion("source_06"), beam.elapsed, 1.0 / 30.0, true)
		await process_frame
		RenderingServer.force_draw(false)
		root.get_texture().get_image().save_png(OUTPUT + "/beam_%03d.png" % frame)
		if frame == 25:
			var renderer=preload("res://scripts/recovered_ed_beam_renderer.gd").ensure(beam)
			renderer.set_process(false);renderer.render_frame()
			await process_frame
			RenderingServer.force_draw(false)
			root.get_texture().get_image().save_png(OUTPUT+"/native-composite.png")
			renderer.frame_image.save_png(OUTPUT+"/native-foreground-rgb5.png")
			renderer.hide()
			await process_frame
			RenderingServer.force_draw(false)
			root.get_texture().get_image().save_png(OUTPUT+"/native-background.png")
			renderer.show();renderer.set_process(true)
			for glow in beam.visual.glows:
				print("ED_GLOW_CAPTURE visible=", glow.is_visible_in_tree(), " position=", glow.global_position, " scale=", glow.global_basis.get_scale(), " tint=", glow.material_override.get_shader_parameter("source_tint"))
			var layers = [beam.visual.main, beam.visual.companion, beam.shield]
			for layer in layers: layer.hide()
			await process_frame
			RenderingServer.force_draw(false)
			root.get_texture().get_image().save_png(OUTPUT + "/source-glow-layer.png")
			for layer in layers: layer.show()
	beam.release()
	for frame in 16:
		beam._process(1.0 / 30.0)
		caster.model._sample(caster.model.motion("source_06") if beam.releasing else caster.model.motion("source_05"), beam.release_elapsed if beam.releasing else 0.0, 1.0 / 30.0, beam.releasing)
		await process_frame
		RenderingServer.force_draw(false)
		root.get_texture().get_image().save_png(OUTPUT + "/beam_%03d.png" % (frame + 60))
	print("ED_ORIGINAL_BEAM_CAPTURE frames=76 output=", OUTPUT)
	if is_instance_valid(beam):beam.stop()
	arena.queue_free()
	await process_frame
	await create_timer(0.35).timeout
	quit()
