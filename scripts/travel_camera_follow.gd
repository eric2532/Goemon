extends RefCounted
## Shared horizontal framing for perspective and Rogue cameras.
const FORWARD_BUFFER = 1.0
const RESPONSE = 22.0
const MAX_LAG = 8.0

var focus = Vector3.ZERO
var previous_position = Vector3.ZERO
var remaining = FORWARD_BUFFER
var moving_forward = false
var buffering = false
var forward_buffer = FORWARD_BUFFER

func reset(position: Vector3) -> void:
	focus = position
	previous_position = position
	remaining = forward_buffer
	moving_forward = false
	buffering = false

func update(position: Vector3, input: Vector2, yaw: float, delta: float) -> Vector3:
	var travel = position - previous_position
	travel.y = 0
	previous_position = position
	if travel.length_squared() > 1600.0:
		reset(position)
		return focus
	var forward = Vector3.FORWARD.rotated(Vector3.UP, yaw)
	var depth = travel.dot(forward)
	var wants_forward = input.y < -0.1
	if wants_forward and not moving_forward:
		remaining = forward_buffer
	moving_forward = wants_forward
	buffering = wants_forward and remaining > 0.0001
	var target = position
	if depth < -0.0001:
		# Translate immediately, including a reversal before forward smoothing
		# catches up. Keeping the current framing avoids a forward camera twitch.
		focus += travel
		remaining = forward_buffer
		moving_forward = false
		buffering = false
	else:
		if buffering:
			remaining = maxf(0, remaining - maxf(0, depth))
			if remaining > 0.0001:
				# Sideways motion follows normally while forward travel spends the
				# buffer. Existing smoothing lag must not consume a fresh buffer;
				# only repeated tiny reversals need the offscreen safety limit.
				var gap = clampf((position - focus).dot(forward), 0, MAX_LAG)
				target -= forward * gap
			else:
				buffering = false
		focus = focus.lerp(target, 1.0 - exp(-delta * RESPONSE))
	focus.y = position.y
	return focus
