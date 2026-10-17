extends RefCounted
const CAMERA_DEFAULT=12.0
const CAMERA_MIN=7.0
const CAMERA_MAX=22.0
const CAMERA_STEP=.5
const CHARACTER_OFFSET_DEFAULT=0.0
const CHARACTER_OFFSET_MIN=-.1
const CHARACTER_OFFSET_MAX=.15
const HUD_DEFAULT=1.0
const HUD_MIN=.65
const HUD_MAX=1.25
static func bounded(value,fallback: float,minimum: float,maximum: float)->float:
	if not (value is float or value is int) or not is_finite(float(value)):return fallback
	return clampf(float(value),minimum,maximum)
