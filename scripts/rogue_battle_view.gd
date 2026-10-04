extends Node3D
## Rogue's stable arena framing, adapted to Sonic's larger, vertical world.

const VIEW_OFFSET = Vector3(14, 21, 21)
const FOLLOW_FRACTION = 0.32
const BASE_SIZE = 19.8
const SIEGE_VIEW_OFFSET = Vector3(14, 28, 21)
const SIEGE_BASE_SIZE = 24.0
const SIEGE_FORWARD_LEAD = 3.6
const SIEGE_SIDE_LEAD = 2.2
const LEAD_RESPONSE = 5.0

var game: Node
var enabled = false
var aim = Vector3.ZERO
var pointer_position = Vector2.ZERO
var reticle: Node3D
var heading: Node3D
var anchor = Vector3.ZERO
var focus = Vector3.ZERO
var movement_lead = Vector3.ZERO
var _direction = Vector3.FORWARD
var _aim_normal = Vector3.UP
var _saved: Dictionary = {}
var _clock = 0.0
var _view_size = BASE_SIZE
var _camera_distance = VIEW_OFFSET.length()

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_make_markers()
	clear()
	set_process(false)

func set_enabled(value: bool) -> void:
	if enabled == value:
		return
	var rig = game.camera_rig
	var camera: Camera3D = rig.camera
	if value:
		_saved = {"projection": camera.projection, "size": camera.size,
			"keep_aspect": camera.keep_aspect, "near": camera.near,
			"fov": camera.fov, "yaw": rig.yaw, "pitch": rig.pitch,
			"distance": rig.distance, "current_distance": rig.current_distance}
		enabled = true
		set_process(true)
		camera.projection = Camera3D.PROJECTION_ORTHOGONAL
		camera.keep_aspect = Camera3D.KEEP_HEIGHT
		camera.near = 0.08
		pointer_position = get_viewport().get_mouse_position()
		reset()
	else:
		enabled = false
		movement_lead = Vector3.ZERO
		set_process(false)
		for property in ["projection", "size", "keep_aspect", "near", "fov"]:
			if _saved.has(property):
				camera.set(property, _saved[property])
		for property in ["yaw", "pitch", "distance", "current_distance"]:
			if _saved.has(property):
				rig.set(property, _saved[property])
		camera.h_offset = 0
		camera.v_offset = 0
		clear()

func reset() -> void:
	if not is_instance_valid(game) or not is_instance_valid(game.player):
		return
	var hero = game.player
	anchor = hero.global_position
	focus = anchor + Vector3.UP * 0.8 * hero.growth_multiplier()
	movement_lead = Vector3.ZERO
	_direction = hero.facing
	aim = hero.global_position + _direction * 5.0
	_aim_normal = Vector3.UP
	_view_size = _base_size()
	var view_offset = _view_offset()
	_camera_distance = view_offset.length()
	if enabled:
		var rig = game.camera_rig
		rig.yaw = atan2(view_offset.x, view_offset.z)
		rig.follow = focus
		rig.camera.size = _view_size
		rig.camera.global_position = focus + view_offset
		rig.camera.look_at(focus, Vector3.UP)
		rig.camera.h_offset = 0
		rig.camera.v_offset = 0
	clear()

func clear() -> void:
	if is_instance_valid(reticle):
		reticle.hide()
	if is_instance_valid(heading):
		heading.hide()

func _process(_dt: float) -> void:
	# The hero stops processing when paused, so it cannot clear these markers.
	if not game.playing or game.paused or game.transitioning or game.player.hp <= 0:
		clear()

func _input(event: InputEvent) -> void:
	if enabled and (event is InputEventMouseMotion or event is InputEventMouseButton):
		pointer_position = event.position

