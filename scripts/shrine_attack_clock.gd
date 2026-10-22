extends RefCounted
const INTERVAL=2.5
var remaining=INTERVAL
var strike_left=0.0
func reset()->void:
	remaining=INTERVAL;strike_left=0
func advance(delta: float,eligible: bool,paused: bool)->bool:
	if paused:return false
	if not eligible:reset();return false
	var dt=maxf(0,delta)
	strike_left=maxf(0,strike_left-dt);remaining-=dt
	if remaining>.000001:return false
	remaining=INTERVAL;strike_left=.3;return true
func pose()->StringName:
	if strike_left>0:return &"strike"
	if remaining<=.65:return &"windup"
	if remaining>1.8 and remaining<INTERVAL:return &"recover"
	return &"chase"
