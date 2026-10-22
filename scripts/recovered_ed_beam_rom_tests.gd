extends SceneTree
## Independent literal fixtures from SC06/016 0.4.dec and SLUS_007.26.
## Source derivation: build/Other Files/Ed Original Restore/ROM_BEAM_SPEC.txt.
const Visual = preload("res://scripts/recovered_ed_beam_visual.gd")
const RELEASE_Q12 = [4096,4096,3723,3351,2978,2606,2234,1861,1489,1117,744,372,256,256,256,256]
const ENTRY_BRIGHTNESS = [0,224,192,160,128,96,64,32,0]
const ENTRY_CENTERS = [Vector3(-5,32,-128),Vector3(-11,30,-128),Vector3(-16,28,-128),Vector3(-21,24,-128),Vector3(-25,20,-128),Vector3(-28,15,-128),Vector3(-30,9,-128),Vector3(-31,4,-128),Vector3(-31,-2,-128)]
const CIRCLE_160 = [Vector2i(0,160),Vector2i(79,138),Vector2i(138,80),Vector2i(160,0),Vector2i(138,-80),Vector2i(79,-138),Vector2i(0,-160),Vector2i(-79,-138),Vector2i(-138,-80),Vector2i(-160,0),Vector2i(-138,80),Vector2i(-79,138)]
var checks = 0
var failures = 0

func _initialize(): run.call_deferred()

func check(ok: bool, label_: String):
	checks += 1
	if not ok: failures += 1
	print("PASS: " if ok else "FAIL: ", label_)

func tint(node: MeshInstance3D) -> Vector3:
	return node.material_override.get_shader_parameter("source_tint")

func tube_bounds(node: Node3D) -> AABB:
	var result = AABB()
	var initialized = false
	for mesh in node.find_children("*", "MeshInstance3D", true, false):
		var relative: Transform3D = node.global_transform.affine_inverse() * mesh.global_transform
		for surface in mesh.mesh.get_surface_count():
			for vertex in mesh.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]:
				var point: Vector3 = relative * vertex
				if not initialized:
					result = AABB(point, Vector3.ZERO)
					initialized = true
				else: result = result.expand(point)
	return result