func aim_at(screen_point: Vector2) -> Vector3:
	pointer_position = screen_point
	var camera: Camera3D = game.camera_rig.camera
	var hero = game.player
	var origin = camera.project_ray_origin(screen_point)
	var ray = camera.project_ray_normal(screen_point)
	# Sky gaps must not pull the pointer hundreds of metres below the hero.
	var plane = Plane(Vector3.UP, hero.global_position.y + 0.06)
	var fallback = plane.intersects_ray(origin, ray)
	if fallback == null:
		return aim
	var point: Vector3 = fallback
	var reach = origin.distance_to(point) + 16.0
	var query = PhysicsRayQueryParameters3D.create(origin, origin + ray * reach, 1)
	query.exclude = _camera_exclusions()
	var hit = get_world_3d().direct_space_state.intersect_ray(query)
	_aim_normal = Vector3.UP
	if not hit.is_empty():
		var height_delta: float = hit.position.y - hero.global_position.y
		if height_delta >= -maxf(5.0, hero.growth_multiplier() * 2.0) and height_delta <= maxf(7.0, hero.growth_multiplier() * 4.0):
			point = hit.position
			_aim_normal = hit.normal
	aim = point
	return aim

func aim_direction() -> Vector3:
	var difference: Vector3 = aim - game.player.global_position
	difference.y = 0
	if difference.length_squared() > 0.09:
		_direction = difference.normalized()
	return _direction

func update_aim() -> void:
	if not enabled or not game.playing or game.paused or game.transitioning or game.player.hp <= 0:
		clear()
		return
	if not get_viewport().get_visible_rect().has_point(pointer_position):
		clear()
		return
	aim_at(pointer_position)
	var direction = aim_direction()
	reticle.global_position = aim + _aim_normal * 0.065
	reticle.quaternion = Quaternion(Vector3.UP, _aim_normal)
	reticle.scale = Vector3.ONE * sqrt(game.player.growth_multiplier())
	reticle.show()
	heading.global_position = game.player.global_position + Vector3.UP * 0.075
	heading.rotation.y = atan2(-direction.x, -direction.z)
	heading.scale = Vector3.ONE * sqrt(game.player.growth_multiplier())
	heading.show()

