extends RefCounted
## Equipment readability on the shared Goemon body; never scales the body/rig.
const SCALE=1.15
const MAX_REACH_VISUAL_SCALE=1.35

static func reach_visual_scale(reach:float)->float:
	return minf(reach,MAX_REACH_VISUAL_SCALE)

# Match Goemon readability: enlarged recovered weapons and skills, not body size.
const RECOVERED_SKILL_SCALE=1.05