func run():
	var visual = Visual.new()
	root.add_child(visual)
	var growth_ok = true
	var hold_ok = true
	for index in 6:
		visual.sample(index + 1, index + 1, 1.0, 1.0, -1.0)
		growth_ok = growth_ok and visual.main.scale.is_equal_approx(Vector3.ONE * [0.0,0.25,0.5,0.75,1.0,1.0][index])
		growth_ok = growth_ok and visual.companion.scale.is_equal_approx(visual.main.scale)
		for glow in visual.glows: hold_ok = hold_ok and glow.visible == (index == 5)
	check(growth_ok, "8017F7F4/8017F918: entry scale zero, then four quarter-scale growth samples")
	check(hold_ok, "Startup visibility adapter defers body glows until the first proven hold update at actor tick6")
	var release_ok = true
	for tick in RELEASE_Q12.size():
		visual.sample(30 + tick, 30 + tick, 1.0, 1.0, -1.0, tick)
		release_ok = release_ok and is_equal_approx(visual.main.scale.x * 4096.0, RELEASE_Q12[tick]) and visual.main.scale.z == 1.0
		release_ok = release_ok and visual.strips.visible and is_equal_approx(visual.strips.material_override.get_shader_parameter("strip_width") * 4096.0, RELEASE_Q12[tick])
		release_ok = release_ok and not visual.entry.visible
		for glow in visual.glows: release_ok = release_ok and not glow.visible
	check(release_ok, "8017FCC4: release keeps length, uses exact Q12 widths, shows ribbon and hides glows")
	visual.sample(35, 22, 1.0, 1.0, -1.0)
	check(is_equal_approx(visual.main.rotation.z, 104.0 * TAU / 4096.0) and visual.companion.rotation.is_zero_approx(), "8017F8FC/8017F6E4: main roll advances120, companion keeps zero roll")
	check(not visual.strips.visible, "8017FA78: release ribbon is absent during normal hold")
	var main_bounds = tube_bounds(visual.main)
	var companion_bounds = tube_bounds(visual.companion)
	check(main_bounds.position.is_equal_approx(Vector3(-64,-64,-784)) and main_bounds.size.is_equal_approx(Vector3(128,128,784)), "801913BC: main TMD keeps radius64 and length784")
	check(companion_bounds.position.is_equal_approx(Vector3(-78,-78,-784)) and companion_bounds.size.is_equal_approx(Vector3(156,156,784)), "80191CC4: companion TMD keeps radius78 and length784")
	var palette_ok = true
	for tick in 32:
		visual.sample(tick + 1, 101 + tick, 1.0, 1.0, -1.0)
		palette_ok = palette_ok and visual.main_material.get_shader_parameter("palette_row") == tick % 16
		palette_ok = palette_ok and visual.companion_material.get_shader_parameter("palette_row") == (101 + tick) % 8
	check(palette_ok, "8017F858/8017F754: main palette is actor-local and companion uses global modulo8")
	var disc_arrays = visual.glows[0].mesh.surface_get_arrays(0)
	var circle_ok = disc_arrays[Mesh.ARRAY_VERTEX].size() == 13
	for index in 12:
		var point = CIRCLE_160[index]
		circle_ok = circle_ok and disc_arrays[Mesh.ARRAY_VERTEX][index + 1] == Vector3(-point.x,-point.y,0)
	check(circle_ok, "800233CC: radius160 disc matches all twelve integer sine-table points")
	var glow_ok = visual.glows.size() == 4 and visual.impacts.size() == 2
	for index in 4:
		glow_ok = glow_ok and visual.glows[index].position == Vector3(0,0,[-64,-224,-384,-544][index])
		glow_ok = glow_ok and tint(visual.glows[index]).is_equal_approx(Vector3(1,64.0/255.0,0))
	check(glow_ok, "8017FE90: four orange body discs use native source depths")
	var annulus_ok = true
	var anchor_ok = true
	for tick in range(1,10):
		visual.sample(tick, tick, 1.0, 1.0, -1.0)
		var brightness: int = ENTRY_BRIGHTNESS[tick - 1]
		annulus_ok = annulus_ok and visual.entry.visible and tint(visual.entry).is_equal_approx(Vector3(brightness,brightness,brightness / 2) / 255.0)
		var vertices = visual.entry.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
		annulus_ok = annulus_ok and vertices.size() == 48
		annulus_ok = annulus_ok and vertices[0] == Vector3(0,-64 * tick,0) and vertices[1] == Vector3(0,-48 * tick,0)
		annulus_ok = annulus_ok and vertices[24] == Vector3(0,-64 * tick,0) and vertices[25] == Vector3(0,-80 * tick,0)
		anchor_ok = anchor_ok and visual.entry.position == ENTRY_CENTERS[tick - 1] and visual.entry.rotation.is_zero_approx()
	check(annulus_ok, "8018048C: nine entry annuli retain source brightness and 0xC00/0x1400 radii")
	check(anchor_ok, "8018064C/801806A4: entry center follows integer roll transform while its basis keeps yaw only")
	visual.sample(10, 10, 1.0, 1.0, -1.0)
	check(not visual.entry.visible, "801806FC: entry rings stop after nine samples")
	var strip_arrays = visual.strips.mesh.surface_get_arrays(0)
	var strip_ok = strip_arrays[Mesh.ARRAY_VERTEX].size() == 40 and strip_arrays[Mesh.ARRAY_INDEX].size() == 60
	for segment in 5:
		for side in 2:
			var offset = segment * 8 + side * 4
			strip_ok = strip_ok and strip_arrays[Mesh.ARRAY_VERTEX][offset] == Vector3(0,0,64 - 128 * segment)
			strip_ok = strip_ok and strip_arrays[Mesh.ARRAY_VERTEX][offset + 1] == Vector3(0,0,-64 - 128 * segment)
			strip_ok = strip_ok and strip_arrays[Mesh.ARRAY_COLOR][offset] == (Color.BLACK if segment == 0 else Color(1,64.0/255.0,0))
			strip_ok = strip_ok and strip_arrays[Mesh.ARRAY_COLOR][offset + 2] == Color.BLACK
	check(strip_ok, "80180894: five native release segments have the source center/edge gradient")
	# Use a fresh actor to verify first-contact phase independently of absolute tick parity.
	visual.free()
	visual = Visual.new()
	root.add_child(visual)
	visual.sample(10, 110, 0.01, 1.5, -1.0)
	visual.sample(11, 111, 0.01, 1.5, 3.0)
	var first = tint(visual.impacts[0])
	visual.sample(11, 111, 0.01, 1.5, 3.0)
	check(first.is_equal_approx(Vector3.ONE * (176.0 / 255.0)) and tint(visual.impacts[0]).is_equal_approx(first), "801802F8: first hit starts176gray and duplicate sampling cannot toggle its color")
	check(visual.impacts[0].position.is_equal_approx(Vector3(0,0,-250)) and tint(visual.impacts[1]).is_equal_approx(Vector3.ONE * (128.0 / 255.0)), "8018027C: wall glows use1.25times returned hit distance and second remains128gray")
	visual.sample(12, 112, 0.01, 1.5, -1.0)
	check(not visual.impacts[0].visible and not visual.impacts[1].visible, "801803C8: no environment contact hides both wall glows")
	visual.sample(13, 113, 0.01, 1.5, 3.0)
	check(tint(visual.impacts[0]).is_equal_approx(Vector3(192,96,96) / 255.0), "801802F8: next successful contact advances the alternating color across an empty probe")
	visual.free()
	await process_frame
	print("RECOVERED_ED_BEAM_ROM_RESULT checks=", checks, " failures=", failures)
	quit(1 if failures else 0)