func update_camera(dt: float) -> void:
	if not enabled or not is_instance_valid(game.player):
		return
	var hero = game.player
	var rig = game.camera_rig
	var camera: Camera3D = rig.camera
	_clock += dt
	var view_offset = _view_offset()
	rig.yaw = atan2(view_offset.x, view_offset.z)
	var town = game.world.get("furnished_town")
	if is_instance_valid(town):
		town.update_cutaway(hero.global_position, rig.yaw)
	var indoors: bool = is_instance_valid(town) and town.indoor
	var speed = Vector2(hero.velocity.x, hero.velocity.z).length()
	var desired_size = (11.5 if indoors else _base_size()) * sqrt(hero.growth_multiplier())
	if not indoors:
		desired_size += clampf((speed - 12.0) * 0.13, 0, 8.0)
		if game.boss_active:
			desired_size += 2.0
		if hero.sky_strike.active:
			desired_size = maxf(desired_size, hero.sky_strike.origin.distance_to(hero.sky_strike.landing) * 1.1 + 10.0)
	_view_size = lerpf(_view_size, desired_size, 1.0 - exp(-dt * 7.0))
	# The anchor moves only at the edge of this local arena. It can travel with
	# the player indefinitely without the 32% follow stranding them offscreen.
	var displacement: Vector3 = hero.global_position - anchor
	displacement.y = 0
	var anchor_radius = _view_size * (0.2 if indoors else 0.3)
	if displacement.length() > anchor_radius:
		anchor += displacement.normalized() * (displacement.length() - anchor_radius)
	var target: Vector3 = anchor.lerp(hero.global_position, FOLLOW_FRACTION)
	var lead_weight = 0.0
	if game.rogue_roster_mode:
		var desired_lead = _movement_lead_target()
		if indoors:
			desired_lead *= 0.5
		movement_lead = movement_lead.lerp(desired_lead, 1.0 - exp(-dt * LEAD_RESPONSE))
		lead_weight = clampf(movement_lead.length() / SIEGE_FORWARD_LEAD, 0.0, 1.0)
		if movement_lead.length_squared() > 0.0001:
			# Recover the arena anchor's rearward bias before looking ahead.
			# Otherwise its partial follow can swallow the entire walking lead.
			var direction = movement_lead.normalized()
			var behind = maxf(0.0, (hero.global_position - target).dot(direction))
			target += direction * behind * lead_weight
		target += movement_lead
	else:
		movement_lead = Vector3.ZERO
	target.y = hero.global_position.y + 0.8 * hero.growth_multiplier()
	target.y -= clampf(-hero.velocity.y * 0.035, 0, 1.5)
	var snapped = focus.distance_to(target) > maxf(40.0, _view_size * 2.0)
	if snapped:
		focus = target
	else:
		var follow_response = lerpf(4.0, 8.0, lead_weight)
		focus.x = lerpf(focus.x, target.x, 1.0 - exp(-dt * follow_response))
		focus.z = lerpf(focus.z, target.z, 1.0 - exp(-dt * follow_response))
		focus.y = lerpf(focus.y, target.y, 1.0 - exp(-dt * 14.0))
	# Bound smoothing lag in camera space, including flight, dashes and falls.
	var right = Vector3(cos(rig.yaw), 0, -sin(rig.yaw))
	var backward = Vector3(sin(rig.yaw), 0, cos(rig.yaw))
	var viewport_size = get_viewport().get_visible_rect().size
	var aspect = viewport_size.x / maxf(viewport_size.y, 1.0)
	var delta_to_hero: Vector3 = hero.global_position - focus
	var side = delta_to_hero.dot(right)
	var depth = delta_to_hero.dot(backward)
	var side_limit = _view_size * aspect * 0.3
	var depth_limit = _view_size * 0.36
	focus += right * (side - clampf(side, -side_limit, side_limit))
	focus += backward * (depth - clampf(depth, -depth_limit, depth_limit))
	focus.y = clampf(focus.y, target.y - _view_size * 0.15, target.y + _view_size * 0.15)
	rig.follow = focus
	var offset = view_offset.normalized()
	var safe_distance = view_offset.length()
	if indoors:
		# Hidden roofs/walls are excluded by the existing furnished-town cutaway.
		for probe in [Vector3.ZERO, right * 0.35, -right * 0.35, Vector3.UP * 0.3]:
			var query = PhysicsRayQueryParameters3D.create(focus + probe, focus + offset * safe_distance + probe, 1)
			query.exclude = _camera_exclusions()
			var hit = get_world_3d().direct_space_state.intersect_ray(query)
			if not hit.is_empty():
				safe_distance = minf(safe_distance, maxf(0.6, focus.distance_to(hit.position) - 0.35))
	_camera_distance = lerpf(_camera_distance, safe_distance, 1.0 - exp(-dt * (32.0 if safe_distance < _camera_distance else 6.0)))
	_camera_distance = minf(_camera_distance, safe_distance + 0.08)
	camera.global_position = focus + offset * _camera_distance
	camera.look_at(focus, Vector3.UP)
	rig.kick_age += dt
	rig.impulse = move_toward(rig.impulse, 0, dt * 1.5)
	var envelope: float = exp(-rig.kick_age * 32.0) * cos(rig.kick_age * 48.0)
	var punch = minf(0.023, rig.impulse * 0.065 + absf(envelope) * rig.kick_strength * 0.03)
	camera.size = _view_size * (1.0 - punch)
	camera.h_offset = sin(_clock * 83.0) * rig.impulse * 0.22 + rig.kick_direction.x * rig.kick_strength * envelope
	camera.v_offset = cos(_clock * 73.0) * rig.impulse * 0.16 + rig.kick_direction.y * rig.kick_strength * envelope
	# Reproject after the camera moves so a stationary screen cursor stays on
	# its displayed world point between physics ticks, including fast flight.
	update_aim()

