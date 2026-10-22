extends RefCounted
## Scale response with each character's selected speed so faster builds remain
## responsive. Air steering, knockback and committed abilities use their own rules.
const TURN_RESPONSE=22.0
const POSE_RESPONSE=24.0

# Authored combat seconds: attack-speed boosts shorten the commitment along
# with the swing. Include a crossing tick so fast strikes cannot skip planting.
static func strike_planted(time: float,contact: float,duration: float,step: float)->bool:
	return time+step>=maxf(0,contact-.010) and time<minf(duration*.8,contact+.060)

static func acceleration(velocity: Vector3,direction: Vector3,reference_speed: float)->float:
	var rate=8.0
	if direction.length_squared()<.01:rate=11.0
	elif velocity.dot(direction)<0:rate=14.0
	return maxf(2.2,reference_speed)*rate
