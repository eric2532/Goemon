extends RefCounted
## Release variation stays independent of aim. The crosshair experiment adds a bounded curve.
const NORMAL_YAW_DEGREES: float = 2.0
const NORMAL_PITCH_DEGREES: float = 1.25
const POWER_YAW_DEGREES: float = 2.5
const POWER_PITCH_DEGREES: float = 1.5

static func launch_direction(aim: Vector3, power: bool) -> Vector3:
	var forward: Vector3 = aim.normalized()
	var side: Vector3 = forward.cross(Vector3.UP).normalized()
	if side.length_squared() < .01: side = Vector3.RIGHT
	var up: Vector3 = side.cross(forward).normalized()
	var yaw_limit: float = deg_to_rad(POWER_YAW_DEGREES if power else NORMAL_YAW_DEGREES)
	var pitch_limit: float = deg_to_rad(POWER_PITCH_DEGREES if power else NORMAL_PITCH_DEGREES)
	var yaw: float = randf_range(-yaw_limit, yaw_limit)
	var pitch: float = randf_range(-pitch_limit, pitch_limit)
	return (forward + side * tan(yaw) + up * tan(pitch)).normalized()

static func attach(pr: Dictionary, serial: int, scale: float, curved: bool = false) -> void:
	var direction: Vector3 = pr.vel.normalized()
	pr.rangerFlight = {"origin": pr.mesh.position, "direction": direction,
		"aimDirection": pr.get("aimDirection", direction),
		"distance": 0.0, "range": pr.life * pr.vel.length(), "scale": scale, "curved": curved}
	if curved:
		var side: Vector3=direction.cross(Vector3.UP).normalized()
		if side.length_squared()<.01:side=Vector3.RIGHT
		pr.rangerFlight.curve=side*(.18 if serial%2==0 else -.18)*scale+side.cross(direction).normalized()*.12*scale
	pr.flightDirection = direction
	pr.mesh.quaternion = Quaternion(Vector3.BACK, direction)

static func advance(pr: Dictionary, dt: float) -> void:
	var f: Dictionary = pr.rangerFlight
	f.distance = minf(f.range, f.distance + pr.vel.length() * dt)
	var previous: Vector3=pr.mesh.position
	pr.mesh.position = f.origin + f.direction * f.distance
	if f.get("curved",false) and f.range>.001:
		pr.mesh.position += f.curve*sin(PI*f.distance/f.range)
		var tangent: Vector3=pr.mesh.position-previous
		if tangent.length_squared()>.000001:
			pr.flightDirection=tangent.normalized()
			pr.mesh.quaternion=Quaternion(Vector3.BACK,pr.flightDirection)