func _movement_lead_target() -> Vector3:
	if not game.playing or game.paused or game.transitioning or game.player.hp <= 0:
		return Vector3.ZERO
	var hero = game.player
	# Intent remains independent of cursor-facing, attack lunges and knockback.
	var input: Vector2 = hero.smoke_move if hero.smoke_mode else Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	input = input.limit_length()
	var depth = SIEGE_FORWARD_LEAD if input.y < 0.0 else SIEGE_SIDE_LEAD
	return Vector3(input.x * SIEGE_SIDE_LEAD, 0, input.y * depth).rotated(Vector3.UP, game.camera_rig.yaw).limit_length(SIEGE_FORWARD_LEAD)

func _base_size() -> float:
	var viewport_size = get_viewport().get_visible_rect().size
	var base_size = SIEGE_BASE_SIZE if game.rogue_roster_mode else BASE_SIZE
	return base_size * (25.0 / BASE_SIZE) if viewport_size.x / maxf(viewport_size.y, 1.0) < 1.2 else base_size

func _view_offset() -> Vector3:
	# See over siege cover while retaining the same screen-relative movement yaw.
	return SIEGE_VIEW_OFFSET if game.rogue_roster_mode else VIEW_OFFSET

func _camera_exclusions() -> Array[RID]:
	var excluded: Array[RID] = [game.player.get_rid()]
	var town = game.world.get("furnished_town")
	if is_instance_valid(town) and town.indoor:
		excluded.append_array(town.camera_exclusions)
	return excluded

func _make_markers() -> void:
	var outline = _marker_material(Color("202b2c"), 5)
	var material = _marker_material(Color("eddbab"), 6)
	reticle = Node3D.new()
	reticle.name = "BattleCursor"
	add_child(reticle)
	_ring(reticle, 0.20, 0.27, outline)
	_ring(reticle, 0.22, 0.25, material)
	for i in range(4):
		var angle = i * PI * 0.5
		var position = Vector3(sin(angle), 0, cos(angle)) * 0.38
		_marker_tick(reticle, position, Vector3(0.075, 0.012, 0.20), angle, outline)
		_marker_tick(reticle, position, Vector3(0.035, 0.012, 0.16), angle, material)
	heading = Node3D.new()
	heading.name = "BattleDirection"
	add_child(heading)
	_ring(heading, 0.55, 0.615, outline)
	_ring(heading, 0.57, 0.595, material)
	for side in [-1.0, 1.0]:
		var position = Vector3(side * 0.115, 0, -0.79)
		_marker_tick(heading, position, Vector3(0.075, 0.012, 0.35), side * PI * 0.25, outline)
		_marker_tick(heading, position, Vector3(0.035, 0.012, 0.31), side * PI * 0.25, material)

func _marker_material(color: Color, priority: int) -> StandardMaterial3D:
	var material = StandardMaterial3D.new()
	material.albedo_color = color
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	# Transparent-pass ordering keeps gold on its dark outline without z-fighting.
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.render_priority = priority
	material.no_depth_test = true
	material.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return material

func _marker_tick(parent: Node3D, point: Vector3, size: Vector3, angle: float, material: Material) -> void:
	var tick = Geo.box(parent, point, size, material)
	tick.rotation.y = angle
	tick.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func _ring(parent: Node3D, inner: float, outer: float, material: Material) -> void:
	var vertices = PackedVector3Array()
	for i in range(48):
		var a = i * TAU / 48.0
		var b = (i + 1) * TAU / 48.0
		var start = Vector3(sin(a), 0, cos(a))
		var end = Vector3(sin(b), 0, cos(b))
		vertices.append_array(PackedVector3Array([start * inner, start * outer, end * outer, start * inner, end * outer, end * inner]))
	var arrays = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	var mesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var instance = Geo.mesh(parent, mesh, Vector3.ZERO, material)
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
